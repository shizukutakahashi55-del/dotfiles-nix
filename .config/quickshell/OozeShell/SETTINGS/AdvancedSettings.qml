// AdvancedSettings — ventana grande de ajustes: categorías a la izquierda, detalle a la derecha.
// Las categorías se listan en SettingsRegistry.qml; las migradas viven en SETTINGS/pages/.
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Widgets
import "../COMMON"
import "../LANG"
import "../AGENDA"
import "../APPEARANCE"
import "../OozeAudio/data"

Item {
  id: root

  property bool open: false
  property string targetScreen: ""
  property string namespace: "oozeshell-advanced-settings"

  signal closeRequested()
  signal backRequested()
  signal requestMonitorEditor()

  // ── Señales de Perfil / General ──
  signal languageChosen(string code)

  // Monitor del shell ("auto" o nombre, ej. "DP-3") y a qué pantalla resuelve hoy
  property string targetMonitor: "auto"
  property string resolvedMonitor: ""
  signal monitorChosen(string name)

  // ── Marco de pantalla (Interfaz) ──
  property bool screenCorners: true
  signal requestCornersToggle()

  // ── Apariencia de Hyprland (mismo estado que APPEARANCE/Appearance.qml) ──
  property var appearanceValues: ({})
  signal appearancePreviewChanged(string key, real value)
  signal appearanceValueCommitted(string key, real value)
  signal appearanceToggleChanged(string key, bool value)

  // Sliders numéricos de Hyprland
  readonly property var hyprSliderSpecs: [
    { key: "gapsIn",          label: "Gaps in",          min: 0,   max: 30,  step: 1,    dec: 0, def: 3   },
    { key: "gapsOut",         label: "Gaps out",         min: 0,   max: 60,  step: 1,    dec: 0, def: 6   },
    { key: "borderSize",      label: "Border size",      min: 0,   max: 10,  step: 1,    dec: 0, def: 2   },
    { key: "rounding",        label: "Rounding",         min: 0,   max: 30,  step: 1,    dec: 0, def: 10  },
    { key: "activeOpacity",   label: "Active opacity",   min: 0.2, max: 1.0, step: 0.01, dec: 2, def: 1.0 },
    { key: "inactiveOpacity", label: "Inactive opacity", min: 0.2, max: 1.0, step: 0.01, dec: 2, def: 1.0 },
    { key: "blurSize",        label: "Blur size",        min: 0,   max: 15,  step: 1,    dec: 0, def: 3   },
    { key: "blurPasses",      label: "Blur passes",      min: 0,   max: 5,   step: 1,    dec: 0, def: 1   },
    { key: "shadowRange",     label: "Shadow range",     min: 0,   max: 50,  step: 1,    dec: 0, def: 3   },
    { key: "shadowRenderPower", label: "Shadow power",   min: 1,   max: 4,   step: 1,    dec: 0, def: 1   }
  ]

  readonly property var hyprSliderColors: ({
    accent: Theme.primary,
    text: Theme.text,
    subtext: Theme.subtext,
    track: Theme.surfaceHigh
  })

  readonly property var hyprToggles: [
    { key: "blurEnabled",       label: Translations.t("appearanceBlur"),       def: true  },
    { key: "shadowEnabled",     label: Translations.t("appearanceShadow"),     def: false },
    { key: "animationsEnabled", label: Translations.t("appearanceAnimations"), def: true  }
  ]

  // Categoría elegida: `id` de SettingsRegistry.categories
  property string category: "profile"
  property string query: ""

  // Mostrando el explorador de imágenes (categoría Perfil, foto de avatar)
  property bool browsing: false

  onOpenChanged: {
    if (!root.open) { root.query = ""; searchInput.text = ""; root.browsing = false; root.pendingAnchor = "" }
  }
  onBrowsingChanged: { if (root.browsing) profileBrowser.go(profileBrowser.home + "/Pictures") }

  // Categorías (orden = barra lateral): SettingsRegistry.qml
  readonly property var categories: SettingsRegistry.categories
  function pageOf(id) { return SettingsRegistry.pageOf(id) }

  // ── Tamaño de la interfaz (categoría General) ──
  readonly property var levelNames: [
    Translations.t("sizeSmall"), Translations.t("sizeMedium"), Translations.t("sizeNormal"),
    Translations.t("sizeLarge"), Translations.t("sizeHuge")
  ]
  readonly property int masterLevel: Theme.barLevel === Theme.windowLevel ? Theme.barLevel : -1
  function levelOf(kind) {
    return kind === "font" ? Theme.fontLevel : kind === "bar" ? Theme.barLevel : Theme.windowLevel
  }

  // Terminales instaladas (más la elegida)
  readonly property var terminalChoices: {
    const all = Theme.terminals
    const inst = Theme.installedTerminals
    const list = inst.length === 0
      ? all.slice()
      : all.filter(t => inst.indexOf(t.id) >= 0 || t.id === Theme.terminalId)
    if (!all.some(t => t.id === Theme.terminalId))
      list.unshift({ id: Theme.terminalId, name: Theme.terminalId })
    return list
  }

  // ── HyprMonitors: editor visual de monitores ──
  property var hmMonitors: []      // modelo editable, ver hmDetect
  property string hmSelected: ""   // "output" elegido abajo del mapa
  property string hmStatus: ""     // texto de estado tras Aplicar

  readonly property var hmCurrent: {
    for (const m of root.hmMonitors) if (m.output === root.hmSelected) return m
    return null
  }

  function hmRefresh() { hmDetect.running = false; hmDetect.running = true }

  Process {
    id: hmDetect
    command: ["hyprctl", "monitors", "-j"]
    running: false
    property string buffer: ""
    stdout: SplitParser { onRead: line => hmDetect.buffer += line }
    onRunningChanged: {
      if (!running) {
        try {
          const list = JSON.parse(hmDetect.buffer)
          root.hmMonitors = list.map(m => ({
            output:    m.name,
            width:     m.width,
            height:    m.height,
            x:         m.x,
            y:         m.y,
            scale:     m.scale,
            transform: m.transform || 0,
            modes:     Array.isArray(m.availableModes) ? m.availableModes : [],
            mode:      "preferred",
            mirrorOf:  ""
          }))
          if (!root.hmMonitors.some(m => m.output === root.hmSelected))
            root.hmSelected = root.hmMonitors.length > 0 ? root.hmMonitors[0].output : ""
        } catch (e) {
          console.log("AdvancedSettings/HyprMonitors: error leyendo hyprctl monitors:", e)
        }
        hmDetect.buffer = ""
      }
    }
  }

  // Redetecta al entrar a la categoría (ver Connections { target: root })

  // Reemplaza un monitor del modelo (inmutable, para que los bindings lo noten)
  function hmUpdateMonitor(output, patch) {
    root.hmMonitors = root.hmMonitors.map(m => m.output === output ? Object.assign({}, m, patch) : m)
  }

  // ── Mapa: caja que envuelve todos los monitores, con margen ──
  readonly property real hmMapPad: 400
  readonly property var hmBounds: {
    if (root.hmMonitors.length === 0) return { minX: 0, minY: 0, w: 1920, h: 1080 }
    let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity
    for (const m of root.hmMonitors) {
      const w = m.width / (m.scale || 1), h = m.height / (m.scale || 1)
      minX = Math.min(minX, m.x); minY = Math.min(minY, m.y)
      maxX = Math.max(maxX, m.x + w); maxY = Math.max(maxY, m.y + h)
    }
    return { minX: minX - root.hmMapPad, minY: minY - root.hmMapPad,
             w: (maxX - minX) + root.hmMapPad * 2, h: (maxY - minY) + root.hmMapPad * 2 }
  }
  property int hmMapHeight: 230
  property real hmMapWidth: 400  // se pisa con el ancho real de la tarjeta del mapa (hmMapCard.width)
  readonly property real hmMapScale: Math.min(
    (root.hmMapWidth - 20 * 2) / Math.max(1, root.hmBounds.w),
    root.hmMapHeight / Math.max(1, root.hmBounds.h)
  )

  function hmToMapX(x) { return (x - root.hmBounds.minX) * root.hmMapScale }
  function hmToMapY(y) { return (y - root.hmBounds.minY) * root.hmMapScale }
  function hmFromMapX(px) { return root.hmBounds.minX + px / root.hmMapScale }
  function hmFromMapY(py) { return root.hmBounds.minY + py / root.hmMapScale }
  // Redondea a pasos de 10px lógicos
  function hmSnap(v) { return Math.round(v / 10) * 10 }

  // ── Escritura de monitors.lua + aplicar ──────────────────────────────
  readonly property string hmMonitorsLuaPath:
    Quickshell.env("HOME") + "/.config/hypr/modules/hardware/settings/monitors.lua"

  // Un hl.monitor({...}) por salida; con espejo la posición se manda como "auto"
  function hmLuaMonitorBlock(m) {
    const pos = m.mirrorOf !== "" ? "auto" : (m.x + "x" + m.y)
    const lines = []
    lines.push("hl.monitor({")
    lines.push("    output   = \"" + m.output + "\",")
    lines.push("    mode     = \"" + m.mode + "\",")
    lines.push("    position = \"" + pos + "\",")
    lines.push("    scale    = " + (m.scale === "auto" ? "\"auto\"" : m.scale) + ",")
    if (m.transform && m.transform !== 0)
      lines.push("    transform = " + m.transform + ", -- 1 = 90°, 2 = 180°, 3 = 270°")
    if (m.mirrorOf !== "")
      lines.push("    mirror   = \"" + m.mirrorOf + "\",")
    lines.push("})")
    return lines.join("\n")
  }

  function hmBuildLua() {
    const header =
      "-- ============================================================================\n" +
      "--  MODULE: monitors.lua\n" +
      "--  Contains: monitor outputs (mode, position, scale, mirroring).\n" +
      "--  Auto-generado por OozeShell (Ajustes avanzados → HyprMonitor). No editar\n" +
      "--  a mano: se pisa entero cada vez que tocás \"Aplicar\" acá.\n" +
      "--  Wiki: https://wiki.hypr.land/Configuring/Basics/Monitors/\n" +
      "-- ============================================================================\n\n" +
      "------------------\n---- MONITORS ----\n------------------\n\n" +
      "-- See https://wiki.hypr.land/Configuring/Basics/Monitors/\n\n"
    return header + root.hmMonitors.map(m => root.hmLuaMonitorBlock(m)).join("\n\n") + "\n"
  }

  Process {
    id: hmSaveMonitorsLua
    property string content: ""
    command: ["bash", "-c",
      "mkdir -p \"$(dirname '" + root.hmMonitorsLuaPath + "')\" && cat > '" +
      root.hmMonitorsLuaPath + "' << 'OOZE_LUA_EOF'\n" + content + "\nOOZE_LUA_EOF\n"]
    running: false
    onRunningChanged: if (!running) { hmApplyReload.running = false; hmApplyReload.running = true }
  }

  // hyprland.lua ya se cargó al arrancar: hace falta un reload real
  Process {
    id: hmApplyReload
    running: false
    command: ["bash", "-c", "hyprctl reload"]
    property bool failed: false
    stdout: SplitParser { onRead: line => console.log("[hyprmonitor] hyprctl:", line) }
    stderr: SplitParser { onRead: line => { hmApplyReload.failed = true; console.log("[hyprmonitor] hyprctl error:", line) } }
    onRunningChanged: {
      if (!running) {
        root.hmStatus = hmApplyReload.failed ? Translations.t("hyprMonitorsError")
                                              : Translations.t("hyprMonitorsApplied")
        hmApplyReload.failed = false
      }
    }
  }

  function hmApplyAndSave() {
    root.hmStatus = ""
    hmSaveMonitorsLua.content = root.hmBuildLua()
    hmSaveMonitorsLua.running = false
    hmSaveMonitorsLua.running = true
  }

  // Ancho fijo de la barra lateral (el cálculo dinámico falla en este setup; si un texto no entra, súbelo a mano)
  readonly property real sidebarWidth: Math.max(160, sidebarMeasure.implicitWidth + 78)

  // ══ BUSCADOR ══
  // Índice de las opciones de todos los paneles. Opción nueva: categoría migrada → SettingsRegistry.qml; inline → `searchIndex`.
  readonly property bool searching: root.query.trim() !== ""

  function norm(s) {
    let t = String(s ?? "").toLowerCase()
    if (t.normalize) t = t.normalize("NFD").replace(/[\u0300-\u036f]/g, "")
    return t
  }
  function catKeyOf(id) { return SettingsRegistry.titleKeyOf(id) }
  function catIconOf(id) { return SettingsRegistry.iconOf(id) }
  function catIconByKey(key) {
    for (const c of root.categories) if (c.titleKey === key) return c.icon
    return ""
  }
  function entryLabel(e) { return e.key ? Translations.t(e.key) : (e.text ?? "") }
  function entryHint(e) { return e.hint ? Translations.t(e.hint) : "" }

  // Sinónimos para los sliders de Hyprland (sus labels están fijos en inglés).
  readonly property var hyprSliderKw: ({
    gapsIn: "espacio separacion margen entre ventanas gap",
    gapsOut: "espacio separacion margen pantalla gap",
    borderSize: "borde grosor border",
    rounding: "redondeo esquinas redondeadas radio corners",
    activeOpacity: "opacidad transparencia ventana activa",
    inactiveOpacity: "opacidad transparencia ventana inactiva",
    blurSize: "desenfoque blur difuminado",
    blurPasses: "desenfoque blur difuminado",
    shadowRange: "sombra shadow",
    shadowRenderPower: "sombra shadow"
  })

  // cat = categoría · key/text = label · hint = descripción · kw = palabras clave · sec = sección · anchor = texto a buscar
  readonly property var searchIndex: {
    const E = (cat, key, hint, kw, sec) => ({ cat: cat, key: key, text: "", hint: hint ?? "", kw: kw ?? "", sec: sec ?? "", anchor: "" })
    const list = [
      // 0 · Apariencia
      E("appearance", "advPaletteTitle", "", "matugen palette paleta colores color tema automatico manual wallpaper fondo"),
      E("appearance", "advHyprTitle", "advHyprHint", "gaps bordes borders blur sombra shadow opacidad opacity rounding hyprland"),
      E("appearance", "appearanceBlur", "", "desenfoque blur difuminado", "advHyprTitle"),
      E("appearance", "appearanceShadow", "", "sombra shadow", "advHyprTitle"),
      E("appearance", "appearanceAnimations", "", "animaciones animations efectos movimiento", "advHyprTitle"),
      E("appearance", "themeSection", "", "theme tema oscuro dark claro light"),
      E("appearance", "themeLightMode", "themeLightHint", "claro light oscuro dark tema theme", "themeSection"),
      // 1 · Interfaz
      E("interface", "uiSizeTitle", "uiSizeHint", "tamano size escala scale zoom grande pequeno"),
      E("interface", "uiFineTune", "uiFineHint", "ajuste fino fine tune"),
      E("interface", "uiFont", "", "fuente letra font tipografia texto", "uiFineTune"),
      E("interface", "uiBar", "", "barra bar altura", "uiFineTune"),
      E("interface", "uiWindows", "", "ventanas windows paneles", "uiFineTune"),
      E("interface", "uiReset", "", "reiniciar reset normal restablecer", "uiFineTune"),
      E("interface", "dockSection", "", "dock iconos apps"),
      E("interface", "dockEnable", "", "dock mostrar show activar", "dockSection"),
      E("interface", "dockAutoHide", "", "auto ocultar hide esconder", "dockSection"),
      E("interface", "dockPosition", "", "posicion position arriba abajo izquierda derecha", "dockSection"),
      E("interface", "dockSize", "dockSizeHint", "tamano size escala scale dock grande pequeno", "dockSection"),
      E("interface", "barSection", "barSectionHint", "barra bar waybar panel"),
      E("interface", "barPosition", "", "posicion position arriba abajo top bottom", "barSection"),
      E("interface", "barFloating", "barFloatingHint", "flotante floating separada", "barSection"),
      E("interface", "barIslands", "barIslandsHint", "islas islands", "barSection"),
      E("interface", "barPillMode", "barPillModeHint", "pildora pill dashboard compacta", "barSection"),
      E("interface", "barPillAutoHide", "", "pildora pill ocultar hide automatico", "barPillMode"),
      E("interface", "barPillTraySync", "", "pildora pill esconder juntas tray bandeja", "barPillMode"),
      E("interface", "pillSize", "pillSizeHint", "pildora pill tamano size escala scale grande pequeno", "barPillMode"),
      E("interface", "dashSize", "dashSizeHint", "dashboard tablero panel pildora pill tamano size grande pequeno niveles", "barPillMode"),
      E("interface", "batterySection", "batteryHint", "bateria battery energia porcentaje"),
      E("interface", "advPanelWidthTitle", "advPanelWidthHint", "ancho width paneles grandes ventana"),
      E("interface", "advFrameTitle", "advFrameEnableHint", "marco frame borde pantalla esquinas corners curvas"),
      E("interface", "advFrameStyleLabel", "advFrameStyleHint", "estilo style marco frame", "advFrameTitle"),
      E("interface", "advFrameStyleCorners", "", "esquinas corners marco frame", "advFrameTitle"),
      E("interface", "advFrameStyleCurved", "", "curvas curved marco frame", "advFrameTitle"),
      E("interface", "advFrameRadiusLabel", "", "radio curva radius redondeo marco frame", "advFrameTitle"),
      E("interface", "advFrameThicknessLabel", "", "grosor thickness ancho marco frame", "advFrameTitle"),
      // 3 · Audio
      E("audio", "advAudioOpenQpwgraph", "", "patchbay pipewire conexiones grafo qpwgraph"),
      E("audio", "advAudioMonitorsToggleLabel", "", "monitores monitors oozeaudio mostrar seccion"),
      E("audio", "advAudioOutputsTitle", "advAudioOutputsHint", "salidas virtuales virtual sink discord pipewire"),
      E("audio", "advAudioCreate", "", "crear create nueva salida virtual", "advAudioOutputsTitle"),
      E("audio", "advAudioMonitorsTitle", "advAudioMonitorsHint", "monitores monitors salidas fisicas parlantes auriculares volumen volume"),
      // 5 · Perfil
      E("profile", "profilePhoto", "profileBrowseHint", "avatar imagen foto picture perfil"),
      E("profile", "profileChange", "", "cambiar imagen foto avatar elegir", "profilePhoto"),
      E("profile", "profileRemove", "", "quitar borrar remove foto avatar", "profilePhoto"),
      E("profile", "profileDisplayName", "profileDisplayNameHint", "nombre usuario username name mostrar"),
      // 6 · General
      E("general", "settingsMonitor", "monitorAutoSubtitle", "pantalla display screen monitor principal auto"),
      E("general", "monitorAutoOption", "monitorAutoHint", "automatico auto monitor pantalla", "settingsMonitor"),
      E("general", "settingsLanguage", "settingsLanguageHint", "idioma language espanol english japones indonesio"),
      E("general", "settingsLauncherSection", "settingsLauncherHint", "launcher lanzador aplicaciones apps"),
      E("general", "settingsLauncherPlacement", "", "ubicacion posicion centro barra center bar launcher lanzador", "settingsLauncherSection"),
      E("general", "settingsLauncherBar", "", "barra bar pegado conectado launcher lanzador", "settingsLauncherSection"),
      E("general", "settingsLauncherCenter", "", "centro centrado center launcher lanzador", "settingsLauncherSection"),
      E("general", "settingsLauncherImage", "", "imagen image launcher lanzador quitar", "settingsLauncherSection"),
      E("general", "settingsLauncherSize", "", "tamano size launcher lanzador", "settingsLauncherSection"),
      E("general", "settingsEffectsSection", "", "efectos effects cpu gpu rendimiento performance"),
      E("general", "settingsEffectsLabel", "settingsEffectsHint", "efectos effects cpu gpu rendimiento performance", "settingsEffectsSection"),
      E("general", "settingsLauncherParticles", "settingsLauncherParticlesHint", "particulas brillos particles glow efectos launcher", "settingsEffectsSection"),
      E("general", "settingsLauncherWallpaperLive", "settingsLauncherWallpaperLiveHint", "fondo animado wallpaper video mpvpaper walls live", "settingsEffectsSection"),
      E("general", "settingsTerminalSection", "settingsTerminalHint", "terminal consola kitty alacritty foot wezterm comandos"),
      E("general", "lockSection", "", "bloqueo lock pantalla oozelock fondo wallpaper"),
      E("general", "lockModeAuto", "", "automatico auto bloqueo lock fondo wallpaper", "lockSection"),
      E("general", "lockModeCustom", "", "personalizado custom bloqueo lock fondo wallpaper ruta path", "lockSection"),
      // 7 · HyprMonitor
      E("hypr", "advCatHyprMonitor", "hyprMonitorsHint", "monitores monitors pantallas displays posicion arrastrar editor"),
      E("hypr", "hyprMonitorsRefresh", "", "detectar refrescar redetect actualizar monitores", "advCatHyprMonitor"),
      E("hypr", "hyprMonitorsMode", "", "modo resolucion resolution hz refresh frecuencia", "advCatHyprMonitor"),
      E("hypr", "hyprMonitorsPreferred", "", "preferido preferred resolucion resolution", "advCatHyprMonitor"),
      E("hypr", "hyprMonitorsScale", "", "escala scale zoom", "advCatHyprMonitor"),
      E("hypr", "hyprMonitorsRotation", "", "rotacion rotation girar vertical transform", "advCatHyprMonitor"),
      E("hypr", "hyprMonitorsMirror", "", "espejo mirror duplicar clonar", "advCatHyprMonitor"),
      E("hypr", "hyprMonitorsApply", "", "aplicar guardar apply save monitors.lua hl.monitor", "advCatHyprMonitor"),
    ]
    const sliders = root.hyprSliderSpecs.map(sp => ({
      cat: "appearance", key: "", text: sp.label, hint: "", kw: root.hyprSliderKw[sp.key] ?? "",
      sec: "advHyprTitle", anchor: sp.label
    }))
    // Categorías de pages/ (índice en SettingsRegistry.qml); descarta claves sin traducción
    return list.concat(sliders).concat(SettingsRegistry.searchEntries)
                .filter(e => !e.key || Translations.t(e.key) !== e.key)
  }

  // Texto normalizado de cada entrada, calculado UNA vez por cambio de índice o
  // de idioma (antes se normalizaba —NFD + regex— 5 cadenas por entrada y por
  // TECLA pulsada). Ahora cada tecla solo hace indexOf sobre estas cadenas.
  readonly property var searchHay: {
    const idxList = root.searchIndex
    const out = new Array(idxList.length)
    for (let i = 0; i < idxList.length; i++) {
      const e = idxList[i]
      const label = root.norm(root.entryLabel(e))
      const hint = root.norm(root.entryHint(e))
      const catName = root.norm(Translations.t(root.catKeyOf(e.cat)))
      const sec = e.sec ? root.norm(Translations.t(e.sec)) : ""
      const kw = root.norm(e.kw)
      out[i] = { label: label, sec: sec, kw: kw,
                 hay: label + " " + sec + " " + catName + " " + hint + " " + kw }
    }
    return out
  }

  // Todos los términos deben aparecer; el label pesa más
  readonly property var searchResults: {
    const q = root.norm(root.query.trim())
    if (q === "") return []
    const tokens = q.split(/\s+/).filter(t => t.length > 0)
    const out = []
    const idxList = root.searchIndex
    const cache = root.searchHay
    for (let i = 0; i < idxList.length; i++) {
      const c = cache[i]
      let ok = true
      let score = 0
      for (const t of tokens) {
        if (c.hay.indexOf(t) < 0) { ok = false; break }
        const at = c.label.indexOf(t)
        if (c.label === t) score += 14
        else if (at === 0) score += 8
        else if (at > 0) score += 5
        else if (c.sec.indexOf(t) >= 0) score += 3
        else if (c.kw.indexOf(t) >= 0) score += 2
        else score += 1
      }
      if (ok) out.push({ e: idxList[i], score: score, i: i })
    }
    out.sort((x, y) => (y.score - x.score) || (x.i - y.i))
    return out.map(r => r.e)
  }

  readonly property var searchCounts: {
    const m = ({})
    for (const e of root.searchResults) m[e.cat] = (m[e.cat] ?? 0) + 1
    return m
  }

  readonly property var visibleCategories: root.searching
    ? root.categories.filter(c => (root.searchCounts[c.id] ?? 0) > 0)
    : root.categories

  // Resalta los términos buscados (solo si la normalización no cambia el largo)
  function hl(text, q) {
    const raw = String(text ?? "")
    const esc = t => t.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    const nq = root.norm(String(q ?? "").trim())
    const n = root.norm(raw)
    if (nq === "" || n.length !== raw.length) return esc(raw)
    const mark = []
    for (let i = 0; i < raw.length; i++) mark.push(false)
    for (const t of nq.split(/\s+/)) {
      if (t.length === 0) continue
      let at = n.indexOf(t)
      while (at >= 0) {
        for (let k = at; k < at + t.length; k++) mark[k] = true
        at = n.indexOf(t, at + t.length)
      }
    }
    let outStr = ""
    let open = false
    for (let i = 0; i < raw.length; i++) {
      if (mark[i] && !open) { outStr += '<font color="' + Theme.primary + '"><b>'; open = true }
      if (!mark[i] && open) { outStr += "</b></font>"; open = false }
      outStr += esc(raw[i])
    }
    if (open) outStr += "</b></font>"
    return outStr
  }

  // ── Ir a una opción: abre la categoría, scrollea y resalta ──
  property string pendingAnchor: ""
  function goToEntry(e) {
    root.pendingAnchor = e.anchor !== "" ? e.anchor : (e.key ? Translations.t(e.key) : (e.text ?? ""))
    root.query = ""
    searchInput.text = ""
    root.category = e.cat
    anchorTimer.restart()
  }
  function openCategory(id) {
    root.pendingAnchor = ""
    root.query = ""
    searchInput.text = ""
    root.category = id
  }
  // Busca el primer Text/Btn visible cuyo texto coincide
  function findByText(item, target) {
    const kids = item.children
    for (let i = 0; i < kids.length; i++) {
      const k = kids[i]
      if (!k.visible) continue
      const t = k.text
      if (typeof t === "string" && t !== "" && root.norm(t) === target) return k
      const r = root.findByText(k, target)
      if (r) return r
    }
    return null
  }
  function scrollToAnchor() {
    const target = root.norm(root.pendingAnchor)
    root.pendingAnchor = ""
    if (target === "") return
    const found = root.findByText(detailCol, target)
    if (!found) return
    const p = found.mapToItem(flick.contentItem, 0, 0)
    const maxY = Math.max(0, flick.contentHeight - flick.height)
    flick.contentY = Math.max(0, Math.min(maxY, p.y - 72))
    // Resalta la tarjeta que lo contiene (o el propio item si no hay)
    let host = found.parent
    while (host && host !== detailCol) {
      if (host.radius === Theme.cardRadius && host.color !== undefined) break
      host = host.parent
    }
    const box = (host && host !== detailCol) ? host : found
    const bp = box.mapToItem(flick.contentItem, 0, 0)
    flashBox.x = bp.x - 4
    flashBox.y = bp.y - 4
    flashBox.width = box.width + 8
    flashBox.height = box.height + 8
    flashAnim.restart()
  }
  Timer { id: anchorTimer; interval: 130; repeat: false; onTriggered: root.scrollToAnchor() }
  Timer { id: queryDebounce; interval: 110; repeat: false; onTriggered: root.query = searchInput.text }

  // Ventana grande, en medidas lógicas (la escala se aplica una sola vez con `card.scale`);
  // el ancho respeta "Ancho de paneles grandes"
  readonly property int winW: Math.round(960 * Theme.panelWidthScale)
  readonly property int winH: 660
  // Escala de la tarjeta, limitada para que quepa en pantalla
  readonly property real winScale: {
    const s = Theme.windowScale
    const p = card.parent
    if (s <= 1 || !p || p.width <= 0 || p.height <= 0) return s
    const fit = Math.min((p.width - 32) / root.winW,
                         (p.height - Theme.barOffset * 2 - 16) / root.winH)
    return Math.max(1, Math.min(s, fit))
  }

  // Mide el label más largo (no se dibuja)
Text {
  id: sidebarMeasure
  visible: false
  font.bold: true
  font.pixelSize: Theme.fs(12)
  font.family: Theme.fontFamily
  text: {
    let longest = ""
    for (const c of root.categories) {
      const t = Translations.t(c.titleKey)
      if (t.length > longest.length) longest = t
    }
    return longest
  }
}


  // ── OozeAudio: mismo AudioService que la app suelta ──
  property string oozeAudioNewName: ""
  // Output a borrar (confirmación en dos clics)
  property string oozeAudioConfirmDelete: ""

  // Refresca el audio la primera vez que se entra a la categoría
  property bool oozeAudioRefreshedOnce: false

  // Un solo Connections para los cambios de categoría (QML no permite dos onCategoryChanged)
  Connections {
    target: root
    function onCategoryChanged() {
      if (root.category === "audio" && !root.oozeAudioRefreshedOnce) {
        root.oozeAudioRefreshedOnce = true
        AudioService.refreshAll()
      }
      // Cambiar de categoría cancela cualquier confirmación de borrado pendiente
      root.oozeAudioConfirmDelete = ""

      // Redetecta monitores al entrar
      if (root.category === "hypr") root.hmRefresh()
    }
  }

  property string oozeAudioError: ""
  Connections {
    target: AudioService
    function onCommandFailed(message) {
      root.oozeAudioError = message
      oozeAudioErrorTimer.restart()
    }
  }
  Timer { id: oozeAudioErrorTimer; interval: 5000; repeat: false; onTriggered: root.oozeAudioError = "" }

  // ── Abrir qpwgraph (avisa si no está instalado) ──
  Process {
    id: qpwgraphProc
    command: ["bash", "-c", "command -v qpwgraph >/dev/null 2>&1 && exec qpwgraph || echo '__ooze_qpwgraph_missing__' >&2"]
    stderr: StdioCollector {
      id: qpwgraphErr
      onStreamFinished: {
        if (qpwgraphErr.text.indexOf("__ooze_qpwgraph_missing__") !== -1) {
          root.oozeAudioError = Translations.t("advAudioQpwgraphMissing")
          oozeAudioErrorTimer.restart()
        }
      }
    }
  }
  function openQpwgraph() {
    qpwgraphProc.running = false
    qpwgraphProc.running = true
  }

  // Fila de audio: nombre + mute + volumen; borrar solo en salidas virtuales (2 clics)
  component AudioRow: SkinRect {
    id: row
    property string nodeId: ""
    property string nodeName: ""
    property string title: ""
    property string subtitle: ""
    property int volume: 100
    property bool muted: false
    property bool deletable: false
    property bool confirmingDelete: false
    // Solo salidas virtuales: chips para conectar cada salida física
    property bool showConnections: false
    signal volumeMoved(real v)
    signal muteToggled()
    signal deleteRequested()

    Layout.fillWidth: true
    implicitHeight: rowContent.implicitHeight + 20  
    radius: 10
    color: Theme.bg
    clip: true

    ColumnLayout {
    id: rowContent
    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
    spacing: 8

      RowLayout {
        Layout.fillWidth: true
        spacing: 10

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 0
          Text {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: row.title
            color: Theme.text
            font.bold: true
            font.pixelSize: Theme.fs(12)
            font.family: Theme.fontFamily
          }
          Text {
            visible: row.subtitle !== ""
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: row.subtitle
            color: Theme.subtext
            font.pixelSize: Theme.fs(10)
            font.family: Theme.fontFamily
          }
        }

        SkinRect {
          Layout.preferredWidth: 30
          Layout.preferredHeight: 26
          radius: 9
          color: row.muted ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.16)
               : (muteArea.containsMouse ? Theme.surfaceHigh : "transparent")
          Behavior on color { ColorAnimation { duration: 120 } }
          Text {
            anchors.centerIn: parent
            text: row.muted ? "󰝟" : "󰕾"
            color: row.muted ? Theme.error : Theme.subtext
            font.pixelSize: Theme.fs(13)
            font.family: Theme.monoFamily
          }
          MouseArea {
            id: muteArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.muteToggled()
          }
        }

        SkinRect {
          visible: row.deletable
          Layout.preferredWidth: 30
          Layout.preferredHeight: 26
          radius: 9
          color: row.confirmingDelete
            ? Theme.error
            : (delArea.containsMouse ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.16) : "transparent")
          Behavior on color { ColorAnimation { duration: 120 } }
          Text {
            anchors.centerIn: parent
            text: row.confirmingDelete ? "󰄬" : "󰆴"
            color: row.confirmingDelete ? Theme.textOnPrimary : Theme.subtext
            font.pixelSize: Theme.fs(12)
            font.family: Theme.monoFamily
          }
          MouseArea {
            id: delArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.deleteRequested()
          }
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: 10
        enabled: !row.muted
        opacity: row.muted ? 0.4 : 1
        Behavior on opacity { NumberAnimation { duration: 120 } }

        Text {
          Layout.fillWidth: true
          text: Translations.t("advAudioVolume")
          color: Theme.subtext
          font.pixelSize: Theme.fs(11)
          font.family: Theme.fontFamily
        }

        NumberStepper {
          Layout.preferredWidth: 130
          value: row.volume
          min: 0; max: 150; step: 5
          suffix: "%"
          onEdited: v => row.volumeMoved(v)
        }
      }

      // ── Conectar a: chips por cada salida física, tildable individual ──
      ColumnLayout {
        Layout.fillWidth: true
        Layout.topMargin: 2
        spacing: 4
        visible: row.showConnections && AudioService.destinationCandidates().length > 0

        Text {
          text: Translations.t("advAudioConnectTo")
          color: Theme.subtext
          font.pixelSize: Theme.fs(10)
          font.family: Theme.fontFamily
        }

        Flow {
          Layout.fillWidth: true
          spacing: 6

          Repeater {
            model: AudioService.destinationCandidates()
            delegate: SkinRect {
              id: chip
              required property var modelData
              readonly property bool connected: AudioService.isConnected(row.nodeName, modelData.name)

              width: chipRow.implicitWidth + 18
              height: 26
              radius: 8
              color: chip.connected
                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)
                : (chipArea.containsMouse ? Theme.surfaceHigh : Theme.surface)
              border.width: chip.connected ? 1 : 0
              border.color: Theme.primary
              Behavior on color { ColorAnimation { duration: 120 } }

              RowLayout {
                id: chipRow
                anchors.centerIn: parent
                spacing: 5
                Text {
                  visible: chip.connected
                  text: "󰄬"
                  color: Theme.primary
                  font.pixelSize: Theme.fs(10)
                  font.family: Theme.monoFamily
                }
                Text {
                  text: chip.modelData.desc
                  color: chip.connected ? Theme.text : Theme.subtext
                  font.pixelSize: Theme.fs(10)
                  font.family: Theme.fontFamily
                }
              }

              MouseArea {
                id: chipArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: AudioService.setConnection(row.nodeName, chip.modelData.name, !chip.connected)
              }
            }
          }
        }
      }
    }
  }

  PanelWindow {
    id: win

    screen: Quickshell.screens.find(s => s.name === root.targetScreen) ?? Quickshell.screens[0]
    visible: true
    color: "transparent"
    exclusiveZone: -1
    anchors { top: true; left: true; right: true; bottom: true }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: root.namespace
    // Modal: mientras está abierta se queda con el teclado (Esc)
    WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Cerrada: región vacía = todo click-through
    mask: Region { item: hitArea }

    Connections {
      target: root
      function onOpenChanged() {
        if (root.open) keyCatcher.forceActiveFocus()
      }
    }


    // ── Zona que captura input (clic afuera = cerrar) ──
    Item {
      id: hitArea
      width: root.open ? parent.width : 0
      height: root.open ? parent.height : 0

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onClicked: root.closeRequested()
      }
    }

    Item {
      id: keyCatcher
      anchors.fill: parent
      focus: true
      Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
          if (root.searching) searchInput.text = ""
          else root.closeRequested()
          event.accepted = true
        } else if (event.text.length === 1 && event.text.charCodeAt(0) >= 32
                   && event.text.charCodeAt(0) !== 127
                   && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
          // Escribir con el foco en cualquier parte del panel = buscar.
          searchInput.forceActiveFocus()
          searchInput.text += event.text
          searchInput.cursorPosition = searchInput.text.length
          event.accepted = true
        }
      }
    }

    // ── Tarjeta grande ──
    Rectangle {
      id: card
      anchors.centerIn: parent
      width: root.winW
      height: root.winH
      // CoOzey: marco con NotchRect
      radius: Theme.cozy ? 0 : Theme.panelRadius
      color: Theme.cozy ? "transparent" : Theme.bg
      border.width: Theme.cozy ? 0 : Theme.bw1
      border.color: Theme.edge
      // Recorta las esquinas al `radius`
      clip: true

      opacity: root.open ? 1 : 0
      visible: opacity > 0
      scale: (root.open ? 1.0 : 0.95) * root.winScale
      Behavior on opacity { NumberAnimation { duration: 180 } }
      Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

      // Los clics sobre la tarjeta no deben llegar al fondo (que cierra)
      MouseArea { anchors.fill: parent }

      // ── Marco pixel (solo CoOzey) ──
      readonly property int pixShadow: 4
      readonly property int pixNotch: 8
      Item {
        visible: Theme.cozy
        anchors.fill: parent
        NotchRect {
          x: 0; y: card.pixShadow
          width: parent.width; height: parent.height - card.pixShadow
          topColor: Theme.shadowInk
          notch: card.pixNotch
        }
        NotchRect {
          width: parent.width; height: parent.height - card.pixShadow
          topColor: Theme.ink
          notch: card.pixNotch
        }
        NotchRect {
          x: Theme.inkWidth; y: Theme.inkWidth
          width: parent.width - 2 * Theme.inkWidth
          height: parent.height - card.pixShadow - 2 * Theme.inkWidth
          topColor: Theme.bg
          notch: card.pixNotch - 1
        }
      }

      // Recorte redondeado del contenido (ClippingRectangle); en CoOzey deja espacio para contorno y sombra
      ClippingRectangle {
        id: cardClip
        x: Theme.cozy ? Theme.inkWidth : 0
        y: Theme.cozy ? Theme.inkWidth : 0
        width: card.width - (Theme.cozy ? 2 * Theme.inkWidth : 0)
        height: card.height - (Theme.cozy ? card.pixShadow + 2 * Theme.inkWidth : 0)
        radius: Theme.cozy ? card.pixNotch - 2 : card.radius
        color: "transparent"

      ColumnLayout {
        // El layout conserva el tamaño completo; el recorte oculta lo que sobra
        x: -cardClip.x
        y: -cardClip.y
        width: card.width
        height: card.height
        spacing: 0

        // ── Encabezado: volver · título · buscador · cerrar ──
        RowLayout {
          Layout.fillWidth: true
          Layout.preferredHeight: 60
          Layout.leftMargin: 20
          Layout.rightMargin: 16
          spacing: 12

          SkinRect {
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            radius: 15
            color: backArea.containsMouse ? Theme.surfaceHigh : Theme.surface
            Behavior on color { ColorAnimation { duration: 120 } }
            Text {
              anchors.centerIn: parent
              text: "󰅁"
              color: Theme.text
              font.pixelSize: Theme.fs(16)
              font.family: Theme.monoFamily
            }
            MouseArea {
              id: backArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.backRequested()
            }
          }

          Text {
            text: "󰒓"
            color: Theme.primary
            font.pixelSize: Theme.fs(19)
            font.family: Theme.monoFamily
          }
          Text {
            text: Translations.t("advTitle")
            color: Theme.text
            font.bold: true
            font.pixelSize: Theme.fs(16)
            font.family: Theme.fontFamily
          }

          Item { Layout.fillWidth: true }

          // ── Buscador: categorías Y opciones de todos los paneles ──
          SkinRect {
            Layout.preferredWidth: 300
            Layout.preferredHeight: 36
            radius: 12
            color: Theme.surface
            border.width: Theme.bw1
            border.color: searchInput.activeFocus
              ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.6)
              : Theme.divider
            Behavior on border.color { ColorAnimation { duration: 150 } }

            RowLayout {
              anchors { fill: parent; leftMargin: 12; rightMargin: 8 }
              spacing: 8

              Text {
                text: "󰍉"
                color: (searchInput.activeFocus || root.searching) ? Theme.primary : Theme.subtext
                font.pixelSize: Theme.fs(13)
                font.family: Theme.monoFamily
                Behavior on color { ColorAnimation { duration: 150 } }
              }

              TextInput {
                id: searchInput
                Layout.fillWidth: true
                color: Theme.text
                selectionColor: Theme.primary
                selectedTextColor: Theme.textOnPrimary
                font.pixelSize: Theme.fs(12)
                font.family: Theme.monoFamily
                clip: true
                inputMethodHints: Qt.ImhNoPredictiveText
                // Debounce: la lista de resultados se reconstruye tras una pausa
                // de 110 ms al teclear, no en cada letra. Vaciar el campo es inmediato.
                onTextChanged: {
                  if (text === "") { queryDebounce.stop(); root.query = "" }
                  else queryDebounce.restart()
                }
                // Esc: primero limpia la búsqueda; con el campo vacío, cierra.
                Keys.onEscapePressed: event => {
                  if (searchInput.text !== "") searchInput.text = ""
                  else root.closeRequested()
                  event.accepted = true
                }
                // Enter: abre el mejor resultado.
                Keys.onReturnPressed: if (root.searchResults.length > 0) root.goToEntry(root.searchResults[0])
                Keys.onEnterPressed: if (root.searchResults.length > 0) root.goToEntry(root.searchResults[0])

                Text {
                  visible: searchInput.text === "" && !searchInput.activeFocus
                  text: Translations.t("advSearchPlaceholder")
                  color: Theme.subtext
                  font.pixelSize: Theme.fs(12)
                  font.family: Theme.fontFamily
                }
              }

              SkinRect {
                visible: searchInput.text !== ""
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                radius: 11
                color: clearArea.containsMouse ? Theme.surfaceHigh : "transparent"
                Text {
                  anchors.centerIn: parent
                  text: "✕"
                  color: Theme.subtext
                  font.pixelSize: Theme.fs(10)
                  font.family: Theme.fontFamily
                }
                MouseArea {
                  id: clearArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: { searchInput.text = ""; searchInput.forceActiveFocus() }
                }
              }
            }
          }

          SkinRect {
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            radius: 15
            color: closeArea.containsMouse ? Theme.surfaceHigh : Theme.surface
            Behavior on color { ColorAnimation { duration: 120 } }
            Text {
              anchors.centerIn: parent
              text: "✕"
              color: Theme.text
              font.pixelSize: Theme.fs(14)
              font.family: Theme.fontFamily
            }
            MouseArea {
              id: closeArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.closeRequested()
            }
          }
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }

        // ── Cuerpo: categorías + detalle ──
        RowLayout {
          Layout.fillWidth: true
          Layout.fillHeight: true
          spacing: 0

          // ── Barra lateral ──
          Rectangle {
            Layout.preferredWidth: root.sidebarWidth
            Layout.minimumWidth: root.sidebarWidth
            Layout.fillHeight: true
            color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.5)

            ColumnLayout {
              anchors { fill: parent; topMargin: 14; leftMargin: 10; rightMargin: 10; bottomMargin: 10 }
              spacing: 3

              Repeater {
                model: root.visibleCategories

                delegate: SkinRect {
                  id: catRow
                  required property var modelData
                  // `.id` de la entrada de SettingsRegistry.categories.
                  readonly property string catIndex: catRow.modelData.id
                  // En búsqueda ninguna categoría está activa
                  readonly property bool current: !root.searching && root.category === catIndex
                  readonly property int hits: root.searchCounts[catIndex] ?? 0

                  Layout.fillWidth: true
                  Layout.preferredHeight: 40
                  radius: 11
                  color: catRow.current ? Theme.primary
                       : (catArea.containsMouse ? Theme.surfaceHigh : "transparent")
                  Behavior on color { ColorAnimation { duration: 150 } }

                  RowLayout {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 9 }
                    spacing: 10

                    Text {
                      Layout.preferredWidth: Theme.fs(16)
                      horizontalAlignment: Text.AlignHCenter
                      text: catRow.modelData.icon
                      color: catRow.current ? Theme.textOnPrimary : Theme.primary
                      font.pixelSize: Theme.fs(15)
                      font.family: Theme.monoFamily
                      Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    Text {
                      Layout.fillWidth: true
                      elide: Text.ElideRight
                      text: Translations.t(catRow.modelData.titleKey)
                      color: catRow.current ? Theme.textOnPrimary : Theme.text
                      font.bold: true
                      font.pixelSize: Theme.fs(12)
                      font.family: Theme.fontFamily
                      Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    // Cuántos resultados de la búsqueda caen en esta categoría
                    SkinRect {
                      visible: root.searching
                      Layout.preferredHeight: 20
                      Layout.preferredWidth: Math.max(22, hitsText.implicitWidth + 12)
                      radius: 10
                      color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)
                      Text {
                        id: hitsText
                        anchors.centerIn: parent
                        text: catRow.hits
                        color: Theme.primary
                        font.bold: true
                        font.pixelSize: Theme.fs(10)
                        font.family: Theme.fontFamily
                      }
                    }
                  }

                  MouseArea {
                    id: catArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openCategory(catRow.catIndex)
                  }
                }
              }

              Text {
                visible: root.visibleCategories.length === 0
                Layout.fillWidth: true
                Layout.topMargin: 8
                Layout.leftMargin: 4
                wrapMode: Text.WordWrap
                text: Translations.t("advNoResults")
                color: Theme.subtext
                font.pixelSize: Theme.fs(11)
                font.family: Theme.fontFamily
              }

              Item { Layout.fillHeight: true }
            }
          }

          Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: Theme.divider }

          // ── Detalle de la categoría elegida ──
          Flickable {
            id: flick
            Layout.fillWidth: true
            Layout.minimumWidth: 320          // ← clave: nunca colapsa a 1px
            Layout.preferredWidth: 480        // ← ancho cómodo por defecto
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: detailCol.implicitHeight + 52
            clip: true
            boundsBehavior: Flickable.StopAtBounds


            // Vuelve arriba al cambiar de categoría o reabrir
            Behavior on contentY {
              enabled: flick.moving === false
              NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }
            Connections {
              target: root
              function onCategoryChanged() { flick.contentY = 0 }
              function onOpenChanged() { if (root.open) flick.contentY = 0 }
            }

            // Búsqueda nueva → la lista de resultados arranca desde arriba.
            Connections {
              target: root
              function onQueryChanged() { if (root.searching) flick.contentY = 0 }
            }

            // Resaltado de la opción a la que se saltó desde un resultado
            SkinRect {
              id: flashBox
              z: 50
              radius: Theme.cardRadius + 3
              color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)
              inkColor: Theme.primary
              border.width: 2
              border.color: Theme.primary
              opacity: 0
              visible: opacity > 0
              enabled: false
            }
            SequentialAnimation {
              id: flashAnim
              NumberAnimation { target: flashBox; property: "opacity"; from: 0; to: 1; duration: 160 }
              PauseAnimation { duration: 950 }
              NumberAnimation { target: flashBox; property: "opacity"; to: 0; duration: 650 }
            }

            // Barra de scroll fina
            Rectangle {
              parent: flick
              z: 60
              visible: flick.contentHeight > flick.height + 1
              width: 4
              radius: Theme.cozy ? 0 : 2
              x: flick.width - width - 4
              height: Math.max(28, flick.height * flick.height / Math.max(1, flick.contentHeight))
              y: (flick.contentHeight - flick.height) > 0
                 ? (flick.height - height) * (flick.contentY / (flick.contentHeight - flick.height))
                 : 0
              color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, (flick.moving || flick.flicking) ? 0.75 : 0.30)
              Behavior on color { ColorAnimation { duration: 200 } }
            }

            ColumnLayout {
              id: detailCol
              // Márgenes y ancho máximo
              width: Math.min(flick.width - 44, 760)
              x: Math.max(22, Math.round((flick.width - width) / 2))
              y: 22
              spacing: 1

              // ── Resultados de búsqueda ──
              ColumnLayout {
                id: resultsBlock
                Layout.fillWidth: true
                visible: root.searching
                spacing: 8

                RowLayout {
                  Layout.fillWidth: true
                  Layout.bottomMargin: 4
                  spacing: 12

                  SkinRect {
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    radius: 11
                    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16)
                    Text {
                      anchors.centerIn: parent
                      text: "󰍉"
                      color: Theme.primary
                      font.pixelSize: Theme.fs(17)
                      font.family: Theme.monoFamily
                    }
                  }
                  Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: Translations.t("advSearchResults") + (root.searchResults.length > 0 ? "  ·  " + root.searchResults.length : "")
                    color: Theme.text
                    font.bold: true
                    font.pixelSize: Theme.fs(19)
                    font.family: Theme.fontFamily
                  }
                }

                // Sin resultados
                ColumnLayout {
                  visible: root.searchResults.length === 0
                  Layout.fillWidth: true
                  Layout.topMargin: 6
                  spacing: 4
                  Text {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: Translations.t("advNoResults")
                    color: Theme.text
                    font.bold: true
                    font.pixelSize: Theme.fs(12)
                    font.family: Theme.fontFamily
                  }
                  Text {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: Translations.t("advSearchTryHint")
                    color: Theme.subtext
                    font.pixelSize: Theme.fs(11)
                    font.family: Theme.fontFamily
                  }
                }

                Repeater {
                  model: root.searchResults

                  delegate: SkinRect {
                    id: resRow
                    required property var modelData
                    readonly property string label: root.entryLabel(resRow.modelData)
                    readonly property string hint: root.entryHint(resRow.modelData)
                    readonly property string secName: resRow.modelData.sec !== ""
                      ? Translations.t(resRow.modelData.sec) : ""
                    readonly property string crumb: Translations.t(root.catKeyOf(resRow.modelData.cat))
                      + ((resRow.secName !== "" && resRow.secName !== resRow.label) ? "   ›   " + resRow.secName : "")

                    Layout.fillWidth: true
                    implicitHeight: resLay.implicitHeight + 24
                    radius: Theme.cardRadius
                    color: resArea.containsMouse ? Theme.surfaceHigh : Theme.surface
                    border.width: Theme.bw1
                    border.color: resArea.containsMouse
                      ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.45)
                      : Theme.divider
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    RowLayout {
                      id: resLay
                      anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 14; rightMargin: 14 }
                      spacing: 12

                      SkinRect {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        Layout.alignment: Qt.AlignTop
                        radius: 10
                        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.14)
                        Text {
                          anchors.centerIn: parent
                          text: root.catIconOf(resRow.modelData.cat)
                          color: Theme.primary
                          font.pixelSize: Theme.fs(15)
                          font.family: Theme.fontFamily
                        }
                      }

                      ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                          Layout.fillWidth: true
                          textFormat: Text.RichText
                          elide: Text.ElideRight
                          text: root.hl(resRow.label, root.query)
                          color: Theme.text
                          font.bold: true
                          font.pixelSize: Theme.fs(12)
                          font.family: Theme.fontFamily
                        }
                        Text {
                          Layout.fillWidth: true
                          elide: Text.ElideRight
                          text: resRow.crumb
                          color: Theme.primary
                          font.pixelSize: Theme.fs(10)
                          font.family: Theme.fontFamily
                        }
                        Text {
                          visible: resRow.hint !== ""
                          Layout.fillWidth: true
                          Layout.topMargin: 2
                          wrapMode: Text.WordWrap
                          maximumLineCount: 2
                          elide: Text.ElideRight
                          textFormat: Text.RichText
                          text: root.hl(resRow.hint, root.query)
                          color: Theme.subtext
                          font.pixelSize: Theme.fs(10)
                          font.family: Theme.fontFamily
                        }
                      }

                      Text {
                        Layout.alignment: Qt.AlignVCenter
                        text: "󰅂"
                        color: resArea.containsMouse ? Theme.primary : Theme.subtext
                        font.pixelSize: Theme.fs(15)
                        font.family: Theme.monoFamily
                        Behavior on color { ColorAnimation { duration: 120 } }
                      }
                    }

                    MouseArea {
                      id: resArea
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.goToEntry(resRow.modelData)
                    }
                  }
                }
              }

              // ── Páginas migradas (pages/): solo existe la de la categoría elegida ──
              Loader {
                id: pageLoader
                Layout.fillWidth: true
                // Sin página no ocupa espacio (un Loader vacío conserva el alto anterior)
                visible: pageLoader.active
                Layout.preferredHeight: pageLoader.item ? pageLoader.item.implicitHeight : 0
                // `card.visible` mantiene la página viva durante el fade-out
                active: !root.searching && root.pageOf(root.category) !== "" && (root.open || card.visible)
                source: root.pageOf(root.category)
                onLoaded: {
                  // Contrato marco → página (ver SettingsPage.qml)
                  pageLoader.item.host = root
                  pageLoader.item.active = Qt.binding(() => root.open)
                  // Si venimos de una búsqueda, scrollea ahora que la página existe
                  if (root.pendingAnchor !== "") anchorTimer.restart()
                }
              }


              // ── Apariencia · Paleta ──
              ColumnLayout {
                Layout.fillWidth: true
                visible: !root.searching && root.category === "appearance"
                spacing: 12

                SettingsPanelTitle { icon: root.catIconByKey("advCatAppearance"); title: Translations.t("advCatAppearance") }

                SkinRect {
                  Layout.fillWidth: true
                  implicitHeight: paletteCol.implicitHeight + 28
                  radius: Theme.cardRadius
                  color: Theme.surface
                  border.width: Theme.bw1
                  border.color: Theme.edge
                  clip: true

                  ColumnLayout {
                    id: paletteCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
                    spacing: 10

                    SectionLabel { text: Translations.t("advPaletteTitle") }

                    // ── Automático ⇄ Paletas ──
                    SkinRect {
                      id: modeSlider
                      Layout.fillWidth: true
                      Layout.preferredHeight: 36
                      radius: 18
                      color: Theme.bg
                      border.width: Theme.bw1
                      border.color: Theme.edge

                      readonly property bool manual: Theme.paletteMode
                      readonly property real half: (width - 4) / 2

                      SkinRect {
                        x: modeSlider.manual ? modeSlider.half + 2 : 2
                        y: 2
                        width: modeSlider.half
                        height: parent.height - 4
                        radius: 16
                        color: Theme.primary
                        Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                      }

                      RowLayout {
                        anchors.fill: parent
                        spacing: 0

                        Repeater {
                          model: [
                            { key: "advPaletteModeAuto",   value: false },
                            { key: "advPaletteModeManual", value: true  }
                          ]

                          delegate: Item {
                            id: seg
                            required property var modelData
                            readonly property bool active: seg.modelData.value === modeSlider.manual

                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            Text {
                              anchors.centerIn: parent
                              text: Translations.t(seg.modelData.key)
                              color: seg.active ? Theme.textOnPrimary : Theme.subtext
                              font.bold: seg.active
                              font.pixelSize: Theme.fs(11)
                              font.family: Theme.fontFamily
                              Behavior on color { ColorAnimation { duration: 150 } }
                            }

                            MouseArea {
                              anchors.fill: parent
                              cursorShape: Qt.PointingHandCursor
                              onClicked: Theme.setPaletteMode(seg.modelData.value)
                            }
                          }
                        }
                      }
                    }

                    Text {
                      Layout.fillWidth: true
                      visible: Theme.paletteMode
                      text: Translations.t("advPaletteManualHint")
                      wrapMode: Text.WordWrap
                      color: Theme.subtext
                      font.pixelSize: Theme.fs(11)
                      font.family: Theme.fontFamily
                    }

                    // ── Estilo de interfaz (solo Automático) ──
                    SectionLabel { visible: !Theme.paletteMode; text: Translations.t("advStyleTitle") }

                    RowLayout {
                      Layout.fillWidth: true
                      visible: !Theme.paletteMode
                      spacing: 10

                      Repeater {
                        model: [
                          { id: "soft", nameKey: "advStyleSoft", hintKey: "advStyleSoftHint" },
                          { id: "cozy", nameKey: "advStyleCozy", hintKey: "advStyleCozyHint" }
                        ]

                        delegate: SkinRect {
                          id: scard
                          required property var modelData
                          readonly property bool active: Theme.uiStyle === scard.modelData.id
                          readonly property bool isCozy: scard.modelData.id === "cozy"

                          Layout.fillWidth: true
                          Layout.preferredWidth: 1
                          implicitHeight: scol.implicitHeight + 24
                          radius: scard.isCozy ? 4 : 12
                          color: scardArea.containsMouse ? Theme.surfaceHigh : Theme.bg
                          inkColor: scard.active ? Theme.primary : Theme.ink
                          border.width: scard.active ? 2 : (scard.isCozy ? 2 : 1)
                          border.color: scard.active ? Theme.primary : (scard.isCozy ? Theme.ink : Theme.divider)
                          Behavior on color { ColorAnimation { duration: 150 } }

                          ColumnLayout {
                            id: scol
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                            spacing: 8

                            // Mini maqueta (usa SU estilo, no el activo)
                            Rectangle {
                              Layout.fillWidth: true
                              Layout.preferredHeight: 54
                              radius: scard.isCozy ? 4 : 10
                              color: Theme.surface
                              border.width: scard.isCozy ? 2 : 1
                              border.color: scard.isCozy ? Theme.ink : Theme.divider
                              clip: true

                              Rectangle {           // barra
                                anchors { left: parent.left; right: parent.right; top: parent.top
                                          margins: scard.isCozy ? 2 : 1 }
                                height: 12
                                radius: scard.isCozy ? 2 : 8
                                color: Theme.bg
                                border.width: scard.isCozy ? 2 : 0
                                border.color: Theme.ink
                              }
                              Rectangle {           // tarjeta
                                x: 8; y: 22; width: parent.width * 0.5; height: 22
                                radius: scard.isCozy ? 2 : 7
                                color: Theme.surfaceHigh
                                border.width: scard.isCozy ? 2 : 1
                                border.color: scard.isCozy ? Theme.ink : Theme.divider
                              }
                              Rectangle {           // botón
                                x: parent.width * 0.5 + 16; y: 26
                                width: parent.width * 0.5 - 30; height: 14
                                radius: scard.isCozy ? 4 : 7
                                color: Theme.primary
                                border.width: scard.isCozy ? 2 : 0
                                border.color: Theme.ink
                              }
                            }

                            RowLayout {
                              Layout.fillWidth: true
                              spacing: 6
                              Text {
                                Layout.fillWidth: true
                                text: Translations.t(scard.modelData.nameKey)
                                color: Theme.text
                                font.bold: true
                                font.pixelSize: Theme.fs(12)
                                font.family: scard.isCozy ? Theme.cozyFamily : Theme.monoFamily
                                elide: Text.ElideRight
                              }
                              Text {
                                visible: scard.active
                                text: "󰄬"
                                color: Theme.primary
                                font.pixelSize: Theme.fs(14)
                                font.family: Theme.monoFamily
                              }
                            }
                            Text {
                              Layout.fillWidth: true
                              text: Translations.t(scard.modelData.hintKey)
                              wrapMode: Text.WordWrap
                              color: Theme.subtext
                              font.pixelSize: Theme.fs(10)
                              font.family: scard.isCozy ? Theme.cozyFamily : Theme.monoFamily
                            }
                          }

                          MouseArea {
                            id: scardArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Theme.setUiStyle(scard.modelData.id)
                          }
                        }
                      }
                    }

                    SectionLabel { visible: !Theme.paletteMode; text: Translations.t("advMatugenTitle") }

                    Text {
                      Layout.fillWidth: true
                      visible: !Theme.paletteMode
                      text: Translations.t("advPaletteHint")
                      wrapMode: Text.WordWrap
                      color: Theme.subtext
                      font.pixelSize: Theme.fs(11)
                      font.family: Theme.fontFamily
                    }

                    // ── Automático: esquemas de matugen (de siempre) ──
                    Flow {
                      Layout.fillWidth: true
                      spacing: 8
                      visible: !Theme.paletteMode

                      Repeater {
                        model: Theme.schemes
                        delegate: SkinRect {
                          id: chip
                          required property var modelData
                          required property int index
                          readonly property bool active: index === Theme.defaultSchemeIndex

                          implicitWidth: chipLabel.implicitWidth + 24
                          implicitHeight: 32
                          radius: 16
                          color: chip.active ? Theme.primary
                               : (chipArea.containsMouse ? Theme.surfaceHigh : Theme.bg)
                          border.width: chip.active ? 0 : Theme.bw1
                          border.color: Theme.edge
                          Behavior on color { ColorAnimation { duration: 150 } }

                          Text {
                            id: chipLabel
                            anchors.centerIn: parent
                            text: chip.modelData.label
                            color: chip.active ? Theme.textOnPrimary : Theme.text
                            font.pixelSize: Theme.fs(11)
                            font.bold: chip.active
                            font.family: Theme.fontFamily
                          }

                          MouseArea {
                            id: chipArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Theme.setDefaultSchemeIndex(chip.index)
                          }
                        }
                      }
                    }

                    // ── Paletas: 6 paletas fijas (con muestra de color) ──
                    Flow {
                      Layout.fillWidth: true
                      spacing: 8
                      visible: Theme.paletteMode

                      Repeater {
                        model: Theme.manualPalettes
                        delegate: SkinRect {
                          id: pchip
                          required property var modelData
                          required property int index
                          readonly property bool active: index === Theme.manualPaletteIndex

                          implicitWidth: pchipRow.implicitWidth + 22
                          implicitHeight: 32
                          radius: 16
                          color: pchip.active ? Theme.primary
                               : (pchipArea.containsMouse ? Theme.surfaceHigh : Theme.bg)
                          border.width: pchip.active ? 0 : Theme.bw1
                          border.color: Theme.edge
                          Behavior on color { ColorAnimation { duration: 150 } }

                          RowLayout {
                            id: pchipRow
                            anchors.centerIn: parent
                            spacing: 6

                            SkinRect {
                              Layout.preferredWidth: 14
                              Layout.preferredHeight: 14
                              radius: 7
                              color: pchip.modelData.primary
                              border.width: Theme.bw1
                              border.color: pchip.active ? Theme.textOnPrimary : Theme.edge
                            }

                            Text {
                              text: pchip.modelData.label
                              color: pchip.active ? Theme.textOnPrimary : Theme.text
                              font.pixelSize: Theme.fs(11)
                              font.bold: pchip.active
                              font.family: Theme.fontFamily
                            }
                          }

                          MouseArea {
                            id: pchipArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Theme.setManualPaletteIndex(pchip.index)
                          }
                        }
                      }
                    }
                  }
                }

                // ── Hyprland: gaps, bordes, blur, sombra ──
                SkinRect {
                  Layout.fillWidth: true
                  implicitHeight: hyprCol.implicitHeight + 28
                  radius: Theme.cardRadius
                  color: Theme.surface
                  border.width: Theme.bw1
                  border.color: Theme.edge
                  clip: true

                  ColumnLayout {
                    id: hyprCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
                    spacing: 14

                    SectionLabel { text: Translations.t("advHyprTitle") }

                    Text {
                      Layout.fillWidth: true
                      text: Translations.t("advHyprHint")
                      wrapMode: Text.WordWrap
                      color: Theme.subtext
                      font.pixelSize: Theme.fs(11)
                      font.family: Theme.fontFamily
                    }

                    GridLayout {
                      Layout.fillWidth: true
                      columns: 2
                      columnSpacing: 18
                      rowSpacing: 10

                      Repeater {
                        model: root.hyprSliderSpecs

                        delegate: AppearanceSlider {
                          Layout.fillWidth: true
                          Layout.preferredWidth: 1
                          Layout.preferredHeight: 44
                          // Sin efecto mientras la sombra está apagada: se atenúan
                          opacity: (modelData.key.indexOf("shadow") === 0
                                    && !(root.appearanceValues.shadowEnabled ?? false)) ? 0.45 : 1
                          Behavior on opacity { NumberAnimation { duration: 150 } }

                          label: modelData.label
                          keyName: modelData.key
                          minValue: modelData.min
                          maxValue: modelData.max
                          stepValue: modelData.step
                          decimals: modelData.dec
                          value: root.appearanceValues[modelData.key] ?? modelData.def
                          colors: root.hyprSliderColors

                          onPreviewChanged: (k, v) => root.appearancePreviewChanged(k, v)
                          onCommitted: (k, v) => root.appearanceValueCommitted(k, v)
                        }
                      }
                    }

                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }

                    RowLayout {
                      Layout.fillWidth: true
                      spacing: 12

                      Repeater {
                        model: root.hyprToggles

                        delegate: Item {
                          id: tog
                          readonly property bool on: root.appearanceValues[modelData.key] ?? modelData.def

                          Layout.fillWidth: true
                          Layout.preferredWidth: 1
                          Layout.preferredHeight: 26

                          RowLayout {
                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                            spacing: 8

                            SkinRect {
                              Layout.preferredWidth: 34
                              Layout.preferredHeight: 20
                              radius: 10
                              color: tog.on ? Theme.primary : Theme.surfaceHigh
                              Behavior on color { ColorAnimation { duration: 150 } }

                              SkinRect {
                                width: 14
                                height: 14
                                radius: 7
                                anchors.verticalCenter: parent.verticalCenter
                                x: tog.on ? 17 : 3
                                color: tog.on ? Theme.textOnPrimary : Theme.subtext
                                Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                Behavior on color { ColorAnimation { duration: 150 } }
                              }
                            }

                            Text {
                              Layout.fillWidth: true
                              text: modelData.label
                              color: Theme.text
                              font.pixelSize: Theme.fs(11)
                              font.family: Theme.fontFamily
                              elide: Text.ElideRight
                            }
                          }

                          MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.appearanceToggleChanged(modelData.key, !tog.on)
                          }
                        }
                      }
                    }
                  }
                }

                // ── Tema claro/oscuro ──
                SkinRect {
                  Layout.fillWidth: true
                  implicitHeight: themeCol.implicitHeight + 30
                  radius: Theme.cardRadius
                  color: Theme.surface
                  border.width: Theme.bw1
                  border.color: Theme.edge
                  clip: true

                  ColumnLayout {
                    id: themeCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                    spacing: 10

                    SectionLabel { text: Translations.t("themeSection") }

                    RowLayout {
                      Layout.fillWidth: true
                      spacing: 10

                      Text {
                        Layout.preferredWidth: Math.min(implicitWidth, 140)
                        Layout.maximumWidth: 140
                        elide: Text.ElideRight
                        text: Translations.t("themeLightMode")
                        color: Theme.text
                        font.bold: true
                        font.pixelSize: Theme.fs(12)
                        font.family: Theme.fontFamily
                      }
                      SettingsBtn {
                        icon: Theme.lightMode ? "󰖨" : "󰖔"
                        text: Theme.lightMode ? "ON" : "OFF"
                        primary: Theme.lightMode
                        onClicked: Theme.setLightMode(!Theme.lightMode)
                      }
                      Text {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: Translations.t(Theme.lightMode ? "themeLightJokeOn" : "themeLightJokeOff")
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        color: Theme.subtext
                        font.italic: true
                        font.pixelSize: Theme.fs(11)
                        font.family: Theme.fontFamily
                      }
                    }

                    Text {
                      Layout.fillWidth: true
                      text: Translations.t("themeLightHint")
                      wrapMode: Text.WordWrap
                      color: Theme.subtext
                      font.pixelSize: Theme.fs(10)
                      font.family: Theme.fontFamily
                    }
                  }
                }
              }

              // ── Interfaz · tamaño, Dock, Barra, marco de pantalla ──
              Loader {
                id: catLoader_interface
                Layout.fillWidth: true
                // Solo existe la categoría elegida (antes las 6 inline se creaban de golpe
                // y solo se ocultaban con `visible`); `card.visible` la mantiene viva en el fade-out.
                active: !root.searching && root.category === "interface" && (root.open || card.visible)
                visible: active
                Layout.preferredHeight: item ? item.implicitHeight : 0
                onLoaded: { if (root.pendingAnchor !== "") anchorTimer.restart() }
                sourceComponent: Component {
                  ColumnLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                spacing: 12

                SettingsPanelTitle { icon: root.catIconByKey("advCatInterface"); title: Translations.t("advCatInterface") }

                // ── Tamaño de la interfaz ──
                SkinRect {
                  Layout.fillWidth: true
                  implicitHeight: sizeCol.implicitHeight + 30
                  radius: Theme.cardRadius
                  color: Theme.surface
                  border.width: Theme.bw1
                  border.color: Theme.edge
                  clip: true

                  ColumnLayout {
                    id: sizeCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                    spacing: 12

                    RowLayout {
                      Layout.fillWidth: true
                      SectionLabel { text: Translations.t("uiSizeTitle") }
                      Item { Layout.fillWidth: true }
                      Text {
                        visible: root.masterLevel < 0
                        text: Translations.t("uiCustom")
                        color: Theme.primary
                        font.pixelSize: Theme.fs(11)
                        font.family: Theme.fontFamily
                      }
                    }

                    Text {
                      Layout.fillWidth: true
                      text: Translations.t("uiSizeHint")
                      wrapMode: Text.WordWrap
                      color: Theme.subtext
                      font.pixelSize: Theme.fs(10)
                      font.family: Theme.fontFamily
                    }

                    LevelPicker {
                      level: root.masterLevel
                      names: root.levelNames
                      showNames: true
                      onPicked: index => Theme.setInterfaceLevel(index)
                    }

                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }

                    SectionLabel { text: "Animaciones de OozeShell" }
                    Text {
                      Layout.fillWidth: true
                      text: "Controla las transiciones de la interfaz del shell. Es independiente de las animaciones de ventanas de Hyprland."
                      wrapMode: Text.WordWrap
                      color: Theme.subtext
                      font.pixelSize: Theme.fs(10)
                      font.family: Theme.fontFamily
                    }
                    RowLayout {
                      Layout.fillWidth: true
                      spacing: 8
                      SettingsBtn {
                        Layout.fillWidth: true
                        text: "Normal"
                        primary: Theme.uiAnimationMode === "normal"
                        onClicked: Theme.setUiAnimationMode("normal")
                      }
                      SettingsBtn {
                        Layout.fillWidth: true
                        text: "Mínimas"
                        primary: Theme.uiAnimationMode === "minimal"
                        onClicked: Theme.setUiAnimationMode("minimal")
                      }
                      SettingsBtn {
                        Layout.fillWidth: true
                        text: "Desactivadas"
                        primary: Theme.uiAnimationMode === "off"
                        onClicked: Theme.setUiAnimationMode("off")
                      }
                    }

                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }

                    SectionLabel { text: Translations.t("uiFineTune") }

                    // ── Tamaño de fuente manual (%) ──
                    ColumnLayout {
                      Layout.fillWidth: true
                      spacing: 6

                      RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Text {
                          Layout.fillWidth: true
                          text: Translations.t("uiFontManual")
                          color: Theme.text
                          font.bold: true
                          font.pixelSize: Theme.fs(12)
                          font.family: Theme.fontFamily
                          elide: Text.ElideRight
                        }
                        Text {
                          visible: Theme.fontCustom
                          text: Translations.t("uiCustom")
                          color: Theme.primary
                          font.pixelSize: Theme.fs(11)
                          font.family: Theme.fontFamily
                        }
                      }

                      RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        NumberStepper {
                          Layout.preferredWidth: 150
                          value: Theme.fontPercentEffective
                          min: Theme.fontPercentMin
                          max: Theme.fontPercentMax
                          step: 5
                          suffix: "%"
                          onEdited: v => Theme.setFontPercent(v)
                        }

                        Text {
                          Layout.fillWidth: true
                          text: Translations.t("uiFontExample") + ": 13 px → " + Theme.fs(13) + " px"
                          color: Theme.subtext
                          font.pixelSize: Theme.fs(10)
                          font.family: Theme.fontFamily
                          elide: Text.ElideRight
                        }

                        SkinRect {
                          visible: Theme.fontCustom
                          Layout.preferredWidth: fontResetLbl.implicitWidth + 20
                          Layout.preferredHeight: 30
                          radius: 9
                          color: fontResetArea.containsMouse ? Theme.surfaceHigh : Theme.surface
                          Text {
                            id: fontResetLbl
                            anchors.centerIn: parent
                            text: "󰑙  " + Translations.t("uiFontReset")
                            color: Theme.text
                            font.pixelSize: Theme.fs(10)
                            font.family: Theme.monoFamily
                          }
                          MouseArea {
                            id: fontResetArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Theme.setFontPercent(0)
                          }
                        }
                      }

                      Text {
                        Layout.fillWidth: true
                        text: Translations.t("uiFontManualHint")
                        wrapMode: Text.WordWrap
                        color: Theme.subtext
                        font.pixelSize: Theme.fs(10)
                        font.family: Theme.fontFamily
                      }
                    }

                    Repeater {
                      model: [
                        { kind: "font",   label: "uiFont" },
                        { kind: "bar",    label: "uiBar" },
                        { kind: "window", label: "uiWindows" }
                      ]

                      delegate: RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        ColumnLayout {
                          Layout.preferredWidth: 100
                          Layout.maximumWidth: 140
                          spacing: 0
                          Text {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: Translations.t(modelData.label)
                            color: Theme.text
                            font.bold: true
                            font.pixelSize: Theme.fs(12)
                            font.family: Theme.fontFamily
                          }
                          Text {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: (modelData.kind === "font" && Theme.fontCustom) ? (Theme.fontPercent + "%") : (root.levelNames[root.levelOf(modelData.kind)] ?? "")
                            color: Theme.subtext
                            font.pixelSize: Theme.fs(10)
                            font.family: Theme.fontFamily
                          }
                        }

                        LevelPicker {
                          level: (modelData.kind === "font" && Theme.fontCustom) ? -1 : root.levelOf(modelData.kind)
                          names: root.levelNames
                          showNames: false
                          onPicked: index => Theme.setLevel(modelData.kind, index)
                        }
                      }
                    }

                    Text {
                      Layout.fillWidth: true
                      text: Translations.t("uiFineHint")
                      wrapMode: Text.WordWrap
                      color: Theme.subtext
                      font.pixelSize: Theme.fs(10)
                      font.family: Theme.fontFamily
                    }

                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }

                    RowLayout {
                      Layout.fillWidth: true
                      Item { Layout.fillWidth: true }
                      SettingsBtn {
                        text: Translations.t("uiReset")
                        onClicked: Theme.resetLevels()
                      }
                    }
                  }
                }

                // ── Dock ──
                SkinRect {
                  Layout.fillWidth: true
                  implicitHeight: dockCol.implicitHeight + 30
                  radius: Theme.cardRadius
                  color: Theme.surface
                  border.width: Theme.bw1
                  border.color: Theme.edge
                  clip: true

                  ColumnLayout {
                    id: dockCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                    spacing: 10

                    SectionLabel { text: Translations.t("dockSection") }

                    Text {
                      Layout.fillWidth: true
                      visible: Theme.frameBorderActive
                      wrapMode: Text.WordWrap
                      text: Translations.t("dockFrameBlocked")
                      color: Theme.primary
                      font.pixelSize: Theme.fs(11)
                      font.family: Theme.fontFamily
                    }

                    RowLayout {
                      Layout.fillWidth: true
                      spacing: 10

                      Text {
                        Layout.preferredWidth: Math.min(implicitWidth, 100)
                        Layout.maximumWidth: 100
                        elide: Text.ElideRight
                        text: Translations.t("dockEnable")
                        color: Theme.text
                        font.bold: true
                        font.pixelSize: Theme.fs(12)
                        font.family: Theme.fontFamily
                      }
                      SettingsBtn {
                        icon: Theme.dockEnabled ? "󰇙" : "󰇘"
                        text: Theme.dockEnabled ? "ON" : "OFF"
                        primary: Theme.dockEnabled
                        onClicked: Theme.setDockEnabled(!Theme.dockEnabled)
                      }

                      Text {
                        Layout.preferredWidth: Math.min(implicitWidth, 100)
                        Layout.maximumWidth: 100
                        elide: Text.ElideRight
                        text: Translations.t("dockAutoHide")
                        color: Theme.text
                        font.bold: true
                        font.pixelSize: Theme.fs(12)
                        font.family: Theme.fontFamily
                      }
                      SettingsBtn {
                        icon: Theme.dockAutoHide ? "▣" : "▢"
                        text: Theme.dockAutoHide ? "ON" : "OFF"
                        primary: Theme.dockAutoHide
                        onClicked: Theme.setDockAutoHide(!Theme.dockAutoHide)
                      }
                      Item { Layout.fillWidth: true }
                    }

                    RowLayout {
                      Layout.fillWidth: true
                      spacing: 10
                      opacity: Theme.barVertical ? 1.0 : 0.4

                      Text {
                        Layout.preferredWidth: Math.min(implicitWidth, 140)
                        Layout.maximumWidth: 140
                        elide: Text.ElideRight
                        text: Translations.t("dockPosition")
                        color: Theme.text
                        font.bold: true
                        font.pixelSize: Theme.fs(12)
                        font.family: Theme.fontFamily
                      }
                      SettingsBtn {
                        icon: "▀"
                        text: Translations.t("barTop")
                        primary: Theme.dockPosition === "top"
                        onClicked: { if (Theme.barVertical) Theme.setDockPosition("top") }
                      }
                      SettingsBtn {
                        icon: "▄"
                        text: Translations.t("barBottom")
                        primary: Theme.dockPosition === "bottom"
                        onClicked: { if (Theme.barVertical) Theme.setDockPosition("bottom") }
                      }
                      Item { Layout.fillWidth: true }
                    }

                    // Tamaño propio del Dock (bloqueado si el Dock no está activo)
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }
                    SectionLabel { text: Translations.t("dockSize") }
                    ScaleSlider {
                      value: Theme.dockScalePercent
                      min: Theme.ownScaleMin
                      max: Theme.ownScaleMax
                      step: 5
                      defaultValue: Theme.dockScaleDefault
                      enabled: Theme.dockUsable
                      onEdited: v => Theme.setDockScalePercent(v)
                    }
                    Text {
                      Layout.fillWidth: true
                      text: Translations.t("dockSizeHint")
                      wrapMode: Text.WordWrap
                      color: Theme.subtext
                      font.pixelSize: Theme.fs(10)
                      font.family: Theme.fontFamily
                    }
                  }
                }

                // ── Barra: se configura acá mismo ──
                SkinRect {
                  Layout.fillWidth: true
                  implicitHeight: barCol.implicitHeight + 30
                  radius: Theme.cardRadius
                  color: Theme.surface
                  border.width: Theme.bw1
                  border.color: Theme.edge
                  clip: true

                  ColumnLayout {
                    id: barCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                    spacing: 10

                    SectionLabel { text: Translations.t("barSection") }
                    Text {
                      Layout.fillWidth: true
                      text: Translations.t("barSectionHint")
                      wrapMode: Text.WordWrap
                      color: Theme.subtext
                      font.pixelSize: Theme.fs(10)
                      font.family: Theme.fontFamily
                    }

                    SectionLabel { text: Translations.t("barPosition") }
                    Flow {
                      Layout.fillWidth: true
                      spacing: 8
                      Repeater {
                        model: [
                          { pos: "top",    icon: "▀", label: "barTop" },
                          { pos: "bottom", icon: "▄", label: "barBottom" },
                          { pos: "left",   icon: "▌", label: "barLeft" },
                          { pos: "right",  icon: "▐", label: "barRight" }
                        ]
                        delegate: SettingsBtn {
                          required property var modelData
                          icon: modelData.icon
                          text: Translations.t(modelData.label)
                          primary: Theme.barPosition === modelData.pos
                          onClicked: Theme.setBarPosition(modelData.pos)
                        }
                      }
                    }

                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }

                    SectionLabel { text: Translations.t("barFloating") }
                    RowLayout {
                      Layout.fillWidth: true
                      spacing: 10
                      SettingsBtn {
                        icon: Theme.barFloatingPref ? "▣" : "▢"
                        text: Theme.barFloatingPref ? "ON" : "OFF"
                        primary: Theme.barFloatingPref
                        opacity: Theme.barVertical ? 0.4 : 1.0
                        onClicked: { if (!Theme.barVertical) Theme.setBarFloating(!Theme.barFloatingPref) }
                      }
                      Item { Layout.fillWidth: true }
                    }
                    Text {
                      Layout.fillWidth: true
                      text: Theme.barVertical ? Translations.t("barFloatingOnlyH") : Translations.t("barFloatingHint")
                      wrapMode: Text.WordWrap
                      color: Theme.subtext
                      font.pixelSize: Theme.fs(10)
                      font.family: Theme.fontFamily
                    }

                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }

                    SectionLabel { text: Translations.t("barIslands") }
                    RowLayout {
                      Layout.fillWidth: true
                      spacing: 10
                      SettingsBtn {
                        icon: Theme.islandsPref ? "◖◗" : "▬"
                        text: Theme.islandsPref ? "ON" : "OFF"
                        primary: Theme.islandsPref
                        opacity: Theme.barVertical ? 0.4 : 1.0
                        onClicked: { if (!Theme.barVertical) Theme.setIslandsEnabled(!Theme.islandsPref) }
                      }
                      Item { Layout.fillWidth: true }
                    }
                    Text {
                      Layout.fillWidth: true
                      text: Theme.barVertical ? Translations.t("barIslandsOnlyH") : Translations.t("barIslandsHint")
                      wrapMode: Text.WordWrap
                      color: Theme.subtext
                      font.pixelSize: Theme.fs(10)
                      font.family: Theme.fontFamily
                    }

                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }

                    // ── Píldora (excluyente con Islas, solo barra horizontal) ──
                    SectionLabel { text: Translations.t("barPillMode") }
                    RowLayout {
                      Layout.fillWidth: true
                      spacing: 10
                      SettingsBtn {
                        icon: Theme.pillModePref ? "󰧞" : "▬"
                        text: Theme.pillModePref ? "ON" : "OFF"
                        primary: Theme.pillModePref
                        opacity: Theme.barVertical ? 0.4 : 1.0
                        onClicked: { if (!Theme.barVertical) Theme.setPillModeEnabled(!Theme.pillModePref) }
                      }
                      Item { Layout.fillWidth: true }
                    }
                    Text {
                      Layout.fillWidth: true
                      text: Theme.barVertical ? Translations.t("barIslandsOnlyH") : Translations.t("barPillModeHint")
                      wrapMode: Text.WordWrap
                      color: Theme.subtext
                      font.pixelSize: Theme.fs(10)
                      font.family: Theme.fontFamily
                    }

                    // Auto-ocultar (independiente del Dashboard)
                    RowLayout {
                      Layout.fillWidth: true
                      spacing: 10
                      visible: Theme.pillMode
                      Text {
                        text: Translations.t("barPillAutoHide")
                        color: Theme.text
                        font.pixelSize: Theme.fs(12)
                        font.family: Theme.fontFamily
                      }
                      Item { Layout.fillWidth: true }
                      SettingsBtn {
                        icon: Theme.pillAutoHidePref ? "󰈈" : "󰈉"
                        text: Theme.pillAutoHidePref ? "ON" : "OFF"
                        primary: Theme.pillAutoHidePref
                        onClicked: Theme.setPillAutoHide(!Theme.pillAutoHidePref)
                      }
                    }

                    // Sincronizar: las píldoras se esconden y aparecen juntas
                    RowLayout {
                      Layout.fillWidth: true
                      spacing: 10
                      visible: Theme.pillMode && Theme.pillAutoHidePref
                      Text {
                        text: Translations.t("barPillTraySync")
                        color: Theme.text
                        font.pixelSize: Theme.fs(12)
                        font.family: Theme.fontFamily
                      }
                      Item { Layout.fillWidth: true }
                      SettingsBtn {
                        icon: Theme.pillTraySyncPref ? "󰌷" : "󰌸"
                        text: Theme.pillTraySyncPref ? "ON" : "OFF"
                        primary: Theme.pillTraySyncPref
                        onClicked: Theme.setPillTraySync(!Theme.pillTraySyncPref)
                      }
                    }

                    // Tamaño propio de las píldoras (bloqueado sin Modo Píldora)
                    SectionLabel { text: Translations.t("pillSize") }
                    ScaleSlider {
                      value: Theme.pillScalePercent
                      min: Theme.ownScaleMin
                      max: Theme.ownScaleMax
                      step: 5
                      defaultValue: Theme.pillScaleDefault
                      enabled: Theme.pillMode
                      onEdited: v => Theme.setPillScalePercent(v)
                    }
                    Text {
                      Layout.fillWidth: true
                      text: Translations.t("pillSizeHint")
                      wrapMode: Text.WordWrap
                      color: Theme.subtext
                      font.pixelSize: Theme.fs(10)
                      font.family: Theme.fontFamily
                    }

                    // Tamaño del Dashboard, 5 niveles (bloqueado sin Modo Píldora)
                    SectionLabel { text: Translations.t("dashSize") }
                    LevelPicker {
                      level: Theme.dashboardLevel
                      names: ["1", "2", "3", "4", "5"]
                      showNames: true
                      enabled: Theme.pillMode
                      opacity: Theme.pillMode ? 1.0 : 0.4
                      onPicked: index => Theme.setDashboardLevel(index)
                    }
                    Text {
                      Layout.fillWidth: true
                      text: Translations.t("dashSizeHint")
                      wrapMode: Text.WordWrap
                      color: Theme.subtext
                      font.pixelSize: Theme.fs(10)
                      font.family: Theme.fontFamily
                    }

                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }

                    SectionLabel { text: Translations.t("batterySection") }
                    RowLayout {
                      Layout.fillWidth: true
                      spacing: 10
                      SettingsBtn {
                        icon: Theme.batteryEnabled ? "󰂄" : "󰂎"
                        text: Theme.batteryEnabled ? "ON" : "OFF"
                        primary: Theme.batteryEnabled
                        onClicked: Theme.setBatteryEnabled(!Theme.batteryEnabled)
                      }
                      Item { Layout.fillWidth: true }
                    }
                    Text {
                      Layout.fillWidth: true
                      text: Translations.t("batteryHint")
                      wrapMode: Text.WordWrap
                      color: Theme.subtext
                      font.pixelSize: Theme.fs(10)
                      font.family: Theme.fontFamily
                    }
                  }
                }

                SkinRect {
                  Layout.fillWidth: true
                  implicitHeight: panelWidthCol.implicitHeight + 30
                  radius: Theme.cardRadius
                  color: Theme.surface
                  border.width: Theme.bw1
                  border.color: Theme.edge
                  clip: true

                  ColumnLayout {
                    id: panelWidthCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                    spacing: 12

                    RowLayout {
                      Layout.fillWidth: true
                      spacing: 12

                      SkinRect {
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 36
                        radius: 11
                        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.14)
                        Text {
                          anchors.centerIn: parent
                          text: "󰊓"
                          color: Theme.primary
                          font.pixelSize: Theme.fs(16)
                          font.family: Theme.monoFamily
                        }
                      }

                      ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        SectionLabel { text: Translations.t("advPanelWidthTitle") }
                        Text {
                          Layout.fillWidth: true
                          text: Translations.t("advPanelWidthHint")
                          wrapMode: Text.WordWrap
                          color: Theme.subtext
                          font.pixelSize: Theme.fs(10)
                          font.family: Theme.fontFamily
                        }
                      }
                    }

                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }

                    RowLayout {
                      Layout.fillWidth: true
                      spacing: 12

                      NumberStepper {
                        Layout.preferredWidth: 150
                        value: Theme.panelWidthPercent
                        min: Theme.panelWidthMin
                        max: Theme.panelWidthMax
                        step: 5
                        suffix: "%"
                        onEdited: v => Theme.setPanelWidthPercent(v)
                      }

                      // ── Barra de progreso con marca en 100% ──
                      ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Item {
                          id: widthTrack
                          Layout.fillWidth: true
                          Layout.preferredHeight: Theme.cozy ? 14 : 6

                          PixelBar {
                            visible: Theme.cozy
                            anchors.fill: parent
                            ratio: (Theme.panelWidthPercent - Theme.panelWidthMin) /
                                   (Theme.panelWidthMax - Theme.panelWidthMin)
                          }
                          Rectangle {
                            visible: !Theme.cozy
                            anchors.fill: parent
                            radius: 3
                            color: Theme.surfaceHigh
                          }
                          Rectangle {
                            visible: !Theme.cozy
                            height: parent.height
                            radius: 3
                            color: Theme.primary
                            width: Math.max(6, parent.width *
                              ((Theme.panelWidthPercent - Theme.panelWidthMin) /
                               (Theme.panelWidthMax - Theme.panelWidthMin)))
                            Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                          }
                          // Marca del 100% (tamaño por defecto)
                          Rectangle {
                            width: 2
                            height: Theme.cozy ? 18 : 10
                            y: -2
                            radius: Theme.cozy ? 0 : 1
                            color: Theme.subtext
                            opacity: 0.6
                            x: Math.min(widthTrack.width - width,
                                        widthTrack.width *
                                        ((100 - Theme.panelWidthMin) /
                                         (Theme.panelWidthMax - Theme.panelWidthMin)))
                          }
                        }

                        Text {
                          Layout.fillWidth: true
                          text: Theme.panelWidthMin + "% ─── 100% ─── " + Theme.panelWidthMax + "%"
                          color: Theme.subtext
                          opacity: 0.6
                          font.pixelSize: Theme.fs(9)
                          font.family: Theme.fontFamily
                        }
                      }

                      // ── Restablecer: solo visible si no está en 100% ──
                      SkinRect {
                        visible: Theme.panelWidthPercent !== 100
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30
                        radius: 9
                        color: resetArea.containsMouse ? Theme.surfaceHigh : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text {
                          anchors.centerIn: parent
                          text: "󰑙"
                          color: Theme.subtext
                          font.pixelSize: Theme.fs(14)
                          font.family: Theme.monoFamily
                        }
                        MouseArea {
                          id: resetArea
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: Theme.setPanelWidthPercent(100)
                        }
                      }
                    }
                  }
                }

                Text {
                  Layout.fillWidth: true
                  text: Translations.t("advPanelWidthNote")
                  wrapMode: Text.WordWrap
                  color: Theme.subtext
                  font.italic: true
                  font.pixelSize: Theme.fs(10)
                  font.family: Theme.fontFamily
                }

                // ── Marco de pantalla: ON/OFF, estilo y radio/grosor ──
                SkinRect {
                  Layout.fillWidth: true
                  implicitHeight: frameCol.implicitHeight + 30
                  radius: Theme.cardRadius
                  color: Theme.surface
                  border.width: Theme.bw1
                  border.color: Theme.edge
                  clip: true

                  ColumnLayout {
                    id: frameCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                    spacing: 12

                    // ── Encabezado + interruptor ON/OFF ──
                    RowLayout {
                      Layout.fillWidth: true
                      spacing: 12

                      SkinRect {
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 36
                        radius: 11
                        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.14)
                        Text {
                          anchors.centerIn: parent
                          text: root.screenCorners ? "▣" : "▢"
                          color: Theme.primary
                          font.pixelSize: Theme.fs(16)
                          font.family: Theme.fontFamily
                        }
                      }

                      ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        SectionLabel { text: Translations.t("advFrameTitle") }
                        Text {
                          Layout.fillWidth: true
                          text: Translations.t("advFrameEnableHint")
                          wrapMode: Text.WordWrap
                          maximumLineCount: 2
                          elide: Text.ElideRight
                          color: Theme.subtext
                          font.pixelSize: Theme.fs(10)
                          font.family: Theme.fontFamily
                        }
                      }

                      // ── Interruptor ──
                      Item {
                        id: frameSwitch
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 20
                        opacity: Theme.barSeparated ? 0.4 : 1.0

                        SkinRect {
                          anchors.fill: parent
                          radius: 10
                          color: root.screenCorners ? Theme.primary : Theme.surfaceHigh
                          Behavior on color { ColorAnimation { duration: 150 } }

                          SkinRect {
                            width: 14
                            height: 14
                            radius: 7
                            anchors.verticalCenter: parent.verticalCenter
                            x: root.screenCorners ? 17 : 3
                            color: root.screenCorners ? Theme.textOnPrimary : Theme.subtext
                            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: 150 } }
                          }
                        }

                        MouseArea {
                          anchors.fill: parent
                          cursorShape: Theme.barSeparated ? Qt.ArrowCursor : Qt.PointingHandCursor
                          onClicked: if (!Theme.barSeparated) root.requestCornersToggle()
                        }
                      }
                    }

                    // ── Aviso: no se muestra con barra flotante o Islas ──
                    Text {
                      visible: Theme.barSeparated
                      Layout.fillWidth: true
                      text: Translations.t("advFrameOffHint")
                      wrapMode: Text.WordWrap
                      color: Theme.subtext
                      font.italic: true
                      font.pixelSize: Theme.fs(10)
                      font.family: Theme.fontFamily
                    }

                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }

                    // ── Estilo: Esquinas | Curvas (selector de 2) ──
                    SectionLabel { text: Translations.t("advFrameStyleLabel") }

                    SkinRect {
                      id: styleSeg
                      Layout.fillWidth: true
                      Layout.preferredHeight: 44
                      radius: 12
                      color: Theme.surfaceHigh

                      readonly property bool curved: Theme.frameCurved
                      readonly property real segW: (width - 6) / 2

                      // Resaltador que se desliza al elegido
                      SkinRect {
                        x: 3 + (styleSeg.curved ? 1 : 0) * styleSeg.segW
                        y: 3
                        width: styleSeg.segW
                        height: parent.height - 6
                        radius: 9
                        color: Theme.primary
                        Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                      }

                      RowLayout {
                        anchors.fill: parent
                        anchors.margins: 3
                        spacing: 0

                        Repeater {
                          model: [
                            { key: "corners", glyph: "▨", label: Translations.t("advFrameStyleCorners") },
                            { key: "curved",  glyph: "◜", label: Translations.t("advFrameStyleCurved")  }
                          ]

                          delegate: Item {
                            id: opt
                            required property var modelData
                            readonly property bool current: Theme.frameStyle === modelData.key

                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            RowLayout {
                              anchors.centerIn: parent
                              spacing: 6
                              Text {
                                text: opt.modelData.glyph
                                color: opt.current ? Theme.textOnPrimary : Theme.text
                                font.pixelSize: Theme.fs(14)
                                font.family: Theme.monoFamily
                                Behavior on color { ColorAnimation { duration: 150 } }
                              }
                              Text {
                                text: opt.modelData.label
                                color: opt.current ? Theme.textOnPrimary : Theme.text
                                font.pixelSize: Theme.fs(11)
                                font.family: Theme.fontFamily
                                Behavior on color { ColorAnimation { duration: 150 } }
                              }
                            }

                            MouseArea {
                              anchors.fill: parent
                              cursorShape: Qt.PointingHandCursor
                              onClicked: Theme.setFrameStyle(opt.modelData.key)
                            }
                          }
                        }
                      }
                    }

                    Text {
                      Layout.fillWidth: true
                      text: Translations.t("advFrameStyleHint")
                      wrapMode: Text.WordWrap
                      color: Theme.subtext
                      font.pixelSize: Theme.fs(10)
                      font.family: Theme.fontFamily
                    }

                    // ── Radio / grosor: solo tienen sentido con "curvas" ──
                    ColumnLayout {
                      Layout.fillWidth: true
                      spacing: 10
                      visible: Theme.frameCurved
                      opacity: Theme.frameCurved ? 1 : 0
                      Behavior on opacity { NumberAnimation { duration: 150 } }

                      Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }

                      RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        ColumnLayout {
                          Layout.fillWidth: true
                          spacing: 6
                          Text {
                            text: Translations.t("advFrameRadiusLabel")
                            color: Theme.subtext
                            font.pixelSize: Theme.fs(10)
                            font.family: Theme.fontFamily
                          }
                          NumberStepper {
                            value: Theme.frameCurveRadius
                            min: 10; max: 60; step: 2
                            suffix: "px"
                            onEdited: v => Theme.setFrameCurveRadius(v)
                          }
                        }

                        ColumnLayout {
                          Layout.fillWidth: true
                          spacing: 6
                          Text {
                            text: Translations.t("advFrameThicknessLabel")
                            color: Theme.subtext
                            font.pixelSize: Theme.fs(10)
                            font.family: Theme.fontFamily
                          }
                          NumberStepper {
                            value: Theme.frameThickness
                            min: 0; max: 150; step: 2
                            suffix: "px"
                            onEdited: v => Theme.setFrameThickness(v)
                          }
                        }
                      }
                    }
                  }
                }

                  }
                }
              }


              // ── Audio · OozeAudio ──
              Loader {
                id: catLoader_audio
                Layout.fillWidth: true
                // Solo existe la categoría elegida (antes las 6 inline se creaban de golpe
                // y solo se ocultaban con `visible`); `card.visible` la mantiene viva en el fade-out.
                active: !root.searching && root.category === "audio" && (root.open || card.visible)
                visible: active
                Layout.preferredHeight: item ? item.implicitHeight : 0
                onLoaded: { if (root.pendingAnchor !== "") anchorTimer.restart() }
                sourceComponent: Component {
                  ColumnLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                spacing: 12

                RowLayout {
                  Layout.fillWidth: true
                  spacing: 10

                  SettingsPanelTitle { icon: root.catIconByKey("advCatAudio"); title: Translations.t("advCatAudio") }

                  SettingsBtn {
                    text: Translations.t("advAudioOpenQpwgraph")
                    icon: "󰏌"
                    onClicked: root.openQpwgraph()
                  }

                  // ── Refrescar: ghost button, gira mientras consulta ──
                  SkinRect {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    radius: 9
                    color: audioRefreshArea.containsMouse ? Theme.surfaceHigh : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Text {
                      anchors.centerIn: parent
                      text: "󰑐"
                      color: Theme.subtext
                      font.pixelSize: Theme.fs(14)
                      font.family: Theme.monoFamily
                      RotationAnimation on rotation {
                        running: AudioService.busy
                        loops: Animation.Infinite
                        from: 0; to: 360
                        duration: 700
                      }
                    }
                    MouseArea {
                      id: audioRefreshArea
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: AudioService.refreshAll()
                    }
                  }
                }

                // ── Mostrar/ocultar tarjeta de monitores físicos ──
                RowLayout {
                  Layout.fillWidth: true
                  spacing: 8

                  Text {
                    Layout.fillWidth: true
                    text: Translations.t("advAudioMonitorsToggleLabel")
                    color: Theme.subtext
                    font.pixelSize: Theme.fs(11)
                    font.family: Theme.fontFamily
                  }

                  SkinRect {
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 20
                    radius: 10
                    color: Theme.audioMonitorsCardEnabled ? Theme.primary : Theme.surfaceHigh
                    Behavior on color { ColorAnimation { duration: 150 } }

                    SkinRect {
                      width: 14
                      height: 14
                      radius: 7
                      anchors.verticalCenter: parent.verticalCenter
                      x: Theme.audioMonitorsCardEnabled ? 17 : 3
                      color: Theme.audioMonitorsCardEnabled ? Theme.textOnPrimary : Theme.subtext
                      Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                      Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: Theme.setAudioMonitorsCardEnabled(!Theme.audioMonitorsCardEnabled)
                    }
                  }
                }

                // ── Error del backend, si el último comando falló ──
                SkinRect {
                  visible: root.oozeAudioError !== ""
                  Layout.fillWidth: true
                  implicitHeight: audioErrText.implicitHeight + 24
                  radius: Theme.cardRadius
                  color: Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.12)
                  clip: true
                  Text {
                    id: audioErrText
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 12 }
                    wrapMode: Text.WordWrap
                    text: root.oozeAudioError
                    color: Theme.error
                    font.pixelSize: Theme.fs(11)
                    font.family: Theme.fontFamily
                  }
                }

                // ── Salidas virtuales (ooze_*): crear, borrar, volumen ──
                SkinRect {
                  Layout.fillWidth: true
                  implicitHeight: outputsCol.implicitHeight + 28
                  radius: Theme.cardRadius
                  color: Theme.surface
                  border.width: Theme.bw1
                  border.color: Theme.edge
                  clip: true

                  ColumnLayout {
                    id: outputsCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
                    spacing: 10

                    SectionLabel { text: Translations.t("advAudioOutputsTitle") }
                    Text {
                      Layout.fillWidth: true
                      text: Translations.t("advAudioOutputsHint")
                      wrapMode: Text.WordWrap
                      color: Theme.subtext
                      font.pixelSize: Theme.fs(11)
                      font.family: Theme.fontFamily
                    }

                    // ── Crear salida nueva ──
                    RowLayout {
                      Layout.fillWidth: true
                      spacing: 8

                      SkinRect {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        radius: 10
                        color: Theme.bg
                        border.width: newOutputInput.activeFocus ? 1 : 0
                        border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.55)
                        Behavior on border.width { NumberAnimation { duration: 150 } }

                        TextInput {
                          id: newOutputInput
                          anchors { fill: parent; leftMargin: 12; rightMargin: 12; verticalCenter: parent.verticalCenter }
                          verticalAlignment: TextInput.AlignVCenter
                          color: Theme.text
                          selectionColor: Theme.primary
                          selectedTextColor: Theme.textOnPrimary
                          font.pixelSize: Theme.fs(12)
                          font.family: Theme.fontFamily
                          clip: true
                          text: root.oozeAudioNewName
                          onTextChanged: root.oozeAudioNewName = text
                          onAccepted: if (root.oozeAudioNewName.trim() !== "") {
                            AudioService.createOutput(root.oozeAudioNewName.trim())
                            root.oozeAudioNewName = ""
                          }

                          Text {
                            visible: newOutputInput.text === "" && !newOutputInput.activeFocus
                            text: Translations.t("advAudioNewOutputPlaceholder")
                            color: Theme.subtext
                            font.pixelSize: Theme.fs(12)
                            font.family: Theme.fontFamily
                          }
                        }
                      }

                      SettingsBtn {
                        text: Translations.t("advAudioCreate")
                        icon: "󰐕"
                        primary: true
                        enabled: !AudioService.busy && root.oozeAudioNewName.trim() !== ""
                        onClicked: {
                          AudioService.createOutput(root.oozeAudioNewName.trim())
                          root.oozeAudioNewName = ""
                        }
                      }
                    }

                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }

                    // ── Lista de salidas virtuales ──
                    ColumnLayout {
                      Layout.fillWidth: true
                      spacing: 8
                      visible: AudioService.outputs.length > 0

                      Repeater {
                        model: AudioService.outputs
                        delegate: AudioRow {
                          required property var modelData
                          nodeId: modelData.id
                          nodeName: modelData.name
                          title: modelData.desc
                          subtitle: modelData.name
                          volume: modelData.volume
                          muted: modelData.muted
                          deletable: true
                          showConnections: true
                          confirmingDelete: root.oozeAudioConfirmDelete === modelData.name
                          onVolumeMoved: v => AudioService.setVolume("outputs", modelData.id, v)
                          onMuteToggled: AudioService.setMute("outputs", modelData.id, !modelData.muted)
                          onDeleteRequested: {
                            if (root.oozeAudioConfirmDelete === modelData.name) {
                              AudioService.deleteOutput(modelData.desc)
                              root.oozeAudioConfirmDelete = ""
                            } else {
                              root.oozeAudioConfirmDelete = modelData.name
                            }
                          }
                        }
                      }
                    }

                    Text {
                      visible: AudioService.outputs.length === 0
                      Layout.fillWidth: true
                      wrapMode: Text.WordWrap
                      text: Translations.t("advAudioNoOutputs")
                      color: Theme.subtext
                      font.italic: true
                      font.pixelSize: Theme.fs(11)
                      font.family: Theme.fontFamily
                    }
                  }
                }

                // ── Monitores / salidas físicas: solo volumen ──
                SkinRect {
                  Layout.fillWidth: true
                  visible: Theme.audioMonitorsCardEnabled
                  implicitHeight: sinksCol.implicitHeight + 28
                  radius: Theme.cardRadius
                  color: Theme.surface
                  border.width: Theme.bw1
                  border.color: Theme.edge
                  clip: true

                  ColumnLayout {
                    id: sinksCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
                    spacing: 10

                    SectionLabel { text: Translations.t("advAudioMonitorsTitle") }
                    Text {
                      Layout.fillWidth: true
                      text: Translations.t("advAudioMonitorsHint")
                      wrapMode: Text.WordWrap
                      color: Theme.subtext
                      font.pixelSize: Theme.fs(11)
                      font.family: Theme.fontFamily
                    }

                    ColumnLayout {
                      Layout.fillWidth: true
                      spacing: 8
                      visible: AudioService.destinationCandidates().length > 0

                      Repeater {
                        model: AudioService.destinationCandidates()
                        delegate: AudioRow {
                          required property var modelData
                          nodeId: modelData.id
                          title: modelData.desc
                          subtitle: modelData.name
                          volume: modelData.volume
                          muted: modelData.muted
                          deletable: false
                          onVolumeMoved: v => AudioService.setVolume("sinks", modelData.id, v)
                          onMuteToggled: AudioService.setMute("sinks", modelData.id, !modelData.muted)
                        }
                      }
                    }

                    Text {
                      visible: AudioService.destinationCandidates().length === 0
                      Layout.fillWidth: true
                      wrapMode: Text.WordWrap
                      text: Translations.t("advAudioNoMonitors")
                      color: Theme.subtext
                      font.italic: true
                      font.pixelSize: Theme.fs(11)
                      font.family: Theme.fontFamily
                    }
                  }
                }

                Item { Layout.preferredHeight: 4 }
                  }
                }
              }


              // ── Perfil · foto y nombre ──
              ColumnLayout {
                Layout.fillWidth: true
                visible: !root.searching && root.category === "profile"
                spacing: 14

                SettingsPanelTitle { icon: root.catIconByKey("advCatProfile"); title: Translations.t("advCatProfile") }

                SkinRect {
                  Layout.fillWidth: true
                  implicitHeight: profileCol.implicitHeight + 30
                  radius: Theme.cardRadius
                  color: Theme.surface
                  border.width: Theme.bw1
                  border.color: Theme.edge
                  clip: true

                  ColumnLayout {
                    id: profileCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                    spacing: 12

                    RowLayout {
                      Layout.fillWidth: true
                      spacing: 16

                      Avatar {
                        Layout.preferredWidth: 76
                        Layout.preferredHeight: 76
                        size: 76
                        source: UserProfile.avatarUrl
                        letter: UserProfile.shownName.length > 0 ? UserProfile.shownName.charAt(0).toUpperCase() : "?"
                      }

                      ColumnLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        spacing: 6

                        Text {
                          Layout.fillWidth: true
                          text: UserProfile.shownName.length > 0 ? UserProfile.shownName : "—"
                          color: Theme.text
                          font.bold: true
                          font.pixelSize: Theme.fs(15)
                          font.family: Theme.fontFamily
                          elide: Text.ElideRight
                        }
                        Text {
                          Layout.fillWidth: true
                          text: UserProfile.busy ? Translations.t("profileSaving")
                              : UserProfile.avatarSource !== "" ? Translations.t("profilePhoto")
                              : Translations.t("profileNoPhoto")
                          color: Theme.subtext
                          font.pixelSize: Theme.fs(11)
                          font.family: Theme.fontFamily
                          elide: Text.ElideRight
                        }

                        RowLayout {
                          spacing: 8
                          SettingsBtn {
                            primary: true
                            icon: "󰋩"
                            text: UserProfile.avatarSource !== "" ? Translations.t("profileChange")
                                                                  : Translations.t("profileChoose")
                            onClicked: root.browsing = !root.browsing
                          }
                          SettingsBtn {
                            visible: UserProfile.avatarPath !== ""
                            icon: "󰆴"
                            text: Translations.t("profileRemove")
                            onClicked: UserProfile.clearAvatar()
                          }
                        }
                      }
                    }

                    Text {
                      visible: root.browsing
                      Layout.fillWidth: true
                      text: Translations.t("profileBrowseHint")
                      wrapMode: Text.WordWrap
                      color: Theme.subtext
                      font.pixelSize: Theme.fs(10)
                      font.family: Theme.fontFamily
                    }

                    ImageBrowser {
                      id: profileBrowser
                      visible: root.browsing
                      Layout.fillWidth: true
                      Layout.preferredHeight: 290

                      onPicked: path => {
                        UserProfile.chooseAvatar(path)
                        root.browsing = false
                      }
                      onCancelled: root.browsing = false
                    }

                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }

                    // ── Nombre a mostrar: vacío = se usa el de usuario ──
                    ColumnLayout {
                      Layout.fillWidth: true
                      spacing: 6

                      SectionLabel { text: Translations.t("profileDisplayName") }

                      Text {
                        Layout.fillWidth: true
                        text: Translations.t("profileDisplayNameHint")
                        wrapMode: Text.WordWrap
                        color: Theme.subtext
                        font.pixelSize: Theme.fs(10)
                        font.family: Theme.fontFamily
                      }

                      SkinRect {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        radius: 12
                        color: Theme.bg
                        border.width: Theme.bw1
                        border.color: displayNameInput.activeFocus
                          ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.55)
                          : Theme.divider
                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        TextInput {
                          id: displayNameInput
                          anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                          verticalAlignment: TextInput.AlignVCenter
                          color: Theme.text
                          selectionColor: Theme.primary
                          selectedTextColor: Theme.textOnPrimary
                          font.pixelSize: Theme.fs(12)
                          font.family: Theme.fontFamily
                          clip: true
                          text: UserProfile.displayName

                          // Solo escribe al confirmar (Enter) o perder foco
                          onEditingFinished: UserProfile.setDisplayName(displayNameInput.text)
                          Keys.onReturnPressed: displayNameInput.focus = false
                          Keys.onEnterPressed: displayNameInput.focus = false

                          Text {
                            visible: displayNameInput.text === "" && !displayNameInput.activeFocus
                            text: Translations.t("profileDisplayNamePlaceholder")
                            color: Theme.subtext
                            font.pixelSize: Theme.fs(12)
                            font.family: Theme.fontFamily
                          }
                        }
                      }
                    }
                  }
                }
              }

              // ── General · accesos a Monitor/Idioma/Launcher/Terminal ──
              Loader {
                id: catLoader_general
                Layout.fillWidth: true
                // Solo existe la categoría elegida (antes las 6 inline se creaban de golpe
                // y solo se ocultaban con `visible`); `card.visible` la mantiene viva en el fade-out.
                active: !root.searching && root.category === "general" && (root.open || card.visible)
                visible: active
                Layout.preferredHeight: item ? item.implicitHeight : 0
                onLoaded: { if (root.pendingAnchor !== "") anchorTimer.restart() }
                sourceComponent: Component {
                  ColumnLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                spacing: 12

                SettingsPanelTitle { icon: root.catIconByKey("advCatGeneral"); title: Translations.t("advCatGeneral") }

                // ── Todo se configura acá; solo Idioma abre su ventana (IPC) ──
                SkinRect {
                  Layout.fillWidth: true
                  implicitHeight: monitorCol.implicitHeight + 30
                  radius: Theme.cardRadius
                  color: Theme.surface
                  border.width: Theme.bw1
                  border.color: Theme.edge
                  clip: true

                  ColumnLayout {
                    id: monitorCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                    spacing: 10

                    SectionLabel { text: Translations.t("settingsMonitor") }

                    Flow {
                      Layout.fillWidth: true
                      spacing: 8
                      SettingsBtn {
                        icon: "󰍹"
                        text: Translations.t("monitorAutoOption")
                        primary: root.targetMonitor === "auto"
                        onClicked: root.monitorChosen("auto")
                      }
                      Repeater {
                        model: Quickshell.screens
                        delegate: SettingsBtn {
                          required property var modelData
                          icon: "󰍹"
                          text: modelData.name
                          primary: root.targetMonitor === modelData.name
                          onClicked: root.monitorChosen(modelData.name)
                        }
                      }
                    }

                    Text {
                      Layout.fillWidth: true
                      text: root.targetMonitor === "auto" && root.resolvedMonitor !== ""
                        ? Translations.t("monitorAutoHint") + " " + root.resolvedMonitor
                        : Translations.t("monitorAutoSubtitle")
                      wrapMode: Text.WordWrap
                      color: Theme.subtext
                      font.pixelSize: Theme.fs(10)
                      font.family: Theme.fontFamily
                    }
                  }
                }

                // ── Idioma ──
                SkinRect {
                  Layout.fillWidth: true
                  implicitHeight: languageCol.implicitHeight + 30
                  radius: Theme.cardRadius
                  color: Theme.surface
                  border.width: Theme.bw1
                  border.color: Theme.edge
                  clip: true

                  ColumnLayout {
                    id: languageCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                    spacing: 10

                    SectionLabel { text: Translations.t("settingsLanguage") }

                    Flow {
                      Layout.fillWidth: true
                      spacing: 8
                      Repeater {
                        // Nombres de idioma sin traducir (cada uno en el suyo)
                        model: Translations.availableLanguages
                        delegate: SettingsBtn {
                          required property var modelData
                          icon: "󰗊"
                          text: modelData.name
                          primary: modelData.code === Translations.current
                          onClicked: root.languageChosen(modelData.code)
                        }
                      }
                    }

                    Text {
                      Layout.fillWidth: true
                      text: Translations.t("settingsLanguageHint")
                      wrapMode: Text.WordWrap
                      color: Theme.subtext
                      font.pixelSize: Theme.fs(10)
                      font.family: Theme.fontFamily
                    }
                  }
                }

                SkinRect {
                  Layout.fillWidth: true
                  implicitHeight: launcherCol.implicitHeight + 30
                  radius: Theme.cardRadius
                  color: Theme.surface
                  border.width: Theme.bw1
                  border.color: Theme.edge
                  clip: true

                  ColumnLayout {
                    id: launcherCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                    spacing: 10

                    SectionLabel { text: Translations.t("settingsLauncherSection") }

                    SectionLabel { text: Translations.t("settingsLauncherPlacement") }
                    RowLayout {
                      Layout.fillWidth: true
                      spacing: 10
                      SettingsBtn {
                        icon: "▀"
                        text: Translations.t("settingsLauncherBar")
                        primary: Theme.launcherAttached
                        onClicked: Theme.setLauncherAttached(true)
                      }
                      SettingsBtn {
                        icon: "▣"
                        text: Translations.t("settingsLauncherCenter")
                        primary: !Theme.launcherAttached
                        onClicked: Theme.setLauncherAttached(false)
                      }
                      Item { Layout.fillWidth: true }
                    }

                    RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Text {
                      Layout.preferredWidth: Math.min(implicitWidth, 140)
                      Layout.maximumWidth: 140
                      elide: Text.ElideRight
                      text: Translations.t("settingsLauncherImage")
                      color: Theme.text
                      font.bold: true
                      font.pixelSize: Theme.fs(12)
                      font.family: Theme.fontFamily
                    }
                    SettingsBtn {
                      icon: "▣"
                      text: Theme.launcherShowImage ? "ON" : "OFF"
                      primary: Theme.launcherShowImage
                      onClicked: Theme.setLauncherShowImage(!Theme.launcherShowImage)
                    }
                    Item { Layout.fillWidth: true }
                  }

                    RowLayout {
                      Layout.fillWidth: true
                      spacing: 10
                      Text {
                        Layout.preferredWidth: Math.min(implicitWidth, 140)
                        Layout.maximumWidth: 140
                        elide: Text.ElideRight
                        text: Translations.t("settingsLauncherSize")
                        color: Theme.text
                        font.bold: true
                        font.pixelSize: Theme.fs(12)
                        font.family: Theme.fontFamily
                      }
                      Repeater {
                        model: [
                          { size: 0, label: "settingsSizeCompact" },
                          { size: 1, label: "settingsSizeNormal" },
                          { size: 2, label: "settingsSizeLarge" }
                        ]
                        delegate: SettingsBtn {
                          required property var modelData
                          text: Translations.t(modelData.label)
                          primary: Theme.launcherSize === modelData.size
                          onClicked: Theme.setLauncherSize(modelData.size)
                        }
                      }
                      Item { Layout.fillWidth: true }
                    }

                    Text {
                      Layout.fillWidth: true
                      text: Translations.t("settingsLauncherHint")
                      wrapMode: Text.WordWrap
                      color: Theme.subtext
                      font.pixelSize: Theme.fs(10)
                      font.family: Theme.fontFamily
                    }

                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }

                    SectionLabel { text: Translations.t("settingsEffectsSection") }
                    RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Text {
                      Layout.preferredWidth: Math.min(implicitWidth, 140)
                      Layout.maximumWidth: 140
                      elide: Text.ElideRight
                      text: Translations.t("settingsEffectsLabel")
                      color: Theme.text
                      font.bold: true
                      font.pixelSize: Theme.fs(12)
                      font.family: Theme.fontFamily
                    }
                    SettingsBtn {
                      icon: "✦"
                      text: Theme.effectsOn ? "ON" : "OFF"
                      primary: Theme.effectsOn
                      onClicked: Theme.setEffects(!Theme.effectsOn)
                    }
                    Item { Layout.fillWidth: true }
                  }
                    Text {
                      Layout.fillWidth: true
                      text: Translations.t("settingsEffectsHint")
                      wrapMode: Text.WordWrap
                      color: Theme.subtext
                      font.pixelSize: Theme.fs(10)
                      font.family: Theme.fontFamily
                    }

                    RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Text {
                      Layout.preferredWidth: Math.min(implicitWidth, 140)
                      Layout.maximumWidth: 140
                      elide: Text.ElideRight
                      text: Translations.t("settingsLauncherParticles")
                      color: Theme.text
                      font.bold: true
                      font.pixelSize: Theme.fs(12)
                      font.family: Theme.fontFamily
                    }
                    SettingsBtn {
                      icon: "✦"
                      text: Theme.launcherParticlesEnabled ? "ON" : "OFF"
                      primary: Theme.launcherParticlesEnabled
                      onClicked: Theme.setLauncherParticlesEnabled(!Theme.launcherParticlesEnabled)
                    }
                    Item { Layout.fillWidth: true }
                  }
                    Text {
                      Layout.fillWidth: true
                      text: Translations.t("settingsLauncherParticlesHint")
                      wrapMode: Text.WordWrap
                      color: Theme.subtext
                      font.pixelSize: Theme.fs(10)
                      font.family: Theme.fontFamily
                    }

                    RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Text {
                      Layout.preferredWidth: Math.min(implicitWidth, 140)
                      Layout.maximumWidth: 140
                      elide: Text.ElideRight
                      text: Translations.t("settingsLauncherWallpaperLive")
                      color: Theme.text
                      font.bold: true
                      font.pixelSize: Theme.fs(12)
                      font.family: Theme.fontFamily
                    }
                    SettingsBtn {
                      icon: "▶"
                      text: Theme.launcherWallpaperLiveEnabled ? "ON" : "OFF"
                      primary: Theme.launcherWallpaperLiveEnabled
                      onClicked: Theme.setLauncherWallpaperLiveEnabled(!Theme.launcherWallpaperLiveEnabled)
                    }
                    Item { Layout.fillWidth: true }
                  }
                    Text {
                      Layout.fillWidth: true
                      text: Translations.t("settingsLauncherWallpaperLiveHint")
                      wrapMode: Text.WordWrap
                      color: Theme.subtext
                      font.pixelSize: Theme.fs(10)
                      font.family: Theme.fontFamily
                    }
                  }
                }

                SkinRect {
                  Layout.fillWidth: true
                  implicitHeight: terminalCol.implicitHeight + 30
                  radius: Theme.cardRadius
                  color: Theme.surface
                  border.width: Theme.bw1
                  border.color: Theme.edge
                  clip: true

                  ColumnLayout {
                    id: terminalCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                    spacing: 10

                    SectionLabel { text: Translations.t("settingsTerminalSection") }

                    Flow {
                      Layout.fillWidth: true
                      spacing: 8
                      Repeater {
                        model: root.terminalChoices
                        delegate: SettingsBtn {
                          required property var modelData
                          icon: "󰆍"
                          text: modelData.name
                          primary: Theme.terminalId === modelData.id
                          onClicked: Theme.setTerminal(modelData.id)
                        }
                      }
                    }

                    Text {
                      Layout.fillWidth: true
                      text: Translations.t("settingsTerminalHint")
                      wrapMode: Text.WordWrap
                      color: Theme.subtext
                      font.pixelSize: Theme.fs(10)
                      font.family: Theme.fontFamily
                    }
                  }
                }

                // ── Pantalla de bloqueo: origen del fondo ──
                SkinRect {
                  Layout.fillWidth: true
                  implicitHeight: lockCol.implicitHeight + 30
                  radius: Theme.cardRadius
                  color: Theme.surface
                  border.width: Theme.bw1
                  border.color: Theme.edge
                  clip: true

                  ColumnLayout {
                    id: lockCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                    spacing: 10

                    // "" | "ok" | "missing" | "empty" — resultado de revisar la ruta
                    property string pathStatus: ""

                    function checkPath() {
                      if (Theme.lockWallpaperPath === "") { lockCol.pathStatus = "empty"; return }
                      lockPathCheck.running = false
                      lockPathCheck.running = true
                    }
                    Component.onCompleted: lockCol.checkPath()

                    Process {
                      id: lockPathCheck
                      command: ["bash", "-c", [
                        'p="$1"',
                        'case "$p" in "~"|"~/"*) p="$HOME${p#\\~}";; esac',
                        'p="${p/#\\$HOME/$HOME}"',
                        '[ -f "$p" ] && echo ok || echo missing'
                      ].join("\n"), "sh", Theme.lockWallpaperPath]
                      stdout: SplitParser {
                        onRead: line => lockCol.pathStatus = line.trim() === "ok" ? "ok" : "missing"
                      }
                    }

                    Connections {
                      target: Theme
                      function onLockWallpaperPathChanged() { lockCol.checkPath() }
                    }

                    SectionLabel { text: Translations.t("lockSection") }

                    Flow {
                      Layout.fillWidth: true
                      spacing: 8

                      SettingsBtn {
                        icon: "󰸉"
                        text: Translations.t("lockModeAuto")
                        primary: Theme.lockWallpaperMode === "auto"
                        onClicked: Theme.setLockWallpaperMode("auto")
                      }
                      SettingsBtn {
                        icon: "󰋩"
                        text: Translations.t("lockModeCustom")
                        primary: Theme.lockWallpaperMode === "custom"
                        onClicked: Theme.setLockWallpaperMode("custom")
                      }
                    }

                    Text {
                      Layout.fillWidth: true
                      text: Translations.t(Theme.lockWallpaperMode === "custom" ? "lockCustomHint" : "lockAutoHint")
                      wrapMode: Text.WordWrap
                      color: Theme.subtext
                      font.pixelSize: Theme.fs(10)
                      font.family: Theme.fontFamily
                    }

                    // Ruta de la imagen (solo en modo "Imagen propia")
                    RowLayout {
                      Layout.fillWidth: true
                      visible: Theme.lockWallpaperMode === "custom"
                      spacing: 8

                      SkinRect {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        radius: 10
                        color: Theme.surfaceHigh
                        border.width: lockPathInput.activeFocus ? 1 : 0
                        border.color: Theme.primary

                        TextInput {
                          id: lockPathInput
                          anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                          verticalAlignment: TextInput.AlignVCenter
                          text: Theme.lockWallpaperPath
                          color: Theme.text
                          selectionColor: Theme.primary
                          selectedTextColor: Theme.textOnPrimary
                          font.pixelSize: Theme.fs(12)
                          font.family: Theme.fontFamily
                          clip: true
                          inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhUrlCharactersOnly
                          onAccepted: Theme.setLockWallpaperPath(text)
                          onEditingFinished: Theme.setLockWallpaperPath(text)

                          Text {
                            visible: lockPathInput.text === "" && !lockPathInput.activeFocus
                            text: Translations.t("lockPathPlaceholder")
                            color: Theme.subtext
                            font.pixelSize: Theme.fs(12)
                            font.family: Theme.fontFamily
                          }
                        }
                      }

                      SettingsBtn {
                        icon: "󰄬"
                        text: Translations.t("lockPathApply")
                        onClicked: Theme.setLockWallpaperPath(lockPathInput.text)
                      }
                    }

                    Text {
                      Layout.fillWidth: true
                      visible: Theme.lockWallpaperMode === "custom" && lockCol.pathStatus !== ""
                      wrapMode: Text.WordWrap
                      text: lockCol.pathStatus === "ok" ? "󰄬  " + Translations.t("lockPathOk")
                          : lockCol.pathStatus === "missing" ? "󰅖  " + Translations.t("lockPathMissing")
                          : Translations.t("lockPathEmpty")
                      color: lockCol.pathStatus === "ok" ? Theme.primary
                           : lockCol.pathStatus === "missing" ? Theme.error
                           : Theme.subtext
                      font.pixelSize: Theme.fs(11)
                      font.family: Theme.monoFamily
                    }
                  }
                }
                  }
                }
              }

              // ── HyprMonitor · editor de monitores ──
              ColumnLayout {
                Layout.fillWidth: true
                visible: !root.searching && root.category === "hypr"
                spacing: 12

                SettingsPanelTitle { icon: root.catIconByKey("advCatHyprMonitor"); title: Translations.t("advCatHyprMonitor") }

                Text {
                  Layout.fillWidth: true
                  text: Translations.t("hyprMonitorsHint")
                  wrapMode: Text.WordWrap
                  color: Theme.subtext
                  font.pixelSize: Theme.fs(10)
                  font.family: Theme.fontFamily
                }

                // ── Mapa: arrastrar para reposicionar ──
                SkinRect {
                  id: hmMapCard
                  Layout.fillWidth: true
                  Layout.preferredHeight: root.hmMapHeight
                  radius: Theme.cardRadius
                  color: Theme.surface
                  border.width: Theme.bw1
                  border.color: Theme.edge
                  clip: true
                  onWidthChanged: root.hmMapWidth = width
                  Component.onCompleted: root.hmMapWidth = width

                  Text {
                    visible: root.hmMonitors.length === 0
                    anchors.centerIn: parent
                    text: Translations.t("hyprMonitorsRefresh") + "…"
                    color: Theme.subtext
                    font.italic: true
                    font.pixelSize: Theme.fs(11)
                    font.family: Theme.fontFamily
                  }

                  Repeater {
                    model: root.hmMonitors

                    delegate: SkinRect {
                      id: hmBox
                      required property var modelData
                      readonly property bool isSelected: modelData.output === root.hmSelected
                      readonly property real logW: modelData.width / (modelData.scale || 1)
                      readonly property real logH: modelData.height / (modelData.scale || 1)

                      x: root.hmToMapX(modelData.x)
                      y: root.hmToMapY(modelData.y)
                      width: Math.max(40, logW * root.hmMapScale)
                      height: Math.max(30, logH * root.hmMapScale)
                      radius: 8
                      color: isSelected
                        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.22)
                        : Theme.bg
                      border.width: isSelected ? 2 : Theme.bw1
                      border.color: isSelected ? Theme.primary : Theme.edge
                      Behavior on x { enabled: !hmDrag.drag.active; NumberAnimation { duration: 120 } }
                      Behavior on y { enabled: !hmDrag.drag.active; NumberAnimation { duration: 120 } }

                      ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 0
                        Text {
                          Layout.alignment: Qt.AlignHCenter
                          text: hmBox.modelData.output
                          color: hmBox.isSelected ? Theme.primary : Theme.text
                          font.bold: true
                          font.pixelSize: Theme.fs(11)
                          font.family: Theme.fontFamily
                        }
                        Text {
                          Layout.alignment: Qt.AlignHCenter
                          visible: hmBox.width > 70
                          text: hmBox.modelData.width + "×" + hmBox.modelData.height
                          color: Theme.subtext
                          font.pixelSize: Theme.fs(9)
                          font.family: Theme.fontFamily
                        }
                      }

                      MouseArea {
                        id: hmDrag
                        anchors.fill: parent
                        cursorShape: Qt.SizeAllCursor
                        onPressed: root.hmSelected = hmBox.modelData.output
                        drag.target: hmBox
                        drag.axis: Drag.XAndYAxis
                        onReleased: root.hmUpdateMonitor(hmBox.modelData.output, {
                          x: root.hmSnap(root.hmFromMapX(hmBox.x)),
                          y: root.hmSnap(root.hmFromMapY(hmBox.y))
                        })
                      }
                    }
                  }
                }

                // ── Selector de salida (si hay más de una) ──
                Flow {
                  Layout.fillWidth: true
                  visible: root.hmMonitors.length > 1
                  spacing: 8
                  Repeater {
                    model: root.hmMonitors
                    delegate: SettingsBtn {
                      required property var modelData
                      icon: "󰍹"
                      text: modelData.output
                      primary: modelData.output === root.hmSelected
                      onClicked: root.hmSelected = modelData.output
                    }
                  }
                }

                // ── Ajustes del monitor seleccionado ──
                SkinRect {
                  Layout.fillWidth: true
                  visible: root.hmCurrent !== null
                  implicitHeight: hmSettingsCol.implicitHeight + 30
                  radius: Theme.cardRadius
                  color: Theme.surface
                  border.width: Theme.bw1
                  border.color: Theme.edge
                  clip: true

                  ColumnLayout {
                    id: hmSettingsCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                    spacing: 12

                    RowLayout {
                      Layout.fillWidth: true
                      Text {
                        text: root.hmCurrent ? root.hmCurrent.output : ""
                        color: Theme.primary
                        font.bold: true
                        font.pixelSize: Theme.fs(13)
                        font.family: Theme.fontFamily
                      }
                      Item { Layout.fillWidth: true }
                      Text {
                        text: root.hmCurrent ? (root.hmCurrent.width + "×" + root.hmCurrent.height
                              + "  @ " + root.hmCurrent.x + "," + root.hmCurrent.y) : ""
                        color: Theme.subtext
                        font.pixelSize: Theme.fs(10)
                        font.family: Theme.fontFamily
                      }
                    }

                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }

                    // Modo
                    RowLayout {
                      Layout.fillWidth: true
                      spacing: 12
                      SectionLabel {
                        Layout.preferredWidth: 90
                        Layout.alignment: Qt.AlignTop
                        text: Translations.t("hyprMonitorsMode")
                      }
                      Flow {
                        Layout.fillWidth: true
                        spacing: 8
                        SettingsBtn {
                          text: Translations.t("hyprMonitorsPreferred")
                          primary: root.hmCurrent && root.hmCurrent.mode === "preferred"
                          onClicked: root.hmUpdateMonitor(root.hmSelected, { mode: "preferred" })
                        }
                        Repeater {
                          model: root.hmCurrent ? root.hmCurrent.modes : []
                          delegate: SettingsBtn {
                            required property string modelData
                            text: modelData
                            primary: root.hmCurrent && root.hmCurrent.mode === modelData
                            onClicked: root.hmUpdateMonitor(root.hmSelected, { mode: modelData })
                          }
                        }
                      }
                    }

                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }

                    // Escala
                    RowLayout {
                      Layout.fillWidth: true
                      spacing: 12
                      SectionLabel {
                        Layout.preferredWidth: 90
                        Layout.alignment: Qt.AlignTop
                        text: Translations.t("hyprMonitorsScale")
                      }
                      Flow {
                        Layout.fillWidth: true
                        spacing: 8
                        Repeater {
                          model: ["auto", 1, 1.25, 1.5, 2]
                          delegate: SettingsBtn {
                            required property var modelData
                            text: modelData === "auto" ? Translations.t("hyprMonitorsAuto")
                                                        : Math.round(modelData * 100) + "%"
                            primary: root.hmCurrent && root.hmCurrent.scale === modelData
                            onClicked: root.hmUpdateMonitor(root.hmSelected, { scale: modelData })
                          }
                        }
                      }
                    }

                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }

                    // Rotación
                    RowLayout {
                      Layout.fillWidth: true
                      spacing: 12
                      SectionLabel {
                        Layout.preferredWidth: 90
                        Layout.alignment: Qt.AlignTop
                        text: Translations.t("hyprMonitorsRotation")
                      }
                      Flow {
                        Layout.fillWidth: true
                        spacing: 8
                        Repeater {
                          model: [ { v: 0, l: "0°" }, { v: 1, l: "90°" }, { v: 2, l: "180°" }, { v: 3, l: "270°" } ]
                          delegate: SettingsBtn {
                            required property var modelData
                            text: modelData.l
                            primary: root.hmCurrent && root.hmCurrent.transform === modelData.v
                            onClicked: root.hmUpdateMonitor(root.hmSelected, { transform: modelData.v })
                          }
                        }
                      }
                    }

                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }

                    // Espejo
                    RowLayout {
                      Layout.fillWidth: true
                      spacing: 12
                      SectionLabel {
                        Layout.preferredWidth: 90
                        Layout.alignment: Qt.AlignTop
                        text: Translations.t("hyprMonitorsMirror")
                      }
                      Flow {
                        Layout.fillWidth: true
                        spacing: 8
                        SettingsBtn {
                          text: Translations.t("hyprMonitorsMirrorNone")
                          primary: root.hmCurrent && root.hmCurrent.mirrorOf === ""
                          onClicked: root.hmUpdateMonitor(root.hmSelected, { mirrorOf: "" })
                        }
                        Repeater {
                          model: root.hmMonitors.filter(m => m.output !== root.hmSelected)
                          delegate: SettingsBtn {
                            required property var modelData
                            icon: "󰍹"
                            text: modelData.output
                            primary: root.hmCurrent && root.hmCurrent.mirrorOf === modelData.output
                            onClicked: root.hmUpdateMonitor(root.hmSelected, { mirrorOf: modelData.output })
                          }
                        }
                      }
                    }
                  }
                }

                // ── Pie: redetectar · estado · aplicar ──
                RowLayout {
                  Layout.fillWidth: true
                  spacing: 10
                  SettingsBtn {
                    icon: "󰑐"
                    text: Translations.t("hyprMonitorsRefresh")
                    onClicked: root.hmRefresh()
                  }
                  Item { Layout.fillWidth: true }
                  Text {
                    visible: root.hmStatus !== ""
                    Layout.maximumWidth: 260
                    text: root.hmStatus
                    wrapMode: Text.WordWrap
                    color: Theme.subtext
                    font.pixelSize: Theme.fs(10)
                    font.family: Theme.fontFamily
                  }
                  SettingsBtn {
                    primary: true
                    icon: "󰄬"
                    text: Translations.t("hyprMonitorsApply")
                    onClicked: root.hmApplyAndSave()
                  }
                }
              }

              Item { Layout.preferredHeight: 4 }
            }
          }
        }
      }
      }  // ClippingRectangle cardClip
    }
  }
}
