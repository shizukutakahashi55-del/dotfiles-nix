import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../LANG"

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

  property var sections: Translations.sections()
  property var vimSections: Translations.vimSections()

  Connections {
    target: Translations
    function onCurrentChanged() {
      keybindsRoot.sections = Translations.sections()
      keybindsRoot.vimSections = Translations.vimSections()
    }
  }

  // "keybinds" | "vim" — qué pestaña está activa arriba del panel.
  property string activeTab: "keybinds"

  // Cada pestaña recuerda su propia sección seleccionada, así
  // cambiar de Keybinds a Vim y volver no resetea la posición.
  property int activeSection: 0
  property int activeVimSection: 0

  readonly property var currentSections: keybindsRoot.activeTab === "vim"
    ? keybindsRoot.vimSections
    : keybindsRoot.sections

  readonly property int currentIndex: keybindsRoot.activeTab === "vim"
    ? keybindsRoot.activeVimSection
    : keybindsRoot.activeSection

  function setCurrentIndex(i) {
    if (keybindsRoot.activeTab === "vim") keybindsRoot.activeVimSection = i
    else keybindsRoot.activeSection = i
  }

  // ─── Panel fullscreen overlay ─────────────────────────────────
  PanelWindow {
    id: mainPanel

    visible: keybindsRoot.open

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.namespace: "keybinds-panel"

    anchors {
      top: true
      left: true
      right: true
      bottom: true
    }

    color: "transparent"
    exclusiveZone: -1

    Rectangle {
      anchors.fill: parent
      color: "transparent"

      // ─── Click fuera → cerrar ────────────────────────────────
      MouseArea {
        anchors.fill: parent
        onClicked: keybindsRoot.closeRequested()
        z: 0
      }

      // ─── Escape → cerrar / navegación con teclado ───────────
      focus: keybindsRoot.open

      Keys.onPressed: event => {
        const total = keybindsRoot.currentSections.length

        switch (event.key) {
          case Qt.Key_Escape:
            keybindsRoot.closeRequested()
            event.accepted = true
            break

          // ─── Cambiar de pestaña (Keybinds ↔ Vim) ─────────
          case Qt.Key_PageDown:
          case Qt.Key_PageUp:
            keybindsRoot.activeTab = keybindsRoot.activeTab === "vim" ? "keybinds" : "vim"
            event.accepted = true
            break

          // ─── Siguiente sección ───────────────────────────
          case Qt.Key_Down:
          case Qt.Key_J:
          case Qt.Key_Right:
          case Qt.Key_L:
          case Qt.Key_Tab:
            keybindsRoot.setCurrentIndex((keybindsRoot.currentIndex + 1) % total)
            event.accepted = true
            break

          // ─── Sección anterior ────────────────────────────
          case Qt.Key_Up:
          case Qt.Key_K:
          case Qt.Key_Left:
          case Qt.Key_H:
          case Qt.Key_Backtab:
            keybindsRoot.setCurrentIndex((keybindsRoot.currentIndex - 1 + total) % total)
            event.accepted = true
            break

          default:
            // ─── Saltar directo a una sección con 1–9 ──────
            if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
              const idx = event.key - Qt.Key_1
              if (idx < total) {
                keybindsRoot.setCurrentIndex(idx)
                event.accepted = true
              }
            }
            break
        }
      }

      // ─── Card ────────────────────────────────────────────────
      Rectangle {
        anchors.centerIn: parent

        width: 760
        height: 620

        radius: 22
        color: keybindsRoot.colors.bg
        border.color: keybindsRoot.colors.border
        border.width: 1
        z: 1

        Behavior on color {
          ColorAnimation { duration: 400 }
        }

        Behavior on border.color {
          ColorAnimation { duration: 400 }
        }

        // ─── Bloquear clicks dentro del card ──────────────────
        MouseArea {
          anchors.fill: parent
          onClicked: {}
        }

        ColumnLayout {
          anchors.fill: parent
          spacing: 0

          // ─── Header ─────────────────────────────────────────
          Item {
            Layout.fillWidth: true
            height: 64

            RowLayout {
              anchors {
                fill: parent
                leftMargin: 24
                rightMargin: 24
              }

              spacing: 10

              Text {
                text: "󰌌"
                color: keybindsRoot.colors.accent
                font.pixelSize: 24
                font.family: "JetBrainsMono Nerd Font"

                Behavior on color {
                  ColorAnimation { duration: 400 }
                }
              }

              // ─── Tabs: Keybinds / Vim ───────────────────────
              Row {
                spacing: 6

                Rectangle {
                  id: keybindsTabBtn
                  width: keybindsTabLabel.implicitWidth + 24
                  height: 32
                  radius: 8

                  color: keybindsRoot.activeTab === "keybinds"
                    ? Qt.rgba(1, 1, 1, 0.10)
                    : "transparent"

                  border.width: keybindsRoot.activeTab === "keybinds" ? 1 : 0
                  border.color: keybindsRoot.colors.accent

                  Behavior on color {
                    ColorAnimation { duration: 180 }
                  }

                  Text {
                    id: keybindsTabLabel
                    anchors.centerIn: parent
                    text: Translations.t("tabKeybinds")
                    font.pixelSize: 15
                    font.bold: keybindsRoot.activeTab === "keybinds"

                    color: keybindsRoot.activeTab === "keybinds"
                      ? keybindsRoot.colors.text
                      : keybindsRoot.colors.subtext

                    Behavior on color {
                      ColorAnimation { duration: 180 }
                    }
                  }

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: keybindsRoot.activeTab = "keybinds"
                  }
                }

                Rectangle {
                  id: vimTabBtn
                  width: vimTabLabel.implicitWidth + 24
                  height: 32
                  radius: 8

                  color: keybindsRoot.activeTab === "vim"
                    ? Qt.rgba(1, 1, 1, 0.10)
                    : "transparent"

                  border.width: keybindsRoot.activeTab === "vim" ? 1 : 0
                  border.color: keybindsRoot.colors.accent

                  Behavior on color {
                    ColorAnimation { duration: 180 }
                  }

                  Text {
                    id: vimTabLabel
                    anchors.centerIn: parent
                    text: Translations.t("tabVim")
                    font.pixelSize: 15
                    font.bold: keybindsRoot.activeTab === "vim"

                    color: keybindsRoot.activeTab === "vim"
                      ? keybindsRoot.colors.text
                      : keybindsRoot.colors.subtext

                    Behavior on color {
                      ColorAnimation { duration: 180 }
                    }
                  }

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: keybindsRoot.activeTab = "vim"
                  }
                }
              }

              Item {
                Layout.fillWidth: true
              }

              Text {
                text: Translations.t("tagline")
                color: keybindsRoot.colors.subtext
                font.pixelSize: 12
                font.family: "JetBrainsMono Nerd Font"

                Behavior on color {
                  ColorAnimation { duration: 400 }
                }
              }
            }

            Rectangle {
              anchors {
                bottom: parent.bottom
                left: parent.left
                right: parent.right
              }

              height: 1
              color: Qt.rgba(1, 1, 1, 0.07)
            }
          }

          // ─── Sidebar + lista ────────────────────────────────
          RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // ─── Sidebar categorías ───────────────────────────
            Rectangle {
              width: 190
              Layout.fillHeight: true
              color: Qt.rgba(0, 0, 0, 0.20)

              ListView {
                id: sectionList

                anchors {
                  fill: parent
                  topMargin: 10
                  bottomMargin: 10
                }

                clip: true
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds

                model: keybindsRoot.currentSections.length

                ScrollBar.vertical: ScrollBar {
                  policy: ScrollBar.AsNeeded
                }

                // ─── Mantiene visible la sección activa al navegar
                // con teclado, aunque haya más categorías que las
                // que entran en el recuadro (ej. Vim con 15).
                Connections {
                  target: keybindsRoot
                  function onCurrentIndexChanged() {
                    sectionList.positionViewAtIndex(keybindsRoot.currentIndex, ListView.Contain)
                  }
                }

                delegate: Item {
                  width: sectionList.width
                  height: 44

                  Rectangle {
                    anchors.fill: parent

                    color: index === keybindsRoot.currentIndex
                      ? Qt.rgba(1, 1, 1, 0.08)
                      : "transparent"

                    Behavior on color {
                      ColorAnimation { duration: 180 }
                    }
                  }

                  Rectangle {
                    visible: index === keybindsRoot.currentIndex

                    width: 3
                    height: 24
                    radius: 2

                    color: keybindsRoot.colors.accent

                    anchors {
                      left: parent.left
                      verticalCenter: parent.verticalCenter
                    }

                    Behavior on color {
                      ColorAnimation { duration: 400 }
                    }
                  }

                  RowLayout {
                    anchors {
                      fill: parent
                      leftMargin: 18
                      rightMargin: 10
                    }

                    spacing: 10

                    Text {
                      text: keybindsRoot.currentSections[index].icon

                      color: index === keybindsRoot.currentIndex
                        ? keybindsRoot.colors.accent
                        : keybindsRoot.colors.subtext

                      font.pixelSize: 17
                      font.family: "JetBrainsMono Nerd Font"

                      Behavior on color {
                        ColorAnimation { duration: 200 }
                      }
                    }

                    Text {
                      text: keybindsRoot.currentSections[index].title

                      color: index === keybindsRoot.currentIndex
                        ? keybindsRoot.colors.text
                        : keybindsRoot.colors.subtext

                      font.pixelSize: 15
                      font.bold: index === keybindsRoot.currentIndex

                      Behavior on color {
                        ColorAnimation { duration: 200 }
                      }
                    }
                  }

                  MouseArea {
                    anchors.fill: parent

                    onClicked: {
                      keybindsRoot.setCurrentIndex(index)
                    }

                    cursorShape: Qt.PointingHandCursor
                  }
                }
              }

              Rectangle {
                anchors {
                  top: parent.top
                  bottom: parent.bottom
                  right: parent.right
                }

                width: 1
                color: Qt.rgba(1, 1, 1, 0.07)
              }
            }

            // ─── Lista de binds ───────────────────────────────
            ListView {
              id: bindsList

              Layout.fillWidth: true
              Layout.fillHeight: true

              topMargin: 12
              bottomMargin: 12
              leftMargin: 16
              rightMargin: 16

              model: keybindsRoot.currentSections[
                keybindsRoot.currentIndex
              ].binds

              spacing: 4
              clip: true

              ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
              }

              delegate: Rectangle {
                width: bindsList.width - 32
                height: 44
                radius: 9

                color: hoverArea.containsMouse
                  ? Qt.rgba(1, 1, 1, 0.05)
                  : "transparent"

                Behavior on color {
                  ColorAnimation { duration: 120 }
                }

                MouseArea {
                  id: hoverArea

                  anchors.fill: parent
                  hoverEnabled: true
                }

                RowLayout {
                  anchors {
                    fill: parent
                    leftMargin: 12
                    rightMargin: 12
                  }

                  spacing: 10

                  // ─── Key caps ──────────────────────────────
                  Row {
                    spacing: 5

                    Repeater {
                      model: modelData.keys

                      delegate: Rectangle {
                        height: 28
                        width: capLabel.implicitWidth + 18
                        radius: 6

                        color: keybindsRoot.colors.btn
                        border.color: Qt.rgba(1, 1, 1, 0.13)
                        border.width: 1

                        Behavior on color {
                          ColorAnimation { duration: 400 }
                        }

                        Rectangle {
                          anchors {
                            bottom: parent.bottom
                            left: parent.left
                            right: parent.right
                          }

                          height: 2
                          radius: 5
                          color: Qt.rgba(0, 0, 0, 0.30)
                        }

                        Text {
                          id: capLabel

                          anchors.centerIn: parent

                          text: modelData
                          color: keybindsRoot.colors.accent

                          font.pixelSize: 14
                          font.family: "JetBrainsMono Nerd Font"
                          font.bold: true

                          Behavior on color {
                            ColorAnimation { duration: 400 }
                          }
                        }
                      }
                    }
                  }

                  Item {
                    Layout.fillWidth: true
                  }

                  Text {
                    text: modelData.desc

                    color: keybindsRoot.colors.subtext

                    font.pixelSize: 16

                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideLeft

                    Behavior on color {
                      ColorAnimation { duration: 400 }
                    }
                  }
                }
              }
            }
          }

          // ─── Footer ─────────────────────────────────────────
          Item {
            Layout.fillWidth: true
            height: 40

            Rectangle {
              anchors {
                top: parent.top
                left: parent.left
                right: parent.right
              }

              height: 1
              color: Qt.rgba(1, 1, 1, 0.07)
            }

            RowLayout {
              anchors {
                fill: parent
                leftMargin: 24
                rightMargin: 24
              }

              Text {
                text: "󰌑  " + Translations.t("footerHint")

                color: keybindsRoot.colors.subtext

                font.pixelSize: 12
                font.family: "JetBrainsMono Nerd Font"

                Behavior on color {
                  ColorAnimation { duration: 400 }
                }
              }

              Item {
                Layout.fillWidth: true
              }

              Text {
                text: keybindsRoot.currentSections[
                  keybindsRoot.currentIndex
                ].title
                  + "  "
                  + (keybindsRoot.currentIndex + 1)
                  + "/"
                  + keybindsRoot.currentSections.length

                color: keybindsRoot.colors.subtext

                font.pixelSize: 12
                font.family: "JetBrainsMono Nerd Font"

                Behavior on color {
                  ColorAnimation { duration: 400 }
                }
              }
            }
          }
        }
      }
    }
  }
}
