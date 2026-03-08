#!/usr/bin/env python3
"""System integrity data bridge for Quickshell popup."""
import asyncio, json, psutil, shutil, os
from pathlib import Path
from datetime import datetime

async def run_cmd(cmd, timeout=5):
    try:
        proc = await asyncio.wait_for(
            asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            ),
            timeout=timeout
        )
        stdout, stderr = await proc.communicate()
        return proc.returncode or 0, stdout.decode("utf-8", errors="replace").strip()
    except Exception:
        return -1, ""

async def check_systemd():
    code, out = await run_cmd(["systemctl", "--failed", "--no-legend", "--quiet"])
    if code != 0:
        return "UNKNOWN", "Cannot query systemd", []
    if not out:
        return "OK", "All services healthy", []
    failed = [l.split()[1] for l in out.splitlines() if l.strip() and len(l.split()) > 1]
    return ("WARNING" if len(failed) < 3 else "CRITICAL"), f"{len(failed)} failed service(s)", failed[:4]

async def check_disk_space():
    warnings = []
    for part in psutil.disk_partitions(all=False):
        if part.fstype in ("squashfs", "tmpfs", "devtmpfs"):
            continue
        try:
            usage = psutil.disk_usage(part.mountpoint)
            if usage.percent >= 90:
                warnings.append(f"{part.mountpoint}: {usage.percent:.0f}%")
        except Exception:
            pass
    if warnings:
        return "WARNING", f"{len(warnings)} partition(s) nearly full", warnings
    return "OK", "Disk space OK", []

async def check_memory():
    mem = psutil.virtual_memory()
    if mem.percent >= 95:
        return "CRITICAL", f"Critical: {mem.percent:.0f}%", []
    if mem.percent >= 85:
        return "WARNING", f"High: {mem.percent:.0f}%", []
    return "OK", f"OK ({mem.percent:.0f}%)", []

async def check_cpu_load():
    try:
        load1, _, _ = os.getloadavg()
        cpu_count = psutil.cpu_count() or 1
        if load1 > cpu_count * 2:
            return "WARNING", f"High: {load1:.2f}", []
        return "OK", f"Load: {load1:.2f}", []
    except Exception:
        return "UNKNOWN", "Cannot read load", []

async def check_temperature():
    try:
        temps = psutil.sensors_temperatures()
        if not temps:
            return "UNKNOWN", "No sensors", []
        max_t = 0.0
        hot = []
        for name, entries in temps.items():
            for e in entries:
                if e.current:
                    max_t = max(max_t, e.current)
                    if e.current >= 85:
                        hot.append(f"{name}: {e.current:.0f}°C")
        if hot:
            st = "CRITICAL" if max_t >= 90 else "WARNING"
            return st, f"High: {max_t:.0f}°C", hot[:3]
        return "OK", f"Max {max_t:.0f}°C", []
    except Exception:
        return "UNKNOWN", "Sensor error", []

async def check_network():
    try:
        reader, writer = await asyncio.wait_for(
            asyncio.open_connection("8.8.8.8", 53), timeout=3
        )
        writer.close()
        await writer.wait_closed()
        return "OK", "Internet connected", []
    except asyncio.TimeoutError:
        return "WARNING", "Unreachable (timeout)", []
    except OSError:
        return "WARNING", "Network error", []

async def check_updates():
    if not shutil.which("checkupdates"):
        return "UNKNOWN", "checkupdates not found", []
    code, out = await run_cmd(["checkupdates"], timeout=15)
    if code == 2 or not out:
        return "OK", "Up to date", []
    count = len([l for l in out.splitlines() if l.strip()])
    if count >= 50:
        return "CRITICAL", f"{count} updates", []
    if count >= 20:
        return "WARNING", f"{count} updates", []
    return "OK", f"{count} updates available", []

async def check_pacman_lock():
    if Path("/var/lib/pacman/db.lck").exists():
        return "WARNING", "Database locked", ["rm /var/lib/pacman/db.lck"]
    return "OK", "Unlocked", []

