// WidgetOptionGroup — opciones de un widget agrupadas (Apariencia / Comportamiento): interruptores, números y textos como filas estándar.

import Quickshell
import QtQuick
import QtQuick.Layouts
import ".."
import "../../COMMON"
import "../../Services/Lang"
import "../../Modules/Widgets"

ColumnLayout {
  id: grp

  property string widgetId: ""
  property string titleKey: ""
  property var keys: []

  readonly property var cfg: WidgetConfig.byId[grp.widgetId] ?? null
  readonly property var entry: grp.cfg ? WidgetRegistry.get(grp.cfg.type) : null

  function label(key) {
    const k = "wgOpt_" + key
    const t = Translations.t(k)
    return t === k ? key : t
  }
  function def(key) { return (grp.entry && grp.entry.defaults) ? grp.entry.defaults[key] : undefined }
  function cur(key) {
    const v = grp.cfg ? grp.cfg.options[key] : undefined
    return v === undefined ? grp.def(key) : v
  }
  function rangeOf(key) {
    return (grp.entry && grp.entry.ranges && grp.entry.ranges[key]) ? grp.entry.ranges[key] : [0, 100000, 1]
  }
  function isPicker(key) { return !!(grp.entry && grp.entry.pickers && grp.entry.pickers[key]) }

  readonly property var boolKeys: grp.keys.filter(k => typeof grp.def(k) === "boolean")
  readonly property var numKeys: grp.keys.filter(k => typeof grp.def(k) === "number")
  readonly property var strKeys: grp.keys.filter(k => typeof grp.def(k) === "string")

  visible: grp.keys.length > 0 && grp.entry !== null
  Layout.fillWidth: true
  spacing: 0

  SectionLabel { textScale: Theme.settingsTextScale;
    Layout.fillWidth: true
    Layout.topMargin: 14
    Layout.bottomMargin: 2
    text: Translations.t(grp.titleKey)
    color: Theme.primary
  }

  Repeater {
    model: grp.boolKeys
    delegate: SettingsRow {
      required property string modelData
      title: grp.label(modelData)
      SettingsSwitch {
        checked: grp.cur(modelData) === true
        onToggled: WidgetConfig.setOption(grp.widgetId, modelData, !(grp.cur(modelData) === true))
      }
    }
  }

  Repeater {
    model: grp.numKeys
    delegate: SettingsRow {
      id: numRow
      required property string modelData
      readonly property var range: grp.rangeOf(numRow.modelData)
      title: grp.label(numRow.modelData)
      NumberStepper {
        Layout.fillWidth: false
        Layout.preferredWidth: 140
        Layout.preferredHeight: 34
        value: { const c = grp.cur(numRow.modelData); return typeof c === "number" ? c : 0 }
        min: numRow.range[0]; max: numRow.range[1]; step: numRow.range[2]
        onEdited: v => WidgetConfig.setOption(grp.widgetId, numRow.modelData, v)
      }
    }
  }

  Repeater {
    model: grp.strKeys
    delegate: SettingsRow {
      id: strRow
      required property string modelData
      readonly property bool picker: grp.isPicker(strRow.modelData)
      property bool browsing: false

      title: grp.label(strRow.modelData)
      stacked: true

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 8

        RowLayout {
          Layout.fillWidth: true
          spacing: 8

          SettingsField {
            value: { const c = grp.cur(strRow.modelData); return typeof c === "string" ? c : "" }
            onSubmitted: text => WidgetConfig.setOption(grp.widgetId, strRow.modelData, text.trim())
          }
          SettingsBtn {
            visible: strRow.picker
            icon: "󰉋"
            text: Translations.t("wgBrowse")
            primary: strRow.browsing
            onClicked: {
              strRow.browsing = !strRow.browsing
              if (strRow.browsing) {
                const c = grp.cur(strRow.modelData)
                const p = typeof c === "string" ? c.trim() : ""
                browser.go(p !== "" ? p : Quickshell.env("HOME") + "/Pictures")
              }
            }
          }
        }

        ImageBrowser {
          id: browser
          visible: strRow.browsing
          allowFolder: true
          Layout.fillWidth: true
          Layout.preferredHeight: strRow.browsing ? 300 : 0
          onPicked: path => { WidgetConfig.setOption(grp.widgetId, strRow.modelData, path); strRow.browsing = false }
          onFolderPicked: path => { WidgetConfig.setOption(grp.widgetId, strRow.modelData, path); strRow.browsing = false }
          onCancelled: strRow.browsing = false
        }
        Text {
          visible: strRow.browsing
          Layout.fillWidth: true
          wrapMode: Text.WordWrap
          text: Translations.t("wgBrowseHint")
          color: Theme.subtext
          font.pixelSize: Theme.sfs(10)
          font.family: Theme.fontFamily
        }
      }
    }
  }
}
