// Launcher — lanzador de apps, ventanas, comandos y archivos (reemplaza a rofi).
// Atajo (IPC), ver shell.qml:
//   quickshell ipc -p .../shell.qml call -- launcher toggle
//   quickshell ipc -p .../shell.qml call -- launcher open apps|windows|run|files
//   quickshell ipc -p .../shell.qml call -- launcher close
//
// Calculadora: en el modo Apps, escribir una cuenta (2*(3+4), sqrt(16), 2^10…)
// muestra el resultado arriba; Enter lo copia al portapapeles (wl-copy).
//
// Requiere (solo el modo que lo use): hyprctl (Ventanas), xdg-open
// (Archivos), y una terminal (por defecto foot) para las apps con
// Terminal=true. El wallpaper sale de ~/.cache/awww/last (lo escribe Walls)
// y, si no está, de `awww query`.
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import "../COMMON"
import "../LANG"

Item {
  id: root

  property bool open: false
  property string targetScreen: ""
  signal closeRequested()

  // Modo con el que se abre (lo cambia el IPC: `launcher open windows`)
  property string startMode: "apps"
  // apps | windows | run | files
  property string mode: "apps"
  // Terminal para apps con Terminal=true y Ctrl+Enter en "Ejecutar"
  // (se elige en Ajustes → General; por defecto foot)
  readonly property var terminal: Theme.terminalCmd

  // true = cuelga de la barra · false = centrado (Ajustes → General)
  readonly property bool attached: Theme.launcherAttached

  // Animaciones "fancy" (partículas + brillos): general (Efectos) Y el
  // interruptor fino propio del Launcher, los dos tienen que estar
  // prendidos (Ajustes → General → Launcher → Efectos)
  readonly property bool fancyFxActive: Theme.effectsOn && Theme.launcherParticlesEnabled

  // ─── Medidas (lógicas: FusedPanel las escala según Ajustes → Ventanas) ──
  // Tamaño (Ajustes → General → Launcher): compacto · normal · grande.
  // Cambian las MEDIDAS del panel (más o menos filas y ancho), no el zoom:
  // para eso está Ajustes → Ventanas.
  readonly property var sizes: [
    { imageW: 440, listW: 400, cardH: 420, rowH: 42 },
    { imageW: 540, listW: 460, cardH: 504, rowH: 46 },
    { imageW: 640, listW: 540, cardH: 600, rowH: 50 }
  ]
  readonly property var sz: root.sizes[Theme.launcherSize] ?? root.sizes[1]
  // Imagen apagada: el panel es solo la lista (un poco más ancha, para que
  // no quede angosto y alto) y el título pasa arriba de la búsqueda
  readonly property bool showImage: Theme.launcherShowImage
  readonly property int imageW: root.showImage ? root.sz.imageW : 0
  readonly property int listW: root.showImage ? root.sz.listW : root.sz.listW + 100
  readonly property int cardW: root.imageW + root.listW
  readonly property int cardH: root.sz.cardH
  readonly property int pad: 16
  readonly property int rowH: root.sz.rowH
  readonly property int rowGap: 2

  // Curvas de la unión con la barra y esquinas del lado opuesto (más
  // generosas que las de otros popups: el launcher es grande)
  readonly property real flareSize: 30
  readonly property real cornerSize: 26

  // true un instante tras abrir / cambiar de modo: las filas que se crean en
  // ese lapso entran una tras otra (fundido + deslizamiento). Después, las
  // que aparecen al filtrar o al desplazarse lo hacen sin retraso.
  property bool entering: false
  Timer {
    id: enterTimer
    interval: 500
    repeat: false
    onTriggered: root.entering = false
  }
  function beginEnter() {
    // Sin efectos las filas aparecen de golpe
    if (!Theme.effectsOn) { root.entering = false; return }
    root.entering = true
    enterTimer.restart()
  }

  readonly property var modes: [
    { id: "apps",    icon: "󰀻",  label: "launcherModeApps" },
    { id: "windows", icon: "󰖯",   label: "launcherModeWindows" },
    { id: "run",     icon: "󰆍",   label: "launcherModeRun" },
    { id: "files",   icon: "󰉋", label: "launcherModeFiles" }
  ]
  readonly property var modeInfo: modes.find(m => m.id === root.mode) ?? modes[0]

  // ─── Lo escrito y la selección ──────────────────────────────────
  readonly property string query: input.text
  property int selected: 0
  onQueryChanged: root.selected = 0

  // ═══ DATOS ═══════════════════════════════════════════════════════
  // Cada lista es un array de objetos { id, name, sub, hay: [{text, w}], … }.
  // `hay` son los textos (en minúsculas) contra los que filtra Fuzzy; se
  // arman UNA vez, no en cada tecla. Los objetos no se recrean al filtrar,
  // así ScriptModel solo mueve filas en vez de rehacerlas.

  // ─── Apps ───────────────────────────────────────────────────────
  readonly property var appItems: {
    const list = DesktopEntries.applications.values
    const out = []
    for (let i = 0; i < list.length; i++) {
      const e = list[i]
      if (!e || e.noDisplay) continue
      const name = e.name || e.id || ""
      if (name === "") continue
      const generic = e.genericName || ""
      out.push({
        id: e.id || name,
        name: name,
        sub: generic || e.comment || "",
        icon: e.icon || "",
        hay: [
          { text: name.toLowerCase(),                            w: 1.0  },
          { text: generic.toLowerCase(),                         w: 0.6  },
          { text: (e.keywords ? e.keywords.join(" ") : "").toLowerCase(), w: 0.5 },
          { text: (e.id || "").toLowerCase(),                    w: 0.4  },
          { text: (e.comment || "").toLowerCase(),               w: 0.25 }
        ]
      })
    }
    out.sort((a, b) => a.name.localeCompare(b.name))
    return out
  }

  // ─── Ventanas (hyprctl clients -j) ──────────────────────────────
  property var clients: []
  property string lastClientsRaw: ""
  property bool clientsDirty: false

  readonly property var windowItems: {
    const list = root.clients.slice()
    // Las usadas hace más poco primero; la que tiene el foco ahora, al final
    // (no tiene sentido elegirla)
    list.sort((a, b) => {
      const ka = a.focusHistoryID === 0 ? 1e6 : a.focusHistoryID
      const kb = b.focusHistoryID === 0 ? 1e6 : b.focusHistoryID
      return ka - kb
    })
    const out = []
    for (let i = 0; i < list.length; i++) {
      const c = list[i]
      const cls = c["class"] || c.initialClass || ""
      const title = c.title || cls
      const ws = c.workspace ? String(c.workspace.name) : ""
      out.push({
        id: c.address,
        name: title,
        sub: cls + (ws !== "" ? "  ·  " + ws : ""),
        cls: cls,
        address: c.address,
        hay: [
          { text: title.toLowerCase(), w: 1.0 },
          { text: cls.toLowerCase(),   w: 0.8 },
          { text: ws.toLowerCase(),    w: 0.2 }
        ]
      })
    }
    return out
  }

  function refreshClients() {
    if (clientsProc.running) root.clientsDirty = true
    else clientsProc.running = true
  }

  Process {
    id: clientsProc
    command: ["hyprctl", "clients", "-j"]
    property string buffer: ""
    stdout: SplitParser { onRead: line => clientsProc.buffer += line }
    onRunningChanged: {
      if (running) return
      const raw = buffer
      buffer = ""
      if (raw !== "" && raw !== root.lastClientsRaw) {
        try {
          root.clients = JSON.parse(raw).filter(c => c.mapped !== false && !c.hidden)
          root.lastClientsRaw = raw
        } catch (e) {
          console.log("Launcher: error leyendo hyprctl clients:", e)
        }
      }
      // Llegó un evento mientras leía: una vuelta más
      if (root.clientsDirty) {
        root.clientsDirty = false
        Qt.callLater(() => root.refreshClients())
      }
    }
  }

  // Con el modo Ventanas abierto, la lista sigue a Hyprland (ventana nueva,
  // cerrada, con foco…). Se agrupa en 150 ms.
  Timer {
    id: clientsTimer
    interval: 150
    repeat: false
    onTriggered: root.refreshClients()
  }
  Connections {
    target: Hyprland
    enabled: root.open && root.mode === "windows"
    function onRawEvent(event) { clientsTimer.restart() }
  }

  // ─── Ejecutar (ejecutables del $PATH) ───────────────────────────
  property var runNames: []
  property int runGen: 0

  readonly property var runItems: root.runNames.map(n => ({
    id: n, name: n, sub: "",
    hay: [{ text: n.toLowerCase(), w: 1.0 }]
  }))

  function loadRun() {
    runProc.buf = []
    runProc.gotGen = false
    runProc.valid = false
    root.runGen++
    runProc.running = false
    runProc.running = true
  }

  // La primera línea de salida es el número de "generación": si el proceso
  // se reinicia a mitad de camino, lo que llegue del viejo se descarta.
  Process {
    id: runProc
    property var buf: []
    property bool gotGen: false
    property bool valid: false
    command: ["sh", "-c",
      'echo "$1"; IFS=:; for d in $PATH; do ' +
      '[ -d "$d" ] && find -L "$d" -maxdepth 1 -type f -executable -printf "%f\\n" 2>/dev/null; ' +
      'done | LC_ALL=C sort -u',
      "sh", String(root.runGen)]
    stdout: SplitParser {
      onRead: line => {
        if (!runProc.gotGen) {
          runProc.gotGen = true
          runProc.valid = (line === String(root.runGen))
          return
        }
        if (runProc.valid && line !== "") runProc.buf.push(line)
      }
    }
    onRunningChanged: {
      if (running || !runProc.valid) return
      root.runNames = runProc.buf.slice()
    }
  }

  // ─── Archivos ───────────────────────────────────────────────────
  property string browseDir: Quickshell.env("HOME")
  property bool showHidden: false
  property var fileLines: []
  property bool fileError: false
  property int fileGen: 0

  function parentOf(dir) {
    const i = dir.lastIndexOf("/")
    return i <= 0 ? "/" : dir.slice(0, i)
  }

  // /home/yo/Docs → ~/Docs
  function prettyDir(dir) {
    const home = Quickshell.env("HOME")
    if (home && dir === home) return "~"
    if (home && dir.indexOf(home + "/") === 0) return "~" + dir.slice(home.length)
    return dir
  }

  readonly property var fileItems: {
    const dir = root.browseDir
    const out = []
    if (dir !== "/") {
      const up = root.parentOf(dir)
      out.push({ id: "..", name: "..", sub: root.prettyDir(up), isDir: true,
                 path: up, hay: [{ text: "..", w: 1.0 }] })
    }
    const lines = root.fileLines
    for (let i = 0; i < lines.length; i++) {
      const l = lines[i]
      const isDir = l.charAt(l.length - 1) === "/"
      const name = isDir ? l.slice(0, -1) : l
      if (name === "") continue
      const path = (dir === "/" ? "" : dir) + "/" + name
      out.push({ id: path, name: name, sub: "", isDir: isDir, path: path,
                 hay: [{ text: name.toLowerCase(), w: 1.0 }] })
    }
    return out
  }

  function loadDir() {
    fileProc.buf = []
    fileProc.gotGen = false
    fileProc.valid = false
    root.fileGen++
    fileProc.running = false
    fileProc.running = true
  }

  function browse(dir) {
    root.browseDir = dir
    // Lo del directorio anterior se descarta YA: hasta que llegue lo nuevo
    // las filas tendrían rutas que ya no corresponden
    root.fileLines = []
    root.fileError = false
    input.text = ""
    root.selected = 0
    root.loadDir()
  }

  Process {
    id: fileProc
    property var buf: []
    property bool gotGen: false
    property bool valid: false
    // -1 una por línea · -p agrega "/" a las carpetas · -L sigue los enlaces
    // (un enlace a carpeta cuenta como carpeta) · carpetas primero
    command: ["sh", "-c",
      'echo "$1"; cd -- "$2" 2>/dev/null || { echo __ERR__; exit 0; }; ' +
      'ls -1pL $3 --group-directories-first 2>/dev/null',
      "sh", String(root.fileGen), root.browseDir, root.showHidden ? "-A" : ""]
    stdout: SplitParser {
      onRead: line => {
        if (!fileProc.gotGen) {
          fileProc.gotGen = true
          fileProc.valid = (line === String(root.fileGen))
          return
        }
        if (fileProc.valid && line !== "") fileProc.buf.push(line)
      }
    }
    onRunningChanged: {
      if (running || !fileProc.valid) return
      const lines = fileProc.buf.slice()
      const bad = lines.length === 1 && lines[0] === "__ERR__"
      root.fileError = bad
      root.fileLines = bad ? [] : lines
    }
  }

  // ═══ CALCULADORA ═════════════════════════════════════════════════
  // En el modo Apps, si lo escrito es una cuenta ("2*(3+4)", "sqrt(16)/2",
  // "2^10", "15 % 4"), aparece arriba de todo una fila con el resultado;
  // Enter lo copia al portapapeles (wl-copy, paquete wl-clipboard) y cierra.
  //
  // NO usa eval(): es un parser propio (descenso recursivo) que solo
  // entiende números, + - * / % ^ ( ), constantes y funciones de abajo.
  // Cualquier otra cosa (nombres de apps, "7zip", "gtk-3"…) falla al
  // parsear y devuelve null, así que el buscador de apps no se ve afectado.
  // Hace falta al menos un operador o una función: un "5" o un "pi" solos
  // siguen siendo búsqueda normal. La coma vale como punto decimal.
  //   Constantes: pi, e
  //   Funciones (1 argumento): sqrt cbrt abs floor ceil round exp ln log
  //   log2 sin cos tan asin acos atan   (trigonométricas en radianes)
  readonly property var calcFuncs: ({
    sqrt: Math.sqrt, cbrt: Math.cbrt, abs: Math.abs, floor: Math.floor,
    ceil: Math.ceil, round: Math.round, exp: Math.exp, ln: Math.log,
    log: Math.log10, log2: Math.log2, sin: Math.sin, cos: Math.cos,
    tan: Math.tan, asin: Math.asin, acos: Math.acos, atan: Math.atan
  })
  readonly property var calcConsts: ({ pi: Math.PI, e: Math.E })

  // → { value: "14", expr: "2*(3+4)" } o null si no es una cuenta válida
  function calcEval(text) {
    let src = (text ?? "").trim().toLowerCase()
    if (src === "") return null
    src = src.replace(/×/g, "*").replace(/÷/g, "/").replace(/\*\*/g, "^")
             .replace(/,/g, ".").replace(/π/g, "pi")

    // ── Tokens ──
    const toks = []
    let i = 0
    while (i < src.length) {
      const rest = src.slice(i)
      let m
      if (/^\s/.test(rest)) { i++; continue }
      if ((m = /^(\d+\.?\d*|\.\d+)/.exec(rest))) { toks.push({ t: "n", v: parseFloat(m[1]) }); i += m[1].length; continue }
      if ((m = /^[a-z_][a-z0-9_]*/.exec(rest))) { toks.push({ t: "id", v: m[0] }); i += m[0].length; continue }
      if ("+-*/%^()".indexOf(rest[0]) >= 0) { toks.push({ t: "op", v: rest[0] }); i++; continue }
      return null
    }
    if (toks.length === 0) return null

    // ── Parser ──
    let pos = 0
    let used = false   // hubo operador binario o llamada a función
    const peek = () => toks[pos]
    const isOp = v => pos < toks.length && toks[pos].t === "op" && toks[pos].v === v
    const fail = () => { throw new Error("calc") }

    function expr() {
      let v = term()
      while (isOp("+") || isOp("-")) {
        const op = toks[pos++].v
        const r = term()
        used = true
        v = op === "+" ? v + r : v - r
      }
      return v
    }
    function term() {
      let v = unary()
      while (isOp("*") || isOp("/") || isOp("%")) {
        const op = toks[pos++].v
        const r = unary()
        used = true
        v = op === "*" ? v * r : op === "/" ? v / r : v % r
      }
      return v
    }
    function unary() {
      if (isOp("-")) { pos++; return -unary() }
      if (isOp("+")) { pos++; return unary() }
      return power()
    }
    function power() {
      const b = primary()
      if (isOp("^")) { pos++; used = true; return Math.pow(b, unary()) }
      return b
    }
    function primary() {
      const tk = peek()
      if (!tk) fail()
      if (tk.t === "n") { pos++; return tk.v }
      if (tk.t === "op" && tk.v === "(") {
        pos++
        const v = expr()
        if (!isOp(")")) fail()
        pos++
        return v
      }
      if (tk.t === "id") {
        pos++
        const has = Object.prototype.hasOwnProperty
        const fn = has.call(root.calcFuncs, tk.v) ? root.calcFuncs[tk.v] : null
        if (fn && isOp("(")) {
          pos++
          const v = expr()
          if (!isOp(")")) fail()
          pos++
          used = true
          return fn(v)
        }
        if (!fn && has.call(root.calcConsts, tk.v)) return root.calcConsts[tk.v]
      }
      fail()
    }

    let result
    try {
      result = expr()
      if (pos !== toks.length) return null
    } catch (e) {
      return null
    }
    if (!used || typeof result !== "number" || !isFinite(result)) return null

    // 12 cifras significativas: 0.1+0.2 → 0.3 (y no 0.30000000000000004)
    let out = String(Number(result.toPrecision(12)))
    if (out === "-0") out = "0"
    return { value: out, expr: (text ?? "").trim() }
  }

  readonly property var calcResult: root.mode === "apps" ? root.calcEval(root.query) : null

  // ═══ RESULTADOS ══════════════════════════════════════════════════
  readonly property var items:
      root.mode === "apps"    ? root.appItems
    : root.mode === "windows" ? root.windowItems
    : root.mode === "run"     ? root.runItems
    :                           root.fileItems

  // Lo que filtra. En "Ejecutar" solo cuenta la primera palabra: lo demás
  // son argumentos del comando.
  readonly property string filterText:
    root.mode === "run" ? (root.query.trim().split(/\s+/)[0] ?? "") : root.query

  // Lo que queda del modo actual filtrado (sin la fila de calculadora)
  readonly property var baseResults: {
    const src = root.items
    const terms = Fuzzy.terms(root.filterText)
    if (terms.length === 0) return src.length > 400 ? src.slice(0, 400) : src

    const scored = []
    for (let i = 0; i < src.length; i++) {
      const s = Fuzzy.match(terms, src[i].hay)
      if (s >= 0) scored.push({ it: src[i], s: s, i: i })
    }
    // Mejor puntaje primero; a igualdad, el orden original de la lista
    scored.sort((a, b) => (b.s - a.s) || (a.i - b.i))
    const out = []
    const n = Math.min(scored.length, 400)
    for (let i = 0; i < n; i++) out.push(scored[i].it)
    return out
  }

  // Con una cuenta válida, su resultado va primero (ver CALCULADORA arriba).
  // El id lleva la cuenta y el valor: así la fila se rehace en cada cambio
  // (ScriptModel identifica las filas por id).
  readonly property var results: {
    const c = root.calcResult
    if (!c) return root.baseResults
    return [{
      id: "__calc__" + c.expr + "=" + c.value,
      name: c.value,
      sub: c.expr + "  ·  " + Translations.t("launcherCalcCopy"),
      isCalc: true,
      value: c.value,
      hay: []
    }].concat(root.baseResults)
  }

  readonly property var current: root.results[root.selected] ?? null

  // El ListView de abajo lee ESTO (displayResults), no results
  // directamente. Motivo: con la búsqueda difusa, results se
  // recalcula (y REORDENA casi entero) en cada letra tipeada, dentro
  // del mismo call stack que QQuickTextInput ya está usando para
  // procesar esa letra. Empujar esa lista tan grande directo al
  // ScriptModel (que hace diff por "id" para animar el reordenamiento)
  // desde ahí adentro puede hacer que Qt reciba dos tandas de
  // itemsMoved/itemsInserted superpuestas si se tipea rápido — y eso
  // crashea (SIGSEGV) dentro de QQmlDelegateModel. Qt.callLater junta
  // varias letras seguidas en una sola actualización, en el próximo
  // tick del loop en vez de en medio del actual, así el diff del
  // modelo nunca se re-entra a sí mismo.
  property var displayResults: root.results
  onResultsChanged: Qt.callLater(root.syncDisplayResults)
  function syncDisplayResults() { root.displayResults = root.results }

  // ═══ ACCIONES ════════════════════════════════════════════════════
  function move(delta) {
    const n = root.results.length
    if (n === 0) return
    root.selected = Math.max(0, Math.min(n - 1, root.selected + delta))
  }

  function setMode(id) {
    if (id === root.mode) return
    root.mode = id
  }

  function cycleMode(delta) {
    const i = root.modes.findIndex(m => m.id === root.mode)
    const n = root.modes.length
    root.setMode(root.modes[(i + delta + n) % n].id)
  }

  // Cambió de modo: se empieza de cero y se cargan los datos que haga falta
  onModeChanged: {
    input.text = ""
    root.selected = 0
    root.beginEnter()
    root.ensureData()
  }

  function ensureData() {
    if (!root.open) return
    if (root.mode === "windows") root.refreshClients()
    else if (root.mode === "run") root.loadRun()
    else if (root.mode === "files") root.loadDir()
  }

  // El item ya no guarda el DesktopEntry (un objeto vivo dentro del
  // ScriptModel puede liberarse mientras el modelo lo usa → crash en
  // Quickshell 0.3.0). Se busca por id justo al lanzar.
  function findEntry(id) {
    const list = DesktopEntries.applications.values
    for (let i = 0; i < list.length; i++) {
      const e = list[i]
      if (e && e.id === id) return e
    }
    return null
  }

  function launchApp(item) {
    if (!item) return
    const e = root.findEntry(item.id)
    if (!e) return
    if (e.runInTerminal) {
      // Sin los códigos de campo (%u, %F…): no hay archivos que pasarle
      const cmd = (e.command ?? []).filter(a => !/^%[a-zA-Z]$/.test(a))
      Quickshell.execDetached(root.terminal.concat(cmd))
    } else {
      e.execute()
    }
    root.closeRequested()
  }

  // `inTerminal`: correrlo dentro de la terminal (Ctrl+Enter)
  function runCommand(cmd, inTerminal) {
    if (cmd === "") return
    if (inTerminal) Quickshell.execDetached(root.terminal.concat(["sh", "-c", cmd]))
    else Quickshell.execDetached(["sh", "-c", cmd])
    root.closeRequested()
  }

  function activate(inTerminal) {
    const item = root.current
    const typed = root.query.trim()

    if (root.mode === "run") {
      // Con argumentos, o sin coincidencias: se ejecuta lo escrito tal cual
      if (typed !== "" && (/\s/.test(typed) || !item)) root.runCommand(typed, inTerminal)
      else if (item) root.runCommand(item.name, inTerminal)
      return
    }
    if (!item) return

    if (item.isCalc) {
      // Calculadora: copia el resultado (requiere wl-clipboard)
      Quickshell.execDetached(["wl-copy", item.value])
      root.closeRequested()
      return
    }
    if (root.mode === "apps") {
      root.launchApp(item)
    } else if (root.mode === "windows") {
      HyprDispatch.focusWindow(item.address)
      root.closeRequested()
    } else {
      if (item.isDir) root.browse(item.path)
      else {
        Quickshell.execDetached(["xdg-open", item.path])
        root.closeRequested()
      }
    }
  }

  // ═══ WALLPAPER (el "dummy" de rofi) ══════════════════════════════
  property string wallPath: ""
  // Mini clip animado del wallpaper en vivo ("" = no hay)
  property string wallClipPath: ""

  // Mismo origen que Walls (~/.cache/awww/last); si no hay, `awww query`
  // (como el script de rofi); si tampoco, el fallback de rofi si existe.
  // Con un wallpaper en vivo (Walls → Live) `last` apunta a un fotograma del
  // video y ~/.cache/oozeshell/live-active guarda el video: si Walls ya generó
  // su mini clip animado (<md5 de la ruta>-preview.gif) se usa también, para
  // que el launcher se mueva igual que el fondo.
  // Salida: una línea "W:<imagen>" y otra "C:<clip o vacío>".
  Process {
    id: wallProc
    property string img: ""
    property string clip: ""
    command: ["sh", "-c",
      'wp=$(cat "$HOME/.cache/awww/last" 2>/dev/null); ' +
      '[ -f "$wp" ] || wp=$(awww query 2>/dev/null | grep -oP "(?<=image: ).*" | head -n1); ' +
      '[ -f "$wp" ] || { [ -f "$HOME/.config/rofi/fallback.jpg" ] && wp="$HOME/.config/rofi/fallback.jpg"; }; ' +
      'clip=""; v=$(cat "$HOME/.cache/oozeshell/live-active" 2>/dev/null); ' +
      'if [ -n "$v" ]; then c="$HOME/.cache/oozeshell/live/$(printf %s "$v" | md5sum | cut -d" " -f1)-preview.gif"; ' +
      '[ -f "$c" ] && clip="$c"; fi; ' +
      'printf "W:%s\\nC:%s\\n" "$wp" "$clip"']
    stdout: SplitParser {
      onRead: line => {
        if (line.startsWith("W:")) wallProc.img = line.slice(2)
        else if (line.startsWith("C:")) wallProc.clip = line.slice(2)
      }
    }
    onRunningChanged: {
      if (running) return
      root.wallPath = wallProc.img.trim()
      root.wallClipPath = wallProc.clip.trim()
      wallProc.img = ""
      wallProc.clip = ""
    }
  }

  // Ruta → URL (con espacios, tildes, # …)
  function toUrl(path) {
    return path === "" ? "" : "file://" + path.split("/").map(encodeURIComponent).join("/")
  }
  readonly property url wallUrl: root.toUrl(root.wallPath)
  readonly property url wallClipUrl: root.toUrl(root.wallClipPath)

  // ═══ APERTURA ════════════════════════════════════════════════════
  onOpenChanged: {
    if (!root.open) return
    // Primero el estado del explorador, DESPUÉS el modo: cambiar de modo
    // dispara la carga de datos (onModeChanged) y tiene que ver lo nuevo
    root.beginEnter()
    root.showHidden = false
    root.browseDir = Quickshell.env("HOME")
    root.fileLines = []
    root.fileError = false
    input.text = ""
    root.selected = 0
    const modeChanged = root.mode !== root.startMode
    root.mode = root.startMode
    if (!modeChanged) root.ensureData()
    if (!wallProc.running) wallProc.running = true
    // FusedWindow le da el foco a su propio capturador de teclas al
    // activarse; acá se lo pedimos DESPUÉS
    Qt.callLater(() => input.forceActiveFocus())
    focusTimer.restart()
  }

  Timer {
    id: focusTimer
    interval: 120
    repeat: false
    onTriggered: if (root.open && !input.activeFocus) input.forceActiveFocus()
  }

  // ═══ UI ══════════════════════════════════════════════════════════
  FusedWindow {
    id: fw
    active: root.open || panel.shown
    targetScreen: root.targetScreen
    namespace: "oozeshell-launcher"
    // Modal: toma el teclado apenas se abre (sin clic previo)
    exclusiveKeys: true
    onCloseRequested: root.closeRequested()
    // Si el foco se fue del campo (clic en una fila…), la primera tecla lo
    // recupera y no se pierde
    onKeyPressed: (key, modifiers, text) => {
      input.forceActiveFocus()
      if (text.length === 1 && text.charCodeAt(0) >= 32 && (modifiers & Qt.ControlModifier) === 0)
        input.text += text
    }

    // ── Partículas ambiente ("polvo mágico") ──────────────────────
    // Detrás de la tarjeta, a pantalla completa. Ver Launcher/LauncherParticles.qml.
    LauncherParticles {
      anchors.fill: parent
      active: root.open && root.fancyFxActive
    }

    FusedPanel {
      id: panel

      open: root.open
      panelWidth: root.cardW
      contentHeight: root.cardH
      align: "center"

      // ── Ubicación: conectado a la barra o centrado ─────────────
      // Centrado = tarjeta flotante (sin curvas cóncavas, 4 esquinas
      // redondas, aparece con fundido + escala) puesta en el medio de la
      // pantalla. Conectado = como siempre: FusedPanel se coloca solo.
      // (Sin curvas no hace falta el margen de las curvas: cuerpo = panel.)
      flare: root.flareSize
      bodyRadius: root.cornerSize
      detached: !root.attached || fw.detached
      flareStart: root.attached
      flareEnd: root.attached
      x: root.attached ? (panel.vertical ? panel.placedDepth : panel.placedAlong)
                       : Math.round((panel.hostWidth - panel.width) / 2)
      y: root.attached ? (panel.vertical ? panel.placedAlong : panel.placedDepth)
                       : Math.round((panel.hostHeight - panel.height) / 2)

      // ── Wallpaper, a la izquierda, recortado con la silueta del panel ──
      // (las medidas del backdrop ya vienen escaladas: de ahí scaleFactor)
      backdrop: [
        Item {
          id: wall
          // Entero: con un ancho fraccionario el borde derecho cae a medio
          // píxel y, con los efectos (zoom/deriva del wallpaper), la imagen
          // se asomaba 1px por fuera del recorte (línea de color al costado).
          width: Math.round(root.imageW * panel.scaleFactor)
          height: parent.height
          visible: root.showImage
          // Sin esto la imagen, al hacer zoom, se saldría hacia la lista
          clip: true

          // Solo se anima con el launcher abierto y a la vista
          readonly property bool live: root.open && root.showImage
          // Efectos (zoom, resplandor, clip animado): además, con el interruptor
          // de Ajustes → General → Efectos encendido
          readonly property bool fx: wall.live && Theme.effectsOn
          // Clip animado (gif) del wallpaper en vivo: interruptor FINO aparte
          // de "fx" (Ajustes → General → Launcher → Wallpaper animado), así
          // se puede tener las partículas y/o el zoom prendidos SIN el gif
          // (o al revés, el gif sin partículas).
          readonly property bool liveGif: wall.fx && Theme.launcherWallpaperLiveEnabled
          onFxChanged: { if (!wall.fx) wallMotion.drift = 0 }

          Rectangle { anchors.fill: parent; color: Theme.surface }

          // Imagen con un "Ken Burns" muy lento: zoom y desplazamiento suaves
          // que van y vienen, para que el fondo respire en vez de verse estático
          Item {
            id: wallMotion
            anchors.fill: parent
            transformOrigin: Item.Center

            property real drift: 0        // 0 ↔ 1
            scale: 1.0 + 0.07 * drift
            transform: Translate { x: -12 * wallMotion.drift * panel.scaleFactor
                                   y: -8 * wallMotion.drift * panel.scaleFactor }

            SequentialAnimation on drift {
              running: wall.fx && Theme.uiAnimationsEnabled
              loops: Animation.Infinite
              NumberAnimation { from: 0; to: 1; duration: Theme.animDuration(16000); easing.type: Easing.InOutSine }
              NumberAnimation { from: 1; to: 0; duration: Theme.animDuration(16000); easing.type: Easing.InOutSine }
            }

            Image {
              id: wallImg
              anchors.fill: parent
              source: root.showImage ? root.wallUrl : ""
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
              smooth: true
              sourceSize.height: 1200
              opacity: status === Image.Ready ? 1.0 : 0.0
              Behavior on opacity { NumberAnimation { duration: Theme.animDuration(400) } }
            }

            // Wallpaper en vivo: si Walls ya hizo su clip animado, se ve aquí
            AnimatedImage {
              id: wallClip
              anchors.fill: parent
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
              smooth: true
              cache: true
              source: (wall.liveGif && root.wallClipPath !== "") ? root.wallClipUrl : ""
              playing: wall.liveGif && status === AnimatedImage.Ready && Theme.uiAnimationsEnabled
              opacity: status === AnimatedImage.Ready ? 1.0 : 0.0
              Behavior on opacity { NumberAnimation { duration: Theme.animDuration(500) } }
            }
          }

          // Resplandor del color del tema que deriva despacio por la imagen
          Shape {
            id: orb
            readonly property real d: 420 * panel.scaleFactor
            width: orb.d
            height: orb.d
            x: wall.width * 0.05 + wall.width * 0.35 * orbMove.t
            y: wall.height * 0.10 + wall.height * 0.30 * (1 - orbMove.t)
            visible: opacity > 0.01
            opacity: wall.fx ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.animDuration(600) } }

            QtObject {
              id: orbMove
              property real t: 0
              SequentialAnimation on t {
                running: wall.fx && Theme.uiAnimationsEnabled
                loops: Animation.Infinite
                NumberAnimation { from: 0; to: 1; duration: Theme.animDuration(11000); easing.type: Easing.InOutSine }
                NumberAnimation { from: 1; to: 0; duration: Theme.animDuration(11000); easing.type: Easing.InOutSine }
              }
            }

            ShapePath {
              strokeWidth: -1
              strokeColor: "transparent"
              fillGradient: RadialGradient {
                centerX: orb.d / 2; centerY: orb.d / 2; centerRadius: orb.d / 2
                focalX: orb.d / 2; focalY: orb.d / 2
                GradientStop { position: 0.0; color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.32) }
                GradientStop { position: 1.0; color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.0) }
              }
              PathSvg { path: "M 0 0 L " + orb.d + " 0 L " + orb.d + " " + orb.d + " L 0 " + orb.d + " Z" }
            }
          }

          // Oscurece hacia abajo, para que el título se lea sobre cualquier fondo
          Rectangle {
            anchors.fill: parent
            gradient: Gradient {
              GradientStop { position: 0.45; color: "transparent" }
              GradientStop { position: 1.0;  color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.92) }
            }
          }

          // ── Difuminado "hacia la barra" ─────────────────────────
          // Franja ancha, sólida del lado de la barra y abriéndose hacia el
          // otro. Solo tiene sentido mientras el panel CUELGA de una barra
          // visible: en modo flotante (pantalla completa) o centrado se
          // funde y desaparece. Si la barra está a la derecha su cara cae del
          // lado de la lista (no del wallpaper), así que no hay nada que dibujar.
          Rectangle {
            id: barFade
            readonly property bool wanted: root.attached && !fw.detached && panel.edge !== "right"
            visible: opacity > 0.01
            opacity: barFade.wanted ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.animDuration(250) } }

            x: 0
            y: panel.edge === "bottom" ? parent.height - height : 0
            width: panel.vertical ? parent.width * 0.5 : parent.width
            height: panel.vertical ? parent.height : parent.height * 0.5
            // El degradado siempre nace sólido en su borde de arriba/izquierda;
            // con la barra abajo se gira 180° para que quede sólido del lado de ella
            rotation: panel.edge === "bottom" ? 180 : 0
            gradient: Gradient {
              orientation: panel.vertical ? Gradient.Horizontal : Gradient.Vertical
              GradientStop { position: 0.0; color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.85) }
              GradientStop { position: 1.0; color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.0) }
            }
          }

          // ── Difuminado "tocando la barra" ───────────────────────
          // Franja fina, exactamente del color del panel pegada a la cara de
          // la barra: el wallpaper nace de ella sin corte. Se queda en modo
          // flotante de pantalla completa (el panel sigue en su sitio); solo
          // se va al centrar el launcher.
          Rectangle {
            id: edgeFade
            readonly property real thick: 34 * panel.scaleFactor
            readonly property bool wanted: root.attached && panel.edge !== "right"
            visible: opacity > 0.01
            opacity: edgeFade.wanted ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.animDuration(250) } }

            x: 0
            y: panel.edge === "bottom" ? parent.height - height : 0
            width: panel.vertical ? edgeFade.thick : parent.width
            height: panel.vertical ? parent.height : edgeFade.thick
            rotation: panel.edge === "bottom" ? 180 : 0
            gradient: Gradient {
              orientation: panel.vertical ? Gradient.Horizontal : Gradient.Vertical
              GradientStop { position: 0.0; color: Theme.bg }
              GradientStop { position: 1.0; color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.0) }
            }
          }

          // Borde derecho: se funde con el color del panel (sin corte seco)
          Rectangle {
            anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
            width: 90 * panel.scaleFactor
            gradient: Gradient {
              orientation: Gradient.Horizontal
              GradientStop { position: 0.0; color: "transparent" }
              GradientStop { position: 1.0; color: Theme.bg }
            }
          }
        },

        // Costura: tapa la columna de píxeles justo pasado el borde del
        // wallpaper. Con "Efectos" prendidos la imagen se mueve/escala y el
        // recorte (clip) deja escapar 1px de ella ahí; esta tira del color
        // del panel lo cubre. Sin efectos no se nota (es del mismo color).
        Rectangle {
          x: wall.width
          width: 2
          height: parent.height
          visible: root.showImage
          color: Theme.bg
        }
      ]

      // ── Título sobre el wallpaper ──────────────────────────────
      Item {
        x: 0
        y: 0
        width: root.imageW
        height: root.cardH
        visible: root.showImage

        Column {
          id: titleCol
          anchors { left: parent.left; bottom: parent.bottom; leftMargin: 28; bottomMargin: 26 }
          spacing: 4

          // Al cambiar de modo el título entra deslizándose desde la izquierda
          transform: Translate { id: titleShift }
          Connections {
            target: root
            function onModeChanged() { if (Theme.effectsOn) titleIn.restart() }
          }
          ParallelAnimation {
            id: titleIn
            NumberAnimation { target: titleCol;   property: "opacity"; from: 0;   to: 1; duration: Theme.animDuration(260) }
            NumberAnimation { target: titleShift; property: "x";       from: -16; to: 0; duration: Theme.animDuration(320); easing.type: Easing.OutCubic }
          }

          // Barrita de acento sobre el título
          Rectangle {
            width: 34
            height: 3
            radius: 2
            color: Theme.primary
          }

          Text {
            text: Translations.t("launcherTitle" + root.mode.charAt(0).toUpperCase() + root.mode.slice(1))
            color: Theme.text
            font.pixelSize: Theme.fs(26)
            font.bold: true
          }
          Text {
            text: root.mode === "files"
              ? root.prettyDir(root.browseDir)
              : root.results.length + " / " + root.items.length
            color: Theme.subtext
            font.pixelSize: Theme.fs(13)
            font.family: Theme.fontFamily
          }
        }
      }

      // ── Columna derecha: buscador, lista, modos ────────────────
      ColumnLayout {
        x: root.imageW
        y: 0
        width: root.listW
        height: root.cardH
        spacing: 0

        Item { Layout.preferredHeight: root.pad }

        // ─── Título (solo sin imagen: con imagen va sobre ella) ─
        RowLayout {
          visible: !root.showImage
          Layout.fillWidth: true
          Layout.leftMargin: root.pad + 6
          Layout.rightMargin: root.pad + 6
          Layout.bottomMargin: 10
          spacing: 10

          Text {
            text: root.modeInfo.icon
            color: Theme.primary
            font.pixelSize: Theme.fs(22)
            font.family: Theme.monoFamily
          }
          Text {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: Translations.t("launcherTitle" + root.mode.charAt(0).toUpperCase() + root.mode.slice(1))
            color: Theme.text
            font.pixelSize: Theme.fs(20)
            font.bold: true
          }
          Text {
            text: root.mode === "files"
              ? root.prettyDir(root.browseDir)
              : root.results.length + " / " + root.items.length
            color: Theme.subtext
            font.pixelSize: Theme.fs(12)
            font.family: Theme.fontFamily
          }
        }

        // ─── Buscador ─────────────────────────────────────────
        Rectangle {
          Layout.fillWidth: true
          Layout.leftMargin: root.pad
          Layout.rightMargin: root.pad
          Layout.preferredHeight: 50
          radius: Theme.cardRadius
          color: Theme.surface
          // Aro del color del tema mientras se escribe
          border.width: input.activeFocus ? 1 : 0
          border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.55)
          Behavior on border.width { NumberAnimation { duration: Theme.animDuration(150) } }

          // Brillo suave alrededor, respirando, mientras está enfocado
          // (una de las animaciones "fancy" del Launcher — se apaga junto
          // con las demás desde Ajustes → General → Launcher → Efectos)
          Rectangle {
            anchors.fill: parent
            anchors.margins: -4
            radius: parent.radius + 4
            color: "transparent"
            border.width: 2
            border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.35)
            visible: input.activeFocus && root.fancyFxActive
            opacity: 0
            SequentialAnimation on opacity {
              running: (input.activeFocus && root.fancyFxActive) && Theme.uiAnimationsEnabled
              loops: Animation.Infinite
              NumberAnimation { from: 0.15; to: 0.6; duration: Theme.animDuration(900); easing.type: Easing.InOutSine }
              NumberAnimation { from: 0.6; to: 0.15; duration: Theme.animDuration(900); easing.type: Easing.InOutSine }
            }
          }

          RowLayout {
            anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
            spacing: 10

            Text {
              text: root.modeInfo.icon
              color: Theme.primary
              font.pixelSize: Theme.fs(20)
              font.family: Theme.monoFamily
            }

            Item {
              Layout.fillWidth: true
              Layout.fillHeight: true

              TextInput {
                id: input
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                color: Theme.text
                selectionColor: Theme.primary
                selectedTextColor: Theme.textOnPrimary
                font.pixelSize: Theme.fs(16)
                clip: true
                inputMethodHints: Qt.ImhNoPredictiveText

                Keys.onPressed: event => {
                  const ctrl = (event.modifiers & Qt.ControlModifier) !== 0
                  const alt  = (event.modifiers & Qt.AltModifier) !== 0

                  switch (event.key) {
                    case Qt.Key_Escape:
                      root.closeRequested()
                      event.accepted = true
                      return

                    case Qt.Key_Down:
                      root.move(1); event.accepted = true; return
                    case Qt.Key_Up:
                      root.move(-1); event.accepted = true; return
                    case Qt.Key_PageDown:
                      root.move(7); event.accepted = true; return
                    case Qt.Key_PageUp:
                      root.move(-7); event.accepted = true; return

                    case Qt.Key_Tab:
                      root.cycleMode(1); event.accepted = true; return
                    case Qt.Key_Backtab:
                      root.cycleMode(-1); event.accepted = true; return

                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                      root.activate(ctrl)
                      event.accepted = true
                      return

                    case Qt.Key_Backspace:
                      // Explorador: con la búsqueda vacía, sube una carpeta
                      if (root.mode === "files" && input.text === "" && root.browseDir !== "/") {
                        root.browse(root.parentOf(root.browseDir))
                        event.accepted = true
                      }
                      return
                  }

                  // Estilo vim / readline
                  if (ctrl) {
                    switch (event.key) {
                      case Qt.Key_N:
                      case Qt.Key_J:
                        root.move(1); event.accepted = true; return
                      case Qt.Key_P:
                      case Qt.Key_K:
                        root.move(-1); event.accepted = true; return
                      case Qt.Key_U:
                        input.text = ""; event.accepted = true; return
                      case Qt.Key_H:
                        if (root.mode === "files") {
                          root.showHidden = !root.showHidden
                          root.loadDir()
                          event.accepted = true
                        }
                        return
                    }
                  }

                  // Alt+1…4: ir directo a un modo
                  if (alt && event.key >= Qt.Key_1 && event.key <= Qt.Key_4) {
                    const m = root.modes[event.key - Qt.Key_1]
                    if (m) root.setMode(m.id)
                    event.accepted = true
                  }
                }
              }

              // Texto de ayuda mientras no hay nada escrito
              Text {
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                visible: input.text === ""
                elide: Text.ElideRight
                text: root.mode === "files"
                  ? Translations.t("launcherPhFiles") + " " + root.prettyDir(root.browseDir)
                  : Translations.t("launcherPh" + root.mode.charAt(0).toUpperCase() + root.mode.slice(1))
                color: Theme.subtext
                font.pixelSize: Theme.fs(16)
              }
            }

            Text {
              text: root.results.length
              color: Theme.subtext
              font.pixelSize: Theme.fs(12)
              font.family: Theme.fontFamily
            }
          }
        }

        Item { Layout.preferredHeight: 10 }

        // ─── Lista ────────────────────────────────────────────
        Item {
          Layout.fillWidth: true
          Layout.fillHeight: true
          Layout.leftMargin: root.pad - 6
          Layout.rightMargin: root.pad - 6

          ListView {
            id: list
            anchors.fill: parent
            clip: true
            spacing: root.rowGap
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height

            model: ScriptModel {
              values: root.displayResults
              objectProp: "id"
            }

            // Mantiene visible la fila elegida al moverse con el teclado
            Connections {
              target: root
              function onSelectedChanged() {
                list.positionViewAtIndex(root.selected, ListView.Contain)
              }
            }

            delegate: Item {
              id: row
              required property var modelData
              required property int index

              readonly property bool isCurrent: row.index === root.selected
              readonly property bool isFile: root.mode === "files"

              width: ListView.view.width
              height: root.rowH

              // Entrada escalonada (ver root.entering): las filas que nacen
              // justo al abrir / cambiar de modo aparecen una tras otra
              property bool revealed: false
              property bool instant: false
              opacity: row.revealed ? 1 : 0
              Behavior on opacity {
                enabled: !row.instant
                NumberAnimation { duration: Theme.animDuration(220) }
              }
              transform: Translate {
                y: row.revealed ? 0 : 10
                Behavior on y {
                  enabled: !row.instant
                  NumberAnimation { duration: Theme.animDuration(260); easing.type: Easing.OutCubic }
                }
              }
              Timer {
                id: revealTimer
                interval: 1 + Math.min(row.index, 9) * 26
                repeat: false
                onTriggered: row.revealed = true
              }
              Component.onCompleted: {
                if (root.entering) revealTimer.start()
                else { row.instant = true; row.revealed = true }
              }

              Rectangle {
                anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                radius: Theme.cardRadius - 2
                color: row.isCurrent ? Theme.surfaceHigh
                     : rowArea.containsMouse ? Theme.surface
                     : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }
              }

              // Brillo detrás de la barrita, respirando (misma familia que
              // el resto de las animaciones "fancy" del Launcher)
              Rectangle {
                visible: row.isCurrent && root.fancyFxActive
                width: 10
                height: 28
                radius: 5
                color: Theme.primary
                anchors { left: parent.left; leftMargin: 5; verticalCenter: parent.verticalCenter }
                opacity: 0.15
                SequentialAnimation on opacity {
                  running: (row.isCurrent && root.fancyFxActive) && Theme.uiAnimationsEnabled
                  loops: Animation.Infinite
                  NumberAnimation { from: 0.15; to: 0.45; duration: Theme.animDuration(900); easing.type: Easing.InOutSine }
                  NumberAnimation { from: 0.45; to: 0.15; duration: Theme.animDuration(900); easing.type: Easing.InOutSine }
                }
              }

              Rectangle {
                visible: row.isCurrent
                width: 3
                height: 22
                radius: 2
                color: Theme.primary
                anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
              }

              RowLayout {
                anchors { fill: parent; leftMargin: 22; rightMargin: 16 }
                spacing: 12

                // Ícono: la app / la ventana, o un glifo (comando, carpeta, archivo)
                Item {
                  Layout.preferredWidth: 28
                  Layout.preferredHeight: 28

                  AppIcon {
                    anchors.fill: parent
                    visible: (root.mode === "apps" && !row.modelData.isCalc) || root.mode === "windows"
                    size: 28
                    icon: root.mode === "apps" ? (row.modelData.icon ?? "") : ""
                    appId: root.mode === "windows" ? (row.modelData.cls ?? "") : ""
                  }

                  Text {
                    anchors.centerIn: parent
                    visible: root.mode === "run" || root.mode === "files" || !!row.modelData.isCalc
                    text: row.modelData.isCalc ? "󰃬"
                        : root.mode === "run" ? "󰆍"
                        : (row.modelData.isDir ? "󰉋" : "󰈔")
                    color: row.modelData.isCalc ? Theme.primary
                         : (row.isFile && row.modelData.isDir) ? Theme.primary : Theme.subtext
                    font.pixelSize: Theme.fs(22)
                    font.family: Theme.monoFamily
                  }
                }

                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: 0

                  Text {
                    Layout.fillWidth: true
                    text: row.modelData.isCalc ? "= " + row.modelData.name : row.modelData.name
                    elide: Text.ElideRight
                    color: Theme.text
                    font.pixelSize: Theme.fs(15)
                    font.bold: row.isCurrent || !!row.modelData.isCalc
                  }
                  Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: row.modelData.sub ?? ""
                    elide: Text.ElideRight
                    color: Theme.subtext
                    font.pixelSize: Theme.fs(11)
                  }
                }

                Text {
                  visible: row.isCurrent
                  text: "󰌑"
                  color: Theme.subtext
                  font.pixelSize: Theme.fs(14)
                  font.family: Theme.monoFamily
                }
              }

              MouseArea {
                id: rowArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.selected = row.index
                  root.activate(false)
                }
              }
            }
          }

          // ─── Estados vacíos ──────────────────────────────────
          Text {
            anchors.centerIn: parent
            width: parent.width - 48
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            visible: root.results.length === 0
            color: Theme.subtext
            font.pixelSize: Theme.fs(14)
            text: root.mode === "run" && root.query.trim() !== ""
                    ? Translations.t("launcherRunHint") + "  " + root.query.trim()
                : root.mode === "files"
                    ? (root.fileError ? Translations.t("launcherFolderError")
                       : root.query !== "" ? Translations.t("launcherEmpty")
                       : Translations.t("launcherFolderEmpty"))
                : Translations.t("launcherEmpty")
          }
        }

        Item { Layout.preferredHeight: 10 }

        // ─── Modos ────────────────────────────────────────────
        // Alto FIJO (mínimo = máximo = 40) y ancho repartido a mano. Antes los
        // botones usaban fillHeight dentro de un RowLayout sin tope de alto y
        // podían crecer hasta tapar la lista; ahora no pueden salirse de acá.
        Item {
          id: modeBar
          Layout.fillWidth: true
          Layout.leftMargin: root.pad
          Layout.rightMargin: root.pad
          Layout.preferredHeight: 40
          Layout.minimumHeight: 40
          Layout.maximumHeight: 40
          clip: true

          readonly property real gap: 6
          readonly property real btnW: (modeBar.width - modeBar.gap * (root.modes.length - 1)) / root.modes.length

          Repeater {
            model: root.modes

            delegate: Rectangle {
              id: modeBtn
              required property var modelData
              required property int index
              readonly property bool isCurrent: root.mode === modeBtn.modelData.id

              x: modeBtn.index * (modeBar.btnW + modeBar.gap)
              y: 0
              width: modeBar.btnW
              height: modeBar.height
              radius: Theme.cardRadius - 2
              color: modeBtn.isCurrent ? Theme.surface
                   : modeArea.containsMouse ? Theme.surface
                   : "transparent"
              border.width: modeBtn.isCurrent ? 1 : 0
              border.color: Theme.primary
              Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }

              Row {
                anchors.centerIn: parent
                spacing: 6

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: modeBtn.modelData.icon
                  color: modeBtn.isCurrent ? Theme.primary : Theme.subtext
                  font.pixelSize: Theme.fs(16)
                  font.family: Theme.monoFamily
                }
                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: Translations.t(modeBtn.modelData.label)
                  color: modeBtn.isCurrent ? Theme.text : Theme.subtext
                  font.pixelSize: Theme.fs(13)
                  font.bold: modeBtn.isCurrent
                }
              }

              MouseArea {
                id: modeArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.setMode(modeBtn.modelData.id)
                  input.forceActiveFocus()
                }
              }
            }
          }
        }

        Item { Layout.preferredHeight: 8 }

        // ─── Atajos ───────────────────────────────────────────
        Text {
          Layout.fillWidth: true
          Layout.leftMargin: root.pad + 4
          Layout.rightMargin: root.pad
          elide: Text.ElideRight
          text: Translations.t("launcherHint")
                + (root.mode === "files" ? "  ·  " + Translations.t("launcherHintFiles") : "")
                + (root.mode === "run"   ? "  ·  " + Translations.t("launcherHintRun")   : "")
          color: Theme.subtext
          font.pixelSize: Theme.fs(11)
          font.family: Theme.fontFamily
        }

        Item { Layout.preferredHeight: root.pad - 2 }
      }
    }
  }
}
