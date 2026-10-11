// text: Translations.t("keybindingsTitle")
// Cambiar Translations.current re-evalúa automáticamente cualquier binding que haya llamado a t(), sections() o vimSections(), porque QML registra esas lecturas de propiedad como dependencias aunque pasen por

pragma Singleton
import QtQml
import "languages"

QtObject {
  id: root


  property string current: "en"

  // ─── Un objeto por idioma (ver languages/) ────────────────────
  readonly property LangEn packEn: LangEn {}
  readonly property LangEs packEs: LangEs {}
  readonly property LangId packId: LangId {}
  readonly property LangJa packJa: LangJa {}


  readonly property var packs: [packEn, packEs, packId, packJa]


  readonly property var availableLanguages:
    root.packs.map(p => ({ code: p.code, name: p.name }))


  function pack() {
    const code = root.current
    for (let i = 0; i < root.packs.length; i++)
      if (root.packs[i].code === code) return root.packs[i]
    return root.packEn
  }

  // ─── Textos sueltos de la UI (headers, hints, etc.) ───────────


  function t(key) {
    const table = root.pack().strings
    if (table[key] !== undefined) return table[key]
    const en = root.packEn.strings
    if (en[key] !== undefined) return en[key]
    return key
  }


  function tw(key, wm) {
    if (wm) {
      const k = key + "_" + wm
      const table = root.pack().strings
      if (table[k] !== undefined) return table[k]
      const en = root.packEn.strings
      if (en[k] !== undefined) return en[k]
    }
    return root.t(key)
  }

  // ─── Panel de Keybinds ────────────────────────────────────────

  function sections() {
    return root.pack().sections || root.packEn.sections
  }

  // ─── Panel de Vim ─────────────────────────────────────────────
  function vimSections() {
    return root.pack().vimSections || root.packEn.vimSections
  }
}
