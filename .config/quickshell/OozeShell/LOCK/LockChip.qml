// LockChip — aviso en píldora bajo el campo de contraseña (Caps Lock, error…).
// Aparece/desaparece desplegando su altura, así lo de abajo no salta. `pulse` cambia → un pequeño destello (para llamar la atención al cambiar).

import QtQuick
import "../COMMON"

Item {
  id: root

  property bool shown: false
  property string text: ""
  property string icon: ""
  property color tone: Theme.primary
  property real unit: 1
  property int pulse: 0

  readonly property int chipH: Math.round(34 * unit)
  readonly property int gap: Math.round(10 * unit)

  implicitWidth: body.width
  implicitHeight: root.shown ? root.chipH + root.gap : 0
  Behavior on implicitHeight {
    NumberAnimation { duration: Theme.animDuration(200); easing.type: Easing.OutCubic }
  }
  visible: implicitHeight > 0.5
  opacity: root.shown ? 1 : 0
  Behavior on opacity { NumberAnimation { duration: Theme.animDuration(160) } }

  SkinRect {
    id: body
    anchors.bottom: parent.bottom
    anchors.horizontalCenter: parent.horizontalCenter
    height: root.chipH
    width: row.implicitWidth + Math.round(30 * root.unit)
    radius: height / 2
    color: Qt.rgba(root.tone.r, root.tone.g, root.tone.b, 0.16)
    border.width: 1
    border.color: Qt.rgba(root.tone.r, root.tone.g, root.tone.b, 0.6)
    inkColor: root.tone
    scale: root.shown ? 1 : 0.92
    Behavior on scale { NumberAnimation { duration: Theme.animDuration(200); easing.type: Easing.OutCubic } }

    Row {
      id: row
      anchors.centerIn: parent
      spacing: Math.round(8 * root.unit)

      Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: root.icon !== ""
        text: root.icon
        color: root.tone
        font.pixelSize: Math.round(17 * root.unit)
        font.bold: true
        font.family: Theme.fontFamily
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.text
        color: root.tone
        font.pixelSize: Math.round(14 * root.unit)
        font.bold: true
        font.family: Theme.fontFamily
      }
    }
  }

  SequentialAnimation {
    id: flash
    NumberAnimation { target: body; property: "scale"; to: 1.07; duration: Theme.animDuration(90); easing.type: Easing.OutCubic }
    NumberAnimation { target: body; property: "scale"; to: 1.0;  duration: Theme.animDuration(180); easing.type: Easing.OutBack }
  }
  onPulseChanged: if (root.shown) flash.restart()
}
