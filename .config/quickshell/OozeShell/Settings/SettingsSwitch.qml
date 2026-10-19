// SettingsSwitch — interruptor ON/OFF. Es el único control para opciones booleanas en todas las páginas.

import QtQuick
import QtQuick.Layouts
import "../COMMON"

Item {
  id: sw

  property bool checked: false

  signal toggled()

  Layout.preferredWidth: 36
  Layout.preferredHeight: 20
  Layout.alignment: Qt.AlignVCenter
  implicitWidth: 36
  implicitHeight: 20

  SkinRect {
    anchors.fill: parent
    radius: 10
    color: sw.checked ? Theme.primary : Theme.surfaceHigh
    Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }

    SkinRect {
      width: 14
      height: 14
      radius: 7
      anchors.verticalCenter: parent.verticalCenter
      x: sw.checked ? 19 : 3
      color: sw.checked ? Theme.textOnPrimary : Theme.subtext
      Behavior on x { NumberAnimation { duration: Theme.animDuration(150); easing.type: Easing.OutCubic } }
      Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
    }
  }

  MouseArea {
    anchors.fill: parent
    enabled: sw.enabled
    cursorShape: Qt.PointingHandCursor
    onClicked: sw.toggled()
  }
}
