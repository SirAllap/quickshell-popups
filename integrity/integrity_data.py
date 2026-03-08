#!/usr/bin/env python3
"""System integrity data bridge for Quickshell popup.
Matches the same 19 checks as waybar-system-integrity.py."""
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

# ── Checks ────────────────────────────────────────────────────────────────────

async def check_systemd():
    code, out = await run_cmd(["systemctl", "--failed", "--no-legend", "--quiet"])
    if code != 0:
        return "UNKNOWN", "Cannot query systemd", []
    if not out:
        return "OK", "All services healthy", []
    failed = [l.split()[1] for l in out.splitlines() if l.strip() and len(l.split()) > 1]
    return ("WARNING" if len(failed) < 3 else "CRITICAL"), f"{len(failed)} failed service(s)", failed[:5]

async def check_disk_health():
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

async def check_updates():
    if not shutil.which("checkupdates"):
        return "UNKNOWN", "checkupdates not found", []
    code, out = await run_cmd(["checkupdates"], timeout=15)
    if code == 2 or not out:
        return "OK", "Up to date", []
    count = len([l for l in out.splitlines() if l.strip()])
    if count >= 50:
        return "CRITICAL", f"{count} updates available", []
    if count >= 20:
        return "WARNING", f"{count} updates available", []
    return "OK", f"{count} updates available", []

async def check_security():
    issues = []
    for svc in ["firewalld", "ufw", "iptables", "nftables"]:
        code, _ = await run_cmd(["systemctl", "is-active", svc])
        if code == 0:
            break
    else:
        issues.append("No active firewall")
    # Check SSH on default port
    code, _ = await run_cmd(["systemctl", "is-active", "sshd"])
    if code == 0:
        c, o = await run_cmd(["ss", "-tlnp", "sport", "=", ":22"])
        if c == 0 and ":22 " in o:
            issues.append("SSH on port 22")
    if issues:
        return "WARNING", "Concerns detected", issues
    return "OK", "Checks passed", []

async def check_system_errors():
    errors = []
    # dmesg kernel errors
    code, out = await run_cmd(["dmesg", "-l", "err,crit,alert,emerg"])
    if code == 0 and out:
        count = len([l for l in out.splitlines() if l.strip()])
        if count > 0:
            errors.append(f"{count} kernel error(s)")
    # journal errors last hour
    code, out = await run_cmd([
        "journalctl", "-p", "err", "--since", "1 hour ago", "--no-legend", "-q"
    ], timeout=5)
    if code == 0 and out:
        count = len([l for l in out.splitlines() if l.strip()])
        if count > 10:
            errors.append(f"{count} journal error(s) (1h)")
    if errors:
        return "WARNING", "Errors detected", errors
    return "OK", "No critical errors", []

async def check_disk_space():
    warnings = []
    for part in psutil.disk_partitions(all=False):
        if not part.fstype or part.fstype in ("squashfs", "tmpfs", "devtmpfs"):
            continue
        try:
            usage = psutil.disk_usage(part.mountpoint)
            if usage.percent >= 90:
                warnings.append(f"{part.mountpoint}: {usage.percent:.0f}% (critical)")
            elif usage.percent >= 80:
                warnings.append(f"{part.mountpoint}: {usage.percent:.0f}% (warning)")
        except Exception:
            pass
    if warnings:
        sev = "CRITICAL" if any("critical" in w for w in warnings) else "WARNING"
        return sev, f"{len(warnings)} partition(s) full", warnings
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
                    if e.current >= 75:
                        hot.append(f"{name}: {e.current:.0f}°C")
        if hot:
            st = "CRITICAL" if max_t >= 85 else "WARNING"
            return st, f"High: {max_t:.0f}°C", hot[:3]
        return "OK", f"Max {max_t:.0f}°C", []
    except Exception:
        return "UNKNOWN", "Sensor error", []

async def check_filesystems():
    issues = []
    if shutil.which("zpool"):
        code, out = await run_cmd(["zpool", "status", "-x"])
        if code == 0 and out and "healthy" not in out.lower():
            issues.append("ZFS pool unhealthy")
    if shutil.which("btrfs"):
        code, out = await run_cmd(["btrfs", "filesystem", "show"])
        if code != 0 or (out and "error" in out.lower()):
            issues.append("BTRFS error detected")
    if not shutil.which("zpool") and not shutil.which("btrfs"):
        return "UNKNOWN", "No ZFS/BTRFS tools", []
    if issues:
        return "WARNING", "Filesystem issues", issues
    return "OK", "Filesystems healthy", []

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