async def check_boot():
    running = os.uname().release
    issues = []
    kernel_variant = "linux"
    if "-zen" in running: kernel_variant = "linux-zen"
    elif "-lts" in running: kernel_variant = "linux-lts"
    elif "-hardened" in running: kernel_variant = "linux-hardened"
    uki_dir = Path("/boot/EFI/Linux")
    if uki_dir.exists():
        uki_files = list(uki_dir.glob(f"*{kernel_variant}*.efi"))
        if uki_files:
            kp = Path(f"/boot/vmlinuz-{kernel_variant}")
            for uki in uki_files:
                if kp.exists() and uki.stat().st_mtime < kp.stat().st_mtime:
                    issues.append("UKI older than kernel")
        else:
            issues.append(f"Missing UKI for {kernel_variant}")
    modules_dir = Path(f"/lib/modules/{running}")
    if not modules_dir.exists():
        issues.append("Missing kernel modules")
    if issues:
        return "CRITICAL", "Boot config issues", issues
    return "OK", "Boot files valid", []

async def check_security():
    issues = []
    for svc in ["firewalld", "ufw", "iptables", "nftables"]:
        code, _ = await run_cmd(["systemctl", "is-active", svc])
        if code == 0:
            break
    else:
        issues.append("No active firewall")
    if issues:
        return "WARNING", "Concerns detected", issues
    return "OK", "Checks passed", []

async def check_mirror():
    sync_dir = Path("/var/lib/pacman/sync")
    if not sync_dir.exists():
        return "UNKNOWN", "No sync database", []
    try:
        db_files = list(sync_dir.glob("*.db"))
        if not db_files:
            return "UNKNOWN", "No database files", []
        newest = max(f.stat().st_mtime for f in db_files)
        age_h = (datetime.now().timestamp() - newest) / 3600
        if age_h > 168:
            return "WARNING", f"{age_h/24:.0f} days old", []
        if age_h > 48:
            return "WARNING", f"{age_h:.0f}h old", []
        return "OK", f"Synced {age_h:.1f}h ago", []
    except Exception:
        return "UNKNOWN", "Cannot check", []

async def check_journal_errors():
    code, out = await run_cmd([
        "journalctl", "-p", "err", "--since", "1 hour ago",
        "--no-legend", "-q", "--lines=50"
    ], timeout=5)
    if code == 0 and out:
        count = len([l for l in out.splitlines() if l.strip()])
        if count > 20:
            return "WARNING", f"{count} errors (1h)", []
    return "OK", "No critical errors", []

async def check_smart():
    if not shutil.which("smartctl"):
        return "UNKNOWN", "smartctl not installed", []
    code, out = await run_cmd(["lsblk", "-d", "-n", "-o", "NAME,TYPE"])
    if code != 0:
        return "UNKNOWN", "Cannot list devices", []
    issues = []
    for line in out.splitlines()[:4]:
        parts = line.split()
        if not parts:
            continue
        dev = parts[0]
        if any(x in dev for x in ("loop", "rom")):
            continue
        c, o = await run_cmd(["sudo", "-n", "smartctl", "-H", f"/dev/{dev}"])
        if c in (0, 4) and o and "PASSED" not in o and "OK" not in o:
            issues.append(f"{dev}: SMART warning")
    if issues:
        return "WARNING", f"{len(issues)} disk(s) warning", issues
    return "OK", "All disks healthy", []

async def run_all():
    checks_meta = [
        ("Systemd Services",  check_systemd()),
        ("Disk Health",       check_smart()),
        ("System Updates",    check_updates()),
        ("Security",          check_security()),
        ("Journal Errors",    check_journal_errors()),
        ("Disk Space",        check_disk_space()),
        ("Memory",            check_memory()),
        ("CPU Load",          check_cpu_load()),
        ("Temperatures",      check_temperature()),
        ("Network",           check_network()),
        ("Pacman Lock",       check_pacman_lock()),
        ("Mirror Status",     check_mirror()),
        ("Boot Config",       check_boot()),
    ]

    results = await asyncio.gather(*[fn for _, fn in checks_meta], return_exceptions=True)

    checks = []
    overall = "OK"
    for (name, _), result in zip(checks_meta, results):
        if isinstance(result, Exception):
            status, msg, details = "UNKNOWN", str(result)[:40], []
        else:
            status, msg, details = result
        checks.append({"name": name, "status": status, "message": msg, "details": details[:3]})
        if status == "CRITICAL":
            overall = "CRITICAL"
        elif status == "WARNING" and overall not in ("CRITICAL",):
            overall = "WARNING"
        elif status == "UNKNOWN" and overall == "OK":
            overall = "UNKNOWN"

    return {"checks": checks, "overall": overall, "timestamp": datetime.now().strftime("%H:%M:%S")}

print(json.dumps(asyncio.run(run_all())))
