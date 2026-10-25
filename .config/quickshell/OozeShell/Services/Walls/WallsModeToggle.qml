// WallsModeToggle — WALLS

import QtQuick
import "../Lang"
import "../../COMMON"

Rectangle {
  id: modeToggle

  required property var walls
  property bool compact: false

  implicitWidth: modeToggle.compact ? 320 : 352
  implicitHeight: modeToggle.compact ? 24 : 26
  radius: Theme.cozy ? 0 : modeToggle.height / 2
  color: Theme.tint(0.08)
  border.color: Theme.tint(0.18)
  border.width: Theme.bw1

  readonly property var modes: [
    { id: "static", label: Translations.t("wallsModeStatic") },
    { id: "live",   label: "▶ " + Translations.t("wallsModeLive") },
    { id: "online", label: "☁ " + Translations.t("wallsModeOnline") },
    { id: "downloaded", label: "⬇ " + Translations.t("wallsModeDownloaded") }
  ]
  readonly property real segW: width / modes.length

  Rectangle {
    y: 2; height: parent.height - 4
    width: modeToggle.segW - 2
    radius: Theme.cozy ? 0 : (modeToggle.height - 4) / 2
    x: 1 + modeToggle.walls.modeIndex * modeToggle.segW
    color: Theme.primary
    Behavior on x { NumberAnimation { duration: Theme.animDuration(180); easing.type: Easing.OutCubic } }
  }

  Repeater {
    model: modeToggle.modes
    delegate: Text {
      required property var modelData
      required property int index
      x: index * modeToggle.segW; width: modeToggle.segW; height: modeToggle.height
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
      elide: Text.ElideRight
      text: modelData.label
      font.pixelSize: 10
      font.family: Theme.fontFamily
      color: modeToggle.walls.mode === modelData.id ? Theme.bg : Theme.tint(0.8)
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: (mouse) => {
      const i = Math.max(0, Math.min(modeToggle.modes.length - 1,
                                    Math.floor(mouse.x / modeToggle.segW)))
      modeToggle.walls.setMode(modeToggle.modes[i].id)
    }
  }
}
