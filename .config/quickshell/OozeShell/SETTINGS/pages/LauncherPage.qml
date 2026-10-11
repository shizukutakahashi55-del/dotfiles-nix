// LauncherPage — categoría "Launcher": backend (Quickshell/Rofi), ubicación, imagen, tamaño y efectos.

import QtQuick
import QtQuick.Layouts
import ".."
import "../../COMMON"
import "../../LANG"

SettingsPage {
  id: page
  catId: "launcher"

  readonly property bool rofiReady: WM.isInstalled("rofi")

  component Label: Text {
    Layout.fillWidth: true
    wrapMode: Text.WordWrap
    color: Theme.text
    font.pixelSize: Theme.fs(12)
    font.bold: true
    font.family: Theme.fontFamily
  }

  component Hint: Text {
    Layout.fillWidth: true
    wrapMode: Text.WordWrap
    color: Theme.subtext
    font.pixelSize: Theme.fs(10)
    font.family: Theme.fontFamily
  }

  component Divider: Rectangle {
    Layout.fillWidth: true
    Layout.preferredHeight: 1
    color: Theme.divider
  }

  component RowLabel: Text {
    Layout.preferredWidth: Math.min(implicitWidth, 140)
    Layout.maximumWidth: 140
    elide: Text.ElideRight
    color: Theme.text
    font.bold: true
    font.pixelSize: Theme.fs(12)
    font.family: Theme.fontFamily
  }

  // ═══ Backend ═══════════════════════════════════════════════════
  SettingsSection {
    titleKey: "lnBackendTitle"
    hintKey: "lnBackendHint"

    Flow {
      Layout.fillWidth: true
      spacing: 8
      SettingsBtn {
        icon: "󰀻"
        text: Translations.t("lnQuickshell")
        primary: Theme.launcherBackend !== "rofi"
        onClicked: Theme.setLauncherBackend("quickshell")
      }
      SettingsBtn {
        icon: "󰆍"
        text: Translations.t("lnRofi")
        primary: Theme.launcherBackend === "rofi" && page.rofiReady
        enabled: page.rofiReady
        onClicked: Theme.setLauncherBackend("rofi")
      }
    }

    Text {
      visible: !page.rofiReady
      Layout.fillWidth: true
      wrapMode: Text.WordWrap
      text: Translations.t("lnRofiMissing")
      color: Theme.error
      font.pixelSize: Theme.fs(11)
      font.family: Theme.fontFamily
    }
    Text {
      visible: page.rofiReady && Theme.launcherBackend === "rofi"
      Layout.fillWidth: true
      wrapMode: Text.WordWrap
      text: Translations.t("lnRofiNote")
      color: Theme.subtext
      font.pixelSize: Theme.fs(11)
      font.family: Theme.fontFamily
    }
  }

  // ═══ Ubicación, imagen y tamaño ═══════════════════════════════
  SettingsSection {
    titleKey: "settingsLauncherSection"
    hintKey: "settingsLauncherHint"

    Label { text: Translations.t("settingsLauncherPlacement") }
    Flow {
      Layout.fillWidth: true
      spacing: 8
      SettingsBtn {
        icon: "▀"
        text: Translations.t("settingsLauncherBar")
        primary: Theme.launcherAttached
        onClicked: Theme.setLauncherAttached(true)
      }
      SettingsBtn {
        icon: "▣"
        text: Translations.t("settingsLauncherCenter")
        primary: !Theme.launcherAttached
        onClicked: Theme.setLauncherAttached(false)
      }
    }

    Divider {}

    RowLayout {
      Layout.fillWidth: true
      spacing: 10
      RowLabel { text: Translations.t("settingsLauncherImage") }
      SettingsBtn {
        icon: "▣"
        text: Theme.launcherShowImage ? "ON" : "OFF"
        primary: Theme.launcherShowImage
        onClicked: Theme.setLauncherShowImage(!Theme.launcherShowImage)
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: 10
      RowLabel { text: Translations.t("settingsLauncherSize") }
      Repeater {
        model: [
          { size: 0, label: "settingsSizeCompact" },
          { size: 1, label: "settingsSizeNormal" },
          { size: 2, label: "settingsSizeLarge" }
        ]
        delegate: SettingsBtn {
          required property var modelData
          text: Translations.t(modelData.label)
          primary: Theme.launcherSize === modelData.size
          onClicked: Theme.setLauncherSize(modelData.size)
        }
      }
    }
  }

  // ═══ Búsqueda: prefijos ═══════════════════════════════════════
  SettingsSection {
    titleKey: "settingsLauncherPrefixes"
    hintKey: "settingsLauncherPrefixesHint"

    RowLayout {
      Layout.fillWidth: true
      spacing: 10
      RowLabel { text: "> · !" }
      SettingsBtn {
        icon: "󰅂"
        text: Theme.launcherCommandMode ? "ON" : "OFF"
        primary: Theme.launcherCommandMode
        onClicked: Theme.setLauncherCommandMode(!Theme.launcherCommandMode)
      }
    }
  }

  // ═══ Efectos ══════════════════════════════════════════════════
  SettingsSection {
    titleKey: "settingsEffectsSection"
    hintKey: "settingsEffectsHint"

    RowLayout {
      Layout.fillWidth: true
      spacing: 10
      RowLabel { text: Translations.t("settingsEffectsLabel") }
      SettingsBtn {
        icon: "✦"
        text: Theme.effectsOn ? "ON" : "OFF"
        primary: Theme.effectsOn
        onClicked: Theme.setEffects(!Theme.effectsOn)
      }
    }

    Divider {}

    Label { text: Translations.t("settingsLauncherParticles") }
    Hint { text: Translations.t("settingsLauncherParticlesHint") }
    SettingsBtn {
      icon: "✦"
      text: Theme.launcherParticlesEnabled ? "ON" : "OFF"
      primary: Theme.launcherParticlesEnabled
      onClicked: Theme.setLauncherParticlesEnabled(!Theme.launcherParticlesEnabled)
    }

    Divider {}

    Label { text: Translations.t("settingsLauncherWallpaperLive") }
    Hint { text: Translations.t("settingsLauncherWallpaperLiveHint") }
    SettingsBtn {
      icon: "▶"
      text: Theme.launcherWallpaperLiveEnabled ? "ON" : "OFF"
      primary: Theme.launcherWallpaperLiveEnabled
      onClicked: Theme.setLauncherWallpaperLiveEnabled(!Theme.launcherWallpaperLiveEnabled)
    }
  }
}
