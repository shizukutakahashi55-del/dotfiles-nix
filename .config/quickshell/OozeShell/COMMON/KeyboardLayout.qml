// KeyboardLayout — UNA sola fuente de verdad para el idioma del teclado.
//

pragma Singleton
import QtQuick
import Quickshell

Singleton {
  id: root

  // ─── Configuración ─────────────────────────────────────────────
  // Teclado que se toma como referencia para la etiqueta. Si no está
  // conectado, cae al teclado "main" y, si tampoco, al primero de la lista.
  property string keyboardName: "by-tech-usb-gaming-keyboard"
  // (solo Hyprland: Mango y Niri manejan el grupo de teclado ellos mismos)
  // true  → `next()` cambia TODOS los teclados a la vez (recomendado: la
  //         etiqueta siempre coincide con lo que escribís, uses el que uses).
  // false → solo cambia el teclado de referencia.
  property bool switchAll: true

  // ─── Estado ────────────────────────────────────────────────────
  // Nombre largo del layout activo, tal cual lo da el compositor (WM.qml)
  readonly property string layoutName: WM.keyboardLayoutName
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
      // OJO: no usar root.label acá. Es un binding de layoutName y, dentro
      // de este handler, puede no haberse re-evaluado todavía → salía la
      // etiqueta del idioma ANTERIOR junto al nombre del nuevo (cruzados).
      root.layoutSwitched(root.layoutName, root.labelFor(root.layoutName))
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
  function next() { WM.nextKeyboardLayout(root.switchAll, root.keyboardName) }
  function refresh() { WM.refreshKeyboard() }

  Component.onCompleted: WM.setPreferredKeyboard(root.keyboardName)
  onKeyboardNameChanged: WM.setPreferredKeyboard(root.keyboardName)
}
