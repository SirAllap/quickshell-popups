#!/usr/bin/env python3
"""Outputs clean weather JSON for the Quickshell popup.
Reads from the Open-Meteo cache at ~/.cache/waybar_weather/data.json"""
import json, os
from datetime import datetime, timezone
from pathlib import Path

CACHE_FILE = Path.home() / ".cache/waybar_weather/data.json"

WEATHER_MAP = {
    # (nerd-font icon, description)
    0:  ("\ue30d", "Clear sky"),        1:  ("\ue30d", "Mainly clear"),
    2:  ("\ue302", "Partly cloudy"),    3:  ("\ue312", "Overcast"),
    45: ("\ue313", "Fog"),              48: ("\ue313", "Rime fog"),
    51: ("\ue319", "Light drizzle"),    53: ("\ue319", "Drizzle"),
    55: ("\ue319", "Dense drizzle"),    56: ("\ue317", "Freezing drizzle"),
    57: ("\ue317", "Dense fr. drizzle"),61: ("\ue318", "Slight rain"),
    63: ("\ue318", "Moderate rain"),    65: ("\ue318", "Heavy rain"),
    66: ("\ue317", "Freezing rain"),    67: ("\ue317", "Heavy fr. rain"),
    71: ("\ue31a", "Slight snow"),      73: ("\ue371", "Moderate snow"),
    75: ("\ue371", "Heavy snow"),       77: ("\ue371", "Snow grains"),
    80: ("\ue319", "Rain showers"),     81: ("\ue319", "Rain showers"),
    82: ("\ue31e", "Violent rain"),     85: ("\ue371", "Snow showers"),
    86: ("\ue371", "Heavy snow showers"),
    95: ("\ue31d", "Thunderstorm"),     96: ("\ue31f", "Storm + hail"),
    99: ("\ue31f", "Storm + hail"),
}

def w_icon(code): return WEATHER_MAP.get(int(code), ("", "Unknown"))[0]
def w_desc(code): return WEATHER_MAP.get(int(code), ("", "Unknown"))[1]

try:
    data = json.loads(CACHE_FILE.read_text())
    c = data["current"]
    h = data["hourly"]
    d = data["daily"]

    now = datetime.now(timezone.utc).astimezone()
    iso_hr = now.strftime("%Y-%m-%dT%H")
    start = next((i for i, t in enumerate(h["time"]) if t.startswith(iso_hr)), 0)

    hourly = [
        {
            "time":       h["time"][i][11:16],
            "temp":       round(float(h["temperature_2m"][i]), 1),
            "icon":       w_icon(h["weather_code"][i]),
            "precip_prob": int(h["precipitation_probability"][i]),
        }
        for i in range(start, min(start + 12, len(h["time"])))
    ]

    rain_probs = d.get("precipitation_probability_max", [0] * len(d["time"]))
    daily = [
        {
            "date":      datetime.fromisoformat(d["time"][i]).strftime("%a"),
            "full_date": d["time"][i],
            "temp_max":  round(float(d["temperature_2m_max"][i]), 1),
            "temp_min":  round(float(d["temperature_2m_min"][i]), 1),
            "icon":      w_icon(d["weather_code"][i]),
            "condition": w_desc(d["weather_code"][i]),
            "rain_prob": int(rain_probs[i]) if i < len(rain_probs) else 0,
        }
        for i in range(min(7, len(d["time"])))
    ]

    print(json.dumps({
        "city":    os.environ.get("WAYBAR_WEATHER_CITY", ""),
        "current": {
            "temp":       round(float(c["temperature_2m"]), 1),
            "feels_like": round(float(c["apparent_temperature"]), 1),
            "humidity":   int(c["relative_humidity_2m"]),
            "wind_speed": round(float(c["wind_speed_10m"]), 1),
            "wind_dir":   int(c["wind_direction_10m"]),
            "precip":     round(float(c.get("precipitation", 0)), 1),
            "icon":       w_icon(c["weather_code"]),
            "condition":  w_desc(c["weather_code"]),
        },
        "hourly":  hourly,
        "daily":   daily,
        "sunrise": d["sunrise"][0][11:16] if d.get("sunrise") else "N/A",
        "sunset":  d["sunset"][0][11:16] if d.get("sunset") else "N/A",
    }))

except Exception as e:
    import sys
    print(json.dumps({"error": str(e)}), file=sys.stderr)
    sys.exit(1)
