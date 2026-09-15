import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Item {
  id: keybindsRoot

  property bool open: false
  signal closeRequested()

  // ─── Colores desde matugen ────────────────────────────────────
  property var colors: ({
    bg:      "#0d0e11",
    border:  "#4a90d9",
    accent:  "#4a90d9",
    text:    "#e1e2e8",
    subtext: "#8e9ab0",
    btn:     "#1e2030",
  })

  Timer {
    id: startupDelay
    interval: 3000
    running: true
    repeat: false
    onTriggered: loadColors.running = true
  }

  Process {
    id: loadColors
    command: ["cat", "/tmp/matugen-colors.json"]
    running: false
    property string buffer: ""
    stdout: SplitParser {
      onRead: line => loadColors.buffer += line
    }
    onRunningChanged: {
      if (!running && buffer !== "") {
        try {
          const palette = JSON.parse(buffer)
          const c = palette.colors
          keybindsRoot.colors = {
            bg:      c.background.dark.color,
            border:  c.primary.dark.color,
            accent:  c.primary.dark.color,
            text:    c.on_background.dark.color,
            subtext: c.secondary.dark.color,
            btn:     c.surface_container.dark.color,
          }
        } catch(e) {
          console.log("keybinds color parse error:", e)
        }
        buffer = ""
      }
    }
  }

  Timer {
    interval: 3000
    running: true
    repeat: true
    onTriggered: {
      loadColors.running = false
      loadColors.running = true
    }
  }

  // ─── Keybinds reales de keybindings.conf ─────────────────────
  property var sections: [
    {
      title: "Aplicaciones",
      icon: "󰀻",
      binds: [
        { keys: ["SUPER", "I"],      desc: "Panel keybindings" },
        { keys: ["SUPER", "Q"],      desc: "Terminal" },
        { keys: ["SUPER", "E"],      desc: "Explorador de archivos" },
        { keys: ["SUPER", "R"],      desc: "Rofi Launcher" },
        { keys: ["SUPER SHIFT", "M"],desc: "Rofi powermenu" },
        { keys: ["SUPER", "W"],      desc: "Selector de wallpaper" },
        { keys: ["SUPER SHIFT", "P"],desc: "Reiniciar OozeShell" },
      ]
    },
    {
      title: "Ventanas",
      icon: "󱂬",
      binds: [
        { keys: ["SUPER", "C"],           desc: "Cerrar ventana activa" },
        { keys: ["SUPER", "V"],           desc: "Toggle flotante" },
        { keys: ["SUPER", "P"],           desc: "Pseudo (dwindle)" },
        { keys: ["SUPER", "J"],           desc: "Toggle split (dwindle)" },
        { keys: ["SUPER", "Tab"],         desc: "Ciclar siguiente" },
        { keys: ["SUPER SHIFT", "Tab"],   desc: "Ciclar anterior" },
        { keys: ["SUPER", "Mouse izq"],   desc: "Mover ventana" },
        { keys: ["SUPER", "Mouse der"],   desc: "Redimensionar ventana" },
      ]
    },
    {
      title: "Foco",
      icon: "󰁌",
      binds: [
        { keys: ["SUPER", "←"],        desc: "Foco izquierda" },
        { keys: ["SUPER", "→"],        desc: "Foco derecha" },
        { keys: ["SUPER", "↑"],        desc: "Foco arriba" },
        { keys: ["SUPER", "↓"],        desc: "Foco abajo" },
        { keys: ["SUPER SHIFT", "←"],  desc: "Mover ventana ←" },
        { keys: ["SUPER SHIFT", "→"],  desc: "Mover ventana →" },
        { keys: ["SUPER SHIFT", "↑"],  desc: "Mover ventana ↑" },
        { keys: ["SUPER SHIFT", "↓"],  desc: "Mover ventana ↓" },
      ]
    },
    {
      title: "Layout",
      icon: "󰕰",
      binds: [
        { keys: ["SUPER", "K"],  desc: "Switch Layout" },
        { keys: ["SUPER", "]"],    desc: "Columna más ancha" },
        { keys: ["SUPER", "["],    desc: "Columna más estrecha" },
      ]
    },
    {
      title: "Workspaces",
      icon: "󰊓",
      binds: [
        { keys: ["SUPER", "1–9"],        desc: "Ir a workspace N" },
        { keys: ["SUPER", "0"],          desc: "Ir a workspace 10" },
        { keys: ["SUPER SHIFT", "1–9"],  desc: "Mover ventana a WS N" },
        { keys: ["SUPER SHIFT", "0"],    desc: "Mover ventana a WS 10" },
        { keys: ["SUPER", "S"],          desc: "Special workspace (magic)" },
        { keys: ["SUPER", "X"],    desc: "Minimize to Special 1App" },
        { keys: ["SUPER SHIFT", "S"],    desc: "Special workspace (special:magic)" },
      ]
    },
    {
      title: "Capturas",
      icon: "󰄀",
      binds: [
        { keys: ["Print"],          desc: "Pantalla completa → clipboard" },
        { keys: ["SUPER", "Print"], desc: "Seleccion Area → clipboard" },

      ]
    }
  ]

  property int activeSection: 0

  // ─── Panel fullscreen overlay ─────────────────────────────────
  PanelWindow {
    id: mainPanel
    visible: keybindsRoot.open
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.namespace: "keybinds-panel"
    anchors { top: true; left: true; right: true; bottom: true }
    color: "transparent"
    exclusiveZone: -1

    Rectangle {
      anchors.fill: parent
      color: "transparent"

      // Click fuera → cerrar
      MouseArea {
        anchors.fill: parent
        onClicked: keybindsRoot.closeRequested()
        z: 0
      }

      // Escape → cerrar
      focus: keybindsRoot.open
      Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
          keybindsRoot.closeRequested()
          event.accepted = true
        }
      }

      // ─── Card ─────────────────────────────────────────────────
      Rectangle {
        x: 78
        y: 32
        width: 580
        height: 460
        radius: 18
        color: keybindsRoot.colors.bg
        border.color: keybindsRoot.colors.border
        border.width: 1
        z: 1

        Behavior on color        { ColorAnimation { duration: 400 } }
        Behavior on border.color { ColorAnimation { duration: 400 } }

        // Bloquear clicks dentro del card
        MouseArea { anchors.fill: parent; onClicked: {} }

        ColumnLayout {
          anchors.fill: parent
          spacing: 0

          // ─── Header ───────────────────────────────────────────
          Item {
            Layout.fillWidth: true
            height: 48

            RowLayout {
              anchors { fill: parent; leftMargin: 18; rightMargin: 18 }
              spacing: 8
              Text {
                text: "󰌌"
                color: keybindsRoot.colors.accent
                font.pixelSize: 18
                font.family: "JetBrainsMono Nerd Font"
                Behavior on color { ColorAnimation { duration: 400 } }
              }
              Text {
                text: "Keybindings"
                color: keybindsRoot.colors.text
                font.pixelSize: 15
                font.bold: true
                Behavior on color { ColorAnimation { duration: 400 } }
              }
              Item { Layout.fillWidth: true }
              Text {
                text: "OozeShell · Hyprland"
                color: keybindsRoot.colors.subtext
                font.pixelSize: 10
                font.family: "JetBrainsMono Nerd Font"
                Behavior on color { ColorAnimation { duration: 400 } }
              }
            }

            Rectangle {
              anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
              height: 1
              color: Qt.rgba(1,1,1,0.07)
            }
          }

          // ─── Sidebar + lista ───────────────────────────────────
          RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // Sidebar categorías
            Rectangle {
              width: 150
              Layout.fillHeight: true
              color: Qt.rgba(0,0,0,0.20)

              ColumnLayout {
                anchors { fill: parent; topMargin: 8; bottomMargin: 8 }
                spacing: 2

                Repeater {
                  model: keybindsRoot.sections.length
                  delegate: Item {
                    Layout.fillWidth: true
                    height: 36

                    Rectangle {
                      anchors.fill: parent
                      color: index === keybindsRoot.activeSection
                        ? Qt.rgba(1,1,1,0.08)
                        : "transparent"
                      Behavior on color { ColorAnimation { duration: 180 } }
                    }

                    Rectangle {
                      visible: index === keybindsRoot.activeSection
                      width: 3; height: 20; radius: 2
                      color: keybindsRoot.colors.accent
                      anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                      Behavior on color { ColorAnimation { duration: 400 } }
                    }

                    RowLayout {
                      anchors { fill: parent; leftMargin: 14; rightMargin: 8 }
                      spacing: 8
                      Text {
                        text: keybindsRoot.sections[index].icon
                        color: index === keybindsRoot.activeSection
                          ? keybindsRoot.colors.accent
                          : keybindsRoot.colors.subtext
                        font.pixelSize: 14
                        font.family: "JetBrainsMono Nerd Font"
                        Behavior on color { ColorAnimation { duration: 200 } }
                      }
                      Text {
                        text: keybindsRoot.sections[index].title
                        color: index === keybindsRoot.activeSection
                          ? keybindsRoot.colors.text
                          : keybindsRoot.colors.subtext
                        font.pixelSize: 12
                        font.bold: index === keybindsRoot.activeSection
                        Behavior on color { ColorAnimation { duration: 200 } }
                      }
                    }

                    MouseArea {
                      anchors.fill: parent
                      onClicked: keybindsRoot.activeSection = index
                      cursorShape: Qt.PointingHandCursor
                    }
                  }
                }

                Item { Layout.fillHeight: true }
              }

              Rectangle {
                anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
                width: 1
                color: Qt.rgba(1,1,1,0.07)
              }
            }

            // Lista de binds
            ListView {
              id: bindsList
              Layout.fillWidth: true
              Layout.fillHeight: true
              topMargin: 8
              bottomMargin: 8
              leftMargin: 12
              rightMargin: 12
              model: keybindsRoot.sections[keybindsRoot.activeSection].binds
              spacing: 3
              clip: true
              ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

              delegate: Rectangle {
                width: bindsList.width - 24
                height: 36
                radius: 8
                color: hoverArea.containsMouse
                  ? Qt.rgba(1,1,1,0.05)
                  : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }

                MouseArea {
                  id: hoverArea
                  anchors.fill: parent
                  hoverEnabled: true
                }

                RowLayout {
                  anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                  spacing: 8

                  // Key caps
                  Row {
                    spacing: 4
                    Repeater {
                      model: modelData.keys
                      delegate: Rectangle {
                        height: 22
                        width: capLabel.implicitWidth + 14
                        radius: 5
                        color: keybindsRoot.colors.btn
                        border.color: Qt.rgba(1,1,1,0.13)
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 400 } }

                        Rectangle {
                          anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                          height: 2; radius: 5
                          color: Qt.rgba(0,0,0,0.30)
                        }

                        Text {
                          id: capLabel
                          anchors.centerIn: parent
                          text: modelData
                          color: keybindsRoot.colors.accent
                          font.pixelSize: 10
                          font.family: "JetBrainsMono Nerd Font"
                          font.bold: true
                          Behavior on color { ColorAnimation { duration: 400 } }
                        }
                      }
                    }
                  }

                  Item { Layout.fillWidth: true }

                  Text {
                    text: modelData.desc
                    color: keybindsRoot.colors.subtext
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideLeft
                    Behavior on color { ColorAnimation { duration: 400 } }
                  }
                }
              }
            }
          }

          // ─── Footer ───────────────────────────────────────────
          Item {
            Layout.fillWidth: true
            height: 30

            Rectangle {
              anchors { top: parent.top; left: parent.left; right: parent.right }
              height: 1
              color: Qt.rgba(1,1,1,0.07)
            }

            RowLayout {
              anchors { fill: parent; leftMargin: 18; rightMargin: 18 }
              Text {
                text: "󰌑  Esc · click fuera para cerrar"
                color: keybindsRoot.colors.subtext
                font.pixelSize: 10
                font.family: "JetBrainsMono Nerd Font"
                Behavior on color { ColorAnimation { duration: 400 } }
              }
              Item { Layout.fillWidth: true }
              Text {
                text: keybindsRoot.sections[keybindsRoot.activeSection].title
                  + "  " + (keybindsRoot.activeSection + 1)
                  + "/" + keybindsRoot.sections.length
                color: keybindsRoot.colors.subtext
                font.pixelSize: 10
                font.family: "JetBrainsMono Nerd Font"
                Behavior on color { ColorAnimation { duration: 400 } }
              }
            }
          }
        }
      }
    }
  }
}
