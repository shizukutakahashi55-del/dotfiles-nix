// MenuModule — botón con el logo de la distro: abre el menú principal.

import QtQuick
import QtQuick.Layouts

import "../../../COMMON"
import "../../../Services/Lang"

BarFlow {
  id: mod

  property var host: null
  readonly property bool shown: true

  BarPillButton {
    id: menuBtn

    active: mod.host.menuOpen
    tip: Translations.t("menuButtonTip")

    onHoverEntered: mod.host.tipEnter(menuBtn)
    onHoverExited: mod.host.tipLeave(menuBtn)
    onClicked: mod.host.menuButtonClicked()

    readonly property string logoFile: {
      if (WM.distro === "arch") return "Arch_Logo/Arch_Linux.svg"
      if (WM.distro === "nixos") return "NixOS_Logo/NixOS.svg"
      return ""
    }

    Image {
      visible: menuBtn.logoFile !== ""
      Layout.alignment: Qt.AlignHCenter
      source: menuBtn.logoFile !== ""
        ? Qt.resolvedUrl("../../../Assets/logos/" + menuBtn.logoFile) : ""
      sourceSize.width: Theme.fs(19)
      sourceSize.height: Theme.fs(19)
      fillMode: Image.PreserveAspectFit
      asynchronous: true
    }
    Text {
      visible: menuBtn.logoFile === ""
      Layout.alignment: Qt.AlignHCenter
      text: "❄"
      color: Theme.text
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fs(19)
    }
  }
}
