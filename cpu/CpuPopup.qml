import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root

    // ── Theme (dynamic — reads ~/.config/omarchy/current/theme/colors.toml) ──
    Theme { id: theme }
    readonly property color base:     theme.base
    readonly property color surface0: theme.surface0
    readonly property color surface1: theme.surface1
    readonly property color overlay0: theme.overlay0
    readonly property color subtext0: theme.subtext0
    readonly property color text:     theme.text
    readonly property color mauve:    theme.mauve
    readonly property color blue:     theme.blue
    readonly property color sapphire: theme.sapphire
    readonly property color teal:     theme.teal
    readonly property color green:    theme.green
    readonly property color yellow:   theme.yellow
    readonly property color peach:    theme.peach
    readonly property color maroon:   theme.maroon
    readonly property color red:      theme.red

    readonly property string scriptsDir: Quickshell.env("HOME") + "/.config/quickshell/cpu"

    property var cpuData: null

    function tempColor(t) {
        if (t >= 85) return red
        if (t >= 75) return peach
        if (t >= 65) return yellow
        if (t >= 50) return green
        return teal
    }
    function coreColor(pct) {
        if (pct >= 90) return red
        if (pct >= 75) return maroon
        if (pct >= 55) return peach
        if (pct >= 35) return yellow
        if (pct >= 15) return green
        return teal
    }
    function usageColor(pct) {
        if (pct >= 85) return red
        if (pct >= 60) return peach
        if (pct >= 40) return yellow
        return blue
    }

    // ── Data poller ───────────────────────────────────────────────────────────
    Process {
        id: poller
        command: ["python3", root.scriptsDir + "/cpu_data.py"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let t = this.text.trim()
                if (t) try { root.cpuData = JSON.parse(t) } catch(e) {}
            }
        }
    }
    Timer { interval: 3000; running: true; repeat: true; onTriggered: poller.running = true }

    // ── Action processes ──────────────────────────────────────────────────────
    Process {
        id: btopProc
        running: false
        command: ["bash", "-c", "xdg-terminal-exec btop &"]
    }
    Process {
        id: killZombiesProc
        running: false
        command: ["bash", "-c",
            "ps -eo pid,ppid,stat | awk '$3~/^Z/{print $2}' | sort -u | xargs -r kill -SIGCHLD 2>/dev/null; true"]
    }
    Process {
        id: fanToggleProc
        running: false
        command: ["python3", Quickshell.env("HOME") + "/.config/waybar/scripts/waybar-cpu.py",
                  "--toggle-fan-profile"]
    }
    Timer { id: refetchTimer; interval: 400; repeat: false; onTriggered: poller.running = true }

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
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                Text {
                    text: "\uf2db"
                    font.family: "JetBrainsMono Nerd Font Mono"
                    font.pixelSize: 22
                    color: cpuData ? root.usageColor(cpuData.percent) : root.mauve
                    Behavior on color { ColorAnimation { duration: 500 } }
                }
                Text {
                    text: cpuData ? cpuData.cpu_name : "CPU"
                    font.pixelSize: 17; font.bold: true; color: root.text
                    width: parent.parent.width - 160
                    elide: Text.ElideRight
                }
            }
            Rectangle {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                width: 80; height: 34; radius: 10; color: root.surface0
                Text {
                    anchors.centerIn: parent
                    text: cpuData ? cpuData.percent.toFixed(1) + "%" : "--"
                    font.pixelSize: 16; font.bold: true
                    color: cpuData ? root.usageColor(cpuData.percent) : root.mauve
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

        // ── Stats tiles ───────────────────────────────────────────────────────
        Item {
            id: statsRow
            anchors.top: sep1.bottom; anchors.topMargin: 10
            anchors.left: parent.left; anchors.right: parent.right
            height: 82

            Row {
                anchors.fill: parent; spacing: 10
                Repeater {
                    model: [
                        { icon: "\uf2c7", label: "Temp",
                          value: cpuData ? cpuData.temp + "°C" : "--",
                          color: cpuData ? root.tempColor(cpuData.temp) : root.mauve },
                        { icon: "",     label: "Frequency",
                          value: cpuData ? cpuData.freq_ghz.toFixed(2) + " GHz" : "--",
                          color: root.blue },
                        { icon: "\uf0e7", label: "Power",
                          value: cpuData ? cpuData.power_w.toFixed(1) + " W" : "--",
                          color: root.yellow },
                        { icon: "\uf021", label: "Fan",
                          value: cpuData ? cpuData.fan_rpm + " RPM  " + cpuData.fan_percent + "%" : "--",
                          color: root.sapphire },
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

        // ── Per-core grid ─────────────────────────────────────────────────────
        Rectangle {
            id: coreSection
            anchors.top: statsRow.bottom; anchors.topMargin: 12
            anchors.left: parent.left; anchors.right: parent.right
            height: 200
            color: root.surface0; radius: 8

            Text {
                id: coreLabel
                anchors.top: parent.top; anchors.left: parent.left; anchors.margins: 12
                text: cpuData
                      ? "Per-Core Utilization  ·  " + cpuData.core_count + " logical  ·  "
                        + cpuData.freq_ghz.toFixed(2) + " / " + cpuData.max_freq_ghz.toFixed(2) + " GHz"
                      : "Per-Core Utilization"
                font.pixelSize: 12; color: root.overlay0
            }

            Item {
                id: coreGrid
                anchors.top: coreLabel.bottom; anchors.topMargin: 8
                anchors.left: parent.left; anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 12; anchors.rightMargin: 12; anchors.bottomMargin: 12

                property int numCores: cpuData ? cpuData.per_core.length : 12
                property int cols: numCores > 16 ? 8 : (numCores > 8 ? 6 : numCores)
                property int rowCount: Math.ceil(numCores / cols)
                property real gap: 8
                property real cellW: cols     > 0 ? (width  - (cols     - 1) * gap) / cols     : 100
                property real cellH: rowCount > 0 ? (height - (rowCount - 1) * gap) / rowCount : 60

                Repeater {
                    model: cpuData ? cpuData.per_core.length : 0
                    delegate: Item {
                        id: coreCell
                        property real pct: cpuData ? cpuData.per_core[index] : 0
                        property color cc: root.coreColor(pct)
                        property int colIdx: index % coreGrid.cols
                        property int rowIdx: Math.floor(index / coreGrid.cols)

                        x: colIdx * (coreGrid.cellW + coreGrid.gap)
                        y: rowIdx * (coreGrid.cellH + coreGrid.gap)
                        width: coreGrid.cellW
                        height: coreGrid.cellH

                        Rectangle {
                            anchors.fill: parent
                            radius: 8
                            color: Qt.rgba(coreCell.cc.r, coreCell.cc.g, coreCell.cc.b, 0.10)
                            border.color: Qt.rgba(coreCell.cc.r, coreCell.cc.g, coreCell.cc.b, 0.35)
                            border.width: 1

                            // Animated fill from bottom
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left; anchors.right: parent.right
                                anchors.margins: 2
                                height: Math.max(2, (parent.height - 4) * coreCell.pct / 100)
                                radius: 6
                                color: Qt.rgba(coreCell.cc.r, coreCell.cc.g, coreCell.cc.b, 0.60)
                                Behavior on height { NumberAnimation { duration: 500 } }
                            }

                            // Core index (top-left, small)
                            Text {
                                anchors.top: parent.top; anchors.left: parent.left
                                anchors.topMargin: 4; anchors.leftMargin: 5
                                text: "C" + index
                                font.pixelSize: 8
                                color: Qt.rgba(coreCell.cc.r, coreCell.cc.g, coreCell.cc.b, 0.80)
                                z: 1
                            }

                            // Percentage (center)
                            Text {
                                anchors.centerIn: parent
                                text: coreCell.pct.toFixed(0) + "%"
                                font.pixelSize: 17; font.bold: true
                                color: root.text
                                z: 1
                            }
                        }
                    }
                }
            }
        }

        // ── Top processes ──────────────────────────────────────────────────────
        Rectangle {
            id: procSection
            anchors.top: coreSection.bottom; anchors.topMargin: 12
            anchors.left: parent.left; anchors.right: parent.right
            anchors.bottom: actionRow.top; anchors.bottomMargin: 12
            color: root.surface0; radius: 8

            Text {
                id: procSectionLabel
                anchors.top: parent.top; anchors.left: parent.left; anchors.margins: 12
                text: "Top Processes"
                font.pixelSize: 12; color: root.overlay0
            }

            Flickable {
                anchors.top: procSectionLabel.bottom; anchors.topMargin: 8
                anchors.left: parent.left; anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 12; anchors.rightMargin: 12; anchors.bottomMargin: 10
                contentHeight: cpuProcColumn.height
                clip: true

                Column {
                    id: cpuProcColumn
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: cpuData ? cpuData.top_procs : []
                        delegate: Item {
                            width: parent.width; height: 24
                            Text {
                                id: procName
                                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                text: modelData.name
                                font.pixelSize: 13; color: root.text
                                width: 200; elide: Text.ElideRight
                            }
                            Rectangle {
                                anchors.left: procName.right; anchors.leftMargin: 10
                                anchors.right: procPct.left; anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                height: 8; radius: 4; color: root.surface1
                                Rectangle {
                                    anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                                    width: Math.max(8, parent.width * Math.min(modelData.pct, 100) / 100)
                                    color: root.usageColor(modelData.pct)
                                    radius: 4; opacity: 0.85
                                    Behavior on width { NumberAnimation { duration: 400 } }
                                }
                            }
                            Text {
                                id: procPct
                                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                text: modelData.pct.toFixed(1) + "%"
                                font.pixelSize: 13; font.bold: true
                                color: root.usageColor(modelData.pct)
                                width: 55; horizontalAlignment: Text.AlignRight
                            }
                        }
                    }

                    Text {
                        visible: !cpuData || !cpuData.top_procs || cpuData.top_procs.length === 0
                        text: "No high-CPU processes detected"
                        font.pixelSize: 13; color: root.overlay0
                    }
                }
            }
        }

        // ── Action buttons ────────────────────────────────────────────────────
        Item {
            id: actionRow
            anchors.bottom: parent.bottom
            anchors.left: parent.left; anchors.right: parent.right
            height: 50

            Row {
                anchors.fill: parent; spacing: 10

                // ── Open btop ─────────────────────────────────────────────────
                Rectangle {
                    width: (actionRow.width - 20) / 3; height: 50
                    radius: 8
                    color: maBtop.containsMouse ? Qt.lighter(root.surface0, 1.3) : root.surface0
                    border.color: root.blue; border.width: 1
                    Behavior on color { ColorAnimation { duration: 150 } }

                    MouseArea {
                        id: maBtop
                        anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: btopProc.running = true
                    }
                    Row {
                        anchors.centerIn: parent; spacing: 8
                        Text {
                            text: "\uf120"
                            font.family: "JetBrainsMono Nerd Font Mono"
                            font.pixelSize: 15; color: root.blue
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: "Open btop"
                            font.pixelSize: 13; font.bold: true; color: root.text
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                // ── Kill Zombies ───────────────────────────────────────────────
                Rectangle {
                    width: (actionRow.width - 20) / 3; height: 50
                    radius: 8
                    color: maZombie.containsMouse ? Qt.lighter(root.surface0, 1.3) : root.surface0
                    border.color: (cpuData && cpuData.zombie_count > 0) ? root.red : root.overlay0
                    border.width: 1
                    Behavior on color  { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 300 } }

                    MouseArea {
                        id: maZombie
                        anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            killZombiesProc.running = true
                            refetchTimer.restart()
                        }
                    }
                    Row {
                        anchors.centerIn: parent; spacing: 8
                        Text {
                            text: "\uf188"
                            font.family: "JetBrainsMono Nerd Font Mono"
                            font.pixelSize: 15
                            color: (cpuData && cpuData.zombie_count > 0) ? root.red : root.overlay0
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on color { ColorAnimation { duration: 300 } }
                        }
                        Text {
                            text: "Kill Zombies"
                            font.pixelSize: 13; font.bold: true; color: root.text
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Rectangle {
                            visible: cpuData !== null && cpuData.zombie_count > 0
                            width: 22; height: 22; radius: 11; color: root.red
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                anchors.centerIn: parent
                                text: cpuData ? cpuData.zombie_count.toString() : "0"
                                font.pixelSize: 11; font.bold: true; color: root.base
                            }
                        }
                    }
                }

                // ── Fan profile toggle ─────────────────────────────────────────
                Rectangle {
                    width: (actionRow.width - 20) / 3; height: 50
                    radius: 8
                    color: maFan.containsMouse ? Qt.lighter(root.surface0, 1.3) : root.surface0
                    border.color: (cpuData && cpuData.fan_profile === "gaming") ? root.green : root.sapphire
                    border.width: 1
                    Behavior on color  { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 300 } }

                    MouseArea {
                        id: maFan
                        anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            fanToggleProc.running = true
                            refetchTimer.restart()
                        }
                    }
                    Row {
                        anchors.centerIn: parent; spacing: 8
                        Text {
                            text: "\uf021"
                            font.family: "JetBrainsMono Nerd Font Mono"
                            font.pixelSize: 15
                            color: (cpuData && cpuData.fan_profile === "gaming") ? root.green : root.sapphire
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on color { ColorAnimation { duration: 300 } }
                        }
                        Text {
                            text: "Fan: " + (cpuData
                                  ? (cpuData.fan_profile === "gaming" ? "Gaming" : "Desktop")
                                  : "Desktop")
                            font.pixelSize: 13; font.bold: true; color: root.text
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }
        }
    }
}