async def check_btrfs_scrub():
    if not shutil.which("btrfs"):
        return "UNKNOWN", "btrfs-progs not installed", []
    code, out = await run_cmd(["btrfs", "filesystem", "show", "--mounted"])
    if code != 0:
        return "UNKNOWN", "Cannot list BTRFS filesystems", []
    issues = []
    for line in out.splitlines():
        if "uuid" in line.lower():
            mount = line.split()[-1] if line.split() else "/"
            _, scrub_out = await run_cmd(["btrfs", "scrub", "status", mount])
            if "no stats available" not in scrub_out and "finished" not in scrub_out:
                if "running" in scrub_out:
                    issues.append(f"{mount}: scrub running")
                elif scrub_out and "error" in scrub_out.lower():
                    issues.append(f"{mount}: scrub errors")
            _, stats_out = await run_cmd(["btrfs", "device", "stats", mount])
            corruption = [l for l in stats_out.splitlines() if l.strip() and not l.endswith("0")]
            if corruption:
                issues.append(f"{mount}: {len(corruption)} device error(s)")
    if issues:
        return "WARNING", "BTRFS attention needed", issues
    return "OK", "BTRFS healthy", []

async def check_pacman_log():
    log_path = Path("/var/log/pacman.log")
    if not log_path.exists():
        return "UNKNOWN", "No pacman log", []
    code, out = await run_cmd(["tail", "-n", "50", str(log_path)])
    if code != 0:
        return "UNKNOWN", "Cannot read log", []
    errors = []
    for line in out.splitlines():
        if any(x in line.lower() for x in ["error", "failed", "warning:", "could not"]):
            errors.append(line.split("] ", 1)[-1][:60])
    if Path("/var/lib/pacman/db.lck").exists():
        errors.append("Pacman database locked")
    if errors:
        return ("WARNING" if len(errors) < 3 else "CRITICAL"), f"{len(errors)} recent issue(s)", errors[-3:]
    return "OK", "Pacman healthy", []

async def check_aur_updates():
    helper = next((h for h in ["yay", "paru"] if shutil.which(h)), None)
    if not helper:
        return "UNKNOWN", "No AUR helper found", []
    code, out = await run_cmd([helper, "-Qua"], timeout=15)
    if code != 0:
        return "UNKNOWN", f"{helper} query failed", []
    count = len([l for l in out.splitlines() if l.strip()])
    if count > 20:
        return "WARNING", f"{count} AUR updates", []
    if count > 0:
        return "OK", f"{count} AUR updates", []
    return "OK", "AUR up to date", []

async def check_systemd_timers():
    code, out = await run_cmd(["systemctl", "list-timers", "--all", "--no-legend", "--failed"])
    if code != 0:
        return "UNKNOWN", "Cannot query timers", []
    failed = [l.split()[0] for l in out.splitlines() if l.strip()]
    code, out = await run_cmd(["systemctl", "list-timers", "--all", "--no-legend"])
    stuck = []
    for line in out.splitlines():
        parts = line.split()
        if len(parts) >= 3 and parts[2] == "n/a":
            stuck.append(parts[0])
    issues = failed + stuck
    if issues:
        return "WARNING", f"{len(issues)} timer issue(s)", issues[:5]
    return "OK", "All timers healthy", []

async def check_build_env():
    issues = []
    code, out = await run_cmd(["pacman", "-Qdtq"])
    if code == 0 and out:
        orphans = len(out.splitlines())
        if orphans > 10:
            issues.append(f"{orphans} orphaned packages")
    cache_dir = Path("/var/cache/pacman/pkg")
    if cache_dir.exists():
        try:
            total = sum(f.stat().st_size for f in cache_dir.glob("*.pkg.tar*"))
            size_gb = total / (1024 ** 3)
            if size_gb > 5:
                issues.append(f"Package cache: {size_gb:.1f}GB")
        except PermissionError:
            pass
    if issues:
        return "WARNING", "Build env issues", issues
    return "OK", "Build env clean", []

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
            return "CRITICAL", f"{age_h/24:.0f} days old", []
        if age_h > 24:
            return "WARNING", f"{age_h:.0f}h old", []
        return "OK", f"Synced {age_h:.1f}h ago", []
    except Exception:
        return "UNKNOWN", "Cannot check", []

