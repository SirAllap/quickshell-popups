#!/usr/bin/env bash
# Tooltip status for the network/bluetooth popup button.
# Uses --rescan no so it never blocks.

eth_line=""
bt_lines=""
button_icon="󱛇"

# --- Ethernet / Active interface ---
IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')
if ip link show "$IFACE" 2>/dev/null | grep -q "state UP"; then
    ip_addr=$(ip -4 addr show dev "$IFACE" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1)
    speed=$(cat /sys/class/net/"$IFACE"/speed 2>/dev/null)
    [[ -n "$ip_addr" ]] || ip_addr="No IP"
    [[ -n "$speed" && "$speed" -gt 0 ]] 2>/dev/null && speed_str="${speed} Mbps" || speed_str="Unknown"
    case "$IFACE" in
        en*|eth*)
            eth_line="󰈀  ${ip_addr} (${speed_str})"
            button_icon="󰈀"
            ;;
        wl*)
            eth_line="󰤨  ${ip_addr} (${speed_str})"
            button_icon="󰤨"
            ;;
        *)
            eth_line="󰈀  ${ip_addr} (${speed_str})"
            button_icon="󰈀"
            ;;
    esac
else
    eth_line="󰈂  Disconnected"
fi

# --- Bluetooth ---
bt_powered=$(bluetoothctl show 2>/dev/null | grep -c "Powered: yes")
if [[ "$bt_powered" -eq 0 ]]; then
    bt_lines="󰂲  Bluetooth off"
else
    mapfile -t connected < <(bluetoothctl devices Connected 2>/dev/null | grep "^Device ")
    if [[ ${#connected[@]} -gt 0 ]]; then
        for line in "${connected[@]}"; do
            name=$(echo "$line" | cut -d ' ' -f 3-)
            bt_lines+="󰂱  ${name}\n"
        done
        bt_lines="${bt_lines%\\n}"  # trim trailing \n
    else
        bt_lines="󰂯  Bluetooth on"
    fi
fi

tooltip="${eth_line}\n${bt_lines}"
# Waybar expects literal \n in tooltip for newlines
printf '{"text":"%s","tooltip":"%s"}\n' "$button_icon" "$(printf '%s' "$tooltip" | sed 's/"/\\"/g')"
