import QtQuick
import QtQuick.Layouts
import "../COMMON"

// PillClock — el reloj de la Pill. Clic → transforma la Pill en Dashboard
// (AppState.toggleDashboard), como pide la especificación: no hay tooltip
// de calendario ni popup propio, el reloj es el gatillo de la superficie
// de control.
SkinRect {
    id: root

    signal clicked()
    // Clic derecho: abre el Dashboard directo en el Calendario (con ToDo)
    signal rightClicked()
    property bool active: false

    property var now: new Date()

    Layout.preferredWidth: 68
    Layout.preferredHeight: 30
    radius: 10

    color: (mouse.containsMouse || root.active) ? Theme.surface : "transparent"
    Behavior on color { ColorAnimation { duration: 150 } }

    scale: Theme.cozy ? 1.0 : (mouse.pressed ? 0.92 : mouse.containsMouse ? 1.04 : 1.0)
    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }

    Text {
        anchors.centerIn: parent
        text: Qt.formatTime(root.now, "HH:mm")
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fs(15)

        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: root.now = new Date()
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouseEv => {
            if (mouseEv.button === Qt.RightButton) root.rightClicked()
            else root.clicked()
        }
    }
}
