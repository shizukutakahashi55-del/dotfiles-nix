// KeyboardLayout — UNA sola fuente de verdad para el idioma del teclado.
//

pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
  id: root

  // ─── Configuración ─────────────────────────────────────────────
  // Teclado que se toma como referencia para la etiqueta. Si no está
  // conectado, cae al teclado "main" y, si tampoco, al primero de la lista.
  property string keyboardName: "by-tech-usb-gaming-keyboard"
  // true  → `next()` cambia TODOS los teclados a la vez (recomendado: la
  //         etiqueta siempre coincide con lo que escribís, uses el que uses).
  // false → solo cambia el teclado de referencia.
  property bool switchAll: true

  // ─── Estado ────────────────────────────────────────────────────
  // Teclado del que realmente se lee el estado (resuelto por refresh())
  property string trackedName: ""
  // Nombre largo del layout activo, tal cual lo da Hyprland
  property string layoutName: ""
  readonly property string label: layoutName === "" ? "…" : root.labelFor(layoutName)

  // ─── Aviso al cambiar de idioma ────────────────────────────────
  // Se emite con CUALQUIER cambio real de layoutName: botón de la barra,
  // next() (IPC/bind), o el toggle nativo de Hyprland
  // (kb_options = grp:alt_shift_toggle) vía "activelayout".
  // La asignación inicial (arranque / primer refresh()) no cuenta como
  // cambio. Lo escucha CAPS/LayoutOSD.qml, que dibuja el OSD.
  signal layoutSwitched(string name, string label)
  property string previousLayoutName: ""
  onLayoutNameChanged: {
    if (root.previousLayoutName !== "" && root.layoutName !== "" &&
        root.layoutName !== root.previousLayoutName) {
      root.layoutSwitched(root.layoutName, root.label)
    }
    root.previousLayoutName = root.layoutName
  }

  function labelFor(name) {
    const n = name.toLowerCase()
    if (n.indexOf("spanish") === 0) return "ESP"
    if (n.indexOf("english") === 0) return "ENG"
    return name.slice(0, 3).toUpperCase()
  }

  // ─── Acciones ──────────────────────────────────────────────────
  function next() {
    Quickshell.execDetached([
      "hyprctl", "switchxkblayout",
      root.switchAll ? "all" : (root.trackedName !== "" ? root.trackedName : root.keyboardName),
      "next"
    ])
    // Red de seguridad: normalmente el evento "activelayout" ya actualizó
    // todo, pero si por algún motivo no llega, esto lo corrige igual.
    settleTimer.restart()
  }

  function refresh() {
    if (!devicesProc.running) devicesProc.running = true
  }

  Timer {
    id: settleTimer
    interval: 250
    repeat: false
    onTriggered: root.refresh()
  }

  // ─── Lectura inicial / resincronización ────────────────────────
  Process {
    id: devicesProc

    command: ["hyprctl", "devices", "-j"]
    running: true
    property string buffer: ""

    stdout: SplitParser { onRead: line => devicesProc.buffer += line }

    onRunningChanged: {
      if (running) return
      const raw = buffer
      buffer = ""
      if (raw === "") return
      try {
        const kbs = JSON.parse(raw).keyboards || []
        const kb = kbs.find(k => k.name === root.keyboardName)
                || kbs.find(k => k.main)
                || kbs[0]
        if (kb) {
          root.trackedName = kb.name
          root.layoutName = kb.active_keymap
        }
      } catch (e) {
        console.log("KeyboardLayout: error leyendo hyprctl devices:", e)
      }
    }
  }

  // Hyprland avisa cada cambio: "activelayout>>teclado,Nombre del layout"
  Connections {
    target: Hyprland

    function onRawEvent(event) {
      if (event.name === "configreloaded") {
        // Puede haber cambiado la lista de layouts o el teclado principal
        root.refresh()
        return
      }
      if (event.name !== "activelayout") return

      const prefix = root.trackedName + ","
      if (root.trackedName !== "" && event.data.indexOf(prefix) === 0) {
        root.layoutName = event.data.slice(prefix.length)
      } else if (root.trackedName === "") {
        // Todavía no sabemos cuál es el teclado de referencia
        root.refresh()
      }
      // Evento de otro teclado: se ignora a propósito. Con switchAll,
      // el teclado de referencia también manda su propio evento.
    }
  }
}
