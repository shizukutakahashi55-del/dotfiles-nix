// PillClock.qml — PILL

import QtQuick
import QtQuick.Layouts
import "../../COMMON"


SkinRect {
    id: root

    signal clicked()

    signal rightClicked()
    property bool active: false

    property var now: new Date()

    Layout.preferredWidth: Math.max(face.clockStyle === "classic" ? 68 : 44, face.implicitWidth + 22)
    Layout.preferredHeight: 30
    radius: 10

    color: (mouse.containsMouse || root.active) ? Theme.surface : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }

    scale: Theme.cozy ? 1.0 : (mouse.pressed ? 0.92 : mouse.containsMouse ? 1.04 : 1.0)
    Behavior on scale { NumberAnimation { duration: Theme.animDuration(160); easing.type: Easing.OutBack } }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    ClockFace {
        id: face
        anchors.centerIn: parent
        clockStyle: Theme.barClockStyleEffective
        vertical: false
        now: root.now
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
