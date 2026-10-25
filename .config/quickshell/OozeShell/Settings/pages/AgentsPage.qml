import Quickshell
import QtQuick
import QtQuick.Layouts
import ".."
import "../../COMMON"
import "../../Services/Lang"
import "../../Services/Agents"

SettingsPage {
  id: page
  catId: "agents"

  onActiveChanged: if (active) AgentsService.refresh()

  readonly property var apiAgents: AgentsService.agents.filter(a => a.kind === "api")
  readonly property var otherAgents: AgentsService.agents.filter(a => a.kind !== "api")
  readonly property var chipModel: AgentsService.agents.map(a => ({ value: a.id, label: a.name }))

  readonly property var sizeModel: [
    { value: "minimal", label: Translations.t("agentsLevelMinimal") },
    { value: "compact", label: Translations.t("agentsLevelCompact") },
    { value: "small",   label: Translations.t("agentsLevelSmall") },
    { value: "normal",  label: Translations.t("agentsLevelNormal") },
    { value: "large",   label: Translations.t("agentsLevelLarge") }
  ]

  readonly property var levelModel: [
    { value: "small",  label: Translations.t("agentsLevelSmall") },
    { value: "normal", label: Translations.t("agentsLevelNormal") },
    { value: "large",  label: Translations.t("agentsLevelLarge") }
  ]

  function keyStatus(id) {
    const s = AgentsService.secrets[id] ?? "none"
    return s === "keyring" ? Translations.t("agentsKeyStatusKeyring")
         : (s === "file" ? Translations.t("agentsKeyStatusFile") : Translations.t("agentsKeyStatusNone"))
  }

  readonly property string backendText: AgentsService.backend === "keyring" ? Translations.t("agentsBackendKeyring")
    : (AgentsService.backend === "file" ? Translations.t("agentsBackendFile") : Translations.t("agentsBackendNone"))

  SettingsSection {
    titleKey: "agentsActiveTitle"
    hintKey: "agentsActiveHint"

    SettingsRow {
      titleKey: "agentsPick"
      stacked: true
      SettingsChips {
        model: page.chipModel
        current: AgentsService.agent
        onPicked: v => AgentsService.setAgent(v)
      }
    }

    SettingsNote {
      visible: AgentsService.agent !== "" && !AgentsService.configured
      kind: "warn"
      text: Translations.t("agentsNotReady")
    }

    SettingsRow {
      visible: AgentsService.current !== null && AgentsService.current.kind !== "cli"
      titleKey: "agentsModel"
      SettingsField {
        mono: true
        value: AgentsService.modelFor(AgentsService.agent)
        onSubmitted: text => AgentsService.setModel(AgentsService.agent, text)
      }
    }

    SettingsRow {
      titleKey: "agentsSize"
      stacked: true
      SettingsChips {
        model: page.sizeModel
        current: AgentsService.sizeLevel
        onPicked: v => AgentsService.setSizeLevel(v)
      }
    }

    SettingsRow {
      titleKey: "agentsFont"
      stacked: true
      SettingsChips {
        model: page.levelModel
        current: AgentsService.fontLevel
        onPicked: v => AgentsService.setFontLevel(v)
      }
    }

    SettingsRow {
      titleKey: "agentsSystem"
      stacked: true
      SettingsField {
        value: AgentsService.systemPrompt
        onSubmitted: text => AgentsService.setSystemPrompt(text)
      }
    }
  }

  SettingsSection {
    titleKey: "agentsAccountsTitle"
    hintKey: "agentsAccountsHint"

    Repeater {
      model: page.apiAgents
      delegate: SettingsRow {
        required property var modelData
        title: modelData.name
        hint: page.keyStatus(modelData.id)

        SettingsField {
          secret: true
          mono: true
          placeholder: Translations.t("agentsKeyField")
          value: ""
          onSubmitted: text => { if (text.trim() !== "") AgentsService.saveKey(modelData.id, text) }
        }
        SettingsBtn {
          icon: "󰆴"
          enabled: (AgentsService.secrets[modelData.id] ?? "none") !== "none"
          onClicked: AgentsService.removeKey(modelData.id)
        }
      }
    }

    SettingsNote {
      visible: AgentsService.keyMsg !== ""
      kind: AgentsService.keyMsg.indexOf("Saved") >= 0 ? "accent" : "error"
      text: Translations.t(AgentsService.keyMsg)
    }

    SettingsNote {
      kind: AgentsService.backend === "none" ? "error" : "info"
      text: page.backendText
    }
  }

  SettingsSection {
    titleKey: "agentsCliTitle"
    hintKey: "agentsCliHint"

    Repeater {
      model: page.otherAgents
      delegate: SettingsRow {
        required property var modelData
        readonly property bool present: AgentsService.installed[modelData.bin] === true
        title: modelData.name
        hint: present ? Translations.t("agentsInstalled") : Translations.t("agentsNotInstalled")

        SettingsBtn {
          visible: modelData.login.length > 0
          enabled: present
          icon: "󰆍"
          text: Translations.t("agentsLogin")
          onClicked: AgentsService.openLogin(modelData.id)
        }
        SettingsBtn {
          enabled: present
          primary: AgentsService.agent === modelData.id
          text: AgentsService.agent === modelData.id ? Translations.t("agentsInUse") : Translations.t("agentsUse")
          onClicked: AgentsService.setAgent(modelData.id)
        }
      }
    }
  }

  SettingsSection {
    titleKey: "agentsIpcTitle"
    hintKey: "agentsIpcHint"

    TextEdit {
      Layout.fillWidth: true
      Layout.topMargin: 6
      Layout.bottomMargin: 6
      readOnly: true
      selectByMouse: true
      wrapMode: TextEdit.Wrap
      text: "qs ipc call agent toggle\nqs ipc call agent ask \"¿cómo uso docker?\"\nqs ipc call agent copy"
      color: Theme.text
      selectionColor: Theme.primary
      selectedTextColor: Theme.textOnPrimary
      font.pixelSize: Theme.sfs(11)
      font.family: Theme.monoFamily
    }

    SettingsRow {
      titleKey: "agentsHide"
      hintKey: "agentsHideHint"
      SettingsBtn {
        icon: "󰈉"
        text: Translations.t("agentsHideBtn")
        onClicked: {
          if (page.host) page.host.category = "about"
          AgentsService.lock()
        }
      }
    }
  }
}
