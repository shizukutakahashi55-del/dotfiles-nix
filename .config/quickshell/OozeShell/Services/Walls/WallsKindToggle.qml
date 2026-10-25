// WallsKindToggle — WALLS

import QtQuick
import "../Lang"
import "../../COMMON"

SkinRect {
  id: kind

  required property var walls
  property int fontSize: 12

  readonly property var kinds: [
    { id: "image", label: "󰋩  " + Translations.t("wallsKindImages") },
    { id: "live",  label: "▶  " + Translations.t("wallsKindLive") }
  ]
  readonly property int cur: Theme.onlineKind === "live" ? 1 : 0

  implicitWidth: 230
  notch: 4
  raised: Theme.cozy
  depth: 3
  inkColor: Theme.primary
  color: Theme.bg
  border.color: Theme.primary
  border.width: 1.5

  Rectangle {
    x: 5 + kind.cur * ((kind.width - 10) / 2)
    y: 5
    width: (kind.width - 10) / 2
    height: kind.height - 10
    radius: Theme.cozy ? 0 : height / 2
    color: Theme.primary
    Behavior on x { NumberAnimation { duration: Theme.animDuration(180); easing.type: Easing.OutCubic } }
  }

  Repeater {
    model: kind.kinds
    delegate: Text {
      required property var modelData
      required property int index
      x: 5 + index * ((kind.width - 10) / 2)
      y: 5
      width: (kind.width - 10) / 2
      height: kind.height - 10
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
      text: modelData.label
      font.pixelSize: kind.fontSize
      font.family: Theme.fontFamily
      color: kind.cur === index ? Theme.bg : Theme.tint(0.85)
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: mouse => kind.walls.setKind(mouse.x < kind.width / 2 ? "image" : "live")
  }
}
