#!/usr/bin/env python3
"""Outputs weather JSON in the format expected by CalendarPopup.qml.
Reads from the Open-Meteo cache at ~/.cache/waybar_weather/data.json"""
import json, re
from datetime import datetime, timezone
from pathlib import Path

CACHE_FILE = Path.home() / ".cache/waybar_weather/data.json"
THEME_FILE = Path.home() / ".config/omarchy/current/theme/colors.toml"

def load_theme():
    """Parse colors.toml and return a dict of key -> #hex."""
    t = {}
    try:
        for line in THEME_FILE.read_text().splitlines():
            m = re.match(r'^(\w+)\s*=\s*"(#[0-9a-fA-F]{6})"', line.strip())
            if m:
                t[m.group(1)] = m.group(2)
    except Exception:
        pass
    return t

_t = load_theme()
# Semantic slots — same logic as Theme.qml
C_SUNNY  = _t.get("color11", "#E07924")  # bright yellow  — clear/sunny
C_CLOUDY = _t.get("color8",  "#8a8a8d")  # bright black   — clouds/fog
C_RAIN   = _t.get("color6",  "#2F8383")  # normal cyan    — rain/drizzle
C_SNOW   = _t.get("color7",  "#bebebe")  # normal white   — snow
C_SEVERE = _t.get("color9",  "#C73838")  # bright red     — storms

# WMO code -> (nerd_font_icon, hex_color, description)
WEATHER_MAP = {
    0:  ("\ue30d", C_SUNNY,  "Clear Sky"),
    1:  ("\ue30d", C_SUNNY,  "Mainly Clear"),
    2:  ("\ue302", C_CLOUDY, "Partly Cloudy"),
    3:  ("\ue312", C_CLOUDY, "Overcast"),
    45: ("\ue313", C_CLOUDY, "Fog"),
    48: ("\ue313", C_CLOUDY, "Rime Fog"),
    51: ("\ue319", C_RAIN,   "Light Drizzle"),
    53: ("\ue319", C_RAIN,   "Drizzle"),
    55: ("\ue319", C_RAIN,   "Dense Drizzle"),
    56: ("\ue317", C_RAIN,   "Freezing Drizzle"),
    57: ("\ue317", C_RAIN,   "Dense Fr. Drizzle"),
    61: ("\ue318", C_RAIN,   "Slight Rain"),
    63: ("\ue318", C_RAIN,   "Moderate Rain"),
    65: ("\ue318", C_RAIN,   "Heavy Rain"),
    66: ("\ue317", C_RAIN,   "Freezing Rain"),
    67: ("\ue317", C_RAIN,   "Heavy Fr. Rain"),
    71: ("\ue31a", C_SNOW,   "Slight Snow"),
    73: ("\ue371", C_SNOW,   "Moderate Snow"),
    75: ("\ue371", C_SNOW,   "Heavy Snow"),
    77: ("\ue371", C_SNOW,   "Snow Grains"),
    80: ("\ue319", C_RAIN,   "Rain Showers"),
    81: ("\ue319", C_RAIN,   "Rain Showers"),
    82: ("\ue31e", C_SEVERE, "Violent Rain"),
    85: ("\ue371", C_SNOW,   "Snow Showers"),
    86: ("\ue371", C_SNOW,   "Heavy Snow Showers"),
    95: ("\ue31d", C_SEVERE, "Thunderstorm"),
    96: ("\ue31f", C_SEVERE, "Storm + Hail"),
    99: ("\ue31f", C_SEVERE, "Storm + Hail"),
}

def w_info(code):
    return WEATHER_MAP.get(int(code), ("\ue312", C_CLOUDY, "Unknown"))

try:
    data = json.loads(CACHE_FILE.read_text())
    c = data["current"]
    h = data["hourly"]
    d = data["daily"]

    now = datetime.now(timezone.utc).astimezone()
    current_hour_str = now.strftime("%Y-%m-%dT%H")

    rain_probs = d.get("precipitation_probability_max", [0] * len(d["time"]))
    wind_max   = d.get("wind_speed_10m_max", [0] * len(d["time"]))

    forecast = []
    for day_idx in range(min(5, len(d["time"]))):
        day_str  = d["time"][day_idx]           # "2026-03-08"
        day_date = datetime.fromisoformat(day_str)
        day_code = d["weather_code"][day_idx]
        icon, hex_color, desc = w_info(day_code)

        # Hourly slots for this day (up to 8)
        hourly = []
        for i, t in enumerate(h["time"]):
            if not t.startswith(day_str):
                continue
            # For today, only show from current hour forward
            if day_idx == 0 and not t.startswith(current_hour_str) and t < (now.strftime("%Y-%m-%dT%H") + ":00"):
                continue
            hi_code = h["weather_code"][i]
            hi_icon, hi_hex, _ = w_info(hi_code)
            hourly.append({
                "time": t[11:16],
                "temp": str(round(float(h["temperature_2m"][i]), 1)),
                "icon": hi_icon,
                "hex":  hi_hex,
            })
            if len(hourly) >= 8:
                break

        feels = str(round(float(c["apparent_temperature"]), 1)) if day_idx == 0 else str(round(float(d["temperature_2m_max"][day_idx]), 1))
        wind  = str(round(float(c["wind_speed_10m"])))          if day_idx == 0 else str(round(float(wind_max[day_idx]) if day_idx < len(wind_max) else 0))
        hum   = str(int(c["relative_humidity_2m"]))             if day_idx == 0 else "—"

        forecast.append({
            "id":        str(day_idx),
            "day":       day_date.strftime("%a"),
            "day_full":  day_date.strftime("%A"),
            "date":      day_date.strftime("%d %b"),
            "max":       str(round(float(d["temperature_2m_max"][day_idx]), 1)),
            "min":       str(round(float(d["temperature_2m_min"][day_idx]), 1)),
            "feels_like": feels,
            "wind":      wind,
            "humidity":  hum,
            "pop":       str(int(rain_probs[day_idx]) if day_idx < len(rain_probs) else 0),
            "icon":      icon,
            "hex":       hex_color,
            "desc":      desc,
            "hourly":    hourly,
        })

    print(json.dumps({"forecast": forecast}))

except Exception as e:
    import sys
    print(json.dumps({"error": str(e)}), file=sys.stderr)
    sys.exit(1)
