// DefaultApps

pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../COMMON"
import "../../Modules/QuickBar"

Singleton {
  id: root


  property var choices: ({})
  property var customs: ({})
  property var installed: ({})
  property bool detected: false
  property bool loaded: false

  property string mimeFilesId: ""
  property var mimeRoles: ({
    files: ["inode/directory"],
    video: ["video/mp4"],
    music: ["audio/mpeg"],
    browser: ["x-scheme-handler/http", "x-scheme-handler/https"]
  })
  property var mimeState: ({})
  signal failed(string role)

  Component.onCompleted: { root.refreshMime(); root.refreshDesktopMimes() }
  function refreshMime(role) {
    const roles = role !== undefined ? [role] : Object.keys(root.mimeRoles)
    let queued = false
    for (const r of roles) {
      if (root.mimeRoles[r] === undefined || mimeQueryQueue.indexOf(r) >= 0) continue
      mimeQueryQueue.push(r)
      queued = true
    }
    if (queued && !mimeQueryWorker.running) root.pumpMimeQueue()
  }
  property var mimeQueryQueue: []
  function pumpMimeQueue() {
    if (mimeQueryWorker.running || mimeQueryQueue.length === 0) return
    const r = mimeQueryQueue[0]
    mimeQueryWorker.role = r
    mimeQueryWorker.mime = root.mimeRoles[r][0]
    mimeQueryWorker.running = true
  }
  Process {
    id: mimeQueryWorker
    property string mime: ""
    property string role: ""
    property string buffer: ""
    command: ["xdg-mime", "query", "default", mimeQueryWorker.mime]
    running: false
    stdout: SplitParser { onRead: line => mimeQueryWorker.buffer += line }
    onRunningChanged: {
      if (running) return
      const id = mimeQueryWorker.buffer.trim()
      mimeQueryWorker.buffer = ""
      const done = mimeQueryQueue.length > 0 ? mimeQueryQueue.shift() : mimeQueryWorker.role
      void done
      const st = Object.assign({}, root.mimeState)
      if (mimeQueryWorker.role === "files") root.mimeFilesId = id
      st[mimeQueryWorker.role] = { id: id, pending: false, error: "" }
      root.mimeState = st
      root.pumpMimeQueue()
    }
  }

  property var desktopDirIds: []
  function refreshDesktopMimes() {
    if (!desktopMimeProc.running) desktopMimeProc.running = true
  }
  Process {
    id: desktopMimeProc
    command: ["python3", Quickshell.shellDir + "/Backends/python/ooze-daemon.py",
      "desktop-mimes", "--", "inode/directory"]
    running: false
    property string buffer: ""
    stdout: SplitParser { onRead: line => desktopMimeProc.buffer += line }
    onRunningChanged: {
      if (running) return
      try {
        const doc = JSON.parse(desktopMimeProc.buffer.trim())
        if (doc && doc.ok === true)
          root.desktopDirIds = (doc.apps || []).map(a => a.id)
      } catch (e) {}
      desktopMimeProc.buffer = ""
    }
  }

  function desktopEntryById(id) {
    let key = String(id ?? "")
    if (key.endsWith(".desktop")) key = key.slice(0, -8)
    if (key === "") return null
    const list = DesktopEntries.applications.values
    for (let i = 0; i < list.length; i++) {
      const e = list[i]
      if (e && (e.id === key || e.id === id)) return e
    }
    try {
      const h = DesktopEntries.heuristicLookup(key)
      if (h) return h
    } catch (e) {}
    return null
  }

  function desktopExecBase(entry) {
    const c = entry && entry.command
    if (!c || c.length === 0) return ""
    const parts = String(c[0]).split("/")
    return parts[parts.length - 1]
  }

  function roleBins(role) {
    if (role === "browser") {
      const out = {}
      for (const b of QuickBarConfig.browsers)
        for (const bin of (b.bins ?? [])) out[bin] = b.id
      return out
    }
    const info = root.roleInfo(role)
    if (!info) return {}
    const out = {}
    for (let i = 0; i < info.apps.length; i++)
      for (const b of info.apps[i].bins) out[b] = info.apps[i].id
    return out
  }

  function desktopHitsFor(role) {
    const byBin = root.roleBins(role)
    if (Object.keys(byBin).length === 0) return []
    const strict = role === "files" ? root.desktopDirIds.length > 0 : true
    const seen = {}
    const out = []
    const list = DesktopEntries.applications.values
    for (let i = 0; i < list.length; i++) {
      const e = list[i]
      if (!e || e.noDisplay) continue
      const base = root.desktopExecBase(e)
      if (base === "") continue
      const appId = byBin[base] ?? ""
      if (appId === "") continue
      const rawExec = (e.command ?? []).join(" ")
      if (/--app(-id)?=/.test(rawExec)) continue
      if (strict && role === "files") {
        const entryId = (e.id || "") + ".desktop"
        if (root.desktopDirIds.indexOf(entryId) < 0) continue
      }
      const key = appId
      if (seen[key]) {
        const prev = out.filter(o => o.id === key)[0]
        if (prev && (prev.desktopId === "" || prev.desktopId === undefined) && e.id) prev.desktopId = e.id
        continue
      }
      seen[key] = true
      out.push({ id: key, name: e.name || e.id || key,
                 icon: e.icon || "", desktopId: e.id || "",
                 catalog: true })
    }
    out.sort((a, b) => String(a.name).localeCompare(String(b.name)))
    return out
  }

  function filesDesktopHits() {
    const out = root.desktopHitsFor("files").slice()
    const strict = root.desktopDirIds.length > 0
    const list = DesktopEntries.applications.values
    for (let i = 0; i < list.length; i++) {
      const e = list[i]
      if (!e || e.noDisplay) continue
      if (root.desktopExecBase(e) === "") continue
      const entryId = (e.id || "") + ".desktop"
      if (strict && root.desktopDirIds.indexOf(entryId) < 0) continue
      const key = "desktop:" + (e.id || "")
      if (key === "desktop:") continue
      let dup = false
      for (const o of out) if (o.id === key || o.desktopId === e.id) { dup = true; break }
      if (dup) continue
      out.push({ id: key, name: e.name || e.id || key,
                 icon: e.icon || "", desktopId: e.id || "",
                 catalog: false })
    }
    out.sort((a, b) => String(a.name).localeCompare(String(b.name)))
    return out
  }

  function setSystemDefault(role, desktopId) {
    const mimes = root.mimeRoles[role]
    let entry = null
    if (typeof desktopId === "string" && desktopId !== "") {
      let key = desktopId
      if (key.startsWith("desktop:")) key = key.slice(8)
      if (key.endsWith(".desktop")) key = key.slice(0, -8)
      entry = root.desktopEntryById(key)
    }
    if (mimes === undefined || entry === null) return false
    let full = entry.id || ""
    if (full !== "" && !full.endsWith(".desktop")) full += ".desktop"
    if (full === "") return false
    const st = Object.assign({}, root.mimeState)
    st[role] = { id: full, pending: true, error: "" }
    root.mimeState = st
    mimeSetWorker.role = role
    mimeSetWorker.desktopId = full
    mimeSetWorker.mimes = mimes.slice()
    mimeSetWorker.running = false
    mimeSetWorker.running = true
    return true
  }
  Process {
    id: mimeSetWorker
    property string role: ""
    property string desktopId: ""
    property var mimes: []
    property string err: ""
    command: ["xdg-mime", "default", mimeSetWorker.desktopId, mimeSetWorker.mimes[0] ?? ""]
    running: false
    stderr: SplitParser { onRead: line => { if (line.trim() !== "") mimeSetWorker.err = line.trim() } }
    onRunningChanged: {
      if (running) return
      const ok = mimeSetWorker.err === ""
      const rest = mimeSetWorker.mimes.slice(1)
      if (ok && rest.length > 0) {
        mimeSetWorker.mimes = rest
        mimeSetWorker.err = ""
        mimeSetWorker.running = true
        return
      }
      const st = Object.assign({}, root.mimeState)
      st[mimeSetWorker.role] = { id: mimeSetWorker.desktopId, pending: false,
                                 error: ok ? "" : mimeSetWorker.err }
      root.mimeState = st
      mimeSetWorker.err = ""
      if (ok) root.refreshMime(mimeSetWorker.role)
      else root.failed(mimeSetWorker.role)
    }
  }

  function resolveChoiceDesktop(role, choiceId) {
    if (typeof choiceId === "string" && choiceId.startsWith("desktop:")) {
      const e = root.desktopEntryById(choiceId.slice(8))
      return e ? (e.id + ".desktop") : ""
    }
    if (choiceId === "system") {
      const st = root.mimeState[role]
      const id = st !== undefined ? st.id : (role === "files" ? root.mimeFilesId : "")
      return id ?? ""
    }
    for (const h of root.desktopHitsFor(role)) {
      if (h.id === choiceId && h.desktopId !== "") {
        let full = h.desktopId
        if (!full.endsWith(".desktop")) full += ".desktop"
        return full
      }
    }
    return ""
  }

  function mimeNoteFor(role) {
    const st = root.mimeState[role]
    if (st !== undefined && st.pending) return "Sistema: aplicando…"
    const id = st !== undefined ? st.id : (role === "files" ? root.mimeFilesId : "")
    if (id === undefined || id === "") return ""
    if (st !== undefined && st.error !== "") return "Sistema: error: " + st.error
    const e = root.desktopEntryById(id)
    if (e) return "Sistema: " + (e.name || e.id) + " (" + id + ")"
    return "Sistema: " + id + " (no instalado)"
  }

  readonly property string dir: Quickshell.env("HOME") + "/.config/oozeshell"
  readonly property string file: root.dir + "/defaultapps.json"


  readonly property var roles: [
    { id: "browser", icon: "󰖟", nameKey: "daRoleBrowser", linked: "quickbar", apps: [] },
    { id: "terminal", icon: "󰆍", nameKey: "daRoleTerminal", linked: "theme", apps: [] },
    { id: "files", icon: "󰉋", nameKey: "daRoleFiles", linked: "", apps: [
      { id: "nautilus",   name: "Files (Nautilus)", bins: ["nautilus"],                term: false },
      { id: "thunar",     name: "Thunar",           bins: ["thunar"],                  term: false },
      { id: "dolphin",    name: "Dolphin",          bins: ["dolphin"],                 term: false },
      { id: "nemo",       name: "Nemo",             bins: ["nemo"],                    term: false },
      { id: "pcmanfm",    name: "PCManFM",          bins: ["pcmanfm", "pcmanfm-qt"],   term: false },
      { id: "caja",       name: "Caja",             bins: ["caja"],                    term: false },
      { id: "yazi",       name: "yazi",             bins: ["yazi"],                    term: true },
      { id: "ranger",     name: "ranger",           bins: ["ranger"],                  term: true },
      { id: "lf",         name: "lf",               bins: ["lf"],                      term: true },
      { id: "nnn",        name: "nnn",              bins: ["nnn"],                     term: true }
    ] },
    { id: "editor", icon: "󰏫", nameKey: "daRoleEditor", linked: "", apps: [
      { id: "nvim",     name: "Neovim",         bins: ["nvim"],                        term: true },
      { id: "vim",      name: "Vim",            bins: ["vim"],                         term: true },
      { id: "helix",    name: "Helix",          bins: ["hx", "helix"],                 term: true },
      { id: "micro",    name: "micro",          bins: ["micro"],                       term: true },
      { id: "nano",     name: "nano",           bins: ["nano"],                        term: true },
      { id: "code",     name: "VS Code",        bins: ["code"],                        term: false },
      { id: "codium",   name: "VSCodium",       bins: ["codium", "vscodium"],          term: false },
      { id: "zed",      name: "Zed",            bins: ["zeditor", "zed"],              term: false },
      { id: "kate",     name: "Kate",           bins: ["kate"],                        term: false },
      { id: "gedit",    name: "gedit",          bins: ["gedit"],                       term: false },
      { id: "sublime",  name: "Sublime Text",   bins: ["subl", "sublime_text"],        term: false }
    ] },
    { id: "music", icon: "󰝚", nameKey: "daRoleMusic", linked: "", apps: [
      { id: "spotify",    name: "Spotify",      bins: ["spotify"],                     term: false },
      { id: "rhythmbox",  name: "Rhythmbox",    bins: ["rhythmbox"],                   term: false },
      { id: "lollypop",   name: "Lollypop",     bins: ["lollypop"],                    term: false },
      { id: "amberol",    name: "Amberol",      bins: ["amberol"],                     term: false },
      { id: "strawberry", name: "Strawberry",   bins: ["strawberry"],                  term: false },
      { id: "elisa",      name: "Elisa",        bins: ["elisa"],                       term: false },
      { id: "cmus",       name: "cmus",         bins: ["cmus"],                        term: true },
      { id: "ncmpcpp",    name: "ncmpcpp",      bins: ["ncmpcpp"],                     term: true }
    ] },
    { id: "video", icon: "󰕧", nameKey: "daRoleVideo", linked: "", apps: [
      { id: "mpv",        name: "mpv",          bins: ["mpv"],                         term: false },
      { id: "vlc",        name: "VLC",          bins: ["vlc"],                         term: false },
      { id: "celluloid",  name: "Celluloid",    bins: ["celluloid"],                   term: false },
      { id: "haruna",     name: "Haruna",       bins: ["haruna"],                      term: false },
      { id: "totem",      name: "Totem",        bins: ["totem"],                       term: false },
      { id: "smplayer",   name: "SMPlayer",     bins: ["smplayer"],                    term: false }
    ] },
  ]

  readonly property var extRoles: root.buildExtRoles()

  function buildExtRoles() {
    const groups = {
      video:  "mp4 mkv webm avi mov wmv flv m4v ogv",
      music:  "mp3 flac ogg opus wav m4a aac wma",
      editor: "txt md log json yaml yml toml ini cfg conf sh bash zsh fish py lua js mjs ts tsx jsx rs go c h cpp hpp java rb php css scss html xml sql nix qml csv"
    }
    const out = {}
    for (const role in groups) {
      const list = groups[role].split(" ")
      for (let i = 0; i < list.length; i++) out[list[i]] = role
    }
    return out
  }


  function roleInfo(id) {
    for (let i = 0; i < root.roles.length; i++)
      if (root.roles[i].id === id) return root.roles[i]
    return null
  }

  function appInfo(info, id) {
    for (let i = 0; i < info.apps.length; i++)
      if (info.apps[i].id === id) return info.apps[i]
    return null
  }

  function binOf(role, app) {
    const map = root.installed[role]
    return (map && map[app.id]) ? map[app.id] : app.bins[0]
  }

  function isInstalled(role, appId) {
    const map = root.installed[role]
    return !!(map && map[appId] !== undefined)
  }

  function roleIds() { return root.roles.map(r => r.id) }

  function choiceOf(role) {
    if (role === "browser") return QuickBarConfig.browserId === "default" ? "system" : QuickBarConfig.browserId
    if (role === "terminal") return Theme.terminalId
    const v = root.choices[role]
    return v === undefined ? "system" : v
  }

  function choicesFor(role) {
    const info = root.roleInfo(role)
    if (!info) return []
    const out = []
    if (role === "terminal") {
      const inst = Theme.installedTerminals
      const all = Theme.terminals
      for (let i = 0; i < all.length; i++)
        if (inst.length === 0 || inst.indexOf(all[i].id) >= 0 || all[i].id === Theme.terminalId)
          out.push({ id: all[i].id, name: all[i].name, missing: false })
      return out
    }
    out.push({ id: "system", name: "", missing: false })
    if (role === "browser") {
      const inst = QuickBarConfig.installedBrowsers
      const all = QuickBarConfig.browsers
      for (let i = 0; i < all.length; i++)
        if (inst.indexOf(all[i].id) >= 0 || all[i].id === QuickBarConfig.browserId)
          out.push({ id: all[i].id, name: all[i].name, missing: inst.indexOf(all[i].id) < 0 })
      return out
    }
    const current = root.choiceOf(role)
    for (let i = 0; i < info.apps.length; i++) {
      const a = info.apps[i]
      const here = root.isInstalled(role, a.id)
      if (here || a.id === current) out.push({ id: a.id, name: a.name, missing: !here })
    }
    if (role === "files") {
      for (const h of root.filesDesktopHits()) {
        if (h.catalog) continue
        if (h.id === current) out.push({ id: h.id, name: h.name, missing: false })
        else if (!out.some(o => o.id === h.id)) out.push({ id: h.id, name: h.name, missing: false })
      }
      if (typeof current === "string" && current.startsWith("desktop:")
          && !out.some(o => o.id === current)) {
        const gone = current.slice(8)
        out.push({ id: current, name: gone, missing: true })
      }
    }
    out.push({ id: "custom", name: "", missing: false })
    return out
  }


  function setChoice(role, id) {
    const info = root.roleInfo(role)
    if (!info || typeof id !== "string" || id === "") return false
    if (role === "browser") {
      const v = id === "system" ? "default" : id
      if (v !== "default" && QuickBarConfig.browserInfo(v) === null) return false
      QuickBarConfig.set("browserId", v)
      return true
    }
    if (role === "terminal") {
      if (!Theme.terminals.some(t => t.id === id)) return false
      Theme.setTerminal(id)
      return true
    }
    if (id !== "system" && id !== "custom" && root.appInfo(info, id) === null) {
      if (!(role === "files" && typeof id === "string" && id.startsWith("desktop:")
            && root.desktopEntryById(id.slice(8)) !== null)) return false
    }
    if (root.choices[role] === id) return true
    const next = Object.assign({}, root.choices)
    next[role] = id
    root.choices = next
    root.save()
    return true
  }

  function setCustom(role, command) {
    const info = root.roleInfo(role)
    if (!info || info.linked !== "" || typeof command !== "string") return false
    const next = Object.assign({}, root.customs)
    next[role] = command.trim()
    root.customs = next
    if (next[role] !== "") {
      const ch = Object.assign({}, root.choices)
      ch[role] = "custom"
      root.choices = ch
    }
    root.save()
    return true
  }


  function splitArgs(text) {
    const out = []
    const re = /"([^"]*)"|'([^']*)'|(\S+)/g
    let m
    while ((m = re.exec(String(text ?? ""))) !== null)
      out.push(m[1] !== undefined ? m[1] : (m[2] !== undefined ? m[2] : m[3]))
    return out
  }

  function expandPath(p) {
    let s = String(p ?? "").trim()
    if (s.indexOf("file://") === 0) {
      try { s = decodeURIComponent(s.slice(7)) } catch (e) { s = s.slice(7) }
    }
    const home = Quickshell.env("HOME")
    if (s === "~") return home
    if (s.indexOf("~/") === 0) return home + s.slice(1)
    return s
  }

  function appArgv(role, app, args) {
    const bin = root.binOf(role, app)
    return app.term ? Theme.terminalCmd.concat([bin], args) : [bin].concat(args)
  }

  function systemArgv(info, args) {
    if (args.length > 0) return ["xdg-open", args[0]]
    if (info.id === "files") return ["xdg-open", Quickshell.env("HOME")]
    for (let i = 0; i < info.apps.length; i++)
      if (root.isInstalled(info.id, info.apps[i].id)) return root.appArgv(info.id, info.apps[i], [])
    return []
  }

  function browserArgv(url, priv) {
    const b = QuickBarConfig.browser
    if (url !== "") return QuickBarConfig.browserCommand(url, priv)
    if (!b) return ["xdg-open", "about:blank"]
    return [QuickBarConfig.browserBins[b.id] ?? b.bins[0]]
  }

  function terminalArgv(args) {
    const base = Theme.terminalCmd
    return args.length === 0 ? [base[0]] : base.concat(args)
  }

  function argvFor(role, args, priv) {
    const a = args ?? []
    if (role === "browser") return root.browserArgv(a.length > 0 ? String(a[0]) : "", !!priv)
    if (role === "terminal") return root.terminalArgv(a)
    const info = root.roleInfo(role)
    if (!info) return []
    const choice = root.choiceOf(role)
    if (choice === "custom") {
      const base = root.splitArgs(root.customs[role] ?? "")
      return base.length > 0 ? base.concat(a) : root.systemArgv(info, a)
    }
    if (choice === "system") return root.systemArgv(info, a)
    const app = root.appInfo(info, choice)
    return app ? root.appArgv(role, app, a) : root.systemArgv(info, a)
  }

  function runDesktopEntry(entry, args) {
    if (!entry) return "no-app"
    const a = args ?? []
    const cmd = ((entry.command ?? []).filter(x => !/^%[a-zA-Z]$/.test(x)))
    if (cmd.length === 0) {
      try { entry.execute() } catch (e) { return "no-app" }
      return "ok"
    }
    if (entry.runInTerminal) Quickshell.execDetached(Theme.terminalCmd.concat(cmd, a))
    else Quickshell.execDetached(cmd.concat(a))
    return "ok"
  }

  function run(role, args, priv) {
    if (root.roleInfo(role) === null) return "unknown-role"
    const choice = root.choiceOf(role)
    if (role === "files" && typeof choice === "string" && choice.startsWith("desktop:"))
      return root.runDesktopEntry(root.desktopEntryById(choice.slice(8)), args ?? [])
    const argv = root.argvFor(role, args, priv)
    if (argv.length === 0) {
      root.failed(role)
      return "no-app"
    }
    Quickshell.execDetached(argv)
    return "ok"
  }


  function extOf(path) {
    const name = path.slice(path.lastIndexOf("/") + 1)
    const dot = name.lastIndexOf(".")
    return dot <= 0 ? "" : name.slice(dot + 1).toLowerCase()
  }

  function roleForPath(path) {
    const role = root.extRoles[root.extOf(path)]
    return role === undefined ? "" : role
  }

  function openUrl(url, priv) {
    const u = String(url ?? "").trim()
    if (u === "") return "empty"
    if (/^mailto:/i.test(u)) return root.run("browser", [u], priv)
  }

  function openFile(path) {
    const p = root.expandPath(path)
    if (p === "") return "empty"
    const role = root.roleForPath(p)
    if (role === "") {
      Quickshell.execDetached(["xdg-open", p])
      return "ok"
    }
    return root.run(role, [p], false)
  }

  function openDir(path) {
    const p = root.expandPath(path)
    return root.run("files", p === "" ? [] : [p], false)
  }

  function openAny(target) {
    const t = String(target ?? "").trim()
    if (t === "") return "empty"
    if (/^mailto:/i.test(t)) { Quickshell.execDetached(["xdg-open", t]); return "ok" }
    if (/^[a-z][a-z0-9+.-]*:\/\//i.test(t) && t.indexOf("file://") !== 0) return root.run("browser", [t], false)
    if (t.indexOf("file://") !== 0 && QuickBarConfig.looksLikeUrl(t) !== "") return root.run("browser", [QuickBarConfig.looksLikeUrl(t)], false)
    const p = root.expandPath(t)
    if (p === Quickshell.env("HOME") || p.slice(-1) === "/") return root.openDir(p)
    return root.openFile(p)
  }

  function runInTerminal(command) {
    const parts = root.splitArgs(command)
    return root.run("terminal", parts, false)
  }

  function describe(role) {
    const info = root.roleInfo(role)
    if (!info) return ({})
    return ({
      role: role,
      choice: root.choiceOf(role),
      custom: root.customs[role] ?? "",
      shared: info.linked,
      command: root.argvFor(role, [], false)
    })
  }

  function snapshot() { return ({ choices: root.choices, customs: root.customs }) }


  Process {
    id: detectProc
    property string buffer: ""

    command: ["sh", "-c",
      'for spec in "$@"; do key="${spec%%=*}"; bins="${spec#*=}"; old="$IFS"; IFS=,; ' +
      'for b in $bins; do if command -v "$b" >/dev/null 2>&1; then echo "b $key $b"; break; fi; done; ' +
      'IFS="$old"; done; exit 0',
      "sh"].concat(root.detectSpecs())
    running: true
    stdout: SplitParser { onRead: line => detectProc.buffer += line + "\n" }
    onRunningChanged: {
      if (running) return
      const found = {}
      const lines = detectProc.buffer.split("\n")
      detectProc.buffer = ""
      for (let i = 0; i < lines.length; i++) {
        const f = lines[i].trim().split(" ")
        if (f.length !== 3 || f[0] !== "b") continue
        const k = f[1].split(":")
        if (k.length !== 2) continue
        if (!found[k[0]]) found[k[0]] = {}
        found[k[0]][k[1]] = f[2]
      }
      root.installed = found
      root.detected = true
    }
  }

  function detectSpecs() {
    const out = []
    for (let i = 0; i < root.roles.length; i++) {
      const r = root.roles[i]
      for (let j = 0; j < r.apps.length; j++)
        out.push(r.id + ":" + r.apps[j].id + "=" + r.apps[j].bins.join(","))
    }
    return out
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
      "mkdir -p '" + root.dir + "' && cat > '" + root.file + ".tmp' << 'OOZE_DEFAULTAPPS_EOF'\n" + json + "\nOOZE_DEFAULTAPPS_EOF\n" +
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
          const ch = {}
          const cu = {}
          for (const role in (j.choices ?? {})) {
            const info = root.roleInfo(role)
            const id = j.choices[role]
            if (!info || info.linked !== "" || typeof id !== "string") continue
            if (id === "system" || id === "custom" || root.appInfo(info, id) !== null) ch[role] = id
          }
          for (const role in (j.customs ?? {})) {
            const info = root.roleInfo(role)
            if (info && info.linked === "" && typeof j.customs[role] === "string") cu[role] = j.customs[role]
          }
          root.choices = ch
          root.customs = cu
        } catch (e) {
          console.log("[defaultapps] error leyendo defaultapps.json:", e)
        }
      }
      root.loaded = true
    }
  }
}
