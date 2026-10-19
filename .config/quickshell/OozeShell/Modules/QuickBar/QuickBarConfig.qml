// QuickBarConfig — ajustes y lógica de QuickSearch (Modules/QuickBar/QuickBar.qml).

pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../COMMON"
import "../../Services/Lang"

Singleton {
  id: root


  property string position: "top"
  property string widthMode: "normal"


  property string browserId: "default"
  property bool privateWindow: false


  property string engineId: "google"
  property string engineCustom: ""
  property bool bangsEnabled: true


  property bool filesEnabled: true
  property string fileOpener: "nvim"
  property bool fileSmartOpen: true
  property string fileEditor: "nvim"
  property string fileRoots: "~"
  property int fileDepth: 6
  property bool fileHidden: false
  property int fileMax: 6


  property bool loaded: false

  readonly property string dir: Quickshell.env("HOME") + "/.config/oozeshell"
  readonly property string file: root.dir + "/quickbar.json"


  readonly property var browsers: [
    { id: "firefox",     name: "Firefox",        bins: ["firefox", "firefox-bin"],                           priv: ["--private-window"] },
    { id: "librewolf",   name: "LibreWolf",      bins: ["librewolf"],                                        priv: ["--private-window"] },
    { id: "zen",         name: "Zen",            bins: ["zen-browser", "zen"],                               priv: ["--private-window"] },
    { id: "floorp",      name: "Floorp",         bins: ["floorp"],                                           priv: ["--private-window"] },
    { id: "chromium",    name: "Chromium",       bins: ["chromium", "chromium-browser"],                     priv: ["--incognito"] },
    { id: "chrome",      name: "Google Chrome",  bins: ["google-chrome-stable", "google-chrome"],            priv: ["--incognito"] },
    { id: "brave",       name: "Brave",          bins: ["brave", "brave-browser", "brave-browser-stable"],   priv: ["--incognito"] },
    { id: "vivaldi",     name: "Vivaldi",        bins: ["vivaldi", "vivaldi-stable"],                        priv: ["--incognito"] },
    { id: "edge",        name: "Microsoft Edge", bins: ["microsoft-edge-stable", "microsoft-edge"],          priv: ["--inprivate"] },
    { id: "opera",       name: "Opera",          bins: ["opera"],                                            priv: ["--private"] },
    { id: "qutebrowser", name: "qutebrowser",    bins: ["qutebrowser"],                                      priv: ["--temp-basedir"] },
    { id: "epiphany",    name: "GNOME Web",      bins: ["epiphany"],                                         priv: ["--private-instance"] }
  ]


  property var installedBrowsers: []
  property var browserBins: ({})
  property bool detected: false

  function browserInfo(id) {
    for (let i = 0; i < root.browsers.length; i++)
      if (root.browsers[i].id === id) return root.browsers[i]
    return null
  }


  readonly property var browser: {
    const b = root.browserInfo(root.browserId)
    if (b && root.detected && root.browserBins[b.id] === undefined) return null
    return b
  }
  readonly property string browserName: root.browser ? root.browser.name : Translations.t("qbBrowserDefault")


  function browserCommand(url, priv) {
    const b = root.browser
    if (!b) return ["xdg-open", url]
    const bin = root.browserBins[b.id] ?? b.bins[0]
    return [bin].concat(priv ? b.priv : [], [url])
  }


  function openWeb(url, alt) {
    const priv = alt ? !root.privateWindow : root.privateWindow
    Quickshell.execDetached(root.browserCommand(url, priv))
  }


  readonly property var engines: [
    { id: "google",     name: "Google",     url: "https://www.google.com/search?q=%s" },
    { id: "duckduckgo", name: "DuckDuckGo", url: "https://duckduckgo.com/?q=%s" },
    { id: "brave",      name: "Brave",      url: "https://search.brave.com/search?q=%s" },
    { id: "startpage",  name: "Startpage",  url: "https://www.startpage.com/do/search?q=%s" },
    { id: "ecosia",     name: "Ecosia",     url: "https://www.ecosia.org/search?q=%s" },
    { id: "bing",       name: "Bing",       url: "https://www.bing.com/search?q=%s" }
  ]

  readonly property bool customValid: /^https?:\/\/\S*%s\S*$/i.test(root.engineCustom)


  readonly property var activeEngine: {
    if (root.engineId === "custom" && root.customValid)
      return { id: "custom", name: Translations.t("qbEngineCustom"), url: root.engineCustom }
    for (let i = 0; i < root.engines.length; i++)
      if (root.engines[i].id === root.engineId) return root.engines[i]
    return root.engines[0]
  }
  readonly property string engineName: root.activeEngine.name


  readonly property var bangs: [
    { id: "yt",     bare: true,  name: "YouTube",          url: "https://www.youtube.com/results?search_query=%s" },
    { id: "gh",     bare: true,  name: "GitHub",           url: "https://github.com/search?q=%s&type=repositories" },
    { id: "nix",    bare: true,  name: "NixOS packages",   url: "https://search.nixos.org/packages?query=%s" },
    { id: "aur",    bare: true,  name: "AUR",              url: "https://aur.archlinux.org/packages?K=%s" },
    { id: "mdn",    bare: true,  name: "MDN",              url: "https://developer.mozilla.org/search?q=%s" },
    { id: "imdb",   bare: true,  name: "IMDb",             url: "https://www.imdb.com/find/?q=%s" },
    { id: "wiki",   bare: false, name: "Wikipedia",        url: "https://{lang}.wikipedia.org/w/index.php?search=%s" },
    { id: "maps",   bare: false, name: "Google Maps",      url: "https://www.google.com/maps/search/%s" },
    { id: "tr",     bare: false, name: "Google Translate", url: "https://translate.google.com/?sl=auto&tl={lang}&text=%s&op=translate" },
    { id: "reddit", bare: false, name: "Reddit",           url: "https://www.reddit.com/search/?q=%s" },
    { id: "stack",  bare: false, name: "Stack Overflow",   url: "https://stackoverflow.com/search?q=%s" },
    { id: "img",    bare: false, name: "Google Images",    url: "https://www.google.com/search?tbm=isch&q=%s" },
    { id: "aw",     bare: false, name: "Arch Wiki",        url: "https://wiki.archlinux.org/index.php?search=%s" }
  ]

  function fillTemplate(tpl, term) {
    return tpl.split("%s").join(encodeURIComponent(term))
              .split("{lang}").join(Translations.current)
  }

  function searchUrl(term) { return root.fillTemplate(root.activeEngine.url, term) }


  function setOf(words) {
    const m = {}
    const list = words.split(" ")
    for (let i = 0; i < list.length; i++) m[list[i]] = true
    return m
  }

  readonly property var fileExts: root.setOf(
    "sh bash zsh fish py pyc md rs pl js mjs ts tsx jsx lua c h cpp hpp go java rb php css scss " +
    "json yaml yml toml ini cfg conf txt log csv xml lock nix qml service desktop rc sql swp bak tmp")


  function looksLikeUrl(text) {
    const s = String(text ?? "").trim()
    if (s === "" || /\s/.test(s)) return ""
    if (/^https?:\/\/\S+$/i.test(s)) return s
    if (/^(localhost|127\.0\.0\.1)(:\d+)?([\/?#]\S*)?$/i.test(s)) return "http://" + s
    if (/^\d{1,3}(\.\d{1,3}){3}(:\d+)?([\/?#]\S*)?$/.test(s)) return "http://" + s
    const m = s.match(/^((?:www\.)?(?:[a-z0-9-]+\.)+)([a-z]{2,24})(?::\d+)?(?:[\/?#]\S*)?$/i)
    if (!m) return ""
    if (/^www\./i.test(s) || (root.fileExts[m[2].toLowerCase()] !== true && root.externalExts[m[2].toLowerCase()] !== true)) return "https://" + s
    return ""
  }


  function classify(text) {
    const q = String(text ?? "").trim()
    if (q === "") return { kind: "empty", term: "", url: "", bang: null }

    if (root.filesEnabled) {
      const f = q.match(/^!?f\s+(.+)$/i)
      if (f) return { kind: "files", term: f[1].trim(), url: "", bang: null }
    }
    if (root.bangsEnabled) {
      const b = q.match(/^(!?)([a-z0-9]{2,8})\s+(.+)$/i)
      if (b) {
        const id = b[2].toLowerCase()
        for (let i = 0; i < root.bangs.length; i++) {
          const g = root.bangs[i]
          if (g.id === id && (g.bare || b[1] === "!"))
            return { kind: "bang", term: b[3].trim(), url: "", bang: g }
        }
      }
    }
    return { kind: "search", term: q, url: root.looksLikeUrl(q), bang: null }
  }


  readonly property var externalExts: root.setOf(
    "jpg jpeg png gif webp bmp ico tif tiff avif heic psd xcf kra " +
    "pdf epub djvu mobi " +
    "mp4 mkv webm avi mov wmv flv m4v mp3 flac ogg opus wav m4a aac " +
    "zip tar gz xz bz2 zst 7z rar iso " +
    "doc docx xls xlsx ppt pptx odt ods odp " +
    "ttf otf woff woff2 exe appimage")

  function isExternalType(path) {
    const name = path.slice(path.lastIndexOf("/") + 1)
    const dot = name.lastIndexOf(".")
    if (dot <= 0) return false
    return root.externalExts[name.slice(dot + 1).toLowerCase()] === true
  }

  function editorArgv() {
    const a = root.fileEditor.split(/\s+/).filter(s => s !== "")
    return a.length > 0 ? a : ["nvim"]
  }
  readonly property string editorBin: root.editorArgv()[0]


  function usesEditor(path, isDir, alt) {
    let ed = root.fileOpener === "nvim"
    if (ed && root.fileSmartOpen && !isDir && root.isExternalType(path)) ed = false
    return alt ? !ed : ed
  }


  function openPath(path, isDir, alt) {
    if (root.usesEditor(path, isDir, alt))
      Quickshell.execDetached(Theme.terminalCmd.concat(root.editorArgv(), [path]))
    else
      Quickshell.execDetached(["xdg-open", path])
  }


  function rootList() {
    const home = Quickshell.env("HOME")
    const out = []
    const parts = root.fileRoots.split(",")
    for (let i = 0; i < parts.length; i++) {
      let r = parts[i].trim()
      if (r === "") continue
      if (r === "~") r = home
      else if (r.indexOf("~/") === 0) r = home + r.slice(1)
      else if (r.indexOf("$HOME") === 0) r = home + r.slice(5)
      out.push(r)
    }
    return out.length > 0 ? out : [home]
  }

  function prettyPath(p) {
    const home = Quickshell.env("HOME")
    if (home && p === home) return "~"
    if (home && p.indexOf(home + "/") === 0) return "~" + p.slice(home.length)
    return p
  }

  function clampInt(v, lo, hi, fallback) {
    const n = parseInt(v)
    return isNaN(n) ? fallback : Math.max(lo, Math.min(hi, n))
  }


  function clean(name, v) {
    switch (name) {
      case "position":    return ["top", "center", "bottom"].indexOf(v) >= 0 ? v : undefined
      case "widthMode":   return ["compact", "normal", "wide"].indexOf(v) >= 0 ? v : undefined
      case "browserId":   return (v === "default" || root.browserInfo(v) !== null) ? v : undefined
      case "engineId": {
        if (v === "custom") return v
        for (let i = 0; i < root.engines.length; i++) if (root.engines[i].id === v) return v
        return undefined
      }
      case "fileOpener":  return (v === "nvim" || v === "default") ? v : undefined
      case "privateWindow": case "bangsEnabled": case "filesEnabled":
      case "fileSmartOpen": case "fileHidden":
        return !!v
      case "engineCustom": case "fileRoots":
        return typeof v === "string" ? v.trim() : undefined
      case "fileEditor":
        return typeof v === "string" ? (v.trim() === "" ? "nvim" : v.trim()) : undefined
      case "fileDepth":   return root.clampInt(v, 1, 12, undefined)
      case "fileMax":     return root.clampInt(v, 3, 8, undefined)
    }
    return undefined
  }

  readonly property var names: ["position", "widthMode", "browserId", "privateWindow", "engineId",
    "engineCustom", "bangsEnabled", "filesEnabled", "fileOpener", "fileSmartOpen", "fileEditor",
    "fileRoots", "fileDepth", "fileHidden", "fileMax"]

  function set(name, value) {
    const v = root.clean(name, value)
    if (v === undefined || root[name] === v) return
    root[name] = v
    if (name === "fileEditor") root.checkEditor()
    root.save()
  }

  function toggle(name) { root.set(name, !root[name]) }

  function snapshot() {
    const o = {}
    for (let i = 0; i < root.names.length; i++) o[root.names[i]] = root[root.names[i]]
    return o
  }

  Process {
    id: detectProc
    property string buffer: ""


    command: ["sh", "-c",
      'for spec in "$@"; do id="${spec%%=*}"; bins="${spec#*=}"; old="$IFS"; IFS=,; ' +
      'for b in $bins; do if command -v "$b" >/dev/null 2>&1; then echo "b $id $b"; break; fi; done; ' +
      'IFS="$old"; done; exit 0',
      "sh"].concat(root.browsers.map(b => b.id + "=" + b.bins.join(",")))
    running: true
    stdout: SplitParser { onRead: line => detectProc.buffer += line + "\n" }
    onRunningChanged: {
      if (running) return
      const ids = []
      const bins = {}
      const lines = detectProc.buffer.split("\n")
      detectProc.buffer = ""
      for (let i = 0; i < lines.length; i++) {
        const f = lines[i].trim().split(" ")
        if (f.length === 3 && f[0] === "b") { ids.push(f[1]); bins[f[1]] = f[2] }
      }
      root.installedBrowsers = ids
      root.browserBins = bins
      root.detected = true
    }
  }


  property bool editorFound: true
  Process {
    id: editorProc
    property string out: ""
    command: ["sh", "-c", 'command -v "$1" >/dev/null 2>&1 && echo ok; exit 0', "sh", root.editorBin]
    stdout: SplitParser { onRead: line => editorProc.out += line }
    onRunningChanged: {
      if (running) return
      root.editorFound = editorProc.out.trim() === "ok"
      editorProc.out = ""
    }
  }
  function checkEditor() {
    editorProc.running = false
    editorProc.running = true
  }


  property bool saveAgain: false

  function save() {
    saveProc.json = JSON.stringify(root.snapshot())
    if (saveProc.running) root.saveAgain = true
    else saveProc.running = true
  }

  Process {
    id: saveProc
    property string json: ""
    command: ["bash", "-c",
      "mkdir -p '" + root.dir + "' && cat > '" + root.file + ".tmp' << 'OOZE_QUICKBAR_EOF'\n" + json + "\nOOZE_QUICKBAR_EOF\n" +
      "mv -f '" + root.file + ".tmp' '" + root.file + "'"]
    running: false
    onRunningChanged: {
      if (running || !root.saveAgain) return
      root.saveAgain = false
      Qt.callLater(() => { saveProc.running = true })
    }
  }

  Process {
    id: loadProc
    property string buffer: ""
    command: ["bash", "-c", "cat '" + root.file + "' 2>/dev/null"]
    running: true
    stdout: SplitParser { onRead: line => loadProc.buffer += line }
    onRunningChanged: {
      if (running) return
      const raw = loadProc.buffer.trim()
      loadProc.buffer = ""
      if (raw !== "") {
        try {
          const j = JSON.parse(raw)


          for (let i = 0; i < root.names.length; i++) {
            const n = root.names[i]
            if (!(n in j)) continue
            const v = root.clean(n, j[n])
            if (v !== undefined) root[n] = v
          }
        } catch (e) {
          console.log("[quickbar] error leyendo quickbar.json:", e)
        }
      }
      root.loaded = true
      root.checkEditor()
    }
  }
}
