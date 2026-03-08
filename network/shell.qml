import QtQuick
import Quickshell
import Quickshell.Hyprland

ShellRoot {
    FloatingWindow {
        id: win
        title: "qs-network-popup"
        color: "transparent"
        implicitWidth: 900
        implicitHeight: 700
        visible: true

        // Dismiss on click-outside.
        // Delayed so Hyprland has time to focus the new window first.
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

            NetworkPopup {
                anchors.fill: parent
            }
        }
    }
}
