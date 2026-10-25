// CapsOSD — aviso flotante de Caps Lock, con el mismo look que AudioOSD:

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../../COMMON"
import "../Lang"

Item {
  id: root

  property string targetScreen: ""
  property int cardWidth: 210

  property int showMs: 1400

  property bool capsOn: false
  property bool osdVisible: false
  property bool gotInitial: false

  function show(on) {
    root.capsOn = on
    root.osdVisible = true
    hideTimer.restart()
  }

  Timer {
    id: hideTimer
    interval: root.showMs
    repeat: false
    onTriggered: root.osdVisible = false
  }


  Process {
    id: watcher
    running: true
    command: ["bash", "-c", [
      '# oozeshell-caps-watch',
      'exec 3<> <(:)',
      'tick() { read -rt "$1" -u 3 _ || :; }',
      'prev=""; warned=0',
      'while :; do',
      '  on=0; found=0',
      '  for f in /sys/class/leds/*capslock/brightness; do',
      '    [ -r "$f" ] || continue',
      '    found=1',
      '    read -r v < "$f" && [ "${v:-0}" != "0" ] && on=1',
      '  done',
      '  if [ "$found" = 0 ]; then',
      '    if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then',
      '      found=1',
      '      hyprctl devices -j 2>/dev/null | grep -q \'"capsLock": *true\' && on=1',
      '    elif [ "$warned" = 0 ]; then',
      '      warned=1',
      '      echo "oozeshell-caps: sin LED de Caps en /sys ni hyprctl; OSD solo manual (ipc caps show)" >&2',
      '    fi',
      '  fi',
      '  if [ "$found" = 0 ]; then tick 2; continue; fi',
      '  if [ "$on" != "$prev" ]; then echo "$on"; prev="$on"; fi',
      '  tick 0.15',
      'done'
    ].join("\n")]

    stdout: SplitParser {
      onRead: line => {
        const on = line.trim() === "1"
        if (!root.gotInitial) {

          root.gotInitial = true
          root.capsOn = on
          return
        }
        root.show(on)
      }
    }
  }

  PanelWindow {
    id: win

    screen: Quickshell.screens.find(s => s.name === root.targetScreen) ?? Quickshell.screens[0]
    // Solo mapeada mientras el OSD se muestra o se anima su cierre (ahorra superficie + VRAM en reposo).
    visible: root.osdVisible || card.height > 0
    color: "transparent"
    exclusiveZone: -1

    anchors { bottom: true; left: true; right: true }
    implicitHeight: 200

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "oozeshell-caps-osd"
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
          color: root.capsOn ? Theme.primary : Theme.surface
          Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }

          Text {
            anchors.centerIn: parent
            text: "⇪"
            color: root.capsOn ? Theme.textOnPrimary : Theme.subtext
            font.pixelSize: 20
            font.bold: true
            font.family: Theme.fontFamily
            Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 0

          Text {
            text: "Caps Lock"
            color: Theme.text
            font.pixelSize: 13
            font.bold: true
            font.family: Theme.fontFamily
          }
          Text {
            text: root.capsOn ? Translations.t("capsOn") : Translations.t("capsOff")
            color: root.capsOn ? Theme.primary : Theme.subtext
            font.pixelSize: 11
            font.family: Theme.fontFamily
            Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
          }
        }
      }
    }
  }
}
