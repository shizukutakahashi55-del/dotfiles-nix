// Walls.qml — WALLS

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../Lang"
import "../../COMMON"
import "../../Modules/Widgets"


Item {
  id: wallsRoot

  property bool open: false
  property int currentIndex: 0
  property string targetScreen: "DP-3"
  signal closeRequested()


  signal liveSurfaceChanged()

  // ─── Vista previa (antes "Efectos") ─────────────────────────────


  property bool previewOn: true
  onPreviewOnChanged: {
    if (!wallsRoot.previewOn) return
    if (wallsRoot.liveMode) wallsRoot.startClipGen()
    else if (wallsRoot.onlineMode) wallsRoot.startOnlineClips()
  }

  // ─── Fusión con el fondo de pantalla ────────────────────────────


  property real fusionAlpha: 1
  function fuse(hexColor, alpha) {
    const c = (typeof hexColor === "string") ? Qt.color(hexColor) : hexColor
    return Qt.rgba(c.r, c.g, c.b, alpha)
  }
  // ─── Carpetas (se eligen en Ajustes → Wallpapers) ──────────────────


  readonly property string defaultWallpaperFolder: "$HOME/Pictures/Wallpapers"
  function resolveDir(p) {
    const home = Quickshell.env("HOME") || ""
    let t = String(p || "").trim()
    if (t === "~" || t === "$HOME" || t === "${HOME}") t = home
    else if (t.indexOf("~/") === 0) t = home + t.slice(1)
    else if (t.indexOf("$HOME/") === 0) t = home + t.slice(5)
    else if (t.indexOf("${HOME}/") === 0) t = home + t.slice(7)
    while (t.length > 1 && t.charAt(t.length - 1) === "/") t = t.slice(0, -1)
    return t
  }
  property string wallpaperFolder: wallsRoot.resolveDir(
    Theme.wallpaperDir !== "" ? Theme.wallpaperDir : wallsRoot.defaultWallpaperFolder)

  // ─── Live wallpapers (video) ───────────────────────────────────────


  property string liveFolder: Theme.liveWallpaperDir !== ""
    ? wallsRoot.resolveDir(Theme.liveWallpaperDir)
    : wallsRoot.wallpaperFolder + "/Live"
  readonly property var liveScanDirs: Theme.liveWallpaperDir !== ""
    ? [wallsRoot.liveFolder] : [wallsRoot.wallpaperFolder, wallsRoot.liveFolder]
  property bool liveMode: false


  property bool onlineMode: false


  property bool downloadedMode: false
  readonly property bool onlineLive: Theme.onlineKind === "live"
  readonly property var liveSiteOrigins: ({
    "moewalls": "https://moewalls.com/",
    "wallpaperwaifu": "https://wallpaperwaifu.com/"
  })
  readonly property string liveReferer: wallsRoot.liveSiteOrigins[Theme.onlineLiveSource] || ""

  function itemRow(name, path, thumb, ready, mtime, isVideo, url, clip, page, pv) {
    return { "name": name, "path": path, "thumb": thumb, "ready": ready,
             "mtime": mtime || 0, "isVideo": !!isVideo, "url": url || "",
             "clip": clip || "", "clipReady": false,
             "page": page || "", "pv": pv || "" }
  }

  function plainItem(it) {
    const r = wallsRoot.itemRow(it.name, it.path, it.thumb, it.ready, it.mtime, it.isVideo, it.url, it.clip, it.page, it.pv)
    r.clipReady = !!it.clipReady
    return r
  }

  function parseStamped(line) {
    const t = line.indexOf("\t")
    if (t < 0) return { m: 0, p: line.trim() }
    return { m: parseFloat(line.slice(0, t)) || 0, p: line.slice(t + 1).trim() }
  }

  readonly property string mode: wallsRoot.onlineMode ? "online" : (wallsRoot.downloadedMode ? "downloaded" : (wallsRoot.liveMode ? "live" : "static"))
  readonly property int modeIndex: wallsRoot.mode === "static" ? 0 : (wallsRoot.mode === "live" ? 1 : (wallsRoot.mode === "online" ? 2 : 3))


  readonly property string pathFix: 'export PATH="$HOME/.local/bin:$HOME/.cargo/bin:/run/current-system/sw/bin:$PATH"; '

  readonly property bool oozeStatic: Theme.wallStaticBackend === "oozewalls"
  readonly property bool oozeLive: Theme.liveBackend === "oozewalls"
  readonly property string liveIpcSocket: wallsRoot.oozeLive
    ? (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/oozewalls/mpv_all.sock"
    : "/tmp/oozeshell-live.sock"


  function oozeScaling(live) {
    if (live) return Theme.liveFit === "fit" ? "fit" : "fill"
    return Theme.wallFit === "crop" ? "fill" : (Theme.wallFit === "stretch" ? "stretch" : "fit")
  }

  // ─── Transiciones ──────────────────────────────────────────────────

  readonly property var awwwTransitionTypes: ({
    "none": "none", "fade": "fade",
    "slide-left": "left", "slide-right": "right", "slide-up": "top", "slide-down": "bottom",
    "wipe-left": "left", "wipe-right": "right", "wipe-up": "top", "wipe-down": "bottom",
    "circle": "center", "zoom": "grow", "blinds": "wave", "random": "random"
  })

  function oozeTransitionArgs(animate) {
    if (!animate || Theme.wallTransition === "none") return " --no-transition"
    return " --transition " + Theme.wallTransition +
           " --transition-duration " + Theme.wallTransitionMs
  }

  function awwwTransitionArgs(animate) {
    const ty = animate ? (wallsRoot.awwwTransitionTypes[Theme.wallTransition] || "fade") : "none"
    if (ty === "none") return "--transition-type none"
    return "--transition-type " + ty +
           " --transition-duration " + (Theme.wallTransitionMs / 1000).toFixed(2) +
           " --transition-fps 60"
  }

  function oozeStaticApply(path, animate) {
    return wallsRoot.pathFix + "oozewalls set static_backend builtin >/dev/null 2>&1; " +
           "oozewalls set layer background >/dev/null 2>&1; " +
           "oozewalls apply " + wallsRoot.shQuote(path) + " --output '*' --scaling " +
           wallsRoot.oozeScaling(false) + wallsRoot.oozeTransitionArgs(animate) + " --no-palette"
  }

  readonly property string awwwFitArgs:
    "--resize " + Theme.wallFit + " --fill-color " + Theme.wallFillColor

  property string mpvOptions:
    "no-audio loop-file=inf hwdec=" + Theme.liveHwdec +
    " panscan=" + (Theme.liveFit === "fit" ? "0.0" : "1.0") +
    " cache=no demuxer-max-bytes=32MiB demuxer-max-back-bytes=32MiB" +


    " profile=fast vd-lavc-threads=2 load-scripts=no ytdl=no osd-level=0" +
    " input-ipc-server=" + liveIpcSocket

  // ─── Ahorro de memoria (ver docs/OPTIMIZACION.md) ──────────────────


  readonly property bool liveOptimize: Theme.liveOptimize
  readonly property bool liveOptSwap: Theme.liveOptSwap
  readonly property int liveOptMaxHeight: Theme.liveOptMaxHeight
  readonly property int liveOptMaxFps: Theme.liveOptMaxFps
  readonly property string liveOptDir: Quickshell.env("HOME") + "/.cache/oozeshell/live/opt"
  readonly property string liveOptScript:
    decodeURIComponent(Qt.resolvedUrl("../../Tools/live-optimize.sh").toString().replace("file://", ""))


  readonly property bool liveStopWhenHidden: Theme.liveStopWhenHidden


  readonly property int liveRamLimitMB: Theme.liveRamLimitMB
  property bool liveStopped: false


  readonly property string liveLayer: WidgetConfig.layer === "bottom" ? "background" : Theme.liveLayer

  property string paletteSource: ""

  property string liveActivePath: ""
  property bool liveRestored: false

  property int thumbRev: 0

  property var indexMemory: ({ stat: 0, live: 0, online: 0, down: 0 })

  readonly property string liveCacheDir: Quickshell.env("HOME") + "/.cache/oozeshell/live"
  readonly property string liveStateFile: Quickshell.env("HOME") + "/.cache/oozeshell/live-active"

  ListModel { id: liveModel }

  readonly property var baseModel: wallsRoot.onlineMode ? onlineModel
                                   : (wallsRoot.downloadedMode ? downloadedModel
                                   : (wallsRoot.liveMode ? liveModel : wallpaperModel))

  // ─── Búsqueda, filtros y orden ─────────────────────────────────────
  property string searchText: ""
  property string filterExt: ""
  property string sortLocal: "name"
  property string popup: ""
  property bool searchFocus: true
  signal focusSearchRequested()
  signal releaseSearchFocus()

  readonly property bool localOnlineSearch: wallsRoot.onlineMode && !wallsRoot.onlineLive && Theme.onlineSource === "bing"
  readonly property bool remoteSearch: wallsRoot.onlineMode && !wallsRoot.localOnlineSearch
  readonly property bool filtering: !wallsRoot.remoteSearch
    && (wallsRoot.searchText.trim() !== "" || wallsRoot.filterExt !== "" || wallsRoot.sortLocal !== "name")
  readonly property var activeModel: wallsRoot.filtering ? viewModel : wallsRoot.baseModel
  readonly property bool searchEmpty: wallsRoot.filtering && viewModel.count === 0 && wallsRoot.baseModel.count > 0

  ListModel { id: viewModel }

  function extOf(name) {
    const m = /\.([^.]+)$/.exec(String(name))
    return m ? m[1].toLowerCase() : ""
  }

  readonly property var availableExts: {
    wallsRoot.thumbRev
    const seen = {}
    const out = []
    const src = wallsRoot.baseModel
    for (let i = 0; i < src.count; i++) {
      const e = wallsRoot.extOf(src.get(i).name)
      if (e !== "" && !seen[e]) { seen[e] = true; out.push(e) }
    }
    out.sort()
    return out
  }

  function rebuildView() {
    if (!wallsRoot.filtering) {
      if (viewModel.count > 0) viewModel.clear()
      return
    }
    const tokens = wallsRoot.searchText.trim().toLowerCase().split(/\s+/).filter(t => t !== "")
    const src = wallsRoot.baseModel
    const rows = []
    for (let i = 0; i < src.count; i++) {
      const it = wallsRoot.plainItem(src.get(i))
      const nm = it.name.toLowerCase()
      if (wallsRoot.filterExt !== "" && wallsRoot.extOf(nm) !== wallsRoot.filterExt) continue
      let ok = true
      for (const t of tokens) if (nm.indexOf(t) < 0) { ok = false; break }
      if (ok) rows.push(it)
    }
    const k = wallsRoot.sortLocal
    if (k === "name-desc") rows.sort((a, b) => b.name.localeCompare(a.name))
    else if (k === "new") rows.sort((a, b) => b.mtime - a.mtime)
    else if (k === "old") rows.sort((a, b) => a.mtime - b.mtime)
    else rows.sort((a, b) => a.name.localeCompare(b.name))
    viewModel.clear()
    for (const r of rows) viewModel.append(r)
    wallsRoot.currentIndex = Math.min(wallsRoot.currentIndex, Math.max(0, viewModel.count - 1))
  }

  Timer {
    id: viewDebounce
    interval: 70
    repeat: false
    onTriggered: wallsRoot.rebuildView()
  }
  function scheduleView() { viewDebounce.restart() }

  onFilteringChanged: wallsRoot.scheduleView()
  onFilterExtChanged: wallsRoot.scheduleView()
  onSortLocalChanged: wallsRoot.scheduleView()
  onSearchTextChanged: {
    wallsRoot.currentIndex = 0
    wallsRoot.scheduleView()
    if (wallsRoot.remoteSearch) remoteSearchDebounce.restart()
  }
  onBaseModelChanged: wallsRoot.scheduleView()
  onThumbRevChanged: if (wallsRoot.filtering) wallsRoot.scheduleView()
  Connections { target: wallpaperModel; function onCountChanged() { wallsRoot.scheduleView() } }
  Connections { target: liveModel; function onCountChanged() { wallsRoot.scheduleView() } }
  Connections { target: downloadedModel; function onCountChanged() { wallsRoot.scheduleView() } }
  Connections { target: onlineModel; function onCountChanged() { if (wallsRoot.localOnlineSearch) wallsRoot.scheduleView() } }

  Timer {
    id: remoteSearchDebounce
    interval: 850
    repeat: false
    onTriggered: wallsRoot.submitSearch()
  }

  function submitSearch() {
    remoteSearchDebounce.stop()
    if (!wallsRoot.remoteSearch) return
    const q = wallsRoot.searchText.trim()
    if (q !== Theme.onlineQuery) Theme.setWallsOpt("onlineQuery", q)
  }

  readonly property bool searchPending: wallsRoot.remoteSearch && wallsRoot.searchText.trim() !== Theme.onlineQuery

  function clearSearch() {
    wallsRoot.searchText = ""
    if (wallsRoot.remoteSearch) wallsRoot.submitSearch()
  }

  onLocalOnlineSearchChanged: wallsRoot.resetSearchForMode()

  Connections {
    target: Theme
    function onOnlineQueryChanged() {
      if (wallsRoot.remoteSearch && !remoteSearchDebounce.running
          && wallsRoot.searchText.trim() !== Theme.onlineQuery)
        wallsRoot.searchText = Theme.onlineQuery
    }
  }

  function resetSearchForMode() {
    wallsRoot.filterExt = ""
    wallsRoot.popup = ""
    remoteSearchDebounce.stop()
    wallsRoot.searchText = wallsRoot.onlineMode && !wallsRoot.localOnlineSearch ? Theme.onlineQuery : ""
  }

  function setKind(k) {
    if (k === Theme.onlineKind) return
    Theme.setWallsOpt("onlineKind", k)
  }

  function sortChoices() {
    if (wallsRoot.remoteSearch) {
      if (wallsRoot.onlineLive)
        return [ { value: "date_added", label: Translations.t("wallsSortLatest") },
                 { value: "relevance", label: Translations.t("wallsSortRelevance") } ]
      return [
        { value: "toplist",    label: Translations.t("wallsSortToplist") },
        { value: "hot",        label: Translations.t("wallsSortHot") },
        { value: "random",     label: Translations.t("wallsSortRandom") },
        { value: "date_added", label: Translations.t("wallsSortLatest") },
        { value: "views",      label: Translations.t("wallsSortViews") },
        { value: "relevance",  label: Translations.t("wallsSortRelevance") }
      ]
    }
    return [
      { value: "name",      label: Translations.t("wallsSortName") },
      { value: "name-desc", label: Translations.t("wallsSortNameDesc") },
      { value: "new",       label: Translations.t("wallsSortNew") },
      { value: "old",       label: Translations.t("wallsSortOld") }
    ]
  }

  readonly property string sortCurrent: wallsRoot.remoteSearch ? Theme.onlineSorting : wallsRoot.sortLocal

  function pickSort(v) {
    if (wallsRoot.remoteSearch) Theme.setWallsOpt("onlineSorting", v)
    else wallsRoot.sortLocal = v
    wallsRoot.popup = ""
  }

  function frameFor(videoPath) {
    return wallsRoot.liveCacheDir + "/" + Qt.md5(videoPath) + ".jpg"
  }


  function clipFor(videoPath) {
    return wallsRoot.liveCacheDir + "/" + Qt.md5(videoPath) + "-preview.gif"
  }


  function frameCmd(video, frame) {
    const v = wallsRoot.shQuote(video), f = wallsRoot.shQuote(frame)
    const ff = "ffmpeg -nostdin -y -v error -i " + v +
               " -frames:v 1 -vf scale=1280:-2 -q:v 2 " + f + " 2>/dev/null"
    const ffSeek = "ffmpeg -nostdin -y -v error -ss 1 -i " + v +
               " -frames:v 1 -vf scale=1280:-2 -q:v 2 " + f + " 2>/dev/null"
    return "[ -s " + f + " ] || " + ffSeek + "; [ -s " + f + " ] || " + ff + "; "
  }


  readonly property string killLiveCmd:
    "pkill -f '[m]pvpaper'; " +
    "for i in 1 2 3 4 5 6 7 8; do pgrep -f '[m]pvpaper' >/dev/null || break; sleep 0.1; done; " +
    "pkill -9 -f '[m]pvpaper'; "


  readonly property string liveLogFile: wallsRoot.liveCacheDir + "/live-player.log"


  function optResolveCmd() {
    if (!wallsRoot.liveOptimize) return ""
    return "O=" + wallsRoot.shQuote(wallsRoot.liveOptDir) + "/$(printf %s \"$V\" | md5sum | cut -d' ' -f1).mp4; " +
           "[ -s \"$O\" ] && V=\"$O\"; "
  }

  readonly property string liveReplaceKillCmd: wallsRoot.oozeLive
    ? "[ -S " + wallsRoot.shQuote(wallsRoot.liveIpcSocket) + " ] || { " + wallsRoot.killLiveCmd + "}; "
    : wallsRoot.killLiveCmd

  function mpvLaunchCmd(video, animate) {
    if (wallsRoot.oozeLive)
      return wallsRoot.pathFix + "V=" + wallsRoot.shQuote(video) + "; " + wallsRoot.optResolveCmd() +
             "mkdir -p " + wallsRoot.shQuote(wallsRoot.liveCacheDir) + "; " +
             "oozewalls set layer " + wallsRoot.liveLayer + " >/dev/null 2>&1; " +
             "oozewalls set hwdec " + Theme.liveHwdec + " >/dev/null 2>&1; " +
             "oozewalls set mute on >/dev/null 2>&1; " +
             "oozewalls apply \"$V\" --output '*' --scaling " + wallsRoot.oozeScaling(true) +
             wallsRoot.oozeTransitionArgs(animate) + " --no-palette >>" + wallsRoot.shQuote(wallsRoot.liveLogFile) + " 2>&1"
    return "V=" + wallsRoot.shQuote(video) + "; " + wallsRoot.optResolveCmd() +
           "mkdir -p " + wallsRoot.shQuote(wallsRoot.liveCacheDir) + "; " +
           "rm -f " + wallsRoot.shQuote(wallsRoot.liveIpcSocket) + "; " +
           "setsid -f mpv\"\"paper -p -l " + wallsRoot.liveLayer +
           " -o " + wallsRoot.shQuote(wallsRoot.mpvOptions) +
           " '*' \"$V\" >>" + wallsRoot.shQuote(wallsRoot.liveLogFile) + " 2>&1"
  }


  Process {
    id: relaunchLive
    property string video: ""
    command: ["bash", "-c", wallsRoot.killLiveCmd + wallsRoot.mpvLaunchCmd(video, false)]
    running: false
    onRunningChanged: if (!running && video !== "") liveSyncDelay.restart()
  }
  function relaunchLiveNow() {
    if (wallsRoot.liveActivePath === "" || relaunchLive.running) return
    relaunchLive.video = wallsRoot.liveActivePath
    relaunchLive.running = true
  }

  // ─── Pausa automática del video de fondo ───────────────────────────


  readonly property var liveScreen:
    Quickshell.screens.find(s => s.name === wallsRoot.targetScreen) ?? Quickshell.screens[0]
  property var pausePowerProfiles: ["power-saver"]
  property string powerProfile: "balanced"
  readonly property bool shouldPauseLive:
    FullscreenState.isOn(wallsRoot.liveScreen) ||
    wallsRoot.pausePowerProfiles.indexOf(wallsRoot.powerProfile) !== -1

  Process {
    id: getPowerProfile
    command: ["sh", "-c",
      'powerprofilesctl get 2>/dev/null || /run/current-system/sw/bin/powerprofilesctl get']
    running: false
    stdout: SplitParser { onRead: line => wallsRoot.powerProfile = line.trim() }
  }


  Timer {
    interval: 8000
    running: wallsRoot.liveActivePath !== ""
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!getPowerProfile.running) getPowerProfile.running = true
  }


  function liveIpcSend(jsonCmd) {
    Quickshell.execDetached(["bash", "-c",
      "echo " + wallsRoot.shQuote(jsonCmd) + " | socat - " + wallsRoot.shQuote(wallsRoot.liveIpcSocket) + " >/dev/null 2>&1"
    ])
  }

  function syncLivePause() {
    if (wallsRoot.liveActivePath === "") return
    console.log("[live] syncLivePause: shouldPauseLive=" + wallsRoot.shouldPauseLive +
                " fullscreen=" + FullscreenState.isOn(wallsRoot.liveScreen) +
                " profile=" + wallsRoot.powerProfile)
    if (wallsRoot.liveStopWhenHidden) {
      if (wallsRoot.shouldPauseLive) {

        wallsRoot.liveStopped = true
        Quickshell.execDetached(["bash", "-c", wallsRoot.killLiveCmd])
      } else if (wallsRoot.liveStopped) {
        wallsRoot.liveStopped = false
        wallsRoot.relaunchLiveNow()
      }
      return
    }
    wallsRoot.liveIpcSend(wallsRoot.shouldPauseLive
      ? '{"command":["set_property","pause",true]}'
      : '{"command":["set_property","pause",false]}')
  }

  // ─── Vigilante de RAM de mpvpaper ──────────────────────────────────


  Process {
    id: liveRssProc
    command: ["bash", "-c",
      "pgrep -f '[m]pvpaper' | xargs -r ps -o rss= -p | awk '{s+=$1} END{if (NR>0) print int(s/1024)}'"]
    running: false
    stdout: SplitParser {
      onRead: line => {
        const mb = parseInt(line.trim())
        if (isNaN(mb)) return
        console.log("[live] RAM mpvpaper: " + mb + " MB (tope " + wallsRoot.liveRamLimitMB + ")")
        if (wallsRoot.liveRamLimitMB > 0 && mb > wallsRoot.liveRamLimitMB) {
          console.log("[live] tope superado: relanzando mpvpaper")
          wallsRoot.relaunchLiveNow()
        }
      }
    }
  }
  Timer {
    interval: 60000
    running: wallsRoot.liveActivePath !== "" && !wallsRoot.liveStopped && wallsRoot.liveRamLimitMB > 0
    repeat: true
    onTriggered: if (!liveRssProc.running && !relaunchLive.running) liveRssProc.running = true
  }

  // ─── Copia liviana en segundo plano ────────────────────────────────
  Process {
    id: optimizeLive
    property string video: ""
    command: ["bash", wallsRoot.liveOptScript, video,
              String(wallsRoot.liveOptMaxHeight), String(wallsRoot.liveOptMaxFps)]
    running: false
    environment: ({ "LIVE_OPT_DIR": wallsRoot.liveOptDir })
    onExited: (code) => {
      console.log("[live] optimizar " + video + " -> código " + code)


      const swap = code === 0 || (code === 2 && wallsRoot.liveOptForceSwap)
      wallsRoot.liveOptForceSwap = false
      if (swap && wallsRoot.liveOptSwap && video === wallsRoot.liveActivePath
          && !wallsRoot.liveStopped)
        wallsRoot.relaunchLiveNow()
    }
  }
  function optimizeActiveLive() {
    if (!wallsRoot.liveOptimize || wallsRoot.liveActivePath === "" || optimizeLive.running) return
    optimizeLive.video = wallsRoot.liveActivePath
    optimizeLive.running = true
  }

  onShouldPauseLiveChanged: wallsRoot.syncLivePause()


  Timer {
    id: liveSyncDelay
    interval: 500
    repeat: false
    onTriggered: {
      console.log("[live] liveSyncDelay: forzando pause=false tras (re)lanzar")
      wallsRoot.liveIpcSend('{"command":["set_property","pause",false]}')
      wallsRoot.liveSurfaceChanged()
    }
  }


  function applyItem(wp) {
    if (!wp) {
      console.log("[live] applyItem: wp vacío/null, no hago nada")
      return
    }
    console.log("[live] applyItem: mode=" + wallsRoot.mode + " path=" + wp.path)
    if (wallsRoot.onlineMode) {
      wallsRoot.applyOnlineItem(wp)
    } else if (wallsRoot.liveMode || wp.isVideo) {
      wallsRoot.startVideo(wp.path)
    } else {
      applyWallpaper.wpPath = wp.path
      wallsRoot.paletteSource = wp.path
      wallsRoot.liveActivePath = ""
      applyWallpaper.running = true
    }
  }

  function startVideo(path) {
    if (applyLive.running) return
    applyLive.videoPath = path
    applyLive.framePath = wallsRoot.frameFor(path)
    wallsRoot.paletteSource = applyLive.framePath
    wallsRoot.liveActivePath = path
    wallsRoot.liveStopped = false
    applyLive.running = true
  }

  function reloadLive() {
    if (scanLive.running || genThumbs.running) return
    liveModel.clear()
    scanLive.running = true
  }


  function setMode(m) {
    const next = (m === "online" || m === "live" || m === "downloaded") ? m : "static"
    if (next === wallsRoot.mode) return
    const memKey = { static: "stat", live: "live", online: "online", downloaded: "down" }
    wallsRoot.indexMemory[memKey[wallsRoot.mode]] = wallsRoot.currentIndex
    wallsRoot.onlineMode = (next === "online")
    wallsRoot.downloadedMode = (next === "downloaded")
    wallsRoot.liveMode = (next === "live")
    const idx = wallsRoot.indexMemory[memKey[next]] ?? 0
    wallsRoot.resetSearchForMode()
    if (next === "live") {

      wallsRoot.currentIndex = idx
      wallsRoot.reloadLive()
    } else if (next === "online") {
      wallsRoot.currentIndex = idx
      if (onlineModel.count === 0) wallsRoot.fetchOnlineFirst()
    } else if (next === "downloaded") {
      wallsRoot.currentIndex = idx
      wallsRoot.reloadDownloaded()
    } else {
      wallsRoot.currentIndex = Math.min(idx, Math.max(0, wallpaperModel.count - 1))
    }
  }
  function cycleMode() {
    wallsRoot.setMode(wallsRoot.mode === "static" ? "live" : (wallsRoot.mode === "live" ? "online" : (wallsRoot.mode === "online" ? "downloaded" : "static")))
  }
  function setLiveMode(on) { wallsRoot.setMode(on ? "live" : "static") }


  function onLiveScanned() {
    if (liveModel.count > 0 && !genThumbs.running) {
      let sc = "mkdir -p " + wallsRoot.shQuote(wallsRoot.liveCacheDir) + "\n" +
               "gen() { V=\"$1\"; F=\"$2\"; " +
               "[ -s \"$F\" ] || ffmpeg -nostdin -y -v error -ss 1 -i \"$V\" -frames:v 1 -vf scale=1280:-2 -q:v 2 \"$F\" 2>/dev/null; " +
               "[ -s \"$F\" ] || ffmpeg -nostdin -y -v error -i \"$V\" -frames:v 1 -vf scale=1280:-2 -q:v 2 \"$F\" 2>/dev/null; " +
               "[ -s \"$F\" ] && echo \"$V\"; }\n"
      for (let i = 0; i < liveModel.count; i++) {
        const it = liveModel.get(i)
        sc += "gen " + wallsRoot.shQuote(it.path) + " " + wallsRoot.shQuote(it.thumb) + "\n"
      }
      genThumbs.script = sc
      genThumbs.running = true
    }

    if (!wallsRoot.liveRestored) {
      wallsRoot.liveRestored = true
      if (wallsRoot.liveActivePath !== "") {
        let idx = 0
        for (let i = 0; i < liveModel.count; i++)
          if (liveModel.get(i).path === wallsRoot.liveActivePath) { idx = i; break }
        wallsRoot.liveMode = true
        wallsRoot.currentIndex = idx
        wallsRoot.paletteSource = wallsRoot.frameFor(wallsRoot.liveActivePath)
      }
    } else if (wallsRoot.liveMode) {
      wallsRoot.currentIndex = Math.min(wallsRoot.currentIndex, Math.max(0, liveModel.count - 1))
    }
  }

  // ─── ¿Se están recargando los colores? ─────────────────────────────


  property bool changing: false

  property int transitionHoldMs: Theme.wallTransition === "none" ? 400 : Theme.wallTransitionMs + 300

  property int settleMs: 700

  property bool colorsPending: false

  property bool holdDone: true
  property bool settled: true

  function beginChange(withTransition) {
    settleTimer.stop()
    wallsRoot.settled = false
    wallsRoot.holdDone = !withTransition
    if (withTransition) changeHold.restart()
    wallsRoot.changing = true
    changeFailsafe.restart()
  }

  function tryFinishChange() {
    if (applyWallpaper.running || applyLive.running || applyOnline.running || matugenProc.running
        || wallsRoot.colorsPending) return
    if (!wallsRoot.holdDone || !wallsRoot.settled) return
    wallsRoot.changing = false
    changeFailsafe.stop()
  }

  Timer {
    id: changeHold
    interval: wallsRoot.transitionHoldMs
    repeat: false
    onTriggered: { wallsRoot.holdDone = true; wallsRoot.tryFinishChange() }
  }

  Timer {
    id: settleTimer
    interval: wallsRoot.settleMs
    repeat: false
    onTriggered: { wallsRoot.settled = true; wallsRoot.tryFinishChange() }
  }

  Timer {
    id: changeFailsafe
    interval: 12000
    repeat: false
    onTriggered: wallsRoot.changing = false
  }

  property int windowSize: 7
  readonly property int halfWindow: Math.floor(windowSize / 2)

  // ─── Navegación ─────────────────────────────────────────────

  function step(d) {
    const total = wallsRoot.activeModel.count
    if (total === 0) return
    wallsRoot.currentIndex = ((wallsRoot.currentIndex + d) % total + total) % total
  }

  function goTo(i) {
    const total = wallsRoot.activeModel.count
    if (total === 0) return
    wallsRoot.currentIndex = Math.max(0, Math.min(total - 1, i))
  }


  function randomIndex() {
    const n = wallsRoot.activeModel.count
    if (n < 2) return
    let i = wallsRoot.currentIndex
    while (i === wallsRoot.currentIndex) i = Math.floor(Math.random() * n)
    wallsRoot.currentIndex = i
  }


  readonly property string appliedPath:
    wallsRoot.liveActivePath !== "" ? wallsRoot.liveActivePath : applyWallpaper.wpPath

  // ─── Volver a leer la carpeta al abrir ─────────────────────────


  onOpenChanged: {
    if (wallsRoot.open) {
      wallsRoot.popup = ""
      wallsRoot.searchFocus = true
      wallsRoot.focusSearchRequested()
    }
    if (wallsRoot.open && wallsRoot.mode === "static" && !loadWalls.running && !rescanWalls.running)
      rescanWalls.running = true
    if (wallsRoot.open && wallsRoot.mode === "downloaded") wallsRoot.reloadDownloaded()
  }

  Process {
    id: rescanWalls
    property var found: []
    command: [ "bash", "-c",
      "find " + wallsRoot.shQuote(wallsRoot.wallpaperFolder) + " -maxdepth 1 -type f -printf '%T@\\t%p\\n' 2>/dev/null | sort -t$'\\t' -k2 | grep -iE '\\.(jpg|jpeg|png|webp|gif)$'" ]
    running: false
    property var stamps: ({})
    stdout: SplitParser {
      onRead: line => {
        const r = wallsRoot.parseStamped(line)
        if (r.p !== "") { rescanWalls.found.push(r.p); rescanWalls.stamps[r.p] = r.m }
      }
    }
    onRunningChanged: {
      if (running) { rescanWalls.found = []; rescanWalls.stamps = ({}); return }
      const f = rescanWalls.found
      rescanWalls.found = []

      if (wallsRoot.staticDirty) { wallsRoot.staticDirty = false; rescanWalls.running = true; return }

      let same = f.length === wallpaperModel.count
      for (let i = 0; same && i < f.length; i++)
        if (wallpaperModel.get(i).path !== f[i]) same = false
      if (same) return


      const curIdx = wallsRoot.mode !== "static" ? wallsRoot.indexMemory["stat"] : wallsRoot.currentIndex
      const cur = wallpaperModel.count > 0 && curIdx < wallpaperModel.count
        ? wallpaperModel.get(curIdx).path : ""
      wallpaperModel.clear()
      for (let i = 0; i < f.length; i++)
        wallpaperModel.append(wallsRoot.itemRow(f[i].split("/").pop(), f[i], f[i], true, rescanWalls.stamps[f[i]], false))
      let idx = f.indexOf(cur)


      if (idx < 0 && applyWallpaper.wpPath !== "") idx = f.indexOf(applyWallpaper.wpPath)
      const next = idx >= 0 ? idx : Math.min(curIdx, Math.max(0, f.length - 1))
      if (wallsRoot.mode !== "static") wallsRoot.indexMemory["stat"] = next
      else wallsRoot.currentIndex = next


      if (idx < 0 && cur === "" && applyWallpaper.wpPath === "") loadLastWp.running = true
    }
  }

  // ─── Cambio de carpeta (Ajustes → Wallpapers) ──────────────────


  property bool staticDirty: false
  property bool liveDirty: false

  function reloadStatic() {
    if (rescanWalls.running || loadWalls.running) { wallsRoot.staticDirty = true; return }
    rescanWalls.running = true
  }
  function reloadLiveFolder() {
    if (scanLive.running || genThumbs.running) { wallsRoot.liveDirty = true; return }
    scanLive.running = true
  }

  function checkLiveDirty() {
    if (!wallsRoot.liveDirty) return false
    wallsRoot.liveDirty = false
    scanLive.running = true
    return true
  }
  onWallpaperFolderChanged: Qt.callLater(wallsRoot.reloadStatic)
  onLiveFolderChanged: Qt.callLater(wallsRoot.reloadLiveFolder)

  function shQuote(s) {
    return "'" + String(s).replace(/'/g, "'\\''") + "'"
  }

  // ─── Función para buscar el índice guardado en el modelo ────
    function restoreLastIndex(savedPath) {
      const cleanPath = savedPath.trim()
      if (cleanPath === "") return

      for (let i = 0; i < wallpaperModel.count; i++) {
        if (wallpaperModel.get(i).path === cleanPath) {
          wallsRoot.currentIndex = i

          applyWallpaper.wpPath = cleanPath
          wallsRoot.paletteSource = cleanPath
          break
        }
      }
    }

  // ─── Esquemas matugen ─────────────────────────────────────────


  property int schemeIndex: Theme.defaultSchemeIndex
  readonly property var schemes: Theme.schemes

  function applyScheme(idx) {
    schemeIndex = idx
    if (wallsRoot.paletteSource !== "") {
      wallsRoot.beginChange(false)
      wallsRoot.runMatugen()
    }
  }


  property bool matugenAgain: false
  function runMatugen() {


    if (Theme.paletteMode) {
      wallsRoot.settled = false
      settleTimer.restart()
      return
    }
    if (matugenProc.running) wallsRoot.matugenAgain = true
    else matugenProc.running = true
  }


  Connections {
    target: Theme
    function onPaletteModeChanged() {
      if (!Theme.paletteMode && wallsRoot.paletteSource !== "") wallsRoot.runMatugen()
    }
  }

  ListModel { id: wallpaperModel }

  // ─── Wallpapers en línea (modo Online) ─────────────────────────────


  ListModel { id: onlineModel }
  property int onlinePage: 1
  property bool onlineHasMore: true

  property string onlineError: ""
  readonly property bool onlineLoading: fetchOnline.running
  readonly property string onlineDir: wallsRoot.resolveDir(
    Theme.onlineSaveDir !== "" ? Theme.onlineSaveDir : wallsRoot.wallpaperFolder + "/Online")
  readonly property string onlineThumbDir: Quickshell.env("HOME") + "/.cache/oozeshell/online/thumbs"
  readonly property string onlineLiveScript:
    decodeURIComponent(Qt.resolvedUrl("../../Tools/online-live.sh").toString().replace("file://", ""))
  readonly property string onlineScript:
    decodeURIComponent(Qt.resolvedUrl("../../Tools/online-wallpapers.sh").toString().replace("file://", ""))
  readonly property string onlineClipScript:
    decodeURIComponent(Qt.resolvedUrl("../../Tools/online-clip.sh").toString().replace("file://", ""))
  readonly property string onlineDownloadScript:
    decodeURIComponent(Qt.resolvedUrl("../../Tools/online-download.sh").toString().replace("file://", ""))

  readonly property string onlineSignature:
    [Theme.onlineSource, Theme.onlineQuery, Theme.onlineSorting, Theme.onlineCategories,
     Theme.onlineMinRes, Theme.onlineSaveDir, Theme.onlinePurity,
     Theme.onlineApiKey !== "", Theme.onlineKind, Theme.onlineLiveSource].join("|")

  readonly property string onlineLiveDir: wallsRoot.onlineDir + "/Live"

  function startFetch() {
    if (fetchOnline.running || !wallsRoot.onlineHasMore) return
    fetchOnline.page = wallsRoot.onlinePage
    fetchOnline.got = 0
    wallsRoot.onlineError = ""
    fetchOnline.running = true
  }
  function fetchOnlineFirst() {
    onlineModel.clear()
    wallsRoot.onlinePage = 1
    wallsRoot.onlineHasMore = true
    wallsRoot.startFetch()
  }

  function loadMoreOnline() {
    if (fetchOnline.running || !wallsRoot.onlineHasMore || onlineModel.count === 0) return
    wallsRoot.onlinePage += 1
    wallsRoot.startFetch()
  }
  onCurrentIndexChanged: {
    if (wallsRoot.onlineMode && onlineModel.count > 0 && wallsRoot.currentIndex >= onlineModel.count - 8)
      wallsRoot.loadMoreOnline()
  }
  onOnlineSignatureChanged: {
    onlineModel.clear()
    wallsRoot.onlinePage = 1
    wallsRoot.onlineHasMore = true
    wallsRoot.onlineError = ""
    wallsRoot.indexMemory["online"] = 0
    genOnlineClips.rerun = false
    genOnlineClips.running = false
    if (wallsRoot.onlineMode) wallsRoot.currentIndex = 0
    if (fetchOnline.running) { fetchOnline.restart = true; fetchOnline.running = false }
    else if (wallsRoot.onlineMode) Qt.callLater(wallsRoot.startFetch)

    if (wallsRoot.downloadedMode) Qt.callLater(wallsRoot.reloadDownloaded)
  }

  Process {
    id: fetchOnline
    property int page: 1
    property int got: 0
    property bool restart: false
    command: wallsRoot.onlineLive
      ? ["bash", wallsRoot.onlineLiveScript, Theme.onlineLiveSource, Theme.onlineQuery,
         Theme.onlineSorting, String(page), wallsRoot.onlineThumbDir]
      : ["bash", wallsRoot.onlineScript, Theme.onlineSource, Theme.onlineQuery,
         Theme.onlineSorting, Theme.onlineCategories, Theme.onlineMinRes,
         String(page), wallsRoot.onlineThumbDir, Theme.onlinePurity]

    environment: ({ "OOZE_WH_KEY": Theme.onlineApiKey })
    running: false
    stdout: SplitParser {
      onRead: (line) => {
        if (fetchOnline.restart) return
        const f = line.split("\t")
        if (f.length < 4 || f[0] === "") return
        const vid = wallsRoot.onlineLive
        const dest = (vid ? wallsRoot.onlineLiveDir : wallsRoot.onlineDir) + "/" + f[0]
        for (let i = 0; i < onlineModel.count; i++)
          if (onlineModel.get(i).path === dest) return
        onlineModel.append(wallsRoot.itemRow(f[3] !== "" ? f[3] : f[0], dest, f[2], true, 0, vid, f[1],
          vid && f.length > 5 ? f[5] : "", vid && f.length > 4 ? f[4] : "", vid && f.length > 6 ? f[6] : ""))
        fetchOnline.got++
        wallsRoot.thumbRev++
      }
    }
    stderr: SplitParser { onRead: (line) => console.log("[online]", line) }
    onExited: (code) => {
      if (fetchOnline.restart) {
        fetchOnline.restart = false
        if (wallsRoot.onlineMode) wallsRoot.startFetch()
        return
      }
      if (code !== 0) {
        wallsRoot.onlineError = "net"
        if (page > 1) wallsRoot.onlinePage = page - 1
        return
      }
      if (got === 0) {
        wallsRoot.onlineHasMore = false
        if (page === 1) wallsRoot.onlineError = "empty"
        return
      }
      if (wallsRoot.onlineLive) {
        wallsRoot.startOnlineClips()
        if (page === 1) Qt.callLater(wallsRoot.loadMoreOnline)
      }
    }
  }

  // ─── Vista previa animada de Online Live ───────────────────────────

  function startOnlineClips() {
    if (!wallsRoot.previewOn || Theme.shellPerf || !wallsRoot.onlineLive) return
    if (genOnlineClips.running) { genOnlineClips.rerun = true; return }
    let jobs = ""
    for (let i = 0; i < onlineModel.count; i++) {
      const it = onlineModel.get(i)
      if (!it.isVideo || it.clip === "" || it.clipReady) continue
      const src = it.pv !== "" ? it.pv : it.url
      if (/\.(mp4|webm)(\?|$)/i.test(src)) jobs += it.path + "\t" + it.clip + "\t" + src + "\n"
    }
    if (jobs === "") return
    genOnlineClips.script = "bash " + wallsRoot.shQuote(wallsRoot.onlineClipScript) + " " +
      wallsRoot.shQuote(wallsRoot.liveReferer) + " <<'OOZE_CLIPS'\n" + jobs + "OOZE_CLIPS\n"
    genOnlineClips.running = true
  }

  Process {
    id: genOnlineClips
    property string script: ""
    property bool rerun: false
    command: ["bash", "-c", script]
    running: false
    stdout: SplitParser {
      onRead: (line) => {
        const p = line.trim()
        for (let i = 0; i < onlineModel.count; i++) {
          if (onlineModel.get(i).path === p) {
            onlineModel.setProperty(i, "clipReady", true)
            wallsRoot.thumbRev++
            break
          }
        }
      }
    }
    stderr: SplitParser { onRead: (line) => console.log("[online-clip]", line) }
    onExited: {
      if (!rerun) return
      rerun = false
      wallsRoot.startOnlineClips()
    }
  }


  function applyOnlineItem(wp) {
    if (!wp || applyOnline.running || !wp.url) return
    applyOnline.url = wp.url
    applyOnline.dest = wp.path
    applyOnline.page = wp.page || ""
    applyOnline.video = !!wp.isVideo
    wallsRoot.beginChange(false)
    applyOnline.running = true
  }
  Process {
    id: applyOnline
    property string url: ""
    property string dest: ""
    property string page: ""
    property bool video: false
    running: false
    command: video
      ? ["bash", wallsRoot.onlineDownloadScript, Theme.onlineLiveSource, url, dest, page, wallsRoot.liveReferer]
      : ["bash", "-c",
      "D=\"$2\"; mkdir -p \"$(dirname \"$D\")\"; " +
      "[ -s \"$D\" ] || { curl -fsSL --retry 2 -m 300 -A \"${3:-OozeShell/1.0}\" ${4:+-e \"$4\"} -o \"$D.part\" \"$1\" && mv -f \"$D.part\" \"$D\"; }; " +
      "[ -s \"$D\" ] || { rm -f \"$D.part\"; exit 1; }",
      "bash", url, dest, "OozeShell/1.0", ""]
    stderr: SplitParser { onRead: (line) => console.log("[online]", line) }
    onExited: (code) => {
      if (code === 0 && video) {
        wallsRoot.startVideo(dest)
      } else if (code === 0) {

        applyWallpaper.wpPath = dest
        wallsRoot.paletteSource = dest
        wallsRoot.liveActivePath = ""
        applyWallpaper.running = true
      } else {
        wallsRoot.onlineError = "net"
        wallsRoot.holdDone = true
        wallsRoot.settled = true
        wallsRoot.tryFinishChange()
      }
    }
  }

  // ─── Modo Downloaded: archivos ya bajados en la carpeta online ────


  ListModel { id: downloadedModel }
  readonly property bool downloadedLoading: scanDownloaded.running

  function reloadDownloaded() {
    if (scanDownloaded.running) return
    scanDownloaded.running = true
  }

  Process {
    id: scanDownloaded
    property var found: []
    command: ["bash", "-c",
      "find " + wallsRoot.shQuote(wallsRoot.onlineDir) + " -maxdepth 2 -type f -printf '%T@\\t%p\\n' 2>/dev/null " +
      "| sort -t$'\\t' -k2 | grep -iE '\\.(jpg|jpeg|png|webp|gif|mp4|mkv|webm|mov|m4v)$'"]
    running: false
    stdout: SplitParser {
      onRead: line => {
        const r = wallsRoot.parseStamped(line)
        if (r.p !== "") scanDownloaded.found.push(r)
      }
    }
    onRunningChanged: {
      if (running) { scanDownloaded.found = []; return }
      const f = scanDownloaded.found
      scanDownloaded.found = []
      downloadedModel.clear()
      let sc = "mkdir -p " + wallsRoot.shQuote(wallsRoot.liveCacheDir) + "\n" +
               "gen() { V=\"$1\"; F=\"$2\"; " +
               "[ -s \"$F\" ] || ffmpeg -nostdin -y -v error -ss 1 -i \"$V\" -frames:v 1 -vf scale=1280:-2 -q:v 2 \"$F\" 2>/dev/null; " +
               "[ -s \"$F\" ] || ffmpeg -nostdin -y -v error -i \"$V\" -frames:v 1 -vf scale=1280:-2 -q:v 2 \"$F\" 2>/dev/null; " +
               "[ -s \"$F\" ] && echo \"$V\"; }\n"
      let videos = 0
      for (let i = 0; i < f.length; i++) {
        const p = f[i].p
        const vid = /\.(mp4|mkv|webm|mov|m4v)$/i.test(p)
        const fr = wallsRoot.frameFor(p)
        downloadedModel.append(wallsRoot.itemRow(p.split("/").pop(), p, vid ? fr : p, !vid, f[i].m, vid))
        if (vid) { videos++; sc += "gen " + wallsRoot.shQuote(p) + " " + wallsRoot.shQuote(fr) + "\n" }
      }
      if (videos > 0 && !genDownThumbs.running) {
        genDownThumbs.script = sc
        genDownThumbs.running = true
      }

      if (wallsRoot.mode === "downloaded")
        wallsRoot.currentIndex = Math.max(0, Math.min(wallsRoot.currentIndex, f.length - 1))
    }
  }

  Process {
    id: genDownThumbs
    property string script: ""
    command: ["bash", "-c", script]
    running: false
    stdout: SplitParser {
      onRead: (line) => {
        const p = line.trim()
        for (let i = 0; i < downloadedModel.count; i++) {
          if (downloadedModel.get(i).path === p) {
            downloadedModel.setProperty(i, "ready", true)
            wallsRoot.thumbRev++
            break
          }
        }
      }
    }
  }

  // ─── Cambios de Ajustes → Wallpapers → En vivo ─────────────────────


  property bool liveOptForceSwap: false
  Timer {
    id: liveRelaunchDebounce
    interval: 900
    repeat: false
    onTriggered: if (wallsRoot.liveActivePath !== "" && !wallsRoot.liveStopped) wallsRoot.relaunchLiveNow()
  }
  Timer {
    id: liveOptDebounce
    interval: 900
    repeat: false
    onTriggered: { optimizeLive.running = false; clearOptCopies.running = true }
  }
  Process {
    id: clearOptCopies
    command: ["bash", "-c", "rm -f \"$1\"/*.mp4 2>/dev/null; true", "bash", wallsRoot.liveOptDir]
    running: false
    onExited: {
      if (wallsRoot.liveActivePath === "") return
      wallsRoot.liveOptForceSwap = true
      if (wallsRoot.liveOptimize) wallsRoot.optimizeActiveLive()
      else wallsRoot.relaunchLiveNow()
    }
  }
  Connections {
    target: Theme
    function onLiveRunRevChanged() { liveRelaunchDebounce.restart() }
    function onLiveOptRevChanged() { liveOptDebounce.restart() }
  }

  // ─── Carga de lista de Wallpapers ──────────────────────────────
  Process {
    id: loadWalls
    command: ["bash", "-c",
      "find " + wallsRoot.shQuote(wallsRoot.wallpaperFolder) + " -maxdepth 1 -type f -printf '%T@\\t%p\\n' 2>/dev/null | sort -t$'\\t' -k2 | grep -iE '\\.(jpg|jpeg|png|webp|gif)$'"
    ]
    running: true
    stdout: SplitParser {
      onRead: (line) => {
        const r = wallsRoot.parseStamped(line)
        if (r.p !== "") wallpaperModel.append(wallsRoot.itemRow(r.p.split("/").pop(), r.p, r.p, true, r.m, false))
      }
    }

    onRunningChanged: if (!running) {
      loadLastWp.running = true
      if (wallsRoot.staticDirty) { wallsRoot.staticDirty = false; rescanWalls.running = true }
    }
  }

  // ─── Proceso para leer la última imagen usada desde el caché ───
    Process {
      id: loadLastWp
      command: ["bash", "-c", "cat \"$HOME/.cache/awww/last\" 2>/dev/null"]
      running: false
      property string lastPath: ""
      stdout: SplitParser { onRead: line => loadLastWp.lastPath += line }
      onRunningChanged: {
        if (!running && lastPath !== "") {
          wallsRoot.restoreLastIndex(lastPath)
          lastPath = ""

          if (applyWallpaper.wpPath !== "") {
            wallsRoot.runMatugen()
          }
        }
      }
    }


    Process {
      id: refitWallpaper
      command: ["bash", "-c",
        wallsRoot.oozeStatic
          ? wallsRoot.oozeStaticApply(applyWallpaper.wpPath, false)
          : "awww img " + wallsRoot.shQuote(applyWallpaper.wpPath) + " " +
            wallsRoot.awwwFitArgs + " --transition-type fade --transition-duration 0.4"
      ]
      running: false
      stdout: SplitParser { onRead: line => console.log("[walls]", line) }
      stderr: SplitParser { onRead: line => console.log("[walls]", line) }
    }
    Connections {
      target: Theme
      function onWallRevChanged() {
        if (wallsRoot.liveActivePath === "" && applyWallpaper.wpPath !== ""
            && !applyWallpaper.running) {
          refitWallpaper.running = false
          refitWallpaper.running = true
        }
      }
    }

    Process {
      id: applyWallpaper
      property string wpPath: ""
      command: ["bash", "-c",

        (wallsRoot.oozeStatic ? "" : wallsRoot.killLiveCmd) +
        "rm -f " + wallsRoot.shQuote(wallsRoot.liveStateFile) + "; " +
        "mkdir -p \"$HOME/.cache/awww\" && " +
        (wallsRoot.oozeStatic
          ? wallsRoot.oozeStaticApply(wpPath, true)
          : "pkill -f 'oozewalls [_]_bg'; " +
            "awww img " + wallsRoot.shQuote(wpPath) + " " +
            wallsRoot.awwwFitArgs + " " +
            wallsRoot.awwwTransitionArgs(true)) + "; " +
        "echo " + wallsRoot.shQuote(wpPath) + " > \"$HOME/.cache/awww/last\""
      ]
      running: false
      stdout: SplitParser { onRead: line => console.log("[walls]", line) }
      stderr: SplitParser { onRead: line => console.log("[walls]", line) }
      onExited: (code) => console.log("[walls] aplicar estatico -> codigo " + code + " ruta=" + wpPath)
      onRunningChanged: {
        if (running) wallsRoot.beginChange(true)
        else if (wpPath !== "") wallsRoot.runMatugen()
      }
    }

    // ─── Live wallpapers: procesos ────────────────────────────────


    Process {
      id: loadLiveState
      command: ["bash", "-c",
        "p=$(cat " + wallsRoot.shQuote(wallsRoot.liveStateFile) + " 2>/dev/null); " +
        "if [ -n \"$p\" ] && [ -f \"$p\" ]; then echo \"$p\"; " +
        (wallsRoot.oozeLive
          ? wallsRoot.pathFix + "oozewalls restore --only live >/dev/null 2>&1; "
          : "pgrep -f '[m]pvpaper' >/dev/null || { " +
            "mkdir -p " + wallsRoot.shQuote(wallsRoot.liveCacheDir) + "; " +
            "rm -f " + wallsRoot.shQuote(wallsRoot.liveIpcSocket) + "; " +
            "V=\"$p\"; " + wallsRoot.optResolveCmd() +
            "setsid -f mpv\"\"paper -p -l " + wallsRoot.liveLayer + " -o " + wallsRoot.shQuote(wallsRoot.mpvOptions) +
            " '*' \"$V\" >>" + wallsRoot.shQuote(wallsRoot.liveLogFile) + " 2>&1; }; ") +
        "fi"
      ]
      running: false
      stdout: SplitParser { onRead: line => { if (line.trim() !== "") wallsRoot.liveActivePath = line.trim() } }
      onRunningChanged: {
        if (running) return
        scanLive.running = true
        if (wallsRoot.liveActivePath !== "") liveSyncDelay.restart()
      }
    }

    Process {
      id: restoreOozeStatic
      command: ["bash", "-c", wallsRoot.pathFix + "oozewalls restore --only static >/dev/null 2>&1"]
      running: false
    }

    property bool bootRestored: false
    function bootRestore() {
      if (wallsRoot.bootRestored) return
      wallsRoot.bootRestored = true
      loadLiveState.running = true
      if (wallsRoot.oozeStatic) restoreOozeStatic.running = true
    }
    Connections {
      target: Theme
      function onWallsPrefsLoaded() { wallsRoot.bootRestore() }
    }
    Timer {
      interval: 2500
      running: true
      repeat: false
      onTriggered: wallsRoot.bootRestore()
    }

    Process {
      id: scanLive
      command: ["bash", "-c",
        "find " + wallsRoot.liveScanDirs.map(d => wallsRoot.shQuote(d)).join(" ") + " -maxdepth 1 -type f -printf '%T@\\t%p\\n' 2>/dev/null " +
        "| grep -iE '\\.(mp4|mkv|webm|mov|avi|m4v)$' | sort -u -t$'\\t' -k2,2"
      ]
      running: false
      stdout: SplitParser {
        onRead: (line) => {
          const r = wallsRoot.parseStamped(line)
          if (r.p !== "") liveModel.append(wallsRoot.itemRow(
            r.p.split("/").pop(), r.p, wallsRoot.frameFor(r.p), false, r.m, true, "", wallsRoot.clipFor(r.p)))
        }
      }
      onRunningChanged: {

        if (running) { liveModel.clear(); return }
        if (wallsRoot.checkLiveDirty()) return
        wallsRoot.onLiveScanned()
      }
    }


    Process {
      id: genThumbs
      property string script: ""
      command: ["bash", "-c", script]
      running: false
      stdout: SplitParser {
        onRead: (line) => {
          const p = line.trim()
          for (let i = 0; i < liveModel.count; i++) {
            if (liveModel.get(i).path === p) {
              liveModel.setProperty(i, "ready", true)
              wallsRoot.thumbRev++
              break
            }
          }
        }
      }


      onRunningChanged: if (!running) { if (!wallsRoot.checkLiveDirty()) wallsRoot.startClipGen() }
    }


    Process {
      id: genClips
      property string script: ""
      command: ["bash", "-c", script]
      running: false
      stdout: SplitParser {
        onRead: (line) => {
          const p = line.trim()
          for (let i = 0; i < liveModel.count; i++) {
            if (liveModel.get(i).path === p) {
              liveModel.setProperty(i, "clipReady", true)
              wallsRoot.thumbRev++
              break
            }
          }
        }
      }
    }


    function startClipGen() {

      if (!wallsRoot.previewOn || Theme.shellPerf) return
      if (liveModel.count === 0 || genClips.running) return
      let sc = "mkdir -p " + wallsRoot.shQuote(wallsRoot.liveCacheDir) + "\n" +
        "VF='fps=12,scale=320:-2:flags=lanczos,split[s0][s1];[s0]palettegen=stats_mode=diff[p];[s1][p]paletteuse=dither=bayer'\n" +
        "gen() { V=\"$1\"; C=\"$2\"; " +
        "[ -s \"$C\" ] || ffmpeg -nostdin -y -v error -ss 1 -t 3 -i \"$V\" -vf \"$VF\" -loop 0 \"$C\" 2>/dev/null; " +
        "[ -s \"$C\" ] || ffmpeg -nostdin -y -v error -t 3 -i \"$V\" -vf \"$VF\" -loop 0 \"$C\" 2>/dev/null; " +
        "[ -s \"$C\" ] && echo \"$V\"; }\n"
      for (let i = 0; i < liveModel.count; i++) {
        const it = liveModel.get(i)
        if (!it.clipReady) sc += "gen " + wallsRoot.shQuote(it.path) + " " + wallsRoot.shQuote(it.clip) + "\n"
      }
      genClips.script = sc
      genClips.running = true
    }


    Process {
      id: applyLive
      property string videoPath: ""
      property string framePath: ""
      command: ["bash", "-c",
        "mkdir -p " + wallsRoot.shQuote(wallsRoot.liveCacheDir) + " \"$HOME/.cache/awww\"; " +
        wallsRoot.frameCmd(videoPath, framePath) +
        wallsRoot.liveReplaceKillCmd +
        wallsRoot.mpvLaunchCmd(videoPath, true) + "; " +
        "echo " + wallsRoot.shQuote(videoPath) + " > " + wallsRoot.shQuote(wallsRoot.liveStateFile) + "; " +

        "echo " + wallsRoot.shQuote(framePath) + " > \"$HOME/.cache/awww/last\""
      ]
      running: false
      stderr: SplitParser { onRead: (line) => console.log("[live]", line) }
      onRunningChanged: {
        console.log("[live] applyLive.running=" + running + " videoPath=" + videoPath)
        if (running) wallsRoot.beginChange(false)
        else if (videoPath !== "") {
          wallsRoot.runMatugen()
          liveSyncDelay.restart()
          wallsRoot.optimizeActiveLive()
        }
      }
    }


  // ─── Modo claro / oscuro ─────────────────────────────────────


  Connections {
    target: Theme
    function onLightModeChanged() { lightModeSettle.restart() }
  }

  Timer {
    id: lightModeSettle
    interval: 400
    repeat: false
    onTriggered: {
      if (wallsRoot.paletteSource === "") return
      wallsRoot.runMatugen()
    }
  }


  readonly property string matugenMode: Theme.lightMode ? "light" : "dark"

  // ─── Matugen ────────────────────────────────────────────────


  Process {
    id: matugenProc


    readonly property int idx: wallsRoot.effectiveSourceIndex
    command: ["bash", "-c",
      "F=" + wallsRoot.shQuote(Theme.colorsFile) + "; mkdir -p \"$(dirname \"$F\")\"; " +
      "P=" + wallsRoot.shQuote(wallsRoot.paletteSource) + "; I=" + idx + "; " +
      "M() { matugen image \"$P\" -m " + wallsRoot.matugenMode +
      " --source-color-index \"$1\" -t scheme-" + wallsRoot.schemes[wallsRoot.schemeIndex].name + " \"${@:2}\"; }; " +
      "M $I || { I=0; M 0; }; " +
      "M $I --json hex | sed -n '/^{/,/^}/p' > \"$F.tmp\"; " +
      "if [ -s \"$F.tmp\" ]; then mv -f \"$F.tmp\" \"$F\"; else rm -f \"$F.tmp\"; fi"
    ]
    running: false
    stderr: SplitParser { onRead: (line) => console.log("[matugen]", line) }
    onRunningChanged: {
      if (running) return


      if (wallsRoot.matugenAgain) {
        wallsRoot.matugenAgain = false
        Qt.callLater(() => { matugenProc.running = true })
        return
      }

      wallsRoot.colorsPending = true
      Theme.reload()

      wallsRoot.probeSourceColors()
    }
  }

  // ─── Colores fuente de matugen (selector de muestras) ──────────────


  property var sourceColors: []
  readonly property int effectiveSourceIndex:
    wallsRoot.sourceColors.length > 0
      ? Math.max(0, Math.min(Theme.wallSourceIndex, wallsRoot.sourceColors.length - 1))
      : Theme.wallSourceIndex

  property string sourceProbeKey: ""
  readonly property string sourceWantedKey:
    wallsRoot.paletteSource + "|" + wallsRoot.schemes[wallsRoot.schemeIndex].name + "|" + wallsRoot.matugenMode

  function probeSourceColors() {
    if (Theme.paletteMode || wallsRoot.paletteSource === "") return
    if (wallsRoot.sourceProbeKey === wallsRoot.sourceWantedKey && wallsRoot.sourceColors.length > 0) return
    if (probeColors.running) { probeColors.again = true; return }
    probeColors.key = wallsRoot.sourceWantedKey
    probeColors.running = true
  }


  function applySourceIndex(i) {
    if (i === wallsRoot.effectiveSourceIndex) return
    Theme.setWallsOpt("wallSourceIndex", i)
    if (wallsRoot.paletteSource !== "") {
      wallsRoot.beginChange(false)
      wallsRoot.runMatugen()
    }
  }


  function inkOn(hex) {
    const c = Qt.color(hex)
    return (0.299 * c.r + 0.587 * c.g + 0.114 * c.b) > 0.55 ? "#111111" : "#ffffff"
  }

  Process {
    id: probeColors
    property string key: ""
    property bool again: false
    property var found: []
    command: ["bash", "-c",
      "P=" + wallsRoot.shQuote(wallsRoot.paletteSource) + "; " +

      "matugen image --help 2>&1 | grep -q -- '--dry-run' || exit 0; " +
      "for i in 0 1 2 3 4 5; do " +
      "J=$(nice -n 10 matugen image \"$P\" -m " + wallsRoot.matugenMode +
      " --source-color-index $i -t scheme-" + wallsRoot.schemes[wallsRoot.schemeIndex].name +
      " --dry-run --json hex 2>/dev/null | sed -n '/^{/,/^}/p' | tr -d '\\n'); " +
      "[ -n \"$J\" ] || break; printf '%s\\t%s\\n' $i \"$J\"; done"
    ]
    running: false
    stdout: SplitParser {
      onRead: (line) => {
        const t = line.indexOf("\t")
        if (t < 0) return
        try {
          const j = JSON.parse(line.slice(t + 1))
          const hex = j.colors.primary[wallsRoot.matugenMode].color

          if (hex && probeColors.found.indexOf(hex) < 0) probeColors.found.push(hex)
        } catch (e) { console.log("[matugen] sondeo:", e) }
      }
    }
    onRunningChanged: {
      if (running) { found = []; return }
      if (again) { again = false; wallsRoot.sourceColors = []; Qt.callLater(wallsRoot.probeSourceColors); return }
      wallsRoot.sourceColors = found
      wallsRoot.sourceProbeKey = key
      found = []
    }
  }


  Connections {
    target: Theme
    function onColorsLoaded() {
      if (!wallsRoot.colorsPending) return
      wallsRoot.colorsPending = false
      if (wallsRoot.changing) {
        wallsRoot.settled = false
        settleTimer.restart()
      }
    }
  }

  // ─── Contenedor ──────────────────────────────────────────────

  readonly property real screenW: wallsWindow.screenWidth || 1920
  property real panelW: Math.min(screenW * 0.9, 1700)
  property real cardRatio: 0.34
  readonly property int pad: 24

  readonly property bool frameFloat: Theme.frameBorderActive
  readonly property int frameFloatGap: 8

  readonly property bool compact: Theme.wallsLayout === "compact-top"
  readonly property bool fullview: Theme.wallsLayout === "fullview"
  readonly property bool rail: Theme.wallsLayout === "rail"
  readonly property bool listview: Theme.wallsLayout === "list"

  readonly property int liveCount: liveModel.count
  readonly property int onlineCount: onlineModel.count
  readonly property int downloadedCount: downloadedModel.count
  readonly property bool liveScanning: scanLive.running
  readonly property bool thumbsGenerating: genThumbs.running

  FusedWindow {
    id: wallsWindow
    targetScreen: wallsRoot.targetScreen
    namespace: "oozeshell-walls"
    active: wallsRoot.open || panel.shown
    exclusiveKeys: true
    onCloseRequested: {
      wallsRoot.closeRequested()
      Theme.trimMemory()
    }

    onKeyPressed: (key, modifiers, text) => {
      if ((key === Qt.Key_K && (modifiers & Qt.ControlModifier)) || key === Qt.Key_Slash) {
        wallsRoot.focusSearchRequested()
        return
      }
      if (key === Qt.Key_Tab) {
        wallsRoot.cycleMode()
        return
      }
      if (key === Qt.Key_F && modifiers === Qt.NoModifier) {
        wallsRoot.previewOn = !wallsRoot.previewOn
        return
      }

      if (wallsRoot.activeModel.count === 0) return

      switch (key) {
        case Qt.Key_Left:
        case Qt.Key_Up:
        case Qt.Key_W:
        case Qt.Key_A:        wallsRoot.step(-1); break
        case Qt.Key_Right:
        case Qt.Key_Down:
        case Qt.Key_S:
        case Qt.Key_D:        wallsRoot.step(1); break
        case Qt.Key_PageUp:   wallsRoot.step(-5); break
        case Qt.Key_PageDown: wallsRoot.step(5); break
        case Qt.Key_Home:     wallsRoot.goTo(0); break
        case Qt.Key_End:      wallsRoot.goTo(wallsRoot.activeModel.count - 1); break
        case Qt.Key_R:        wallsRoot.randomIndex(); break
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space:
          wallsRoot.applyItem(wallsRoot.activeModel.get(wallsRoot.currentIndex)); break
      }
    }

    WallsPanel {
      id: panel
      walls: wallsRoot
    }

    Connections {
      target: wallsRoot
      function onReleaseSearchFocus() { wallsWindow.focusKeys() }
    }
  }
}
