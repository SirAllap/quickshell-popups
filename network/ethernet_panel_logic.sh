#!/usr/bin/env bash

IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')

# Check if interface exists and is up
if [[ -z "$IFACE" ]] || ! ip link show "$IFACE" &>/dev/null; then
    echo '{"power":"off","connected":null,"networks":[]}'
    exit 0
fi

STATE=$(ip link show "$IFACE" | grep -c "state UP")
if [[ "$STATE" -eq 0 ]]; then
    echo '{"power":"off","connected":null,"networks":[]}'
    exit 0
fi

# Get IP address
IP=$(ip -4 addr show dev "$IFACE" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1)
[ -z "$IP" ] && IP="No IP"

# Get link speed
SPEED=$(cat /sys/class/net/"$IFACE"/speed 2>/dev/null)
if [[ -n "$SPEED" && "$SPEED" -gt 0 ]] 2>/dev/null; then
    FREQ="${SPEED} Mbps"
else
    FREQ="Unknown"
fi

CONNECTED_JSON=$(jq -n \
    --arg id "Ethernet" \
    --arg ssid "Ethernet" \
    --arg icon "󰈀" \
    --arg signal "100" \
    --arg security "Wired" \
    --arg ip "$IP" \
    --arg freq "$FREQ" \
    '{id: $id, ssid: $ssid, icon: $icon, signal: $signal, security: $security, ip: $ip, freq: $freq}')

jq -n \
    --arg power "on" \
    --argjson connected "$CONNECTED_JSON" \
    --argjson networks '[]' \
    '{power: $power, connected: $connected, networks: $networks}'
