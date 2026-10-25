// BACKEND — SystemMonitor
// Fachada única de métricas del equipo. Usa el núcleo nativo
// (OozeShell.Native → C++) cuando está compilado; si no, delega en el
// muestreo QML (Modules/Menu/SystemStats.qml). Mismos nombres y unidades
// (porcentajes 0..100, gpu = -1 si no hay GPU) para que la UI no distinga.
//
// Cuesta CERO si nadie lo pide: registrar con setWanted(clave, true/false).

pragma Singleton
import QtQuick
import "../Modules/Menu"
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

  // ─── Núcleo nativo ───────────────────────────────────────────
  property var core: null
  readonly property bool nativeActive: root.core !== null
  readonly property string backend: root.nativeActive ? "native" : "qml"

  Component.onCompleted: root._probe()

  function _probe() {
    try {
      const probe = NativeSpec.probe(
        'QtObject { readonly property var sm: SystemMonitor }',
        root, "OozeSysMonProbe")
      root.core = probe.sm
      root.core.intervalMs = root.intervalMs
      root.core.historySize = root.maxSamples
      root.core.setWanted("facade", root.wanted)
    } catch (e) {
      root.core = null
    }
    root._sync()
  }

  function _sync() {
    if (root.nativeActive) root.core.setWanted("facade", root.wanted)
    fallback.active = root.wanted && !root.nativeActive
  }

  // ─── Respaldo QML ────────────────────────────────────────────
  SystemStats {
    id: fallback
    active: false
    intervalMs: root.intervalMs
    maxSamples: root.maxSamples
  }

  // ─── Ajustes ─────────────────────────────────────────────────
  property int intervalMs: 1000
  onIntervalMsChanged: if (root.nativeActive) root.core.intervalMs = root.intervalMs
  property int maxSamples: 60
  onMaxSamplesChanged: if (root.nativeActive) root.core.historySize = root.maxSamples

  // ─── CPU / RAM ───────────────────────────────────────────────
  readonly property real cpu: root.nativeActive ? root.core.cpu : fallback.cpu
  readonly property var cores: root.nativeActive ? root.core.perCore : []
  readonly property real cpuTemp: root.nativeActive ? root.core.cpuTemp : fallback.cpuTemp
  readonly property real cpuFreqMhz: root.nativeActive ? root.core.cpuFreqMhz : 0
  readonly property real ram: root.nativeActive ? root.core.ram : fallback.ram
  readonly property real ramUsedMb: root.nativeActive ? root.core.ramUsedMb : Math.round(fallback.ramUsedGb * 1024)
  readonly property real ramTotalMb: root.nativeActive ? root.core.ramTotalMb : Math.round(fallback.ramTotalGb * 1024)
  readonly property real ramUsedGb: root.ramUsedMb / 1024
  readonly property real ramTotalGb: root.ramTotalMb / 1024
  readonly property real swap: root.nativeActive ? root.core.swap : 0
  readonly property real swapUsedGb: root.nativeActive ? root.core.swapUsedMb / 1024 : -1
  readonly property real swapTotalGb: root.nativeActive ? root.core.swapTotalMb / 1024 : -1
  readonly property real load1: root.nativeActive ? root.core.load1 : -1
  readonly property real load5: root.nativeActive ? root.core.load5 : -1
  readonly property real load15: root.nativeActive ? root.core.load15 : -1

  // ─── GPU ─────────────────────────────────────────────────────
  readonly property real gpu: root.nativeActive ? root.core.gpu : fallback.gpu
  readonly property bool gpuAvailable: root.gpu >= 0
  readonly property string gpuName: root.nativeActive ? root.core.gpuName : ""
  readonly property real gpuTemp: root.nativeActive ? root.core.gpuTemp : fallback.gpuTemp
  readonly property real gpuVramUsedMb: root.nativeActive ? root.core.gpuVramUsedMb : -1
  readonly property real gpuVramTotalMb: root.nativeActive ? root.core.gpuVramTotalMb : -1

  // ─── Historial ───────────────────────────────────────────────
  readonly property var cpuHistory: root.nativeActive ? root.core.cpuHistory : fallback.cpuHistory
  readonly property var ramHistory: root.nativeActive ? root.core.ramHistory : fallback.ramHistory
  readonly property var gpuHistory: root.nativeActive ? root.core.gpuHistory : fallback.gpuHistory

  // ─── Red ─────────────────────────────────────────────────────
  readonly property real netDown: root.nativeActive ? root.core.netRx : fallback.netDown
  readonly property real netUp: root.nativeActive ? root.core.netTx : fallback.netUp
  readonly property string netIface: root.nativeActive ? root.core.netIface : fallback.netIface
  readonly property var netDownHistory: root.nativeActive ? root.core.netRxHistory : fallback.netDownHistory
  readonly property var netUpHistory: root.nativeActive ? root.core.netTxHistory : fallback.netUpHistory
  readonly property real netPeak: {
    let m = 10240
    const d = root.netDownHistory, u = root.netUpHistory
    for (let i = 0; i < d.length; i++) if (d[i] > m) m = d[i]
    for (let j = 0; j < u.length; j++) if (u[j] > m) m = u[j]
    return m
  }
  readonly property var netDownGraph: root.netDownHistory.map(v => v / root.netPeak * 100)
  readonly property var netUpGraph: root.netUpHistory.map(v => v / root.netPeak * 100)

  // ─── Discos ──────────────────────────────────────────────────
  readonly property var disks: {
    const src = root.nativeActive ? root.core.disks : fallback.disks
    const out = []
    for (let i = 0; i < src.length; i++) {
      const d = src[i]
      if (root.nativeActive) {
        const dev = d.device || ""
        const base = dev.split("/").pop() || d.name
        const kind = base.indexOf("nvme") === 0 ? "NVMe"
          : (base.indexOf("mmcblk") === 0 ? "SD" : "SSD")
        out.push({ name: base, label: d.name, mount: d.mount, device: dev, fs: d.fs, kind: kind,
                   used: d.used, size: d.total, total: d.total, ratio: (d.percent || 0) / 100,
                   percent: d.percent || 0, temp: -1, isRoot: d.mount === "/" })
      } else {
        out.push({ name: d.name, label: d.name, mount: d.isRoot ? "/" : "",
                   device: "/dev/" + d.name, fs: "", kind: d.kind, used: d.used, size: d.size,
                   total: d.total, ratio: d.ratio,
                   percent: d.ratio >= 0 ? d.ratio * 100 : -1, temp: d.temp, isRoot: d.isRoot })
      }
    }
    return out
  }

  function diskRate(name) {
    if (root.nativeActive) {
      const r = root.core.diskRates[name]
      return r ? r : { r: 0, w: 0 }
    }
    return fallback.diskRate(name)
  }

  // ─── Identidad ───────────────────────────────────────────────
  readonly property string hostname: root.nativeActive ? root.core.hostname : ""
  readonly property string kernel: root.nativeActive ? root.core.kernel : ""
  readonly property string osName: root.nativeActive ? root.core.osName : ""

  // ─── Formato ─────────────────────────────────────────────────
  function fmtRate(b) {
    if (b < 1024) return Math.round(b) + " B/s"
    if (b < 1048576) return (b / 1024).toFixed(b < 10240 ? 1 : 0) + " KB/s"
    if (b < 1073741824) return (b / 1048576).toFixed(b < 10485760 ? 1 : 0) + " MB/s"
    return (b / 1073741824).toFixed(1) + " GB/s"
  }

  function fmtSize(b) {
    if (b < 1073741824) return Math.round(b / 1048576) + "M"
    if (b < 1099511627776) return (b / 1073741824).toFixed(b < 10737418240 ? 1 : 0) + "G"
    return (b / 1099511627776).toFixed(1) + "T"
  }
}
