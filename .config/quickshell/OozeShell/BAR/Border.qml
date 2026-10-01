// Border — solo franjas RECTAS (grosor t).
// La deformación/curva queda SOLO en FrameCorner (esquinas).
//

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
    readonly property int r: Math.max(0, Theme.frameCornerRadius)
    readonly property color frameColor: Theme.bg


    readonly property bool showTop:    active && t > 0 && Theme.barPosition !== "top"
    readonly property bool showBottom: active && t > 0 && Theme.barPosition !== "bottom"
    readonly property bool showLeft:   active && t > 0 && Theme.barPosition !== "left"
    readonly property bool showRight:  active && t > 0 && Theme.barPosition !== "right"


    readonly property int endCap: r

    // ── TOP (horizontal, recto) ──
    PanelWindow {
        screen: root.screen
        anchors { top: true; left: true; right: true }
        margins.left: root.endCap
        margins.right: root.endCap
        implicitHeight: root.showTop ? root.t : 0
        exclusiveZone: root.showTop ? root.t : -1
        visible: root.showTop
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "oozeshell-frame-top"

        // Rectángulo puro: sin radius, sin Shape, sin scale
        Rectangle {
            anchors.fill: parent
            color: root.frameColor
            radius: 0
            opacity: root.suppressed ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: Theme.animDuration(150); easing.type: Easing.OutCubic } }
        }
    }

    // ── BOTTOM (horizontal, recto) ──
    // Único lado con la animación de "marco flotante" durante la
    // aplicación de un wallpaper — ver WALLS/WallsFrameFlare.qml.
    PanelWindow {
        screen: root.screen
        anchors { bottom: true; left: true; right: true }
        margins.left: root.endCap
        margins.right: root.endCap
        implicitHeight: root.showBottom ? root.t : 0
        exclusiveZone: root.showBottom ? root.t : -1
        visible: root.showBottom
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "oozeshell-frame-bottom"

        // Mientras se aplica un wallpaper esta franja NO se apaga con el
        // resto de la barra (screenRoot.suppressed): al revés, se queda
        // visible haciendo de indicador — WallsFrameFlare la dibuja
        // "flotando" en vez de pegada a los bordes asi no se glitchea.
        Item {
            anchors.fill: parent
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
        implicitWidth: root.showLeft ? root.t : 0
        exclusiveZone: root.showLeft ? root.t : -1
        visible: root.showLeft
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "oozeshell-frame-left"

        Rectangle {
            anchors.fill: parent
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
        implicitWidth: root.showRight ? root.t : 0
        exclusiveZone: root.showRight ? root.t : -1
        visible: root.showRight
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "oozeshell-frame-right"

        Rectangle {
            anchors.fill: parent
            color: root.frameColor
            radius: 0
            opacity: root.suppressed ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: Theme.animDuration(150); easing.type: Easing.OutCubic } }
        }
    }
}