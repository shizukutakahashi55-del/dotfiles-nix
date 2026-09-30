// TerminalSettings — qué terminal usan nix shell / nix profile install y
// las apps de terminal del Launcher, como submenú de Ajustes (pestaña
// General → Terminal).
//
// Antes vivía embebido en la pestaña General de SettingsPanel; se separó
// a su propia ventana (mismo patrón que Bluetooth/Red desde el Menu).
import Quickshell
import QtQuick
import QtQuick.Layouts
import "../COMMON"
import "../LANG"

Item {
  id: root

  property bool open: false
  property string targetScreen: ""

  property int cardWidth: 400
  property int edgeMargin: 10
  readonly property int pad: 18

  signal closeRequested()
  signal backRequested()

  component Btn: SkinRect {
    id: btn
    property string text: ""
    property string icon: ""
    property bool primary: false
    signal clicked()

    implicitHeight: 34
    implicitWidth: btnRow.implicitWidth + 26
    Layout.preferredHeight: 34
    Layout.preferredWidth: btnRow.implicitWidth + 26
    radius: 10
    color: btn.primary
      ? (btnArea.containsMouse ? Qt.lighter(Theme.primary, 1.12) : Theme.primary)
      : (btnArea.containsMouse ? Theme.surfaceHigh : Theme.surface)
    Behavior on color { ColorAnimation { duration: 150 } }

    scale: btnArea.pressed ? 0.94 : 1.0
    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }

    RowLayout {
      id: btnRow
      anchors.centerIn: parent
      spacing: 7
      Text {
        visible: btn.icon !== ""
        text: btn.icon
        color: btn.primary ? Theme.textOnPrimary : Theme.primary
        font.pixelSize: Theme.fs(15)
        font.family: Theme.monoFamily
      }
      Text {
        text: btn.text
        color: btn.primary ? Theme.textOnPrimary : Theme.text
        font.pixelSize: Theme.fs(12)
        font.bold: true
        font.family: Theme.fontFamily
      }
    }

    MouseArea {
      id: btnArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: btn.clicked()
    }
  }

  // Terminales que se ofrecen: las instaladas (más la elegida, aunque no
  // aparezca). Si todavía no terminó la detección, o no hay ninguna de la
  // lista, se muestran todas. (Movido tal cual desde SettingsPanel.)
  readonly property var terminalChoices: {
    const all = Theme.terminals
    const inst = Theme.installedTerminals
    const list = inst.length === 0
      ? all.slice()
      : all.filter(t => inst.indexOf(t.id) >= 0 || t.id === Theme.terminalId)
    if (!all.some(t => t.id === Theme.terminalId))
      list.unshift({ id: Theme.terminalId, name: Theme.terminalId })
    return list
  }

  FusedWindow {
    id: fw
    active: root.open || panel.shown
    targetScreen: root.targetScreen
    namespace: "oozeshell-terminal-settings"
    onCloseRequested: root.closeRequested()

    FusedPanel {
      id: panel

      open: root.open
      panelWidth: root.cardWidth
      contentHeight: col.implicitHeight + root.pad * 2

      align: "end"
      alignMargin: root.edgeMargin + Theme.barEdge + Theme.frameSideArm

      ColumnLayout {
        id: col
        x: root.pad
        y: root.pad
        width: parent.width - root.pad * 2
        spacing: 14

        PanelHeader {
          Layout.fillWidth: true
          icon: "󰆍"
          title: Translations.t("settingsTerminalSection")
          onBackRequested: root.backRequested()
        }

        Flow {
          Layout.fillWidth: true
          spacing: 8

          Repeater {
            model: root.terminalChoices

            delegate: Btn {
              required property var modelData
              icon: "󰆍"
              text: modelData.name
              primary: Theme.terminalId === modelData.id
              onClicked: Theme.setTerminal(modelData.id)
            }
          }
        }

        Text {
          Layout.fillWidth: true
          text: Translations.t("settingsTerminalHint")
          wrapMode: Text.WordWrap
          color: Theme.subtext
          font.pixelSize: Theme.fs(10)
          font.family: Theme.fontFamily
        }
      }
    }
  }
}