async def check_initramfs():
    running = os.uname().release
    issues = []
    kernel_variant = "linux"
    if "-zen" in running: kernel_variant = "linux-zen"
    elif "-lts" in running: kernel_variant = "linux-lts"
    elif "-hardened" in running: kernel_variant = "linux-hardened"
    uki_dir = Path("/boot/EFI/Linux")
    has_uki = False
    if uki_dir.exists():
        uki_files = list(uki_dir.glob(f"*{kernel_variant}*.efi"))
        if uki_files:
            has_uki = True
            kp = Path(f"/boot/vmlinuz-{kernel_variant}")
            for uki in uki_files:
                if kp.exists() and uki.stat().st_mtime < kp.stat().st_mtime:
                    issues.append(f"UKI older than kernel: {uki.name}")
        else:
            issues.append(f"Missing UKI for {kernel_variant}")
    if not has_uki and not Path("/boot/initramfs-linux.img").exists():
        issues.append(f"Missing initramfs for {running}")
    if not Path(f"/lib/modules/{running}").exists():
        issues.append("Missing kernel modules")
    log_path = Path("/var/log/mkinitcpio.log")
    if log_path.exists():
        code, out = await run_cmd(["tail", "-n", "5", str(log_path)])
        if code == 0 and "error" in out.lower():
            issues.append("Recent mkinitcpio errors")
    if issues:
        return "CRITICAL", "Boot config issues", issues
    return "OK", "Boot files valid", []

# ── Fix actions ───────────────────────────────────────────────────────────────
_FIX_ACTIONS = {
    "System Updates":   ("Update Now",    "omarchy-launch-floating-terminal-with-presentation omarchy-update"),
    "AUR Updates":      ("Update AUR",    "omarchy-launch-floating-terminal-with-presentation yay -Syu --aur"),
    "Mirror Status":    ("Sync Mirrors",  "pkexec pacman -Sy"),
    "Pacman Log":       ("Remove Lock",   "pkexec sh -c 'rm -f /var/lib/pacman/db.lck'"),
    "Memory":           ("Clear Cache",   "bash -c 'sync; echo 3 | pkexec tee /proc/sys/vm/drop_caches > /dev/null'"),
    "Network":          ("Reconnect",     "bash -c 'nmcli networking off; sleep 1; nmcli networking on'"),
    "Systemd Services": ("View Logs",     "xdg-terminal-exec journalctl -xe"),
    "Disk Space":       ("Open Files",    "nautilus /"),
    "Initramfs":        ("Rebuild",       "omarchy-launch-floating-terminal-with-presentation bash -c 'sudo mkinitcpio -P; read -p \"Done — press enter\"'"),
    "Build Environment":("Clean Cache",   "omarchy-launch-floating-terminal-with-presentation bash -c 'sudo find /var/cache/pacman/pkg -maxdepth 1 -name \"download-*\" -delete 2>/dev/null; yes | sudo pacman -Scc; read -p \"Done — press enter\"'"),
}

# ── Runner ────────────────────────────────────────────────────────────────────
async def run_all():
    checks_meta = [
        ("Systemd Services",  check_systemd()),
        ("Disk Health",       check_disk_health()),
        ("System Updates",    check_updates()),
        ("Security",          check_security()),
        ("System Errors",     check_system_errors()),
        ("Disk Space",        check_disk_space()),
        ("Memory",            check_memory()),
        ("CPU Load",          check_cpu_load()),
        ("Temperatures",      check_temperature()),
        ("Filesystems",       check_filesystems()),
        ("Network",           check_network()),
        ("BTRFS Scrub",       check_btrfs_scrub()),
        ("Pacman Log",        check_pacman_log()),
        ("AUR Updates",       check_aur_updates()),
        ("Systemd Timers",    check_systemd_timers()),
        ("Build Environment", check_build_env()),
        ("Mirror Status",     check_mirror()),
        ("Initramfs",         check_initramfs()),
    ]

    results = await asyncio.gather(*[fn for _, fn in checks_meta], return_exceptions=True)

    checks = []
    overall = "OK"
    for (name, _), result in zip(checks_meta, results):
        if isinstance(result, Exception):
            status, msg, details = "UNKNOWN", str(result)[:40], []
        else:
            status, msg, details = result

        fix_label, fix_cmd = "", ""
        if status not in ("OK",) and name in _FIX_ACTIONS:
            fix_label, fix_cmd = _FIX_ACTIONS[name]

        checks.append({"name": name, "status": status, "message": msg,
                       "details": details[:3], "fix_label": fix_label, "fix_cmd": fix_cmd})
        if status == "CRITICAL":
            overall = "CRITICAL"
        elif status == "WARNING" and overall != "CRITICAL":
            overall = "WARNING"
        elif status == "UNKNOWN" and overall == "OK":
            overall = "UNKNOWN"

    _order = {"CRITICAL": 0, "WARNING": 1, "UNKNOWN": 2, "OK": 3}
    checks.sort(key=lambda c: _order.get(c["status"], 4))
    return {"checks": checks, "overall": overall, "timestamp": datetime.now().strftime("%H:%M:%S")}

print(json.dumps(asyncio.run(run_all())))
