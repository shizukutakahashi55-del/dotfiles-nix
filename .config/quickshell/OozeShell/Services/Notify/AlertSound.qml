pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  // ─── Estado ────────────────────────────────────────────────────
  readonly property string userDir: Quickshell.env("HOME") + "/.config/oozeshell/sounds"
  property var library: []
  property string importStatus: ""

  signal imported(string path)

  // ─── Utilidades ────────────────────────────────────────────────
  function baseName(path) {
    const s = String(path)
    return s.substring(s.lastIndexOf("/") + 1)
  }

  function labelFor(path) {
    if (!path) return ""
    const b = root.baseName(path)
    const i = b.lastIndexOf(".")
    return i > 0 ? b.substring(0, i) : b
  }

  function clampVolume(v) {
    const n = Math.round(Number(v))
    return isNaN(n) ? 100 : Math.max(0, Math.min(100, n))
  }

  // ─── Biblioteca ────────────────────────────────────────────────
  function refresh() {
    if (scanProc.running) { scanProc.again = true; return }
    scanProc.rows = []
    scanProc.running = true
  }

  Process {
    id: scanProc
    property var rows: []
    property bool again: false
    command: ["bash", "-c",
      "IFS=:; for d in $XDG_DATA_DIRS /run/current-system/sw/share /usr/share /usr/local/share; do " +
      "for f in \"$d\"/sounds/*/stereo/*.oga; do [ -f \"$f\" ] && printf 's\\t%s\\n' \"$f\"; done; done; unset IFS; " +
      "for f in \"$OOZE_USER\"/*; do case \"${f,,}\" in *.oga|*.ogg|*.wav|*.flac|*.mp3) [ -f \"$f\" ] && printf 'u\\t%s\\n' \"$f\";; esac; done; exit 0"]
    environment: ({ "OOZE_USER": root.userDir })
    running: false
    stdout: SplitParser {
      onRead: line => {
        const t = line.indexOf("\t")
        if (t < 1) return
        const rows = scanProc.rows.slice()
        rows.push({ kind: line.substring(0, t), path: line.substring(t + 1) })
        scanProc.rows = rows
      }
    }
    onRunningChanged: {
      if (running) return
      root.library = root.build(scanProc.rows)
      if (scanProc.again) { scanProc.again = false; root.refresh() }
    }
  }

  function build(rows) {
    const seen = {}
    const mine = []
    const system = []
    for (const r of rows) {
      const name = root.labelFor(r.path)
      if (r.kind === "u") { mine.push({ path: r.path, name: name, user: true }); continue }
      if (seen[name]) continue
      seen[name] = true
      system.push({ path: r.path, name: name, user: false })
    }
    const cmp = (a, b) => a.name.localeCompare(b.name)
    return mine.sort(cmp).concat(system.sort(cmp))
  }

  // ─── Reproducción ──────────────────────────────────────────────
  function play(path, volume, defaults) {
    playProc.file = path ? String(path) : ""
    playProc.vol = String(root.clampVolume(volume))
    playProc.fallback = (defaults && defaults.length > 0 ? defaults : ["complete", "alarm-clock-elapsed", "message-new-instant"]).join(":")
    playProc.running = false
    playProc.running = true
  }

  Process {
    id: playProc
    property string file: ""
    property string vol: "100"
    property string fallback: ""
    command: ["bash", "-c",
      "s=\"$OOZE_SND\"; " +
      "case \"$s\" in \"~/\"*) s=\"$HOME/${s#\\~/}\";; \"file://\"*) s=\"${s#file://}\";; esac; " +
      "if [ ! -f \"$s\" ]; then s=''; IFS=:; " +
      "for d in $XDG_DATA_DIRS /run/current-system/sw/share /usr/share /usr/local/share; do " +
      "for n in $OOZE_DEF; do f=\"$d/sounds/freedesktop/stereo/$n.oga\"; [ -f \"$f\" ] && s=\"$f\" && break 2; done; done; unset IFS; fi; " +
      "v=\"${OOZE_VOL:-100}\"; " +
      "if [ -n \"$s\" ]; then " +
      "{ command -v pw-play >/dev/null && pw-play --volume=\"$(printf '%d.%02d' $((v/100)) $((v%100)))\" \"$s\"; } || " +
      "{ command -v paplay >/dev/null && paplay --volume=\"$((v*65536/100))\" \"$s\"; } || " +
      "{ command -v canberra-gtk-play >/dev/null && canberra-gtk-play -f \"$s\"; }; " +
      "else command -v canberra-gtk-play >/dev/null && canberra-gtk-play -i \"${OOZE_DEF%%:*}\"; fi; exit 0"]
    environment: ({ "OOZE_SND": playProc.file, "OOZE_VOL": playProc.vol, "OOZE_DEF": playProc.fallback })
    running: false
  }

  // ─── Importar ──────────────────────────────────────────────────
  function importFile(path) {
    const p = String(path).trim()
    if (p === "" || importProc.running) return
    importProc.src = p
    importProc.dest = ""
    importProc.running = true
  }

  Process {
    id: importProc
    property string src: ""
    property string dest: ""
    command: ["bash", "-c",
      "src=\"$OOZE_SRC\"; " +
      "case \"$src\" in \"~/\"*) src=\"$HOME/${src#\\~/}\";; '$HOME/'*) src=\"$HOME/${src#\\$HOME/}\";; \"file://\"*) src=\"${src#file://}\";; esac; " +
      "[ -f \"$src\" ] || exit 2; " +
      "case \"${src,,}\" in *.oga|*.ogg|*.wav|*.flac|*.mp3) ;; *) exit 3;; esac; " +
      "mkdir -p \"$OOZE_USER\" && cp -f -- \"$src\" \"$OOZE_USER/\" || exit 4; " +
      "printf '%s\\n' \"$OOZE_USER/${src##*/}\""]
    environment: ({ "OOZE_SRC": importProc.src, "OOZE_USER": root.userDir })
    running: false
    stdout: SplitParser { onRead: line => importProc.dest = line }
    onExited: code => {
      if (code === 0 && importProc.dest !== "") {
        root.importStatus = "ok"
        root.refresh()
        root.imported(importProc.dest)
      } else {
        root.importStatus = code === 2 ? "missing" : (code === 3 ? "format" : "error")
      }
      statusTimer.restart()
    }
  }

  Timer {
    id: statusTimer
    interval: 4000
    repeat: false
    onTriggered: root.importStatus = ""
  }
}
