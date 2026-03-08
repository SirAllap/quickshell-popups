import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

// Ported from: ilyamiro/nixos-configuration CalendarPopup.qml
// Adapted: scriptsDir path, weather data source, removed schedule section

Item {
    id: window

    // -------------------------------------------------------------------------
    // KEYBOARD SHORTCUTS
    // -------------------------------------------------------------------------
    Shortcut {
        sequence: "Left"
        onActivated: {
            if (calHover.hovered) {
                window.monthOffset--;
            } else {
                if (window.weatherView > 0) window.weatherView--;
            }
        }
    }

    Shortcut {
        sequence: "Right"
        onActivated: {
            if (calHover.hovered) {
                window.monthOffset++;
            } else {
                if (window.weatherView < 4 && window.weatherData) window.weatherView++;
            }
        }
    }

    // ── Theme (dynamic — reads ~/.config/omarchy/current/theme/colors.toml) ──
    Theme { id: theme }
    readonly property color base:     theme.base
    readonly property color mantle:   theme.mantle
    readonly property color crust:    theme.crust
    readonly property color text:     theme.text
    readonly property color subtext1: theme.subtext1
    readonly property color subtext0: theme.subtext0
    readonly property color overlay2: theme.overlay2
    readonly property color overlay1: theme.overlay1
    readonly property color overlay0: theme.overlay0
    readonly property color surface2: theme.surface2
    readonly property color surface1: theme.surface1
    readonly property color surface0: theme.surface0
    readonly property color mauve:    theme.mauve
    readonly property color pink:     theme.pink
    readonly property color blue:     theme.blue
    readonly property color sapphire: theme.sapphire
    readonly property color peach:    theme.peach
    readonly property color yellow:   theme.yellow
    readonly property color teal:     theme.teal
    readonly property color green:    theme.green
    readonly property color red:      theme.red

    readonly property string scriptsDir: Quickshell.env("HOME") + "/.config/quickshell/weather"

    // -------------------------------------------------------------------------
    // TIME OF DAY DYNAMIC COLORS
    // -------------------------------------------------------------------------
    readonly property color timeColor: {
        let h = window.currentTime.getHours();
        if (h >= 5 && h < 12) return window.peach;
        if (h >= 12 && h < 17) return window.sapphire;
        if (h >= 17 && h < 21) return window.mauve;
        return window.blue;
    }

    readonly property color timeAccent: {
        let h = window.currentTime.getHours();
        if (h >= 5 && h < 12) return window.yellow;
        if (h >= 12 && h < 17) return window.teal;
        if (h >= 17 && h < 21) return window.pink;
        return window.mauve;
    }

    // -------------------------------------------------------------------------
    // ANIMATIONS & INTRO
    // -------------------------------------------------------------------------
    property real introState: 0.0
    Behavior on introState { NumberAnimation { duration: 1200; easing.type: Easing.OutExpo } }

    property real globalOrbitAngle: 0
    NumberAnimation on globalOrbitAngle {
        from: 0; to: Math.PI * 2; duration: 90000; loops: Animation.Infinite; running: true
    }

    // -------------------------------------------------------------------------
    // STATE & TIME (WITH SECOND PULSE)
    // -------------------------------------------------------------------------
    property var currentTime: new Date()
    property real currentEpoch: currentTime.getTime() / 1000

    property real secondPulse: 1.0
    NumberAnimation on secondPulse {
        id: pulseReset
        to: 1.0; duration: 600; easing.type: Easing.OutQuint; running: false
    }

    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: {
            window.currentTime = new Date();
            window.secondPulse = 1.06;
            pulseReset.start();

            if (window.currentTime.getHours() === 0 && window.currentTime.getMinutes() === 0 && window.currentTime.getSeconds() === 0) {
                updateCalendarGrid();
            }
        }
    }

    // -------------------------------------------------------------------------
    // WEATHER DATA & DYNAMIC TIME CALCULATION
    // -------------------------------------------------------------------------
    property var weatherData: null
    property int weatherView: 0
    property color activeWeatherHex: weatherData && weatherData.forecast && weatherData.forecast[weatherView] ? weatherData.forecast[weatherView].hex : window.mauve

    property int activeHourIndex: {
        if (window.weatherView !== 0 || !window.weatherData || !window.weatherData.forecast || !window.weatherData.forecast[0] || !window.weatherData.forecast[0].hourly) return -1;

        let ch = window.currentTime.getHours();
        let hrArr = window.weatherData.forecast[0].hourly.slice(0, 8);
        let bestIdx = -1;
        let minDiff = 999;

        for (let i = 0; i < hrArr.length; i++) {
            let timeStr = hrArr[i].time || "00:00";
            let h = parseInt(timeStr.split(":")[0]);
            let diff = Math.abs(h - ch);
            if (diff < minDiff) {
                minDiff = diff;
                bestIdx = i;
            }
        }
        return bestIdx !== -1 ? bestIdx : 0;
    }

    Process {
        id: weatherPoller
        command: ["python3", window.scriptsDir + "/weather_calendar.py"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = this.text.trim();
                if (txt !== "") {
                    try { window.weatherData = JSON.parse(txt); } catch(e) {}
                }
            }
        }
    }

    Timer {
        interval: 300000
        running: true; repeat: true
        onTriggered: weatherPoller.running = true
    }

    // -------------------------------------------------------------------------
    // CALENDAR GRID LOGIC
    // -------------------------------------------------------------------------
    property int monthOffset: 0
    property string targetMonthName: ""
    ListModel { id: calendarModel }

    function updateCalendarGrid() {
        let d = new Date(window.currentTime.getTime());
        d.setDate(1);
        d.setMonth(d.getMonth() + window.monthOffset);

        let targetMonth = d.getMonth();
        let targetYear = d.getFullYear();

        let actualToday = new Date();
        let isRealCurrentMonth = (actualToday.getMonth() === targetMonth && actualToday.getFullYear() === targetYear);
        let todayDate = actualToday.getDate();

        window.targetMonthName = Qt.formatDateTime(d, "MMMM yyyy");

        let firstDay = new Date(targetYear, targetMonth, 1).getDay();
        firstDay = (firstDay === 0) ? 6 : firstDay - 1;

        let daysInMonth = new Date(targetYear, targetMonth + 1, 0).getDate();
        let daysInPrevMonth = new Date(targetYear, targetMonth, 0).getDate();

        calendarModel.clear();

        for (let i = firstDay - 1; i >= 0; i--) {
            calendarModel.append({ dayNum: (daysInPrevMonth - i).toString(), isCurrentMonth: false, isToday: false });
        }
        for (let i = 1; i <= daysInMonth; i++) {
            calendarModel.append({ dayNum: i.toString(), isCurrentMonth: true, isToday: (isRealCurrentMonth && i === todayDate) });
        }
        let remaining = 42 - calendarModel.count;
        for (let i = 1; i <= remaining; i++) {
            calendarModel.append({ dayNum: i.toString(), isCurrentMonth: false, isToday: false });
        }
    }

    onMonthOffsetChanged: updateCalendarGrid()

    Component.onCompleted: {
        introState = 1.0;
        updateCalendarGrid();
    }

    // -------------------------------------------------------------------------
    // UI LAYOUT
    // -------------------------------------------------------------------------
    Item {
        anchors.fill: parent
        scale: 0.90 + (0.10 * introState)
        opacity: introState

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: window.base
            clip: true

            // =======================================================
            // AMBIENT WIDGET COLOR BLOBS
            // =======================================================
            Item {
                anchors.fill: parent
                z: -1

                Rectangle {
                    width: 800; height: 800; radius: 400
                    x: (parent.width / 2 - width / 2) + Math.cos(window.globalOrbitAngle * 1.5) * 200
                    y: (parent.height / 2 - height / 2) + Math.sin(window.globalOrbitAngle * 1.5) * 150
                    color: window.activeWeatherHex
                    opacity: 0.05
                    Behavior on color { ColorAnimation { duration: 1500 } }
                }

                Rectangle {
                    width: 700; height: 700; radius: 350
                    x: (parent.width / 2 - width / 2) + Math.sin(window.globalOrbitAngle * -1.2) * 250
                    y: (parent.height / 2 - height / 2) + Math.cos(window.globalOrbitAngle * -1.2) * 200
                    color: window.timeColor
                    opacity: 0.04
                    Behavior on color { ColorAnimation { duration: 1500 } }
                }

                Rectangle {
                    width: 600; height: 600; radius: 300
                    x: (parent.width / 2 - width / 2) + Math.cos(window.globalOrbitAngle * 2.0) * -150
                    y: (parent.height / 2 - height / 2) + Math.sin(window.globalOrbitAngle * 2.0) * -100
                    color: window.timeAccent
                    opacity: 0.04
                    Behavior on color { ColorAnimation { duration: 1500 } }
                }
            }

            // =======================================================
            // AMBIENT WEATHER BACKGROUND ORBITS
            // =======================================================
            Repeater {
                model: 2
                Rectangle {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -100
                    width: 500 + index * 300
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.color: window.activeWeatherHex
                    border.width: 1
                    opacity: 0.04
                    transform: Rotation {
                        origin.x: width / 2; origin.y: height / 2
                        angle: window.globalOrbitAngle * (180 / Math.PI) * (index === 0 ? 0.8 : -0.5)
                    }
                    Canvas {
                        anchors.fill: parent
                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0,0,width,height);
                            ctx.beginPath();
                            ctx.arc(width/2, height/2, width/2-1, 0, Math.PI*2);
                            ctx.strokeStyle = window.activeWeatherHex;
                            ctx.lineWidth = 6;
                            ctx.setLineDash([30, 80]);
                            ctx.stroke();
                        }
                    }
                }
            }

            // Giant faint background weather icon
            Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -100
                text: window.weatherData && window.weatherData.forecast[window.weatherView] ? window.weatherData.forecast[window.weatherView].icon : ""
                font.family: "Iosevka Nerd Font"
                font.pixelSize: 800
                color: window.activeWeatherHex
                opacity: 0.03 + (0.01 * Math.sin(window.globalOrbitAngle * 4))
                z: 0
                Behavior on color { ColorAnimation { duration: 1500 } }

                property real drift: 0
                SequentialAnimation on drift {
                    loops: Animation.Infinite
                    NumberAnimation { to: -20; duration: 6000; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0; duration: 6000; easing.type: Easing.InOutSine }
                }
                transform: Translate { y: parent.drift }
            }

            // =======================================================
            // CENTRAL HERO: CLOCK + 3D ORBITAL HOURLY FORECAST
            // =======================================================
            Item {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -100
                width: 1; height: 1
                z: 5

                property real levitation: 0
                SequentialAnimation on levitation {
                    loops: Animation.Infinite
                    NumberAnimation { to: -15; duration: 4000; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0; duration: 4000; easing.type: Easing.InOutSine }
                }
                transform: Translate { y: parent.levitation }

                // 3D ellipse orbit track
                Canvas {
                    z: -10
                    x: -320
                    y: -140
                    width: 640
                    height: 280
                    opacity: 0.25
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        ctx.beginPath();
                        for (var i = 0; i <= Math.PI * 2; i += 0.05) {
                            var xx = width/2 + Math.cos(i) * 320;
                            var yy = height/2 + Math.sin(i) * 140;
                            if (i === 0) ctx.moveTo(xx, yy); else ctx.lineTo(xx, yy);
                        }
                        ctx.strokeStyle = window.activeWeatherHex;
                        ctx.lineWidth = 1.5;
                        ctx.setLineDash([4, 10]);
                        ctx.stroke();
                    }
                    Behavior on opacity { NumberAnimation { duration: 1500 } }
                }

                // Core Clock
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 0
                    z: 0
                    scale: 0.95 + (0.05 * window.secondPulse)

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 2

                        Text {
                            text: Qt.formatTime(window.currentTime, "HH:mm")
                            font.family: "JetBrains Mono"
                            font.weight: Font.Black
                            font.pixelSize: 84
                            color: window.text
                            style: Text.Outline; styleColor: "#40000000"
                        }
                        Text {
                            text: Qt.formatTime(window.currentTime, ":ss")
                            font.family: "JetBrains Mono"
                            font.weight: Font.Bold
                            font.pixelSize: 32
                            color: window.activeWeatherHex
                            Layout.alignment: Qt.AlignBottom
                            Layout.bottomMargin: 15
                            opacity: window.secondPulse > 1.02 ? 1.0 : 0.6
                            style: Text.Outline; styleColor: "#40000000"
                            Behavior on color { ColorAnimation { duration: 1000 } }
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: Qt.formatDateTime(window.currentTime, "dddd, MMMM dd")
                        font.family: "JetBrains Mono"
                        font.weight: Font.Bold
                        font.pixelSize: 16
                        color: window.subtext0
                        opacity: 0.9
                    }
                }

                // TRUE 3D ORBITAL HOURLY FORECAST
                Repeater {
                    id: hourRepeater
                    model: window.weatherData && window.weatherData.forecast[window.weatherView] && window.weatherData.forecast[window.weatherView].hourly ? window.weatherData.forecast[window.weatherView].hourly.slice(0, 8) : []

                    delegate: Item {
                        property int mCount: hourRepeater.count
                        property bool isToday: window.weatherView === 0
                        property bool isHighlighted: isToday && index === window.activeHourIndex

                        property real rx: 320
                        property real ry: 140

                        property int relIdx: isToday ? (index - window.activeHourIndex) : index

                        property real targetAngleDeg: isToday ? (65 + (relIdx * 30)) : (index * (360 / Math.max(1, mCount)))

                        property real orbitOffset: isToday ? 0 : (window.globalOrbitAngle * (180 / Math.PI) * -1.5)
                        property real osc: isToday ? (Math.sin(window.globalOrbitAngle * 10 + index) * 5) : 0

                        property real rad: (targetAngleDeg + orbitOffset + osc) * (Math.PI / 180)

                        x: Math.cos(rad) * rx - width/2
                        y: Math.sin(rad) * ry - height/2
                        z: Math.sin(rad) * 100

                        scale: isHighlighted ? 1.4 : (isToday ? (0.95 + 0.20 * Math.sin(rad)) : (0.90 + 0.25 * Math.sin(rad)))
                        opacity: isHighlighted ? 1.0 : (isToday ? (0.35 + 0.45 * ((Math.sin(rad) + 1) / 2)) : (0.4 + 0.6 * ((Math.sin(rad) + 1) / 2)))

                        width: 56; height: 95

                        Rectangle {
                            anchors.fill: parent
                            radius: 28
                            color: isHighlighted ? window.activeWeatherHex : (hrMa.containsMouse ? "#3affffff" : "#0dffffff")
                            border.color: isHighlighted ? "transparent" : (hrMa.containsMouse ? window.activeWeatherHex : "#1affffff")
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: 200 } }

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 4

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: modelData.time
                                    font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: 10
                                    color: isHighlighted ? window.mantle : (hrMa.containsMouse ? window.text : window.overlay1)
                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: modelData.icon || (window.weatherData && window.weatherData.forecast[window.weatherView] ? window.weatherData.forecast[window.weatherView].icon : "")
                                    font.family: "Iosevka Nerd Font"; font.pixelSize: 18
                                    color: isHighlighted ? window.base : (modelData.hex || window.activeWeatherHex)

                                    transform: Translate { y: hrMa.containsMouse ? -3 : 0 }
                                    Behavior on transform { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter; text: modelData.temp + "°"
                                    font.family: "JetBrains Mono"; font.weight: Font.Black; font.pixelSize: 12
                                    color: isHighlighted ? window.base : window.text
                                }
                            }
                        }
                        MouseArea { id: hrMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor }
                    }
                }
            }

            // =======================================================
            // LEFT WING: FLOATING GLASS CALENDAR
            // =======================================================
            Rectangle {
                id: calendarRect
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.margins: 40
                width: 320
                height: 420
                color: "#05ffffff"
                radius: 8
                border.color: "#1affffff"
                border.width: 1
                z: 10

                HoverHandler { id: calHover }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 25
                    spacing: 15

                    RowLayout {
                        Layout.fillWidth: true

                        Rectangle {
                            width: 32; height: 32; radius: 16
                            color: prevMa.containsMouse ? window.surface1 : "transparent"
                            Text { anchors.centerIn: parent; text: "\ue0b2"; font.family: "Iosevka Nerd Font"; color: window.text; font.pixelSize: 16 }
                            MouseArea { id: prevMa; anchors.fill: parent; hoverEnabled: true; onClicked: window.monthOffset-- }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: window.targetMonthName.toUpperCase()
                            font.family: "JetBrains Mono"
                            font.weight: Font.Black
                            font.pixelSize: 15
                            color: window.text
                            horizontalAlignment: Text.AlignHCenter
                        }

                        Rectangle {
                            width: 32; height: 32; radius: 16
                            color: nextMa.containsMouse ? window.surface1 : "transparent"
                            Text { anchors.centerIn: parent; text: "\ue0b0"; font.family: "Iosevka Nerd Font"; color: window.text; font.pixelSize: 16 }
                            MouseArea { id: nextMa; anchors.fill: parent; hoverEnabled: true; onClicked: window.monthOffset++ }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Repeater {
                            model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                            Text {
                                Layout.fillWidth: true
                                text: modelData
                                font.family: "JetBrains Mono"
                                font.weight: Font.Black
                                font.pixelSize: 12
                                color: window.overlay0
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        columns: 7
                        rowSpacing: 6
                        columnSpacing: 6

                        Repeater {
                            model: calendarModel
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                color: isToday ? window.activeWeatherHex : (dayMa.containsMouse ? "#2affffff" : "transparent")
                                radius: 8
                                scale: dayMa.containsMouse ? 1.2 : 1.0
                                border.color: isToday ? window.surface0 : (dayMa.containsMouse ? window.overlay0 : "transparent")
                                border.width: isToday || dayMa.containsMouse ? 1 : 0

                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }

                                Text {
                                    anchors.centerIn: parent
                                    text: dayNum
                                    font.family: "JetBrains Mono"
                                    font.weight: isToday ? Font.Black : Font.Bold
                                    font.pixelSize: 13
                                    color: isToday ? window.base : (isCurrentMonth ? window.text : window.surface0)
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }

                                MouseArea { id: dayMa; anchors.fill: parent; hoverEnabled: true }
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 20
                        visible: window.monthOffset !== 0

                        Text {
                            anchors.centerIn: parent
                            text: "Return to Today"
                            font.family: "JetBrains Mono"
                            font.weight: Font.Bold
                            font.pixelSize: 11
                            color: resetMa.containsMouse ? window.text : window.overlay0
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                        MouseArea { id: resetMa; anchors.fill: parent; hoverEnabled: true; onClicked: window.monthOffset = 0 }
                    }
                }
            }

            // =======================================================
            // RIGHT WING: WEATHER STATS + DAY NAVIGATION
            // =======================================================
            Item {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 40
                width: 320
                height: 420
                z: 10

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 20

                    RowLayout {
                        Layout.alignment: Qt.AlignRight | Qt.AlignTop
                        spacing: 20

                        MouseArea {
                            id: wPrevMa; width: 30; height: 30; hoverEnabled: true
                            onClicked: if (window.weatherView > 0) window.weatherView--

                            property real pulseOffset: 0
                            SequentialAnimation on pulseOffset {
                                loops: Animation.Infinite; running: true
                                NumberAnimation { to: -3; duration: 1000; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 0; duration: 1000; easing.type: Easing.InOutSine }
                            }

                            Text {
                                anchors.centerIn: parent; text: "\ue0b2"; font.family: "Iosevka Nerd Font"; font.pixelSize: 18
                                color: parent.containsMouse ? window.activeWeatherHex : window.overlay1
                                transform: Translate { x: parent.containsMouse ? -5 : wPrevMa.pulseOffset }
                                Behavior on transform { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
                            }
                        }

                        Text {
                            text: window.weatherData && window.weatherData.forecast[window.weatherView] ? window.weatherData.forecast[window.weatherView].day_full.toUpperCase() : "LOADING..."
                            font.family: "JetBrains Mono"
                            font.weight: Font.Black
                            font.pixelSize: 14
                            color: window.text
                        }

                        MouseArea {
                            id: wNextMa; width: 30; height: 30; hoverEnabled: true
                            onClicked: if (window.weatherView < 4 && window.weatherData) window.weatherView++

                            property real pulseOffset: 0
                            SequentialAnimation on pulseOffset {
                                loops: Animation.Infinite; running: true
                                NumberAnimation { to: 3; duration: 1000; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 0; duration: 1000; easing.type: Easing.InOutSine }
                            }

                            Text {
                                anchors.centerIn: parent; text: "\ue0b0"; font.family: "Iosevka Nerd Font"; font.pixelSize: 18
                                color: parent.containsMouse ? window.activeWeatherHex : window.overlay1
                                transform: Translate { x: parent.containsMouse ? 5 : wNextMa.pulseOffset }
                                Behavior on transform { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.alignment: Qt.AlignRight
                        spacing: -5

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: window.weatherData && window.weatherData.forecast[window.weatherView] ? window.weatherData.forecast[window.weatherView].max + "°" : ""
                            font.family: "JetBrains Mono"
                            font.weight: Font.Black
                            font.pixelSize: 84
                            color: window.text
                            style: Text.Outline; styleColor: "#40000000"
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: window.weatherData && window.weatherData.forecast[window.weatherView] ? window.weatherData.forecast[window.weatherView].desc : ""
                            font.family: "JetBrains Mono"
                            font.weight: Font.Bold
                            font.pixelSize: 18
                            color: window.activeWeatherHex
                            Behavior on color { ColorAnimation { duration: 1000 } }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignRight
                        Layout.rightMargin: 10
                        spacing: 20

                        Repeater {
                            model: window.weatherData && window.weatherData.forecast[window.weatherView] ? [
                                { icon: "\ue30f", val: window.weatherData.forecast[window.weatherView].wind + "m/s", lbl: "WIND",  fill: Math.min(1.0, parseFloat(window.weatherData.forecast[window.weatherView].wind) / 25.0) },
                                { icon: "\ue373", val: window.weatherData.forecast[window.weatherView].humidity + "%", lbl: "HUMID", fill: parseFloat(window.weatherData.forecast[window.weatherView].humidity) / 100.0 },
                                { icon: "\ue319", val: window.weatherData.forecast[window.weatherView].pop + "%",      lbl: "RAIN",  fill: parseFloat(window.weatherData.forecast[window.weatherView].pop) / 100.0 },
                                { icon: "\ue30f", val: window.weatherData.forecast[window.weatherView].feels_like + "°", lbl: "FEELS", fill: Math.max(0.0, Math.min(1.0, (parseFloat(window.weatherData.forecast[window.weatherView].feels_like) + 15) / 55.0)) }
                            ] : []

                            Item {
                                width: 68
                                height: 100
                                scale: gaugeMa.containsMouse ? 1.15 : 1.0
                                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }

                                Rectangle {
                                    anchors.top: parent.top
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 68; height: 68; radius: 34
                                    color: window.activeWeatherHex
                                    opacity: gaugeMa.containsMouse ? 0.3 : 0.0
                                    Behavior on opacity { NumberAnimation { duration: 200 } }
                                }

                                Item {
                                    id: circleItem
                                    width: 68; height: 68
                                    anchors.top: parent.top
                                    anchors.horizontalCenter: parent.horizontalCenter

                                    Canvas {
                                        id: gaugeCanvas
                                        anchors.fill: parent
                                        rotation: -90

                                        property real progress: modelData.fill
                                        property real animProgress: 0

                                        NumberAnimation on animProgress {
                                            to: gaugeCanvas.progress; duration: 1500; easing.type: Easing.OutExpo; running: true
                                        }

                                        onAnimProgressChanged: requestPaint()

                                        onPaint: {
                                            var ctx = getContext("2d");
                                            ctx.clearRect(0, 0, width, height);
                                            var r = width / 2;

                                            ctx.beginPath();
                                            ctx.arc(r, r, r - 4, 0, 2 * Math.PI);
                                            ctx.strokeStyle = "#1affffff";
                                            ctx.lineWidth = 3;
                                            ctx.stroke();

                                            if (animProgress > 0) {
                                                ctx.beginPath();
                                                ctx.arc(r, r, r - 4, 0, animProgress * 2 * Math.PI);
                                                var grad = ctx.createLinearGradient(0, 0, width, height);
                                                grad.addColorStop(0, window.activeWeatherHex);
                                                grad.addColorStop(1, window.blue);
                                                ctx.strokeStyle = grad;
                                                ctx.lineWidth = 4;
                                                ctx.lineCap = "round";
                                                ctx.stroke();
                                            }
                                        }
                                        Behavior on progress { NumberAnimation { duration: 1000; easing.type: Easing.OutExpo } }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.val
                                        font.family: "JetBrains Mono"
                                        font.weight: Font.Black
                                        font.pixelSize: 13
                                        color: window.text
                                    }
                                }

                                RowLayout {
                                    anchors.bottom: parent.bottom
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: 4

                                    Text {
                                        text: modelData.icon
                                        font.family: "Iosevka Nerd Font"
                                        font.pixelSize: 12
                                        color: gaugeMa.containsMouse ? window.activeWeatherHex : window.overlay0
                                        Behavior on color { ColorAnimation { duration: 200 } }
                                    }
                                    Text {
                                        text: modelData.lbl
                                        font.family: "JetBrains Mono"
                                        font.weight: Font.Bold
                                        font.pixelSize: 10
                                        color: window.overlay0
                                    }
                                }

                                MouseArea { id: gaugeMa; anchors.fill: parent; hoverEnabled: true }
                            }
                        }
                    }
                }
            }

            // =======================================================
            // BOTTOM SECTION: ANIMATED WAVE + DATE/LINK
            // =======================================================
            Item {
                id: bottomSection
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 180
                z: 20

                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 1.0; color: "#1a000000" }
                    }
                }

                Rectangle { anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; height: 1; color: "#1affffff" }

                // Animated sine waves
                Canvas {
                    anchors.fill: parent
                    z: -1
                    opacity: 0.15

                    property real phase1: 0
                    property real phase2: 0
                    property real phase3: 0

                    NumberAnimation on phase1 { from: 0; to: Math.PI * 2; duration: 4000; loops: Animation.Infinite; running: true }
                    NumberAnimation on phase2 { from: 0; to: Math.PI * 2; duration: 5500; loops: Animation.Infinite; running: true }
                    NumberAnimation on phase3 { from: 0; to: Math.PI * 2; duration: 7000; loops: Animation.Infinite; running: true }

                    onPhase1Changed: requestPaint()

                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        var cy = height / 2;

                        ctx.beginPath();
                        ctx.moveTo(0, cy);
                        for(var x = 0; x <= width; x += 10) ctx.lineTo(x, cy + Math.sin(x/100 + phase1) * 30);
                        ctx.strokeStyle = window.mauve;
                        ctx.lineWidth = 2;
                        ctx.stroke();

                        ctx.beginPath();
                        ctx.moveTo(0, cy);
                        for(var x = 0; x <= width; x += 10) ctx.lineTo(x, cy + Math.sin(x/120 - phase2) * 40);
                        ctx.strokeStyle = window.sapphire;
                        ctx.lineWidth = 2;
                        ctx.stroke();

                        ctx.beginPath();
                        ctx.moveTo(0, cy);
                        for(var x = 0; x <= width; x += 10) ctx.lineTo(x, cy + Math.sin(x/80 + phase3) * 20);
                        ctx.strokeStyle = window.peach;
                        ctx.lineWidth = 2;
                        ctx.stroke();
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 25
                    spacing: 15

                    Rectangle {
                        width: 40; height: 40; radius: 20; color: window.surface0
                        Text { anchors.centerIn: parent; text: "\ue21a"; font.family: "Iosevka Nerd Font"; font.pixelSize: 18; color: window.mauve }
                    }

                    Text {
                        text: Qt.formatDateTime(window.currentTime, "dddd, dd MMM yyyy")
                        font.family: "JetBrains Mono"
                        font.weight: Font.Bold
                        font.pixelSize: 12
                        color: window.overlay0
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        width: 120; height: 36; radius: 18
                        color: openWebMa.containsMouse ? window.mauve : "#1affffff"
                        border.color: window.mauve; border.width: 1
                        Behavior on color { ColorAnimation { duration: 150 } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Text { text: "Open Web"; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: 12; color: openWebMa.containsMouse ? window.base : window.text }
                            Text { text: "\ue28c"; font.family: "Iosevka Nerd Font"; font.pixelSize: 14; color: openWebMa.containsMouse ? window.base : window.text }
                        }

                        MouseArea {
                            id: openWebMa; anchors.fill: parent; hoverEnabled: true
                            onClicked: Quickshell.execDetached(["xdg-open", "https://wttr.in/"])
                        }
                    }
                }
            }
        }
    }
}
