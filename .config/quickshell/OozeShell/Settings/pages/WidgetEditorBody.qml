// WidgetEditorBody — cuerpo de edición de un widget: estilo, monitor, posición y tamaño, y opciones agrupadas. Lo usan WidgetsPage y WidgetQuickSettings.

import Quickshell
import QtQuick
import QtQuick.Layouts
import ".."
import "../../COMMON"
import "../../Services/Lang"
import "../../Modules/Widgets"

ColumnLayout {
  id: body

  property string widgetId: ""
  property bool topDivider: true

  readonly property var cfg: WidgetConfig.byId[body.widgetId] ?? null
  readonly property var entry: body.cfg ? WidgetRegistry.get(body.cfg.type) : null
  readonly property var defKeys: body.entry ? Object.keys(body.entry.defaults ?? {}) : []
  readonly property var shownKeys: body.cfg
    ? body.defKeys.filter(k => WidgetRegistry.optionVisible(body.cfg.type, body.cfg.style, k)) : []
  readonly property var appearanceKeys: WidgetRegistry.appearanceKeys.filter(k => body.shownKeys.indexOf(k) >= 0)
  readonly property var behaviorKeys: body.shownKeys.filter(k => WidgetRegistry.appearanceKeys.indexOf(k) < 0)

  function tr(prefix, id, fallback) {
    const k = prefix + id
    const t = Translations.t(k)
    return t === k ? (fallback ?? id) : t
  }

  component PosCell: RowLayout {
    id: cell
    property string label: ""
    property int value: 0
    property int min: 0
    property int max: 4000
    signal edited(int v)

    Layout.fillWidth: true
    spacing: 8

    Text {
      Layout.preferredWidth: Math.round(44 * Theme.settingsTextScale)
      text: cell.label
      elide: Text.ElideRight
      color: Theme.text
      font.pixelSize: Theme.sfs(11)
      font.family: Theme.fontFamily
    }
    NumberStepper {
      Layout.fillWidth: true
      Layout.preferredHeight: 34
      value: cell.value
      min: cell.min; max: cell.max; step: 10; suffix: " px"
      onEdited: v => cell.edited(v)
    }
  }

  visible: body.cfg !== null
  Layout.fillWidth: true
  spacing: 0

  Rectangle {
    visible: body.topDivider
    Layout.fillWidth: true
    Layout.preferredHeight: 1
    color: Theme.divider
  }

  SettingsNote {
    visible: body.entry !== null && body.entry.needsNative && !Theme.nativeActive
    kind: "error"
    text: Translations.t("wgNeedsNative")
  }

  SettingsRow {
    titleKey: "wgStyle"
    stacked: true
    SettingsChips {
      model: (body.entry ? body.entry.styles : []).map(s => ({ value: s, label: body.tr("wgStyle_", s) }))
      current: body.cfg ? body.cfg.style : ""
      onPicked: v => WidgetConfig.setStyle(body.widgetId, v)
    }
  }

  SettingsRow {
    visible: Quickshell.screens.length > 1
    titleKey: "wgMonitor"
    stacked: true
    SettingsChips {
      model: [{ value: "", label: Translations.t("wgMonitorAuto") }]
        .concat(Quickshell.screens.map(s => ({ value: s.name, label: s.name })))
      current: body.cfg ? body.cfg.monitor : ""
      onPicked: v => WidgetConfig.update(body.widgetId, { monitor: v })
    }
  }

  SettingsRow {
    titleKey: "wgPosition"
    stacked: true

    GridLayout {
      Layout.fillWidth: true
      columns: 2
      columnSpacing: 12
      rowSpacing: 6

      PosCell {
        label: "X"
        value: body.cfg ? body.cfg.x : 0
        min: -2000; max: 20000
        onEdited: v => WidgetConfig.update(body.widgetId, { x: v })
      }
      PosCell {
        label: "Y"
        value: body.cfg ? body.cfg.y : 0
        min: -2000; max: 20000
        onEdited: v => WidgetConfig.update(body.widgetId, { y: v })
      }
      PosCell {
        label: Translations.t("wgWidth")
        value: body.cfg ? body.cfg.w : 0
        min: 40; max: 4000
        onEdited: v => WidgetConfig.update(body.widgetId, { w: v })
      }
      PosCell {
        label: Translations.t("wgHeight")
        value: body.cfg ? body.cfg.h : 0
        min: 40; max: 4000
        onEdited: v => WidgetConfig.update(body.widgetId, { h: v })
      }
    }
  }

  WidgetOptionGroup {
    widgetId: body.widgetId
    titleKey: "wgAppearance"
    keys: body.appearanceKeys
  }
  WidgetOptionGroup {
    widgetId: body.widgetId
    titleKey: "wgBehavior"
    keys: body.behaviorKeys
  }
}
