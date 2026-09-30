// MonitorSelect — selector de monitor, como submenú de Ajustes (pestaña General).
//
// Atajo de teclado (IPC), sigue igual que antes:
//   quickshell ipc -p .../shell.qml call -- monitor togglePicker
import Quickshell
import QtQuick
import QtQuick.Layouts
import "../COMMON"
import "../LANG"

Item {
  id: root

  property bool open: false
  property string current: "DP-3"
  // Solo para mostrar, en la fila "Auto", qué pantalla se está usando
  // ahora mismo (la que Hyprland ve bajo el mouse). No decide nada acá.
  property string resolvedCurrent: ""

  property int cardWidth: 420
  property int edgeMargin: 10
  readonly property int pad: 18

  signal closeRequested()
  signal backRequested()
  signal monitorChosen(string name)

  // Pantalla donde se abre el selector (la pasa shell.qml: focusedMonitor).
  // Antes había una ventana a pantalla completa POR CADA monitor, todas
  // activas a la vez (cada una con su panel, su máscara y su foco de teclado):
  // ahora es una sola, igual que Idioma / Apariencia / Red. La lista de
  // adentro sigue mostrando todas las pantallas.
  property string targetScreen: ""

  FusedWindow {
    id: fw

    active: root.open || panel.shown
    targetScreen: root.targetScreen
    namespace: "oozeshell-monitor"
    onCloseRequested: root.closeRequested()

    FusedPanel {
      id: panel

      open: root.open
      panelWidth: root.cardWidth
      contentHeight: col.implicitHeight + root.pad * 2

      // Cuelga de la barra, del lado de su botón (derecha si es horizontal,
      // abajo si es vertical). FusedPanel se coloca solo según Theme.barPosition.
      align: "end"
      alignMargin: root.edgeMargin + Theme.barEdge + Theme.frameSideArm

      ColumnLayout {
        id: col
        x: root.pad
        y: root.pad
        width: parent.width - root.pad * 2
        spacing: 12

        PanelHeader {
          Layout.fillWidth: true
          icon: "󰍹"
          title: Translations.t("monitorPickerTitle")
          onBackRequested: root.backRequested()
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 4

          // ─── Auto ──────────────────────────────────────────
          // No fija ninguna pantalla: cada cosa que se abra usa la
          // que tenga el mouse encima en ese momento (lo decide
          // Hyprland, no acá). El subtítulo muestra cuál sería
          // ahora mismo, para que quede claro que está vivo.
          Rectangle {
            id: autoRow
            readonly property bool active: root.current === "auto"

            Layout.fillWidth: true
            Layout.preferredHeight: 48
            radius: 10
            color: active
              ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16)
              : (autoArea.containsMouse ? Theme.surface : "transparent")
            Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }

            RowLayout {
              anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
              spacing: 12

              Text {
                text: "󰍹"
                color: autoRow.active ? Theme.primary : Theme.subtext
                font.pixelSize: Theme.fs(18)
                font.family: Theme.monoFamily
              }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                  Layout.fillWidth: true
                  text: Translations.t("monitorAutoOption")
                  color: autoRow.active ? Theme.primary : Theme.text
                  font.bold: autoRow.active
                  font.pixelSize: Theme.fs(13)
                  font.family: Theme.fontFamily
                  elide: Text.ElideRight
                }
                Text {
                  Layout.fillWidth: true
                  text: root.resolvedCurrent !== ""
                    ? Translations.t("monitorAutoHint") + " " + root.resolvedCurrent
                    : Translations.t("monitorAutoSubtitle")
                  color: Theme.subtext
                  font.pixelSize: Theme.fs(10)
                  font.family: Theme.fontFamily
                  elide: Text.ElideRight
                }
              }

              Text {
                visible: autoRow.active
                text: "󰄬"
                color: Theme.primary
                font.pixelSize: Theme.fs(15)
                font.family: Theme.monoFamily
              }
            }

            MouseArea {
              id: autoArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.monitorChosen("auto")
                root.closeRequested()
              }
            }
          }

          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            Layout.topMargin: 2
            Layout.bottomMargin: 2
            color: Theme.subtext
            opacity: 0.15
          }

          Repeater {
            model: Quickshell.screens

            delegate: Rectangle {
              id: row
              readonly property bool active: modelData.name === root.current

              Layout.fillWidth: true
              Layout.preferredHeight: 48
              radius: 10
              color: active
                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16)
                : (rowArea.containsMouse ? Theme.surface : "transparent")
              Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }

              RowLayout {
                anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                spacing: 12

                Text {
                  text: "󰍹"
                  color: row.active ? Theme.primary : Theme.subtext
                  font.pixelSize: Theme.fs(18)
                  font.family: Theme.monoFamily
                }

                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: 1

                  Text {
                    Layout.fillWidth: true
                    text: modelData.name
                    color: row.active ? Theme.primary : Theme.text
                    font.bold: row.active
                    font.pixelSize: Theme.fs(13)
                    font.family: Theme.fontFamily
                    elide: Text.ElideRight
                  }
                  Text {
                    Layout.fillWidth: true
                    text: modelData.width + "×" + modelData.height
                    color: Theme.subtext
                    font.pixelSize: Theme.fs(10)
                    font.family: Theme.fontFamily
                  }
                }

                Text {
                  visible: row.active
                  text: "󰄬"
                  color: Theme.primary
                  font.pixelSize: Theme.fs(15)
                  font.family: Theme.monoFamily
                }
              }

              MouseArea {
                id: rowArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.monitorChosen(modelData.name)
                  root.closeRequested()
                }
              }
            }
          }
        }
      }
    }
  }
}
