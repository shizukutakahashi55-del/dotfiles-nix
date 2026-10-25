// FolderField — campo de ruta de carpeta con explorador integrado y botón para volver al valor por defecto.

import QtQuick
import QtQuick.Layouts
import "../COMMON"
import "../Services/Lang"

ColumnLayout {
  id: fe

  property string placeholder: ""
  property string current: ""
  property bool browsing: false
  signal chosen(string path)

  Layout.fillWidth: true
  spacing: 8

  GridLayout {
    id: bar
    readonly property bool compact: fe.width < 440

    Layout.fillWidth: true
    columns: bar.compact ? 2 : 3
    columnSpacing: 8
    rowSpacing: 8

    SettingsField {
      Layout.columnSpan: bar.compact ? 2 : 1
      Layout.minimumWidth: 0
      placeholder: fe.placeholder
      value: fe.current
      onSubmitted: text => fe.chosen(text)
    }
    SettingsBtn {
      Layout.fillWidth: bar.compact
      icon: "󰉋"
      text: Translations.t("wallsFolderBrowse")
      primary: fe.browsing
      onClicked: {
        if (fe.browsing) { fe.browsing = false; return }
        fe.browsing = true
        const cur = fe.current !== "" ? fe.current : fe.placeholder
        browser.go(cur.replace(/^\$\{?HOME\}?/, browser.home))
      }
    }
    SettingsBtn {
      Layout.fillWidth: bar.compact
      visible: fe.current !== ""
      icon: "󰑐"
      text: Translations.t("wallsFolderReset")
      onClicked: fe.chosen("")
    }
  }

  ImageBrowser {
    id: browser
    visible: fe.browsing
    allowFolder: true
    Layout.fillWidth: true
    Layout.preferredHeight: fe.browsing ? 300 : 0
    onFolderPicked: path => { fe.chosen(path); fe.browsing = false }
    onPicked: path => { fe.chosen(browser.parentOf(path)); fe.browsing = false }
    onCancelled: fe.browsing = false
  }
}
