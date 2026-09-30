// OozeShell — Traducciones centralizadas
//
// Los textos del shell viven en UN ARCHIVO POR IDIOMA, en languages/:
//
//   languages/LangEn.qml    English
//   languages/LangEs.qml    Español
//   languages/LangId.qml    Bahasa Indonesia
//   languages/LangJa.qml    日本語
//
// Este singleton solo elige cuál está activo y sirve sus textos. Cualquier
// componente puede importar esta carpeta y usar:
//
//   import "../LANG"
//   ...
//   text: Translations.t("keybindingsTitle")
//
// Cambiar Translations.current re-evalúa automáticamente cualquier
// binding que haya llamado a t(), sections() o vimSections(), porque QML
// registra esas lecturas de propiedad como dependencias aunque pasen por
// una función.
//
// Se cambia el idioma activo desde LanguagePicker.qml (vía shell.qml, que
// persiste la elección en disco). No hace falta tocar este archivo para
// eso — solo para agregar textos nuevos o un idioma nuevo.
//
// ─── Agregar un idioma ────────────────────────────────────────
//   1. Copia languages/LangEn.qml a languages/LangXx.qml y traducelo.
//   2. Registralo en languages/qmldir:   LangXx 1.0 LangXx.qml
//   3. Sumá una línea `LangXx { id: ... }` abajo y agregalo a `packs`.
//   El selector de idioma lo muestra solo (lee `availableLanguages`).
//
// Un texto que falte en un idioma cae al inglés; si tampoco existe ahí,
// t() devuelve la clave tal cual (nunca revienta).

pragma Singleton
import QtQml
import "languages"

QtObject {
  id: root

  // Código de idioma activo: "en" | "es" | "id" | "ja"
  property string current: "en"

  // ─── Un objeto por idioma (ver languages/) ────────────────────
  readonly property LangEn packEn: LangEn {}
  readonly property LangEs packEs: LangEs {}
  readonly property LangId packId: LangId {}
  readonly property LangJa packJa: LangJa {}

  // El orden de esta lista es el orden del selector de idioma
  readonly property var packs: [packEn, packEs, packId, packJa]

  // [{ code, name }] para el selector. Los nombres NUNCA se traducen:
  // cada idioma se muestra en su propio idioma.
  readonly property var availableLanguages:
    root.packs.map(p => ({ code: p.code, name: p.name }))

  // Paquete del idioma activo (inglés si el código no existe)
  function pack() {
    const code = root.current
    for (let i = 0; i < root.packs.length; i++)
      if (root.packs[i].code === code) return root.packs[i]
    return root.packEn
  }

  // ─── Textos sueltos de la UI (headers, hints, etc.) ───────────
  // Busca "key" en el idioma activo; si falta, cae a inglés;
  // si tampoco existe ahí, devuelve la key tal cual.
  function t(key) {
    const table = root.pack().strings
    if (table[key] !== undefined) return table[key]
    const en = root.packEn.strings
    if (en[key] !== undefined) return en[key]
    return key
  }

  // ─── Panel de Keybinds ────────────────────────────────────────
  // "keys" (SUPER, Mouse LMB…) no se traducen: son nombres de tecla.
  function sections() {
    return root.pack().sections || root.packEn.sections
  }

  // ─── Panel de Vim ─────────────────────────────────────────────
  function vimSections() {
    return root.pack().vimSections || root.packEn.vimSections
  }
}
