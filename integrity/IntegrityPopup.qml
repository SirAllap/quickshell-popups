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
    readonly property color blue:     theme.blue
    readonly property color teal:     theme.teal
    readonly property color green:    theme.green
    readonly property color yellow:   theme.yellow
    readonly property color peach:    theme.peach
    readonly property color red:      theme.red
    readonly property color mauve:    theme.mauve

    readonly property string scriptsDir: Quickshell.env("HOME") + "/.config/quickshell/integrity"

    property var integrityData: null
    property bool loading: true

    function statusColor(s) {
        if (s === "OK")       return green
        if (s === "WARNING")  return yellow
        if (s === "CRITICAL") return red
        return overlay0
    }
    function statusIcon(s) {
        if (s === "OK")       return "\uf00c"
        if (s === "WARNING")  return "\uf071"
        if (s === "CRITICAL") return "\uf057"
        return "\uf059"
    }
    function overallColor(s) {
        if (s === "OK")       return green
        if (s === "WARNING")  return yellow
        if (s === "CRITICAL") return red
        return overlay0
    }
    function overallIcon(s) {
        if (s === "OK")       return "\uf058"
        if (s === "WARNING")  return "\uf071"
        if (s === "CRITICAL") return "\uf06a"
        return "\uf059"
    }
    function overallLabel(s) {
        if (s === "OK")       return "System Healthy"
        if (s === "WARNING")  return "Warnings Detected"
        if (s === "CRITICAL") return "Critical Issues!"
        return "Checking..."
    }

    // ── Data poller ───────────────────────────────────────────────────────────
    Process {
        id: poller
        command: ["python3", root.scriptsDir + "/integrity_data.py"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false
                let t = this.text.trim()
                if (t) try { root.integrityData = JSON.parse(t) } catch(e) {}
            }
        }
    }
    // Integrity checks are heavy — poll every 30s
    Timer { interval: 30000; running: true; repeat: true
            onTriggered: { root.loading = true; poller.running = true } }

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
            height: 56

            Row {
                anchors.verticalCenter: parent.verticalCenter; spacing: 12

                Text {
                    text: integrityData ? root.overallIcon(integrityData.overall) : "\uf110"
                    font.family: "JetBrainsMono Nerd Font Mono"
                    font.pixelSize: 28
                    color: integrityData ? root.overallColor(integrityData.overall) : root.overlay0
                    Behavior on color { ColorAnimation { duration: 500 } }

                    SequentialAnimation on opacity {
                        running: integrityData && integrityData.overall !== "OK" && !loading
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.4; duration: 800; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutSine }
                    }
                }

                Column {
                    spacing: 2
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        text: integrityData ? root.overallLabel(integrityData.overall) : "Running checks..."
                        font.pixelSize: 18; font.bold: true
                        color: integrityData ? root.overallColor(integrityData.overall) : root.overlay0
                        Behavior on color { ColorAnimation { duration: 500 } }
                    }
                    Text {
                        text: integrityData ? "Last checked: " + integrityData.timestamp : "Please wait..."
                        font.pixelSize: 12; color: root.overlay0
                    }
                }
            }

            // ── Summary badges ────────────────────────────────────────────────
            Row {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                spacing: 8; visible: integrityData !== null

                property int okCount:   integrityData ? integrityData.checks.filter(c => c.status === "OK").length       : 0
                property int warnCount: integrityData ? integrityData.checks.filter(c => c.status === "WARNING").length  : 0
                property int critCount: integrityData ? integrityData.checks.filter(c => c.status === "CRITICAL").length : 0

                Rectangle {
                    visible: parent.okCount > 0
                    width: 46; height: 28; radius: 8
                    color: Qt.rgba(root.green.r, root.green.g, root.green.b, 0.15)
                    border.color: root.green; border.width: 1
                    Text { anchors.centerIn: parent
                           text: "\uf00c " + parent.parent.okCount
                           font.family: "JetBrainsMono Nerd Font Mono"
                           font.pixelSize: 12; color: root.green }
                }
                Rectangle {
                    visible: parent.warnCount > 0
                    width: 46; height: 28; radius: 8
                    color: Qt.rgba(root.yellow.r, root.yellow.g, root.yellow.b, 0.15)
                    border.color: root.yellow; border.width: 1
                    Text { anchors.centerIn: parent
                           text: "\uf071 " + parent.parent.warnCount
                           font.family: "JetBrainsMono Nerd Font Mono"
                           font.pixelSize: 12; color: root.yellow }
                }
                Rectangle {
                    visible: parent.critCount > 0
                    width: 46; height: 28; radius: 8
                    color: Qt.rgba(root.red.r, root.red.g, root.red.b, 0.15)
                    border.color: root.red; border.width: 1
                    Text { anchors.centerIn: parent
                           text: "\uf057 " + parent.parent.critCount
                           font.family: "JetBrainsMono Nerd Font Mono"
                           font.pixelSize: 12; color: root.red }
                }
            }
        }

        Rectangle {
            id: sep1
            anchors.top: header.bottom; anchors.topMargin: 10
            anchors.left: parent.left; anchors.right: parent.right
            height: 1; color: root.surface1
        }

        // ── Loading indicator ─────────────────────────────────────────────────
        Item {
            visible: loading && !integrityData
            anchors.top: sep1.bottom; anchors.bottom: parent.bottom
            anchors.left: parent.left; anchors.right: parent.right

            Column {
                anchors.centerIn: parent; spacing: 12
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "\uf110"
                    font.family: "JetBrainsMono Nerd Font Mono"
                    font.pixelSize: 36; color: root.blue
                    SequentialAnimation on opacity {
                        running: true; loops: Animation.Infinite
                        NumberAnimation { to: 0.2; duration: 600 }
                        NumberAnimation { to: 1.0; duration: 600 }
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Running system checks..."
                    font.pixelSize: 14; color: root.subtext0
                }
            }
        }

        // ── Checks grid ───────────────────────────────────────────────────────
        Flickable {
            visible: integrityData !== null
            anchors.top: sep1.bottom; anchors.topMargin: 12
            anchors.left: parent.left; anchors.right: parent.right
            anchors.bottom: parent.bottom
            contentHeight: checksGrid.height
            clip: true

            Grid {
                id: checksGrid
                width: parent.width
                columns: 2
                spacing: 10

                property real cellW: (width - spacing) / 2

                Repeater {
                    model: integrityData ? integrityData.checks : []
                    delegate: Rectangle {
                        width: checksGrid.cellW
                        height: detailsCol.height + 24
                        color: root.surface0; radius: 8

                        // Left status stripe
                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top; anchors.bottom: parent.bottom
                            anchors.topMargin: 4; anchors.bottomMargin: 4
                            width: 3; radius: 2
                            color: root.statusColor(modelData.status)
                            opacity: 0.85
                        }

                        Column {
                            id: detailsCol
                            anchors.left: parent.left; anchors.leftMargin: 14
                            anchors.right: parent.right; anchors.rightMargin: 10
                            anchors.top: parent.top; anchors.topMargin: 12
                            spacing: 4

                            Row {
                                width: parent.width; spacing: 6
                                Text {
                                    text: root.statusIcon(modelData.status)
                                    font.family: "JetBrainsMono Nerd Font Mono"
                                    font.pixelSize: 14
                                    color: root.statusColor(modelData.status)
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: modelData.name
                                    font.pixelSize: 13; font.bold: true; color: root.text
                                    width: parent.width - 24; elide: Text.ElideRight
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Text {
                                text: modelData.message
                                font.pixelSize: 12; color: root.subtext0
                                width: parent.width; elide: Text.ElideRight
                            }

                            Repeater {
                                model: modelData.details
                                Text {
                                    text: "  \u2022 " + modelData
                                    font.pixelSize: 11; color: root.overlay0
                                    width: parent.width; elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
