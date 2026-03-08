#!/usr/bin/env python3
"""Storage data bridge for Quickshell popup."""
import psutil, json, subprocess, os, re, time

IO_STATE_FILE = "/tmp/qs_storage_io_state.json"

def resolve_dm_device(dm_name):
    """Follow a device-mapper device to find the underlying physical disk."""
    try:
        import glob as _glob
        for dm_dir in _glob.glob("/sys/block/dm-*"):
            name_file = os.path.join(dm_dir, "dm", "name")
            if os.path.exists(name_file):
                with open(name_file) as f:
                    if f.read().strip() == dm_name:
                        slaves = os.listdir(os.path.join(dm_dir, "slaves"))
                        if slaves:
                            # Strip partition suffix from slave device
                            return strip_partition(slaves[0])
    except Exception:
        pass
    return dm_name

def strip_partition(device):
    """Strip partition suffix: nvme0n1p2 → nvme0n1, sda1 → sda, nvme0n1 → nvme0n1 (unchanged)."""
    if re.match(r'nvme\d+n\d+p\d+$', device):
        return re.sub(r'p\d+$', '', device)  # nvme0n1p2 → nvme0n1
    if re.match(r'nvme\d+n\d+$', device):
        return device  # already an NVMe disk (nvme0n1), no stripping needed
    return re.sub(r'\d+$', '', device)  # sda1 → sda, hda1 → hda

def get_drive_model(device):
    """Read drive model from sysfs. device should already be the disk (not partition)."""
    for path in [
        f"/sys/block/{device}/device/model",
    ]:
        try:
            with open(path) as f:
                return f.read().strip()
        except Exception:
            pass
    return device

def fmt_speed(bps):
    if bps >= 1024**3:
        return f"{bps / 1024**3:.1f} GB/s"
    if bps >= 1024**2:
        return f"{bps / 1024**2:.1f} MB/s"
    if bps >= 1024:
        return f"{bps / 1024:.0f} KB/s"
    return f"{bps} B/s"

def get_io_speeds():
    """Calculate per-device I/O speeds using a state file."""
    now = time.time()
    current = {}
    try:
        counters = psutil.disk_io_counters(perdisk=True)
        for dev, stat in counters.items():
            current[dev] = {"r": stat.read_bytes, "w": stat.write_bytes, "t": now}
    except Exception:
        pass

    speeds = {}
    try:
        with open(IO_STATE_FILE) as f:
            prev = json.load(f)
        for dev, cur in current.items():
            if dev in prev:
                dt = cur["t"] - prev[dev]["t"]
                if dt > 0.5:
                    speeds[dev] = {
                        "read_bps":  max(0, int((cur["r"] - prev[dev]["r"]) / dt)),
                        "write_bps": max(0, int((cur["w"] - prev[dev]["w"]) / dt)),
                        "read_str":  fmt_speed(max(0, (cur["r"] - prev[dev]["r"]) / dt)),
                        "write_str": fmt_speed(max(0, (cur["w"] - prev[dev]["w"]) / dt)),
                    }
    except Exception:
        pass

    try:
        with open(IO_STATE_FILE, "w") as f:
            json.dump(current, f)
    except Exception:
        pass

    return speeds

def get_smart_info(device):
    """SMART data for temperature, health, lifespan."""
    result = {"health": "", "temp": 0, "lifespan": ""}
    try:
        r = subprocess.run(
            ["sudo", "-n", "smartctl", "-A", "-H", f"/dev/{device}"],
            capture_output=True, text=True, timeout=5
        )
        if r.returncode in (0, 4):
            text = r.stdout
            if "PASSED" in text or " OK" in text:
                result["health"] = "OK"
            elif "FAILED" in text:
                result["health"] = "FAIL"
            for line in text.splitlines():
                if "Temperature" in line:
                    m = re.search(r'(\d+)\s*(?:Celsius|°C|\()?$', line.split('#')[0].strip())
                    if not m:
                        m = re.search(r'\b(\d{2})\b', line)
                    if m and 20 <= int(m.group(1)) <= 120:
                        result["temp"] = int(m.group(1))
                        break
            for line in text.splitlines():
                if "Percentage Used" in line:
                    m = re.search(r'(\d+)', line.split()[-1])
                    if m:
                        result["lifespan"] = f"{100 - int(m.group(1))}%"
                    break
                if "SSD_Life_Left" in line or "Wear_Leveling_Count" in line:
                    m = re.search(r'\b(\d{1,3})\b', line)
                    if m:
                        result["lifespan"] = f"{m.group(1)}%"
                    break
    except Exception:
        pass
    return result

def resolve_block_device(mountpoint, psutil_device):
    """Resolve the actual block device, following device-mapper to physical disk."""
    dev = psutil_device
    if not dev.startswith("/dev/"):
        try:
            with open("/proc/mounts") as f:
                for line in f:
                    parts = line.split()
                    if len(parts) >= 2 and parts[1] == mountpoint and parts[0].startswith("/dev/"):
                        dev = parts[0]
                        break
        except Exception:
            pass
    # Follow device mapper (/dev/mapper/name → underlying physical device)
    if dev.startswith("/dev/mapper/"):
        dm_name = os.path.basename(dev)
        phys = resolve_dm_device(dm_name)
        return f"/dev/{phys}"
    return dev

io_speeds = get_io_speeds()
drives = []
seen = set()

try:
    for part in sorted(psutil.disk_partitions(all=False), key=lambda p: p.mountpoint):
        if part.fstype in ("squashfs", "tmpfs", "devtmpfs", ""):
            continue
        actual_dev = resolve_block_device(part.mountpoint, part.device)
        raw_dev = os.path.basename(actual_dev) if actual_dev.startswith("/dev/") else ""
        base_dev = strip_partition(raw_dev) if raw_dev else ""
        if base_dev in seen:
            continue
        seen.add(base_dev)

        try:
            usage = psutil.disk_usage(part.mountpoint)
        except Exception:
            continue

        smart = get_smart_info(base_dev) if base_dev else {}
        model = get_drive_model(base_dev) if base_dev else part.device

        # Match I/O speeds (nvme0n1, sda, etc.)
        io = io_speeds.get(raw_dev) or io_speeds.get(base_dev) or {}

        drives.append({
            "model":       model,
            "device":      base_dev or raw_dev,
            "mountpoint":  part.mountpoint,
            "fstype":      part.fstype,
            "total_gb":    round(usage.total / 1024**3, 1),
            "used_gb":     round(usage.used / 1024**3, 1),
            "free_gb":     round(usage.free / 1024**3, 1),
            "used_percent": int(usage.percent),
            "temperature": smart.get("temp", 0),
            "health":      smart.get("health", ""),
            "lifespan":    smart.get("lifespan", ""),
            "read_bps":    io.get("read_bps", 0),
            "write_bps":   io.get("write_bps", 0),
            "read_str":    io.get("read_str", "0 B/s"),
            "write_str":   io.get("write_str", "0 B/s"),
        })
except Exception as e:
    drives = [{"error": str(e), "model": "Error", "device": "", "mountpoint": "/",
               "total_gb": 0, "used_gb": 0, "free_gb": 0, "used_percent": 0,
               "temperature": 0, "health": "", "lifespan": "",
               "read_bps": 0, "write_bps": 0, "read_str": "0 B/s", "write_str": "0 B/s"}]

print(json.dumps({"drives": drives}))
