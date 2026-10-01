// KeyboardLayout — UNA sola fuente de verdad para el idioma del teclado.
// Version Mango: el idioma llega por `mmsg watch keyboardlayout` (MangoIpc)
// y se cambia con el dispatcher `switch_keyboard_layout`.
// Los layouts se definen en mango/input.conf (xkb_rules_layout).

pragma Singleton
import QtQuick
import Quickshell

Singleton {
  id: root

  // Nombre largo del layout activo, tal cual lo da xkb ("English (US)", "Spanish"...)
  readonly property string layoutName: MangoIpc.keyboardLayoutName
  readonly property string label: layoutName === "" ? "…" : root.labelFor(layoutName)

  // ─── Aviso al cambiar de idioma ────────────────────────────────
  // Se emite con CUALQUIER cambio real de layoutName (boton de la barra,
  // next() o el toggle nativo de xkb). La asignacion inicial no cuenta.
  // Lo escucha CAPS/LayoutOSD.qml, que dibuja el OSD.
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
  function next() { MangoIpc.nextKeyboardLayout() }

  // mmsg ya empuja cada cambio; se deja por compatibilidad con Menu.qml
  function refresh() {}
}
