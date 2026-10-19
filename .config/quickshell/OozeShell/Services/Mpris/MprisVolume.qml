// MprisVolume — MPRIS

import QtQuick
import "../../COMMON"

Item {
  id: root

  property bool vertical: false
  property real thickness: Theme.ds(28)

  readonly property real value: MprisBackend.currentVolume
  readonly property bool muted: MprisBackend.volumeMuted
  readonly property real shown: area.pressed ? root.dragValue : root.value
  property real dragValue: 0

  implicitWidth: root.vertical ? root.thickness : Theme.ds(200)
  implicitHeight: root.vertical ? Theme.ds(120) : root.thickness

  SkinRect {
    id: iconBox
    width: root.thickness
    height: root.thickness
    radius: root.thickness / 2
    notch: 3
    x: root.vertical ? (root.width - width) / 2 : 0
    y: root.vertical ? root.height - height : (root.height - height) / 2
    color: iconArea.containsMouse ? Theme.surfaceHigh : Theme.surface
    Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }

    Text {
      anchors.centerIn: parent
      text: MprisBackend.volumeIcon
      color: root.muted ? Theme.subtext : Theme.primary
      font.pixelSize: Theme.dfs(14)
      font.family: Theme.monoFamily
    }
    MouseArea {
      id: iconArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: MprisBackend.toggleVolumeMute()
    }
  }

  Item {
    id: slider
    readonly property real gap: Theme.ds(10)
    readonly property bool grabbed: area.containsMouse || area.pressed

    x: root.vertical ? (root.width - width) / 2 : iconBox.width + gap
    y: root.vertical ? 0 : (root.height - height) / 2
    width: root.vertical ? root.thickness : Math.max(0, root.width - iconBox.width - gap)
    height: root.vertical ? Math.max(0, root.height - iconBox.height - gap) : root.thickness

    Item {
      id: bar
      anchors.centerIn: parent
      width: root.vertical ? slider.height : slider.width
      height: root.vertical ? slider.width : slider.height
      rotation: root.vertical ? -90 : 0

      PixelBar {
        visible: Theme.cozy
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: Math.max(12, Theme.ds(16))
        ratio: root.shown
        colorA: Theme.mix(root.muted ? Theme.subtext : Theme.primary, Theme.bg, 0.40)
        colorB: root.muted ? Theme.subtext : Theme.primary
      }

      Rectangle {
        id: track
        visible: !Theme.cozy
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: slider.grabbed ? 8 : 6
        radius: height / 2
        color: Theme.tint(0.12)
        Behavior on height { NumberAnimation { duration: Theme.animDuration(100) } }

        Rectangle {
          width: track.width * Math.max(0, Math.min(1, root.shown))
          height: parent.height
          radius: parent.radius
          color: root.muted ? Theme.subtext : Theme.primary
          Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
        }
        Rectangle {
          x: track.width * Math.max(0, Math.min(1, root.shown)) - width / 2
          anchors.verticalCenter: parent.verticalCenter
          width: slider.grabbed ? 14 : 0
          height: width
          radius: width / 2
          color: Theme.text
          Behavior on width { NumberAnimation { duration: Theme.animDuration(100) } }
        }
      }
    }

    MouseArea {
      id: area
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor

      function ratioAt(mx, my) {
        const r = root.vertical ? 1 - my / height : mx / width
        return Math.max(0, Math.min(1, r))
      }
      function apply(mx, my) {
        root.dragValue = area.ratioAt(mx, my)
        MprisBackend.setVolume(root.dragValue)
      }

      onPressed: mouse => area.apply(mouse.x, mouse.y)
      onPositionChanged: mouse => { if (pressed) area.apply(mouse.x, mouse.y) }
      onReleased: MprisBackend.commitVolume()
      onCanceled: MprisBackend.commitVolume()
      onWheel: wheel => {
        MprisBackend.setVolume(root.value + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
        MprisBackend.commitVolume()
      }
    }
  }
}
