// QuickBarPage — categoría "QuickSearch": dónde aparece, con qué navegador y buscador abre las búsquedas, y la búsqueda de archivos (nvim en la terminal).

import QtQuick
import QtQuick.Layouts
import ".."
import "../../COMMON"
import "../../Services/Lang"
import "../../Modules/QuickBar"

SettingsPage {
  id: page
  catId: "quickbar"

  readonly property var positionChoices: [
    { value: "top",    label: Translations.t("qbPosTop") },
    { value: "center", label: Translations.t("qbPosCenter") },
    { value: "bottom", label: Translations.t("qbPosBottom") }
  ]
  readonly property var widthChoices: [
    { value: "compact", label: Translations.t("qbWidthCompact") },
    { value: "normal",  label: Translations.t("qbWidthNormal") },
    { value: "wide",    label: Translations.t("qbWidthWide") }
  ]

  readonly property var browserChoices: {
    const out = [{ value: "default", label: Translations.t("qbBrowserDefault"), icon: "󰖟" }]
    const inst = QuickBarConfig.installedBrowsers
    const all = QuickBarConfig.browsers
    for (let i = 0; i < all.length; i++)
      if (inst.indexOf(all[i].id) >= 0 || all[i].id === QuickBarConfig.browserId)
        out.push({ value: all[i].id, label: all[i].name, icon: "󰖟" })
    return out
  }
  readonly property bool browserMissing: QuickBarConfig.browserId !== "default"
    && QuickBarConfig.detected && QuickBarConfig.installedBrowsers.indexOf(QuickBarConfig.browserId) < 0

  readonly property var engineChoices: QuickBarConfig.engines
    .map(e => ({ value: e.id, label: e.name }))
    .concat([{ value: "custom", label: Translations.t("qbEngineCustom") }])

  readonly property var openerChoices: [
    { value: "nvim",    label: Translations.t("qbFilesOpenerNvim"),    icon: "󰆍" },
    { value: "default", label: Translations.t("qbFilesOpenerDefault"), icon: "󰈔" }
  ]

  readonly property string bangList: {
    const bare = [], bang = []
    const all = QuickBarConfig.bangs
    for (let i = 0; i < all.length; i++) (all[i].bare ? bare : bang).push(all[i].bare ? all[i].id : "!" + all[i].id)
    return bare.join("  ") + "   ·   " + bang.join("  ")
  }

  readonly property string terminalName: {
    const list = Theme.terminals
    for (let i = 0; i < list.length; i++) if (list[i].id === Theme.terminalId) return list[i].name
    return Theme.terminalId
  }

  SettingsSection {
    titleKey: "qbLookTitle"
    hintKey: "qbLookHint"

    SettingsRow {
      titleKey: "qbPosition"
      SettingsChoice {
        model: page.positionChoices
        current: QuickBarConfig.position
        onPicked: v => QuickBarConfig.set("position", v)
      }
    }

    SettingsRow {
      titleKey: "qbWidth"
      SettingsChoice {
        model: page.widthChoices
        current: QuickBarConfig.widthMode
        onPicked: v => QuickBarConfig.set("widthMode", v)
      }
    }
  }

  SettingsSection {
    titleKey: "qbBrowserTitle"
    hintKey: "qbBrowserHint"

    SettingsRow {
      titleKey: "qbBrowserPref"
      stacked: true
      SettingsChips {
        model: page.browserChoices
        current: QuickBarConfig.browserId
        onPicked: v => QuickBarConfig.set("browserId", v)
      }
    }
    SettingsNote {
      visible: page.browserMissing
      kind: "error"
      text: Translations.t("qbBrowserMissing").replace("%1", (QuickBarConfig.browserInfo(QuickBarConfig.browserId) ?? { name: QuickBarConfig.browserId }).name)
    }

    SettingsRow {
      titleKey: "qbPrivate"
      hintKey: "qbPrivateHint"
      enabled: QuickBarConfig.browser !== null
      SettingsSwitch {
        checked: QuickBarConfig.privateWindow
        onToggled: QuickBarConfig.toggle("privateWindow")
      }
    }
  }

  SettingsSection {
    titleKey: "qbSearchTitle"
    hintKey: "qbSearchHint"

    SettingsRow {
      titleKey: "qbEngine"
      stacked: true
      SettingsChips {
        model: page.engineChoices
        current: QuickBarConfig.engineId
        onPicked: v => QuickBarConfig.set("engineId", v)
      }
    }

    SettingsRow {
      visible: QuickBarConfig.engineId === "custom"
      titleKey: "qbCustomUrl"
      hintKey: "qbCustomUrlHint"
      stacked: true
      SettingsField {
        placeholder: "https://…?q=%s"
        value: QuickBarConfig.engineCustom
        onSubmitted: text => QuickBarConfig.set("engineCustom", text)
      }
    }

    SettingsRow {
      titleKey: "qbBangs"
      hintKey: "qbBangsHint"
      SettingsSwitch {
        checked: QuickBarConfig.bangsEnabled
        onToggled: QuickBarConfig.toggle("bangsEnabled")
      }
    }
    SettingsNote {
      visible: QuickBarConfig.bangsEnabled
      text: Translations.t("qbBangsList") + "  " + page.bangList
    }
  }

  SettingsSection {
    titleKey: "qbFilesTitle"
    hintKey: "qbFilesHint"

    SettingsRow {
      titleKey: "qbFilesEnable"
      SettingsSwitch {
        checked: QuickBarConfig.filesEnabled
        onToggled: QuickBarConfig.toggle("filesEnabled")
      }
    }

    SettingsRow {
      titleKey: "qbFilesOpener"
      hintKey: "qbFilesOpenerHint"
      enabled: QuickBarConfig.filesEnabled
      SettingsChoice {
        model: page.openerChoices
        current: QuickBarConfig.fileOpener
        onPicked: v => QuickBarConfig.set("fileOpener", v)
      }
    }
    SettingsNote {
      visible: QuickBarConfig.filesEnabled
      text: Translations.t("qbTerminalNow").replace("%1", page.terminalName)
    }

    SettingsRow {
      titleKey: "qbFilesEditor"
      hintKey: "qbFilesEditorHint"
      enabled: QuickBarConfig.filesEnabled
      SettingsField {
        placeholder: "nvim"
        value: QuickBarConfig.fileEditor
        onSubmitted: text => QuickBarConfig.set("fileEditor", text)
      }
    }
    SettingsNote {
      visible: QuickBarConfig.filesEnabled && !QuickBarConfig.editorFound
      kind: "error"
      text: Translations.t("qbEditorMissing").replace("%1", QuickBarConfig.editorBin)
    }

    SettingsRow {
      titleKey: "qbFilesSmart"
      hintKey: "qbFilesSmartHint"
      enabled: QuickBarConfig.filesEnabled
      SettingsSwitch {
        checked: QuickBarConfig.fileSmartOpen
        onToggled: QuickBarConfig.toggle("fileSmartOpen")
      }
    }

    SettingsRow {
      titleKey: "qbFilesRoots"
      hintKey: "qbFilesRootsHint"
      enabled: QuickBarConfig.filesEnabled
      SettingsField {
        placeholder: "~"
        value: QuickBarConfig.fileRoots
        onSubmitted: text => QuickBarConfig.set("fileRoots", text)
      }
    }

    SettingsRow {
      titleKey: "qbFilesDepth"
      hintKey: "qbFilesDepthHint"
      enabled: QuickBarConfig.filesEnabled
      NumberStepper {
        Layout.fillWidth: false
        Layout.preferredWidth: 140
        Layout.preferredHeight: 34
        value: QuickBarConfig.fileDepth
        min: 1; max: 12; step: 1
        onEdited: v => QuickBarConfig.set("fileDepth", v)
      }
    }

    SettingsRow {
      titleKey: "qbFilesMax"
      enabled: QuickBarConfig.filesEnabled
      NumberStepper {
        Layout.fillWidth: false
        Layout.preferredWidth: 140
        Layout.preferredHeight: 34
        value: QuickBarConfig.fileMax
        min: 3; max: 8; step: 1
        onEdited: v => QuickBarConfig.set("fileMax", v)
      }
    }

    SettingsRow {
      titleKey: "qbFilesHidden"
      enabled: QuickBarConfig.filesEnabled
      SettingsSwitch {
        checked: QuickBarConfig.fileHidden
        onToggled: QuickBarConfig.toggle("fileHidden")
      }
    }
  }
}
