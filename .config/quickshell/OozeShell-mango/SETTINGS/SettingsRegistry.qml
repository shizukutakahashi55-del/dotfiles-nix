// SettingsRegistry — lista única de las categorías de Ajustes avanzados.
//
// TODO lo genérico se arma desde acá:
//   • AdvancedSettings.qml   dibuja la barra lateral (en este orden), carga la
//                            página de la categoría elegida con un Loader y
//                            arma el índice del buscador.
//   • SettingsPanelTitle     saca de acá el ícono y el nombre de cada categoría.
//
// Para AGREGAR una categoría migrada (una página en pages/):
//   1. SETTINGS/pages/MiPage.qml     `SettingsPage { catId: "mi"; … }`
//   2. Una entrada acá abajo, en el lugar donde quieras que salga en la barra.
//   3. Claves de traducción (título de la categoría y de cada sección).
// Ver GUIA_MODULOS.md.
//
// Campos de cada entrada:
//   id        identificador estable (string). Es el valor de `category` en
//             AdvancedSettings y el `cat` de las entradas del buscador.
//   icon      glifo Nerd Font del chip
//   titleKey  clave de traducción del nombre
//   page      archivo de la página, relativo a SETTINGS/ (ej. "pages/MiPage.qml").
//             "" = categoría todavía inline dentro de AdvancedSettings.qml
//             (se migra de a una; ver el plan en SIGUIENTE_FASE.md §3).
//   sections  (opcional) lo BUSCABLE de esa página. Solo las categorías con
//             `page` lo usan; las inline siguen en `searchIndex` de
//             AdvancedSettings.qml. Cada sección:
//               { titleKey, hintKey?, kw?, anchor?,
//                 rows?: [ { labelKey, hintKey?, kw?, anchor? } ] }
//             kw      palabras clave extra (es/en, sin tildes da igual)
//             anchor  texto visible al que scrollear (por defecto, el label)
//             Tocar un resultado abre la categoría, scrollea al texto y
//             resalta la tarjeta que lo contiene.
pragma Singleton
import QtQuick
import Quickshell
import "../LANG"

Singleton {
  id: root

  // Orden = orden de la barra lateral.
  readonly property var categories: [
    { id: "profile",    icon: "󰀄", titleKey: "advCatProfile",     page: "" },
    { id: "general",    icon: "󰒓", titleKey: "advCatGeneral",     page: "" },
    { id: "appearance", icon: "󰏘", titleKey: "advCatAppearance",  page: "" },
    { id: "interface",  icon: "󰍹", titleKey: "advCatInterface",   page: "" },

    { id: "agenda",      icon: "󰃭", titleKey: "advCatAgenda",      page: "pages/AgendaPage.qml",
      sections: [
        { titleKey: "todoAlarmsTitle", hintKey: "todoAlarmsHint",
          kw: "alarma alarmas recordatorio recordatorios aviso notificacion hora reminder alarm todo agenda",
          rows: [
            { labelKey: "todoAlarmsEnable", kw: "alarma alarmas activar desactivar encender apagar on off" },
            { labelKey: "todoAlarmSound", hintKey: "todoAlarmSoundHint", kw: "sonido audio pitido campana beep sound pw-play paplay" },
            { labelKey: "todoAlarmPersistent", hintKey: "todoAlarmPersistentHint", kw: "notificacion persistente fija pantalla critica cerrar sticky" },
            { labelKey: "todoAlarmTest", kw: "probar prueba test alarma notificacion" }
          ] }
      ] },

    { id: "services",   icon: "󰆍", titleKey: "advCatServices",    page: "pages/ServicesPage.qml",
      sections: [
        { titleKey: "advTachideskTitle", hintKey: "advTachideskHint",
          kw: "manga servidor server systemd servicio service",
          rows: [
            { labelKey: "advTachideskStart",       kw: "iniciar start encender tachidesk" },
            { labelKey: "advTachideskStop",        kw: "detener stop apagar tachidesk" },
            { labelKey: "advTachideskRestart",     kw: "reiniciar restart tachidesk" },
            { labelKey: "advTachideskOutputTitle", kw: "salida output estado status log" }
          ] }
      ] },

    { id: "audio",      icon: "󰕾", titleKey: "advCatAudio",       page: "" },

    { id: "about",      icon: "󰋽", titleKey: "advCatAbout",       page: "pages/AboutPage.qml",
      sections: [
        { titleKey: "advAboutSysInfoTitle", kw: "sistema system info hostname kernel uname cpu ram" },
        { titleKey: "advAboutRepoTitle", kw: "github git repositorio repos dotfiles codigo",
          rows: [
            { labelKey: "advAboutRepoDotfilesTitle", kw: "dotfiles hyprland github git" },
            { labelKey: "advAboutRepoNixTitle",      kw: "nixos nix home configuracion github git" }
          ] }
      ] }
  ]

  // ── Consultas ────────────────────────────────────────────────────────
  function byId(id) {
    for (const c of root.categories) if (c.id === id) return c
    return null
  }
  function iconOf(id)     { const c = root.byId(id); return c ? c.icon : "" }
  function titleKeyOf(id) { const c = root.byId(id); return c ? c.titleKey : "" }
  function pageOf(id)     { const c = root.byId(id); return (c && c.page) ? c.page : "" }

  // Entradas del buscador de las categorías migradas (formato de
  // AdvancedSettings.searchIndex: cat · key · hint · kw · sec · anchor).
  readonly property var searchEntries: {
    const out = []
    for (const c of root.categories) {
      for (const s of (c.sections ?? [])) {
        out.push({ cat: c.id, key: s.titleKey, text: "", hint: s.hintKey ?? "",
                   kw: s.kw ?? "", sec: "", anchor: s.anchor ?? "" })
        for (const r of (s.rows ?? []))
          out.push({ cat: c.id, key: r.labelKey, text: "", hint: r.hintKey ?? "",
                     kw: r.kw ?? "", sec: s.titleKey, anchor: r.anchor ?? "" })
      }
    }
    return out
  }
}
