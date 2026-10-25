// LangModule — distribución de teclado actual; el clic pasa al siguiente layout.

import QtQuick
import QtQuick.Layouts

import "../../../COMMON"
import "../../../Services/Lang"

BarFlow {
  id: mod

  property var host: null
  readonly property bool shown: true

  BarPillButton {
    id: langBtn

    tip: Translations.t("langSwitchTip")

    onHoverEntered: mod.host.tipEnter(langBtn)
    onHoverExited: mod.host.tipLeave(langBtn)
    onClicked: KeyboardLayout.next()

    Text {
      visible: Theme.barVertical
      Layout.alignment: Qt.AlignHCenter
      text: "󰌌"
      color: Theme.subtext
      font.family: Theme.monoFamily
      font.pixelSize: Theme.fs(14)
    }

    Text {
      Layout.alignment: Qt.AlignHCenter
      text: (Theme.barVertical ? "" : "󰌌 ") + KeyboardLayout.label
      color: Theme.text
      font.family: Theme.monoFamily
      font.pixelSize: Theme.fs(13)
    }
  }
}
