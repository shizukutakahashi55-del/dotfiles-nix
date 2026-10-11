// SettingsPanelTitle — título de cada categoría de Ajustes avanzados: chip con el ícono de la barra lateral + nombre. (Antes era el inline component

import QtQuick
import QtQuick.Layouts
import "../COMMON"
import "../LANG"

RowLayout {
  id: pt


  property string catId: ""
  property string icon: pt.catId !== "" ? SettingsRegistry.iconOf(pt.catId) : ""
  property string title: pt.catId !== "" ? Translations.t(SettingsRegistry.titleKeyOf(pt.catId)) : ""

  Layout.fillWidth: true
  Layout.bottomMargin: 2
  spacing: 12

  SkinRect {
    Layout.preferredWidth: 36
    Layout.preferredHeight: 36
    radius: 11
    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16)
    Text {
      anchors.centerIn: parent
      text: pt.icon
      color: Theme.primary
      font.pixelSize: Theme.fs(17)
      font.family: Theme.monoFamily
    }
  }
  Text {
    Layout.fillWidth: true
    elide: Text.ElideRight
    text: pt.title
    color: Theme.text
    font.bold: true
    font.pixelSize: Theme.fs(19)
    font.family: Theme.fontFamily
  }
}
