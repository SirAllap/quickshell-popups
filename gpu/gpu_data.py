#!/usr/bin/env python3
"""GPU data bridge for Quickshell popup (AMD via sysfs)."""
import json, os, sys
from pathlib import Path

DRM_BASE = Path("/sys/class/drm")

GPU_PCI_IDS = {
    "0x744c": "RX 7900 XTX", "0x7448": "RX 7900 XT", "0x7480": "RX 7900 GRE",
    "0x7422": "RX 7700 XT",  "0x7423": "RX 7800 XT", "0x73bf": "RX 6900 XT",
    "0x73a5": "RX 6950 XT",  "0x687f": "Vega 64",    "0x6fdf": "RX 580",
    "0x687e": "Vega 56",     "0x731f": "RX 5700 XT", "0x7310": "RX 5700",
}

def find_drm():
    for n in range(4):
        p = DRM_BASE / f"card{n}/device"
        if not p.exists():
            continue
        vp = p / "vendor"
        if vp.exists():
            try:
                if vp.read_text().strip() in ("0x1002", "0x1022"):
                    return p
            except Exception:
                pass
        if (p / "mem_info_vram_total").exists():
            return p
    return None

def find_hwmon(drm):
    hwmon_base = drm / "hwmon"
    if not hwmon_base.exists():
        return None
    try:
        dirs = [d for d in hwmon_base.iterdir() if d.name.startswith("hwmon")]
        return dirs[0] if dirs else None
    except Exception:
        return None

def ri(path, div=1, default=0):
    try:
        return int(path.read_text().strip()) // div
    except Exception:
        return default

def rf(path, div=1.0, default=0.0):
    try:
        return float(path.read_text().strip()) / div
    except Exception:
        return default

drm = find_drm()
if not drm:
    print(json.dumps({"error": "No AMD GPU found", "name": "N/A", "temperature": 0,
                      "utilization": 0, "power_draw": 0, "power_limit": 0,
                      "vram_used_mb": 0, "vram_total_mb": 0, "fan_rpm": 0,
                      "fan_percent": 0, "processes": []}))
    sys.exit(0)

hwmon = find_hwmon(drm)

# GPU name
name = "AMD Radeon GPU"
try:
    dev_id = (drm / "device").read_text().strip()
    for pid, pname in GPU_PCI_IDS.items():
        if pid in dev_id:
            name = f"AMD Radeon {pname}"
            break
except Exception:
    pass

# VRAM
vram_total = ri(drm / "mem_info_vram_total", div=1024*1024) if (drm / "mem_info_vram_total").exists() else 0
vram_used = ri(drm / "mem_info_vram_used", div=1024*1024) if (drm / "mem_info_vram_used").exists() else 0

# Utilization
utilization = ri(drm / "gpu_busy_percent")

temp = 0
power_draw = 0.0
power_limit = 355.0
fan_rpm = 0
fan_percent = 0.0

if hwmon:
    for tf in ["temp1_input", "temp2_input", "temp3_input"]:
        val = ri(hwmon / tf, div=1000)
        if val > 0:
            temp = val
            break
    for pf in ["power1_average", "power1_input"]:
        pp = hwmon / pf
        if pp.exists():
            power_draw = rf(pp, div=1_000_000.0)
            break
    cap = hwmon / "power1_cap"
    if cap.exists():
        power_limit = rf(cap, div=1_000_000.0)
        if power_limit <= 0:
            power_limit = 355.0
    fi = hwmon / "fan1_input"
    pw = hwmon / "pwm1"
    pwm_max_f = hwmon / "pwm1_max"
    if fi.exists():
        fan_rpm = ri(fi)
    if pw.exists():
        pwm_val = ri(pw)
        pwm_max = ri(pwm_max_f, default=255) if pwm_max_f.exists() else 255
        fan_percent = round(pwm_val / pwm_max * 100, 1) if pwm_max > 0 else 0.0

# Compositor/system processes that inflate VRAM via shared buffer references
SYSTEM_PROCS = {"Hyprland", "Xwayland", "xdg-desktop-por", "quickshell", "walker",
                "xdg-permission-", "pipewire", "wireplumber", "hyprland"}

# Processes — detect via drm-memory-vram in /proc/PID/fdinfo (works for any GPU app)
processes = []
try:
    own_pid = str(os.getpid())
    for pid_str in os.listdir("/proc"):
        if not pid_str.isdigit() or pid_str == own_pid:
            continue
        fdinfo_dir = Path(f"/proc/{pid_str}/fdinfo")
        if not fdinfo_dir.exists():
            continue
        try:
            vram_kib = 0
            for fd_path in fdinfo_dir.iterdir():
                try:
                    for line in fd_path.read_text().splitlines():
                        if line.startswith("drm-memory-vram:"):
                            parts = line.split()
                            if len(parts) >= 2:
                                vram_kib += int(parts[1])
                            break
                except Exception:
                    pass
            if vram_kib > 0:
                try:
                    proc_name = Path(f"/proc/{pid_str}/comm").read_text().strip()
                except Exception:
                    proc_name = f"pid{pid_str}"
                if proc_name in SYSTEM_PROCS or any(proc_name.startswith(p) for p in SYSTEM_PROCS):
                    continue
                processes.append({"name": proc_name[:22], "vram_mb": vram_kib // 1024})
        except (PermissionError, OSError):
            pass
    processes.sort(key=lambda x: x["vram_mb"], reverse=True)
    processes = processes[:10]
except Exception:
    pass

vram_percent = round(vram_used / vram_total * 100, 1) if vram_total > 0 else 0.0
power_percent = round(power_draw / power_limit * 100, 1) if power_limit > 0 else 0.0

print(json.dumps({
    "name": name,
    "temperature": temp,
    "utilization": utilization,
    "power_draw": round(power_draw, 1),
    "power_limit": round(power_limit, 1),
    "power_percent": power_percent,
    "vram_used_mb": vram_used,
    "vram_total_mb": vram_total,
    "vram_percent": vram_percent,
    "fan_rpm": fan_rpm,
    "fan_percent": fan_percent,
    "processes": processes
}))
