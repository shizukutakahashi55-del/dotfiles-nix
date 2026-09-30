// AudioOSD — el "swayosd" de OozeShell: una píldora flotante, centrada
// abajo, que aparece 1.6s cuando cambia el volumen o el mic (rueda del
// pill de audio, o el IpcHandler "audio" pensado para los binds de
// Hyprland) y se esconde sola. 
import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../COMMON"
import "../AUDIO"

Item {
  id: root

  property string targetScreen: ""
  property int barWidth: 240

  PanelWindow {
    id: win

    screen: Quickshell.screens.find(s => s.name === root.targetScreen) ?? Quickshell.screens[0]
    visible: true
    color: "transparent"
    exclusiveZone: -1

    anchors { bottom: true; left: true; right: true }
    implicitHeight: 200

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "oozeshell-audio-osd"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Igual que FusedPanel: el mask sigue el alto animado del propio
    // card (0 → sin zona de clics, cerrado de verdad, no solo invisible)
    mask: Region { item: card }

    Rectangle {
      id: card
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 34 + (Theme.barAtBottom ? Theme.barOffset : 0)

      readonly property int fullHeight: 58

      width: root.barWidth
      height: AudioBackend.osdVisible ? fullHeight : 0
      clip: true
      radius: Theme.panelRadius
      color: Theme.bg

      opacity: Math.max(0, Math.min(1, height / fullHeight))
      scale: 0.94 + 0.06 * opacity

      Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

      RowLayout {
        width: card.width - 32
        height: card.fullHeight - 16
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        spacing: 12

        Text {
          text: {
            if (AudioBackend.osdKind === "mic")
              return AudioBackend.osdMuted ? "󰍭" : "󰍬"
            if (AudioBackend.osdMuted || AudioBackend.osdValue <= 0) return "󰝟"
            if (AudioBackend.osdValue < 0.34) return "󰕿"
            if (AudioBackend.osdValue < 0.67) return "󰖀"
            return "󰕾"
          }
          color: AudioBackend.osdMuted ? Theme.subtext : Theme.primary
          font.pixelSize: 20
          font.family: Theme.fontFamily
        }

        Item {
          Layout.fillWidth: true
          Layout.preferredHeight: 8

          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 8
            radius: 4
            color: Theme.surfaceHigh

            Rectangle {
              width: parent.width * (AudioBackend.osdMuted ? 0 : AudioBackend.osdValue)
              height: parent.height
              radius: parent.radius
              color: Theme.primary
              Behavior on width { NumberAnimation { duration: 120 } }
            }
          }
        }

        Text {
          Layout.preferredWidth: 40
          horizontalAlignment: Text.AlignRight
          text: AudioBackend.osdMuted ? "—" : Math.round(AudioBackend.osdValue * 100) + "%"
          color: Theme.text
          font.pixelSize: 12
          font.bold: true
          font.family: Theme.fontFamily
        }
      }
    }
  }
}
