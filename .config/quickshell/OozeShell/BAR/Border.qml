// Border — solo franjas RECTAS (grosor t).
// La deformación/curva queda SOLO en FrameCorner (esquinas).

import Quickshell
import Quickshell.Wayland
import QtQuick
import "../COMMON"
import "../WALLS"

Item {
    id: root

    required property var screen
    property bool active: false
    property bool suppressed: false


    readonly property int t: Math.max(0, Theme.frameThickness)
    readonly property real tv: Math.max(0, Theme.frameThicknessVis)
    readonly property int winT: Math.max(root.t, Math.ceil(root.tv))
    readonly property int r: Math.max(0, Theme.frameCornerRadius)
    readonly property color frameColor: Theme.bg


    readonly property bool showTop:    active && winT > 0 && Theme.barPosition !== "top"
    readonly property bool showBottom: active && winT > 0 && Theme.barPosition !== "bottom"
    readonly property bool showLeft:   active && winT > 0 && Theme.barPosition !== "left"
    readonly property bool showRight:  active && winT > 0 && Theme.barPosition !== "right"


    readonly property int endCap: r

    // ── TOP (horizontal, recto) ──
    PanelWindow {
        screen: root.screen
        anchors { top: true; left: true; right: true }
        margins.left: root.endCap
        margins.right: root.endCap
        implicitHeight: root.showTop ? root.winT : 0
        exclusiveZone: root.showTop ? root.t : -1
        mask: Region { item: topStrip }
        visible: root.showTop
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "oozeshell-frame-top"


        Rectangle {
            id: topStrip
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: root.tv
            color: root.frameColor
            radius: 0
            opacity: root.suppressed ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: Theme.animDuration(150); easing.type: Easing.OutCubic } }
        }
    }

    // ── BOTTOM (horizontal, recto) ──


    PanelWindow {
        screen: root.screen
        anchors { bottom: true; left: true; right: true }
        margins.left: root.endCap
        margins.right: root.endCap
        implicitHeight: root.showBottom ? root.winT : 0
        exclusiveZone: root.showBottom ? root.t : -1
        mask: Region { item: bottomStrip }
        visible: root.showBottom
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "oozeshell-frame-bottom"


        Item {
            id: bottomStrip
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
            height: root.tv
            opacity: (root.suppressed && !Theme.wallpaperChanging) ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: Theme.animDuration(150); easing.type: Easing.OutCubic } }

            WallsFrameFlare {
                anchors.fill: parent
                fillColor: root.frameColor
            }
        }
    }

    // ── LEFT (vertical, recto) ──
    PanelWindow {
        screen: root.screen
        anchors { top: true; bottom: true; left: true }
        margins.top: root.endCap
        margins.bottom: root.endCap
        implicitWidth: root.showLeft ? root.winT : 0
        exclusiveZone: root.showLeft ? root.t : -1
        mask: Region { item: leftStrip }
        visible: root.showLeft
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "oozeshell-frame-left"

        Rectangle {
            id: leftStrip
            anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
            width: root.tv
            color: root.frameColor
            radius: 0
            opacity: root.suppressed ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: Theme.animDuration(150); easing.type: Easing.OutCubic } }
        }
    }

    // ── RIGHT (vertical, recto) ──
    PanelWindow {
        screen: root.screen
        anchors { top: true; bottom: true; right: true }
        margins.top: root.endCap
        margins.bottom: root.endCap
        implicitWidth: root.showRight ? root.winT : 0
        exclusiveZone: root.showRight ? root.t : -1
        mask: Region { item: rightStrip }
        visible: root.showRight
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "oozeshell-frame-right"

        Rectangle {
            id: rightStrip
            anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
            width: root.tv
            color: root.frameColor
            radius: 0
            opacity: root.suppressed ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: Theme.animDuration(150); easing.type: Easing.OutCubic } }
        }
    }
}
