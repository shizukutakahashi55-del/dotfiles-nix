// BarRevealZone

import Quickshell
import Quickshell.Wayland
import QtQuick
import "../../../COMMON"

PanelWindow {
    id: zone

    property bool suppressed: false
    property bool covered: false

    readonly property real grip: 6
    readonly property bool vertical: Theme.barVertical

    readonly property bool armed: !Theme.barPeek && !zone.suppressed && !zone.covered

    visible: Theme.barHidden
    exclusiveZone: -1
    color: "transparent"

    WlrLayershell.layer: WM.islandLayer
    WlrLayershell.namespace: "oozeshell-bar-reveal"

    anchors {
        top: !Theme.barAtBottom
        bottom: Theme.barAtBottom || Theme.barVertical
        left: !Theme.barVertical || !Theme.barAtRight
        right: !Theme.barVertical || Theme.barAtRight
    }

    implicitWidth: zone.vertical ? zone.grip : 0
    implicitHeight: zone.vertical ? 0 : zone.grip

    mask: Region { item: zone.armed ? hit : null }

    Item {
        id: hit
        anchors.fill: parent

        Rectangle {
            id: handle
            visible: zone.armed
            anchors.centerIn: parent
            width: zone.vertical ? 3 : 56
            height: zone.vertical ? 56 : 3
            radius: 2
            color: Theme.primary
            opacity: area.containsMouse ? 0.95 : 0.4
            Behavior on opacity { NumberAnimation { duration: Theme.animDuration(150); easing.type: Easing.OutCubic } }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onContainsMouseChanged: Theme.edgeHover(containsMouse)
            onClicked: Theme.requestBarPeek("click")
        }
    }
}
