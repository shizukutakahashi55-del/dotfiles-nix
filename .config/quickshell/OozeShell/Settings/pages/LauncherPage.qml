// LauncherPage — categoría "Launcher": motor (Quickshell/Rofi), ubicación y tamaño, búsqueda y efectos.

import QtQuick
import QtQuick.Layouts
import ".."
import "../../COMMON"
import "../../Services/Lang"

SettingsPage {
  id: page
  catId: "launcher"

  readonly property bool rofiReady: WM.isInstalled("rofi")

  SettingsSection {
    titleKey: "lnBackendTitle"
    hintKey: "lnBackendHint"

    SettingsRow {
      stacked: true
      SettingsChoice {
        model: [
          { value: "quickshell", label: Translations.t("lnQuickshell"), icon: "󰀻" },
          { value: "rofi",       label: Translations.t("lnRofi"),       icon: "󰆍", enabled: page.rofiReady }
        ]
        current: (Theme.launcherBackend === "rofi" && page.rofiReady) ? "rofi" : "quickshell"
        onPicked: v => Theme.setLauncherBackend(v)
      }
    }

    SettingsNote {
      visible: !page.rofiReady
      kind: "error"
      text: Translations.t("lnRofiMissing")
    }
    SettingsNote {
      visible: page.rofiReady && Theme.launcherBackend === "rofi"
      text: Translations.t("lnRofiNote")
    }
  }

  SettingsSection {
    titleKey: "settingsLauncherSection"
    hintKey: "settingsLauncherHint"

    SettingsRow {
      titleKey: "settingsLauncherPlacement"
      SettingsChoice {
        model: [
          { value: true,  label: Translations.t("settingsLauncherBar"),    icon: "▀" },
          { value: false, label: Translations.t("settingsLauncherCenter"), icon: "▣" }
        ]
        current: Theme.launcherAttached
        onPicked: v => Theme.setLauncherAttached(v)
      }
    }

    SettingsRow {
      titleKey: "settingsLauncherSize"
      SettingsChoice {
        model: [
          { value: 0, label: Translations.t("settingsSizeCompact") },
          { value: 1, label: Translations.t("settingsSizeNormal") },
          { value: 2, label: Translations.t("settingsSizeLarge") }
        ]
        current: Theme.launcherSize
        onPicked: v => Theme.setLauncherSize(v)
      }
    }

    SettingsRow {
      titleKey: "settingsLauncherImage"
      SettingsSwitch {
        checked: Theme.launcherShowImage
        onToggled: Theme.setLauncherShowImage(!Theme.launcherShowImage)
      }
    }
  }

  SettingsSection {
    titleKey: "settingsLauncherPrefixes"
    hintKey: "settingsLauncherPrefixesHint"

    SettingsRow {
      title: "> · !"
      SettingsSwitch {
        checked: Theme.launcherCommandMode
        onToggled: Theme.setLauncherCommandMode(!Theme.launcherCommandMode)
      }
    }
  }

  SettingsSection {
    titleKey: "settingsEffectsSection"
    hintKey: "settingsEffectsHint"

    SettingsRow {
      titleKey: "settingsEffectsLabel"
      SettingsSwitch {
        checked: Theme.effectsOn
        onToggled: Theme.setEffects(!Theme.effectsOn)
      }
    }

    SettingsRow {
      titleKey: "settingsLauncherParticles"
      hintKey: "settingsLauncherParticlesHint"
      SettingsSwitch {
        checked: Theme.launcherParticlesEnabled
        onToggled: Theme.setLauncherParticlesEnabled(!Theme.launcherParticlesEnabled)
      }
    }

    SettingsRow {
      titleKey: "settingsLauncherWallpaperLive"
      hintKey: "settingsLauncherWallpaperLiveHint"
      SettingsSwitch {
        checked: Theme.launcherWallpaperLiveEnabled
        onToggled: Theme.setLauncherWallpaperLiveEnabled(!Theme.launcherWallpaperLiveEnabled)
      }
    }
  }
}
