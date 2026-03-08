#!/usr/bin/env python3
"""CPU data bridge for Quickshell popup — with cross-run process tracking."""
import psutil, json, glob, os, re, time

PROCESS_STATE_FILE = "/tmp/qs_cpu_proc_state.json"
FAN_PROFILE_FILE   = "/tmp/fan-profile"

# ── CPU name ──────────────────────────────────────────────────────────────────
cpu_name = "Unknown CPU"
try:
    with open("/proc/cpuinfo") as f:
        for line in f:
            if "model name" in line and ":" in line:
                full = line.split(":", 1)[1].strip()
                cpu_name = re.sub(r'\s+(\d+-Core\s+Processor|CPU\s+@\s+[\d.]+GHz).*', '', full).strip()
                break
except Exception:
    pass

# ── CPU usage (0.5s blocking for accuracy) ────────────────────────────────────
try:
    cpu_pct = psutil.cpu_percent(interval=0.5)
    per_core = psutil.cpu_percent(interval=None, percpu=True)
except Exception:
    cpu_pct = 0.0
    per_core = []

# ── Temperature ───────────────────────────────────────────────────────────────
max_temp = 0
try:
    for label in ["k10temp", "coretemp", "zenpower"]:
        temps = (psutil.sensors_temperatures() or {}).get(label, [])
        for t in temps:
            if t.current > max_temp:
                max_temp = int(t.current)
except Exception:
    pass

# ── Frequency ─────────────────────────────────────────────────────────────────
freq_ghz = max_freq_ghz = 0.0
try:
    info = psutil.cpu_freq(percpu=False)
    if info:
        freq_ghz     = round((info.current or 0) / 1000, 2)
        max_freq_ghz = round((info.max or info.current or 0) / 1000, 2)
except Exception:
    pass

# ── Fan speed (nct6687) ───────────────────────────────────────────────────────
fan_rpm = 0
fan_percent = 0.0
try:
    for hwmon in glob.glob("/sys/class/hwmon/hwmon*"):
        with open(os.path.join(hwmon, "name")) as f:
            if f.read().strip() != "nct6687":
                continue
        rpms, pwm_val = [], 0
        for i in range(1, 9):
            try:
                with open(os.path.join(hwmon, f"fan{i}_input")) as f:
                    rpm = int(f.read().strip())
                    if rpm > 0:
                        rpms.append(rpm)
            except Exception:
                pass
            if pwm_val == 0:
                try:
                    with open(os.path.join(hwmon, f"pwm{i}")) as f:
                        pwm_val = int(f.read().strip())
                except Exception:
                    pass
        if rpms:
            fan_rpm     = int(sum(rpms) / len(rpms))
            fan_percent = round(pwm_val / 255 * 100, 1) if pwm_val > 0 else 0.0
        break
except Exception:
    pass

# ── Power (zenpower) ──────────────────────────────────────────────────────────
cpu_power = 0.0
try:
    for hwmon in glob.glob("/sys/class/hwmon/hwmon*"):
        with open(os.path.join(hwmon, "name")) as f:
            if f.read().strip() != "zenpower":
                continue
        for pf in glob.glob(os.path.join(hwmon, "power*_input")):
            with open(pf) as f:
                cpu_power += int(f.read().strip()) / 1_000_000
        break
except Exception:
    pass

# ── Fan profile ───────────────────────────────────────────────────────────────
fan_profile = "desktop"
try:
    with open(FAN_PROFILE_FILE) as f:
        fan_profile = f.read().strip()
except Exception:
    pass

# ── Zombie count ──────────────────────────────────────────────────────────────
zombie_count = 0
try:
    zombie_count = sum(1 for p in psutil.process_iter(['status'])
                       if p.info['status'] == psutil.STATUS_ZOMBIE)
except Exception:
    pass

# Kernel threads and system processes to exclude from top CPU list
_SYSTEM_PROCS = {
    "Hyprland", "waybar", "quickshell", "walker", "Xwayland",
    "systemd", "dbus-daemon", "pipewire", "wireplumber",
    "xdg-desktop-por", "xdg-permission-",
}
_KERNEL_PREFIXES = ("kworker/", "ksoftirqd/", "migration/", "rcu_", "watchdog/",
                    "kswapd", "khugepaged", "kcompactd", "kdevtmpfs", "kthreadd",
                    "kintegrityd", "kblockd", "irq/", "idle_inject/")

def _is_system_proc(name):
    if name in _SYSTEM_PROCS:
        return True
    if any(name.startswith(p) for p in _KERNEL_PREFIXES):
        return True
    return False

# ── Top processes (cross-run state file for accurate CPU%) ───────────────────
def get_top_processes(count=5):
    now = time.time()
    prev_state = {}
    try:
        with open(PROCESS_STATE_FILE) as f:
            prev_state = json.load(f)
    except Exception:
        pass

    current_state = {}
    results = []
    cpu_count = psutil.cpu_count() or 1

    try:
        for proc in psutil.process_iter(['pid', 'name', 'status']):
            try:
                if proc.info['status'] == psutil.STATUS_ZOMBIE:
                    continue
                pid_str = str(proc.info['pid'])
                name = (proc.info['name'] or "").strip()
                if not name or _is_system_proc(name):
                    continue
                ct = proc.cpu_times()
                total = ct.user + ct.system
                current_state[pid_str] = {'cpu': total, 't': now, 'name': name}
                if pid_str in prev_state:
                    prev = prev_state[pid_str]
                    dt = now - prev['t']
                    if dt >= 0.5:
                        delta = total - prev['cpu']
                        if delta >= 0:
                            pct = (delta / dt) * 100.0 / cpu_count
                            if pct > 0.3:
                                results.append({'name': name[:22], 'pct': round(min(pct, 100.0), 1)})
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                continue
    except Exception:
        pass

    try:
        with open(PROCESS_STATE_FILE, 'w') as f:
            json.dump(current_state, f)
    except Exception:
        pass

    results.sort(key=lambda x: x['pct'], reverse=True)
    return results[:count]

top_procs = get_top_processes(15)

print(json.dumps({
    "cpu_name":      cpu_name,
    "core_count":    psutil.cpu_count(logical=True) or len(per_core),
    "percent":       round(cpu_pct, 1),
    "per_core":      [round(x, 1) for x in per_core],
    "temp":          max_temp,
    "freq_ghz":      freq_ghz,
    "max_freq_ghz":  max_freq_ghz,
    "power_w":       round(cpu_power, 1),
    "fan_rpm":       fan_rpm,
    "fan_percent":   fan_percent,
    "fan_profile":   fan_profile,
    "zombie_count":  zombie_count,
    "top_procs":     top_procs,
}))
