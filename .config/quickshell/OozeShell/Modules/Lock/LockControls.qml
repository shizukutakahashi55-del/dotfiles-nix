// LockControls

import QtQuick
import QtQuick.Layouts
import "../../COMMON"
import "../../Services/Mpris"

RowLayout {
  id: root

  property real unit: 1
  property real shrink: 1
  property bool playing: false

  // ── Medidas ──
  readonly property int btnSize: Math.round(36 * root.unit * root.shrink)
  readonly property int playSize: Math.round(46 * root.unit * root.shrink)

  spacing: Math.round(18 * root.unit * root.shrink)

  function glyph(cp) { return String.fromCodePoint(cp) }

  // ── Botones ──
  Repeater {
    model: [
      { cmd: "previous",   icon: 0xF04AE, main: false },
      { cmd: "play-pause", icon: 0,       main: true },
      { cmd: "next",       icon: 0xF04AD, main: false }
    ]

    delegate: Rectangle {
      id: btn
      required property var modelData
      readonly property int size: modelData.main ? root.playSize : root.btnSize

      Layout.preferredWidth: size
      Layout.preferredHeight: size
      radius: Theme.cozy ? 4 : size / 2
      color: modelData.main ? Theme.primary
             : (hit.containsMouse ? Theme.surfaceHigh : Theme.surface)
      border.width: modelData.main ? 0 : 1
      border.color: Qt.rgba(1, 1, 1, 0.14)
      scale: hit.pressed ? 0.92 : (hit.containsMouse ? 1.05 : 1.0)
      Behavior on scale { NumberAnimation { duration: Theme.animDuration(120); easing.type: Easing.OutBack } }
      Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }

      Text {
        anchors.centerIn: parent
        text: btn.modelData.main ? root.glyph(root.playing ? 0xF03E4 : 0xF040A) : root.glyph(btn.modelData.icon)
        color: btn.modelData.main ? Theme.textOnPrimary : Theme.text
        font.pixelSize: Math.round((btn.modelData.main ? 22 : 18) * root.unit * root.shrink)
        font.family: Theme.monoFamily
      }
      MouseArea {
        id: hit
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: MprisBackend.runCtl([btn.modelData.cmd])
      }
    }
  }
}
