// BarTemplates

import QtQuick
import QtQuick.Layouts
import "../COMMON"
import "../Services/Lang"

ColumnLayout {
  id: tpl

  Layout.fillWidth: true
  spacing: 10

  property string pending: ""
  enabled: Theme.barTemplatesAvailable
  opacity: tpl.enabled ? 1 : 0.5

  SettingsNote {
    visible: !Theme.barTemplatesAvailable
    kind: "warn"
    text: Translations.t("barTplIslandsOnly")
  }

  function builtinLabel(id) {
    return Translations.t("barTplBuiltin_" + id)
  }

  function chipModel() {
    const out = []
    const b = Theme.barBuiltinNames
    for (let i = 0; i < b.length; i++) out.push({ value: b[i], label: tpl.builtinLabel(b[i]), icon: "◆" })
    const u = Theme.barTemplateNames
    for (let i = 0; i < u.length; i++) out.push({ value: u[i], label: u[i], icon: "★" })
    return out
  }

  SettingsChips {
    model: tpl.chipModel()
    current: tpl.pending
    onPicked: value => { tpl.pending = value }
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: 8

    SettingsBtn {
      icon: "⤓"
      text: Translations.t("barTplLoad")
      primary: true
      enabled: tpl.pending !== ""
      onClicked: Theme.loadBarTemplate(tpl.pending)
    }

    SettingsBtn {
      icon: "✕"
      text: Translations.t("barTplDelete")
      enabled: tpl.pending !== "" && Theme.barTemplateNames.indexOf(tpl.pending) >= 0
      onClicked: {
        Theme.deleteBarTemplate(tpl.pending)
        tpl.pending = ""
      }
    }

    Item { Layout.fillWidth: true }
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: 8

    SettingsField {
      id: nameField
      placeholder: Translations.t("barTplName")
      onSubmitted: text => {
        if (Theme.saveBarTemplate(text)) tpl.pending = Theme.cleanTemplateName(text)
      }
    }

    SettingsBtn {
      icon: "⤒"
      text: Translations.t("barTplSave")
      enabled: Theme.cleanTemplateName(nameField.input.text) !== ""
        && Theme.barBuiltinNames.indexOf(Theme.cleanTemplateName(nameField.input.text)) < 0
      onClicked: {
        const n = Theme.cleanTemplateName(nameField.input.text)
        if (Theme.saveBarTemplate(n)) tpl.pending = n
      }
    }
  }
}
