#!/usr/bin/env python3
import subprocess
import json


def get_devices():
    try:
        default_sink = subprocess.run(
            ['pactl', 'get-default-sink'],
            capture_output=True, text=True
        ).stdout.strip()

        sinks = subprocess.run(
            ['pactl', 'list', 'sinks'],
            capture_output=True, text=True
        ).stdout

        devices = []
        current_name = None
        current_desc = None

        for line in sinks.split('\n'):
            stripped = line.strip()
            if stripped.startswith('Name:'):
                current_name = stripped[5:].strip()
                current_desc = None
            elif stripped.startswith('Description:') and current_name:
                current_desc = stripped[12:].strip()
                name = current_name
                desc = current_desc or current_name

                if 'bluez' in name or 'bluetooth' in name.lower():
                    icon = '󰂯'
                elif 'hdmi' in name.lower() or 'hdmi' in desc.lower():
                    icon = '󰡁'
                elif 'usb' in name.lower() or 'usb' in desc.lower():
                    icon = '󰓃'
                elif 'pci' in name.lower() or 'analog' in desc.lower():
                    icon = '󰋎'
                else:
                    icon = '󰓃'

                devices.append({
                    'name': name,
                    'desc': desc,
                    'icon': icon,
                    'default': name == default_sink
                })
                current_name = None

        print(json.dumps(devices))
    except Exception:
        print('[]')


get_devices()
