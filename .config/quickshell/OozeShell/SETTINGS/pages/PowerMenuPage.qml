// PowerMenuPage — categoría "PowerMenu": backend Quickshell o Rofi.
// Con "rofi" el botón de energía de la barra y los IPC `powermenu` lanzan ~/.config/rofi/Powermenu/powermenu.sh en vez del PowerMenu propio. Rofi solo se puede elegir si está instalado (WM.isInstalled);

import QtQuick
import QtQuick.Layouts
import ".."
import "../../COMMON"
import "../../LANG"

SettingsPage {
  id: page
  catId: "powermenu"

  readonly property bool rofiReady: WM.isInstalled("rofi")

  SettingsSection {
    titleKey: "pmBackendTitle"
    hintKey: "pmBackendHint"

    Flow {
      Layout.fillWidth: true
      spacing: 8
      SettingsBtn {
        icon: "󰐥"
        text: Translations.t("pmQuickshell")
        primary: Theme.powermenuBackend !== "rofi"
        onClicked: Theme.setPowermenuBackend("quickshell")
      }
      SettingsBtn {
        icon: "󰆍"
        text: Translations.t("pmRofi")
        primary: Theme.powermenuBackend === "rofi" && page.rofiReady
        enabled: page.rofiReady
        onClicked: Theme.setPowermenuBackend("rofi")
      }
    }

    Text {
      visible: !page.rofiReady
      Layout.fillWidth: true
      wrapMode: Text.WordWrap
      text: Translations.t("pmRofiMissing")
      color: Theme.error
      font.pixelSize: Theme.fs(11)
      font.family: Theme.fontFamily
    }
    Text {
      visible: page.rofiReady && Theme.powermenuBackend === "rofi"
      Layout.fillWidth: true
      wrapMode: Text.WordWrap
      text: Translations.t("pmRofiNote")
      color: Theme.subtext
      font.pixelSize: Theme.fs(11)
      font.family: Theme.fontFamily
    }
  }
}
