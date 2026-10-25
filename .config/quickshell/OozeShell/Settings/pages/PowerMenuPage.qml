// PowerMenuPage — categoría "PowerMenu": motor del menú de energía (Quickshell o Rofi).

import QtQuick
import QtQuick.Layouts
import ".."
import "../../COMMON"
import "../../Services/Lang"

SettingsPage {
  id: page
  catId: "powermenu"

  readonly property bool rofiReady: WM.isInstalled("rofi")

  SettingsSection {
    titleKey: "pmBackendTitle"
    hintKey: "pmBackendHint"

    SettingsRow {
      stacked: true
      SettingsChoice {
        model: [
          { value: "quickshell", label: Translations.t("pmQuickshell"), icon: "󰐥" },
          { value: "rofi",       label: Translations.t("pmRofi"),       icon: "󰆍", enabled: page.rofiReady }
        ]
        current: (Theme.powermenuBackend === "rofi" && page.rofiReady) ? "rofi" : "quickshell"
        onPicked: v => Theme.setPowermenuBackend(v)
      }
    }

    SettingsNote {
      visible: !page.rofiReady
      kind: "error"
      text: Translations.t("pmRofiMissing")
    }
    SettingsNote {
      visible: page.rofiReady && Theme.powermenuBackend === "rofi"
      text: Translations.t("pmRofiNote")
    }
  }
}
