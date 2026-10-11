// WM — capa común de window manager + distro (Global-Manager).
// FASE 1: selección y persistencia (wm.json), detección, tabla de capacidades y las acciones básicas (enfocar ventana, ir a workspace, salir). FASE 2: estado unificado (monitores, ventanas, workspaces, fullscreen, layout

pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: root

  // ─── Catálogo ───────────────────────────────────────────────────
  readonly property var wmList: [
    { id: "hyprland", name: "Hyprland" },
    { id: "mango",    name: "MangoWM"  },
    { id: "niri",     name: "Niri"     }
  ]
  readonly property var distroList: [
    { id: "arch",  name: "Arch Linux" },
    { id: "nixos", name: "NixOS"      }
  ]
  readonly property var pkgHelperList: ["paru", "yay", "pacman"]

  // ─── Selección del usuario ("auto" = detectar) ──────────────────
  property string wmPref: "auto"
  property string distroPref: "auto"
  property string pkgHelperPref: "auto"

  // ─── Detección ──────────────────────────────────────────────────
  readonly property string detectedWm: {
    if (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")) return "hyprland"
    if (Quickshell.env("MANGO_INSTANCE_SIGNATURE"))    return "mango"
    if (Quickshell.env("NIRI_SOCKET"))                 return "niri"
    return ""
  }


  property string osIds: ""
  readonly property string detectedDistro: {
    const ids = root.osIds.toLowerCase().split(/\s+/)
    if (ids.indexOf("nixos") >= 0) return "nixos"
    if (ids.indexOf("arch") >= 0)  return "arch"
    return ""
  }


  property var installedTools: []
  function isInstalled(tool) { return root.installedTools.indexOf(tool) >= 0 }

  // ─── Valores efectivos ──────────────────────────────────────────
  readonly property string wm: {
    if (root.wmPref !== "auto") return root.wmPref
    return root.detectedWm !== "" ? root.detectedWm : "hyprland"
  }
  readonly property string distro: {
    if (root.distroPref !== "auto") return root.distroPref
    return root.detectedDistro !== "" ? root.detectedDistro : "nixos"
  }


  readonly property bool wmMismatch: root.detectedWm !== "" && root.detectedWm !== root.wm


  readonly property string packageBackend: {
    if (root.distro === "nixos") return "nix-search"
    if (root.pkgHelperPref !== "auto") return root.pkgHelperPref
    for (const h of root.pkgHelperList) if (root.isInstalled(h)) return h
    return "pacman"
  }

  // ─── Capacidades por WM ─────────────────────────────────────────


  readonly property var capTable: ({
    hyprland: { liveOptions: true,  animProfile: true,  workspaceLayouts: true,
                monitorEditor: true,  blur: true,  shadow: true,  gapsSync: true,
                specialWorkspaces: true,  fullscreenDetect: true, hyprshutdown: true },
    mango:    { liveOptions: true,  animProfile: true,  workspaceLayouts: true,
                monitorEditor: false, blur: true,  shadow: true,  gapsSync: true,
                specialWorkspaces: false, fullscreenDetect: true, hyprshutdown: false },


    niri:     { liveOptions: true,  animProfile: true,  workspaceLayouts: true,
                monitorEditor: false, blur: true,  shadow: true,  gapsSync: true,
                specialWorkspaces: false, fullscreenDetect: false, hyprshutdown: false }
  })
  readonly property var capKeys: ["liveOptions", "animProfile", "workspaceLayouts", "monitorEditor",
                                  "blur", "shadow", "gapsSync", "specialWorkspaces", "fullscreenDetect"]
  function has(cap) {
    const t = root.capTable[root.wm]
    return t ? t[cap] === true : false
  }


  // ─── Estado unificado ───────────────────────────────────────────


  readonly property bool perMonitorWorkspaces: root.wm !== "hyprland"


  readonly property var monitors: {
    switch (root.wm) {
      case "mango": return MangoIpc.monitorsCompat
      case "niri":  return NiriState.monitors
      default:      return HyprState.monitors
    }
  }


  readonly property var clients: {
    switch (root.wm) {
      case "mango": return MangoIpc.clientsCompat
      case "niri":  return NiriState.clients
      default:      return HyprState.clients
    }
  }

  readonly property string focusedMonitorName: {
    switch (root.wm) {
      case "mango": return MangoIpc.focusedMonitorName
      case "niri":  return NiriState.focusedMonitorName
      default:      return HyprState.focusedMonitorName
    }
  }


  function workspacesFor(screenName, includeSpecial) {
    const sn = screenName ?? ""
    switch (root.wm) {
      case "mango": return MangoIpc.workspacesFor(sn !== "" ? sn : MangoIpc.focusedMonitorName, false)
      case "niri":  return NiriState.workspacesFor(sn, includeSpecial === true)
      default:
        return includeSpecial === true ? HyprState.workspaces : HyprState.workspaces.filter(w => w.id > 0)
    }
  }


  function barWorkspacesFor(screenName) {
    const all = root.workspacesFor(screenName, true)
    return root.wm === "niri" ? all.filter(w => w.active) : all
  }


  function dotsWorkspacesFor(screenName) {
    const sn = screenName ?? ""
    if (root.wm === "mango")
      return MangoIpc.workspacesFor(sn !== "" ? sn : MangoIpc.focusedMonitorName, true)
    if (root.wm === "niri") return root.barWorkspacesFor(sn)
    const live = HyprState.workspaces.filter(w => w.id > 0)
    let max = 10
    const seen = {}
    for (let i = 0; i < live.length; i++) {
      seen[live[i].id] = true
      if (live[i].id > max) max = live[i].id
    }
    const out = live.slice()
    for (let i = 1; i <= max; i++) {
      if (seen[i]) continue
      const id = i

      out.push({ id: id, name: String(id), active: false, urgent: false, occupied: false,
        activate: () => Quickshell.execDetached(["hyprctl", "dispatch", "workspace", String(id)]) })
    }
    out.sort((a, b) => a.id - b.id)
    return out
  }


  readonly property bool hasNativeOverview: root.wm === "niri"
  function toggleNativeOverview() {
    if (root.wm === "niri") Quickshell.execDetached(["niri", "msg", "action", "toggle-overview"])
  }
  function openNativeOverview() {
    if (root.wm === "niri") Quickshell.execDetached(["niri", "msg", "action", "open-overview"])
  }
  function closeNativeOverview() {
    if (root.wm === "niri") Quickshell.execDetached(["niri", "msg", "action", "close-overview"])
  }


  function clickWorkspace(w) {
    if (root.hasNativeOverview) root.toggleNativeOverview()
    else if (w && w.activate) w.activate()
  }


  function wsMonitorName(w) {
    if (!w || !w.monitor) return ""
    return typeof w.monitor === "string" ? w.monitor : (w.monitor.name || "")
  }


  function activeWorkspaceId(screenName) {
    switch (root.wm) {
      case "mango": { const t = MangoIpc.activeTag(screenName); return t > 0 ? t : -999 }
      case "niri":  return NiriState.activeWorkspaceId(screenName)
      default:      return HyprState.activeWorkspaceId(screenName)
    }
  }


  function hasFullscreen(screen) {
    if (!screen) return false
    switch (root.wm) {
      case "mango": return MangoIpc.hasFullscreen(screen.name)
      case "niri":  return false
      default:      return HyprState.hasFullscreen(screen)
    }
  }


  function toplevelFor(address) {
    switch (root.wm) {
      case "mango": return MangoIpc.toplevelFor(address)
      case "niri":  return NiriState.toplevelFor(address)
      default:      return HyprState.toplevelFor(address)
    }
  }


  function retainClients(key)  { if (root.wm === "hyprland") HyprState.retain(key) }
  function releaseClients(key) { if (root.wm === "hyprland") HyprState.release(key) }
  function refreshClients()    { if (root.wm === "hyprland") HyprState.refresh() }

  function withClients(cb) {
    if (root.wm === "hyprland") HyprState.snapshot(cb)
    else cb(root.clients)
  }

  // ─── Teclado ────────────────────────────────────────────────────

  readonly property string keyboardLayoutName: {
    switch (root.wm) {
      case "mango": return MangoIpc.keyboardLayoutName
      case "niri":  return NiriState.kbLayout
      default:      return HyprState.kbLayout
    }
  }

  function nextKeyboardLayout(all, preferredName) {
    switch (root.wm) {
      case "mango": MangoIpc.nextKeyboardLayout(); break
      case "niri":  NiriState.nextLayout(); break
      default:
        HyprState.kbPreferred = preferredName ?? HyprState.kbPreferred
        HyprState.kbNext(all !== false)
    }
  }
  function setPreferredKeyboard(name) {
    if (root.wm !== "hyprland") return
    HyprState.kbPreferred = name
    HyprState.kbRefresh()
  }
  function refreshKeyboard() { if (root.wm === "hyprland") HyprState.kbRefresh() }

  // ─── Acciones (validan el argumento antes de ejecutar nada) ─────

  function focusWindow(address) {
    const a = String(address ?? "")
    switch (root.wm) {
      case "hyprland": HyprDispatch.focusWindow(a); break
      case "mango":    MangoIpc.focusClient(a); break
      case "niri":
        if (/^[0-9]+$/.test(a))
          Quickshell.execDetached(["niri", "msg", "action", "focus-window", "--id", a])
        break
    }
  }


  function workspace(id, monitorName) {
    const n = parseInt(id)
    if (isNaN(n)) return
    switch (root.wm) {
      case "hyprland": HyprDispatch.workspace(n); break
      case "mango":    MangoIpc.viewTag(n, monitorName); break
      case "niri":
        NiriState.focusWorkspace(monitorName ?? "", n)
        break
    }
  }


  function logoutCommand() {
    switch (root.wm) {
      case "mango": return ["mmsg", "dispatch", "quit"]
      case "niri":  return ["niri", "msg", "action", "quit", "--skip-confirmation"]
      default:      return ["sh", "-c", "hyprctl dispatch 'hl.dsp.exit()'"]
    }
  }
  function logoutShell() {
    switch (root.wm) {
      case "mango": return "mmsg dispatch quit"
      case "niri":  return "niri msg action quit --skip-confirmation"
      default:      return "command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"
    }
  }

  // ─── Setters (guardan al toque) ─────────────────────────────────
  function setWm(id) {
    if (id !== "auto" && !root.wmList.some(w => w.id === id)) return
    root.wmPref = id; root.save()
  }
  function setDistro(id) {
    if (id !== "auto" && !root.distroList.some(d => d.id === id)) return
    root.distroPref = id; root.save()
  }
  function setPkgHelper(id) {
    if (id !== "auto" && root.pkgHelperList.indexOf(id) < 0) return
    root.pkgHelperPref = id; root.save()
  }

  // ─── Persistencia ───────────────────────────────────────────────
  readonly property string prefsDir: Quickshell.env("HOME") + "/.config/oozeshell"
  readonly property string prefsFile: prefsDir + "/wm.json"

  function save() {
    saveProc.json = JSON.stringify({ wm: root.wmPref, distro: root.distroPref, pkgHelper: root.pkgHelperPref })
    if (saveProc.running) saveProc.pending = true
    else saveProc.running = true
  }

  Process {
    id: saveProc
    property string json: ""
    property bool pending: false

    command: ["sh", "-c", 'mkdir -p "$1" && printf %s "$3" > "$2.tmp" && mv "$2.tmp" "$2"',
              "sh", root.prefsDir, root.prefsFile, saveProc.json]
    onRunningChanged: {
      if (!running && saveProc.pending) { saveProc.pending = false; saveProc.running = true }
    }
  }

  Process {
    id: loadProc
    command: ["sh", "-c", 'cat "$1" 2>/dev/null', "sh", root.prefsFile]
    running: true
    property string buffer: ""
    stdout: SplitParser { onRead: line => loadProc.buffer += line }
    onRunningChanged: {
      if (running) return
      const raw = loadProc.buffer.trim()
      loadProc.buffer = ""
      if (raw === "") return
      try {
        const j = JSON.parse(raw)
        root.wmPref = (j.wm === "auto" || root.wmList.some(w => w.id === j.wm)) ? j.wm : "auto"
        root.distroPref = (j.distro === "auto" || root.distroList.some(d => d.id === j.distro)) ? j.distro : "auto"
        root.pkgHelperPref = (j.pkgHelper === "auto" || root.pkgHelperList.indexOf(j.pkgHelper) >= 0) ? j.pkgHelper : "auto"
      } catch (e) {
        console.log("WM: error leyendo wm.json:", e)
      }
    }
  }


  Process {
    id: detectProc
    command: ["sh", "-c",
      '. /etc/os-release 2>/dev/null; echo "IDS:$ID $ID_LIKE"; ' +
      'for c in paru yay pacman nix-search nix rofi waybar; do command -v "$c" >/dev/null 2>&1 && echo "BIN:$c"; done']
    running: true
    property var tools: []
    stdout: SplitParser {
      onRead: line => {
        if (line.startsWith("IDS:")) root.osIds = line.slice(4).trim()
        else if (line.startsWith("BIN:")) detectProc.tools = detectProc.tools.concat([line.slice(4).trim()])
      }
    }
    onRunningChanged: { if (!running) root.installedTools = detectProc.tools }
  }
}
