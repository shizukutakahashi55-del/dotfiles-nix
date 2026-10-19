// InterfacePage — categoría "Interfaz": rendimiento, tamaño y animaciones, ajuste fino, ventana de ajustes y marco de pantalla.

import QtQuick
import QtQuick.Layouts
import ".."
import "../../COMMON"
import "../../Services/Lang"

SettingsPage {
  id: page
  catId: "interface"

  readonly property var levelNames: page.host ? page.host.levelNames : []
  readonly property int masterLevel: page.host ? page.host.masterLevel : -1
  readonly property bool screenCorners: page.host ? page.host.screenCorners : false

  readonly property var sizeNames: [
    Translations.t("settingsSizeMin"), Translations.t("settingsSizeCompact"),
    Translations.t("settingsSizeNormal"), Translations.t("settingsSizeLarge")
  ]

  function levelOf(kind) { return page.host ? page.host.levelOf(kind) : 0 }

  SettingsSection {
    titleKey: "perfTitle"
    hintKey: "perfHint"
    borderColor: Theme.performanceMode ? Theme.primary : Theme.edge

    SettingsRow {
      titleKey: "setEnable"
      SettingsSwitch {
        checked: Theme.performanceMode
        onToggled: Theme.setPerformanceMode(!Theme.performanceMode)
      }
    }

    SettingsRow {
      titleKey: "perfScopeTitle"
      hintKey: "perfScopeHint"
      SettingsChoice {
        model: [
          { value: "both",       label: Translations.t("perfScopeBoth") },
          { value: "shell",      label: Translations.t("perfScopeShell") },
          { value: "compositor", label: Translations.t("perfScopeCompositor") }
        ]
        current: Theme.performanceScope
        onPicked: v => Theme.setPerformanceScope(v)
      }
    }
  }

  SettingsSection {
    titleKey: "uiSizeTitle"
    hintKey: "uiSizeHint"

    SettingsNote {
      visible: page.masterLevel < 0
      kind: "accent"
      text: Translations.t("uiCustom")
    }

    SettingsRow {
      stacked: true
      LevelPicker {
        level: page.masterLevel
        names: page.levelNames
        showNames: true
        onPicked: index => Theme.setInterfaceLevel(index)
      }
    }

    SettingsRow {
      title: "Animaciones de OozeShell"
      hintKey: "uiAnimNote"
      SettingsChoice {
        model: [
          { value: "normal",  label: "Normal" },
          { value: "minimal", label: "Mínimas" },
          { value: "off",     label: "Desactivadas" }
        ]
        current: Theme.uiAnimationMode
        onPicked: v => Theme.setUiAnimationMode(v)
      }
    }
  }

  SettingsSection {
    titleKey: "uiFineTune"
    hintKey: "uiFineHint"

    SettingsRow {
      titleKey: "uiFontManual"
      hintKey: "uiFontManualHint"

      SettingsBtn {
        visible: Theme.fontCustom
        icon: "󰑙"
        text: Translations.t("uiFontReset")
        onClicked: Theme.setFontPercent(0)
      }
      NumberStepper {
        Layout.fillWidth: false
        Layout.preferredWidth: 150
        Layout.preferredHeight: 34
        value: Theme.fontPercentEffective
        min: Theme.fontPercentMin
        max: Theme.fontPercentMax
        step: 5
        suffix: "%"
        onEdited: v => Theme.setFontPercent(v)
      }
    }
    SettingsNote {
      text: Translations.t("uiFontExample") + ": 13 px → " + Theme.sfs(13) + " px"
    }

    Repeater {
      model: [
        { kind: "font",   label: "uiFont" },
        { kind: "bar",    label: "uiBar" },
        { kind: "window", label: "uiWindows" }
      ]

      delegate: SettingsRow {
        required property var modelData
        titleKey: modelData.label
        hint: (modelData.kind === "font" && Theme.fontCustom) ? (Theme.fontPercent + "%") : (page.levelNames[page.levelOf(modelData.kind)] ?? "")
        stacked: true

        LevelPicker {
          level: (modelData.kind === "font" && Theme.fontCustom) ? -1 : page.levelOf(modelData.kind)
          names: page.levelNames
          showNames: false
          onPicked: index => Theme.setLevel(modelData.kind, index)
        }
      }
    }

    SettingsRow {
      titleKey: "uiReset"
      SettingsBtn {
        icon: "󰑙"
        text: ""
        onClicked: Theme.resetLevels()
      }
    }
  }

  SettingsSection {
    titleKey: "settingsWinTitle"
    hintKey: "settingsWinHint"

    SettingsRow {
      titleKey: "settingsWinSize"
      hint: page.sizeNames[Theme.settingsSize] ?? ""
      stacked: true

      LevelPicker {
        count: 4
        level: Theme.settingsSize
        names: page.sizeNames
        showNames: true
        onPicked: index => Theme.setSettingsSize(index)
      }
    }

    SettingsNote {
      text: Translations.t("settingsWinNote")
    }

    SettingsRow {
      titleKey: "settingsWinReset"
      SettingsBtn {
        icon: "󰑙"
        text: ""
        onClicked: Theme.resetSettingsWin()
      }
    }
  }

  SettingsSection {
    titleKey: "advFrameTitle"
    hintKey: "advFrameEnableHint"

    SettingsRow {
      titleKey: "setEnable"
      enabled: !Theme.barSeparated && WM.has("screenFrame")
      SettingsSwitch {
        checked: page.screenCorners && WM.has("screenFrame")
        onToggled: page.host.requestCornersToggle()
      }
    }
    SettingsNote {
      visible: Theme.barSeparated || !WM.has("screenFrame")
      text: Translations.t("advFrameOffHint")
    }

    SettingsRow {
      titleKey: "advFrameStyleLabel"
      hintKey: "advFrameStyleHint"
      SettingsChoice {
        model: [
          { value: "corners", label: Translations.t("advFrameStyleCorners"), icon: "▨" },
          { value: "curved",  label: Translations.t("advFrameStyleCurved"),  icon: "◜" }
        ]
        current: Theme.frameStyle
        onPicked: v => Theme.setFrameStyle(v)
      }
    }

    SettingsRow {
      visible: Theme.frameCurved
      titleKey: "advFrameRadiusLabel"
      NumberStepper {
        Layout.fillWidth: false
        Layout.preferredWidth: 140
        Layout.preferredHeight: 34
        value: Theme.frameCurveRadius
        min: 10; max: 60; step: 2
        suffix: "px"
        onEdited: v => Theme.setFrameCurveRadius(v)
      }
    }

    SettingsRow {
      visible: Theme.frameCurved
      titleKey: "advFrameThicknessLabel"
      NumberStepper {
        Layout.fillWidth: false
        Layout.preferredWidth: 140
        Layout.preferredHeight: 34
        value: Theme.frameThickness
        min: 0; max: 150; step: 2
        suffix: "px"
        onEdited: v => Theme.setFrameThickness(v)
      }
    }

    SettingsRow {
      visible: Theme.frameCurved && Theme.frameBorderActive
      titleKey: "advFrameFuse"
      SettingsSwitch {
        checked: Theme.frameFuse
        onToggled: Theme.setFrameFuse(!Theme.frameFuse)
      }
    }
  }
}
