import QtQuick
import Quickshell
import Quickshell.Hyprland

ShellRoot {
    FloatingWindow {
        id: win
        title: "qs-storage-popup"
        color: "transparent"
        implicitWidth: 900
        implicitHeight: 560
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

            StoragePopup {
                anchors.fill: parent
            }
        }
    }
}
