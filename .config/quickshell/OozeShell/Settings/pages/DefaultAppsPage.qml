// DefaultAppsPage

import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."
import "../../COMMON"
import "../../Services/Lang"
import "../../Services/DefaultApps"

SettingsPage {
  id: page
  catId: "defaultapps"
  Component.onCompleted: DefaultApps.refreshMime()

  readonly property var roleSections: [
    { titleKey: "daSecEssential", roles: ["browser", "terminal", "files"] },
    { titleKey: "daSecEditing", roles: ["editor"] },
    { titleKey: "daSecMedia", roles: ["music", "video"] }
  ]
  function rolesIn(ids) {
    return DefaultApps.roles.filter(r => ids.indexOf(r.id) >= 0)
  }

  property string sampleRole: "browser"

  readonly property var sampleKeys: ({
    browser: "b", terminal: "t", files: "e", editor: "n",
    music: "p", video: "v"
  })
  readonly property string sampleKey: page.sampleKeys[page.sampleRole] ?? "b"
  readonly property string ipcFull: "qs ipc -p " + Quickshell.shellDir + " call apps open " + page.sampleRole
  readonly property string ipcCommand: "oozeshell apps open " + page.sampleRole
  readonly property string installCommand: "ln -s " + Quickshell.shellDir + "/Tools/oozeshell ~/.local/bin/oozeshell"
  readonly property string mangoBind: "bind=SUPER," + page.sampleKey + ",spawn," + page.ipcCommand
  readonly property string homeDir: Quickshell.env("HOME") ?? ""
  readonly property string shellFile: {
    const f = Quickshell.shellDir + "/shell.qml"
    return page.homeDir !== "" && f.indexOf(page.homeDir + "/") === 0 ? "~" + f.slice(page.homeDir.length) : f
  }
  readonly property string niriKey: "Mod+" + page.sampleKey.charAt(0).toUpperCase() + page.sampleKey.slice(1)

  function niriBindFor(key, call) {
    return key + " {\n    spawn-sh \"quickshell ipc -p " + page.shellFile + " call -- " + call + "\";\n}"
  }

  readonly property string niriBind: page.niriBindFor(page.niriKey, "apps open " + page.sampleRole)
  readonly property string moreCommands:
    "apps url <address>  ·  apps urlPrivate <address>  ·  apps file <path>  ·  apps dir <path>  ·  " +
    "apps term <command>  ·  apps openWith <role> <arg>  ·  apps any <target>  ·  " +
    "apps set <role> <app>  ·  apps custom <role> <command>  ·  apps get <role>  ·  apps list  ·  apps state"

  component CodeLine: SettingsRow {
    id: cl
    property string code: ""
    stacked: true

    RowLayout {
      Layout.fillWidth: true
      spacing: 8

      SkinRect {
        Layout.fillWidth: true
        Layout.preferredHeight: codeText.implicitHeight + 18
        radius: Theme.cozy ? 4 : 10
        color: Theme.surfaceHigh

        TextEdit {
          id: codeText
          anchors { fill: parent; margins: 9 }
          readOnly: true
          selectByMouse: true
          wrapMode: TextEdit.WrapAnywhere
          text: cl.code
          color: Theme.text
          selectionColor: Theme.primary
          selectedTextColor: Theme.textOnPrimary
          font.pixelSize: Theme.sfs(11)
          font.family: Theme.monoFamily
        }
      }

      SettingsBtn {
        Layout.alignment: Qt.AlignTop
        icon: "󰆏"
        text: Translations.t("daCopy")
        onClicked: Quickshell.execDetached(["wl-copy", cl.code])
      }
    }
  }

  component RoleRow: SettingsRow {
    id: rr
    required property var info

    readonly property string role: rr.info.id
    readonly property string choice: DefaultApps.choiceOf(rr.role)
    readonly property var opts: DefaultApps.choicesFor(rr.role)
    readonly property bool choiceMissing: rr.opts.some(o => o.missing && o.id === rr.choice)

    title: Translations.t(rr.info.nameKey)
    hint: rr.info.linked !== "" ? Translations.t(rr.info.linked === "quickbar" ? "daLinkedBrowser" : "daLinkedTerminal") : ""
    stacked: true

    ColumnLayout {
      Layout.fillWidth: true
      spacing: 8

      SettingsChips {
        model: rr.opts.map(o => ({
          value: o.id,
          label: o.id === "system" ? Translations.t("daSystem")
               : o.id === "custom" ? Translations.t("daCustom") : o.name
        }))
        current: rr.choice
        onPicked: v => DefaultApps.setChoice(rr.role, v)
      }

      SettingsNote {
        visible: rr.choiceMissing
        kind: "error"
        text: Translations.t("daMissing")
      }

      SettingsNote {
        visible: DefaultApps.mimeNoteFor(rr.role) !== ""
        kind: "info"
        text: DefaultApps.mimeNoteFor(rr.role)
      }

      Text {
        visible: rr.choice === "custom"
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: Translations.t("daCustomLabel") + " — " + Translations.t("daCustomHint")
        color: Theme.subtext
        font.pixelSize: Theme.sfs(10)
        font.family: Theme.fontFamily
      }

      SettingsField {
        visible: rr.choice === "custom"
        placeholder: Translations.t("daCustomPlaceholder")
        value: DefaultApps.customs[rr.role] ?? ""
        onSubmitted: text => DefaultApps.setCustom(rr.role, text)
      }

      SettingsBtn {
        icon: ""
        text: Translations.t("daApplySystem")
        visible: DefaultApps.mimeRoles[rr.role] !== undefined
          && DefaultApps.resolveChoiceDesktop(rr.role, rr.choice) !== ""
        onClicked: DefaultApps.setSystemDefault(rr.role, DefaultApps.resolveChoiceDesktop(rr.role, rr.choice))
      }

      SettingsBtn {
        icon: "󰐊"
        text: Translations.t("daTest")
        onClicked: DefaultApps.run(rr.role, [], false)
      }
    }
  }

  Repeater {
    model: page.roleSections
    delegate: SettingsSection {
      required property var modelData
      property var sec: modelData
      titleKey: sec.titleKey

      Repeater {
        model: page.rolesIn(sec.roles)
        delegate: RoleRow {
          required property var modelData
          info: modelData
        }
      }
    }
  }

  SettingsSection {
    titleKey: "daIpcTitle"
    hintKey: "daIpcHint"

    SettingsRow {
      stacked: true

      SettingsChips {
        model: DefaultApps.roles.map(r => ({ value: r.id, label: r.id, icon: r.icon }))
        current: page.sampleRole
        onPicked: v => page.sampleRole = v
      }
    }

    CodeLine { titleKey: "daIpcCommand"; code: page.ipcCommand }
    CodeLine { titleKey: "daIpcMango";   code: page.mangoBind }
    CodeLine { titleKey: "daIpcNiri";    code: page.niriBind }
    CodeLine { titleKey: "daIpcFull";    code: page.ipcFull }
    CodeLine { titleKey: "daIpcInstall"; code: page.installCommand }

    SettingsNote { text: page.moreCommands }
  }
}
