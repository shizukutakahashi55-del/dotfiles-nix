// SystemStats — CPU / RAM / GPU en vivo + historial para los gráficos.
//
// Solo muestrea mientras `active` sea true (el menú abierto), así no
// gasta nada cuando nadie lo mira. Un único proceso por muestra.
//
// GPU: intenta nvidia-smi y, si no hay, el contador de amdgpu en sysfs
// (gpu_busy_percent). Con GPU Intel o sin soporte queda en "N/A" (-1).
import QtQuick
import Quickshell.Io

Item {
  id: root
  visible: false

  property bool active: false
  property int intervalMs: 1500
  property int maxSamples: 30

  property real cpu: 0
  property real ram: 0
  property real gpu: -1          // -1 = N/A
  property real ramUsedGb: 0
  property real ramTotalGb: 0
  property real cpuTemp: -1      // °C, -1 = N/A (k10temp / coretemp)
  property real gpuTemp: -1      // °C, -1 = N/A (nvidia-smi / amdgpu)

  property var cpuHistory: []
  property var ramHistory: []
  property var gpuHistory: []

  property real prevTotal: 0
  property real prevIdle: 0

  function push(arr, v) {
    return arr.concat([v]).slice(-root.maxSamples)
  }

  function parse(line) {
    const p = line.trim().split(" ")
    if (p.length < 5) return

    const total = parseFloat(p[0])
    const idle = parseFloat(p[1])
    if (root.prevTotal > 0 && total > root.prevTotal) {
      const dt = total - root.prevTotal
      const di = idle - root.prevIdle
      root.cpu = Math.max(0, Math.min(100, (1 - di / dt) * 100))
    }
    root.prevTotal = total
    root.prevIdle = idle

    const usedKb = parseFloat(p[2])
    const totalKb = parseFloat(p[3])
    root.ramUsedGb = usedKb / 1048576
    root.ramTotalGb = totalKb / 1048576
    root.ram = totalKb > 0 ? (usedKb / totalKb) * 100 : 0

    const g = parseFloat(p[4])
    root.gpu = isNaN(g) ? -1 : g

    // Temperaturas (campos opcionales: versiones viejas del comando no los traen)
    const ct = p.length > 5 ? parseFloat(p[5]) : NaN
    const gt = p.length > 6 ? parseFloat(p[6]) : NaN
    root.cpuTemp = isNaN(ct) ? -1 : ct
    root.gpuTemp = isNaN(gt) ? -1 : gt

    root.cpuHistory = root.push(root.cpuHistory, root.cpu)
    root.ramHistory = root.push(root.ramHistory, root.ram)
    if (root.gpu >= 0) root.gpuHistory = root.push(root.gpuHistory, root.gpu)
  }

  Process {
    id: proc
    command: ["bash", "-c", [
      "read -r _ u n s i w q sq st _ < /proc/stat",
      "tot=$((u+n+s+i+w+q+sq+st)); idle=$((i+w))",
      "read -r mt ma <<< \"$(awk '/^MemTotal:/{t=$2} /^MemAvailable:/{a=$2} END{print t, a}' /proc/meminfo)\"",
      "gpu=N/A; gt=N/A; ct=N/A",
      // GPU: uso + temperatura en UNA sola consulta (nvidia-smi es lento)
      "if command -v nvidia-smi >/dev/null 2>&1; then read -r gpu gt <<< \"$(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -n1 | tr -d ',')\"",
      "else for f in /sys/class/drm/card*/device/gpu_busy_percent; do if [ -r \"$f\" ]; then gpu=$(cat \"$f\"); break; fi; done",
      "for h in /sys/class/hwmon/hwmon*; do if [ \"$(cat \"$h/name\" 2>/dev/null)\" = amdgpu ] && [ -r \"$h/temp1_input\" ]; then gt=$(( $(cat \"$h/temp1_input\") / 1000 )); break; fi; done; fi",
      // CPU: sensor k10temp (AMD) / coretemp (Intel)
      "for h in /sys/class/hwmon/hwmon*; do case \"$(cat \"$h/name\" 2>/dev/null)\" in k10temp|coretemp|zenpower) if [ -r \"$h/temp1_input\" ]; then ct=$(( $(cat \"$h/temp1_input\") / 1000 )); break; fi;; esac; done",
      "echo \"$tot $idle $((mt-ma)) $mt ${gpu:-N/A} ${ct:-N/A} ${gt:-N/A}\""
    ].join("\n")]
    running: false
    stdout: SplitParser { onRead: line => root.parse(line) }
  }

  Timer {
    interval: root.intervalMs
    running: root.active
    repeat: true
    triggeredOnStart: true
    onTriggered: { if (!proc.running) proc.running = true }
  }

  // Al reabrir, el primer delta de CPU sería contra una muestra vieja
  onActiveChanged: { if (root.active) root.prevTotal = 0 }
}
