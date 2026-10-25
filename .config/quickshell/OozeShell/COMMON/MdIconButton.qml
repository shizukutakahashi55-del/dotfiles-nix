// MdIconButton — COMMON

import QtQuick

Item {
  id: root

  property string glyph: ""
  property string variant: "tonal"
  property real size: 40
  property real glyphSize: 0
  property bool toggled: false
  property bool checkable: false
  property color accent: Theme.primary
  property color onAccent: Theme.textOnPrimary
  property string tip: ""

  signal clicked()

  readonly property bool filled: root.variant === "filled"
  readonly property bool tonal: root.variant === "tonal"
  readonly property bool outlined: root.variant === "outlined"
  readonly property bool lit: root.filled || (root.checkable && root.toggled)
  readonly property real restRadius: root.checkable && !root.toggled ? root.size * 0.32 : root.size / 2
  readonly property real shownRadius: area.pressed ? root.size * 0.22 : root.restRadius

  implicitWidth: root.size
  implicitHeight: root.size
  width: root.size
  height: root.size
  opacity: root.enabled ? 1 : 0.4

  Rectangle {
    id: face
    anchors.fill: parent
    radius: Theme.cozy ? 3 : root.shownRadius
    Behavior on radius { NumberAnimation { duration: Theme.animDuration(180); easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

    color: root.lit ? root.accent
         : root.tonal ? MdTokens.controlStrong
         : "transparent"
    border.width: root.outlined ? 1 : (Theme.cozy ? 2 : ((root.tonal && !root.lit) ? 1 : 0))
    border.color: Theme.cozy ? Theme.ink : ((root.tonal && !root.lit) ? MdTokens.edgeSoft : Theme.withAlpha(Theme.text, 0.4))
    Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }

    Rectangle {
      anchors.fill: parent
      radius: parent.radius
      color: MdTokens.stateLayer(root.lit ? root.onAccent : Theme.text, area.containsMouse, area.pressed)
    }
  }

  Text {
    anchors.centerIn: parent
    text: root.glyph
    color: root.lit ? root.onAccent : (root.tonal ? MdTokens.onContainer : Theme.text)
    font.family: Theme.monoFamily
    font.pixelSize: root.glyphSize > 0 ? root.glyphSize : Math.round(root.size * 0.46)
    Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
  }

  scale: area.pressed ? 0.94 : 1
  Behavior on scale { NumberAnimation { duration: Theme.animDuration(120); easing.type: Easing.OutBack } }

  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    enabled: root.enabled
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
