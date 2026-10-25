// LeftModules.qml — LEFT (isla izquierda / superior en barra vertical)

import Quickshell
import Quickshell.Wayland

import QtQuick

import "../../../COMMON"
import "../components"

BarHost {
    id: leftModules

    side: "left"

    property real frameArmLeft: 0
    property real frameArmTop: 0

    property int leftMargin: 6

    occupied: modulesRow.occupied
    othersHeight: modulesRow.othersHeight
    pillItem: pill
    pillHovered: leftHover.hovered

    panelOrigin: Qt.point(
        Theme.barAtRight
            ? (leftModules.targetScreen ? leftModules.targetScreen.width : 0) - leftPanel.width
            : leftPanel.margins.left,
        Theme.barAtBottom
            ? (leftModules.targetScreen ? leftModules.targetScreen.height : 0) - leftPanel.margins.bottom - leftPanel.height
            : leftPanel.margins.top)

    spanX: Math.max(leftModules.leftMargin, leftModules.frameArmLeft) + Theme.barEdge
    spanW: pill.width

    islandRect: {
        if (!Theme.islandsMode || !targetScreen) return null
        return {
            x: Math.max(leftModules.leftMargin, leftModules.frameArmLeft) + Theme.barEdge,
            y: Theme.barAtBottom ? targetScreen.height - Theme.barEdge - pill.height : Theme.barEdge,
            w: pill.width,
            h: pill.height
        }
    }

    readonly property real extent: (Theme.barVertical && leftModules.shown)
        ? Theme.barEdge + Math.max(leftModules.leftMargin, leftModules.frameArmTop) + pill.height
        : 0

    PanelWindow {
        id: leftPanel

        screen: leftModules.targetScreen

        anchors {
            top: !Theme.barAtBottom
            bottom: Theme.barAtBottom
            left: !Theme.barAtRight
            right: Theme.barVertical && Theme.barAtRight
        }
        margins.top: Theme.barEdge + (Theme.barVertical ? Math.max(leftModules.leftMargin, leftModules.frameArmTop) : 0)
        margins.bottom: Theme.barEdge

        margins.left: Theme.barVertical ? 0 : Math.max(leftModules.leftMargin, leftModules.frameArmLeft) + Theme.barEdge
        margins.right: 0
        Behavior on margins.left { NumberAnimation { duration: Theme.animDuration(200); easing.type: Easing.OutCubic } }
        Behavior on margins.top { NumberAnimation { duration: Theme.animDuration(200); easing.type: Easing.OutCubic } }

        implicitWidth: Theme.barVertical
            ? Theme.barThickness + Math.round(340 * Theme.barScale)
            : Math.max(pill.width + 20, Math.round(360 * Theme.barScale))
        implicitHeight: Theme.barVertical
            ? pill.height + Math.round(120 * Theme.barScale)
            : Theme.barHeight + Math.round(120 * Theme.barScale)

        color: "transparent"

        visible: true

        WlrLayershell.layer: WM.islandLayer
        WlrLayershell.namespace: "quickshell-left-modules"

        exclusiveZone: -1

        mask: Region { item: pill }

        property var glassPanels: []
        GlassRegion {
          id: blurReg
            panels: leftPanel.glassPanels
            rect: pill
            rectOn: Theme.glassBlurOn && Theme.islandsMode && leftModules.live
            rectRadius: Theme.islandRadius
        }
        Component.onCompleted: {
          if (WM.hasBackgroundBlur) BackgroundEffect.blurRegion = blurReg
        }

        Item {
            id: pill

            HoverHandler { id: leftHover }

            visible: leftModules.live

            x: (Theme.barVertical && Theme.barAtRight) ? parent.width - width : 0

            y: (!Theme.barVertical && Theme.barAtBottom) ? parent.height - height : 0

            width: !leftModules.live ? 0
                : (Theme.barVertical ? Theme.barThickness : modulesRow.implicitWidth * Theme.barScale + 14)
            height: !leftModules.live ? 0
                : (Theme.barVertical ? modulesRow.implicitHeight * Theme.barScale + 14 : Theme.barHeight)

            SkinRect {
                anchors.fill: parent
                radius: Theme.islandRadius
                raised: Theme.cozy && Theme.islandsMode
                depth: 2
                notch: 0
                inkColor: Theme.ink
                color: Theme.islandBg
            }

            BarSectionRow {
                id: modulesRow

                side: "left"
                host: leftModules

                anchors.centerIn: parent
                scale: Theme.barScale
            }
        }

        FusedTip {
            id: tip

            open: leftModules.tipOpen
            text: leftModules.tipText

            z: Theme.islandsMode ? -1 : 0
            island: "left"
            screenName: leftModules.screenName
            hostOriginX: leftModules.panelOrigin.x
            islandRectLocal: Theme.islandsMode
                ? ({ x: pill.x, y: pill.y, w: pill.width, h: pill.height }) : null
            align: "center"
            alignCenter: leftModules.tipCenterX

            x: Theme.barVertical
                ? (Theme.barAtRight ? pill.x - tip.width : Theme.barThickness)
                : (tip.islandActive
                    ? tip.placedAlong
                    : Math.max(Theme.frameSideArm, Math.min(parent.width - width - Theme.frameSideArm, leftModules.tipCenterX - width / 2)))
            y: Theme.barVertical
                ? Math.max(0, Math.min(parent.height - height, leftModules.tipCenterY - height / 2))
                : (tip.hull ? tip.placedDepth
                            : (Theme.barAtBottom ? pill.y - tip.height : Theme.barHeight))

            Behavior on x {
                enabled: tip.shown && !Theme.barVertical && !tip.hull
                NumberAnimation { duration: Theme.animDuration(160); easing.type: Easing.OutCubic }
            }
            Behavior on y {
                enabled: tip.shown && Theme.barVertical
                NumberAnimation { duration: Theme.animDuration(160); easing.type: Easing.OutCubic }
            }
        }
    }
}
