// LockDashboard

import QtQuick
import QtQuick.Layouts
import "../../COMMON"

Item {
  id: root

  property real unit: 1
  property bool active: true
  property int panelWidth: Math.round(340 * root.unit)
  property real maxHeight: 0

  property bool weatherOn: true
  property string city: ""
  property bool fahrenheit: false
  property bool forecast: true
  property int days: 5
  property bool tintOn: true

  property bool mediaOn: true
  property bool showCover: true
  property bool onlyPlaying: false
  property bool visualizer: true

  property string notifMode: "apps"
  property int notifMax: 4

  readonly property bool anyShown: weather.shown || media.shown || notifs.shown

  // ── Geometría ──
  width: root.panelWidth
  height: stack.implicitHeight
  visible: root.active && glass.opacity > 0
  scale: root.maxHeight > 0 && root.height > root.maxHeight ? root.maxHeight / root.height : 1

  // ── Entrada ──
  opacity: 0
  transform: Translate { id: rise; y: Math.round(18 * root.unit) }
  Component.onCompleted: enterAnim.start()

  ParallelAnimation {
    id: enterAnim
    PauseAnimation { duration: Theme.animDuration(140) }
    NumberAnimation { target: root; property: "opacity"; to: 1
      duration: Theme.animDuration(300); easing.type: Easing.OutCubic }
    NumberAnimation { target: rise; property: "y"; to: 0
      duration: Theme.animDuration(440); easing.type: Easing.OutCubic }
  }

  // ── Panel ──
  SkinRect {
    id: glass
    anchors.fill: parent
    radius: Theme.cozy ? Theme.cardRadius : Theme.cardRadius + Math.round(6 * root.unit)
    color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.6)
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.14)
    opacity: root.anyShown ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.animDuration(280); easing.type: Easing.OutCubic } }
  }

  // ── Velo de color ──
  Rectangle {
    visible: root.tintOn && !Theme.cozy && weather.shown
    x: 0
    y: 0
    width: parent.width
    height: weather.height + Math.round(36 * root.unit)
    radius: glass.radius
    gradient: Gradient {
      orientation: Gradient.Vertical
      GradientStop { position: 0.0; color: Qt.rgba(weather.tint.r, weather.tint.g, weather.tint.b, 0.26) }
      GradientStop { position: 0.7; color: Qt.rgba(weather.tint.r, weather.tint.g, weather.tint.b, 0.04) }
      GradientStop { position: 1.0; color: "transparent" }
    }
  }

  // ── Secciones ──
  ColumnLayout {
    id: stack
    anchors { left: parent.left; right: parent.right; top: parent.top }
    spacing: 0

    LockDashWeather {
      id: weather
      unit: root.unit
      active: root.weatherOn
      city: root.city
      fahrenheit: root.fahrenheit
      forecast: root.forecast
      days: root.days
    }

    LockDashMedia {
      id: media
      unit: root.unit
      divider: weather.shown
      active: root.mediaOn
      showCover: root.showCover
      onlyPlaying: root.onlyPlaying
      visualizer: root.visualizer
    }

    LockDashNotifs {
      id: notifs
      unit: root.unit
      divider: weather.shown || media.shown
      active: root.notifMode !== "off"
      mode: root.notifMode
      maxItems: root.notifMax
    }
  }
}
