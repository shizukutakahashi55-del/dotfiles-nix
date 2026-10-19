// BACKEND — ProcessList
// Fachada de procesos. Usa el núcleo nativo (OozeShell.Native → /proc en C++)
// si está compilado; si no, toma una foto con `ps` cada intervalo.
// Cuesta CERO si nadie lo pide: registrar con setWanted(clave, true/false).

pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "./native"

Item {
  id: root
  visible: false

  // ─── Clientes (refcount) ─────────────────────────────────────
  property var _clients: ({})
  readonly property bool wanted: Object.keys(root._clients).length > 0
  function setWanted(who, on) {
    const has = root._clients[who] === true
    if (on === has) return
    const next = {}
    for (const k in root._clients) next[k] = true
    if (on) next[who] = true; else delete next[who]
    root._clients = next
    root._sync()
  }
  property bool active: false
  onActiveChanged: root.setWanted("default", root.active)

  // ─── Ajustes ─────────────────────────────────────────────────
  property int intervalMs: 1500
  onIntervalMsChanged: if (root.nativeActive) root.core.intervalMs = root.intervalMs
  property int limit: 200
  onLimitChanged: if (root.nativeActive) root.core.limit = root.limit
  property string sortBy: "cpu"
  onSortByChanged: if (root.nativeActive) root.core.sortBy = root.sortBy

  // ─── Núcleo nativo ───────────────────────────────────────────
  property var core: null
  readonly property bool nativeActive: root.core !== null
  readonly property string backend: root.nativeActive ? "native" : "ps"

  Component.onCompleted: root._probe()

  function _probe() {
    try {
      const obj = NativeSpec.probe('ProcessList {}', root, "OozeProcListProbe")
      root.core = obj
      root.core.intervalMs = root.intervalMs
      root.core.limit = root.limit
      root.core.sortBy = root.sortBy
      root.core.setWanted("facade", root.wanted)
    } catch (e) {
      root.core = null
    }
    if (!root.nativeActive) nprocProc.running = true
    root._sync()
  }

  function _sync() {
    if (root.nativeActive) root.core.setWanted("facade", root.wanted)
    if (!root.wanted && psProc.running) psProc.running = false
  }

  // ─── Datos ───────────────────────────────────────────────────
  property var _psRows: []
  property int _psCores: 1
  readonly property var _raw: root.nativeActive ? root.core.rows : root._psRows
  readonly property var rows: root._ordered(root._raw, root.sortBy)
  readonly property int total: root.nativeActive ? root.core.total : root._psRows.length
  readonly property int numCores: root.nativeActive ? root.core.numCores : root._psCores
  readonly property real cpuTotal: root.nativeActive ? root.core.cpuTotal : root._psCpuTotal
  readonly property real memTotalMb: root.nativeActive ? root.core.memTotalMb : root._psMemTotal
  property real _psCpuTotal: 0
  property real _psMemTotal: 0

  function _ordered(list, key) {
    const out = Array.prototype.slice.call(list || [], 0)
    out.sort(function (a, b) {
      if (key === "pid") return a.pid - b.pid
      if (key === "name") {
        const x = String(a.name).toLowerCase()
        const y = String(b.name).toLowerCase()
        if (x !== y) return x < y ? -1 : 1
        return a.pid - b.pid
      }
      const f = key === "mem" ? "memMb" : "cpu"
      const g = key === "mem" ? "cpu" : "memMb"
      if (a[f] !== b[f]) return b[f] - a[f]
      if (a[g] !== b[g]) return b[g] - a[g]
      return a.pid - b.pid
    })
    return out
  }

  function kill(pid, sig) {
    if (root.nativeActive) return root.core.kill(pid, sig === undefined ? 15 : sig)
    killProc.pid = pid
    killProc.sig = sig === undefined ? 15 : sig
    killProc.running = true
    return true
  }

  // ─── Respaldo `ps` ───────────────────────────────────────────
  Timer {
    interval: root.intervalMs
    running: root.wanted && !root.nativeActive
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!psProc.running) psProc.running = true
  }

  Process {
    id: psProc
    command: ["ps", "-eo", "pid,user,pcpu,pmem,rss,comm", "--no-headers"]
    running: false
    property string buffer: ""
    stdout: SplitParser { onRead: line => psProc.buffer += line + "\n" }
    onRunningChanged: {
      if (running) return
      root._parsePs(psProc.buffer)
      psProc.buffer = ""
    }
  }

  Process {
    id: nprocProc
    command: ["nproc"]
    running: false
    stdout: SplitParser {
      onRead: line => {
        const n = parseInt(line, 10)
        if (n > 0) root._psCores = n
      }
    }
  }

  Process {
    id: killProc
    property int pid: 0
    property int sig: 15
    command: ["kill", "-" + killProc.sig, String(killProc.pid)]
    running: false
  }

  function _parsePs(text) {
    const out = []
    let cpuTotal = 0, memTotal = 0
    const lines = (text || "").split("\n")
    for (let i = 0; i < lines.length; i++) {
      const t = lines[i].trim().split(/\s+/)
      if (t.length < 6) continue
      const cpu = parseFloat(t[2]) || 0
      const memMb = (parseFloat(t[4]) || 0) / 1024
      cpuTotal += cpu
      memTotal += memMb
      out.push({ pid: parseInt(t[0], 10), user: t[1], cpu: cpu, memPct: parseFloat(t[3]) || 0,
                 memMb: memMb, name: t.slice(5).join(" "), state: "" })
    }
    const ordered = root._ordered(out, root.sortBy)
    if (root.limit > 0 && ordered.length > root.limit) ordered.length = root.limit
    root._psCpuTotal = cpuTotal
    root._psMemTotal = memTotal
    root._psRows = ordered
  }
}
