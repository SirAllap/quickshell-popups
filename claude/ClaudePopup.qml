import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: window

    // ── Theme (dynamic — reads ~/.config/omarchy/current/theme/colors.toml) ──
    Theme { id: theme }
    readonly property color base:     theme.base
    readonly property color surface0: theme.surface0
    readonly property color surface1: theme.surface1
    readonly property color overlay0: theme.overlay0
    readonly property color overlay1: theme.overlay1
    readonly property color subtext0: theme.subtext0
    readonly property color text:     theme.text
    readonly property color mauve:    theme.mauve
    readonly property color blue:     theme.blue
    readonly property color sapphire: theme.sapphire
    readonly property color teal:     theme.teal
    readonly property color yellow:   theme.yellow
    readonly property color maroon:   theme.maroon
    readonly property color red:      theme.red

    readonly property string scriptsDir: Quickshell.env("HOME") + "/.config/quickshell/claude"

    // ── Animations ───────────────────────────────────────────────────────────
    property real introState: 0.0
    Behavior on introState { NumberAnimation { duration: 1200; easing.type: Easing.OutExpo } }

    property real globalOrbitAngle: 0.0
    NumberAnimation on globalOrbitAngle {
        from: 0; to: Math.PI * 2
        duration: 90000; loops: Animation.Infinite; running: true
    }

    // ── Data ─────────────────────────────────────────────────────────────────
    property var claudeData: null

    readonly property color accentColor: {
        if (!claudeData || !claudeData.week) return blue
        let p = claudeData.week.percent
        if (p >= 90) return red
        if (p >= 75) return maroon
        if (p >= 50) return yellow
        return blue
    }

    readonly property color accentColor2: {
        if (!claudeData || !claudeData.session) return mauve
        let p = claudeData.session.percent
        if (p >= 90) return red
        if (p >= 75) return maroon
        if (p >= 50) return yellow
        return mauve
    }

    Process {
        id: dataPoller
        command: ["python3", window.scriptsDir + "/claude_data.py"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = this.text.trim()
                if (txt !== "") {
                    try { window.claudeData = JSON.parse(txt) } catch(e) {}
                }
            }
        }
    }

    Timer { interval: 30000; running: true; repeat: true; onTriggered: dataPoller.running = true }

    Component.onCompleted: introState = 1.0

    // ── Root UI ──────────────────────────────────────────────────────────────
    Item {
        anchors.fill: parent
        scale:   0.90 + 0.10 * introState
        opacity: introState

        Rectangle {
            anchors.fill: parent
            radius: 8; color: window.base
            clip: true

            // ── Ambient blobs ────────────────────────────────────────────────
            Item {
                anchors.fill: parent; z: -1
                Rectangle {
                    width: 500; height: 500; radius: 250
                    x: parent.width/2  - 250 + Math.cos(window.globalOrbitAngle * 1.5) * 130
                    y: parent.height/2 - 250 + Math.sin(window.globalOrbitAngle * 1.5) * 90
                    color: window.accentColor; opacity: 0.05
                    Behavior on color { ColorAnimation { duration: 1500 } }
                }
                Rectangle {
                    width: 420; height: 420; radius: 210
                    x: parent.width/2  - 210 + Math.sin(window.globalOrbitAngle * -1.2) * 160
                    y: parent.height/2 - 210 + Math.cos(window.globalOrbitAngle * -1.2) * 130
                    color: window.accentColor2; opacity: 0.04
                    Behavior on color { ColorAnimation { duration: 1500 } }
                }
                Rectangle {
                    width: 360; height: 360; radius: 180
                    x: parent.width/2  - 180 + Math.cos(window.globalOrbitAngle * 2.0) * -100
                    y: parent.height/2 - 180 + Math.sin(window.globalOrbitAngle * 2.0) * -70
                    color: window.mauve; opacity: 0.03
                }
            }

            // ── Dashed orbit rings ───────────────────────────────────────────
            Repeater {
                model: 2
                Rectangle {
                    anchors.centerIn: parent; anchors.verticalCenterOffset: -60
                    width: 320 + index * 210; height: width; radius: width / 2
                    color: "transparent"
                    border.color: window.accentColor; border.width: 1; opacity: 0.04
                    transform: Rotation {
                        origin.x: width/2; origin.y: height/2
                        angle: window.globalOrbitAngle * (180 / Math.PI) * (index === 0 ? 0.8 : -0.5)
                    }
                    Canvas {
                        anchors.fill: parent
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0,0,width,height)
                            ctx.beginPath()
                            ctx.arc(width/2, height/2, width/2-1, 0, Math.PI*2)
                            ctx.strokeStyle = window.accentColor
                            ctx.lineWidth = 5; ctx.setLineDash([20, 55]); ctx.stroke()
                        }
                    }
                }
            }

            // ── Faint background lightbulb icon ──────────────────────────────
            Text {
                anchors.centerIn: parent; anchors.verticalCenterOffset: -60
                text: "\uf0eb"
                font.family: "Iosevka Nerd Font"; font.pixelSize: 380
                color: window.accentColor
                opacity: 0.03 + 0.01 * Math.sin(window.globalOrbitAngle * 4)
                z: 0
                Behavior on color { ColorAnimation { duration: 1500 } }
                property real drift: 0.0
                SequentialAnimation on drift {
                    loops: Animation.Infinite
                    NumberAnimation { to: -12; duration: 6000; easing.type: Easing.InOutSine }
                    NumberAnimation { to:   0; duration: 6000; easing.type: Easing.InOutSine }
                }
                transform: Translate { y: parent.drift }
            }

            // ── CENTER: cost display + orbital stat pills ─────────────────────
            Item {
                anchors.centerIn: parent; anchors.verticalCenterOffset: -60
                width: 1; height: 1; z: 5

                property real levitation: 0.0
                SequentialAnimation on levitation {
                    loops: Animation.Infinite
                    NumberAnimation { to: -10; duration: 4000; easing.type: Easing.InOutSine }
                    NumberAnimation { to:   0; duration: 4000; easing.type: Easing.InOutSine }
                }
                transform: Translate { y: parent.levitation }

                // Dashed ellipse orbit track
                Canvas {
                    z: -10; x: -280; y: -128; width: 560; height: 256; opacity: 0.25
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        ctx.beginPath()
                        for (var i = 0; i <= Math.PI * 2; i += 0.05) {
                            var xx = width/2 + Math.cos(i) * 200
                            var yy = height/2 + Math.sin(i) * 88
                            if (i === 0) ctx.moveTo(xx, yy); else ctx.lineTo(xx, yy)
                        }
                        ctx.strokeStyle = window.accentColor
                        ctx.lineWidth = 1.5; ctx.setLineDash([4, 10]); ctx.stroke()
                    }
                }

                // Cost display
                ColumnLayout {
                    anchors.centerIn: parent; spacing: 0; z: 1
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "$" + (window.claudeData && window.claudeData.today && window.claudeData.today.cost
                                     ? window.claudeData.today.cost : "0.00")
                        font.family: "JetBrains Mono"; font.weight: Font.Black; font.pixelSize: 70
                        color: window.text; style: Text.Outline; styleColor: "#40000000"
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "TODAY'S COST"
                        font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: 15
                        color: window.accentColor
                        Behavior on color { ColorAnimation { duration: 1000 } }
                    }
                }

                // Orbital stat pills (5 items)
                Repeater {
                    model: {
                        if (!window.claudeData || !window.claudeData.today) return []
                        let t = window.claudeData.today
                        return [
                            { lbl: "msgs",     val: t.messages !== undefined ? t.messages.toString() : "\u2014", ico: "\uf086" },
                            { lbl: "tools",    val: t.tools    !== undefined ? t.tools.toString()    : "\u2014", ico: "\uf0ad" },
                            { lbl: "think%",   val: (t.thinking_pct || 0) + "%",                               ico: "\uf0eb" },
                            { lbl: "cache",    val: t.cache_ratio || "\u2014",                                  ico: "\uf1c0" },
                            { lbl: "avg turn", val: t.avg_turn    || "\u2014",                                  ico: "\uf017" },
                        ]
                    }

                    delegate: Item {
                        property real rx: 280; property real ry: 128
                        property real baseAngle: index * 72.0
                        property real orbitOff: window.globalOrbitAngle * (180 / Math.PI) * -1.5
                        property real osc: Math.sin(window.globalOrbitAngle * 8 + index) * 4
                        property real rad: (baseAngle + orbitOff + osc) * (Math.PI / 180)
                        x: Math.cos(rad) * rx - width  / 2
                        y: Math.sin(rad) * ry - height / 2
                        z: Math.sin(rad) * 100
                        scale:   0.88 + 0.24 * Math.sin(rad)
                        opacity: 0.38 + 0.62 * ((Math.sin(rad) + 1) / 2)
                        width: 56; height: 72

                        Rectangle {
                            anchors.fill: parent; radius: 18
                            color: pillMa.containsMouse ? "#3affffff" : "#0dffffff"
                            border.color: pillMa.containsMouse ? window.accentColor : "#1affffff"
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 200 } }

                            ColumnLayout {
                                anchors.centerIn: parent; spacing: 2
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: modelData.ico; font.family: "Iosevka Nerd Font"; font.pixelSize: 18
                                    color: pillMa.containsMouse ? window.accentColor : window.overlay1
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: modelData.val; font.family: "JetBrains Mono"
                                    font.weight: Font.Black; font.pixelSize: 14; color: window.text
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: modelData.lbl; font.family: "JetBrains Mono"
                                    font.pixelSize: 12; color: window.overlay0
                                }
                            }
                        }
                        MouseArea { id: pillMa; anchors.fill: parent; hoverEnabled: true }
                    }
                }
            }

            // ── LEFT: Usage limits + model breakdown ──────────────────────────
            Item {
                anchors.left: parent.left; anchors.top: parent.top; anchors.margins: 22
                width: 300; height: parent.height - 120 - 22 - 16; z: 10

                ColumnLayout {
                    anchors.fill: parent; spacing: 14

                    // Section header
                    RowLayout {
                        spacing: 8
                        Rectangle { width: 3; height: 32; radius: 2; color: window.accentColor; Behavior on color { ColorAnimation { duration: 1500 } } }
                        ColumnLayout {
                            spacing: 1
                            Text { text: "USAGE LIMITS"; font.family: "JetBrains Mono"; font.weight: Font.Black; font.pixelSize: 16; color: window.text }
                            Text {
                                text: window.claudeData
                                      ? (window.claudeData.fetching ? "refreshing..." : "updated " + window.claudeData.age + "s ago")
                                      : "loading..."
                                font.family: "JetBrains Mono"; font.pixelSize: 13; color: window.overlay0
                            }
                        }
                    }

                    // Usage gauges
                    Repeater {
                        model: {
                            if (!window.claudeData) return []
                            let out = []
                            if (window.claudeData.session) out.push({
                                lbl: "Session", pct: window.claudeData.session.percent,
                                rst: window.claudeData.session.reset, clr: window.claudeData.session.color, sub: ""
                            })
                            if (window.claudeData.week) {
                                let wb = window.claudeData.week_budget
                                out.push({
                                    lbl: "Week", pct: window.claudeData.week.percent,
                                    rst: window.claudeData.week.reset, clr: window.claudeData.week.color,
                                    sub: wb ? "Day " + wb.day + "/7  \u00b7  " + wb.ratio + "% of budget" : ""
                                })
                            }
                            if (window.claudeData.week_sonnet) {
                                let wb = window.claudeData.wson_budget
                                out.push({
                                    lbl: "Sonnet", pct: window.claudeData.week_sonnet.percent,
                                    rst: window.claudeData.week_sonnet.reset, clr: window.claudeData.week_sonnet.color,
                                    sub: wb ? "Day " + wb.day + "/7  \u00b7  " + wb.ratio + "% of budget" : ""
                                })
                            }
                            return out
                        }

                        Item {
                            Layout.fillWidth: true; height: 64

                            RowLayout {
                                anchors.fill: parent; spacing: 10

                                // Circular gauge
                                Item {
                                    width: 44; height: 44
                                    Canvas {
                                        id: uCanvas; anchors.fill: parent; rotation: -90
                                        property real progress: modelData.pct / 100.0
                                        property real animProg: 0.0
                                        NumberAnimation on animProg {
                                            to: uCanvas.progress
                                            duration: 1500; easing.type: Easing.OutExpo; running: true
                                        }
                                        onAnimProgChanged: requestPaint()
                                        onPaint: {
                                            var ctx = getContext("2d"); ctx.clearRect(0,0,width,height)
                                            var r = width / 2
                                            ctx.beginPath(); ctx.arc(r,r,r-4,0,2*Math.PI)
                                            ctx.strokeStyle = "#1affffff"; ctx.lineWidth = 3; ctx.stroke()
                                            if (animProg > 0) {
                                                ctx.beginPath(); ctx.arc(r,r,r-4,0,animProg*2*Math.PI)
                                                ctx.strokeStyle = modelData.clr
                                                ctx.lineWidth = 4; ctx.lineCap = "round"; ctx.stroke()
                                            }
                                        }
                                        Behavior on progress { NumberAnimation { duration: 1000; easing.type: Easing.OutExpo } }
                                    }
                                    Text {
                                        anchors.centerIn: parent; text: modelData.pct + "%"
                                        font.family: "JetBrains Mono"; font.weight: Font.Black; font.pixelSize: 14; color: window.text
                                    }
                                }

                                // Label + progress bar
                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 3
                                    RowLayout {
                                        Text { text: modelData.lbl.toUpperCase(); font.family: "JetBrains Mono"; font.weight: Font.Black; font.pixelSize: 15; color: window.text }
                                        Item { Layout.fillWidth: true }
                                        Text { visible: modelData.rst !== ""; text: modelData.rst; font.family: "JetBrains Mono"; font.pixelSize: 13; color: window.overlay0 }
                                    }
                                    Rectangle {
                                        Layout.fillWidth: true; height: 3; radius: 2; color: "#1affffff"
                                        Rectangle {
                                            width: parent.width * Math.min(1.0, modelData.pct / 100.0)
                                            height: parent.height; radius: parent.radius; color: modelData.clr
                                            Behavior on width { NumberAnimation { duration: 1000; easing.type: Easing.OutExpo } }
                                        }
                                    }
                                    Text { visible: modelData.sub !== ""; text: modelData.sub; font.family: "JetBrains Mono"; font.pixelSize: 12; color: window.overlay0 }
                                }
                            }
                        }
                    }

                    Item { Layout.fillHeight: true; Layout.minimumHeight: 2 }

                    // Model breakdown
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 5
                        Text { text: "MODELS TODAY"; font.family: "JetBrains Mono"; font.weight: Font.Black; font.pixelSize: 14; color: window.overlay0 }
                        Repeater {
                            model: window.claudeData && window.claudeData.today ? (window.claudeData.today.models || []) : []
                            RowLayout {
                                Layout.fillWidth: true; spacing: 6
                                Rectangle {
                                    width: 5; height: 5; radius: 3
                                    color: modelData.name === "Opus" ? window.mauve : (modelData.name === "Sonnet" ? window.blue : window.teal)
                                }
                                Text { text: modelData.name; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: 14; color: window.text }
                                Item { Layout.fillWidth: true }
                                Text { text: modelData.count + "  \u00b7  $" + modelData.cost; font.family: "JetBrains Mono"; font.pixelSize: 13; color: window.overlay0 }
                            }
                        }
                    }
                }
            }

            // ── RIGHT: Today's activity ───────────────────────────────────────
            Item {
                anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 22
                width: 300; height: parent.height - 120 - 22 - 16; z: 10

                ColumnLayout {
                    anchors.fill: parent; spacing: 14

                    // Section header
                    RowLayout {
                        spacing: 8
                        Item { Layout.fillWidth: true }
                        ColumnLayout {
                            spacing: 1
                            Text { text: "TODAY'S ACTIVITY"; font.family: "JetBrains Mono"; font.weight: Font.Black; font.pixelSize: 16; color: window.text; Layout.alignment: Qt.AlignRight }
                            Text {
                                text: window.claudeData && window.claudeData.today
                                      ? (window.claudeData.today.sessions || 0) + " sessions"
                                      : "no data"
                                font.family: "JetBrains Mono"; font.pixelSize: 13; color: window.overlay0; Layout.alignment: Qt.AlignRight
                            }
                        }
                        Rectangle { width: 3; height: 32; radius: 2; color: window.accentColor2; Behavior on color { ColorAnimation { duration: 1500 } } }
                    }

                    // 2×3 stat tiles
                    GridLayout {
                        Layout.fillWidth: true; columns: 2; rowSpacing: 6; columnSpacing: 6
                        Repeater {
                            model: {
                                if (!window.claudeData || !window.claudeData.today) return []
                                let t = window.claudeData.today
                                return [
                                    { ico: "\uf086", lbl: "Messages",   val: (t.messages || 0).toString() },
                                    { ico: "\uf0ad", lbl: "Tool Calls", val: (t.tools    || 0).toString() },
                                    { ico: "\uf0eb", lbl: "Thinking",   val: (t.thinking_blocks || 0) + " (" + (t.thinking_pct || 0) + "%)" },
                                    { ico: "\uf017", lbl: "Avg Turn",   val: t.avg_turn || "\u2014" },
                                    { ico: "\uf019", lbl: "In Tokens",  val: t.input    || "\u2014" },
                                    { ico: "\uf093", lbl: "Out Tokens", val: t.output   || "\u2014" },
                                ]
                            }
                            Item {
                                Layout.fillWidth: true; height: 52
                                Rectangle {
                                    anchors.fill: parent; radius: 7
                                    color: tileMa.containsMouse ? "#10ffffff" : "#06ffffff"
                                    border.color: "#0cffffff"; border.width: 1
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }
                                RowLayout {
                                    anchors.fill: parent; anchors.margins: 8; spacing: 6
                                    Text {
                                        text: modelData.ico; font.family: "Iosevka Nerd Font"; font.pixelSize: 22
                                        color: tileMa.containsMouse ? window.accentColor2 : window.overlay1
                                        Behavior on color { ColorAnimation { duration: 200 } }
                                    }
                                    ColumnLayout {
                                        spacing: 1
                                        Text { text: modelData.lbl; font.family: "JetBrains Mono"; font.pixelSize: 12;  color: window.overlay0 }
                                        Text { text: modelData.val; font.family: "JetBrains Mono"; font.weight: Font.Black; font.pixelSize: 15; color: window.text }
                                    }
                                }
                                MouseArea { id: tileMa; anchors.fill: parent; hoverEnabled: true }
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    // Cache stats
                    Rectangle {
                        Layout.fillWidth: true; height: 52
                        color: "#06ffffff"; radius: 8; border.color: "#0cffffff"; border.width: 1
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 10; spacing: 10
                            Text { text: "\uf1c0"; font.family: "Iosevka Nerd Font"; font.pixelSize: 24; color: window.sapphire }
                            ColumnLayout {
                                spacing: 1
                                Text { text: "CACHE"; font.family: "JetBrains Mono"; font.weight: Font.Black; font.pixelSize: 13; color: window.overlay0 }
                                Text {
                                    text: "R " + (window.claudeData && window.claudeData.today ? window.claudeData.today.cache_read  : "\u2014") +
                                          "  W " + (window.claudeData && window.claudeData.today ? window.claudeData.today.cache_write : "\u2014")
                                    font.family: "JetBrains Mono"; font.pixelSize: 14; color: window.text
                                }
                            }
                            Item { Layout.fillWidth: true }
                            ColumnLayout {
                                spacing: 1
                                Text { text: "RATIO"; font.family: "JetBrains Mono"; font.weight: Font.Black; font.pixelSize: 13; color: window.overlay0; Layout.alignment: Qt.AlignRight }
                                Text {
                                    text: window.claudeData && window.claudeData.today ? (window.claudeData.today.cache_ratio || "\u2014") : "\u2014"
                                    font.family: "JetBrains Mono"; font.weight: Font.Black; font.pixelSize: 17; color: window.sapphire
                                    Layout.alignment: Qt.AlignRight
                                }
                            }
                        }
                    }
                }
            }

            // ── BOTTOM: animated waves + top tools + refresh ──────────────────
            Item {
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                height: 120; z: 20

                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 1.0; color: "#1a000000" }
                    }
                }

                Rectangle { anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; height: 1; color: "#1affffff" }

                Canvas {
                    anchors.fill: parent; z: -1; opacity: 0.12
                    property real p1: 0; property real p2: 0; property real p3: 0
                    NumberAnimation on p1 { from: 0; to: Math.PI * 2; duration: 4000; loops: Animation.Infinite; running: true }
                    NumberAnimation on p2 { from: 0; to: Math.PI * 2; duration: 5500; loops: Animation.Infinite; running: true }
                    NumberAnimation on p3 { from: 0; to: Math.PI * 2; duration: 7000; loops: Animation.Infinite; running: true }
                    onP1Changed: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d"); ctx.clearRect(0,0,width,height); var cy = height / 2
                        ctx.beginPath(); ctx.moveTo(0, cy)
                        for (var x = 0; x <= width; x += 10) ctx.lineTo(x, cy + Math.sin(x/100 + p1) * 20)
                        ctx.strokeStyle = window.blue; ctx.lineWidth = 2; ctx.stroke()
                        ctx.beginPath(); ctx.moveTo(0, cy)
                        for (var x = 0; x <= width; x += 10) ctx.lineTo(x, cy + Math.sin(x/120 - p2) * 26)
                        ctx.strokeStyle = window.mauve; ctx.lineWidth = 2; ctx.stroke()
                        ctx.beginPath(); ctx.moveTo(0, cy)
                        for (var x = 0; x <= width; x += 10) ctx.lineTo(x, cy + Math.sin(x/80 + p3) * 14)
                        ctx.strokeStyle = window.teal; ctx.lineWidth = 2; ctx.stroke()
                    }
                }

                RowLayout {
                    anchors.fill: parent; anchors.margins: 16; spacing: 10

                    Rectangle {
                        width: 34; height: 34; radius: 17; color: window.surface0
                        Text { anchors.centerIn: parent; text: "\uf0eb"; font.family: "Iosevka Nerd Font"; font.pixelSize: 22; color: window.accentColor; Behavior on color { ColorAnimation { duration: 1500 } } }
                    }

                    Text { text: "TOOLS:"; font.family: "JetBrains Mono"; font.weight: Font.Black; font.pixelSize: 13; color: window.overlay0 }

                    Flow {
                        Layout.fillWidth: true; spacing: 5; clip: true
                        Repeater {
                            model: window.claudeData && window.claudeData.today ? (window.claudeData.today.top_tools || []) : []
                            Rectangle {
                                height: 22; radius: 11
                                color: toolMa.containsMouse ? "#2affffff" : "#10ffffff"
                                border.color: "#15ffffff"; border.width: 1
                                width: tlbl.implicitWidth + 16
                                Text {
                                    id: tlbl; anchors.centerIn: parent
                                    text: modelData.name + "  " + modelData.count
                                    font.family: "JetBrains Mono"; font.pixelSize: 13
                                    color: toolMa.containsMouse ? window.text : window.subtext0
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }
                                MouseArea { id: toolMa; anchors.fill: parent; hoverEnabled: true }
                            }
                        }
                    }

                    Rectangle {
                        width: 96; height: 30; radius: 15
                        color: refMa.containsMouse ? window.accentColor : "#1affffff"
                        border.color: window.accentColor; border.width: 1
                        Behavior on color { ColorAnimation { duration: 150 } }
                        RowLayout {
                            anchors.centerIn: parent; spacing: 5
                            Text { text: "Refresh"; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: 15; color: refMa.containsMouse ? window.base : window.text }
                            Text { text: "\uf021"; font.family: "Iosevka Nerd Font"; font.pixelSize: 16; color: refMa.containsMouse ? window.base : window.text }
                        }
                        MouseArea { id: refMa; anchors.fill: parent; hoverEnabled: true; onClicked: dataPoller.running = true }
                    }
                }
            }
        }
    }
}
