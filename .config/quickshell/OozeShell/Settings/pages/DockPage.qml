// DockPage — categoría "Dock": estado y posición, y apariencia (modo, tamaño, opacidad, blur).

import QtQuick
import QtQuick.Layouts
import ".."
import "../../COMMON"
import "../../Services/Lang"

SettingsPage {
  id: page
  catId: "dock"

  SettingsSection {
    titleKey: "dockSection"

    SettingsNote {
      visible: Theme.frameBorderActive
      kind: "accent"
      text: Translations.t("dockFrameBlocked")
    }

    SettingsRow {
      titleKey: "dockEnable"
      SettingsSwitch {
        checked: Theme.dockEnabled
        onToggled: Theme.setDockEnabled(!Theme.dockEnabled)
      }
    }

    SettingsRow {
      titleKey: "dockAutoHide"
      SettingsSwitch {
        checked: Theme.dockAutoHide
        onToggled: Theme.setDockAutoHide(!Theme.dockAutoHide)
      }
    }

    SettingsRow {
      titleKey: "dockPosition"
      hint: Theme.barVertical ? Translations.t("dockPositionHint") : Translations.t("dockPositionAutoHint")
      enabled: Theme.barVertical
      SettingsChoice {
        model: [
          { value: "top",    label: Translations.t("barTop"),    icon: "▀" },
          { value: "bottom", label: Translations.t("barBottom"), icon: "▄" }
        ]
        current: Theme.dockPosition
        onPicked: v => Theme.setDockPosition(v)
      }
    }
  }

  SettingsSection {
    titleKey: "advDockLookTitle"
    hintKey: "advDockLookHint"

    SettingsRow {
      titleKey: "advDockModeLabel"
      hintKey: "advDockModeHint"
      enabled: Theme.dockUsable
      SettingsChoice {
        model: [
          { value: "panel", label: Translations.t("advDockModePanel"), icon: "󰘔" },
          { value: "pill",  label: Translations.t("advDockModePill"),  icon: "󰋙" }
        ]
        current: Theme.dockMode
        onPicked: v => Theme.setDockMode(v)
      }
    }

    SettingsRow {
      titleKey: "dockSize"
      hintKey: "dockSizeHint"
      enabled: Theme.dockUsable
      ScaleSlider {
        Layout.fillWidth: false
        Layout.preferredWidth: 240
        value: Theme.dockScalePercent
        min: Theme.ownScaleMin
        max: Theme.ownScaleMax
        step: 5
        defaultValue: Theme.dockScaleDefault
        onEdited: v => Theme.setDockScalePercent(v)
      }
    }

    SettingsRow {
      titleKey: "advDockOpacity"
      enabled: Theme.dockUsable
      ScaleSlider {
        Layout.fillWidth: false
        Layout.preferredWidth: 240
        value: Theme.dockOpacity
        min: 0
        max: 100
        step: 5
        defaultValue: Theme.dockOpacityDefault
        onEdited: v => Theme.setDockOpacity(v)
      }
    }

    SettingsRow {
      titleKey: "advDockBlur"
      hintKey: "advDockLookNote"
      enabled: Theme.dockUsable
      SettingsSwitch {
        checked: Theme.dockBlur > 0
        onToggled: Theme.setDockBlur(Theme.dockBlur > 0 ? 0 : 100)
      }
    }
  }
}
