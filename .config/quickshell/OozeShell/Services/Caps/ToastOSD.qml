// ToastOSD — OSD genérico (mismo look que CapsOSD/AudioOSD) para avisos que vienen de fuera del shell: cambio de layout de ventanas, hyprsunset…

import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../../COMMON"

Item {
  id: root

  property string targetScreen: ""
  property int cardWidth: 250
  property int showMs: 1400

  property string iconText: ""
  property string titleText: ""
  property string subtitleText: ""
  property bool active: true
  property bool osdVisible: false

  function show(icon, title, subtitle, on) {
    root.iconText = icon
    root.titleText = title
    root.subtitleText = subtitle
    root.active = on
    root.osdVisible = true
    hideTimer.restart()
  }

  Timer {
    id: hideTimer
    interval: root.showMs
    repeat: false
    onTriggered: root.osdVisible = false
  }

  PanelWindow {
    id: win

    screen: Quickshell.screens.find(s => s.name === root.targetScreen) ?? Quickshell.screens[0]
    visible: true
    color: "transparent"
    exclusiveZone: -1

    anchors { bottom: true; left: true; right: true }
    implicitHeight: 200

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "oozeshell-toast-osd"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None


    mask: Region { item: card }

    Rectangle {
      id: card
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 34 + (Theme.barAtBottom ? Theme.barFace : 0)

      readonly property int fullHeight: 58

      width: root.cardWidth
      height: root.osdVisible ? fullHeight : 0
      clip: true
      radius: Theme.panelRadius
      color: Theme.panelBg

      opacity: Math.max(0, Math.min(1, height / fullHeight))
      scale: 0.94 + 0.06 * opacity

      Behavior on height { NumberAnimation { duration: Theme.animDuration(160); easing.type: Easing.OutCubic } }

      RowLayout {
        width: card.width - 32
        height: card.fullHeight - 16
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        spacing: 12

        Rectangle {
          Layout.preferredWidth: 34
          Layout.preferredHeight: 34
          radius: 10
          color: root.active ? Theme.primary : Theme.surface
          Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }

          Text {
            anchors.centerIn: parent
            text: root.iconText
            color: root.active ? Theme.textOnPrimary : Theme.subtext
            font.pixelSize: 20
            font.family: Theme.fontFamily
            Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 0

          Text {
            Layout.fillWidth: true
            text: root.titleText
            elide: Text.ElideRight
            color: Theme.text
            font.pixelSize: 13
            font.bold: true
            font.family: Theme.fontFamily
          }
          Text {
            Layout.fillWidth: true
            text: root.subtitleText
            elide: Text.ElideRight
            color: root.active ? Theme.primary : Theme.subtext
            font.pixelSize: 11
            font.family: Theme.fontFamily
            Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
          }
        }
      }
    }
  }
}
