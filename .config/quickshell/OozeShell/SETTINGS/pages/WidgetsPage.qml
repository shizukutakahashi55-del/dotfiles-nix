// WidgetsPage — categoría "Widgets": widgets de escritorio (WIDGETS/).
// Todo se arma desde WidgetRegistry: un widget nuevo aparece aquí solo (botón "Agregar", estilos, opciones) sin tocar este archivo. Los cambios van por WidgetConfig, que los aplica en vivo y los guarda en widgets.json.

import Quickshell
import QtQuick
import QtQuick.Layouts
import ".."
import "../../COMMON"
import "../../LANG"
import "../../WIDGETS"

SettingsPage {
  id: page
  catId: "widgets"


  function tr(prefix, id, fallback) {
    const k = prefix + id
    const t = Translations.t(k)
    return t === k ? (fallback ?? id) : t
  }
  function typeTitle(type) {
    const e = WidgetRegistry.get(type)
    return page.tr("wgType_", type, e ? e.title : type)
  }

  // ── General: modo mover + capa ──────────────────────────────────
  SettingsSection {
    titleKey: "wgGeneralTitle"
    hintKey: "wgGeneralHint"

    Flow {
      Layout.fillWidth: true
      spacing: 8

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
      SettingsBtn {
        icon: "󰁝"
        text: Translations.t("wgRaise")
        onClicked: WidgetConfig.raiseRequested()
      }
    }

    Text {
      visible: WidgetConfig.editMode
      Layout.fillWidth: true
      wrapMode: Text.WordWrap
      color: Theme.primary
      font.pixelSize: Theme.fs(11)
      font.family: Theme.fontFamily
      text: Translations.t("wgEditModeActive")
    }

    Text {
      Layout.fillWidth: true
      Layout.topMargin: 6
      text: Translations.t("wgLayerTitle")
      color: Theme.text
      font.pixelSize: Theme.fs(12)
      font.bold: true
      font.family: Theme.fontFamily
    }
    Flow {
      Layout.fillWidth: true
      spacing: 8
      SettingsBtn {
        text: Translations.t("wgLayerBottom")
        primary: WidgetConfig.layer === "bottom"
        onClicked: WidgetConfig.setLayer("bottom")
      }
      SettingsBtn {
        text: Translations.t("wgLayerBackground")
        primary: WidgetConfig.layer === "background"
        onClicked: WidgetConfig.setLayer("background")
      }
    }
    Text {
      Layout.fillWidth: true
      wrapMode: Text.WordWrap
      color: Theme.subtext
      font.pixelSize: Theme.fs(10)
      font.family: Theme.fontFamily
      text: Translations.t("wgLayerHint")
    }
  }

  // ── Global: master + opacidad/blur para todos ───────────────
  SettingsSection {
    titleKey: "wgGlobalTitle"
    hintKey: "wgGlobalHint"

    Flow {
      Layout.fillWidth: true
      spacing: 8
      SettingsBtn {
        icon: WidgetConfig.widgetsEnabled ? "▣" : "▢"
        text: Translations.t("wgEnabled")
        primary: WidgetConfig.widgetsEnabled
        onClicked: WidgetConfig.setEnabled(!WidgetConfig.widgetsEnabled)
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: 10
      Text {
        Layout.fillWidth: true
        text: Translations.t("wgGlobalOpacity")
        color: Theme.text
        font.pixelSize: Theme.fs(12)
        font.family: Theme.fontFamily
      }
      SettingsBtn {
        text: WidgetConfig.globalOpacity >= 0 ? "ON" : "OFF"
        primary: WidgetConfig.globalOpacity >= 0
        onClicked: WidgetConfig.setGlobalOpacity(
          WidgetConfig.globalOpacity >= 0 ? -1 : 60)
      }
      NumberStepper {
        Layout.preferredWidth: 130
        enabled: WidgetConfig.globalOpacity >= 0
        opacity: WidgetConfig.globalOpacity >= 0 ? 1 : 0.45
        value: Math.max(0, WidgetConfig.globalOpacity)
        min: 0; max: 100; step: 5
        suffix: "%"
        onEdited: v => WidgetConfig.setGlobalOpacity(v)
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: 10
      Text {
        Layout.fillWidth: true
        text: Translations.t("wgGlobalBlur")
        color: Theme.text
        font.pixelSize: Theme.fs(12)
        font.family: Theme.fontFamily
      }
      SettingsBtn {
        text: WidgetConfig.globalBlur >= 0 ? "ON" : "OFF"
        primary: WidgetConfig.globalBlur >= 0
        onClicked: WidgetConfig.setGlobalBlur(
          WidgetConfig.globalBlur >= 0 ? -1 : 40)
      }
      NumberStepper {
        Layout.preferredWidth: 130
        enabled: WidgetConfig.globalBlur >= 0
        opacity: WidgetConfig.globalBlur >= 0 ? 1 : 0.45
        value: Math.max(0, WidgetConfig.globalBlur)
        min: 0; max: 100; step: 5
        onEdited: v => WidgetConfig.setGlobalBlur(v)
      }
    }
  }

  // ── Agregar ─────────────────────────────────────────────────────
  SettingsSection {
    titleKey: "wgAddTitle"
    hintKey: "wgAddHint"

    Flow {
      Layout.fillWidth: true
      spacing: 8
      Repeater {
        model: WidgetRegistry.types
        delegate: SettingsBtn {
          required property var modelData
          icon: "󰐕"
          text: page.typeTitle(modelData.id)
          onClicked: WidgetConfig.add(modelData.id, "")
        }
      }
    }
  }

  // ── Lista ───────────────────────────────────────────────────────
  SettingsSection {
    visible: WidgetConfig.allIds.length === 0
    titleKey: "wgListTitle"
    Text {
      Layout.fillWidth: true
      wrapMode: Text.WordWrap
      color: Theme.subtext
      font.italic: true
      font.pixelSize: Theme.fs(11)
      font.family: Theme.fontFamily
      text: Translations.t("wgListEmpty")
    }
  }


  Repeater {
    model: WidgetConfig.allIds
    delegate: SettingsSection {
      id: card
      required property string modelData

      readonly property var cfg: WidgetConfig.byId[card.modelData] ?? null
      readonly property var entry: card.cfg ? WidgetRegistry.get(card.cfg.type) : null
      property bool confirmRemove: false

      visible: card.cfg !== null
      borderColor: (card.cfg && card.cfg.enabled) ? Theme.edge : Theme.divider
      spacing: 10


      RowLayout {
        Layout.fillWidth: true
        spacing: 8

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 0
          Text {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: card.cfg ? page.typeTitle(card.cfg.type) : ""
            color: Theme.text
            font.bold: true
            font.pixelSize: Theme.fs(13)
            font.family: Theme.fontFamily
          }
          Text {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: card.modelData
            color: Theme.subtext
            font.pixelSize: Theme.fs(10)
            font.family: Theme.fontFamily
          }
        }
        SettingsBtn {
          text: Translations.t(card.cfg && card.cfg.enabled ? "wgOn" : "wgOff")
          primary: card.cfg ? card.cfg.enabled : false
          onClicked: WidgetConfig.update(card.modelData, { enabled: !card.cfg.enabled })
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
        Timer { id: confirmTimer; interval: 3000; onTriggered: card.confirmRemove = false }
      }


      Text {
        visible: card.entry !== null && card.entry.needsNative && !Theme.nativeActive
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        color: Theme.error
        font.pixelSize: Theme.fs(11)
        font.family: Theme.fontFamily
        text: Translations.t("wgNeedsNative")
      }


      Text {
        Layout.fillWidth: true
        text: Translations.t("wgStyle")
        color: Theme.subtext
        font.pixelSize: Theme.fs(11)
        font.family: Theme.fontFamily
      }
      Flow {
        Layout.fillWidth: true
        spacing: 8
        Repeater {
          model: card.entry ? card.entry.styles : []
          delegate: SettingsBtn {
            required property string modelData
            text: page.tr("wgStyle_", modelData)
            primary: card.cfg ? card.cfg.style === modelData : false
            onClicked: WidgetConfig.setStyle(card.cfg.id, modelData)
          }
        }
      }


      Text {
        Layout.fillWidth: true
        text: Translations.t("wgMonitor")
        color: Theme.subtext
        font.pixelSize: Theme.fs(11)
        font.family: Theme.fontFamily
      }
      Flow {
        Layout.fillWidth: true
        spacing: 8
        SettingsBtn {
          text: Translations.t("wgMonitorAuto")
          primary: card.cfg ? card.cfg.monitor === "" : false
          onClicked: WidgetConfig.update(card.modelData, { monitor: "" })
        }
        Repeater {
          model: Quickshell.screens.map(s => s.name)
          delegate: SettingsBtn {
            required property string modelData
            text: modelData
            primary: card.cfg ? card.cfg.monitor === modelData : false
            onClicked: WidgetConfig.update(card.cfg.id, { monitor: modelData })
          }
        }
      }


      GridLayout {
        Layout.fillWidth: true
        columns: 4
        columnSpacing: 10
        rowSpacing: 8

        Text { text: "X"; color: Theme.subtext; font.pixelSize: Theme.fs(11); font.family: Theme.fontFamily }
        NumberStepper {
          value: card.cfg ? card.cfg.x : 0
          min: -2000; max: 20000; step: 10; suffix: " px"
          onEdited: v => WidgetConfig.update(card.modelData, { x: v })
        }
        Text { text: "Y"; color: Theme.subtext; font.pixelSize: Theme.fs(11); font.family: Theme.fontFamily }
        NumberStepper {
          value: card.cfg ? card.cfg.y : 0
          min: -2000; max: 20000; step: 10; suffix: " px"
          onEdited: v => WidgetConfig.update(card.modelData, { y: v })
        }
        Text { text: Translations.t("wgWidth"); color: Theme.subtext; font.pixelSize: Theme.fs(11); font.family: Theme.fontFamily }
        NumberStepper {
          value: card.cfg ? card.cfg.w : 0
          min: 40; max: 4000; step: 10; suffix: " px"
          onEdited: v => WidgetConfig.update(card.modelData, { w: v })
        }
        Text { text: Translations.t("wgHeight"); color: Theme.subtext; font.pixelSize: Theme.fs(11); font.family: Theme.fontFamily }
        NumberStepper {
          value: card.cfg ? card.cfg.h : 0
          min: 40; max: 4000; step: 10; suffix: " px"
          onEdited: v => WidgetConfig.update(card.modelData, { h: v })
        }
      }


      Text {
        visible: card.entry !== null && Object.keys(card.entry.defaults ?? {}).length > 0
        Layout.fillWidth: true
        Layout.topMargin: 4
        text: Translations.t("wgOptions")
        color: Theme.subtext
        font.pixelSize: Theme.fs(11)
        font.family: Theme.fontFamily
      }
      Repeater {
        model: card.entry ? Object.keys(card.entry.defaults ?? {}) : []
        delegate: ColumnLayout {
          id: optCol
          required property string modelData
          readonly property var def: card.entry.defaults[optCol.modelData]
          readonly property var cur: (card.cfg && card.cfg.options[optCol.modelData] !== undefined)
                                     ? card.cfg.options[optCol.modelData] : optCol.def
          readonly property var range: (card.entry.ranges && card.entry.ranges[optCol.modelData])
                                       ? card.entry.ranges[optCol.modelData] : [0, 100000, 1]
          readonly property bool picker: !!(card.entry.pickers && card.entry.pickers[optCol.modelData])
          property bool browsing: false
          Layout.fillWidth: true
          spacing: 6

          RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
              Layout.fillWidth: true
              elide: Text.ElideRight
              text: page.tr("wgOpt_", optCol.modelData)
              color: Theme.text
              font.pixelSize: Theme.fs(11)
              font.family: Theme.fontFamily
            }
            SettingsBtn {
              visible: typeof optCol.def === "boolean"
              text: Translations.t(optCol.cur ? "wgOn" : "wgOff")
              primary: optCol.cur === true
              onClicked: WidgetConfig.setOption(card.modelData, optCol.modelData, !optCol.cur)
            }
            NumberStepper {
              visible: typeof optCol.def === "number"
              Layout.fillWidth: false
              Layout.preferredWidth: 170
              value: typeof optCol.cur === "number" ? optCol.cur : 0
              min: optCol.range[0]; max: optCol.range[1]; step: optCol.range[2]
              onEdited: v => WidgetConfig.setOption(card.modelData, optCol.modelData, v)
            }

            SkinRect {
              visible: typeof optCol.def === "string"
              Layout.fillWidth: false
              Layout.preferredWidth: 220
              Layout.preferredHeight: 40
              radius: 12
              color: Theme.surface
              border.width: textIn.activeFocus ? 1 : 0
              border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.55)
              TextInput {
                id: textIn
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                verticalAlignment: TextInput.AlignVCenter
                clip: true
                selectByMouse: true
                color: Theme.text
                selectionColor: Theme.primary
                selectedTextColor: Theme.textOnPrimary
                font.pixelSize: Theme.fs(12)
                font.family: Theme.fontFamily

                readonly property string shown: typeof optCol.cur === "string" ? optCol.cur : ""
                onShownChanged: if (!activeFocus) text = shown
                Component.onCompleted: text = shown
                onEditingFinished: WidgetConfig.setOption(card.modelData, optCol.modelData, text.trim())
                Keys.onEscapePressed: { text = shown; focus = false }
              }
            }
            SettingsBtn {
              visible: optCol.picker
              icon: "󰉋"
              text: Translations.t("wgBrowse")
              primary: optCol.browsing
              onClicked: {
                optCol.browsing = !optCol.browsing
                if (optCol.browsing) {
                  const cur = typeof optCol.cur === "string" ? optCol.cur.trim() : ""

                  browser.go(cur !== "" ? cur : Quickshell.env("HOME") + "/Pictures")
                }
              }
            }
          }


          ImageBrowser {
            id: browser
            visible: optCol.browsing
            allowFolder: true
            Layout.fillWidth: true
            Layout.preferredHeight: optCol.browsing ? 300 : 0
            onPicked: path => { WidgetConfig.setOption(card.modelData, optCol.modelData, path); optCol.browsing = false }
            onFolderPicked: path => { WidgetConfig.setOption(card.modelData, optCol.modelData, path); optCol.browsing = false }
            onCancelled: optCol.browsing = false
          }
          Text {
            visible: optCol.browsing
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: Translations.t("wgBrowseHint")
            color: Theme.subtext
            font.pixelSize: Theme.fs(10)
            font.family: Theme.fontFamily
          }
        }
      }
    }
  }
}
