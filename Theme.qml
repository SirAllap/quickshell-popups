// Theme.qml — Dynamic omarchy theme bridge for Quickshell
// Reads ~/.config/omarchy/current/theme/colors.toml and exposes semantic color properties.
// Usage: add  import "../"  to any Popup, then  Theme { id: theme }
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    visible: false; implicitWidth: 0; implicitHeight: 0

    // ── Internal: raw key→hex map ─────────────────────────────────────────────
    property var _r: ({})

    function _parse(txt) {
        let r = {}
        txt.split("\n").forEach(function(line) {
            line = line.trim()
            let m = line.match(/^(\w+)\s*=\s*"(#[0-9a-fA-F]{6})"/)
            if (m) r[m[1]] = m[2]
        })
        root._r = r
    }

    Process {
        id: _reader
        command: ["cat", Quickshell.env("HOME") + "/.config/omarchy/current/theme/colors.toml"]
        stdout: StdioCollector { onStreamFinished: root._parse(this.text) }
    }
    Component.onCompleted: _reader.running = true

    // Re-read every 30s so theme switches are picked up automatically
    Timer { interval: 30000; repeat: true; running: true; onTriggered: _reader.running = true }

    // ── Structural (backgrounds & surfaces) ──────────────────────────────────
    // base    → background              (darkest bg)
    // mantle  → derived darker          (below-card tint)
    // crust   → derived darkest         (text on accent buttons)
    // surface0→ derived, just above base (card bg)
    // surface1→ color0 / normal black   (dividers, chips)
    // surface2→ derived lighter         (hover states)
    readonly property color base:     _r.background ?? "#121212"
    readonly property color mantle:   Qt.darker(base, 1.25)
    readonly property color crust:    Qt.darker(base, 1.6)
    readonly property color surface0: Qt.lighter(base, 1.7)
    readonly property color surface1: _r.color0    ?? "#333333"
    readonly property color surface2: Qt.lighter(surface1, 1.3)

    // ── Text & overlays ───────────────────────────────────────────────────────
    // text     → foreground
    // subtext0 → color7 / normal white  (secondary labels)
    // subtext1 → color15 / bright white (emphasis)
    // overlay0 → color8 / bright black  (muted labels)
    // overlay1 → derived lighter        (slightly less muted)
    readonly property color text:     _r.foreground ?? "#D4D4D4"
    readonly property color subtext0: _r.color7    ?? "#bebebe"
    readonly property color subtext1: _r.color15   ?? "#eaeaea"
    readonly property color overlay0: _r.color8    ?? "#8a8a8d"
    readonly property color overlay1: Qt.lighter(overlay0, 1.15)
    readonly property color overlay2: Qt.lighter(overlay0, 1.3)

    // ── Accent colors ─────────────────────────────────────────────────────────
    // Mapped to the closest vhs80 semantic equivalent.
    // Status gradient (cool→warm→hot):  teal → green → yellow → peach → red
    readonly property color teal:     _r.color6    ?? "#2F8383"  // normal cyan
    readonly property color sapphire: _r.color6    ?? "#2F8383"  // normal cyan  (cool pair with blue)
    readonly property color blue:     _r.color14   ?? "#46BEBE"  // bright cyan  (brighter pair)
    readonly property color green:    _r.color10   ?? "#5BB775"  // bright green
    readonly property color yellow:   _r.color11   ?? "#E07924"  // bright yellow
    readonly property color peach:    _r.color3    ?? "#A85511"  // orange (normal yellow in vhs80)
    readonly property color maroon:   _r.color1    ?? "#862020"  // normal red   (dark warning)
    readonly property color red:      _r.color9    ?? "#C73838"  // bright red   (danger)
    readonly property color mauve:    _r.color5    ?? "#932A37"  // normal magenta (warm pair)
    readonly property color pink:     _r.color13   ?? "#C73838"  // bright magenta (brighter warm pair)
    readonly property color lavender: _r.color12   ?? "#C6B441"  // bright blue/olive
    readonly property color accent:   _r.accent    ?? "#862020"
}
