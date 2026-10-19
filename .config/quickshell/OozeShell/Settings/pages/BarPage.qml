// BarPage — categoría "Barra": motor (Quickshell/Waybar), posición y visibilidad, módulos, cristal, ventanas flotantes, píldora, Dashboard (tamaño, común a barra y píldora) y batería.

import QtQuick
import QtQuick.Layouts
import ".."
import "../../COMMON"
import "../../Services/Lang"

SettingsPage {
  id: page
  catId: "bar"

  readonly property bool waybarReady: WM.isInstalled("waybar")

  readonly property var winAnimChoices: Theme.windowAnimStyles.map(s => ({
    value: s,
    label: Translations.t("barWinAnim_" + s)
  }))

  SettingsSection {
    titleKey: "barBackendTitle"
    hintKey: "barBackendHint"

    SettingsRow {
      stacked: true
      SettingsChoice {
        model: [
          { value: "ooze",   label: Translations.t("barOoze"),   icon: "▀" },
          { value: "waybar", label: Translations.t("barWaybar"), icon: "▬", enabled: page.waybarReady }
        ]
        current: (Theme.barBackend === "waybar" && page.waybarReady) ? "waybar" : "ooze"
        onPicked: v => Theme.setBarBackend(v)
      }
    }

    SettingsNote {
      visible: !page.waybarReady
      kind: "error"
      text: Translations.t("barWaybarMissing")
    }
    SettingsNote {
      visible: page.waybarReady && Theme.barBackend === "waybar"
      text: Translations.t("barWaybarNote")
    }
  }

  SettingsSection {
    titleKey: "barSection"
    hintKey: "barSectionHint"

    SettingsRow {
      titleKey: "barPosition"
      SettingsChoice {
        model: [
          { value: "top",    label: Translations.t("barTop"),    icon: "▀" },
          { value: "bottom", label: Translations.t("barBottom"), icon: "▄" },
          { value: "left",   label: Translations.t("barLeft"),   icon: "▌" },
          { value: "right",  label: Translations.t("barRight"),  icon: "▐" }
        ]
        current: Theme.barPosition
        onPicked: v => Theme.setBarPosition(v)
      }
    }

    SettingsRow {
      titleKey: "barFloating"
      hint: Theme.barVertical ? Translations.t("barFloatingOnlyH") : Translations.t("barFloatingHint")
      enabled: !Theme.barVertical
      SettingsSwitch {
        checked: Theme.barFloatingPref
        onToggled: Theme.setBarFloating(!Theme.barFloatingPref)
      }
    }

    SettingsRow {
      titleKey: "barIslands"
      hint: Theme.barVertical ? Translations.t("barIslandsOnlyH") : Translations.t("barIslandsHint")
      enabled: !Theme.barVertical
      SettingsSwitch {
        checked: Theme.islandsPref
        onToggled: Theme.setIslandsEnabled(!Theme.islandsPref)
      }
    }

    SettingsRow {
      titleKey: "barHide"
      hintKey: "barHideHint"
      enabled: !Theme.usingWaybar && !Theme.pillMode
      SettingsSwitch {
        checked: Theme.barHiddenPref
        onToggled: Theme.setBarHidden(!Theme.barHiddenPref)
      }
    }
    SettingsNote {
      visible: Theme.usingWaybar
      kind: "error"
      text: Translations.t("barHideWaybar")
    }

    SettingsRow {
      titleKey: "barRevealMode"
      hintKey: "barRevealHint"
      enabled: Theme.barHiddenPref
      SettingsChoice {
        model: [
          { value: "hover", label: Translations.t("barRevealHover"), icon: "󰇀" },
          { value: "click", label: Translations.t("barRevealClick"), icon: "󰍽" }
        ]
        current: Theme.barRevealMode
        onPicked: v => Theme.setBarRevealMode(v)
      }
    }

    SettingsRow {
      titleKey: "barHideFrame"
      hintKey: "barHideFrameHint"
      SettingsSwitch {
        checked: Theme.barHiddenFramePref
        onToggled: Theme.setBarHiddenFrame(!Theme.barHiddenFramePref)
      }
    }
  }

  SettingsSection {
    titleKey: "barModulesTitle"
    hintKey: "barModulesHint"

    SettingsNote {
      visible: Theme.pillMode
      kind: "error"
      text: Translations.t("barModulesPill")
    }

    SettingsNote {
      visible: !Theme.pillMode
      text: Translations.t("barModulesPerMode")
    }

    SettingsRow {
      stacked: true
      enabled: !Theme.pillMode
      BarModulePicker {}
    }

    SettingsRow {
      titleKey: "barModulesReset"
      enabled: !Theme.pillMode
      SettingsBtn {
        icon: "↺"
        text: ""
        onClicked: Theme.resetBarLayout()
      }
    }

    SettingsRow {
      titleKey: "barTplTitle"
      hintKey: "barTplHint"
      stacked: true
      BarTemplates {}
    }
  }

  SettingsSection {
    visible: Theme.glassAllowed
    titleKey: "barGlass"
    hintKey: "barGlassHint"

    SettingsRow {
      titleKey: "setEnable"
      SettingsSwitch {
        checked: Theme.glassModePref
        onToggled: Theme.setGlassMode(!Theme.glassModePref)
      }
    }

    SettingsRow {
      titleKey: "barGlassOpacity"
      enabled: Theme.glassModePref
      ScaleSlider {
        Layout.fillWidth: false
        Layout.preferredWidth: 240
        value: Theme.glassOpacity
        min: 10
        max: 100
        step: 5
        defaultValue: Theme.glassOpacityDefault
        onEdited: v => Theme.setGlassOpacity(v)
      }
    }

    SettingsRow {
      titleKey: "barGlassBlur"
      hintKey: "barGlassBlurHint"
      enabled: Theme.glassModePref
      SettingsSwitch {
        checked: Theme.glassBlurPref
        onToggled: Theme.setGlassBlur(!Theme.glassBlurPref)
      }
    }

    SettingsRow {
      titleKey: "barGlassSeam"
      hintKey: "barGlassSeamHint"
      enabled: Theme.glassModePref && Theme.glassBlurPref
      ScaleSlider {
        Layout.fillWidth: false
        Layout.preferredWidth: 240
        value: Theme.glassSeamInset
        min: 0
        max: 24
        step: 1
        defaultValue: Theme.glassSeamDefault
        onEdited: v => Theme.setGlassSeamInset(v)
      }
    }

    SettingsNote {
      visible: Theme.glassModePref
      text: Translations.t("barGlassFloatHint")
    }
  }

  SettingsSection {
    titleKey: "barFloatWin"
    hintKey: "barFloatWinHint"

    SettingsRow {
      titleKey: "setEnable"
      SettingsSwitch {
        checked: Theme.floatWindowsPref
        onToggled: Theme.setFloatWindows(!Theme.floatWindowsPref)
      }
    }
    SettingsNote {
      visible: Theme.perfFloatsWindows && !Theme.islandsMode && !Theme.pillMode
      text: Translations.t("barFloatWinPerfHint")
    }
    SettingsNote {
      visible: Theme.shellPerf && (Theme.islandsMode || Theme.pillMode) && !Theme.glassMode
      text: Translations.t("barFloatWinPerfIslandsHint")
    }
    SettingsNote {
      visible: Theme.floatWindowsPref && !Theme.glassMode && (Theme.islandsMode || Theme.pillMode)
      text: Translations.t("barFloatWinIslandsHint")
    }

    SettingsRow {
      titleKey: "barWinAnim"
      hintKey: "barWinAnimHint"
      stacked: true
      SettingsChips {
        model: page.winAnimChoices
        current: Theme.windowAnimStyle
        onPicked: v => Theme.setWindowAnimStyle(v)
      }
    }
  }

  SettingsSection {
    titleKey: "barPillMode"
    hintKey: "barPillModeHint"

    SettingsRow {
      titleKey: "setEnable"
      enabled: !Theme.barVertical
      SettingsSwitch {
        checked: Theme.pillModePref
        onToggled: Theme.setPillModeEnabled(!Theme.pillModePref)
      }
    }

    SettingsRow {
      visible: Theme.pillMode
      titleKey: "barPillAutoHide"
      SettingsSwitch {
        checked: Theme.pillAutoHidePref
        onToggled: Theme.setPillAutoHide(!Theme.pillAutoHidePref)
      }
    }

    SettingsRow {
      visible: Theme.pillMode && Theme.pillAutoHidePref
      titleKey: "barPillTraySync"
      SettingsSwitch {
        checked: Theme.pillTraySyncPref
        onToggled: Theme.setPillTraySync(!Theme.pillTraySyncPref)
      }
    }

    SettingsRow {
      titleKey: "pillSize"
      hintKey: "pillSizeHint"
      enabled: Theme.pillMode
      ScaleSlider {
        Layout.fillWidth: false
        Layout.preferredWidth: 240
        value: Theme.pillScalePercent
        min: Theme.ownScaleMin
        max: Theme.ownScaleMax
        step: 5
        defaultValue: Theme.pillScaleDefault
        onEdited: v => Theme.setPillScalePercent(v)
      }
    }
  }

  // ── Dashboard ──
  SettingsSection {
    titleKey: "dashSection"
    hintKey: "dashSectionHint"

    SettingsRow {
      titleKey: "dashSize"
      hintKey: "dashSizeHint"
      stacked: true
      LevelPicker {
        level: Theme.dashboardLevel
        names: ["1", "2", "3", "4", "5"]
        showNames: true
        onPicked: index => Theme.setDashboardLevel(index)
      }
    }
  }

  SettingsSection {
    titleKey: "batterySection"
    hintKey: "batteryHint"

    SettingsRow {
      titleKey: "setEnable"
      SettingsSwitch {
        checked: Theme.batteryEnabled
        onToggled: Theme.setBatteryEnabled(!Theme.batteryEnabled)
      }
    }
  }
}
