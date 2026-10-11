// SystemStats — CPU / RAM / GPU en vivo + historial para los gráficos.
// Solo muestrea mientras `active` sea true (el menú abierto), así no gasta nada cuando nadie lo mira.

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
      return
    }

    if (root.tickN > 0 && !root.gotStat) { root.missedStat++; root.checkFallback() }
    root.gotStat = false
    statFile.reload()
    memFile.reload()
    if (root.cpuTempPath !== "") cpuTempFile.reload()
    if (root.gpuTempPath !== "") gpuTempFile.reload()
    if (root.gpuBusyPath !== "") gpuBusyFile.reload()
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
    if (root.active) { root.prevTotal = 0; root.tickN = 0; root.ensureDiscovered() }
  }
}
