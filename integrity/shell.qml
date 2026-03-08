import QtQuick
import Quickshell
import Quickshell.Hyprland

ShellRoot {
    FloatingWindow {
        id: win
        title: "qs-integrity-popup"
        color: "transparent"
        implicitWidth: 1000
        implicitHeight: 660
        visible: true

        HyprlandFocusGrab {
            id: grab
            windows: [win]
            active: false
            // Don't close while a fix command (e.g. pkexec dialog) has focus
            onCleared: if (popup.fixingCheck === "") Qt.quit()
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

            IntegrityPopup {
                id: popup
                anchors.fill: parent
            }
        }
    }
}
