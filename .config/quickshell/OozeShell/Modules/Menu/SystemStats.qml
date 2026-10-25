// SystemStats — CPU / RAM / GPU / discos / red en vivo + historial para los gráficos.

import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root
  visible: false

  property bool active: false
  property int intervalMs: 1500
  property int maxSamples: 30

  property real cpu: 0
  property real ram: 0
  property real gpu: -1
  property real ramUsedGb: 0
  property real ramTotalGb: 0
  property real cpuTemp: -1
  property real gpuTemp: -1

  property var cpuHistory: []
  property var ramHistory: []
  property var gpuHistory: []

  // ─── Red y discos: estado ────────────────────────────────────
  property real netDown: 0
  property real netUp: 0
  property string netIface: ""
  property var netDownHistory: []
  property var netUpHistory: []
  property real prevRx: -1
  property real prevTx: -1
  property real prevNetT: 0

  property var disks: []
  property var diskIndex: ({})
  property var diskRates: ({})
  property var prevDisk: ({})
  property real prevDiskT: 0
  property string pendRoot: ""
  property string pendJson: ""
  property var pendTemps: ({})

  readonly property real netPeak: {
    let m = 10240
    for (let i = 0; i < root.netDownHistory.length; i++) if (root.netDownHistory[i] > m) m = root.netDownHistory[i]
    for (let j = 0; j < root.netUpHistory.length; j++) if (root.netUpHistory[j] > m) m = root.netUpHistory[j]
    return m
  }
  readonly property var netDownGraph: root.netDownHistory.map(v => v / root.netPeak * 100)
  readonly property var netUpGraph: root.netUpHistory.map(v => v / root.netPeak * 100)

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

  function diskRate(name) {
    return root.diskRates[name] ?? { r: 0, w: 0 }
  }

  property real prevTotal: 0
  property real prevIdle: 0

  function push(arr, v) {
    return arr.concat([v]).slice(-root.maxSamples)
  }

  // ─── Estado interno ──────────────────────────────────────────
  property bool useShell: false
  property bool discovered: false
  property string cpuTempPath: ""
  property string gpuTempPath: ""
  property string gpuBusyPath: ""
  property bool hasNvidia: false
  property int tickN: 0
  property bool gotStat: false
  property int missedStat: 0

  function applyCpu(total, idle) {
    if (root.prevTotal > 0 && total > root.prevTotal) {
      const dt = total - root.prevTotal
      const di = idle - root.prevIdle
      root.cpu = Math.max(0, Math.min(100, (1 - di / dt) * 100))
    }
    root.prevTotal = total
    root.prevIdle = idle
  }

  function applyMem(usedKb, totalKb) {
    root.ramUsedGb = usedKb / 1048576
    root.ramTotalGb = totalKb / 1048576
    root.ram = totalKb > 0 ? (usedKb / totalKb) * 100 : 0
  }

  function commit() {
    root.cpuHistory = root.push(root.cpuHistory, root.cpu)
    root.ramHistory = root.push(root.ramHistory, root.ram)
    if (root.gpu >= 0) root.gpuHistory = root.push(root.gpuHistory, root.gpu)
  }

  // ─── Lecturas por FileView ───────────────────────────────────
  function onStat(text) {

    if (!root.active) return

    const m = /^cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/.exec(text || "")
    if (!m) { root.missedStat += 2; root.checkFallback(); return }
    let total = 0
    for (let i = 1; i <= 8; i++) total += parseFloat(m[i])
    root.gotStat = true
    root.missedStat = 0
    root.applyCpu(total, parseFloat(m[4]) + parseFloat(m[5]))
    root.commit()
  }

  function onMem(text) {
    const t = /MemTotal:\s+(\d+)/.exec(text || "")
    const a = /MemAvailable:\s+(\d+)/.exec(text || "")
    if (!t || !a) return
    const totalKb = parseFloat(t[1])
    root.applyMem(totalKb - parseFloat(a[1]), totalKb)
  }

  // ─── Red y discos: lecturas ──────────────────────────────────
  function onNet(text) {
    if (root.netIface === "") return
    const key = root.netIface + ":"
    const lines = (text || "").split("\n")
    for (let i = 0; i < lines.length; i++) {
      const ln = lines[i].trim()
      if (!ln.startsWith(key)) continue
      const f = ln.substring(key.length).trim().split(/\s+/)
      const rx = parseFloat(f[0])
      const tx = parseFloat(f[8])
      if (isNaN(rx) || isNaN(tx)) return
      const now = Date.now()
      if (root.prevRx >= 0 && now > root.prevNetT) {
        const dt = (now - root.prevNetT) / 1000
        root.netDown = Math.max(0, (rx - root.prevRx) / dt)
        root.netUp = Math.max(0, (tx - root.prevTx) / dt)
        root.netDownHistory = root.push(root.netDownHistory, root.netDown)
        root.netUpHistory = root.push(root.netUpHistory, root.netUp)
      }
      root.prevRx = rx
      root.prevTx = tx
      root.prevNetT = now
      return
    }
  }

  function onDiskStats(text) {
    const now = Date.now()
    const dt = (now - root.prevDiskT) / 1000
    const cur = {}
    const rates = {}
    const lines = (text || "").split("\n")
    for (let i = 0; i < lines.length; i++) {
      const f = lines[i].trim().split(/\s+/)
      if (f.length < 10) continue
      const n = f[2]
      if (root.diskIndex[n] !== true) continue
      const rd = parseFloat(f[5])
      const wr = parseFloat(f[9])
      cur[n] = [rd, wr]
      const p = root.prevDisk[n]
      if (p && root.prevDiskT > 0 && dt > 0)
        rates[n] = { r: Math.max(0, (rd - p[0]) * 512 / dt), w: Math.max(0, (wr - p[1]) * 512 / dt) }
    }
    root.prevDisk = cur
    root.prevDiskT = now
    if (Object.keys(rates).length > 0) root.diskRates = rates
  }

  function sumFs(node, acc) {
    const u = parseFloat(node.fsused)
    const s = parseFloat(node.fssize)
    if (!isNaN(u) && !isNaN(s)) { acc.used += u; acc.size += s }
    const ch = node.children || []
    for (let i = 0; i < ch.length; i++) root.sumFs(ch[i], acc)
  }

  function buildDisks() {
    let data
    try { data = JSON.parse(root.pendJson) } catch (e) { return }
    const list = data.blockdevices || []
    const out = []
    const idx = {}
    for (let i = 0; i < list.length; i++) {
      const d = list[i]
      if (d.type !== "disk" || !/^(nvme|sd|vd|hd|mmcblk|xvd)/.test(d.name)) continue
      if (d.rm === true || d.rm === 1 || d.rm === "1") continue
      const acc = { used: 0, size: 0 }
      root.sumFs(d, acc)
      const rota = d.rota === true || d.rota === 1 || d.rota === "1"
      const kind = d.name.startsWith("nvme") ? "NVMe" : (d.name.startsWith("mmcblk") ? "SD" : (rota ? "HDD" : "SSD"))
      const t = root.pendTemps[d.name]
      out.push({
        name: d.name,
        kind: kind,
        used: acc.used,
        size: acc.size,
        total: parseFloat(d.size) || 0,
        ratio: acc.size > 0 ? acc.used / acc.size : -1,
        temp: t === undefined ? -1 : t,
        isRoot: d.name === root.pendRoot
      })
      idx[d.name] = true
    }
    out.sort((a, b) => (b.isRoot ? 1 : 0) - (a.isRoot ? 1 : 0) || (a.name < b.name ? -1 : 1))
    root.diskIndex = idx
    root.disks = out
  }

  function onSlow(line) {
    const sep = line.indexOf("|")
    if (sep < 0) return
    const k = line.substring(0, sep)
    const v = line.substring(sep + 1)
    if (k === "R") root.pendRoot = v.trim()
    else if (k === "N") { if (v.trim() !== root.netIface) root.netIface = v.trim() }
    else if (k === "J") root.pendJson = v
    else if (k === "T") {
      const p = v.split("|")
      const m = parseFloat(p[1])
      if (p.length > 1 && !isNaN(m)) {
        const t = Object.assign({}, root.pendTemps)
        t[p[0]] = Math.round(m / 1000)
        root.pendTemps = t
      }
    }
  }

  onNetIfaceChanged: { root.prevRx = -1; root.prevTx = -1 }

  function checkFallback() {
    if (root.missedStat >= 2 && !root.useShell) {
      console.log("[systemstats] FileView no entrega /proc/stat: se usa el comando de respaldo")
      root.useShell = true
    }
  }

  FileView {
    id: statFile
    path: "/proc/stat"
    onLoaded: root.onStat(statFile.text())
    onLoadFailed: { root.missedStat += 2; root.checkFallback() }
  }
  FileView {
    id: memFile
    path: "/proc/meminfo"
    onLoaded: root.onMem(memFile.text())
  }
  FileView {
    id: netFile
    path: "/proc/net/dev"
    onLoaded: root.onNet(netFile.text())
  }
  FileView {
    id: diskFile
    path: "/proc/diskstats"
    onLoaded: root.onDiskStats(diskFile.text())
  }
  FileView {
    id: cpuTempFile
    path: root.cpuTempPath
    onLoaded: { const v = parseFloat(cpuTempFile.text()); root.cpuTemp = isNaN(v) ? -1 : Math.round(v / 1000) }
  }
  FileView {
    id: gpuTempFile
    path: root.gpuTempPath
    onLoaded: { const v = parseFloat(gpuTempFile.text()); root.gpuTemp = isNaN(v) ? -1 : Math.round(v / 1000) }
  }
  FileView {
    id: gpuBusyFile
    path: root.gpuBusyPath
    onLoaded: { const v = parseFloat(gpuBusyFile.text()); root.gpu = isNaN(v) ? -1 : v }
  }


  Process {
    id: nv
    command: ["nvidia-smi", "--query-gpu=utilization.gpu,temperature.gpu",
              "--format=csv,noheader,nounits"]
    stdout: SplitParser {
      onRead: line => {
        const p = line.split(",")
        const g = parseFloat(p[0])
        const t = parseFloat(p[1])
        root.gpu = isNaN(g) ? -1 : g
        root.gpuTemp = isNaN(t) ? -1 : t
      }
    }
  }

  // ─── Descubrimiento (una sola vez) ───────────────────────────

  Process {
    id: discover
    command: ["bash", "-c", [
      "for h in /sys/class/hwmon/hwmon*; do case \"$(cat \"$h/name\" 2>/dev/null)\" in k10temp|coretemp|zenpower) if [ -r \"$h/temp1_input\" ]; then echo \"cputemp=$h/temp1_input\"; break; fi;; esac; done",
      "if command -v nvidia-smi >/dev/null 2>&1; then echo nvidia=1",
      "else for f in /sys/class/drm/card*/device/gpu_busy_percent; do if [ -r \"$f\" ]; then echo \"gpubusy=$f\"; break; fi; done",
      "for h in /sys/class/hwmon/hwmon*; do if [ \"$(cat \"$h/name\" 2>/dev/null)\" = amdgpu ] && [ -r \"$h/temp1_input\" ]; then echo \"gputemp=$h/temp1_input\"; break; fi; done; fi"
    ].join("\n")]
    stdout: SplitParser {
      onRead: line => {
        const i = line.indexOf("=")
        if (i < 0) return
        const k = line.substring(0, i)
        const v = line.substring(i + 1).trim()
        if (k === "cputemp") root.cpuTempPath = v
        else if (k === "gputemp") root.gpuTempPath = v
        else if (k === "gpubusy") root.gpuBusyPath = v
        else if (k === "nvidia") root.hasNvidia = true
      }
    }
    onExited: root.discovered = true
  }

  // ─── Descubrimiento lento: discos, temperaturas y red ────────
  Process {
    id: slow
    command: ["bash", "-c", [
      "src=$(findmnt -n -o SOURCE / 2>/dev/null); src=${src%%\\[*}",
      "rd=; if [ -n \"$src\" ]; then rd=$(lsblk -nrso NAME,TYPE \"$src\" 2>/dev/null | awk '$2==\"disk\"{print $1; exit}'); fi",
      "echo \"R|$rd\"",
      "awk 'NR>1 && $2==\"00000000\"{ if (m==\"\" || $7+0<m) { m=$7+0; i=$1 } } END{print \"N|\" i}' /proc/net/route",
      "for d in /sys/block/*; do n=${d##*/}",
      "case $n in nvme*|sd*|hd*|vd*|mmcblk*) ;; *) continue;; esac",
      "for f in \"$d\"/device/hwmon*/temp1_input \"$d\"/device/hwmon/hwmon*/temp1_input /sys/class/nvme/${n%n[0-9]*}/hwmon*/temp1_input; do",
      "if [ -r \"$f\" ]; then echo \"T|$n|$(cat \"$f\" 2>/dev/null)\"; break; fi",
      "done; done",
      "echo \"J|$(lsblk -J -b -o NAME,TYPE,SIZE,FSUSED,FSSIZE,ROTA,RM 2>/dev/null | tr -d '\\n')\""
    ].join("\n")]
    running: false
    stdout: SplitParser { onRead: line => root.onSlow(line) }
    onExited: root.buildDisks()
  }

  Timer {
    interval: 10000
    running: root.active
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!slow.running) { root.pendTemps = ({}); slow.running = true }
  }

  Process {
    id: ioProc
    command: ["bash", "-c", "cat /proc/net/dev; echo @@; cat /proc/diskstats"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        const p = text.split("@@")
        root.onNet(p[0])
        root.onDiskStats(p[1] || "")
      }
    }
  }

  // ─── Respaldo: el comando de siempre ─────────────────────────
  function parseShell(line) {
    const p = line.trim().split(" ")
    if (p.length < 5) return
    root.applyCpu(parseFloat(p[0]), parseFloat(p[1]))
    root.applyMem(parseFloat(p[2]), parseFloat(p[3]))
    const g = parseFloat(p[4])
    root.gpu = isNaN(g) ? -1 : g
    const ct = p.length > 5 ? parseFloat(p[5]) : NaN
    const gt = p.length > 6 ? parseFloat(p[6]) : NaN
    root.cpuTemp = isNaN(ct) ? -1 : ct
    root.gpuTemp = isNaN(gt) ? -1 : gt
    root.commit()
  }

  Process {
    id: shellProc
    command: ["bash", "-c", [
      "read -r _ u n s i w q sq st _ < /proc/stat",
      "tot=$((u+n+s+i+w+q+sq+st)); idle=$((i+w))",
      "read -r mt ma <<< \"$(awk '/^MemTotal:/{t=$2} /^MemAvailable:/{a=$2} END{print t, a}' /proc/meminfo)\"",
      "gpu=N/A; gt=N/A; ct=N/A",
      "if command -v nvidia-smi >/dev/null 2>&1; then read -r gpu gt <<< \"$(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -n1 | tr -d ',')\"",
      "else for f in /sys/class/drm/card*/device/gpu_busy_percent; do if [ -r \"$f\" ]; then gpu=$(cat \"$f\"); break; fi; done",
      "for h in /sys/class/hwmon/hwmon*; do if [ \"$(cat \"$h/name\" 2>/dev/null)\" = amdgpu ] && [ -r \"$h/temp1_input\" ]; then gt=$(( $(cat \"$h/temp1_input\") / 1000 )); break; fi; done; fi",
      "for h in /sys/class/hwmon/hwmon*; do case \"$(cat \"$h/name\" 2>/dev/null)\" in k10temp|coretemp|zenpower) if [ -r \"$h/temp1_input\" ]; then ct=$(( $(cat \"$h/temp1_input\") / 1000 )); break; fi;; esac; done",
      "echo \"$tot $idle $((mt-ma)) $mt ${gpu:-N/A} ${ct:-N/A} ${gt:-N/A}\""
    ].join("\n")]
    running: false
    stdout: SplitParser { onRead: line => root.parseShell(line) }
  }

  // ─── Muestreo ────────────────────────────────────────────────
  function tick() {
    if (root.useShell) {
      if (!shellProc.running) shellProc.running = true
      if (!ioProc.running) ioProc.running = true
      return
    }

    if (root.tickN > 0 && !root.gotStat) { root.missedStat++; root.checkFallback() }
    root.gotStat = false
    statFile.reload()
    memFile.reload()
    if (root.cpuTempPath !== "") cpuTempFile.reload()
    if (root.gpuTempPath !== "") gpuTempFile.reload()
    if (root.gpuBusyPath !== "") gpuBusyFile.reload()
    netFile.reload()
    diskFile.reload()
    if (root.hasNvidia && root.tickN % 3 === 0 && !nv.running) nv.running = true
    root.tickN++
  }

  Timer {
    interval: root.intervalMs
    running: root.active && (root.discovered || root.useShell)
    repeat: true
    triggeredOnStart: true
    onTriggered: root.tick()
  }

  function ensureDiscovered() {
    if (root.active && !root.discovered && !root.useShell && !discover.running)
      discover.running = true
  }
  Component.onCompleted: root.ensureDiscovered()


  onActiveChanged: {
    if (root.active) {
      root.prevTotal = 0; root.tickN = 0
      root.prevRx = -1; root.prevTx = -1; root.prevDiskT = 0
      root.ensureDiscovered()
    }
  }
}
