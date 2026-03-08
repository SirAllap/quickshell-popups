import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    // ── Theme (dynamic) ───────────────────────────────────────────────────────
    Theme { id: theme }
    readonly property color base:     theme.base
    readonly property color surface0: theme.surface0
    readonly property color surface1: theme.surface1
    readonly property color overlay0: theme.overlay0
    readonly property color subtext0: theme.subtext0
    readonly property color text:     theme.text
    readonly property color mauve:    theme.mauve
    readonly property color blue:     theme.blue
    readonly property color teal:     theme.teal
    readonly property color green:    theme.green
    readonly property color yellow:   theme.yellow
    readonly property color peach:    theme.peach
    readonly property color red:      theme.red

    readonly property string scriptsDir: Quickshell.env("HOME") + "/.config/quickshell/memory"

    property var memData: null

    function usageColor(pct) {
        if (pct >= 90) return red
        if (pct >= 75) return peach
        if (pct >= 55) return yellow
        return blue
    }

    // ── Data poller ───────────────────────────────────────────────────────────
    Process {
        id: poller
        command: ["python3", root.scriptsDir + "/mem_data.py"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let t = this.text.trim()
                if (t) try { root.memData = JSON.parse(t) } catch(e) {}
            }
        }
    }
    Timer { interval: 5000; running: true; repeat: true; onTriggered: poller.running = true }

    Process {
        id: clearCacheProc
        running: false
        command: ["python3", Quickshell.env("HOME") + "/.config/waybar/scripts/waybar-memory.py",
                  "--clear-cache"]
        onRunningChanged: if (!running) poller.running = true
    }

    // ── Intro animation ───────────────────────────────────────────────────────
    property real intro: 0.0
    Behavior on intro { NumberAnimation { duration: 550; easing.type: Easing.OutExpo } }
    Component.onCompleted: intro = 1.0

    Rectangle { anchors.fill: parent; color: base; radius: 8 }

    Item {
        anchors.fill: parent
        anchors.margins: 20
        scale:   0.92 + 0.08 * root.intro
        opacity: root.intro

        // ── Header ────────────────────────────────────────────────────────────
        Item {
            id: header
            anchors.top: parent.top
            anchors.left: parent.left; anchors.right: parent.right
            height: 46

            Row {
                anchors.verticalCenter: parent.verticalCenter; spacing: 10
                Text {
                    text: "\uf1c0"
                    font.family: "JetBrainsMono Nerd Font Mono"
                    font.pixelSize: 22
                    color: memData ? root.usageColor(memData.percent) : root.blue
                    Behavior on color { ColorAnimation { duration: 500 } }
                }
                Text {
                    text: "Memory"
                    font.pixelSize: 17; font.bold: true; color: root.text
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: memData
                          ? memData.total_gb.toFixed(1) + " GB"
                            + (memData.modules.length > 0 ? "  " + memData.modules[0].type : "")
                          : ""
                    font.pixelSize: 13; color: root.overlay0
                }
            }
            Rectangle {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                width: 80; height: 34; radius: 10; color: root.surface0
                Text {
                    anchors.centerIn: parent
                    text: memData ? memData.percent.toFixed(1) + "%" : "--"
                    font.pixelSize: 16; font.bold: true
                    color: memData ? root.usageColor(memData.percent) : root.blue
                    Behavior on color { ColorAnimation { duration: 500 } }
                }
            }
        }

        Rectangle {
            id: sep1
            anchors.top: header.bottom; anchors.topMargin: 10
            anchors.left: parent.left; anchors.right: parent.right
            height: 1; color: root.surface1
        }

        // ── Segmented usage bar ───────────────────────────────────────────────
        Rectangle {
            id: usageSection
            anchors.top: sep1.bottom; anchors.topMargin: 12
            anchors.left: parent.left; anchors.right: parent.right
            height: 100; color: root.surface0; radius: 8

            Column {
                anchors.fill: parent; anchors.margins: 14; spacing: 10

                // Stacked bar: [used][cached][buffers][free]
                Item {
                    id: barItem
                    width: parent.width; height: 20

                    // Pre-compute segment widths so x-bindings stay clean
                    property real usedW:   memData ? Math.max(0, width * memData.used_gb    / memData.total_gb) : 0
                    property real cachedW: memData ? Math.max(0, width * memData.cached_gb  / memData.total_gb) : 0
                    property real buffW:   memData ? Math.max(0, width * memData.buffers_gb / memData.total_gb) : 0

                    Rectangle {
                        anchors.fill: parent; radius: 10; color: root.surface1; clip: true

                        Rectangle {
                            x: 0; anchors.top: parent.top; anchors.bottom: parent.bottom
                            width: barItem.usedW; color: root.blue; opacity: 0.90; radius: 0
                            Behavior on width { NumberAnimation { duration: 600 } }
                        }
                        Rectangle {
                            x: barItem.usedW; anchors.top: parent.top; anchors.bottom: parent.bottom
                            width: barItem.cachedW; color: root.mauve; opacity: 0.65; radius: 0
                            Behavior on width { NumberAnimation { duration: 600 } }
                        }
                        Rectangle {
                            x: barItem.usedW + barItem.cachedW
                            anchors.top: parent.top; anchors.bottom: parent.bottom
                            width: barItem.buffW; color: root.teal; opacity: 0.60; radius: 0
                            Behavior on width { NumberAnimation { duration: 600 } }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: memData ? memData.percent.toFixed(0) + "%" : ""
                        font.pixelSize: 11; font.bold: true; color: root.text
                    }
                }

                // Legend
                Row {
                    spacing: 16
                    Repeater {
                        model: [
                            { dot: root.blue,     label: "Used",    value: memData ? memData.used_gb.toFixed(1)    + " GB" : "--" },
                            { dot: root.mauve,    label: "Cached",  value: memData ? memData.cached_gb.toFixed(1)  + " GB" : "--" },
                            { dot: root.teal,     label: "Buffers", value: memData ? memData.buffers_gb.toFixed(1) + " GB" : "--" },
                            { dot: root.surface1, label: "Free",    value: memData ? memData.free_gb.toFixed(1)    + " GB" : "--" },
                        ]
                        Row {
                            spacing: 5
                            Rectangle {
                                width: 8; height: 8; radius: 4; color: modelData.dot
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: modelData.label + ":  " + modelData.value
                                font.pixelSize: 12; color: root.subtext0
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }
            }
        }

        // ── Stats tiles ───────────────────────────────────────────────────────
        Item {
            id: statsRow
            anchors.top: usageSection.bottom; anchors.topMargin: 12
            anchors.left: parent.left; anchors.right: parent.right
            height: 82

            Row {
                anchors.fill: parent; spacing: 10
                Repeater {
                    model: [
                        { icon: "\uf1c0", label: "Total",
                          value: memData ? memData.total_gb.toFixed(1) + " GB" : "--",
                          color: root.blue },
                        { icon: "\uf0c7", label: "Used",
                          value: memData ? memData.used_gb.toFixed(1) + " GB" : "--",
                          color: memData ? root.usageColor(memData.percent) : root.blue },
                        { icon: "\uf00c", label: "Available",
                          value: memData ? memData.available_gb.toFixed(1) + " GB" : "--",
                          color: root.green },
                        { icon: "\uf187", label: "Swap",
                          value: memData
                                 ? memData.swap_used_gb.toFixed(1) + " / " + memData.swap_total_gb.toFixed(1) + " GB"
                                 : "--",
                          color: memData && memData.swap_percent > 50 ? root.peach : root.teal },
                    ]
                    Rectangle {
                        width: (statsRow.width - 30) / 4; height: 82
                        color: root.surface0; radius: 8
                        Column {
                            anchors.centerIn: parent; spacing: 4
                            Text { anchors.horizontalCenter: parent.horizontalCenter
                                   text: modelData.icon
                                   font.family: "JetBrainsMono Nerd Font Mono"
                                   font.pixelSize: 18; color: modelData.color }
                            Text { anchors.horizontalCenter: parent.horizontalCenter
                                   text: modelData.value
                                   font.pixelSize: 14; font.bold: true; color: root.text }
                            Text { anchors.horizontalCenter: parent.horizontalCenter
                                   text: modelData.label
                                   font.pixelSize: 11; color: root.overlay0 }
                        }
                    }
                }
            }
        }

        // ── DIMM modules ──────────────────────────────────────────────────────
        Rectangle {
            id: dimmSection
            anchors.top: statsRow.bottom; anchors.topMargin: 12
            anchors.left: parent.left; anchors.right: parent.right
            anchors.bottom: actionRow.top; anchors.bottomMargin: 12
            color: root.surface0; radius: 8

            Text {
                id: dimmLabel
                anchors.top: parent.top; anchors.left: parent.left; anchors.margins: 12
                text: "Memory Modules"
                font.pixelSize: 12; color: root.overlay0
            }

            Column {
                anchors.top: dimmLabel.bottom; anchors.topMargin: 8
                anchors.left: parent.left; anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 12; anchors.rightMargin: 12; anchors.bottomMargin: 10
                spacing: 8

                Repeater {
                    model: memData ? memData.modules : []
                    delegate: Rectangle {
                        width: parent.width; height: 40
                        color: root.surface1; radius: 8

                        Text {
                            id: dimmIcon
                            anchors.left: parent.left; anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: "\uf1c0"
                            font.family: "JetBrainsMono Nerd Font Mono"
                            font.pixelSize: 14; color: root.blue
                        }
                        Text {
                            id: dimmLabel
                            anchors.left: dimmIcon.right; anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.label
                            font.pixelSize: 13; color: root.overlay0
                            width: 50
                        }
                        Text {
                            id: dimmSize
                            anchors.left: dimmLabel.right; anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.size
                            font.pixelSize: 13; font.bold: true; color: root.blue
                            width: 52
                        }
                        Text {
                            anchors.left: dimmSize.right; anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.type + " @ " + modelData.speed
                            font.pixelSize: 13; color: root.subtext0
                        }
                        Text {
                            anchors.right: parent.right; anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.part_number
                            font.pixelSize: 11; color: root.overlay0
                        }
                    }
                }

                Text {
                    visible: !memData || !memData.modules || memData.modules.length === 0
                    text: "No module info (dmidecode requires sudo)"
                    font.pixelSize: 13; color: root.overlay0
                }
            }
        }

        // ── Action button ─────────────────────────────────────────────────────
        Item {
            id: actionRow
            anchors.bottom: parent.bottom
            anchors.left: parent.left; anchors.right: parent.right
            height: 50

            Rectangle {
                anchors.fill: parent
                radius: 8
                color: maClear.containsMouse ? Qt.lighter(root.surface0, 1.3) : root.surface0
                border.color: root.blue; border.width: 1
                Behavior on color { ColorAnimation { duration: 150 } }

                MouseArea {
                    id: maClear
                    anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: clearCacheProc.running = true
                }
                Row {
                    anchors.centerIn: parent; spacing: 8
                    Text {
                        text: "\uf0e2"
                        font.family: "JetBrainsMono Nerd Font Mono"
                        font.pixelSize: 15; color: root.blue
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "Clear RAM Cache"
                        font.pixelSize: 13; font.bold: true; color: root.text
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }
    }
}
