// WidgetBase — lo único que un widget necesita heredar.

import QtQuick
import "../../COMMON"

Item {
  id: base

  property var cfg: null
  property bool editMode: false


  readonly property bool isWidgetBase: true

  // ─── Blur real ─────────────────────────────────────────────
  property var blurItems: []
  function registerBlur(item) {
    if (base.blurItems.indexOf(item) < 0) base.blurItems = base.blurItems.concat([item])
  }
  function unregisterBlur(item) {
    base.blurItems = base.blurItems.filter(i => i !== item)
  }

  readonly property string widgetId: base.cfg ? base.cfg.id : ""
  readonly property string widgetStyle: base.cfg ? base.cfg.style : ""
  readonly property var options: base.cfg ? base.cfg.options : ({})


  readonly property real blurStrength: Math.max(0, Math.min(100, Number(base.opt("blur", 0))))

  readonly property bool showBorder: WidgetConfig.globalBorder === 0 ? false
    : (WidgetConfig.globalBorder === 1 ? true : base.options.border === true)

  function opt(key, def) {

    if (key === "bgOpacity" && WidgetConfig.globalOpacity >= 0) return WidgetConfig.globalOpacity
    if (key === "blur" && WidgetConfig.globalBlur >= 0) return WidgetConfig.globalBlur
    const v = base.options[key]
    return (v === undefined || v === null) ? def : v
  }
}
