// WidgetHost — lo ÚNICO que shell.qml necesita instanciar.

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "../../COMMON"
import "../../Services/Lang"
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
    function freemove(on: bool): void { WidgetConfig.setFreeMove(on) }
    function arrange(): void { WidgetConfig.arrange() }
    function border(mode: string): bool {
      if (mode === "all") WidgetConfig.setGlobalBorder(1)
      else if (mode === "none") WidgetConfig.setGlobalBorder(0)
      else if (mode === "individual") WidgetConfig.setGlobalBorder(-1)
      else return false
      return true
    }
    function raise(): void { host.raiseNow() }
    function quick(action: string): bool {
      if (action === "open") WidgetConfig.openQuick("", "")
      else if (action === "close") WidgetConfig.closeQuick()
      else if (action === "toggle") { if (WidgetConfig.quickOpen) WidgetConfig.closeQuick(); else WidgetConfig.openQuick("", "") }
      else if (action === "left" || action === "right") WidgetConfig.setQuickSide(action)
      else if (action === "side") WidgetConfig.toggleQuickSide()
      else return false
      return true
    }
  }

  property bool mapped: true


  function raise() { raiseDelay.restart() }
  function raiseNow() { host.mapped = false; remap.restart() }


  Connections { target: WidgetConfig; function onRaiseRequested() { host.raiseNow() } }
  Connections {
    target: WidgetConfig
    function onWidgetsChanged() {
      if (!WidgetConfig.menuOpen || WidgetConfig.menuId === "") return
      if (!WidgetConfig.byId[WidgetConfig.menuId] || WidgetConfig.enabledIds.indexOf(WidgetConfig.menuId) < 0)
        WidgetConfig.closeMenu()
    }
  }

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


  function menuScreens() {
    const m = Quickshell.screens.filter(s => s.name === WidgetConfig.menuMonitor)
    return m.length > 0 ? m : (Quickshell.screens.length > 0 ? [Quickshell.screens[0]] : [])
  }

  // ── Menú contextual (clic derecho sobre un widget) ──
  Variants {
    model: WidgetConfig.menuOpen ? host.menuScreens() : []

    PanelWindow {
      id: menuWin
      required property var modelData
      screen: modelData
      color: "transparent"
      exclusiveZone: -1
      anchors { top: true; left: true; right: true; bottom: true }
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "oozeshell-widget-menu"
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: WidgetConfig.closeMenu()
      }

      FocusScope {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: WidgetConfig.closeMenu()
        Component.onCompleted: forceActiveFocus()

        SkinRect {
          id: menuCard
          x: Math.max(8, Math.min(WidgetConfig.menuX, menuWin.width - menuCard.width - 8))
          y: Math.max(8, Math.min(WidgetConfig.menuY, menuWin.height - menuCard.height - 8))
          width: menuRow.implicitWidth + 28
          height: 42
          color: Theme.bg
          radius: Theme.cardRadius
          border.width: Theme.bw1
          border.color: Theme.edge
          raised: true

          Rectangle {
            anchors { fill: parent; margins: 4 }
            radius: Math.max(2, Theme.cardRadius - 3)
            color: itemArea.containsMouse ? Theme.surfaceHigh : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }

            Row {
              id: menuRow
              anchors.centerIn: parent
              spacing: 10
              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "󰒓"
                color: Theme.primary
                font.pixelSize: Theme.fs(15)
                font.family: Theme.monoFamily
              }
              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Translations.t("wgQuickTitle")
                color: Theme.text
                font.bold: true
                font.pixelSize: Theme.fs(12)
                font.family: Theme.fontFamily
              }
            }
            MouseArea {
              id: itemArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: WidgetConfig.openQuick(WidgetConfig.menuId, WidgetConfig.menuMonitor)
            }
          }
        }
      }
    }
  }

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
