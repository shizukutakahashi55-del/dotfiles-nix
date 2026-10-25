// PowerModule — botón de apagado: abre el menú de energía.

import QtQuick

import "../../../COMMON"
import "../../../Services/Lang"

BarFlow {
  id: mod

  property var host: null
  readonly property bool shown: true

  BarPillButton {
    id: powerBtn

    tip: Translations.t("powerMenuTip")

    onHoverEntered: mod.host.tipEnter(powerBtn)
    onHoverExited: mod.host.tipLeave(powerBtn)
    onClicked: mod.host.powerButtonClicked()

    Text {
      text: "⏻"
      color: Theme.text
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fs(17)
    }
  }
}
