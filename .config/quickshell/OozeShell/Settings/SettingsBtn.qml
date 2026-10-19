// SettingsBtn — botón chico de acción / opción para paneles de Ajustes (mismo look que el `component Btn` de AdvancedSettings.qml y de

import QtQuick
import QtQuick.Layouts
import "../COMMON"

SkinRect {
  id: btn

  property string text: ""
  property string icon: ""
  property bool primary: false


  signal clicked()

  implicitHeight: 32
  implicitWidth: btnRow.implicitWidth + 22
  Layout.preferredHeight: 32
  Layout.preferredWidth: btnRow.implicitWidth + 22
  radius: Theme.cozy ? 4 : 9
  opacity: btn.enabled ? 1 : 0.45

  color: btn.primary
    ? (btnArea.containsMouse ? Qt.lighter(Theme.primary, 1.12) : Theme.primary)
    : (Theme.colorfulMode


       ? (btnArea.containsMouse ? Theme.mix(Theme.surfaceHigh, Theme.primary, 0.24) : Theme.surfaceHigh)
       : (btnArea.containsMouse ? Theme.surfaceHigh : Theme.glassCtlBg))

  border.width: btn.primary ? Theme.inkWidth : Theme.bw1
  inkColor: Theme.ink
  border.color: Theme.cozy
    ? Theme.ink
    : (btnArea.containsMouse
       ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.45)
       : (Theme.glassCtl ? Theme.glassEdge : Theme.edge))
  Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
  Behavior on border.color { ColorAnimation { duration: Theme.animDuration(150) } }


  scale: Theme.cozy ? 1.0 : (btnArea.pressed && btn.enabled ? 0.94 : 1.0)
  Behavior on scale { NumberAnimation { duration: Theme.animDuration(140); easing.type: Easing.OutBack } }

  RowLayout {
    id: btnRow
    anchors.centerIn: parent
    anchors.verticalCenterOffset: (Theme.cozy && btnArea.pressed && btn.enabled) ? 2 : 0
    spacing: 6
    Text {
      visible: btn.icon !== ""
      text: btn.icon
      color: btn.primary ? Theme.textOnPrimary : Theme.primary
      font.pixelSize: Theme.sfs(13)
      font.family: Theme.monoFamily
    }
    Text {
      text: btn.text
      color: btn.primary ? Theme.textOnPrimary : Theme.text
      font.pixelSize: Theme.sfs(11)
      font.bold: true
      font.family: Theme.fontFamily
    }
  }

  MouseArea {
    id: btnArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: btn.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: if (btn.enabled) btn.clicked()
  }
}
