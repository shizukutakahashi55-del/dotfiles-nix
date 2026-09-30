// CapsOSD — aviso flotante de Caps Lock, con el mismo look que AudioOSD:
// una píldora centrada abajo que aparece ~1.4 s cuando se activa o se
// desactiva el bloqueo de mayúsculas y se esconde sola.
//
// ─── De dónde sale el estado ──────────────────────────────────────────
// Quickshell no expone el estado de Caps Lock, así que un único proceso
// liviano (un bucle de bash) vigila el LED "capslock" del teclado en
// /sys/class/leds/*capslock/brightness y SOLO imprime cuando cambia:
//   • no usa root ni permisos especiales (es de solo lectura)
//   • cualquier teclado con LED de Caps (USB, portátil, la mayoría de los
//     Bluetooth) funciona; con varios teclados, cuenta si CUALQUIERA está activo
//   • si no hay ningún LED de Caps en /sys, cae a `hyprctl devices -j`
//     (campo "capsLock"), un poco menos liviano pero igual de válido
// La primera lectura al arrancar el shell solo fija el estado inicial: no
// muestra el OSD.
//
// Prueba manual (sin tocar el teclado):
//   quickshell ipc -p .../shell.qml call -- caps show true
//   quickshell ipc -p .../shell.qml call -- caps show false
//
// Vive montado siempre (como AudioOSD): visible pero click-through (mask
// vacío) mientras no hay nada que mostrar. Si la barra está abajo, sube lo
// necesario para no quedar debajo de ella.
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../COMMON"
import "../LANG"

Item {
  id: root

  property string targetScreen: ""
  property int cardWidth: 210
  // Cuánto dura visible el aviso
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

  // Vigila el LED de Caps y avisa por stdout cada cambio ("1" / "0")
  Process {
    id: watcher
    running: true
    command: ["bash", "-c", [
      'prev=""',
      'while :; do',
      '  on=0; found=0',
      '  for f in /sys/class/leds/*capslock/brightness; do',
      '    [ -r "$f" ] || continue',
      '    found=1',
      '    read -r v < "$f" && [ "${v:-0}" != "0" ] && on=1',
      '  done',
      '  if [ "$found" = 0 ]; then',
      '    hyprctl devices -j 2>/dev/null | grep -q \'"capsLock": *true\' && on=1',
      '  fi',
      '  if [ "$on" != "$prev" ]; then echo "$on"; prev="$on"; fi',
      '  sleep 0.15',
      'done'
    ].join("\n")]

    stdout: SplitParser {
      onRead: line => {
        const on = line.trim() === "1"
        if (!root.gotInitial) {
          // Primera lectura: estado inicial, sin OSD
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
    visible: true
    color: "transparent"
    exclusiveZone: -1

    anchors { bottom: true; left: true; right: true }
    implicitHeight: 200

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "oozeshell-caps-osd"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // El mask sigue el alto animado del card: 0 = sin zona de clics
    mask: Region { item: card }

    Rectangle {
      id: card
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 34 + (Theme.barAtBottom ? Theme.barOffset : 0)

      readonly property int fullHeight: 58

      width: root.cardWidth
      height: root.osdVisible ? fullHeight : 0
      clip: true
      radius: Theme.panelRadius
      color: Theme.bg

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

        // Ícono: chip primario cuando está activo, apagado cuando no
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
