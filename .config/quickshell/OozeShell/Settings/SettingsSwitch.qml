// SettingsSwitch — interruptor ON/OFF. Es el único control para opciones booleanas en todas las páginas.

import QtQuick
import QtQuick.Layouts
import "../COMMON"

Item {
  id: sw

  property bool checked: false

  signal toggled()

  readonly property int trackW: Theme.cozy ? 36 : 48
  readonly property int trackH: Theme.cozy ? 20 : 28
  readonly property real thumb: Theme.cozy ? 14 : (sw.checked ? 20 : (area.pressed ? 18 : 14))

  Layout.preferredWidth: sw.trackW
  Layout.preferredHeight: sw.trackH
  Layout.alignment: Qt.AlignVCenter
  implicitWidth: sw.trackW
  implicitHeight: sw.trackH

  SkinRect {
    anchors.fill: parent
    radius: sw.trackH / 2
    color: sw.checked ? Theme.primary : (Theme.cozy ? Theme.surfaceHigh : MdTokens.well)
    border.width: (!sw.checked && !Theme.cozy) ? 2 : 0
    border.color: Theme.subtext
    Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }

    SkinRect {
      width: sw.thumb
      height: sw.thumb
      radius: sw.thumb / 2
      anchors.verticalCenter: parent.verticalCenter
      x: sw.checked ? parent.width - width - (sw.trackH - width) / 2 : (sw.trackH - width) / 2
      color: sw.checked ? Theme.textOnPrimary : Theme.subtext
      Behavior on x { NumberAnimation { duration: Theme.animDuration(180); easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
      Behavior on width { NumberAnimation { duration: Theme.animDuration(140) } }
      Behavior on height { NumberAnimation { duration: Theme.animDuration(140) } }
      Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }

      Text {
        anchors.centerIn: parent
        visible: sw.checked && !Theme.cozy
        text: "󰄬"
        color: Theme.primary
        font.family: Theme.monoFamily
        font.pixelSize: 13
      }
    }
  }

  MouseArea {
    id: area
    anchors.fill: parent
    enabled: sw.enabled
    cursorShape: Qt.PointingHandCursor
    onClicked: sw.toggled()
  }
}
