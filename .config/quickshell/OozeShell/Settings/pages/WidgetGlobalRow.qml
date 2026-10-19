// WidgetGlobalRow — fila de un ajuste global de widgets: interruptor (usar valor global o el de cada widget) + valor en porcentaje.

import QtQuick
import QtQuick.Layouts
import ".."
import "../../COMMON"

SettingsRow {
  id: gr

  property int value: -1
  property int fallback: 60
  property string suffix: ""

  signal changed(int v)

  SettingsSwitch {
    checked: gr.value >= 0
    onToggled: gr.changed(gr.value >= 0 ? -1 : gr.fallback)
  }
  NumberStepper {
    Layout.fillWidth: false
    Layout.preferredWidth: 140
    Layout.preferredHeight: 34
    enabled: gr.value >= 0
    opacity: gr.value >= 0 ? 1 : 0.45
    value: Math.max(0, gr.value)
    min: 0; max: 100; step: 5
    suffix: gr.suffix
    onEdited: v => gr.changed(v)
  }
}
