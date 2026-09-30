// LanguagePicker — selector de idioma, como submenú de Ajustes (pestaña General).
// Atajo de teclado (IPC):
//   quickshell ipc -p .../shell.qml call -- lang togglePicker
import Quickshell
import QtQuick
import QtQuick.Layouts
import "../COMMON"
import "../LANG"

Item {
  id: root

  property bool open: false
  property string current: "en"
  property string targetScreen: ""

  property int cardWidth: 420
  property int edgeMargin: 10
  readonly property int pad: 18

  signal closeRequested()
  signal backRequested()
  signal languageChosen(string code)

  FusedWindow {
    id: fw
    active: root.open || panel.shown
    targetScreen: root.targetScreen
    namespace: "oozeshell-lang"
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
          icon: "󰗊"
          title: Translations.t("chooseLanguage")
          onBackRequested: root.backRequested()
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 4

          Repeater {
            // Nombres de idioma NUNCA se traducen: siempre se muestran en
            // su propio idioma, para que se reconozcan aunque no entiendas
            // el activo.
            model: Translations.availableLanguages

            delegate: Rectangle {
              id: row
              readonly property bool active: modelData.code === root.current

              Layout.fillWidth: true
              Layout.preferredHeight: 44
              radius: 10
              color: active
                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16)
                : (rowArea.containsMouse ? Theme.surface : "transparent")
              Behavior on color { ColorAnimation { duration: 120 } }

              RowLayout {
                anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                spacing: 10

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
                  text: modelData.code.toUpperCase()
                  color: Theme.subtext
                  font.pixelSize: Theme.fs(10)
                  font.family: Theme.fontFamily
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
                  root.languageChosen(modelData.code)
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
