// GeneralPage

import Quickshell
import QtQuick
import QtQuick.Layouts
import ".."
import "../../COMMON"
import "../../Services/Lang"

SettingsPage {
  id: page
  catId: "general"

  readonly property string targetMonitor: page.host ? page.host.targetMonitor : "auto"
  readonly property string resolvedMonitor: page.host ? page.host.resolvedMonitor : ""

  readonly property var monitorChoices: [{ value: "auto", label: Translations.t("monitorAutoOption"), icon: "󰍹" }]
    .concat(Quickshell.screens.map(s => ({ value: s.name, label: s.name, icon: "󰍹" })))
  readonly property var terminalChoices: page.host
    ? page.host.terminalChoices.map(t => ({ value: t.id, label: t.name, icon: "󰆍" })) : []

  SettingsSection {
    titleKey: "settingsMonitor"

    SettingsRow {
      hint: page.targetMonitor === "auto" && page.resolvedMonitor !== ""
        ? Translations.t("monitorAutoHint") + " " + page.resolvedMonitor
        : Translations.t("monitorAutoSubtitle")
      stacked: true
      SettingsChips {
        model: page.monitorChoices
        current: page.targetMonitor
        onPicked: v => page.host.monitorChosen(v)
      }
    }
  }

  SettingsSection {
    titleKey: "settingsLanguage"

    SettingsRow {
      hintKey: "settingsLanguageHint"
      stacked: true
      SettingsChips {
        model: Translations.availableLanguages.map(l => ({ value: l.code, label: l.name, icon: "󰗊" }))
        current: Translations.current
        onPicked: v => page.host.languageChosen(v)
      }
    }
  }

  SettingsSection {
    titleKey: "settingsTerminalSection"

    SettingsRow {
      hintKey: "settingsTerminalHint"
      stacked: true
      SettingsChips {
        model: page.terminalChoices
        current: Theme.terminalId
        onPicked: v => Theme.setTerminal(v)
      }
    }
  }

  SettingsSection {
    titleKey: "fontTitle"
    hintKey: "fontHint"

    SettingsRow {
      stacked: true
      divider: false
      FontPicker { Layout.fillWidth: true }
    }
  }
}
