// WidgetHost — lo ÚNICO que shell.qml necesita instanciar.
// Crea una WidgetWindow por cada widget ACTIVO. Apagar uno lo saca de `enabledIds` y su ventana (con todo lo que cargó) se destruye.

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "../COMMON"
import "../LANG"
import "./pomodoro"

Scope {
  id: host

  // ─── IPC ───

  IpcHandler {
    target: "widgets"

    function list(): string {
      if (WidgetConfig.widgets.length === 0) return "(sin widgets)"
      return WidgetConfig.widgets.map(w =>
        w.id + "  " + w.type + "/" + w.style + "  " + (w.enabled ? "on " : "off")
        + "  @" + w.x + "," + w.y + "  " + w.w + "x" + w.h
        + (w.monitor ? "  [" + w.monitor + "]" : "")).join("\n")
    }
    function types(): string {
      return WidgetRegistry.types.map(t => t.id + ": " + t.styles.join(" | ")).join("\n")
    }
    function add(type: string, style: string): string {
      const id = WidgetConfig.add(type, style)
      return id === "" ? "tipo desconocido: " + type : id
    }
    function remove(id: string): bool { return WidgetConfig.remove(id) }
    function enable(id: string): bool { return WidgetConfig.update(id, { enabled: true }) }
    function disable(id: string): bool { return WidgetConfig.update(id, { enabled: false }) }
    function toggle(id: string): bool {
      const w = WidgetConfig.byId[id]
      return w ? WidgetConfig.update(id, { enabled: !w.enabled }) : false
    }
    function style(id: string, style: string): bool { return WidgetConfig.setStyle(id, style) }
    function move(id: string, x: int, y: int): bool { return WidgetConfig.update(id, { x: x, y: y }) }
    function size(id: string, w: int, h: int): bool { return WidgetConfig.update(id, { w: w, h: h }) }
    function monitor(id: string, name: string): bool { return WidgetConfig.update(id, { monitor: name }) }
    function option(id: string, key: string, value: string): bool {

      let v = value
      if (value === "true") v = true
      else if (value === "false") v = false
      else if (value !== "" && !isNaN(Number(value))) v = Number(value)
      return WidgetConfig.setOption(id, key, v)
    }

    function pomodoro(id: string, action: string): bool {
      const w = WidgetConfig.byId[id]
      if (!w || w.type !== "pomodoro") return false
      if (action === "toggle") PomodoroService.toggle(id)
      else if (action === "skip") PomodoroService.skip(id)
      else if (action === "reset") PomodoroService.reset(id)
      else if (action === "restart") PomodoroService.restart(id)
      else return false
      return true
    }
    function layer(name: string): void { WidgetConfig.setLayer(name) }
    function edit(on: bool): void { WidgetConfig.editMode = on }
    function raise(): void { host.raiseNow() }
  }

  property bool mapped: true


  function raise() { raiseDelay.restart() }
  function raiseNow() { host.mapped = false; remap.restart() }


  Connections { target: WidgetConfig; function onRaiseRequested() { host.raiseNow() } }

  Timer { id: raiseDelay; interval: 1200; onTriggered: host.raiseNow() }
  Timer { id: remap; interval: 80; onTriggered: host.mapped = true }

  Variants {
    model: (host.mapped && WidgetConfig.widgetsEnabled) ? WidgetConfig.enabledIds : []
    WidgetWindow {
      required property string modelData
      widgetId: modelData
    }
  }

  // ── Modo mover: botón flotante «Confirmar» (una barrita por pantalla) ──


  Variants {
    model: WidgetConfig.editMode ? Quickshell.screens : []

    PanelWindow {
      id: bar
      required property var modelData
      screen: modelData
      color: "transparent"
      exclusiveZone: -1
      anchors { bottom: true }
      margins { bottom: 56 }
      implicitWidth: pill.width
      implicitHeight: pill.height
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "oozeshell-widget-editbar"
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

      Rectangle {
        id: pill
        width: row.implicitWidth + 28
        height: 52
        radius: height / 2
        color: Theme.bg
        border.color: Theme.primary
        border.width: 1

        Row {
          id: row
          anchors.centerIn: parent
          spacing: 14

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Translations.t("wgMoveHint")
            color: Theme.subtext
            font.pixelSize: Theme.fs(12)
            font.family: Theme.fontFamily
          }
          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: label.implicitWidth + 32
            height: 34
            radius: 17
            color: confirm.containsMouse ? Qt.lighter(Theme.primary, 1.15) : Theme.primary
            Text {
              id: label
              anchors.centerIn: parent
              text: "✓  " + Translations.t("wgConfirm")
              color: Theme.bg
              font.bold: true
              font.pixelSize: Theme.fs(12)
              font.family: Theme.fontFamily
            }
            MouseArea {
              id: confirm
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: WidgetConfig.editMode = false
            }
          }
        }
      }
    }
  }

}
