import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Io

Item {
    id: root

    // ── Theme (dynamic — reads ~/.config/omarchy/current/theme/colors.toml) ──
    Theme { id: theme }
    readonly property color base:     theme.base
    readonly property color surface0: theme.surface0
    readonly property color surface1: theme.surface1
    readonly property color surface2: theme.surface2
    readonly property color overlay0: theme.overlay0
    readonly property color overlay1: theme.overlay1
    readonly property color overlay2: theme.overlay2
    readonly property color text:     theme.text
    readonly property color subtext0: theme.subtext0
    readonly property color subtext1: theme.subtext1
    readonly property color blue:     theme.blue
    readonly property color sapphire: theme.sapphire
    readonly property color lavender: theme.lavender
    readonly property color mauve:    theme.mauve
    readonly property color pink:     theme.pink
    readonly property color red:      theme.red
    readonly property color yellow:   theme.yellow

    // ─── Data State ───────────────────────────────────────────────────────────
    property var musicData: ({
        "title": "Not Playing", "artist": "", "status": "Stopped",
        "percent": 0, "length": 0, "position": 0,
        "lengthStr": "00:00", "positionStr": "00:00", "timeStr": "--:-- / --:--",
        "source": "Offline", "playerName": "", "blur": "", "grad": "",
        "textColor": root.text.toString(), "deviceIcon": "󰓃", "deviceName": "Speaker", "artUrl": ""
    })
    property var devicesData: []

    // ─── UI State ─────────────────────────────────────────────────────────────
    property bool userIsSeeking:          false
    property bool userToggledPlay:        false
    property bool userIsChangingVolume:   false
    property real volumeLevel:            65

    Timer { id: volDebounceTimer; interval: 400; onTriggered: root.userIsChangingVolume = false }

    Process {
        id: volumePoller
        command: ["bash", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{v=int($2*100); print (v>100?100:v)}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.userIsChangingVolume) {
                    var v = parseInt(this.text.trim())
                    if (!isNaN(v) && v >= 0) root.volumeLevel = v
                }
            }
        }
    }
    Timer { interval: 2000; repeat: true; running: true; triggeredOnStart: true; onTriggered: if (!volumePoller.running) volumePoller.running = true }

    // ─── Global Animations ────────────────────────────────────────────────────
    property real catppuccinFlowOffset: 0
    NumberAnimation on catppuccinFlowOffset {
        from: 0; to: 1.0; duration: 3000; loops: Animation.Infinite; running: true
    }

    property real globalOrbitAngle: 0
    NumberAnimation on globalOrbitAngle {
        from: 0; to: Math.PI * 2; duration: 90000; loops: Animation.Infinite; running: true
    }

    // ─── Startup Animations ───────────────────────────────────────────────────
    property real introMain:  0
    property real introCover: 0
    property real introText:  0
    property real introEq:    0

    ParallelAnimation {
        running: true
        NumberAnimation { target: root; property: "introMain";  from: 0; to: 1.0; duration:  700; easing.type: Easing.OutQuart }
        NumberAnimation { target: root; property: "introCover"; from: 0; to: 1.0; duration:  800; easing.type: Easing.OutExpo }
        NumberAnimation { target: root; property: "introText";  from: 0; to: 1.0; duration:  900; easing.type: Easing.OutExpo }
        NumberAnimation { target: root; property: "introEq";    from: 0; to: 1.0; duration: 1000; easing.type: Easing.OutExpo }
    }

    property color dynamicTextColor: {
        if (root.musicData && root.musicData.textColor) {
            var m = String(root.musicData.textColor).trim().match(/^(#[0-9a-fA-F]{6})/)
            if (m) return m[1]
        }
        return root.text
    }

    // ─── Status Change: Play Pulse ─────────────────────────────────────────────
    property string lastMusicStatus: "Stopped"
    onMusicDataChanged: {
        if (musicData && musicData.status && musicData.status !== lastMusicStatus) {
            if (musicData.status === "Playing") playPulse.trigger()
            lastMusicStatus = musicData.status
        }
    }

    // ─── Helpers ──────────────────────────────────────────────────────────────
    function execCmd(cmdStr) {
        var safe = cmdStr.replace(/`/g, "\\`")
        Qt.createQmlObject(`
            import Quickshell.Io
            Process {
                command: ["bash", "-c", \`${safe}\`]
                running: true
                onExited: destroy()
            }
        `, root)
    }

    function switchAudioDevice(sinkName) {
        // Optimistic UI update
        var devs = []
        for (var i = 0; i < root.devicesData.length; i++) {
            var d = Object.assign({}, root.devicesData[i])
            d.default = (d.name === sinkName)
            devs.push(d)
        }
        root.devicesData = devs
        // Apply the switch and move all active streams
        execCmd(`pactl set-default-sink "${sinkName}" && pactl list sink-inputs short 2>/dev/null | awk '{print $1}' | xargs -r -I{} pactl move-sink-input {} "${sinkName}"`)
        // Refresh device list after settling
        refreshDevicesTimer.restart()
    }

    // ─── Timers ───────────────────────────────────────────────────────────────
    Timer { id: seekDebounceTimer;   interval: 2500; onTriggered: root.userIsSeeking   = false }
    Timer { id: playDebounceTimer;   interval: 1500; onTriggered: root.userToggledPlay = false }
    Timer { id: refreshDevicesTimer; interval: 1500; onTriggered: { if (!devicesProc.running) devicesProc.running = true } }

    // ─── Data Polling ─────────────────────────────────────────────────────────
    Timer {
        interval: 500; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { if (!musicProc.running) musicProc.running = true }
    }
    Timer {
        interval: 2000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { if (!devicesProc.running) devicesProc.running = true }
    }

    Process {
        id: musicProc
        command: ["bash", "-c", "$HOME/.config/quickshell/media/music_info.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!this.text) return
                var s = this.text.trim()
                if (!s) return
                try {
                    var d = JSON.parse(s)
                    if (root.userToggledPlay) d.status = root.musicData.status
                    root.musicData = d
                } catch(e) {}
            }
        }
    }

    Process {
        id: devicesProc
        command: ["bash", "-c", "python3 $HOME/.config/quickshell/media/devices_info.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!this.text) return
                var s = this.text.trim()
                if (!s) return
                try { root.devicesData = JSON.parse(s) } catch(e) {}
            }
        }
    }

    // ─── UI Layout ────────────────────────────────────────────────────────────
    Item {
        id: mainWrapper
        anchors.fill: parent
        scale: 0.95 + 0.05 * root.introMain
        opacity: root.introMain

        // ── Inner Window ──────────────────────────────────────────────────────
        Rectangle {
            id: innerBg
            anchors.fill: parent
            color: root.base
            radius: 8
            layer.enabled: true

            Rectangle { id: innerBgMask; anchors.fill: parent; radius: 8; visible: false; layer.enabled: true }

            // Background effects: blurred album art + animated orbits
            Item {
                anchors.fill: parent
                layer.enabled: true
                layer.effect: MultiEffect { maskEnabled: true; maskSource: innerBgMask }

                Image {
                    anchors.fill: parent
                    source: root.musicData.blur ? "file://" + root.musicData.blur : ""
                    fillMode: Image.PreserveAspectCrop
                    opacity: status === Image.Ready ? 0.6 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 800; easing.type: Easing.InOutQuad } }
                }
                Rectangle {
                    width: parent.width * 0.8; height: width; radius: width / 2
                    x: parent.width/2 - width/2 + Math.cos(root.globalOrbitAngle * 2) * 150
                    y: parent.height/2 - height/2 + Math.sin(root.globalOrbitAngle * 2) * 100
                    opacity: root.musicData.status === "Playing" ? 0.12 : 0.04
                    color:   root.musicData.status === "Playing" ? root.mauve : root.surface2
                    Behavior on color   { ColorAnimation  { duration: 1000 } }
                    Behavior on opacity { NumberAnimation { duration: 1000 } }
                }
                Rectangle {
                    width: parent.width * 0.9; height: width; radius: width / 2
                    x: parent.width/2 - width/2 + Math.sin(root.globalOrbitAngle * 1.5) * -150
                    y: parent.height/2 - height/2 + Math.cos(root.globalOrbitAngle * 1.5) * -100
                    opacity: root.musicData.status === "Playing" ? 0.08 : 0.02
                    color:   root.musicData.status === "Playing" ? root.blue : root.surface1
                    Behavior on color   { ColorAnimation  { duration: 1000 } }
                    Behavior on opacity { NumberAnimation { duration: 1000 } }
                }
            }

            // ── Main Content ─────────────────────────────────────────────────
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 0

                // ── TOP: Cover Art + Track Info + Controls ────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 200
                    spacing: 22

                    // Cover Art (rotating circle)
                    Item {
                        Layout.preferredWidth: 200
                        Layout.preferredHeight: 200
                        Layout.alignment: Qt.AlignVCenter

                        opacity: root.introCover
                        transform: Translate { x: -30 * (1 - root.introCover) }

                        scale: root.musicData.status === "Playing" ? 1.0 : 0.90
                        Behavior on scale { NumberAnimation { duration: 800; easing.type: Easing.OutElastic; easing.overshoot: 1.2 } }

                        Rectangle {
                            anchors.fill: parent
                            radius: 100
                            color: root.surface1
                            border.width: 4
                            border.color: root.musicData.status === "Playing" ? root.mauve : root.overlay0
                            Behavior on border.color { ColorAnimation { duration: 500 } }

                            // Glow ring
                            Rectangle {
                                z: -1
                                anchors.centerIn: parent
                                width: parent.width + 20; height: parent.height + 20; radius: width / 2
                                color: root.mauve
                                opacity: root.musicData.status === "Playing" ? 0.5 : 0.0
                                Behavior on opacity { NumberAnimation { duration: 500 } }
                                layer.enabled: true
                                layer.effect: MultiEffect { blurEnabled: true; blurMax: 32; blur: 1.0 }
                            }

                            // Album art with circular mask
                            Item {
                                anchors.fill: parent
                                anchors.margins: 4
                                Image {
                                    id: artImg
                                    anchors.fill: parent
                                    source: root.musicData.artUrl ? "file://" + root.musicData.artUrl : ""
                                    fillMode: Image.PreserveAspectCrop
                                    visible: false
                                }
                                Rectangle {
                                    id: maskRect
                                    anchors.fill: parent; radius: width / 2
                                    visible: false; layer.enabled: true
                                }
                                MultiEffect {
                                    anchors.fill: parent; source: artImg
                                    maskEnabled: true; maskSource: maskRect
                                    opacity: artImg.status === Image.Ready ? 1.0 : 0.0
                                    Behavior on opacity { NumberAnimation { duration: 800 } }
                                }
                                // Center hole
                                Rectangle { width: 36; height: 36; radius: 18; color: "#000"; opacity: 0.8; anchors.centerIn: parent }
                            }

                            NumberAnimation on rotation {
                                from: 0; to: 360; duration: 8000
                                loops: Animation.Infinite; running: true
                                paused: root.musicData.status !== "Playing"
                            }
                        }
                    }

                    // Track info + progress + controls
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 14

                        opacity: root.introText
                        transform: Translate { x: 30 * (1 - root.introText) }

                        // Title + Artist + Source pill
                        ColumnLayout {
                            spacing: 5
                            Text {
                                text: root.musicData.title
                                color: root.dynamicTextColor
                                font.family: "JetBrains Mono"; font.pixelSize: 19; font.bold: true
                                elide: Text.ElideRight; maximumLineCount: 2; wrapMode: Text.Wrap
                                Layout.fillWidth: true
                                Behavior on color { ColorAnimation { duration: 600 } }
                            }
                            Text {
                                text: root.musicData.artist ? "BY " + root.musicData.artist : ""
                                color: root.pink
                                font.family: "JetBrains Mono"; font.pixelSize: 13; font.bold: true
                                elide: Text.ElideRight; Layout.fillWidth: true
                            }
                            RowLayout {
                                spacing: 8
                                Rectangle {
                                    color: "#1AFFFFFF"; radius: 4
                                    Layout.preferredHeight: 22
                                    Layout.preferredWidth: devicePillContent.width + 18
                                    RowLayout {
                                        id: devicePillContent
                                        anchors.centerIn: parent; spacing: 5
                                        Text { text: root.musicData.deviceIcon || "󰓃"; color: root.mauve; font.family: "Iosevka Nerd Font"; font.pixelSize: 13 }
                                        Text { text: root.musicData.deviceName || "Speaker"; color: root.overlay2; font.family: "JetBrains Mono"; font.pixelSize: 11; font.bold: true }
                                    }
                                }
                                Text {
                                    text: "VIA " + (root.musicData.source || "Offline")
                                    color: root.yellow
                                    font.family: "JetBrains Mono"; font.pixelSize: 11; font.bold: true; font.italic: true
                                }
                            }
                        }

                        // Progress slider
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Slider {
                                id: progBar
                                Layout.fillWidth: true
                                Layout.preferredHeight: 20
                                from: 0; to: 100

                                Connections {
                                    target: root
                                    function onMusicDataChanged() {
                                        if (!progBar.pressed && !root.userIsSeeking) {
                                            var p = Number(root.musicData.percent)
                                            if (!isNaN(p)) progBar.value = p
                                        }
                                    }
                                }

                                Behavior on value {
                                    enabled: !progBar.pressed && !root.userIsSeeking
                                    NumberAnimation { duration: 400; easing.type: Easing.OutSine }
                                }

                                onPressedChanged: {
                                    if (pressed) {
                                        root.userIsSeeking = true
                                        seekDebounceTimer.stop()
                                    } else {
                                        var temp = Object.assign({}, root.musicData)
                                        temp.percent = value
                                        root.musicData = temp
                                        var posSec = (value / 100 * Number(root.musicData.length)).toFixed(2)
                                        var pl = root.musicData.playerName ? ` --player="${root.musicData.playerName}"` : ""
                                        root.execCmd(`playerctl position ${posSec}${pl}`)
                                        seekDebounceTimer.restart()
                                    }
                                }

                                background: Item {
                                    x: progBar.leftPadding
                                    y: progBar.topPadding + (progBar.availableHeight - 12) / 2
                                    width: progBar.availableWidth; height: 12

                                    Rectangle {
                                        anchors.fill: parent; radius: 6; color: "#CC000000"
                                        layer.enabled: true
                                        layer.effect: MultiEffect {
                                            shadowEnabled: true; shadowColor: "#000"; shadowOpacity: 0.9; shadowBlur: 0.5; shadowVerticalOffset: 1
                                        }
                                    }
                                    Item {
                                        width: progBar.handle.x - progBar.leftPadding + progBar.handle.width / 2
                                        height: parent.height
                                        layer.enabled: true
                                        layer.effect: MultiEffect { maskEnabled: true; maskSource: sliderFillMask }
                                        Rectangle { id: sliderFillMask; anchors.fill: parent; radius: 6; visible: false; layer.enabled: true }
                                        Rectangle {
                                            width: 2000; height: parent.height
                                            x: -(root.catppuccinFlowOffset * 1000)
                                            gradient: Gradient {
                                                orientation: Gradient.Horizontal
                                                GradientStop { position: 0.0;   color: root.mauve }
                                                GradientStop { position: 0.166; color: root.blue  }
                                                GradientStop { position: 0.333; color: root.pink  }
                                                GradientStop { position: 0.5;   color: root.mauve }
                                                GradientStop { position: 0.666; color: root.blue  }
                                                GradientStop { position: 0.833; color: root.pink  }
                                                GradientStop { position: 1.0;   color: root.mauve }
                                            }
                                        }
                                    }
                                }

                                handle: Rectangle {
                                    x: progBar.leftPadding + progBar.visualPosition * (progBar.availableWidth - width)
                                    y: progBar.topPadding + (progBar.availableHeight - height) / 2
                                    implicitWidth: 18; implicitHeight: 18; width: 18; height: 18
                                    radius: 9; color: root.text
                                    scale: progBar.pressed ? 1.3 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: root.musicData.positionStr || "00:00"; color: root.overlay2; font.family: "JetBrains Mono"; font.bold: true; font.pixelSize: 12 }
                                Item  { Layout.fillWidth: true }
                                Text { text: root.musicData.lengthStr  || "00:00"; color: root.overlay2; font.family: "JetBrains Mono"; font.bold: true; font.pixelSize: 12 }
                            }
                        }

                        // Volume control
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Text {
                                text: root.volumeLevel === 0 ? "\uf6a9" : (root.volumeLevel < 50 ? "\uf027" : "\uf028")
                                color: root.overlay1
                                font.family: "Iosevka Nerd Font"; font.pixelSize: 16
                                Layout.preferredWidth: 18
                                horizontalAlignment: Text.AlignHCenter
                            }

                            Slider {
                                id: volBar
                                Layout.fillWidth: true
                                Layout.preferredHeight: 20
                                from: 0; to: 100

                                Connections {
                                    target: root
                                    function onVolumeLevelChanged() {
                                        if (!volBar.pressed && !root.userIsChangingVolume)
                                            volBar.value = root.volumeLevel
                                    }
                                }

                                Behavior on value {
                                    enabled: !volBar.pressed && !root.userIsChangingVolume
                                    NumberAnimation { duration: 300; easing.type: Easing.OutSine }
                                }

                                onMoved: {
                                    root.userIsChangingVolume = true
                                    root.volumeLevel = value
                                    root.execCmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ " + Math.round(value) + "%")
                                    volDebounceTimer.restart()
                                }

                                background: Item {
                                    x: volBar.leftPadding
                                    y: volBar.topPadding + (volBar.availableHeight - 8) / 2
                                    width: volBar.availableWidth; height: 8

                                    Rectangle { anchors.fill: parent; radius: 4; color: root.surface1 }
                                    Rectangle {
                                        width: volBar.visualPosition * parent.width
                                        height: parent.height; radius: 4
                                        color: root.mauve
                                        opacity: 0.85
                                        Behavior on color { ColorAnimation { duration: 300 } }
                                    }
                                }

                                handle: Rectangle {
                                    x: volBar.leftPadding + volBar.visualPosition * (volBar.availableWidth - width)
                                    y: volBar.topPadding + (volBar.availableHeight - height) / 2
                                    implicitWidth: 14; implicitHeight: 14
                                    radius: 7; color: root.text
                                    scale: volBar.pressed ? 1.3 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                                }
                            }

                            Text {
                                text: Math.round(root.volumeLevel) + "%"
                                color: root.overlay1
                                font.family: "JetBrains Mono"; font.pixelSize: 11; font.bold: true
                                Layout.preferredWidth: 36; horizontalAlignment: Text.AlignRight
                            }
                        }

                        // Playback controls
                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 28

                            MouseArea {
                                width: 28; height: 28; cursorShape: Qt.PointingHandCursor
                                onClicked: root.execCmd("playerctl previous")
                                Text { anchors.centerIn: parent; text: "\uf048"; color: parent.pressed ? root.text : root.overlay2; font.family: "Iosevka Nerd Font"; font.pixelSize: 22 }
                            }

                            MouseArea {
                                id: playPauseBtn
                                width: 46; height: 46; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.userToggledPlay = true
                                    playDebounceTimer.restart()
                                    var temp = Object.assign({}, root.musicData)
                                    temp.status = (temp.status === "Playing" ? "Paused" : "Playing")
                                    root.musicData = temp
                                    root.execCmd("playerctl play-pause")
                                }

                                Rectangle {
                                    id: playPulse
                                    anchors.centerIn: parent
                                    width: parent.width; height: parent.height; radius: width / 2
                                    color: root.mauve; opacity: 0; scale: 1
                                    NumberAnimation { id: playPulseScaleAnim; target: playPulse; property: "scale";   from: 1.0; to: 1.8; duration: 500; easing.type: Easing.OutQuart }
                                    NumberAnimation { id: playPulseFadeAnim;  target: playPulse; property: "opacity"; from: 0.5; to: 0.0; duration: 500; easing.type: Easing.OutQuart }
                                    function trigger() { playPulseScaleAnim.restart(); playPulseFadeAnim.restart() }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: root.musicData.status === "Playing" ? "\uf04c" : "\uf04b"
                                    color: parent.pressed ? root.pink : root.mauve
                                    font.family: "Iosevka Nerd Font"; font.pixelSize: 40
                                    scale: parent.pressed ? 0.8 : 1.0
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                                }
                            }

                            MouseArea {
                                width: 28; height: 28; cursorShape: Qt.PointingHandCursor
                                onClicked: root.execCmd("playerctl next")
                                Text { anchors.centerIn: parent; text: "\uf051"; color: parent.pressed ? root.text : root.overlay2; font.family: "Iosevka Nerd Font"; font.pixelSize: 22 }
                            }
                        }
                    }
                }

                // ── Separator ──────────────────────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 1
                    Layout.topMargin: 14; Layout.bottomMargin: 14
                    color: "#1AFFFFFF"; radius: 1
                    opacity: root.introEq
                    transform: Translate { y: 10 * (1 - root.introEq) }
                }

                // ── Audio Device Selector ──────────────────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 10

                    opacity: root.introEq
                    transform: Translate { y: 20 * (1 - root.introEq) }

                    // Header
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Audio Output"
                            color: root.mauve; font.family: "JetBrains Mono"; font.pixelSize: 15; font.bold: true
                            Layout.fillWidth: true
                        }
                        Text {
                            text: root.devicesData.length + " device" + (root.devicesData.length !== 1 ? "s" : "")
                            color: root.overlay1; font.family: "JetBrains Mono"; font.pixelSize: 12
                        }
                    }

                    // Device list
                    Column {
                        id: deviceListColumn
                        Layout.fillWidth: true
                        spacing: 6

                        Repeater {
                            model: root.devicesData
                            delegate: DeviceRow {
                                width: deviceListColumn.width
                                deviceName: modelData.name
                                deviceDesc: modelData.desc
                                deviceIcon: modelData.icon
                                isDefault:  modelData.default
                                onActivated: root.switchAudioDevice(deviceName)
                            }
                        }
                    }

                    // Empty state
                    Text {
                        visible: root.devicesData.length === 0
                        text: "No audio devices found"
                        color: root.overlay0; font.family: "JetBrains Mono"; font.pixelSize: 13
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Item { Layout.fillHeight: true }
                }
            }
        }
    }

    // ─── Device Row Component ─────────────────────────────────────────────────
    component DeviceRow : Rectangle {
        id: devRow
        property string deviceName: ""
        property string deviceDesc: ""
        property string deviceIcon: "󰓃"
        property bool   isDefault:  false
        signal activated

        height: 46
        radius: 10
        color: isDefault
            ? Qt.alpha(root.mauve, 0.2)
            : (hoverMa.containsMouse ? root.surface1 : Qt.alpha(root.base, 0.75))

        Behavior on color { ColorAnimation { duration: 200 } }

        border.width: isDefault ? 1 : 0
        border.color: isDefault ? root.mauve : "transparent"

        // Icon
        Text {
            id: devIconText
            anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
            text: deviceIcon
            font.family: "Iosevka Nerd Font"; font.pixelSize: 20
            color: isDefault ? root.mauve : root.overlay1
            Behavior on color { ColorAnimation { duration: 200 } }
        }

        // Name + secondary info
        Column {
            anchors {
                left: devIconText.right; leftMargin: 14
                right: activeIndicator.left; rightMargin: 12
                verticalCenter: parent.verticalCenter
            }
            spacing: 2
            Text {
                width: parent.width
                text: deviceDesc
                font.family: "JetBrains Mono"; font.pixelSize: 13; font.bold: true
                color: isDefault ? root.text : root.subtext0
                elide: Text.ElideRight
                Behavior on color { ColorAnimation { duration: 200 } }
            }
        }

        // Active indicator dot
        Item {
            id: activeIndicator
            anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
            width: 22; height: 22

            Rectangle {
                anchors.fill: parent; radius: width / 2
                color: root.mauve
                opacity: isDefault ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 300 } }
                layer.enabled: isDefault
                layer.effect: MultiEffect { blurEnabled: true; blurMax: 16; blur: 0.5 }
            }
            Text {
                anchors.centerIn: parent
                text: "\uf00c"
                font.family: "Iosevka Nerd Font"; font.pixelSize: 12
                color: root.base
                opacity: isDefault ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 300 } }
            }
        }

        MouseArea {
            id: hoverMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: isDefault ? Qt.ArrowCursor : Qt.PointingHandCursor
            onClicked: { if (!devRow.isDefault) devRow.activated() }
        }
    }
}
