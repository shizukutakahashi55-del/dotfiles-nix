// WidgetQuickSettings — panel lateral compacto para ajustar widgets sin tapar el escritorio. Se cierra solo con Esc o con su botón; el lado (izquierda/derecha) se cambia desde el encabezado.

import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../COMMON"
import "../Services/Lang"
import "../Modules/Widgets"
import "./pages"

Scope {
  id: root

  property bool open: false
  property bool keyGrab: false

  readonly property bool onRight: WidgetConfig.quickSide !== "left"
  readonly property var screenRef: Quickshell.screens.find(s => s.name === WidgetConfig.quickMonitor) ?? Quickshell.screens[0]
  readonly property int panelW: Math.round(380 * Theme.settingsTextScale)
  readonly property int edge: 10
  readonly property string selectedId: WidgetConfig.byId[WidgetConfig.quickId] ? WidgetConfig.quickId : (WidgetConfig.allIds[0] ?? "")
  readonly property var selectedCfg: WidgetConfig.byId[root.selectedId] ?? null

  function tr(prefix, id, fallback) {
    const k = prefix + id
    const t = Translations.t(k)
    return t === k ? (fallback ?? id) : t
  }
  function typeTitle(type) {
    const e = WidgetRegistry.get(type)
    return root.tr("wgType_", type, e ? e.title : type)
  }
  function chipLabel(id) {
    const c = WidgetConfig.byId[id]
    if (!c) return id
    const n = id.split("-").pop()
    return root.typeTitle(c.type) + " " + n
  }
  function isTextField(f) {
    return !!f && typeof f.cursorPosition !== "undefined" && typeof f.selectByMouse !== "undefined"
  }
  function handleKey(e) {
    if (e.key !== Qt.Key_Escape) return
    let f = null
    try {
      const w = keyScope.Window.window
      f = w ? w.activeFocusItem : null
    } catch (err) { f = null }
    if (root.isTextField(f)) {
      f.focus = false
      keyScope.forceActiveFocus()
    } else {
      WidgetConfig.closeQuick()
    }
    e.accepted = true
  }

  PanelWindow {
    id: win

    screen: root.screenRef
    visible: true
    color: "transparent"
    exclusiveZone: 0
    anchors { top: true; bottom: true; left: !root.onRight; right: root.onRight }
    margins { top: root.edge; bottom: root.edge; left: root.edge; right: root.edge }
    implicitWidth: root.panelW

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "oozeshell-widget-quick"
    WlrLayershell.keyboardFocus: !root.open ? WlrKeyboardFocus.None : (root.keyGrab ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand)

    property Region noInput: Region {}
    property Region panelInput: Region { item: panel }
    mask: root.open ? win.panelInput : win.noInput

    Connections {
      target: root
      function onOpenChanged() {
        if (root.open) {
          keyScope.forceActiveFocus()
          root.keyGrab = true
          keyGrabTimer.restart()
        } else {
          root.keyGrab = false
        }
      }
    }
    Timer { id: keyGrabTimer; interval: 250; onTriggered: root.keyGrab = false }

    FocusScope {
      id: keyScope
      anchors.fill: parent
      focus: true
      Keys.onPressed: event => root.handleKey(event)

      SkinRect {
        id: panel
        width: parent.width
        height: parent.height
        x: root.open ? 0 : (root.onRight ? 36 : -36)
        opacity: root.open ? 1 : 0
        visible: opacity > 0
        color: Theme.bg
        radius: Theme.panelRadius
        border.width: Theme.bw1
        border.color: Theme.edge
        raised: true
        Behavior on x { NumberAnimation { duration: Theme.animDuration(200); easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: Theme.animDuration(160) } }

        MouseArea { anchors.fill: parent }

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Theme.cozy ? 12 : 8
          spacing: 0

          RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            Layout.leftMargin: 8
            Layout.rightMargin: 4
            spacing: 6

            Text {
              text: "󰒓"
              color: Theme.primary
              font.pixelSize: Theme.sfs(18)
              font.family: Theme.monoFamily
            }
            Text {
              Layout.fillWidth: true
              Layout.minimumWidth: 0
              elide: Text.ElideRight
              text: Translations.t("wgQuickTitle")
              color: Theme.text
              font.bold: true
              font.pixelSize: Theme.sfs(15)
              font.family: Theme.titleFamily
            }
            SettingsIconBtn {
              icon: root.onRight ? "󰅁" : "󰅂"
              onClicked: WidgetConfig.toggleQuickSide()
            }
            SettingsIconBtn {
              icon: "󰅖"
              onClicked: WidgetConfig.closeQuick()
            }
          }

          Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }

          Flickable {
            id: flick
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: 8
            contentWidth: width
            contentHeight: content.implicitHeight + 8
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick

            MouseArea {
              anchors.fill: parent
              acceptedButtons: Qt.NoButton
              onWheel: wheel => {
                flick.contentY = Math.max(0, Math.min(flick.contentHeight - flick.height, flick.contentY - wheel.angleDelta.y))
              }
            }

            ColumnLayout {
              id: content
              width: flick.width - 6
              spacing: 12

              SettingsSection {
                visible: WidgetConfig.allIds.length === 0
                titleKey: "wgListTitle"
                SettingsNote { text: Translations.t("wgListEmptyQuick") }
              }

              SettingsSection {
                visible: WidgetConfig.allIds.length > 0
                titleKey: "wgListTitle"

                SettingsRow {
                  stacked: true
                  divider: false
                  SettingsChips {
                    model: WidgetConfig.allIds.map(id => ({
                      value: id,
                      label: root.chipLabel(id),
                      enabled: (WidgetConfig.byId[id] ?? { enabled: true }).enabled
                    }))
                    current: root.selectedId
                    onPicked: v => {
                      if (removeBtn.confirm) { removeBtn.confirm = false; removeTimer.stop() }
                      WidgetConfig.quickId = v
                    }
                  }
                }

                SettingsRow {
                  visible: root.selectedCfg !== null
                  title: root.selectedCfg ? root.typeTitle(root.selectedCfg.type) : ""
                  hint: root.selectedCfg
                    ? root.selectedId + "  ·  " + root.tr("wgStyle_", root.selectedCfg.style) + "  ·  " + root.selectedCfg.w + " × " + root.selectedCfg.h
                    : ""

                  SettingsSwitch {
                    checked: root.selectedCfg ? root.selectedCfg.enabled : false
                    onToggled: WidgetConfig.update(root.selectedId, { enabled: !root.selectedCfg.enabled })
                  }
                  SettingsBtn {
                    id: removeBtn
                    property bool confirm: false
                    icon: "󰆴"
                    text: removeBtn.confirm ? Translations.t("wgRemoveConfirm") : ""
                    primary: removeBtn.confirm
                    onClicked: {
                      if (removeBtn.confirm) {
                        removeBtn.confirm = false
                        WidgetConfig.remove(root.selectedId)
                      } else {
                        removeBtn.confirm = true
                        removeTimer.restart()
                      }
                    }
                    Timer { id: removeTimer; interval: 3000; onTriggered: removeBtn.confirm = false }
                  }
                }

                WidgetEditorBody {
                  visible: root.selectedCfg !== null
                  widgetId: root.selectedId
                }
              }

              SettingsSection {
                titleKey: "wgGeneralTitle"

                SettingsRow {
                  titleKey: "wgEnabled"
                  SettingsSwitch {
                    checked: WidgetConfig.widgetsEnabled
                    onToggled: WidgetConfig.setEnabled(!WidgetConfig.widgetsEnabled)
                  }
                }
                SettingsRow {
                  titleKey: "wgFreeMove"
                  SettingsSwitch {
                    checked: WidgetConfig.freeMove
                    onToggled: WidgetConfig.setFreeMove(!WidgetConfig.freeMove)
                  }
                }
                SettingsRow {
                  titleKey: "wgEditMode"
                  SettingsBtn {
                    icon: "󰆾"
                    text: Translations.t(WidgetConfig.editMode ? "wgEditModeDone" : "wgEditMode")
                    primary: WidgetConfig.editMode
                    enabled: WidgetConfig.allIds.length > 0
                    onClicked: WidgetConfig.editMode = !WidgetConfig.editMode
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
                  stacked: true
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
                        text: root.typeTitle(modelData.id)
                        onClicked: WidgetConfig.quickId = WidgetConfig.add(modelData.id, "")
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
