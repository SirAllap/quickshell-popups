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
    readonly property color red:      theme.red

    readonly property string scriptsDir: Quickshell.env("HOME") + "/.config/quickshell/gpu"

    property var gpuData: null

    function tempColor(t) {
        if (t >= 85) return red
        if (t >= 75) return peach
        if (t >= 65) return yellow
        if (t >= 50) return green
        return teal
    }
    function loadColor(pct) {
        if (pct >= 85) return red
        if (pct >= 65) return peach
        if (pct >= 45) return yellow
        return blue
    }

    // ── Data poller ───────────────────────────────────────────────────────────
    Process {
        id: poller
        command: ["python3", root.scriptsDir + "/gpu_data.py"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let t = this.text.trim()
                if (t) try { root.gpuData = JSON.parse(t) } catch(e) {}
            }
        }
    }
    Timer { interval: 3000; running: true; repeat: true; onTriggered: poller.running = true }

    Process {
        id: corectrlProc
        running: false
        command: ["bash", "-c", "corectrl &"]
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
                    text: "\uf1b2"
                    font.family: "JetBrainsMono Nerd Font Mono"
                    font.pixelSize: 22
                    color: gpuData ? root.tempColor(gpuData.temperature) : root.yellow
                    Behavior on color { ColorAnimation { duration: 500 } }
                }
                Text {
                    text: gpuData ? gpuData.name : "GPU"
                    font.pixelSize: 17; font.bold: true; color: root.text
                    width: parent.parent.width - 160; elide: Text.ElideRight
                }
            }
            Rectangle {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                width: 80; height: 34; radius: 10; color: root.surface0
                Text {
                    anchors.centerIn: parent
                    text: gpuData ? gpuData.utilization + "%" : "--"
                    font.pixelSize: 16; font.bold: true
                    color: gpuData ? root.loadColor(gpuData.utilization) : root.mauve
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
                          value: gpuData ? gpuData.temperature + "°C" : "--",
                          color: gpuData ? root.tempColor(gpuData.temperature) : root.mauve },
                        { icon: "\uf080", label: "Utilization",
                          value: gpuData ? gpuData.utilization + "%" : "--",
                          color: gpuData ? root.loadColor(gpuData.utilization) : root.blue },
                        { icon: "\uf0e7", label: "Power",
                          value: gpuData ? gpuData.power_draw.toFixed(0) + " W" : "--",
                          color: root.yellow },
                        { icon: "\uf021", label: "Fan",
                          value: gpuData ? gpuData.fan_rpm + " RPM" : "--",
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
                                   font.pixelSize: 15; font.bold: true; color: root.text }
                            Text { anchors.horizontalCenter: parent.horizontalCenter
                                   text: modelData.label
                                   font.pixelSize: 11; color: root.overlay0 }
                        }
                    }
                }
            }
        }

        // ── Metrics card (VRAM + Utilization + Power) ─────────────────────────
        Rectangle {
            id: metricsCard
            anchors.top: statsRow.bottom; anchors.topMargin: 12
            anchors.left: parent.left; anchors.right: parent.right
            height: 170
            color: root.surface0; radius: 8

            Column {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                // ── VRAM ──────────────────────────────────────────────────────
                Item {
                    width: parent.width; height: 38

                    Item {
                        id: vramLabelRow
                        width: parent.width; height: 18

                        Row {
                            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                            spacing: 6
                            Text { text: "\uf1c0"
                                   font.family: "JetBrainsMono Nerd Font Mono"
                                   font.pixelSize: 13
                                   color: gpuData ? root.loadColor(gpuData.vram_percent) : root.blue }
                            Text { text: "VRAM"; font.pixelSize: 12; color: root.overlay0 }
                        }
                        Text {
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            text: gpuData
                                  ? (gpuData.vram_used_mb >= 1024
                                     ? (gpuData.vram_used_mb / 1024).toFixed(1) + " / "
                                       + (gpuData.vram_total_mb / 1024).toFixed(0) + " GB"
                                     : gpuData.vram_used_mb + " / " + gpuData.vram_total_mb + " MB")
                                  : "--"
                            font.pixelSize: 12; font.bold: true
                            color: gpuData ? root.loadColor(gpuData.vram_percent) : root.blue
                        }
                    }
                    Rectangle {
                        anchors.top: vramLabelRow.bottom; anchors.topMargin: 4
                        anchors.left: parent.left; anchors.right: parent.right
                        height: 16; radius: 8; color: root.surface1
                        Rectangle {
                            anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                            width: gpuData ? Math.max(12, parent.width * gpuData.vram_percent / 100) : 0
                            radius: 8; opacity: 0.85
                            color: gpuData ? root.loadColor(gpuData.vram_percent) : root.blue
                            Behavior on width { NumberAnimation { duration: 500 } }
                        }
                        Text {
                            anchors.right: parent.right; anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: gpuData ? gpuData.vram_percent.toFixed(0) + "%" : ""
                            font.pixelSize: 9; font.bold: true; color: root.text
                            visible: gpuData && gpuData.vram_percent > 15
                        }
                    }
                }

                // ── Utilization ───────────────────────────────────────────────
                Item {
                    width: parent.width; height: 38

                    Item {
                        id: utilLabelRow
                        width: parent.width; height: 18

                        Row {
                            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                            spacing: 6
                            Text { text: "\uf080"
                                   font.family: "JetBrainsMono Nerd Font Mono"
                                   font.pixelSize: 13
                                   color: gpuData ? root.loadColor(gpuData.utilization) : root.blue }
                            Text { text: "Utilization"; font.pixelSize: 12; color: root.overlay0 }
                        }
                        Text {
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            text: gpuData ? gpuData.utilization + "%" : "--"
                            font.pixelSize: 12; font.bold: true
                            color: gpuData ? root.loadColor(gpuData.utilization) : root.blue
                        }
                    }
                    Rectangle {
                        anchors.top: utilLabelRow.bottom; anchors.topMargin: 4
                        anchors.left: parent.left; anchors.right: parent.right
                        height: 16; radius: 8; color: root.surface1
                        Rectangle {
                            anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                            width: gpuData ? Math.max(12, parent.width * gpuData.utilization / 100) : 0
                            radius: 8; opacity: 0.85
                            color: gpuData ? root.loadColor(gpuData.utilization) : root.blue
                            Behavior on width { NumberAnimation { duration: 500 } }
                        }
                        Text {
                            anchors.right: parent.right; anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: gpuData ? gpuData.utilization + "%" : ""
                            font.pixelSize: 9; font.bold: true; color: root.text
                            visible: gpuData && gpuData.utilization > 15
                        }
                    }
                }

                // ── Power ─────────────────────────────────────────────────────
                Item {
                    width: parent.width; height: 38

                    Item {
                        id: powerLabelRow
                        width: parent.width; height: 18

                        Row {
                            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                            spacing: 6
                            Text { text: "\uf0e7"
                                   font.family: "JetBrainsMono Nerd Font Mono"
                                   font.pixelSize: 13
                                   color: gpuData ? root.loadColor(gpuData.power_percent) : root.yellow }
                            Text { text: "Power"; font.pixelSize: 12; color: root.overlay0 }
                        }
                        Text {
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            text: gpuData
                                  ? gpuData.power_draw.toFixed(0) + " / " + gpuData.power_limit.toFixed(0) + " W"
                                  : "--"
                            font.pixelSize: 12; font.bold: true
                            color: gpuData ? root.loadColor(gpuData.power_percent) : root.yellow
                        }
                    }
                    Rectangle {
                        anchors.top: powerLabelRow.bottom; anchors.topMargin: 4
                        anchors.left: parent.left; anchors.right: parent.right
                        height: 16; radius: 8; color: root.surface1
                        Rectangle {
                            anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                            width: gpuData ? Math.max(12, parent.width * gpuData.power_percent / 100) : 0
                            radius: 8; opacity: 0.85
                            color: gpuData ? root.loadColor(gpuData.power_percent) : root.yellow
                            Behavior on width { NumberAnimation { duration: 500 } }
                        }
                        Text {
                            anchors.right: parent.right; anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: gpuData ? gpuData.power_percent.toFixed(0) + "%" : ""
                            font.pixelSize: 9; font.bold: true; color: root.text
                            visible: gpuData && gpuData.power_percent > 15
                        }
                    }
                }
            }
        }

        // ── GPU Processes ─────────────────────────────────────────────────────
        Rectangle {
            id: procSection
            anchors.top: metricsCard.bottom; anchors.topMargin: 12
            anchors.left: parent.left; anchors.right: parent.right
            anchors.bottom: actionRow.top; anchors.bottomMargin: 12
            color: root.surface0; radius: 8

            Text {
                id: procLabel
                anchors.top: parent.top; anchors.left: parent.left; anchors.margins: 12
                text: "GPU Processes"
                font.pixelSize: 12; color: root.overlay0
            }

            Flickable {
                anchors.top: procLabel.bottom; anchors.topMargin: 8
                anchors.left: parent.left; anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 12; anchors.rightMargin: 12; anchors.bottomMargin: 10
                contentHeight: procColumn.height
                clip: true

                Column {
                    id: procColumn
                    width: parent.width
                    spacing: 5

                    Repeater {
                        model: gpuData ? gpuData.processes : []
                        delegate: Item {
                            width: parent.width; height: 22

                            Text {
                                id: gProcName
                                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                text: modelData.name
                                font.pixelSize: 13; color: root.text
                                width: 200; elide: Text.ElideRight
                            }
                            Rectangle {
                                anchors.left: gProcName.right; anchors.leftMargin: 10
                                anchors.right: gProcMem.left; anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                height: 8; radius: 4; color: root.surface1
                                Rectangle {
                                    anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                                    width: Math.max(6, parent.width * Math.min(modelData.vram_mb / (gpuData ? gpuData.vram_total_mb : 16384), 1))
                                    color: root.mauve; radius: 4; opacity: 0.75
                                    Behavior on width { NumberAnimation { duration: 400 } }
                                }
                            }
                            Text {
                                id: gProcMem
                                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                text: modelData.vram_mb >= 1024
                                      ? (modelData.vram_mb / 1024).toFixed(1) + " GB"
                                      : modelData.vram_mb + " MB"
                                font.pixelSize: 13; font.bold: true; color: root.mauve
                                width: 65; horizontalAlignment: Text.AlignRight
                            }
                        }
                    }

                    Text {
                        visible: !gpuData || !gpuData.processes || gpuData.processes.length === 0
                        text: "No GPU processes detected"
                        font.pixelSize: 13; color: root.overlay0
                    }
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
                color: maCorectrl.containsMouse ? Qt.lighter(root.surface0, 1.3) : root.surface0
                border.color: root.mauve; border.width: 1
                Behavior on color { ColorAnimation { duration: 150 } }

                MouseArea {
                    id: maCorectrl
                    anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: corectrlProc.running = true
                }
                Row {
                    anchors.centerIn: parent; spacing: 8
                    Text {
                        text: "\uf085"
                        font.family: "JetBrainsMono Nerd Font Mono"
                        font.pixelSize: 15; color: root.mauve
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "Open CoreCtrl"
                        font.pixelSize: 13; font.bold: true; color: root.text
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }
    }
}
