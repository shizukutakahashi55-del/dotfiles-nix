// RightModules — isla derecha (inferior en barra vertical).

import Quickshell
import Quickshell.Wayland
import QtQuick

import "../../../COMMON"
import "../components"

BarHost {
  id: rightModules

  side: "right"

  property real frameArmRight: 0
  property real frameArmBottom: 0

  property int rightMargin: 6

  occupied: modulesRow.occupied
  othersHeight: modulesRow.othersHeight
  pillItem: pill
  pillHovered: rightHover.hovered

  panelOrigin: Qt.point(
    (!Theme.barVertical || Theme.barAtRight)
      ? (rightModules.targetScreen ? rightModules.targetScreen.width : 0) - rightPanel.margins.right - rightPanel.width
      : rightPanel.margins.left,
    (Theme.barAtBottom || Theme.barVertical)
      ? (rightModules.targetScreen ? rightModules.targetScreen.height : 0) - rightPanel.margins.bottom - rightPanel.height
      : rightPanel.margins.top)

  spanX: (rightModules.targetScreen ? rightModules.targetScreen.width : 0)
    - rightModules.rightMargin - Math.max(Theme.barEdge, rightModules.frameArmRight) - pill.width
  spanW: pill.width

  islandRect: {
    if (!Theme.islandsMode || !targetScreen) return null
    return {
      x: targetScreen.width - rightModules.rightMargin - Math.max(Theme.barEdge, rightModules.frameArmRight) - pill.width,
      y: Theme.barAtBottom ? targetScreen.height - Theme.barEdge - pill.height : Theme.barEdge,
      w: pill.width,
      h: pill.height
    }
  }

  readonly property real extent: (Theme.barVertical && rightModules.shown)
    ? rightModules.rightMargin + Math.max(Theme.barEdge, rightModules.frameArmBottom) + pill.height
    : 0

  PanelWindow {
    id: rightPanel

    screen: rightModules.targetScreen

    anchors {
      top: !Theme.barAtBottom && !Theme.barVertical
      bottom: Theme.barAtBottom || Theme.barVertical
      right: !Theme.barVertical || Theme.barAtRight
      left: Theme.barVertical && !Theme.barAtRight
    }
    margins.top: Theme.barEdge

    margins.bottom: Theme.barVertical
      ? rightModules.rightMargin + Math.max(Theme.barEdge, rightModules.frameArmBottom)
      : Theme.barEdge

    margins.right: Theme.barVertical ? 0 : rightModules.rightMargin + Math.max(Theme.barEdge, rightModules.frameArmRight)
    margins.left: 0
    Behavior on margins.right { NumberAnimation { duration: Theme.animDuration(200); easing.type: Easing.OutCubic } }
    Behavior on margins.bottom { NumberAnimation { duration: Theme.animDuration(200); easing.type: Easing.OutCubic } }

    implicitWidth: Theme.barVertical
      ? Theme.barThickness + Math.round(340 * Theme.barScale)
      : Math.max(pill.width + 20, Math.round(380 * Theme.barScale))

    implicitHeight: Theme.barVertical
      ? pill.height + Math.round(260 * Theme.barScale)
      : Theme.barHeight + Math.round(260 * Theme.barScale)

    color: "transparent"
    visible: true

    WlrLayershell.layer: WM.islandLayer
    WlrLayershell.namespace: "quickshell-right-modules"
    exclusiveZone: -1

    mask: Region { item: pill }

    property var glassPanels: []
    GlassRegion {
      id: blurReg
      panels: rightPanel.glassPanels
      rect: pill
      rectOn: Theme.glassBlurOn && Theme.islandsMode && rightModules.live
      rectRadius: Theme.islandRadius
    }
    Component.onCompleted: {
      if (WM.hasBackgroundBlur) BackgroundEffect.blurRegion = blurReg
    }

    Item {
      id: pill

      HoverHandler { id: rightHover }

      visible: rightModules.live

      x: (Theme.barVertical && !Theme.barAtRight) ? 0 : parent.width - width

      y: (Theme.barVertical || Theme.barAtBottom) ? parent.height - height : 0

      width: !rightModules.live ? 0
        : (Theme.barVertical ? Theme.barThickness : modulesRow.implicitWidth * Theme.barScale + 14)
      height: !rightModules.live ? 0
        : (Theme.barVertical ? modulesRow.implicitHeight * Theme.barScale + 14 : Theme.barHeight)

      Rectangle {
        visible: !(Theme.cozy && Theme.islandsMode)
        anchors.fill: parent
        radius: Theme.islandRadius
        color: Theme.islandBg
        border.width: Theme.islandsMode ? Theme.inkWidth : 0
        border.color: Theme.ink
      }

      SkinRect {
        visible: Theme.cozy && Theme.islandsMode
        anchors.fill: parent
        notch: 0
        color: Theme.islandBg
        inkColor: Theme.ink
      }

      BarSectionRow {
        id: modulesRow

        side: "right"
        host: rightModules

        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        scale: Theme.barScale
      }
    }

    FusedTip {
      id: tip

      open: rightModules.tipOpen
      text: rightModules.tipText

      maxDepth: Theme.barVertical
        ? parent.height - 8 - 2 * Theme.tipFlare
        : parent.height - Theme.barFace - 6

      z: Theme.islandsMode ? -1 : 0
      island: "right"
      screenName: rightModules.screenName
      hostOriginX: rightModules.panelOrigin.x
      islandRectLocal: Theme.islandsMode
        ? ({ x: pill.x, y: pill.y, w: pill.width, h: pill.height }) : null
      align: "center"
      alignCenter: rightModules.tipCenterX

      x: Theme.barVertical
        ? (Theme.barAtRight ? pill.x - tip.width : Theme.barThickness)
        : (tip.islandActive
            ? tip.placedAlong
            : Math.max(Theme.frameSideArm, Math.min(parent.width - width - Theme.frameSideArm, rightModules.tipCenterX - width / 2)))
      y: Theme.barVertical
        ? Math.max(0, Math.min(parent.height - height, rightModules.tipCenterY - height / 2))
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
