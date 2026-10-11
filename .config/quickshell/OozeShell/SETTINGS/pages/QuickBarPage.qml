// QuickBarPage — categoría "Barra rápida": dónde aparece, con qué navegador y buscador abre las búsquedas, y la búsqueda de archivos (nvim en la terminal).

import QtQuick
import QtQuick.Layouts
import ".."
import "../../COMMON"
import "../../LANG"
import "../../QUICKBAR"

SettingsPage {
  id: page
  catId: "quickbar"

  // ─── Piezas chicas ─────────────────────────────────────────────
  component Hint: Text {
    Layout.fillWidth: true
    wrapMode: Text.WordWrap
    color: Theme.subtext
    font.pixelSize: Theme.fs(10)
    font.family: Theme.fontFamily
  }

  component Label: Text {
    Layout.fillWidth: true
    wrapMode: Text.WordWrap
    color: Theme.text
    font.pixelSize: Theme.fs(12)
    font.family: Theme.fontFamily
  }

  component Divider: Rectangle {
    Layout.fillWidth: true
    Layout.preferredHeight: 1
    color: Theme.divider
  }


  component Toggle: RowLayout {
    id: tg
    property string labelKey: ""
    property string hintKey: ""
    property bool checked: false
    signal toggled()

    Layout.fillWidth: true
    spacing: 10

    ColumnLayout {
      Layout.fillWidth: true
      spacing: 2
      Label { text: Translations.t(tg.labelKey) }
      Hint { visible: tg.hintKey !== ""; text: Translations.t(tg.hintKey) }
    }
    SettingsBtn {
      icon: tg.checked ? "▣" : "▢"
      text: tg.checked ? "ON" : "OFF"
      primary: tg.checked
      onClicked: tg.toggled()
    }
  }


  component Field: ColumnLayout {
    id: fld
    property string labelKey: ""
    property string hintKey: ""
    property string placeholder: ""
    property string value: ""
    signal submitted(string text)

    Layout.fillWidth: true
    spacing: 6

    Label { text: Translations.t(fld.labelKey) }
    Hint { visible: fld.hintKey !== ""; text: Translations.t(fld.hintKey) }

    SkinRect {
      Layout.fillWidth: true
      Layout.preferredHeight: 34
      radius: 10
      color: Theme.surfaceHigh
      border.width: fieldInput.activeFocus ? 1 : 0
      border.color: Theme.primary

      TextInput {
        id: fieldInput
        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
        verticalAlignment: TextInput.AlignVCenter
        text: fld.value
        color: Theme.text
        selectionColor: Theme.primary
        selectedTextColor: Theme.textOnPrimary
        font.pixelSize: Theme.fs(12)
        font.family: Theme.fontFamily
        clip: true
        inputMethodHints: Qt.ImhNoPredictiveText
        onEditingFinished: {
          fld.submitted(text)


          text = Qt.binding(() => fld.value)
        }

        Text {
          visible: fieldInput.text === "" && !fieldInput.activeFocus && fld.placeholder !== ""
          text: fld.placeholder
          color: Theme.subtext
          font.pixelSize: Theme.fs(12)
          font.family: Theme.fontFamily
        }
      }
    }
  }

  // ─── Datos ─────────────────────────────────────────────────────
  readonly property var positions: [
    { id: "top",    key: "qbPosTop" },
    { id: "center", key: "qbPosCenter" },
    { id: "bottom", key: "qbPosBottom" }
  ]
  readonly property var widthModes: [
    { id: "compact", key: "qbWidthCompact" },
    { id: "normal",  key: "qbWidthNormal" },
    { id: "wide",    key: "qbWidthWide" }
  ]


  readonly property var browserChoices: {
    const out = [{ id: "default", name: Translations.t("qbBrowserDefault") }]
    const inst = QuickBarConfig.installedBrowsers
    const all = QuickBarConfig.browsers
    for (let i = 0; i < all.length; i++)
      if (inst.indexOf(all[i].id) >= 0 || all[i].id === QuickBarConfig.browserId)
        out.push({ id: all[i].id, name: all[i].name })
    return out
  }
  readonly property bool browserMissing: QuickBarConfig.browserId !== "default"
    && QuickBarConfig.detected && QuickBarConfig.installedBrowsers.indexOf(QuickBarConfig.browserId) < 0

  readonly property var engineChoices: QuickBarConfig.engines.concat(
    [{ id: "custom", name: Translations.t("qbEngineCustom") }])


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

  // ═══ Posición y tamaño ═════════════════════════════════════════
  SettingsSection {
    titleKey: "qbLookTitle"
    hintKey: "qbLookHint"

    Label { text: Translations.t("qbPosition") }
    Flow {
      Layout.fillWidth: true
      spacing: 8
      Repeater {
        model: page.positions
        delegate: SettingsBtn {
          required property var modelData
          text: Translations.t(modelData.key)
          primary: QuickBarConfig.position === modelData.id
          onClicked: QuickBarConfig.set("position", modelData.id)
        }
      }
    }

    Divider {}

    Label { text: Translations.t("qbWidth") }
    Flow {
      Layout.fillWidth: true
      spacing: 8
      Repeater {
        model: page.widthModes
        delegate: SettingsBtn {
          required property var modelData
          text: Translations.t(modelData.key)
          primary: QuickBarConfig.widthMode === modelData.id
          onClicked: QuickBarConfig.set("widthMode", modelData.id)
        }
      }
    }
  }

  // ═══ Navegador ═════════════════════════════════════════════════
  SettingsSection {
    titleKey: "qbBrowserTitle"
    hintKey: "qbBrowserHint"

    Label { text: Translations.t("qbBrowserPref") }
    Flow {
      Layout.fillWidth: true
      spacing: 8
      Repeater {
        model: page.browserChoices
        delegate: SettingsBtn {
          required property var modelData
          icon: "󰖟"
          text: modelData.name
          primary: QuickBarConfig.browserId === modelData.id
          onClicked: QuickBarConfig.set("browserId", modelData.id)
        }
      }
    }
    Hint {
      visible: page.browserMissing
      color: Theme.error
      text: Translations.t("qbBrowserMissing").replace("%1", (QuickBarConfig.browserInfo(QuickBarConfig.browserId) ?? { name: QuickBarConfig.browserId }).name)
    }

    Divider {}


    Toggle {
      opacity: QuickBarConfig.browser !== null ? 1 : 0.45
      enabled: QuickBarConfig.browser !== null
      labelKey: "qbPrivate"
      hintKey: "qbPrivateHint"
      checked: QuickBarConfig.privateWindow
      onToggled: QuickBarConfig.toggle("privateWindow")
    }
  }

  // ═══ Búsqueda web ══════════════════════════════════════════════
  SettingsSection {
    titleKey: "qbSearchTitle"
    hintKey: "qbSearchHint"

    Label { text: Translations.t("qbEngine") }
    Flow {
      Layout.fillWidth: true
      spacing: 8
      Repeater {
        model: page.engineChoices
        delegate: SettingsBtn {
          required property var modelData
          text: modelData.name
          primary: QuickBarConfig.engineId === modelData.id
          onClicked: QuickBarConfig.set("engineId", modelData.id)
        }
      }
    }

    Field {
      visible: QuickBarConfig.engineId === "custom"
      labelKey: "qbCustomUrl"
      hintKey: "qbCustomUrlHint"
      placeholder: "https://…?q=%s"
      value: QuickBarConfig.engineCustom
      onSubmitted: text => QuickBarConfig.set("engineCustom", text)
    }

    Divider {}

    Toggle {
      labelKey: "qbBangs"
      hintKey: "qbBangsHint"
      checked: QuickBarConfig.bangsEnabled
      onToggled: QuickBarConfig.toggle("bangsEnabled")
    }
    Hint {
      visible: QuickBarConfig.bangsEnabled
      text: Translations.t("qbBangsList") + "  " + page.bangList
    }
  }

  // ═══ Búsqueda de archivos ══════════════════════════════════════
  SettingsSection {
    titleKey: "qbFilesTitle"
    hintKey: "qbFilesHint"

    Toggle {
      labelKey: "qbFilesEnable"
      checked: QuickBarConfig.filesEnabled
      onToggled: QuickBarConfig.toggle("filesEnabled")
    }


    ColumnLayout {
      Layout.fillWidth: true
      spacing: 10
      opacity: QuickBarConfig.filesEnabled ? 1 : 0.45
      enabled: QuickBarConfig.filesEnabled

      Divider {}

      Label { text: Translations.t("qbFilesOpener") }
      Flow {
        Layout.fillWidth: true
        spacing: 8
        SettingsBtn {
          icon: "󰆍"
          text: Translations.t("qbFilesOpenerNvim")
          primary: QuickBarConfig.fileOpener === "nvim"
          onClicked: QuickBarConfig.set("fileOpener", "nvim")
        }
        SettingsBtn {
          icon: "󰈔"
          text: Translations.t("qbFilesOpenerDefault")
          primary: QuickBarConfig.fileOpener === "default"
          onClicked: QuickBarConfig.set("fileOpener", "default")
        }
      }
      Hint { text: Translations.t("qbFilesOpenerHint") }
      Hint {
        font.bold: true
        text: Translations.t("qbTerminalNow").replace("%1", page.terminalName)
      }

      Divider {}

      Field {
        labelKey: "qbFilesEditor"
        hintKey: "qbFilesEditorHint"
        placeholder: "nvim"
        value: QuickBarConfig.fileEditor
        onSubmitted: text => QuickBarConfig.set("fileEditor", text)
      }
      Hint {
        visible: !QuickBarConfig.editorFound
        color: Theme.error
        text: Translations.t("qbEditorMissing").replace("%1", QuickBarConfig.editorBin)
      }

      Toggle {
        labelKey: "qbFilesSmart"
        hintKey: "qbFilesSmartHint"
        checked: QuickBarConfig.fileSmartOpen
        onToggled: QuickBarConfig.toggle("fileSmartOpen")
      }

      Divider {}

      Field {
        labelKey: "qbFilesRoots"
        hintKey: "qbFilesRootsHint"
        placeholder: "~"
        value: QuickBarConfig.fileRoots
        onSubmitted: text => QuickBarConfig.set("fileRoots", text)
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: 10
        Label { text: Translations.t("qbFilesDepth") }
        NumberStepper {
          Layout.preferredWidth: 130
          value: QuickBarConfig.fileDepth
          min: 1; max: 12; step: 1
          onEdited: v => QuickBarConfig.set("fileDepth", v)
        }
      }
      Hint { text: Translations.t("qbFilesDepthHint") }

      RowLayout {
        Layout.fillWidth: true
        spacing: 10
        Label { text: Translations.t("qbFilesMax") }
        NumberStepper {
          Layout.preferredWidth: 130
          value: QuickBarConfig.fileMax
          min: 3; max: 8; step: 1
          onEdited: v => QuickBarConfig.set("fileMax", v)
        }
      }

      Toggle {
        labelKey: "qbFilesHidden"
        checked: QuickBarConfig.fileHidden
        onToggled: QuickBarConfig.toggle("fileHidden")
      }
    }
  }
}
