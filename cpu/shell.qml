import QtQuick
import Quickshell
import Quickshell.Hyprland

ShellRoot {
    FloatingWindow {
        id: win
        title: "qs-cpu-popup"
        color: "transparent"
        implicitWidth: 900
        implicitHeight: 680
        visible: true

        HyprlandFocusGrab {
            id: grab
            windows: [win]
            active: false
            onCleared: Qt.quit()
        }
        Timer {
            interval: 500
            running: true
            onTriggered: grab.active = true
        }

        Item {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: Qt.quit()

            CpuPopup {
                anchors.fill: parent
            }
        }
    }
}
