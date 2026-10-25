// SettingsIconBtn — botón fantasma de solo ícono (refrescar, copiar...). Con `spinning` el ícono gira mientras algo corre.

import QtQuick
import QtQuick.Layouts
import "../COMMON"

SkinRect {
  id: btn

  property string icon: "󰑐"
  property bool spinning: false

  signal clicked()

  Layout.preferredWidth: 32
  Layout.preferredHeight: 32
  Layout.alignment: Qt.AlignVCenter
  implicitWidth: 32
  implicitHeight: 32
  radius: Theme.cozy ? 4 : 9
  color: btnArea.containsMouse ? (Theme.cozy ? Theme.surfaceHigh : MdTokens.control) : "transparent"
  Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }

  Text {
    anchors.centerIn: parent
    text: btn.icon
    color: Theme.mix(Theme.subtext, Theme.text, 0.4)
    font.pixelSize: Theme.sfs(14)
    font.family: Theme.monoFamily
    RotationAnimation on rotation {
      running: btn.spinning && Theme.uiAnimationsEnabled
      loops: Animation.Infinite
      from: 0; to: 360
      duration: Theme.animDuration(700)
    }
  }

  MouseArea {
    id: btnArea
    anchors.fill: parent
    enabled: btn.enabled
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: btn.clicked()
  }
}
