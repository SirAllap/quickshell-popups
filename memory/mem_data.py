#!/usr/bin/env python3
"""Memory data bridge for Quickshell popup."""
import psutil, json, subprocess

mem = psutil.virtual_memory()
swap = psutil.swap_memory()

total_gb    = round(mem.total   / 1024**3, 2)
used_gb     = round(mem.used    / 1024**3, 2)
available_gb = round(mem.available / 1024**3, 2)
cached_gb   = round(getattr(mem, 'cached', 0) / 1024**3, 2)
buffers_gb  = round(getattr(mem, 'buffers', 0) / 1024**3, 2)
free_gb     = round(mem.free    / 1024**3, 2)
percent     = round(mem.percent, 1)

swap_total_gb = round(swap.total / 1024**3, 2)
swap_used_gb  = round(swap.used  / 1024**3, 2)
swap_percent  = round(swap.percent, 1)

# Memory modules via dmidecode (needs sudo -n)
modules = []
try:
    r = subprocess.run(
        ["sudo", "-n", "dmidecode", "-t", "memory"],
        capture_output=True, text=True, timeout=4
    )
    if r.returncode == 0:
        current = {}
        for line in r.stdout.splitlines():
            line = line.strip()
            if line.startswith("Memory Device"):
                if current:
                    sz = current.get("Size", "")
                    if sz and "No Module" not in sz and "Not Installed" not in sz:
                        modules.append(current)
                current = {}
            elif ": " in line:
                k, v = line.split(": ", 1)
                current[k.strip()] = v.strip()
        if current:
            sz = current.get("Size", "")
            if sz and "No Module" not in sz and "Not Installed" not in sz:
                modules.append(current)
except Exception:
    pass

clean_modules = []
slot = 1
for m in modules:
    size = m.get("Size", "?")
    if "No Module" in size or "Not Installed" in size:
        continue
    mfr = m.get("Manufacturer", "").strip()
    part = m.get("Part Number", "").strip()
    clean_modules.append({
        "label":        f"Slot {slot}",
        "size":         size,
        "type":         m.get("Type", "?"),
        "speed":        m.get("Configured Memory Speed", m.get("Speed", "?")),
        "manufacturer": "" if mfr in ("Unknown", "Not Specified", "") else mfr,
        "part_number":  "" if part in ("Unknown", "Not Specified", "") else part,
    })
    slot += 1

print(json.dumps({
    "total_gb":     total_gb,
    "used_gb":      used_gb,
    "available_gb": available_gb,
    "cached_gb":    cached_gb,
    "buffers_gb":   buffers_gb,
    "free_gb":      free_gb,
    "percent":      percent,
    "swap_total_gb": swap_total_gb,
    "swap_used_gb":  swap_used_gb,
    "swap_percent":  swap_percent,
    "modules":      clean_modules,
}))
