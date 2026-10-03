// WmAppearance — adaptador de apariencia por window manager (Global-Manager, fase 3).
//
// shell.qml guarda el estado (`appearance`, su cache JSON, el IPC) y llama acá
// para lo que depende del WM:
//   • aplicar un valor EN VIVO (hyprctl eval / mmsg setoption; Niri no tiene)
//   • escribir los archivos autogen que tus dotfiles cargan
//   • layouts disponibles y su equivalente en cada WM
//
//   Hyprland → ~/.config/hypr/modules/appearance/autogen/{theme,layouta,animprofile}.lua
//   Mango    → ~/.config/mango/autogen/{theme,layout,animprofile}.conf   (source-optional)
//   Niri     → ~/.config/niri/autogen/{theme,layout,animprofile}.kdl     (include en config.kdl)
//
// Niri: `include` es POSICIONAL (pisa lo anterior). Poné los include al FINAL de
// config.kdl, y con optional=true (niri 26.04+) para que no falle si faltan:
//   include optional=true "~/.config/niri/autogen/theme.kdl"
//   include optional=true "~/.config/niri/autogen/layout.kdl"
//   include optional=true "~/.config/niri/autogen/animprofile.kdl"
// Niri recarga solo al guardar un archivo incluido: el "en vivo" es reescribir theme.kdl
// con throttle de 200 ms mientras se arrastra el slider (ver applyLive).
// Los tres archivos son dueños de secciones distintas, sin pisarse:
//   theme.kdl → layout (gaps/borde/sombra), window-rule (esquinas, opacidad, blur), blur {}
//   layout.kdl → layout { default-column-display }
//   animprofile.kdl → animations (off o perfil completo)
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: root

  readonly property string home: Quickshell.env("HOME")

  // ─── Catálogo por WM ────────────────────────────────────────────
  readonly property var layoutNames: {
    switch (WM.wm) {
      case "mango": return ["scroller", "grid", "tile", "vertical_scroller", "dwindle"]
      case "niri":  return ["normal", "tabbed"]
      default:      return ["scrolling", "dwindle", "master", "monocle"]
    }
  }
  readonly property var layoutIcons: {
    switch (WM.wm) {
      case "mango": return { scroller: "|||", grid: "󰕰", tile: "󰓦", vertical_scroller: "≡", dwindle: "󰕳" }
      case "niri":  return { normal: "󰕮", tabbed: "󰓩" }
      default:      return { scrolling: "󰕰", dwindle: "󰕳", master: "󰓦", monocle: "󰖲" }
    }
  }
  readonly property var layoutLabels: {
    switch (WM.wm) {
      case "mango": return { scroller: "scroller", grid: "grid", tile: "tile", vertical_scroller: "v-scroller", dwindle: "dwindle" }
      case "niri":  return { normal: "columns", tabbed: "tabbed" }
      default:      return ({})
    }
  }
  readonly property string defaultLayout: {
    switch (WM.wm) {
      case "mango": return "scroller"
      case "niri":  return "normal"
      default:      return "dwindle"
    }
  }
  // Equivalencias del cache viejo (otro WM / versión anterior)
  readonly property var legacyLayouts: ({ scrolling: "scroller", master: "tile", monocle: "scroller" })

  function normalizeLayout(name) {
    let n = String(name ?? "")
    if (WM.wm === "mango") n = root.legacyLayouts[n] ?? n
    return root.layoutNames.indexOf(n) >= 0 ? n : root.defaultLayout
  }

  // Opciones solo de un WM (el panel las muestra según esto)
  readonly property bool hasBlurOptimized: WM.wm === "mango"

  readonly property var animProfileNames: ["smooth", "snappy", "playful", "minimal", "dramatic", "dramatic_side"]

  // ─── Hyprland: clave → ruta de tabla en hl.config() ─────────────
  // Hyprland 0.55+ corre con configProvider lua: `hyprctl keyword` está
  // deshabilitado; se usa `hyprctl eval '<lua>'`.
  readonly property var hyprPath: ({
    gapsIn:            ["general", "gaps_in"],
    gapsOut:           ["general", "gaps_out"],
    borderSize:        ["general", "border_size"],
    rounding:          ["decoration", "rounding"],
    roundingPower:     ["decoration", "rounding_power"],
    activeOpacity:     ["decoration", "active_opacity"],
    inactiveOpacity:   ["decoration", "inactive_opacity"],
    blurEnabled:       ["decoration", "blur", "enabled"],
    blurSize:          ["decoration", "blur", "size"],
    blurPasses:        ["decoration", "blur", "passes"],
    shadowEnabled:     ["decoration", "shadow", "enabled"],
    shadowRange:       ["decoration", "shadow", "range"],
    shadowRenderPower: ["decoration", "shadow", "render_power"],
    animationsEnabled: ["animations", "enabled"]
  })

  function luaTable(path, value) {
    const v = (typeof value === "boolean") ? (value ? "true" : "false") : Number(value)
    let expr = String(v)
    for (let i = path.length - 1; i >= 0; i--) expr = "{ " + path[i] + " = " + expr + " }"
    return expr
  }

  // ─── Mango: clave → opción(es) de mango.conf ────────────────────
  readonly property var mangoOpts: ({
    gapsIn:            [{ opt: "gappih" }, { opt: "gappiv" }],
    gapsOut:           [{ opt: "gappoh" }, { opt: "gappov" }],
    borderSize:        [{ opt: "borderpx" }],
    rounding:          [{ opt: "border_radius" }],
    activeOpacity:     [{ opt: "focused_opacity" }],
    inactiveOpacity:   [{ opt: "unfocused_opacity" }],
    blurEnabled:       [{ opt: "blur", bool: true }],
    blurOptimized:     [{ opt: "blur_optimized", bool: true }],
    blurSize:          [{ opt: "blur_params_radius" }],
    blurPasses:        [{ opt: "blur_params_num_passes" }],
    shadowEnabled:     [{ opt: "shadows", bool: true }],
    shadowRange:       [{ opt: "shadows_size" }],
    animationsEnabled: [{ opt: "animations", bool: true }]
  })
  function mangoValue(spec, value) {
    if (spec.bool === true) return value ? "1" : "0"
    const n = Number(value)
    return isFinite(n) ? String(Math.round(n * 1000) / 1000) : "0"
  }
  function setoptionCmd(key, value) {
    const specs = root.mangoOpts[key]
    if (!specs) return ""
    return specs.map(sp => "mmsg dispatch 'setoption," + sp.opt + "," + root.mangoValue(sp, value) + "'").join("; ")
  }

  // ─── Aplicar en vivo ────────────────────────────────────────────
  Process {
    id: liveProc
    property string cmd: ""
    command: ["sh", "-c", liveProc.cmd]
    stdout: SplitParser { onRead: line => console.log("[appearance]", line) }
    stderr: SplitParser { onRead: line => console.log("[appearance] error:", line) }
  }
  function runLive(cmd) {
    if (cmd === "") return
    liveProc.cmd = cmd
    liveProc.running = false
    liveProc.running = true
  }

  // Preview mientras se arrastra un slider.
  //   Hyprland / Mango: directo al compositor, no toca disco.
  //   Niri: no tiene "setoption", pero recarga solo al guardar un archivo incluido:
  //   se reescribe theme.kdl con el valor de preview, como mucho cada 200 ms
  //   (throttle) para no recargar la config en cada pixel del slider.
  //   `current` = el estado de apariencia de la shell (para armar el theme completo).
  readonly property var niriLiveKeys: ["gapsOut", "borderSize", "rounding", "blurEnabled",
                                       "blurSize", "blurPasses", "shadowEnabled", "shadowRange"]
  property var niriPending: null
  Timer {
    id: niriLiveTimer
    interval: 200
    repeat: false
    onTriggered: {
      if (root.niriPending) { root.writeTheme(root.niriPending); root.niriPending = null }
    }
  }
  function applyLive(key, value, current) {
    switch (WM.wm) {
      case "hyprland": {
        const path = root.hyprPath[key]
        if (!path) return
        root.runLive("hyprctl eval 'hl.config(" + root.luaTable(path, value) + ")'")
        break
      }
      case "mango": root.runLive(root.setoptionCmd(key, value)); break
      case "niri": {
        if (root.niriLiveKeys.indexOf(key) < 0 || !current) return
        const merged = Object.assign({}, current)
        merged[key] = value
        root.niriPending = merged
        if (!niriLiveTimer.running) niriLiveTimer.start()
        break
      }
      default: break
    }
  }

  // Modo performance: blur / sombras / animaciones de un solo golpe
  function applyPerformance(a) {
    const t = v => v ? "true" : "false"
    switch (WM.wm) {
      case "hyprland":
        root.runLive("hyprctl eval 'hl.config({ decoration = { blur = { enabled = " + t(a.blurEnabled) +
          " }, shadow = { enabled = " + t(a.shadowEnabled) + " } }, animations = { enabled = " + t(a.animationsEnabled) + " } })'")
        break
      case "mango":
        root.runLive(["blurEnabled", "shadowEnabled", "animationsEnabled"].map(k => root.setoptionCmd(k, a[k])).join("; "))
        break
      default: break
    }
  }

  // Layout por defecto de todos los workspaces, en vivo
  function applyLayoutLive(name) {
    switch (WM.wm) {
      case "hyprland":
        // Un solo eval con un for, en vez de 10 llamadas
        root.runLive("hyprctl eval 'for i = 1, 10 do hl.workspace_rule({ workspace = tostring(i), layout = \"" + name + "\" }) end'")
        break
      case "mango": root.runLive("mmsg dispatch 'setlayout," + name + "'"); break
      default: break   // Niri: lo aplica el autogen (default-column-display)
    }
  }

  // ─── Archivos autogen ───────────────────────────────────────────
  readonly property string autogenDir: {
    switch (WM.wm) {
      case "mango": return root.home + "/.config/mango/autogen"
      case "niri":  return root.home + "/.config/niri/autogen"
      default:      return root.home + "/.config/hypr/modules/appearance/autogen"
    }
  }
  readonly property var fileNames: {
    switch (WM.wm) {
      case "mango": return { theme: "theme.conf", layout: "layout.conf", anim: "animprofile.conf" }
      case "niri":  return { theme: "theme.kdl",  layout: "layout.kdl",  anim: "animprofile.kdl" }
      default:      return { theme: "theme.lua",  layout: "layouta.lua", anim: "animprofile.lua" }
    }
  }
  readonly property string commentPrefix: WM.wm === "hyprland" ? "--" : (WM.wm === "niri" ? "//" : "#")
  function header(extra) {
    return root.commentPrefix + " Auto-generado por OozeShell (APPEARANCE). No editar a mano.\n" +
           (extra ? root.commentPrefix + " " + extra + "\n" : "")
  }

  // Cola de escritura: de a un archivo, atómico (temporal + rename)
  property var queue: []
  function writeFile(name, content, reloadCmd) {
    root.queue.push({ dir: root.autogenDir, name: name, content: content, reload: reloadCmd ?? [] })
    root.pump()
  }
  function pump() {
    if (writer.running || root.queue.length === 0) return
    const j = root.queue.shift()
    writer.job = j
    writer.running = true
  }
  Process {
    id: writer
    property var job: ({ dir: "", name: "", content: "", reload: [] })
    command: ["sh", "-c", 'mkdir -p "$1" && printf %s "$3" > "$1/$2.tmp" && mv "$1/$2.tmp" "$1/$2"',
              "sh", writer.job.dir, writer.job.name, writer.job.content]
    stderr: SplitParser { onRead: line => console.log("[autogen] error:", line) }
    onRunningChanged: {
      if (running) return
      if (writer.job.reload.length > 0) Quickshell.execDetached(writer.job.reload)
      root.pump()
    }
  }

  // Recarga explícita (Hyprland/Mango; Niri recarga solo al guardar)
  readonly property var reloadCommand: {
    switch (WM.wm) {
      case "mango": return ["mmsg", "dispatch", "reload_config"]
      case "niri":  return []
      default:      return ["hyprctl", "reload"]
    }
  }

  // ─── theme ──────────────────────────────────────────────────────
  function themeText(a) {
    const b = v => v ? 1 : 0
    const t = v => v ? "true" : "false"
    switch (WM.wm) {
      case "mango":
        return root.header("Se regenera cada vez que cambias algo desde el panel de apariencia.") +
          "gappih=" + a.gapsIn + "\ngappiv=" + a.gapsIn + "\ngappoh=" + a.gapsOut + "\ngappov=" + a.gapsOut + "\n" +
          "borderpx=" + a.borderSize + "\nborder_radius=" + a.rounding + "\n" +
          "focused_opacity=" + a.activeOpacity + "\nunfocused_opacity=" + a.inactiveOpacity + "\n" +
          "blur=" + b(a.blurEnabled) + "\nblur_optimized=" + b(a.blurOptimized ?? true) + "\n" +
          "blur_params_radius=" + a.blurSize + "\nblur_params_num_passes=" + Math.max(1, a.blurPasses) + "\n" +
          "shadows=" + b(a.shadowEnabled) + "\nshadows_size=" + a.shadowRange + "\n" +
          "animations=" + b(a.animationsEnabled) + "\n"

      case "niri": {
        // Solo propiedades que Niri documenta (Layout, Window Rules, Window Effects):
        //  • gaps: `layout { gaps N }` (internos y externos a la vez; Gaps in no aplica).
        //  • borde: si hay grosor se prende `border` y se apaga `focus-ring` (si no, Niri
        //    dibuja los dos encimados). Con grosor 0 no se toca el focus-ring: queda el tuyo.
        //  • esquinas: geometry-corner-radius + clip-to-geometry.
        //  • opacidad activa/inactiva: desactivada en Niri (no se escribe nada y los sliders
        //    se ocultan), para no pisar las reglas de opacidad por app de tu config.kdl.
        //  • blur: `background-effect { blur true }` + sección global `blur {}` (niri 26.04+).
        //    Sin `xray false` (es experimental); se ve solo con ventanas semitransparentes.
        //  • animaciones: viven TODAS en animprofile.kdl (off + perfil en un solo bloque).
        const bw = Math.max(0, Number(a.borderSize))
        let s = root.header("Se regenera cada vez que cambias algo desde el panel de apariencia.") +
          "layout {\n" +
          "    gaps " + a.gapsOut + "\n"
        if (bw > 0) s += "    focus-ring {\n        off\n    }\n" +
                         "    border {\n        on\n        width " + bw + "\n    }\n"
        else        s += "    border {\n        off\n    }\n"
        if (a.shadowEnabled) s += "    shadow {\n        on\n        softness " + Math.max(1, Number(a.shadowRange)) + "\n    }\n"
        else                 s += "    shadow {\n        off\n    }\n"
        s += "}\n\n" +
          "window-rule {\n" +
          "    geometry-corner-radius " + a.rounding + "\n" +
          "    clip-to-geometry true\n" +
          (a.blurEnabled ? "    background-effect {\n        blur true\n    }\n" : "") +
          "}\n"
        if (a.blurEnabled)
          s += "\nblur {\n    passes " + Math.max(1, Number(a.blurPasses)) + "\n    offset " + Math.max(1, Number(a.blurSize)).toFixed(1) + "\n}\n"
        return s
      }

      default:
        return root.header("Se regenera cada vez que cambiás algo desde el panel de apariencia.") +
          "return {\n" +
          "    gaps_in = " + a.gapsIn + ",\n    gaps_out = " + a.gapsOut + ",\n    border_size = " + a.borderSize + ",\n" +
          "    rounding = " + a.rounding + ",\n    rounding_power = " + a.roundingPower + ",\n" +
          "    active_opacity = " + a.activeOpacity + ",\n    inactive_opacity = " + a.inactiveOpacity + ",\n" +
          "    animations = " + t(a.animationsEnabled) + ",\n" +
          "    blur = {\n        enabled = " + t(a.blurEnabled) + ",\n        size = " + a.blurSize + ",\n        passes = " + a.blurPasses + ",\n    },\n" +
          "    shadow = {\n        enabled = " + t(a.shadowEnabled) + ",\n        range = " + a.shadowRange + ",\n        render_power = " + a.shadowRenderPower + ",\n    },\n" +
          "}\n"
    }
  }
  function writeTheme(a) { root.writeFile(root.fileNames.theme, root.themeText(a)) }

  // ─── layout ─────────────────────────────────────────────────────
  function layoutText(name) {
    const n = root.normalizeLayout(name)
    switch (WM.wm) {
      case "mango": {
        let s = root.header()
        for (let i = 1; i <= 9; i++) s += "tagrule=id:" + i + ",layout_name:" + n + "\n"
        return s
      }
      case "niri":
        // Niri solo tiene el layout de columnas; "tabbed" abre las columnas nuevas en pestañas
        return root.header() + "layout {\n    default-column-display \"" + n + "\"\n}\n"
      default:
        return root.header() + "return {\n    layout = \"" + n + "\",\n}\n"
    }
  }
  function writeLayout(name, reload) {
    root.writeFile(root.fileNames.layout, root.layoutText(name), reload === true ? root.reloadCommand : [])
  }

  // ─── perfil de animación ────────────────────────────────────────
  // Hyprland: solo el nombre (los valores viven en tu Lua).
  // Mango: valores resueltos acá. Niri: bloque `animations` completo (o `off`).
  readonly property var mangoAnimDefs: ({
    smooth:        { open: "slide", close: "slide", dOpen: 400, dMove: 500, dTag: 350, dClose: 800,
                     curve: "0.46,1.0,0.29,1", curveOpen: "0.46,1.0,0.29,1", curveClose: "0.08,0.92,0,1", fadeIn: 0.5 },
    snappy:        { open: "zoom",  close: "zoom",  dOpen: 250, dMove: 280, dTag: 220, dClose: 250,
                     curve: "0.2,0.9,0.3,1", curveOpen: "0.2,0.9,0.3,1", curveClose: "0.2,0.9,0.3,1", fadeIn: 0.7 },
    playful:       { open: "zoom",  close: "zoom",  dOpen: 500, dMove: 550, dTag: 400, dClose: 400,
                     curve: "0.34,1.4,0.64,1", curveOpen: "0.34,1.56,0.64,1", curveClose: "0.36,0,0.66,-0.2", fadeIn: 0.4 },
    minimal:       { open: "fade",  close: "fade",  dOpen: 120, dMove: 120, dTag: 100, dClose: 120,
                     curve: "0.5,0.5,0.5,0.5", curveOpen: "0.5,0.5,0.5,0.5", curveClose: "0.5,0.5,0.5,0.5", fadeIn: 0.0 },
    dramatic:      { open: "zoom",  close: "zoom",  dOpen: 800, dMove: 900, dTag: 600, dClose: 900,
                     curve: "0.65,0,0.35,1", curveOpen: "0.65,0,0.35,1", curveClose: "0.65,0,0.35,1", fadeIn: 0.2 },
    dramatic_side: { open: "slide", close: "slide", dOpen: 800, dMove: 900, dTag: 600, dClose: 900,
                     curve: "0.65,0,0.35,1", curveOpen: "0.65,0,0.35,1", curveClose: "0.65,0,0.35,1", fadeIn: 0.2 }
  })

  // Niri: perfiles reales. Las subsecciones de `animations` NO se mezclan entre includes,
  // se reemplazan enteras: por eso animprofile.kdl (incluido al final) pisa las de tu config.kdl.
  // Resorte = { s: stiffness, d: damping-ratio }; easing = { ms, curve }.
  // damping-ratio > 1.0 no se usa (la doc avisa de glitches numéricos).
  readonly property var niriAnimDefs: ({
    smooth: {
      ws:   { s: 900,  d: 1.0 }, hvm: { s: 700,  d: 1.0 }, wmv: { s: 700,  d: 1.0 },
      wrs:  { s: 700,  d: 1.0 }, ov:  { s: 700,  d: 1.0 }, cfg: { s: 1000, d: 0.6 },
      open: { ms: 180, curve: "ease-out-expo" }, close: { ms: 160, curve: "ease-out-quad" },
      shot: { ms: 200, curve: "ease-out-quad" }
    },
    snappy: {
      ws:   { s: 1400, d: 1.0 }, hvm: { s: 1300, d: 1.0 }, wmv: { s: 1300, d: 1.0 },
      wrs:  { s: 1300, d: 1.0 }, ov:  { s: 1200, d: 1.0 }, cfg: { s: 1400, d: 0.8 },
      open: { ms: 110, curve: "ease-out-quad" }, close: { ms: 100, curve: "ease-out-quad" },
      shot: { ms: 120, curve: "ease-out-quad" }
    },
    playful: {
      ws:   { s: 700,  d: 0.75 }, hvm: { s: 600, d: 0.8 }, wmv: { s: 650, d: 0.7 },
      wrs:  { s: 650,  d: 0.75 }, ov:  { s: 600, d: 0.8 }, cfg: { s: 900,  d: 0.5 },
      open: { ms: 300, curve: "ease-out-expo" }, close: { ms: 220, curve: "ease-out-cubic" },
      shot: { ms: 260, curve: "ease-out-cubic" }
    },
    minimal: {
      ws:   { s: 2000, d: 1.0 }, hvm: { s: 2000, d: 1.0 }, wmv: { s: 2000, d: 1.0 },
      wrs:  { s: 2000, d: 1.0 }, ov:  { s: 1800, d: 1.0 }, cfg: { s: 2000, d: 1.0 },
      open: { ms: 80,  curve: "linear" }, close: { ms: 70, curve: "linear" },
      shot: { ms: 80,  curve: "linear" }
    },
    dramatic: {
      ws:   { s: 300,  d: 1.0 }, hvm: { s: 280, d: 1.0 }, wmv: { s: 280, d: 1.0 },
      wrs:  { s: 280,  d: 1.0 }, ov:  { s: 280, d: 1.0 }, cfg: { s: 400,  d: 0.7 },
      open: { ms: 500, curve: "ease-out-expo" }, close: { ms: 450, curve: "ease-out-cubic" },
      shot: { ms: 400, curve: "ease-out-cubic" }
    },
    dramatic_side: {
      ws:   { s: 400,  d: 1.0 }, hvm: { s: 200, d: 1.0 }, wmv: { s: 200, d: 1.0 },
      wrs:  { s: 220,  d: 1.0 }, ov:  { s: 300, d: 1.0 }, cfg: { s: 400,  d: 0.7 },
      open: { ms: 650, curve: "ease-out-cubic" }, close: { ms: 550, curve: "ease-out-cubic" },
      shot: { ms: 400, curve: "ease-out-cubic" }
    }
  })
  function niriSpring(n, v) { return "    " + n + " {\n        spring damping-ratio=" + v.d.toFixed(2) + " stiffness=" + v.s + " epsilon=0.0001\n    }\n" }
  function niriEase(n, v)   { return "    " + n + " {\n        duration-ms " + v.ms + "\n        curve \"" + v.curve + "\"\n    }\n" }
  function niriAnimText(name, enabled) {
    if (!enabled) return "animations {\n    off\n}\n"
    const d = root.niriAnimDefs[name]
    return "animations {\n" +
      root.niriSpring("workspace-switch", d.ws) + root.niriEase("window-open", d.open) +
      root.niriEase("window-close", d.close) + root.niriSpring("horizontal-view-movement", d.hvm) +
      root.niriSpring("window-movement", d.wmv) + root.niriSpring("window-resize", d.wrs) +
      root.niriSpring("config-notification-open-close", d.cfg) + root.niriEase("screenshot-ui-open", d.shot) +
      root.niriSpring("overview-open-close", d.ov) + "}\n"
  }

  function animText(profile, animationsEnabled) {
    const enabled = animationsEnabled !== false
    const name = root.animProfileNames.indexOf(profile) >= 0 ? profile : "smooth"
    switch (WM.wm) {
      case "mango": {
        const d = root.mangoAnimDefs[name]
        return root.header("Perfil: " + name) +
          "animation_type_open=" + d.open + "\nanimation_type_close=" + d.close + "\n" +
          "layer_animation_type_open=" + d.open + "\nlayer_animation_type_close=" + d.close + "\n" +
          "fadein_begin_opacity=" + d.fadeIn + "\n" +
          "animation_duration_open=" + d.dOpen + "\nanimation_duration_move=" + d.dMove + "\n" +
          "animation_duration_tag=" + d.dTag + "\nanimation_duration_close=" + d.dClose + "\n" +
          "animation_curve_open=" + d.curveOpen + "\nanimation_curve_move=" + d.curve + "\n" +
          "animation_curve_tag=" + d.curve + "\nanimation_curve_close=" + d.curveClose + "\n"
      }
      case "niri":
        // Todo `animations` va acá (off o perfil completo), así no hay dos bloques peleando.
        return root.header("Perfil: " + name) + root.niriAnimText(name, enabled)
      default:
        return root.header() + "return {\n    profile = \"" + name + "\",\n}\n"
    }
  }
  function writeAnimProfile(profile, reload, enabled) {
    root.writeFile(root.fileNames.anim, root.animText(profile, enabled !== false), reload === true ? root.reloadCommand : [])
  }

  // Todo junto, sin recargar (arranque: que los archivos existan siempre)
  function ensureAutogen(a) {
    root.writeTheme(a)
    root.writeLayout(a.layout, false)
    root.writeAnimProfile(a.animProfile, false, a.animationsEnabled)
  }
}
