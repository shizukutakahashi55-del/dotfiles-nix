// Walls.qml — WALLS

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../LANG"
import "../COMMON"


Item {
  id: wallsRoot

  property bool open: false
  property int currentIndex: 0
  property string targetScreen: "DP-3"
  signal closeRequested()


  signal liveSurfaceChanged()

  // ─── Vista previa (antes "Efectos") ─────────────────────────────


  property bool previewOn: true
  onPreviewOnChanged: if (wallsRoot.previewOn && wallsRoot.liveMode) wallsRoot.startClipGen()

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
  readonly property string mode: wallsRoot.onlineMode ? "online" : (wallsRoot.downloadedMode ? "downloaded" : (wallsRoot.liveMode ? "live" : "static"))
  readonly property int modeIndex: wallsRoot.mode === "static" ? 0 : (wallsRoot.mode === "live" ? 1 : (wallsRoot.mode === "online" ? 2 : 3))


  readonly property string liveIpcSocket: "/tmp/oozeshell-live.sock"


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
    decodeURIComponent(Qt.resolvedUrl("../tools/live-optimize.sh").toString().replace("file://", ""))


  readonly property bool liveStopWhenHidden: Theme.liveStopWhenHidden


  readonly property int liveRamLimitMB: Theme.liveRamLimitMB
  property bool liveStopped: false


  readonly property string liveLayer: Theme.liveLayer

  property string paletteSource: ""

  property string liveActivePath: ""
  property bool liveRestored: false

  property int thumbRev: 0

  property var indexMemory: ({ stat: 0, live: 0, online: 0, down: 0 })

  readonly property string liveCacheDir: Quickshell.env("HOME") + "/.cache/oozeshell/live"
  readonly property string liveStateFile: Quickshell.env("HOME") + "/.cache/oozeshell/live-active"

  ListModel { id: liveModel }

  readonly property var activeModel: wallsRoot.onlineMode ? onlineModel
                                   : (wallsRoot.downloadedMode ? downloadedModel
                                   : (wallsRoot.liveMode ? liveModel : wallpaperModel))

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

  function mpvLaunchCmd(video) {
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
    command: ["bash", "-c", wallsRoot.killLiveCmd + wallsRoot.mpvLaunchCmd(video)]
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
    } else if (wallsRoot.liveMode) {
      applyLive.videoPath = wp.path
      applyLive.framePath = wallsRoot.frameFor(wp.path)
      wallsRoot.paletteSource = applyLive.framePath
      wallsRoot.liveActivePath = wp.path
      wallsRoot.liveStopped = false
      applyLive.running = true
      console.log("[live] applyLive.running = true (videoPath=" + applyLive.videoPath + ")")
    } else {
      applyWallpaper.wpPath = wp.path
      wallsRoot.paletteSource = wp.path
      wallsRoot.liveActivePath = ""
      applyWallpaper.running = true
    }
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

  property int transitionHoldMs: 1300

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
    wallsRoot.liveMode ? wallsRoot.liveActivePath
                       : (wallsRoot.liveActivePath === "" ? applyWallpaper.wpPath : "")

  // ─── Volver a leer la carpeta al abrir ─────────────────────────


  onOpenChanged: {
    if (wallsRoot.open && wallsRoot.mode === "static" && !loadWalls.running && !rescanWalls.running)
      rescanWalls.running = true
    if (wallsRoot.open && wallsRoot.mode === "downloaded") wallsRoot.reloadDownloaded()
  }

  Process {
    id: rescanWalls
    property var found: []
    command: [ "bash", "-c",
      "find " + wallsRoot.shQuote(wallsRoot.wallpaperFolder) + " -maxdepth 1 -type f 2>/dev/null | sort | grep -iE '\\.(jpg|jpeg|png|webp|gif)$'" ]
    running: false
    stdout: SplitParser {
      onRead: line => { const p = line.trim(); if (p !== "") rescanWalls.found.push(p) }
    }
    onRunningChanged: {
      if (running) { rescanWalls.found = []; return }
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
        wallpaperModel.append({ "name": f[i].split("/").pop(), "path": f[i], "thumb": f[i], "ready": true })
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
  readonly property string onlineScript:
    decodeURIComponent(Qt.resolvedUrl("../tools/online-wallpapers.sh").toString().replace("file://", ""))

  readonly property string onlineSignature:
    [Theme.onlineSource, Theme.onlineQuery, Theme.onlineSorting, Theme.onlineCategories,
     Theme.onlineMinRes, Theme.onlineSaveDir, Theme.onlinePurity,
     Theme.onlineApiKey !== ""].join("|")

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
    if (wallsRoot.onlineMode && onlineModel.count > 0 && wallsRoot.currentIndex >= onlineModel.count - 4)
      wallsRoot.loadMoreOnline()
  }
  onOnlineSignatureChanged: {
    onlineModel.clear()
    wallsRoot.onlinePage = 1
    wallsRoot.onlineHasMore = true
    wallsRoot.onlineError = ""
    wallsRoot.indexMemory["online"] = 0
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
    command: ["bash", wallsRoot.onlineScript, Theme.onlineSource, Theme.onlineQuery,
              Theme.onlineSorting, Theme.onlineCategories, Theme.onlineMinRes,
              String(page), wallsRoot.onlineThumbDir, Theme.onlinePurity]

    environment: ({ "OOZE_WH_KEY": Theme.onlineApiKey })
    running: false
    stdout: SplitParser {
      onRead: (line) => {
        if (fetchOnline.restart) return
        const f = line.split("\t")
        if (f.length < 4 || f[0] === "") return
        const dest = wallsRoot.onlineDir + "/" + f[0]
        for (let i = 0; i < onlineModel.count; i++)
          if (onlineModel.get(i).path === dest) return
        onlineModel.append({ "name": f[3] !== "" ? f[3] : f[0], "path": dest, "thumb": f[2],
                             "ready": true, "url": f[1], "clip": "", "clipReady": false })
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
      }
    }
  }


  function applyOnlineItem(wp) {
    if (!wp || applyOnline.running || !wp.url) return
    applyOnline.url = wp.url
    applyOnline.dest = wp.path
    wallsRoot.beginChange(false)
    applyOnline.running = true
  }
  Process {
    id: applyOnline
    property string url: ""
    property string dest: ""
    running: false
    command: ["bash", "-c",
      "D=\"$2\"; mkdir -p \"$(dirname \"$D\")\"; " +
      "[ -s \"$D\" ] || { curl -fsSL --retry 2 -m 180 -A 'OozeShell/1.0' -o \"$D.part\" \"$1\" && mv -f \"$D.part\" \"$D\"; }; " +
      "[ -s \"$D\" ] || { rm -f \"$D.part\"; exit 1; }",
      "bash", url, dest]
    stderr: SplitParser { onRead: (line) => console.log("[online]", line) }
    onExited: (code) => {
      if (code === 0) {

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
      "find " + wallsRoot.shQuote(wallsRoot.onlineDir) + " -maxdepth 1 -type f 2>/dev/null | sort | grep -iE '\\.(jpg|jpeg|png|webp|gif)$'"]
    running: false
    stdout: SplitParser {
      onRead: line => { const p = line.trim(); if (p !== "") scanDownloaded.found.push(p) }
    }
    onRunningChanged: {
      if (running) { scanDownloaded.found = []; return }
      const f = scanDownloaded.found
      scanDownloaded.found = []
      downloadedModel.clear()
      for (let i = 0; i < f.length; i++)
        downloadedModel.append({ "name": f[i].split("/").pop(), "path": f[i], "thumb": f[i], "ready": true })

      if (wallsRoot.mode === "downloaded")
        wallsRoot.currentIndex = Math.max(0, Math.min(wallsRoot.currentIndex, f.length - 1))
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
      "find " + wallsRoot.shQuote(wallsRoot.wallpaperFolder) + " -maxdepth 1 -type f 2>/dev/null | sort | grep -iE '\\.(jpg|jpeg|png|webp|gif)$'"
    ]
    running: true
    stdout: SplitParser {
      onRead: (line) => {
        const p = line.trim()
        if (p !== "") wallpaperModel.append({ "name": p.split("/").pop(), "path": p, "thumb": p, "ready": true })
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
        "awww img " + wallsRoot.shQuote(applyWallpaper.wpPath) + " " +
        wallsRoot.awwwFitArgs + " --transition-type fade --transition-duration 0.4"
      ]
      running: false
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

        wallsRoot.killLiveCmd + "rm -f " + wallsRoot.shQuote(wallsRoot.liveStateFile) + "; " +
        "mkdir -p \"$HOME/.cache/awww\" && " +
        "awww img " + wallsRoot.shQuote(wpPath) + " " +
        wallsRoot.awwwFitArgs + " " +
        "--transition-type center " +
        "--transition-angle 30 " +
        "--transition-duration 1; " +
        "echo " + wallsRoot.shQuote(wpPath) + " > \"$HOME/.cache/awww/last\""
      ]
      running: false
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
        "pgrep -f '[m]pvpaper' >/dev/null || { " +
        "mkdir -p " + wallsRoot.shQuote(wallsRoot.liveCacheDir) + "; " +
        "rm -f " + wallsRoot.shQuote(wallsRoot.liveIpcSocket) + "; " +
        "V=\"$p\"; " + wallsRoot.optResolveCmd() +
        "setsid -f mpv\"\"paper -p -l " + wallsRoot.liveLayer + " -o " + wallsRoot.shQuote(wallsRoot.mpvOptions) +
        " '*' \"$V\" >>" + wallsRoot.shQuote(wallsRoot.liveLogFile) + " 2>&1; }; fi"
      ]
      running: true
      stdout: SplitParser { onRead: line => { if (line.trim() !== "") wallsRoot.liveActivePath = line.trim() } }
      onRunningChanged: {
        if (running) return
        scanLive.running = true
        if (wallsRoot.liveActivePath !== "") liveSyncDelay.restart()
      }
    }

    Process {
      id: scanLive
      command: ["bash", "-c",
        "find " + wallsRoot.liveScanDirs.map(d => wallsRoot.shQuote(d)).join(" ") + " -maxdepth 1 -type f 2>/dev/null " +
        "| grep -iE '\\.(mp4|mkv|webm|mov|avi|m4v)$' | sort -u"
      ]
      running: false
      stdout: SplitParser {
        onRead: (line) => {
          const p = line.trim()
          if (p !== "") liveModel.append({
            "name": p.split("/").pop(), "path": p,
            "thumb": wallsRoot.frameFor(p), "ready": false,
            "clip": wallsRoot.clipFor(p), "clipReady": false
          })
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

      if (!wallsRoot.previewOn || Theme.performanceMode) return
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
        wallsRoot.killLiveCmd +
        wallsRoot.mpvLaunchCmd(videoPath) + "; " +
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
  property real cardRatio: 0.24
  readonly property int pad: 24


  readonly property bool frameFloat: Theme.frameBorderActive
  readonly property int frameFloatGap: 8


  FusedWindow {
    id: wallsWindow
    targetScreen: wallsRoot.targetScreen
    namespace: "oozeshell-walls"
    active: wallsRoot.open || panel.shown
    exclusiveKeys: true
    onCloseRequested: {
      wallsRoot.closeRequested()
      gc()
    }


    onKeyPressed: (key, modifiers, text) => {
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
        case Qt.Key_A:        wallsRoot.step(-1); break
        case Qt.Key_Right:
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

      FusedPanel {
        id: panel


        edge: "bottom"
        align: "center"


        faceOffset: (Theme.barAtBottom ? Theme.barOffset
                                       : (wallsRoot.frameFloat ? Math.ceil(Theme.frameThicknessVis) : 0))
                    + (wallsRoot.frameFloat ? wallsRoot.frameFloatGap : 0)


        glassFloat: Theme.glassFloat && Theme.barAtBottom
        detached: (Theme.barAtBottom && (wallsWindow.detached || wallsRoot.changing)) || panel.glassFloat
                  || wallsRoot.frameFloat


        uiScale: 1.0
        open: wallsRoot.open
        panelWidth: wallsRoot.panelW
        contentHeight: col.implicitHeight + wallsRoot.pad * 2


        color: wallsRoot.fuse(Theme.bg, wallsRoot.fusionAlpha)

        ColumnLayout {
          id: col
          x: 0
          y: wallsRoot.pad
          width: parent.width
          spacing: 14

          // ─── CABECERA: Static/Live + esquemas ─────────────────
          RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: wallsRoot.pad
            Layout.rightMargin: wallsRoot.pad
            spacing: 10

            Item { Layout.fillWidth: true }

            // ─── BOTÓN Static / Live / Online / Downloaded ──────────


            SkinRect {
              id: modeBubble
              Layout.preferredWidth: modeToggle.width + 20
              Layout.preferredHeight: schemeFlow.implicitHeight + 20
              notch: 4
              raised: Theme.cozy
              depth: 3
              inkColor: Theme.primary
              color: Theme.bg
              border.color: Theme.primary
              border.width: 1.5

              Rectangle {
                id: modeToggle
                anchors.centerIn: parent
                width: 352; height: 26; radius: Theme.cozy ? 0 : 13
                color: Theme.tint(0.08)
                border.color: Theme.tint(0.18)
                border.width: Theme.bw1

                readonly property var modes: [
                  { id: "static", label: Translations.t("wallsModeStatic") },
                  { id: "live",   label: "▶ " + Translations.t("wallsModeLive") },
                  { id: "online", label: "☁ " + Translations.t("wallsModeOnline") },
                  { id: "downloaded", label: "⬇ " + Translations.t("wallsModeDownloaded") }
                ]
                readonly property real segW: width / modes.length


                Rectangle {
                  y: 2; height: parent.height - 4
                  width: modeToggle.segW - 2
                  radius: Theme.cozy ? 0 : 11
                  x: 1 + wallsRoot.modeIndex * modeToggle.segW
                  color: Theme.primary
                  Behavior on x { NumberAnimation { duration: Theme.animDuration(180); easing.type: Easing.OutCubic } }
                }

                Repeater {
                  model: modeToggle.modes
                  delegate: Text {
                    required property var modelData
                    required property int index
                    x: index * modeToggle.segW; width: modeToggle.segW; height: modeToggle.height
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                    text: modelData.label
                    font.pixelSize: 10
                    font.family: Theme.fontFamily
                    color: wallsRoot.mode === modelData.id ? Theme.bg : Theme.tint(0.8)
                  }
                }
                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: (mouse) => {
                    const i = Math.max(0, Math.min(modeToggle.modes.length - 1,
                                                  Math.floor(mouse.x / modeToggle.segW)))
                    wallsRoot.setMode(modeToggle.modes[i].id)
                  }
                }
              }
            }

            // ─── SELECTOR DE ESQUEMAS ──────────────────────────
            SkinRect {
              id: topBar
              Layout.preferredWidth: Math.min(500, col.width * 0.5)
              Layout.preferredHeight: schemeFlow.implicitHeight + 20
              notch: 4
              raised: Theme.cozy
              depth: 3
              inkColor: Theme.primary
              color: Theme.bg
              border.color: Theme.primary
              border.width: 1.5

              Flow {
                id: schemeFlow
                anchors.centerIn: parent
                spacing: 11

                Repeater {
                  model: wallsRoot.schemes
                  delegate: SkinRect {
                    id: schemeChip
                    readonly property bool active: index === wallsRoot.schemeIndex
                    width: chipText.implicitWidth + 20; height: 26
                    notch: 3
                    raised: Theme.cozy && active
                    depth: 2
                    inkColor: active ? Theme.primary : Theme.ink
                    color: active ? Theme.primary : Theme.tint(0.08)
                    border.color: active ? "#ffffff" : Theme.tint(0.18)
                    border.width: Theme.bw1
                    Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }

                    Text {
                      id: chipText
                      anchors.centerIn: parent
                      text: modelData.label
                      font.pixelSize: 10
                      font.family: Theme.fontFamily
                      color: schemeChip.active ? Theme.bg : Theme.tint(0.8)
                    }
                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: wallsRoot.applyScheme(index)
                    }
                  }
                }
              }
            }

            // ─── COLORES DE MATUGEN (1…x) ───────────────────────


            SkinRect {
              id: sourceBubble
              visible: !Theme.paletteMode && wallsRoot.sourceColors.length > 1
              Layout.preferredWidth: visible ? sourceRow.implicitWidth + 20 : 0
              Layout.preferredHeight: schemeFlow.implicitHeight + 20
              notch: 4
              raised: Theme.cozy
              depth: 3
              inkColor: Theme.primary
              color: Theme.bg
              border.color: Theme.primary
              border.width: 1.5

              Row {
                id: sourceRow
                anchors.centerIn: parent
                spacing: 8

                Repeater {
                  model: wallsRoot.sourceColors
                  delegate: SkinRect {
                    id: swatch
                    required property string modelData
                    required property int index
                    readonly property bool active: index === wallsRoot.effectiveSourceIndex
                    width: 26; height: 26
                    notch: 3
                    raised: Theme.cozy && active
                    depth: 2
                    inkColor: modelData
                    color: modelData
                    border.color: active ? "#ffffff" : Theme.tint(0.18)
                    border.width: active ? 2 : Theme.bw1
                    scale: swatchArea.containsMouse && !active ? 1.08 : 1.0
                    Behavior on scale { NumberAnimation { duration: Theme.animDuration(120) } }

                    Text {
                      anchors.centerIn: parent
                      text: swatch.index + 1
                      font.pixelSize: 10
                      font.bold: swatch.active
                      font.family: Theme.monoFamily
                      color: wallsRoot.inkOn(swatch.modelData)
                      opacity: swatch.active ? 1.0 : 0.7
                    }
                    MouseArea {
                      id: swatchArea
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: wallsRoot.applySourceIndex(swatch.index)
                    }
                  }
                }
              }
            }

            // ─── ACCIONES: aleatorio + vista previa ─────────────


            SkinRect {
              id: actionsBubble
              Layout.preferredWidth: actionsRow.implicitWidth + 20
              Layout.preferredHeight: schemeFlow.implicitHeight + 20
              notch: 4
              raised: Theme.cozy
              depth: 3
              inkColor: Theme.primary
              color: Theme.bg
              border.color: Theme.primary
              border.width: 1.5

              Row {
                id: actionsRow
                anchors.centerIn: parent
                spacing: 8


                SkinRect {
                  id: randomChip
                  width: randomText.implicitWidth + 20; height: 26
                  notch: 3
                  raised: Theme.cozy
                  depth: 2
                  inkColor: Theme.ink
                  color: randomArea.containsMouse ? Theme.tint(0.16) : Theme.tint(0.08)
                  border.color: Theme.tint(0.18); border.width: Theme.bw1
                  Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
                  Text {
                    id: randomText
                    anchors.centerIn: parent
                    text: "⚄  " + Translations.t("wallsRandom")
                    font.pixelSize: 10
                    font.family: Theme.fontFamily
                    color: Theme.tint(0.8)
                  }
                  MouseArea {
                    id: randomArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: wallsRoot.randomIndex()
                  }
                }


                SkinRect {
                  id: fxChip
                  width: fxText.implicitWidth + 20; height: 26
                  notch: 3
                  raised: Theme.cozy && wallsRoot.previewOn
                  depth: 2
                  inkColor: wallsRoot.previewOn ? Theme.primary : Theme.ink
                  color: wallsRoot.previewOn ? Theme.primary : Theme.tint(0.08)
                  border.color: wallsRoot.previewOn ? "#ffffff" : Theme.tint(0.18)
                  border.width: Theme.bw1
                  Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
                  Text {
                    id: fxText
                    anchors.centerIn: parent
                    text: "󰈈  " + Translations.t("wallsPreview") + "  " + (wallsRoot.previewOn ? "ON" : "OFF")
                    font.pixelSize: 10
                    font.family: Theme.monoFamily
                    color: wallsRoot.previewOn ? Theme.bg : Theme.tint(0.8)
                  }
                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: wallsRoot.previewOn = !wallsRoot.previewOn
                  }
                }
              }
            }

            Item { Layout.fillWidth: true }
          }

          // ══════════════════════════════════════════════════════

          // ══════════════════════════════════════════════════════


          Item {
            id: dockArea

            Layout.fillWidth: true
            Layout.preferredHeight: cardH

            // ─── Tamaño de las tarjetas ───
            property real cardW: width * wallsRoot.cardRatio
            property real cardH: cardW * (9.0 / 16.0)


            MouseArea {
              anchors.fill: parent
              z: -1
              acceptedButtons: Qt.NoButton
              onWheel: wheel => {
                if (wheelLock.running) return
                const dy = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x
                if (dy === 0) return
                wallsRoot.step(dy < 0 ? 1 : -1)
                wheelLock.restart()
              }
            }
            Timer { id: wheelLock; interval: 110; repeat: false }


    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height - dockArea.cardH / 2 - height / 2
        visible: wallsRoot.liveMode && liveModel.count === 0 && !scanLive.running
        horizontalAlignment: Text.AlignHCenter
        text: Translations.t("wallsNoLive") + "\n" + wallsRoot.liveFolder
        color: Theme.tint(0.67)
        font.pixelSize: 13
        font.family: Theme.fontFamily
    }


    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height - dockArea.cardH / 2 - height / 2
        width: parent.width * 0.8
        visible: wallsRoot.onlineMode && onlineModel.count === 0
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: wallsRoot.onlineLoading ? Translations.t("wallsOnlineLoading")
            : (wallsRoot.onlineError === "net" ? Translations.t("wallsOnlineNetError")
            : Translations.t("wallsOnlineEmpty"))
        color: Theme.tint(0.67)
        font.pixelSize: 13
        font.family: Theme.fontFamily
    }


    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height - dockArea.cardH / 2 - height / 2
        width: parent.width * 0.8
        visible: wallsRoot.downloadedMode && downloadedModel.count === 0
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: wallsRoot.downloadedLoading ? Translations.t("wallsOnlineLoading")
            : Translations.t("wallsDownloadedEmpty") + "\n" + wallsRoot.onlineDir
        color: Theme.tint(0.67)
        font.pixelSize: 13
        font.family: Theme.fontFamily
    }

    Repeater {
        model: wallsRoot.windowSize
        delegate: Item {
            id: cCard
            property int offset: index - wallsRoot.halfWindow
            property int total: wallsRoot.activeModel.count
            property bool slotActive:
                total > 0 &&
                Math.abs(offset) < Math.max(1, Math.ceil(total / 2))
            property int actualIndex:
                total > 0
                    ? ((wallsRoot.currentIndex + offset) % total + total) % total
                    : -1
            property var wp: {

                wallsRoot.thumbRev
                wallsRoot.liveMode
                wallsRoot.downloadedMode
                return (slotActive && actualIndex >= 0 && actualIndex < total)
                    ? wallsRoot.activeModel.get(actualIndex)
                    : null
            }
            property bool isCurrent: offset === 0
            property real cw: dockArea.cardW
            property real ch: dockArea.cardH

            // ─── OVERLAP ───


            property real spacing: cw * 0.52
            property real targetX:
                (dockArea.width / 2) -
                (cw / 2) +
                (offset * spacing)


            readonly property bool hovered: cardMouse.containsMouse
            property real targetY:
                (dockArea.height - ch) -
                ((wallsRoot.previewOn && hovered && !isCurrent) ? 10 : 0)

            // ─── ESCALA ───

            property real targetScale:
                isCurrent
                    ? 1.0
                    : Math.max(
                        0.92,
                        0.98 - Math.abs(offset) * 0.025
                    )

            // ─── OPACIDAD ───
            property real targetOpacity:
                !slotActive
                    ? 0.0
                    : (
                        isCurrent
                            ? 1.0
                            : Math.min(
                                0.97,
                                Math.max(
                                    0.50,
                                    0.82 - Math.abs(offset) * 0.08
                                ) + ((wallsRoot.previewOn && hovered) ? 0.15 : 0)
                            )
                    )

            // ─── ROTACIÓN ───
            property real targetAngle:
                offset * 0

            x: targetX
            y: targetY
            width: cw
            height: ch
            opacity: targetOpacity
            visible: slotActive

            z: isCurrent
                ? 99
                : 50 - Math.abs(offset)

            // ─── Animaciones de movimiento ───


            Behavior on x {
                enabled: panel.progress >= 0.999
                NumberAnimation {
                    duration: Theme.animDuration(350)
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on y {
                enabled: panel.progress >= 0.999
                NumberAnimation {
                    duration: Theme.animDuration(350)
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.animDuration(250)
                }
            }
            transform: [

                // ─── ESCALA ───
                Scale {
                    origin.x: cw / 2
                    origin.y: ch
                    xScale: cCard.targetScale
                    yScale: cCard.targetScale

                    Behavior on xScale {
                        NumberAnimation {
                            duration: Theme.animDuration(350)
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on yScale {
                        NumberAnimation {
                            duration: Theme.animDuration(350)
                            easing.type: Easing.OutCubic
                        }
                    }
                },

                // ─── ROTACIÓN ───
                Rotation {
                    origin.x: cw / 2
                    origin.y: ch / 2
                    angle: cCard.targetAngle
                    Behavior on angle {
                        NumberAnimation {
                            duration: Theme.animDuration(350)
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            ]

            // ══════════════════════════════════════════════

            // ══════════════════════════════════════════════

            SkinRect {
                id: cardFrame
                anchors.fill: parent
                clip: true
                radius: 0
                notch: 0
                raised: Theme.cozy
                depth: 4
                inkColor: cCard.isCurrent ? Theme.primary : Theme.ink
                color: Theme.bg
                border.color:
                    cCard.isCurrent
                        ? Theme.primary
                        : Theme.tint(0.25)
                border.width: 2
                Behavior on border.color {
                    ColorAnimation {
                        duration: Theme.animDuration(200)
                    }
                }

                // ─── Imagen ───

                Image {
                    id: cThumb
                    anchors.fill: parent
                    anchors.margins: cardFrame.border.width
                    source:
                        (cCard.wp && cCard.wp.ready)
                            ? ("file://" + cCard.wp.thumb)
                            : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    sourceSize.width: parent.width
                    sourceSize.height: parent.height


                    visible: !cAnim.visible || cAnim.status !== AnimatedImage.Ready
                    opacity:
                        status === Image.Ready
                            ? 1.0
                            : 0.0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.animDuration(280)
                        }
                    }
                }


                Rectangle {
                    id: shimmer
                    anchors.fill: parent
                    anchors.margins: cardFrame.border.width
                    visible: wallsRoot.previewOn && cCard.slotActive && cThumb.status !== Image.Ready
                    color: Theme.primary
                    opacity: 0.12
                    SequentialAnimation on opacity {
                        running: (shimmer.visible && wallsRoot.open) && Theme.uiAnimationsEnabled
                        loops: Animation.Infinite
                        NumberAnimation { from: 0.08; to: 0.26; duration: Theme.animDuration(900); easing.type: Easing.InOutSine }
                        NumberAnimation { from: 0.26; to: 0.08; duration: Theme.animDuration(900); easing.type: Easing.InOutSine }
                    }
                }

                // ─── Vista previa animada (solo tarjeta central) ───


                AnimatedImage {
                    id: cAnim
                    anchors.fill: parent
                    anchors.margins: cardFrame.border.width
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true


                    visible:
                        wallsRoot.previewOn &&
                        !Theme.performanceMode &&
                        wallsRoot.open &&
                        wallsRoot.liveMode &&
                        cCard.isCurrent &&
                        !!cCard.wp &&
                        !!cCard.wp.clipReady
                    source: visible ? ("file://" + cCard.wp.clip) : ""
                    playing: visible && Theme.uiAnimationsEnabled
                }


                SkinRect {
                    visible: wallsRoot.onlineMode && cCard.wp
                    anchors { top: parent.top; right: parent.right; margins: cardFrame.border.width + 6 }
                    width: onlineBadge.implicitWidth + 14; height: 20
                    notch: 3
                    raised: Theme.cozy
                    depth: 2
                    inkColor: Theme.primary
                    color: Qt.rgba(0, 0, 0, 0.65)
                    Text {
                        id: onlineBadge
                        anchors.centerIn: parent
                        text: "☁ ONLINE"
                        color: Theme.primary
                        font.pixelSize: 9
                        font.bold: true
                        font.family: Theme.fontFamily
                    }
                }


                SkinRect {
                    visible: wallsRoot.liveMode && cCard.wp
                    anchors { top: parent.top; right: parent.right; margins: cardFrame.border.width + 6 }
                    width: liveBadge.implicitWidth + 14; height: 20
                    notch: 3
                    raised: Theme.cozy
                    depth: 2
                    inkColor: Theme.primary
                    color: Qt.rgba(0, 0, 0, 0.65)
                    Text {
                        id: liveBadge
                        anchors.centerIn: parent
                        text: "▶ LIVE"
                        color: Theme.primary
                        font.pixelSize: 9
                        font.bold: true
                        font.family: Theme.fontFamily
                    }
                }


                SkinRect {
                    visible: !!cCard.wp && cCard.wp.path === wallsRoot.appliedPath
                    anchors { top: parent.top; left: parent.left; margins: cardFrame.border.width + 6 }
                    width: curBadge.implicitWidth + 14; height: 20
                    notch: 3
                    raised: Theme.cozy
                    depth: 2
                    inkColor: Theme.primary
                    color: Theme.primary
                    Text {
                        id: curBadge
                        anchors.centerIn: parent
                        text: "● " + Translations.t("wallsCurrent")
                        color: Theme.bg
                        font.pixelSize: 9
                        font.bold: true
                        font.family: Theme.fontFamily
                    }
                }

                // ══════════════════════════════════════════

                // ══════════════════════════════════════════

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: cardFrame.border.width
                    height: 36
                    color: Qt.rgba(0, 0, 0, 0.65)
                    visible:
                        cCard.isCurrent &&
                        cCard.wp

                    RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: 12
                            rightMargin: 12
                        }

                        Text {
                            text:
                                cCard.wp
                                    ? cCard.wp.name.replace(
                                        /\.[^.]+$/,
                                        ""
                                    )
                                    : ""

                            color: "#ffffffdd"
                            font.pixelSize: 11
                            font.family: Theme.fontFamily
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text:
                                Translations.t(
                                    wallsRoot.changing ? "wallsApplying"
                                    : (wallsRoot.onlineMode && wallsRoot.onlineError === "net" ? "wallsOnlineFailed"
                                    : "wallsApplyHint")
                                )
                            color:
                                Theme.primary

                            font.pixelSize: 9
                            font.family: Theme.fontFamily
                        }
                    }
                }
            }

            // ══════════════════════════════════════════════

            // ══════════════════════════════════════════════

            MouseArea {
                id: cardMouse
                anchors.fill: parent
                enabled: cCard.slotActive
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (cCard.isCurrent) {
                        wallsRoot.applyItem(cCard.wp)
                    } else {
                        wallsRoot.currentIndex =
                            cCard.actualIndex
                    }
                }
            }
        }
    }
          }

          // ─── PAGINADOR + CONTADOR ───────────────────────────
          Item {
            Layout.fillWidth: true
            Layout.leftMargin: wallsRoot.pad
            Layout.rightMargin: wallsRoot.pad
            Layout.preferredHeight: 32

            Row {
              anchors.centerIn: parent
              spacing: 6
              Repeater {
                model: Math.min(wallsRoot.activeModel.count, 15)
                delegate: Rectangle {
                  width: index === (wallsRoot.currentIndex % 15) ? 18 : 6; height: 6; radius: Theme.cozy ? 0 : 3
                  color: index === (wallsRoot.currentIndex % 15) ? Theme.primary : Theme.tint(0.25)
                  Behavior on width { NumberAnimation { duration: Theme.animDuration(200) } }
                }
              }
            }

            // ─── HUD (Contador) ──────────────────────────────
            SkinRect {
              id: counterPill
              anchors { right: parent.right; verticalCenter: parent.verticalCenter }
              width: counterText.width + 24; height: 32
              notch: 4
              raised: Theme.cozy
              depth: 3
              inkColor: Theme.ink
              color: Qt.rgba(0, 0, 0, 0.55)
              border.color: Qt.rgba(1, 1, 1, 0.18)
              border.width: Theme.bw1

              Text {
                id: counterText
                anchors.centerIn: parent
                text: (wallsRoot.activeModel.count > 0 ? wallsRoot.currentIndex + 1 : 0) + " / " + wallsRoot.activeModel.count
                + (genThumbs.running ? "  ·  " + Translations.t("wallsGenerating") : "")
                + (wallsRoot.onlineMode && wallsRoot.onlineLoading ? "  ·  " + Translations.t("wallsOnlineLoading") : "")
                color: Qt.rgba(1,1,1,0.75)
                font.pixelSize: 11
                font.family: Theme.fontFamily
              }
            }
          }
        }
      }
  }
}
