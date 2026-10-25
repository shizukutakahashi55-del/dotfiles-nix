// WidgetsPage — categoría "Widgets": ajustes generales, globales, agregar y la lista de widgets con sus opciones.

import Quickshell
import QtQuick
import QtQuick.Layouts
import ".."
import "../../COMMON"
import "../../Services/Lang"
import "../../Modules/Widgets"

SettingsPage {
  id: page
  catId: "widgets"

  property string openId: ""

  function tr(prefix, id, fallback) {
    const k = prefix + id
    const t = Translations.t(k)
    return t === k ? (fallback ?? id) : t
  }
  function typeTitle(type) {
    const e = WidgetRegistry.get(type)
    return page.tr("wgType_", type, e ? e.title : type)
  }

  SettingsSection {
    titleKey: "wgGeneralTitle"
    hintKey: "wgGeneralHint"

    SettingsRow {
      titleKey: "wgQuickTitle"
      hintKey: "wgQuickHint"
      SettingsBtn {
        icon: "󰒓"
        text: Translations.t("wgQuickOpenBtn")
        primary: WidgetConfig.quickOpen
        onClicked: WidgetConfig.openQuick("", page.host ? page.host.targetScreen : "")
      }
    }

    SettingsRow {
      titleKey: "wgEditMode"
      SettingsBtn {
        icon: "󰆾"
        text: Translations.t(WidgetConfig.editMode ? "wgEditModeDone" : "wgEditMode")
        primary: WidgetConfig.editMode
        enabled: WidgetConfig.allIds.length > 0
        onClicked: {
          WidgetConfig.editMode = !WidgetConfig.editMode

          if (WidgetConfig.editMode && page.host) page.host.closeRequested()
        }
      }
    }
    SettingsNote {
      visible: WidgetConfig.editMode
      kind: "accent"
      text: Translations.t("wgEditModeActive")
    }

    SettingsRow {
      titleKey: "wgFreeMove"
      hintKey: "wgFreeMoveHint"
      SettingsSwitch {
        checked: WidgetConfig.freeMove
        onToggled: WidgetConfig.setFreeMove(!WidgetConfig.freeMove)
      }
    }

    SettingsRow {
      titleKey: "wgLayerTitle"
      hintKey: "wgLayerHint"
      SettingsChoice {
        model: [
          { value: "bottom",     label: Translations.t("wgLayerBottom") },
          { value: "background", label: Translations.t("wgLayerBackground") }
        ]
        current: WidgetConfig.layer
        onPicked: v => WidgetConfig.setLayer(v)
      }
    }

    SettingsRow {
      titleKey: "wgArrange"
      SettingsBtn {
        icon: "󰕮"
        text: ""
        enabled: WidgetConfig.enabledIds.length > 0
        onClicked: WidgetConfig.arrange()
      }
    }

    SettingsRow {
      titleKey: "wgRaise"
      SettingsBtn {
        icon: "󰁝"
        text: ""
        onClicked: WidgetConfig.raiseRequested()
      }
    }
  }

  SettingsSection {
    titleKey: "wgGlobalTitle"
    hintKey: "wgGlobalHint"

    SettingsRow {
      titleKey: "wgEnabled"
      SettingsSwitch {
        checked: WidgetConfig.widgetsEnabled
        onToggled: WidgetConfig.setEnabled(!WidgetConfig.widgetsEnabled)
      }
    }

    WidgetGlobalRow {
      titleKey: "wgGlobalOpacity"
      value: WidgetConfig.globalOpacity
      fallback: 60
      suffix: "%"
      onChanged: v => WidgetConfig.setGlobalOpacity(v)
    }

    WidgetGlobalRow {
      titleKey: "wgGlobalBlur"
      value: WidgetConfig.globalBlur
      fallback: 40
      onChanged: v => WidgetConfig.setGlobalBlur(v)
    }

    SettingsRow {
      titleKey: "wgGlobalBorder"
      SettingsChoice {
        model: [
          { value: -1, label: Translations.t("wgBorderIndividual") },
          { value: 1,  label: Translations.t("wgBorderAll") },
          { value: 0,  label: Translations.t("wgBorderNone") }
        ]
        current: WidgetConfig.globalBorder
        onPicked: v => WidgetConfig.setGlobalBorder(v)
      }
    }
  }

  SettingsSection {
    titleKey: "wgAddTitle"
    hintKey: "wgAddHint"

    SettingsRow {
      stacked: true
      divider: false

      Flow {
        Layout.fillWidth: true
        spacing: 8
        Repeater {
          model: WidgetRegistry.types
          delegate: SettingsBtn {
            required property var modelData
            icon: "󰐕"
            text: page.typeTitle(modelData.id)
            onClicked: page.openId = WidgetConfig.add(modelData.id, "")
          }
        }
      }
    }
  }

  SettingsSection {
    visible: WidgetConfig.allIds.length === 0
    titleKey: "wgListTitle"

    SettingsNote {
      text: Translations.t("wgListEmpty")
    }
  }

  SectionLabel { textScale: Theme.settingsTextScale;
    visible: WidgetConfig.allIds.length > 0
    Layout.fillWidth: true
    Layout.topMargin: 4
    text: Translations.t("wgListTitle")
    color: Theme.primary
  }

  Repeater {
    model: WidgetConfig.allIds
    delegate: SettingsSection {
      id: card
      required property string modelData

      readonly property var cfg: WidgetConfig.byId[card.modelData] ?? null
      readonly property bool open: page.openId === card.modelData
      property bool confirmRemove: false

      visible: card.cfg !== null
      borderColor: (card.cfg && card.cfg.enabled) ? Theme.edge : Theme.divider

      // ── Cabecera ──
      SettingsRow {
        title: card.cfg ? page.typeTitle(card.cfg.type) : ""
        hint: card.cfg
          ? card.modelData + "  ·  " + page.tr("wgStyle_", card.cfg.style) + "  ·  " + card.cfg.w + " × " + card.cfg.h
          : ""

        SettingsSwitch {
          checked: card.cfg ? card.cfg.enabled : false
          onToggled: WidgetConfig.update(card.modelData, { enabled: !card.cfg.enabled })
        }
        SettingsBtn {
          icon: "󰆴"
          text: card.confirmRemove ? Translations.t("wgRemoveConfirm") : ""
          primary: card.confirmRemove
          onClicked: {
            if (card.confirmRemove) WidgetConfig.remove(card.modelData)
            else { card.confirmRemove = true; confirmTimer.restart() }
          }
        }
        SettingsIconBtn {
          icon: card.open ? "▾" : "▸"
          onClicked: page.openId = card.open ? "" : card.modelData
        }
        Timer { id: confirmTimer; interval: 3000; onTriggered: card.confirmRemove = false }
      }

      WidgetEditorBody {
        visible: card.open
        widgetId: card.modelData
      }
    }
  }
}
