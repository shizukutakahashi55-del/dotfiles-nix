import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../../COMMON"
import "../../Settings"
import "../Lang"

Item {
  id: root

  property bool open: false
  signal closeRequested()

  readonly property real sc: Theme.windowScale
  readonly property int pad: Math.round(18 * root.sc)

  PanelWindow {
    id: win

    screen: Quickshell.screens.find(s => s.name === EqualizerService.screenName) ?? Quickshell.screens[0]
    visible: root.open || card.opacity > 0.02
    color: "transparent"
    exclusiveZone: -1
    implicitWidth: card.width + 40
    implicitHeight: card.height + 40

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "oozeshell-equalizer"
    WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    Item {
      anchors.fill: parent
      focus: true
      Keys.onEscapePressed: root.closeRequested()
    }

    SkinRect {
      id: card
      anchors.centerIn: parent
      width: Math.round(680 * root.sc)
      height: body.implicitHeight + root.pad * 2
      radius: Theme.panelRadius
      color: Theme.surface
      border.width: Theme.bw1 + 0.5
      border.color: Theme.primary
      inkColor: Theme.primary

      opacity: root.open ? 1 : 0
      scale: root.open ? 1 : 0.96
      Behavior on opacity { NumberAnimation { duration: Theme.animDuration(root.open ? 180 : 130); easing.type: Easing.OutCubic } }
      Behavior on scale { NumberAnimation { duration: Theme.animDuration(200); easing.type: Easing.OutCubic } }

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
      }

      EqualizerPanel {
        id: body
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: root.pad }
        k: root.sc
        closable: true
        onCloseRequested: root.closeRequested()
      }
    }
  }
}
