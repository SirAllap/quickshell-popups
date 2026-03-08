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
    readonly property color blue:     theme.blue
    readonly property color sapphire: theme.sapphire
    readonly property color teal:     theme.teal
    readonly property color green:    theme.green
    readonly property color yellow:   theme.yellow
    readonly property color peach:    theme.peach
    readonly property color red:      theme.red
    readonly property color mauve:    theme.mauve

    readonly property string scriptsDir: Quickshell.env("HOME") + "/.config/quickshell/storage"

    property var storageData: null

    function usageColor(pct) {
        if (pct >= 90) return red
        if (pct >= 75) return peach
        if (pct >= 55) return yellow
        return blue
    }
    function tempColor(t) {
        if (t >= 60) return red
        if (t >= 50) return peach
        if (t >= 40) return yellow
        if (t > 0)   return green
        return teal
    }
    function speedColor(bps) {
        if (bps >= 500*1024*1024) return red
        if (bps >= 100*1024*1024) return peach
        if (bps >= 10*1024*1024)  return yellow
        if (bps > 0)              return green
        return overlay0
    }

    Process {
        id: poller
        command: ["python3", root.scriptsDir + "/storage_data.py"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let t = this.text.trim()
                if (t) try { root.storageData = JSON.parse(t) } catch(e) {}
            }
        }
    }
    Timer { interval: 4000; running: true; repeat: true; onTriggered: poller.running = true }

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
                Text { text: "\uf1c0"
                       font.family: "JetBrainsMono Nerd Font Mono"
                       font.pixelSize: 22; color: root.blue }
                Text { text: "Storage"
                       font.pixelSize: 17; font.bold: true; color: root.text }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: storageData ? storageData.drives.length + " drive(s)" : ""
                    font.pixelSize: 13; color: root.overlay0
                }
            }

            // Root usage badge
            Rectangle {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                width: 80; height: 34; radius: 10; color: root.surface0
                Text {
                    anchors.centerIn: parent
                    text: {
                        if (!storageData) return "--"
                        let root_drive = storageData.drives.find(d => d.mountpoint === "/")
                        return root_drive ? root_drive.used_percent + "%" : "--"
                    }
                    font.pixelSize: 16; font.bold: true
                    color: {
                        if (!storageData) return root.blue
                        let d = storageData.drives.find(dr => dr.mountpoint === "/")
                        return d ? root.usageColor(d.used_percent) : root.blue
                    }
                }
            }
        }

        Rectangle {
            id: sep1
            anchors.top: header.bottom; anchors.topMargin: 10
            anchors.left: parent.left; anchors.right: parent.right
            height: 1; color: root.surface1
        }

        // ── Drive list ────────────────────────────────────────────────────────
        Flickable {
            anchors.top: sep1.bottom; anchors.topMargin: 12
            anchors.left: parent.left; anchors.right: parent.right
            anchors.bottom: parent.bottom
            contentHeight: driveColumn.height
            clip: true

            Column {
                id: driveColumn
                width: parent.width
                spacing: 10

                Repeater {
                    model: storageData ? storageData.drives : []
                    delegate: Rectangle {
                        width: parent.width
                        height: driveContent.height + 24
                        color: root.surface0; radius: 8

                        Column {
                            id: driveContent
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.leftMargin: 14; anchors.rightMargin: 14; anchors.topMargin: 12
                            spacing: 10

                            // Drive name row
                            Item {
                                width: parent.width; height: 42

                                // Drive icon + info (left side)
                                Row {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 8
                                    Text {
                                        text: "\uf1c0"
                                        font.family: "JetBrainsMono Nerd Font Mono"
                                        font.pixelSize: 16
                                        color: modelData.device.startsWith("nvme") ? root.sapphire : root.blue
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Column {
                                        spacing: 2
                                        Text {
                                            text: modelData.model !== modelData.device ? modelData.model : modelData.device
                                            font.pixelSize: 14; font.bold: true; color: root.text
                                            width: 500; elide: Text.ElideRight
                                        }
                                        Text {
                                            text: modelData.mountpoint + "  (" + modelData.device + ")"
                                            font.pixelSize: 11; color: root.overlay0
                                        }
                                    }
                                }

                                // Health / lifespan badge (right side)
                                Rectangle {
                                    id: healthBadge
                                    visible: modelData.health !== "" || modelData.lifespan !== ""
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 68; height: 28; radius: 8
                                    color: modelData.health === "OK" ?
                                           Qt.rgba(0.22, 0.51, 0.35, 0.25) :
                                           modelData.health === "FAIL" ?
                                           Qt.rgba(0.95, 0.55, 0.66, 0.25) :
                                           Qt.rgba(0.5, 0.5, 0.5, 0.15)
                                    border.color: modelData.health === "OK" ? root.green :
                                                  modelData.health === "FAIL" ? root.red : root.overlay0
                                    border.width: 1
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.lifespan !== "" ? modelData.lifespan :
                                              modelData.health === "OK" ? "\uf00c OK" :
                                              modelData.health === "FAIL" ? "\uf00d FAIL" : "--"
                                        font.family: "JetBrainsMono Nerd Font Mono"
                                        font.pixelSize: 12; font.bold: true
                                        color: modelData.health === "OK" ? root.green :
                                               modelData.health === "FAIL" ? root.red : root.overlay0
                                    }
                                }
                            }

                            // Usage bar with labels
                            Column {
                                width: parent.width; spacing: 5

                                Item {
                                    width: parent.width; height: 16
                                    Text {
                                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.used_gb.toFixed(1) + " / " + modelData.total_gb.toFixed(1) + " GB"
                                        font.pixelSize: 12; color: root.subtext0
                                    }
                                    Text {
                                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.free_gb.toFixed(1) + " GB free"
                                        font.pixelSize: 12; color: root.overlay0
                                    }
                                }

                                Rectangle {
                                    width: parent.width; height: 12; radius: 6; color: root.surface1
                                    Rectangle {
                                        anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                                        width: Math.max(8, parent.width * modelData.used_percent / 100)
                                        color: root.usageColor(modelData.used_percent)
                                        radius: 6; opacity: 0.85
                                        Behavior on width { NumberAnimation { duration: 500 } }
                                    }
                                    Text {
                                        anchors.right: parent.right; anchors.rightMargin: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.used_percent + "%"
                                        font.pixelSize: 9; font.bold: true; color: root.text
                                        visible: modelData.used_percent > 15
                                    }
                                }
                            }

                            // Stats row (temp + I/O speeds)
                            Row {
                                spacing: 20

                                // Temperature
                                Row {
                                    spacing: 5; visible: modelData.temperature > 0
                                    Text { text: "\uf2c7"
                                           font.family: "JetBrainsMono Nerd Font Mono"
                                           font.pixelSize: 14
                                           color: root.tempColor(modelData.temperature)
                                           anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: modelData.temperature + "°C"
                                           font.pixelSize: 13
                                           color: root.tempColor(modelData.temperature)
                                           anchors.verticalCenter: parent.verticalCenter }
                                }

                                // Read speed
                                Row {
                                    spacing: 5
                                    Text { text: "\uf063"
                                           font.family: "JetBrainsMono Nerd Font Mono"
                                           font.pixelSize: 13
                                           color: root.speedColor(modelData.read_bps)
                                           anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: "R: " + modelData.read_str
                                           font.pixelSize: 13
                                           color: root.speedColor(modelData.read_bps)
                                           anchors.verticalCenter: parent.verticalCenter }
                                }

                                // Write speed
                                Row {
                                    spacing: 5
                                    Text { text: "\uf062"
                                           font.family: "JetBrainsMono Nerd Font Mono"
                                           font.pixelSize: 13
                                           color: root.speedColor(modelData.write_bps)
                                           anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: "W: " + modelData.write_str
                                           font.pixelSize: 13
                                           color: root.speedColor(modelData.write_bps)
                                           anchors.verticalCenter: parent.verticalCenter }
                                }
                            }
                        }
                    }
                }

                Text {
                    visible: !storageData || storageData.drives.length === 0
                    text: "Loading storage data..."
                    font.pixelSize: 14; color: root.overlay0
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }
}
