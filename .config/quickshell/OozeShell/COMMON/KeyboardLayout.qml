// KeyboardLayout — UNA sola fuente de verdad para el idioma del teclado.

pragma Singleton
import QtQuick
import Quickshell

Singleton {
  id: root

  // ─── Configuración ─────────────────────────────────────────────


  property string keyboardName: "by-tech-usb-gaming-keyboard"


  property bool switchAll: true

  // ─── Estado ────────────────────────────────────────────────────

  readonly property string layoutName: WM.keyboardLayoutName
  readonly property string label: layoutName === "" ? "…" : root.labelFor(layoutName)

  // ─── Aviso al cambiar de idioma ────────────────────────────────


  signal layoutSwitched(string name, string label)
  property string previousLayoutName: ""
  onLayoutNameChanged: {
    if (root.previousLayoutName !== "" && root.layoutName !== "" &&
        root.layoutName !== root.previousLayoutName) {


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
