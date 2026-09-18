// OozeShell — Selector de idioma (mismo patrón que MonitorSelect)
// Chips clickeables: English / Español / Bahasa Indonesia.
// Al elegir uno emite languageChosen(code) y se cierra.
//
// Se dispara vía IPC:
//   quickshell ipc -p .../shell.qml call -- lang togglePicker
// (bindealo a una tecla en tu config de Hyprland, ej. SUPER+G)

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "../LANG"

Item {
  id: pickerRoot

  property bool open: false
  property string current: "en"
  signal closeRequested()
  signal languageChosen(string code)

  // ─── Colores desde matugen (mismo patrón que el resto) ─────────
  property var colors: ({
    bg: "#0d0e11", border: "#4a90d9", accent: "#4a90d9",
    text: "#e1e2e8", subtext: "#8e9ab0"
  })

  function withAlpha(hex, alpha) {
    var h = String(hex).replace('#', '')
    var r = parseInt(h.substring(0, 2), 16) / 255
    var g = parseInt(h.substring(2, 4), 16) / 255
    var b = parseInt(h.substring(4, 6), 16) / 255
    return Qt.rgba(r, g, b, alpha)
  }

  Process {
    id: loadColors
    command: ["cat", "/tmp/matugen-colors.json"]
    running: false
    property string buffer: ""
    stdout: SplitParser { onRead: line => loadColors.buffer += line }
    onRunningChanged: {
      if (!running && buffer !== "") {
        try {
          const palette = JSON.parse(buffer)
          const c = palette.colors
          pickerRoot.colors = {
            bg:      c.surface?.dark?.color    ?? c.background?.dark?.color ?? "#0d0e11",
            border:  c.primary?.dark?.color    ?? "#4a90d9",
            accent:  c.primary?.dark?.color    ?? "#4a90d9",
            text:    c.on_surface?.dark?.color ?? c.on_background?.dark?.color ?? "#e1e2e8",
            subtext: c.secondary?.dark?.color  ?? "#8e9ab0"
          }
        } catch (e) {
          console.log("language picker color parse error:", e)
        }
        buffer = ""
      }
    }
  }

  onOpenChanged: {
    if (open) {
      loadColors.running = false
      loadColors.running = true
    }
  }

  Variants {
    model: Quickshell.screens

    delegate: Component {
      PanelWindow {
        id: pickerPanel
        property var modelData
        screen: modelData
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "language-picker"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        anchors { top: true; left: true; right: true; bottom: true }
        color: "transparent"
        exclusiveZone: -1
        visible: pickerRoot.open

        Rectangle {
          anchors.fill: parent
          color: Qt.rgba(0, 0, 0, 0.35)
          opacity: pickerRoot.open ? 1.0 : 0.0
          Behavior on opacity { NumberAnimation { duration: 150 } }

          MouseArea {
            anchors.fill: parent
            onClicked: pickerRoot.closeRequested()
          }

          focus: pickerRoot.open
          Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
              pickerRoot.closeRequested()
              event.accepted = true
            }
          }

          // ─── Tarjeta central ────────────────────────────────
          Rectangle {
            id: card
            anchors.centerIn: parent
            width: Math.max(280, chipCol.implicitWidth + 40)
            height: col.implicitHeight + 40
            radius: 22
            color: pickerRoot.withAlpha(pickerRoot.colors.bg, 0.94)
            border.color: pickerRoot.withAlpha(pickerRoot.colors.border, 0.55)
            border.width: 1

            Behavior on color        { ColorAnimation { duration: 300 } }
            Behavior on border.color { ColorAnimation { duration: 300 } }

            MouseArea { anchors.fill: parent; onClicked: {} }

            Column {
              id: col
              anchors { fill: parent; margins: 20 }
              spacing: 12

              Text {
                text: "󰗊  " + Translations.t("chooseLanguage")
                color: pickerRoot.colors.text
                font.pixelSize: 13
                font.bold: true
                font.family: "JetBrainsMono Nerd Font"
              }

              Column {
                id: chipCol
                width: col.width
                spacing: 8

                Repeater {
                  // Nombres de idioma NUNCA se traducen: siempre se
                  // muestran en su propio idioma, para que se
                  // reconozcan aunque no entiendas el activo.
                  model: Translations.availableLanguages

                  delegate: Rectangle {
                    id: chip
                    readonly property bool active: modelData.code === pickerRoot.current
                    width: chipCol.width
                    height: 40
                    radius: 12
                    color: active ? pickerRoot.colors.accent : Qt.rgba(1, 1, 1, 0.08)
                    border.color: active ? "#ffffff" : Qt.rgba(1, 1, 1, 0.18)
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                      anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                        leftMargin: 16
                      }
                      text: modelData.name
                      color: chip.active ? pickerRoot.colors.bg : pickerRoot.colors.text
                      font.pixelSize: 14
                      font.bold: chip.active
                      font.family: "JetBrainsMono Nerd Font"
                    }

                    Text {
                      visible: chip.active
                      anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        rightMargin: 14
                      }
                      text: "󰄬"
                      color: pickerRoot.colors.bg
                      font.pixelSize: 15
                      font.family: "JetBrainsMono Nerd Font"
                    }

                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        pickerRoot.languageChosen(modelData.code)
                        pickerRoot.closeRequested()
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
