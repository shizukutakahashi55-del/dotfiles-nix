// text: Translations.t("keybindingsTitle")

pragma Singleton
import QtQml
import "languages"

QtObject {
  id: root


  property string current: "en"

  // ─── Un objeto por idioma (ver languages/) ────────────────────
  readonly property LangEn packEn: LangEn {}
  readonly property LangEs packEs: LangEs {}


  readonly property var packs: [packEn, packEs]


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

  // ─── Fechas y horas según el idioma elegido ───────────────────
  readonly property string localeCode: ({
    en: "en_US",
    es: "es_ES"
  })[root.current] || "en_US"

  // ─── Panel de Vim ─────────────────────────────────────────────
  function vimSections() {
    return root.pack().vimSections || root.packEn.vimSections
  }
}
