// WidgetBase — lo único que un widget necesita heredar.

import QtQuick
import "../COMMON"

Item {
  id: base

  property var cfg: null
  property bool editMode: false


  readonly property bool isWidgetBase: true
  property real screenW: 1920
  property real screenH: 1080
  property real originX: 0
  property real originY: 0

  readonly property string widgetId: base.cfg ? base.cfg.id : ""
  readonly property string widgetStyle: base.cfg ? base.cfg.style : ""
  readonly property var options: base.cfg ? base.cfg.options : ({})


  readonly property real blurStrength: Math.max(0, Math.min(100, Number(base.opt("blur", 0))))

  function opt(key, def) {

    if (key === "bgOpacity" && WidgetConfig.globalOpacity >= 0) return WidgetConfig.globalOpacity
    if (key === "blur" && WidgetConfig.globalBlur >= 0) return WidgetConfig.globalBlur
    const v = base.options[key]
    return (v === undefined || v === null) ? def : v
  }
}
