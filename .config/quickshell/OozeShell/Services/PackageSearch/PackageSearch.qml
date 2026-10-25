// PackageSearch — buscador de paquetes unificado (Global-Manager, fase 4).

import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../COMMON"
import "../Lang"

Item {
  id: root

  property bool open: false
  property string targetScreen: ""
  signal closeRequested()


  property string startQuery: ""

  // ─── Backend ────────────────────────────────────────────────────
  readonly property string backend: WM.packageBackend
  readonly property bool isNix: root.backend === "nix-search"

  // ─── Configuración ──────────────────────────────────────────────


  readonly property var terminal: Theme.terminalCmd

  property string channel: ""

  property var searchArgs: ["--json", "--max-results", "40"]
  readonly property int maxNixResults: 40

  property int debounceMs: 350
  property int minChars: 2

  property int maxArchResults: 60

  // ─── Medidas (lógicas: FusedPanel las escala según Ajustes → Ventanas) ──
  readonly property int cardW: 800
  readonly property int cardH: 540
  readonly property int pad: 16
  readonly property int rowH: 44
  readonly property int colAttr: 230
  readonly property int colVersion: 96
  readonly property int colFlags: 58

  // ─── Estado ─────────────────────────────────────────────────────

  property string level: "list"
  property var results: []
  property int selected: 0
  property int actionSel: 0
  property bool searching: false

  property string status: ""
  property string errText: ""

  readonly property string query: input.text
  readonly property var current: root.results[root.selected] ?? null

  // ─── Instalados (solo Arch) ─────────────────────────────────────

  property string mode: "search"

  property bool startInstalled: false
  readonly property bool inInstalled: root.mode === "installed" && !root.isNix

  property bool installedAll: false
  property var installedList: []
  property bool installedLoading: false
  property int installedGen: 0

  property int confirmSel: 0
  readonly property string installedScript:
    decodeURIComponent(Qt.resolvedUrl("installed.sh").toString().replace("file://", ""))

  readonly property var actions: {
    if (root.isNix) return [
      { id: "details", icon: "󰋽",  label: "nixActDetails", key: "Ctrl+D" },
      { id: "shell",   icon: "󰆍", label: "nixActShell",   key: "Ctrl+S" },
      { id: "install", icon: "󰏗",   label: "nixActInstall", key: "Ctrl+I" },
      { id: "copy",    icon: "󰆏",  label: "nixActCopy",    key: "Ctrl+Y" },
      { id: "copyref", icon: "󰌹",  label: "nixActCopyRef", key: "Ctrl+⇧Y" },
      { id: "web",     icon: "󰖟",   label: "nixActWeb",     key: "Ctrl+O" }
    ]

    const a = [{ id: "details", icon: "󰋽",  label: "nixActDetails", key: "Ctrl+D" }]
    if (!root.inInstalled)
      a.push({ id: "install", icon: "󰏗",   label: "pkgActInstall", key: "Ctrl+I" })
    if (root.inInstalled || (root.current && root.current.installed))
      a.push({ id: "remove",  icon: "󰆴",   label: "pkgActRemove",  key: "Ctrl+R" })
    a.push({ id: "copy", icon: "󰆏",  label: "pkgActCopy", key: "Ctrl+Y" })
    a.push({ id: "web",  icon: "󰖟",   label: "pkgActWeb",  key: "Ctrl+O" })
    return a
  }
  function hasAction(id) { return root.actions.some(a => a.id === id) }


  property string pendingQuery: ""
  property bool rerun: false
  property int searchGen: 0

  Timer {
    id: debounce
    interval: root.debounceMs
    repeat: false
    onTriggered: root.startSearch()
  }

  function queryEdited() {

    root.level = "list"
    root.selected = 0

    if (root.inInstalled) { root.applyFilter(); return }
    debounce.restart()
  }

  function startSearch() {
    const q = root.query.trim()
    if (q.length < root.minChars) {
      root.rerun = false
      if (searchProc.running) searchProc.running = false
      root.results = []
      root.searching = false
      root.status = ""
      return
    }
    root.pendingQuery = q
    if (searchProc.running) {
      root.rerun = true
      searchProc.running = false
      return
    }
    root.runSearch(q)
  }

  readonly property string daemonPath:
    decodeURIComponent(Qt.resolvedUrl("../../Backends/python/ooze-daemon.py").toString().replace("file://", ""))

  function runSearch(q) {
    searchProc.buf = []
    searchProc.gotGen = false
    searchProc.valid = false
    searchProc.capped = false
    searchProc.err = ""
    searchProc.terms = q.split(/\s+/).filter(t => t !== "")
    root.searchGen++
    root.searching = true
    root.status = ""
    root.selected = 0
    searchProc.viaDaemon = root.isNix
    if (searchProc.viaDaemon) searchProc.valid = true
    searchProc.running = true
  }


  function parseItem(o) {
    if (!o || typeof o !== "object") return null
    const attr = o.package_attr_name ?? o.attr ?? o.attribute ?? o.name ?? ""
    if (attr === "") return null

    const lic = o.package_license ?? o.license ?? []
    const licList = Array.isArray(lic) ? lic : (lic ? [lic] : [])
    const licenses = licList
      .map(l => (typeof l === "string") ? l : (l.fullName ?? l.spdxId ?? ""))
      .filter(n => n !== "")

    const home = o.package_homepage ?? o.homepage ?? ""
    const programs = o.package_programs ?? o.programs ?? []

    return {
      id: attr,
      attr: attr,
      version: String(o.package_pversion ?? o.version ?? ""),
      desc: String(o.package_description ?? o.description ?? ""),
      longDesc: String(o.package_longDescription ?? o.longDescription ?? ""),
      homepage: Array.isArray(home) ? (home[0] ?? "") : String(home),
      programs: Array.isArray(programs) ? programs : [],
      licenses: licenses,
      unfree: o.package_unfree === true || o.unfree === true
              || licenses.some(n => /unfree/i.test(n)),
      badge: (o.package_unfree === true || o.unfree === true
              || licenses.some(n => /unfree/i.test(n))) ? Translations.t("nixUnfree") : "",
      repo: "", installed: false, aur: false
    }
  }


  function parseArchHeader(line) {
    const m = /^(\S+?)\/(\S+)\s+(\S+)(.*)$/.exec(line)
    if (!m) return null
    const extra = m[4] ?? ""
    const installed = /installed/i.test(extra)
    const aur = m[1] === "aur"
    return {
      id: m[1] + "/" + m[2], attr: m[2], version: m[3], desc: "", longDesc: "",
      homepage: aur ? "https://aur.archlinux.org/packages/" + encodeURIComponent(m[2])
                    : "https://archlinux.org/packages/?q=" + encodeURIComponent(m[2]),
      programs: [], licenses: [], unfree: false,
      badge: installed ? "✔" : (aur ? "AUR" : ""),
      repo: m[1], installed: installed, aur: aur,
      outdated: /out-of-date/i.test(extra)
    }
  }

  Process {
    id: searchProc
    property var buf: []
    property var terms: []
    property bool gotGen: false
    property bool valid: false
    property string err: ""
    property bool viaDaemon: false


    property bool capped: false


    command: (root.isNix && searchProc.viaDaemon) ? ["python3", root.daemonPath, "nix-search"]
      .concat(root.channel !== "" ? ["--channel", root.channel] : [],
              ["--max", String(root.maxNixResults)],
              ["--args"], root.searchArgs,
              ["--"], searchProc.terms)
    : root.isNix ? ["sh", "-c",
      'echo "$1"; shift; ' +
      'command -v nix-search >/dev/null 2>&1 || { echo __NO_NIX_SEARCH__; exit 127; }; ' +
      'exec nix-search "$@"',
      "sh", String(root.searchGen)
    ].concat(root.searchArgs,
             root.channel !== "" ? ["--channel", root.channel] : [],
             ["--"],
             searchProc.terms)
    : ["sh", "-c",

      'echo "$1"; shift; ' +
      'command -v "$1" >/dev/null 2>&1 || { echo __NO_NIX_SEARCH__; exit 127; }; ' +
      'LC_ALL=C exec "$@"',
      "sh", String(root.searchGen), root.backend, "--color", "never", "-Ss", "--"
    ].concat(searchProc.terms)

    stdout: SplitParser {
      onRead: line => {
        if (searchProc.viaDaemon) {
          let doc = null
          try { doc = JSON.parse(line) } catch (e) { return }
          if (!doc || doc.ok !== true) {
            root.status = (doc && doc.error === "missing") ? "missing" : "failed"
            root.errText = (doc && doc.error) ? String(doc.error) : ""
            searchProc.buf = []
            root.results = []
            return
          }
          const out = []
          for (const o of (doc.results || [])) {
            const it = root.parseItem(o)
            if (it) out.push(it)
          }
          searchProc.buf = out
          root.results = searchProc.buf.slice()
          return
        }
        if (!searchProc.gotGen) {
          searchProc.gotGen = true
          searchProc.valid = (line === String(root.searchGen))
          return
        }
        if (!searchProc.valid || line === "") return

        if (line === "__NO_NIX_SEARCH__") { root.status = "missing"; return }

        if (!root.isNix) {

          if (/^\s/.test(line)) {
            const n = searchProc.buf.length
            if (n === 0 || searchProc.capped) return
            const last = Object.assign({}, searchProc.buf[n - 1])
            last.desc = last.desc !== "" ? last.desc + " " + line.trim() : line.trim()
            searchProc.buf[n - 1] = last
            root.results = searchProc.buf.slice()
          } else if (searchProc.buf.length < root.maxArchResults) {
            const it = root.parseArchHeader(line)
            if (it) { searchProc.buf.push(it); root.results = searchProc.buf.slice() }
          } else {
            searchProc.capped = true
          }
          return
        }

        let parsed
        try { parsed = JSON.parse(line) } catch (e) { return }

        const list = Array.isArray(parsed) ? parsed : [parsed]
        for (let i = 0; i < list.length; i++) {
          const it = root.parseItem(list[i])
          if (it) searchProc.buf.push(it)
        }
        root.results = searchProc.buf.slice()
      }
    }

    stderr: SplitParser {
      onRead: line => { if (line.trim() !== "") searchProc.err = line.trim() }
    }

    onRunningChanged: {
      if (running) return
      root.searching = false

      if (root.rerun) {
        root.rerun = false
        root.runSearch(root.pendingQuery)
        return
      }
      if (!searchProc.valid) return
      if (searchProc.buf.length === 0) {
        root.results = []
        if (root.status === "") {
          root.status = searchProc.err !== "" ? "failed" : ""
          root.errText = searchProc.err
        }
      }
    }
  }


  function applyFilter() {
    const terms = root.query.trim().toLowerCase().split(/\s+/).filter(t => t !== "")
    const src = root.installedList
    root.results = terms.length === 0 ? src
      : src.filter(p => {
          const hay = (p.attr + " " + p.desc).toLowerCase()
          return terms.every(t => hay.indexOf(t) >= 0)
        })
  }

  function loadInstalled() {
    if (root.isNix) return
    root.installedGen++
    root.installedLoading = true
    root.status = ""

    if (installedProc.running) {
      installedProc.rerun = true
      installedProc.running = false
      return
    }
    installedProc.begin()
  }

  function setMode(m) {
    if (root.isNix || root.mode === m) return
    root.mode = m
    root.level = "list"
    root.selected = 0
    root.actionSel = 0
    root.status = ""
    root.errText = ""
    debounce.stop()
    root.rerun = false
    if (searchProc.running) searchProc.running = false
    root.searching = false
    if (m === "installed") {
      root.applyFilter()
      root.loadInstalled()
    } else {
      root.results = []
      root.startSearch()
    }
  }
  function toggleMode() { root.setMode(root.mode === "search" ? "installed" : "search") }

  function toggleScope() {
    if (!root.inInstalled) return
    root.installedAll = !root.installedAll
    root.installedList = []
    root.results = []
    root.selected = 0
    root.loadInstalled()
  }

  Process {
    id: installedProc
    property var buf: []
    property bool gotGen: false
    property bool valid: false
    property bool rerun: false

    function begin() {
      installedProc.buf = []
      installedProc.gotGen = false
      installedProc.valid = false
      installedProc.running = true
    }

    command: ["bash", root.installedScript, String(root.installedGen),
              root.installedAll ? "all" : "explicit"]

    stdout: SplitParser {
      onRead: line => {
        if (!installedProc.gotGen) {
          installedProc.gotGen = true
          installedProc.valid = (line === String(root.installedGen))
          return
        }
        if (!installedProc.valid || line === "") return
        if (line === "__NO_PACMAN__") { root.status = "missing"; return }


        const f = line.split("\t")
        if (f.length < 6) return
        const aur = f[5] === "1"
        installedProc.buf.push({
          id: f[0], attr: f[0], version: f[1], size: f[2], reason: f[3],
          desc: f[4], longDesc: "", programs: [], licenses: [], unfree: false,
          homepage: aur ? "https://aur.archlinux.org/packages/" + encodeURIComponent(f[0])
                        : "https://archlinux.org/packages/?q=" + encodeURIComponent(f[0]),
          badge: aur ? "AUR" : (f[3] === "d" ? Translations.t("pkgDepBadge") : ""),
          repo: (f[6] ?? "") !== "" ? f[6] : (aur ? "aur" : ""),
          installed: true, aur: aur, outdated: false
        })
      }
    }

    onRunningChanged: {
      if (running) return
      if (installedProc.rerun) { installedProc.rerun = false; installedProc.begin(); return }
      root.installedLoading = false
      if (!installedProc.valid) return
      root.installedList = installedProc.buf.slice()
      if (root.inInstalled) root.applyFilter()
    }
  }

  function copyText(text) {
    Quickshell.execDetached(["sh", "-c",
      'printf %s "$1" | wl-copy && notify-send -a OozeShell "$2" "$1"',
      "sh", text, Translations.t("nixCopied")])
  }


  function archRun(item, op) {
    const rm = op === "remove"
    const pm = root.backend
    const flags = rm ? "-Rns" : "-S"
    const cmd = pm === "pacman" ? 'sudo pacman ' + flags + ' -- "$1"' : pm + ' ' + flags + ' -- "$1"'
    Quickshell.execDetached(root.terminal.concat(["sh", "-c",
      cmd + '; s=$?; ' +
      'if [ "$s" -eq 0 ]; then notify-send -a OozeShell "' + pm + '" "$2: $1"; ' +
      'else notify-send -u critical -a OozeShell "' + pm + '" "$3: $1 ($s)"; fi; ' +
      'printf "\\n%s " "$4"; read -r _',
      "sh", item.attr,
      Translations.t(rm ? "pkgRemoved" : "nixInstalled"),
      Translations.t(rm ? "pkgRemoveFailed" : "nixInstallFailed"),
      Translations.t("nixPressEnter")]))
  }


  function confirmRemove() {
    if (!root.current || root.isNix) return
    root.archRun(root.current, "remove")
    root.closeRequested()
  }

  function runAction(id, item) {
    if (!item || !root.hasAction(id)) return
    const ref = "nixpkgs#" + item.attr

    switch (id) {
      case "details":
        root.level = "details"
        return

      case "shell":
        Quickshell.execDetached(root.terminal.concat(["nix", "shell", ref]))
        break

      case "install":
        if (!root.isNix) { root.archRun(item, "install"); break }

        Quickshell.execDetached(root.terminal.concat(["sh", "-c",
          'nix profile install "$1"; s=$?; ' +
          'if [ "$s" -eq 0 ]; then notify-send -a OozeShell "nix profile" "$2: $1"; ' +
          'else notify-send -u critical -a OozeShell "nix profile" "$3: $1 ($s)"; fi; ' +
          'printf "\\n%s " "$4"; read -r _',
          "sh", ref, Translations.t("nixInstalled"), Translations.t("nixInstallFailed"),
          Translations.t("nixPressEnter")]))
        break

      case "remove":

        root.confirmSel = 0
        root.level = "confirm"
        return

      case "copy":
        root.copyText(item.attr)
        break

      case "copyref":
        root.copyText(ref)
        break

      case "web":
        if (!root.isNix) { Quickshell.execDetached(["xdg-open", item.homepage]); break }
        Quickshell.execDetached(["xdg-open",
          "https://search.nixos.org/packages?channel=" + (root.channel !== "" ? root.channel : "unstable")
          + "&show=" + encodeURIComponent(item.attr)
          + "&query=" + encodeURIComponent(item.attr)])
        break
    }
    root.closeRequested()
  }

  function move(delta) {
    if (root.level === "actions") {
      root.actionSel = Math.max(0, Math.min(root.actions.length - 1, root.actionSel + delta))
    } else if (root.level === "details") {
      detailsView.nudge(delta * 48)
    } else {
      const n = root.results.length
      if (n === 0) return
      root.selected = Math.max(0, Math.min(n - 1, root.selected + delta))
    }
  }


  onStartInstalledChanged: {
    if (root.open && !root.isNix) root.setMode(root.startInstalled ? "installed" : "search")
  }

  onOpenChanged: {
    if (!root.open) {
      debounce.stop()
      return
    }
    root.level = "list"
    root.selected = 0
    root.actionSel = 0
    root.status = ""
    root.errText = ""
    root.rerun = false
    if (searchProc.running) searchProc.running = false
    root.results = []
    root.searching = false
    root.mode = (root.startInstalled && !root.isNix) ? "installed" : "search"
    root.installedList = []
    input.text = root.startQuery


    debounce.stop()
    if (root.inInstalled) root.loadInstalled()
    else if (root.startQuery.trim() !== "") root.startSearch()


    Qt.callLater(() => input.forceActiveFocus())
    focusTimer.restart()
  }

  Timer {
    id: focusTimer
    interval: 120
    repeat: false
    onTriggered: if (root.open && !input.activeFocus) input.forceActiveFocus()
  }

  FusedWindow {
    id: fw
    active: root.open || panel.shown
    targetScreen: root.targetScreen
    namespace: "oozeshell-nixsearch"

    exclusiveKeys: true
    onCloseRequested: root.closeRequested()

    onKeyPressed: (key, modifiers, text) => {
      input.forceActiveFocus()
      if (text.length === 1 && text.charCodeAt(0) >= 32 && (modifiers & Qt.ControlModifier) === 0)
        input.text += text
    }

    FusedPanel {
      id: panel

      open: root.open
      panelWidth: root.cardW
      contentHeight: root.cardH
      align: "center"

      ColumnLayout {
        anchors { fill: parent; margins: root.pad }
        spacing: 8

        // ─── Buscador ───────────────────────────────────────
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: 50
          radius: Theme.cardRadius
          color: Theme.surface

          RowLayout {
            anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
            spacing: 10

            Text {
              text: root.isNix ? "❄" : "󰏗"
              color: Theme.primary
              font.pixelSize: Theme.fs(22)
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
                font.family: Theme.fontFamily
                clip: true
                inputMethodHints: Qt.ImhNoPredictiveText

                onTextChanged: root.queryEdited()

                Keys.onPressed: event => {
                  const ctrl  = (event.modifiers & Qt.ControlModifier) !== 0
                  const shift = (event.modifiers & Qt.ShiftModifier) !== 0

                  switch (event.key) {
                    case Qt.Key_Escape:


                      if (root.level === "confirm") root.level = "actions"
                      else if (root.level !== "list") root.level = "list"
                      else root.closeRequested()
                      event.accepted = true
                      return

                    case Qt.Key_Down:
                      if (root.level === "confirm") { root.confirmSel = 1; event.accepted = true; return }
                      root.move(1); event.accepted = true; return
                    case Qt.Key_Up:
                      if (root.level === "confirm") { root.confirmSel = 0; event.accepted = true; return }
                      root.move(-1); event.accepted = true; return
                    case Qt.Key_Right:
                    case Qt.Key_Tab:
                      if (root.level === "confirm") {
                        root.confirmSel = 1 - root.confirmSel
                        event.accepted = true
                      }
                      return
                    case Qt.Key_PageDown:
                      root.move(6); event.accepted = true; return
                    case Qt.Key_PageUp:
                      root.move(-6); event.accepted = true; return

                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                      if (root.level === "list") {
                        if (root.current) { root.actionSel = 0; root.level = "actions" }
                      } else if (root.level === "actions") {
                        root.runAction(root.actions[root.actionSel].id, root.current)
                      } else if (root.level === "confirm") {
                        if (root.confirmSel === 1) root.confirmRemove()
                        else root.level = "actions"
                      } else {
                        root.level = "list"
                      }
                      event.accepted = true
                      return


                    case Qt.Key_Left:
                    case Qt.Key_Backspace:
                      if (root.level === "confirm" && event.key === Qt.Key_Left) {
                        root.confirmSel = 0
                        event.accepted = true
                      } else if (root.level !== "list") {
                        root.level = "list"
                        event.accepted = true
                      }
                      return
                  }

                  if (!ctrl || root.level === "confirm") return


                  switch (event.key) {
                    case Qt.Key_N:
                    case Qt.Key_J:
                      root.move(1); event.accepted = true; return
                    case Qt.Key_P:
                    case Qt.Key_K:
                      root.move(-1); event.accepted = true; return
                    case Qt.Key_U:
                      input.text = ""; event.accepted = true; return
                    case Qt.Key_D:
                      root.runAction("details", root.current); event.accepted = true; return
                    case Qt.Key_S:
                      root.runAction("shell", root.current); event.accepted = true; return
                    case Qt.Key_I:
                      root.runAction("install", root.current); event.accepted = true; return
                    case Qt.Key_Y:
                      root.runAction(shift ? "copyref" : "copy", root.current)
                      event.accepted = true
                      return
                    case Qt.Key_O:
                      root.runAction("web", root.current); event.accepted = true; return


                    case Qt.Key_L:
                      if (!root.isNix) { root.toggleMode(); event.accepted = true }
                      return
                    case Qt.Key_E:
                      if (root.inInstalled) { root.toggleScope(); event.accepted = true }
                      return
                    case Qt.Key_R:
                      root.runAction("remove", root.current); event.accepted = true; return
                  }
                }
              }

              Text {
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                visible: input.text === ""
                elide: Text.ElideRight
                text: root.isNix ? Translations.t("nixPlaceholder")
                    : root.inInstalled ? Translations.t("pkgInstalledPlaceholder")
                    : Translations.t("pkgPlaceholder") + " (" + root.backend + ")…"
                color: Theme.subtext
                font.pixelSize: Theme.fs(16)
                font.family: Theme.fontFamily
              }
            }

            Text {
              text: root.inInstalled
                      ? (root.installedLoading && root.results.length === 0 ? Translations.t("pkgLoading")
                         : root.results.length > 0 ? String(root.results.length) : "")
                  : root.searching ? Translations.t("nixSearching")
                  : root.results.length > 0 ? String(root.results.length)
                  : ""
              color: Theme.subtext
              font.pixelSize: Theme.fs(12)
              font.family: Theme.fontFamily
            }


            Rectangle {
              visible: root.inInstalled
              Layout.preferredHeight: 28
              Layout.preferredWidth: scopeLabel.implicitWidth + 24
              radius: 14
              color: scopeArea.containsMouse ? Theme.surfaceHigh : Theme.bg
              Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }

              Text {
                id: scopeLabel
                anchors.centerIn: parent
                text: Translations.t(root.installedAll ? "pkgScopeAll" : "pkgScopeExplicit")
                color: Theme.text
                font.pixelSize: Theme.fs(12)
                font.family: Theme.fontFamily
              }
              MouseArea {
                id: scopeArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { root.toggleScope(); input.forceActiveFocus() }
              }
            }


            Rectangle {
              visible: !root.isNix
              Layout.preferredHeight: 28
              Layout.preferredWidth: instLabel.implicitWidth + 28
              radius: 14
              color: root.inInstalled ? Theme.primary
                   : instArea.containsMouse ? Theme.surfaceHigh : Theme.bg
              Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }

              Text {
                id: instLabel
                anchors.centerIn: parent
                text: "󰏖  " + Translations.t("pkgBtnInstalled")
                color: root.inInstalled ? Theme.textOnPrimary : Theme.text
                font.pixelSize: Theme.fs(12)
                font.bold: root.inInstalled
                font.family: Theme.fontFamily
              }
              MouseArea {
                id: instArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { root.toggleMode(); input.forceActiveFocus() }
              }
            }
          }
        }

        // ─── Títulos de columna (solo con resultados) ───────
        RowLayout {
          Layout.fillWidth: true
          Layout.leftMargin: 22
          Layout.rightMargin: 16
          Layout.preferredHeight: 18
          visible: root.level === "list" && root.results.length > 0
          spacing: 12

          Text {
            Layout.preferredWidth: root.colAttr
            text: Translations.t("nixColPackage")
            color: Theme.subtext
            font.pixelSize: Theme.fs(11)
            font.family: Theme.fontFamily
            font.bold: true
          }
          Text {
            Layout.preferredWidth: root.colVersion
            text: Translations.t("nixColVersion")
            color: Theme.subtext
            font.pixelSize: Theme.fs(11)
            font.family: Theme.fontFamily
            font.bold: true
          }
          Item { Layout.preferredWidth: root.colFlags }
          Text {
            Layout.fillWidth: true
            text: Translations.t("nixColDescription")
            color: Theme.subtext
            font.pixelSize: Theme.fs(11)
            font.family: Theme.fontFamily
            font.bold: true
          }
        }

        // ─── Contenido: lista / acciones / detalles ─────────
        Item {
          Layout.fillWidth: true
          Layout.fillHeight: true

          // ── Nivel: lista de resultados ────────────────────
          ListView {
            id: list
            anchors.fill: parent
            visible: root.level === "list"
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height

            model: ScriptModel {
              values: root.results
              objectProp: "id"
            }

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

              width: ListView.view.width
              height: root.rowH

              Rectangle {
                anchors { fill: parent; leftMargin: 0; rightMargin: 0 }
                radius: Theme.cardRadius - 2
                color: row.isCurrent ? Theme.surfaceHigh
                     : rowArea.containsMouse ? Theme.surface
                     : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }
              }

              Rectangle {
                visible: row.isCurrent
                width: 3
                height: 22
                radius: 2
                color: Theme.primary
                anchors { left: parent.left; leftMargin: 6; verticalCenter: parent.verticalCenter }
              }

              RowLayout {
                anchors { fill: parent; leftMargin: 16; rightMargin: 10 }
                spacing: 12

                Text {
                  Layout.preferredWidth: root.colAttr
                  text: row.modelData.attr
                  elide: Text.ElideRight
                  color: row.isCurrent ? Theme.primary : Theme.text
                  font.pixelSize: Theme.fs(15)
                  font.family: Theme.fontFamily
                  font.bold: true
                }
                Text {
                  Layout.preferredWidth: root.colVersion
                  text: row.modelData.version
                  elide: Text.ElideRight
                  color: Theme.subtext
                  font.pixelSize: Theme.fs(13)
                  font.family: Theme.fontFamily
                }
                Item {
                  Layout.preferredWidth: root.colFlags
                  Layout.preferredHeight: 20

                  Rectangle {
                    visible: row.modelData.badge !== ""
                    anchors.centerIn: parent
                    width: unfreeLabel.implicitWidth + 12
                    height: 18
                    radius: 9
                    color: row.modelData.unfree
                           ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.18)
                           : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)

                    Text {
                      id: unfreeLabel
                      anchors.centerIn: parent
                      text: row.modelData.badge
                      color: row.modelData.unfree ? Theme.error : Theme.primary
                      font.pixelSize: Theme.fs(10)
                      font.family: Theme.fontFamily
                      font.bold: true
                    }
                  }
                }
                Text {
                  Layout.fillWidth: true
                  text: row.modelData.desc
                  elide: Text.ElideRight
                  color: Theme.subtext
                  font.pixelSize: Theme.fs(13)
                  font.family: Theme.fontFamily
                }
              }

              MouseArea {
                id: rowArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.selected = row.index
                  root.actionSel = 0
                  root.level = "actions"
                  input.forceActiveFocus()
                }
              }
            }
          }

          // ── Nivel: acciones sobre el resultado elegido ────
          ColumnLayout {
            anchors.fill: parent
            visible: root.level === "actions"
            spacing: 6

            RowLayout {
              Layout.fillWidth: true
              Layout.leftMargin: 8
              Layout.bottomMargin: 4
              spacing: 10

              Text {
                text: root.current ? root.current.attr : ""
                color: Theme.primary
                font.pixelSize: Theme.fs(18)
                font.family: Theme.titleFamily
                font.bold: true
              }
              Text {
                text: root.current ? root.current.version : ""
                color: Theme.subtext
                font.pixelSize: Theme.fs(13)
                font.family: Theme.fontFamily
              }
            }

            Repeater {
              model: root.actions

              delegate: Item {
                id: act
                required property var modelData
                required property int index
                readonly property bool isCurrent: act.index === root.actionSel

                Layout.fillWidth: true
                Layout.preferredHeight: root.rowH

                Rectangle {
                  anchors.fill: parent
                  radius: Theme.cardRadius - 2
                  color: act.isCurrent ? Theme.surfaceHigh
                       : actArea.containsMouse ? Theme.surface
                       : "transparent"
                  Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }
                }

                Rectangle {
                  visible: act.isCurrent
                  width: 3
                  height: 22
                  radius: 2
                  color: Theme.primary
                  anchors { left: parent.left; leftMargin: 6; verticalCenter: parent.verticalCenter }
                }

                RowLayout {
                  anchors { fill: parent; leftMargin: 22; rightMargin: 16 }
                  spacing: 14

                  Text {
                    text: act.modelData.icon
                    color: act.isCurrent ? Theme.primary : Theme.subtext
                    font.pixelSize: Theme.fs(20)
                    font.family: Theme.monoFamily
                  }
                  Text {
                    Layout.fillWidth: true
                    text: Translations.t(act.modelData.label)
                    color: Theme.text
                    font.pixelSize: Theme.fs(15)
                    font.family: Theme.fontFamily
                    font.bold: act.isCurrent
                  }
                  Text {
                    text: act.modelData.key
                    color: Theme.subtext
                    font.pixelSize: Theme.fs(12)
                    font.family: Theme.fontFamily
                  }
                }

                MouseArea {
                  id: actArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.actionSel = act.index
                    root.runAction(act.modelData.id, root.current)
                    input.forceActiveFocus()
                  }
                }
              }
            }

            Item { Layout.fillHeight: true }
          }

          // ── Nivel: confirmar desinstalación (solo Arch) ───
          ColumnLayout {
            anchors.fill: parent
            visible: root.level === "confirm"
            spacing: 12

            Item { Layout.fillHeight: true }

            Text {
              Layout.fillWidth: true
              horizontalAlignment: Text.AlignHCenter
              text: Translations.t("pkgConfirmTitle")
              color: Theme.error
              font.pixelSize: Theme.fs(18)
              font.family: Theme.titleFamily
              font.bold: true
            }
            Text {
              Layout.fillWidth: true
              horizontalAlignment: Text.AlignHCenter
              elide: Text.ElideRight
              text: root.current ? root.current.attr + "  " + root.current.version : ""
              color: Theme.primary
              font.pixelSize: Theme.fs(16)
              font.family: Theme.fontFamily
              font.bold: true
            }
            Text {
              Layout.fillWidth: true
              Layout.leftMargin: 48
              Layout.rightMargin: 48
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.WordWrap
              text: Translations.t("pkgConfirmBody")
              color: Theme.subtext
              font.pixelSize: Theme.fs(13)
              font.family: Theme.fontFamily
            }

            RowLayout {
              Layout.alignment: Qt.AlignHCenter
              Layout.topMargin: 8
              spacing: 14

              Repeater {
                model: [
                  { id: "cancel", label: "pkgConfirmCancel" },
                  { id: "ok",     label: "pkgConfirmOk" }
                ]

                delegate: Rectangle {
                  id: cbtn
                  required property var modelData
                  required property int index
                  readonly property bool sel: cbtn.index === root.confirmSel
                  readonly property bool danger: cbtn.modelData.id === "ok"

                  Layout.preferredWidth: 160
                  Layout.preferredHeight: 40
                  radius: 20
                  color: cbtn.sel
                           ? (cbtn.danger ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.25)
                                          : Theme.surfaceHigh)
                           : (cbArea.containsMouse ? Theme.surface : Theme.bg)
                  border.width: cbtn.sel ? 2 : 0
                  border.color: cbtn.danger ? Theme.error : Theme.primary
                  Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }

                  Text {
                    anchors.centerIn: parent
                    text: Translations.t(cbtn.modelData.label)
                    color: cbtn.danger ? Theme.error : Theme.text
                    font.pixelSize: Theme.fs(14)
                    font.family: Theme.fontFamily
                    font.bold: cbtn.sel
                  }

                  MouseArea {
                    id: cbArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      root.confirmSel = cbtn.index
                      if (cbtn.danger) root.confirmRemove()
                      else root.level = "actions"
                      input.forceActiveFocus()
                    }
                  }
                }
              }
            }

            Item { Layout.fillHeight: true }
          }

          // ── Nivel: detalles ───────────────────────────────
          Flickable {
            id: detailsView
            anchors.fill: parent
            visible: root.level === "details"
            clip: true
            contentWidth: width
            contentHeight: detailsCol.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            function nudge(dy) {
              const max = Math.max(0, contentHeight - height)
              contentY = Math.max(0, Math.min(max, contentY + dy))
            }


            onVisibleChanged: if (visible) contentY = 0

            ColumnLayout {
              id: detailsCol
              width: detailsView.width - 12
              x: 6
              spacing: 10

              RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                  text: root.current ? root.current.attr : ""
                  color: Theme.primary
                  font.pixelSize: Theme.fs(22)
                  font.family: Theme.titleFamily
                  font.bold: true
                }
                Text {
                  text: root.current ? root.current.version : ""
                  color: Theme.subtext
                  font.pixelSize: Theme.fs(14)
                  font.family: Theme.fontFamily
                }
              }

              Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.current ? root.current.desc : ""
                wrapMode: Text.WordWrap
                color: Theme.text
                font.pixelSize: Theme.fs(15)
                font.family: Theme.fontFamily
              }

              Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.current ? root.current.longDesc : ""
                wrapMode: Text.WordWrap
                color: Theme.subtext
                font.pixelSize: Theme.fs(13)
                font.family: Theme.fontFamily
              }


              Repeater {
                model: root.current ? (root.isNix ? [
                  { k: "nixLicense",  v: root.current.licenses.join(", ") },
                  { k: "nixHomepage", v: root.current.homepage },
                  { k: "nixPrograms", v: root.current.programs.slice(0, 16).join(", ")
                                       + (root.current.programs.length > 16 ? " …" : "") }
                ] : [
                  { k: "pkgRepo",     v: root.current.repo },
                  { k: "pkgSize",     v: root.current.size ?? "" },
                  { k: "pkgReason",   v: root.current.reason === "d" ? Translations.t("pkgReasonDep")
                                         : root.current.reason === "e" ? Translations.t("pkgReasonExplicit") : "" },
                  { k: "pkgStatus",   v: root.current.installed ? Translations.t("pkgInstalled")
                                         : root.current.outdated ? Translations.t("pkgOutdated") : "" },
                  { k: "nixHomepage", v: root.current.homepage }
                ]).filter(r => r.v !== "") : []

                delegate: ColumnLayout {
                  id: metaRow
                  required property var modelData
                  Layout.fillWidth: true
                  spacing: 2

                  Text {
                    text: Translations.t(metaRow.modelData.k)
                    color: Theme.subtext
                    font.pixelSize: Theme.fs(11)
                    font.family: Theme.fontFamily
                    font.bold: true
                  }
                  Text {
                    Layout.fillWidth: true
                    text: metaRow.modelData.v
                    wrapMode: Text.WrapAnywhere
                    color: Theme.text
                    font.pixelSize: Theme.fs(13)
                    font.family: Theme.fontFamily
                  }
                }
              }
            }
          }

          // ── Mensajes (sin consulta, buscando, sin resultados, error) ──
          Text {
            anchors.centerIn: parent
            width: parent.width - 64
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            visible: root.level === "list" && root.results.length === 0
            color: root.status !== "" ? Theme.error : Theme.subtext
            font.pixelSize: Theme.fs(14)
            font.family: Theme.fontFamily
            text: root.inInstalled
                    ? (root.status === "missing" ? Translations.t("pkgMissing") + " pacman"
                       : root.installedLoading ? Translations.t("pkgLoading")
                       : root.query.trim() !== "" ? Translations.t("nixNoResults")
                       : Translations.t("pkgInstalledEmpty"))
                : root.status === "missing"
                    ? (root.isNix ? Translations.t("nixMissing") : Translations.t("pkgMissing") + " " + root.backend)
                : root.status === "failed"
                    ? (root.isNix ? Translations.t("nixFailed") : Translations.t("pkgFailed"))
                      + (root.errText !== "" ? "\n" + root.errText : "")
                : root.searching ? Translations.t("nixSearching")
                : root.query.trim().length < root.minChars
                    ? (root.isNix ? Translations.t("nixTypeToSearch") : Translations.t("pkgTypeToSearch"))
                : Translations.t("nixNoResults")
          }
        }

        // ─── Atajos ─────────────────────────────────────────
        Text {
          Layout.fillWidth: true
          Layout.leftMargin: 6
          elide: Text.ElideRight
          text: root.level === "list"
                  ? Translations.t(root.isNix ? "nixHintList" : root.inInstalled ? "pkgHintInstalled" : "pkgHintList")
              : root.level === "confirm" ? Translations.t("pkgHintConfirm")
              : root.level === "actions" ? Translations.t("nixHintActions")
              : Translations.t("nixHintDetails")
          color: Theme.subtext
          font.pixelSize: Theme.fs(11)
          font.family: Theme.fontFamily
        }
      }
    }
  }
}
