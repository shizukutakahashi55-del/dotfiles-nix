// OozeShell — Popup de aviso simple (Al cambiar de Layout)


import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

Item {
  id: notifyRoot

  property string targetScreen: "DP-3"

  // ─── Colores desde matugen (mismo patrón que Mpris.qml) ───────
  property var colors: ({
    bg:      "#0d0e11",
    border:  "#4a90d9",
    text:    "#e1e2e8"
  })

  function withAlpha(hex, alpha) {
    var h = String(hex).replace('#', '')
    var r = parseInt(h.substring(0, 2), 16) / 255
    var g = parseInt(h.substring(2, 4), 16) / 255
    var b = parseInt(h.substring(4, 6), 16) / 255
    return Qt.rgba(r, g, b, alpha)
  }

  Process {
    id: loadColors
    command: ["cat", "/tmp/matugen-colors.json"]
    running: false
    property string buffer: ""
    stdout: SplitParser { onRead: line => loadColors.buffer += line }
    onRunningChanged: {
      if (!running && buffer !== "") {
        try {
          const palette = JSON.parse(buffer)
          const c = palette.colors
          notifyRoot.colors = {
            bg:     c.surface?.dark?.color          ?? c.background?.dark?.color ?? "#0d0e11",
            border: c.primary?.dark?.color          ?? "#4a90d9",
            text:   c.on_surface?.dark?.color       ?? c.on_background?.dark?.color ?? "#e1e2e8"
          }
        } catch (e) {
          console.log("notify color parse error:", e)
        }
        buffer = ""
      }
    }
  }

  // Refresca cada vez que se muestra el popup, así siempre toma
  // la última paleta aunque matugen haya corrido hace rato.
  function reloadColors() {
    loadColors.running = false
    loadColors.running = true
  }

  // ─── Estado del popup ──────────────────────────────────────────
  property string message: ""
  property bool visible_: false

  // Cuánto dura en pantalla antes de autocerrarse (ms).
  property int defaultDuration: 2200

  Timer {
    id: hideTimer
    repeat: false
    onTriggered: notifyRoot.visible_ = false
  }

  // Se llama desde afuera (IPC) para mostrar un mensaje.
  // duration es opcional; si no se pasa (o es 0/undefined) usa defaultDuration.
  function show(text, duration) {
    notifyRoot.reloadColors()
    notifyRoot.message = text
    notifyRoot.visible_ = true
    hideTimer.stop()
    hideTimer.interval = (duration && duration > 0) ? duration : notifyRoot.defaultDuration
    hideTimer.start()
  }

  IpcHandler {
    target: "notify"
    function show(text: string): void { notifyRoot.show(text, 0) }
  }

  // ─── Ventana del popup ─────────────────────────────────────────
  PanelWindow {
    id: notifyPanel
    screen: Quickshell.screens.find(s => s.name === notifyRoot.targetScreen) ?? Quickshell.screens[0]
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "notify-popup"
    exclusiveZone: -1
    focusable: false
    color: "transparent"
    visible: notifyRoot.visible_

    anchors { top: true }
    margins { top: 24 }
    implicitWidth: Math.min(560, msgText.implicitWidth + 56)
    implicitHeight: msgText.implicitHeight + 30

    Rectangle {
      id: card
      anchors.fill: parent
      radius: 22
      color: notifyRoot.withAlpha(notifyRoot.colors.bg, 0.94)
      border.color: notifyRoot.withAlpha(notifyRoot.colors.border, 0.55)
      border.width: 1

      opacity: notifyRoot.visible_ ? 1.0 : 0.0
      Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
      Behavior on color        { ColorAnimation { duration: 300 } }
      Behavior on border.color { ColorAnimation { duration: 300 } }

      Text {
        id: msgText
        anchors.centerIn: parent
        text: notifyRoot.message
        color: notifyRoot.colors.text
        font.pixelSize: 13
        font.family: "JetBrainsMono Nerd Font"
        Behavior on color { ColorAnimation { duration: 300 } }
      }
    }
  }
}
