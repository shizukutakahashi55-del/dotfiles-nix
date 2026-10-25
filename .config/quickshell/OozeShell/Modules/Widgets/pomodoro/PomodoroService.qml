// PomodoroService — el temporizador de los widgets Pomodoro (uno por widget).

pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import "../../../COMMON"
import "../../../Services/Lang"
import "../../../Services/Notify"
import ".."
import "../../../Core/Toml.js" as Toml

Singleton {
  id: root

  property var states: ({})
  property real now: Date.now()
  property bool anyRunning: false

  // ─── Opciones y duraciones ─────────────────────────────────────
  readonly property string dashId: "dashboard"
  readonly property string dashFile: Theme.prefsDir + "/pomodoro.toml"
  readonly property string dashLegacy: Theme.prefsDir + "/pomodoro.json"
  property var dashOpts: ({})
  property string dashWritten: ""

  function opts(id) {
    const t = WidgetRegistry.get("pomodoro")
    if (id === root.dashId) return Object.assign({}, t ? t.defaults : {}, root.dashOpts)
    const c = WidgetConfig.byId[id]
    return Object.assign({}, t ? t.defaults : {}, c ? c.options : {})
  }

  function setDash(key, value) {
    const t = WidgetRegistry.get("pomodoro")
    const r = t && t.ranges ? t.ranges[key] : null
    let v = value
    if (r) v = Math.max(r[0], Math.min(r[1], Math.round(Number(value))))
    if (root.dashOpts[key] === v) return
    const n = Object.assign({}, root.dashOpts)
    n[key] = v
    root.dashOpts = n
    root.saveDash()
    root.set(root.dashId, {})
  }
  function dashValue(key) { return root.opts(root.dashId)[key] }

  function saveDash() { dashSave.restart() }
  Timer {
    id: dashSave
    interval: 300
    onTriggered: {
      const text = Toml.stringify({ version: 1, options: root.dashOpts })
      root.dashWritten = text
      dashWriter.payload = text
      if (dashWriter.running) dashWriter.pending = true
      else dashWriter.running = true
    }
  }
  Process {
    id: dashWriter
    property string payload: ""
    property bool pending: false
    command: ["bash", "-c",
      'mkdir -p "$OOZE_DIR" && printf %s "$OOZE_DATA" > "$OOZE_FILE.tmp" && mv "$OOZE_FILE.tmp" "$OOZE_FILE" && { [ -f "$OOZE_LEGACY" ] && mv -f "$OOZE_LEGACY" "$OOZE_LEGACY.bak"; true; }']
    environment: ({ "OOZE_DATA": dashWriter.payload, "OOZE_DIR": Theme.prefsDir, "OOZE_FILE": root.dashFile, "OOZE_LEGACY": root.dashLegacy })
    running: false
    onRunningChanged: {
      if (running || !pending) return
      pending = false
      running = true
    }
  }
  FileView {
    path: root.dashFile
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
      const raw = text().trim()
      if (raw === "" || raw === root.dashWritten.trim()) return
      try {
        const j = Toml.parseAny(raw)
        if (j && typeof j.options === "object") root.dashOpts = j.options
      } catch (e) {}
    }
    onLoadFailed: dashLegacyView.path = root.dashLegacy
  }
  FileView {
    id: dashLegacyView
    onLoaded: {
      try {
        const j = JSON.parse(text().trim())
        if (j && typeof j.options === "object") { root.dashOpts = j.options; root.saveDash() }
      } catch (e) {}
    }
  }
  function roundsOf(o) { return Math.max(1, Math.round(Number(o.rounds) || 4)) }
  function phaseMs(phase, o) {
    const m = phase === "long" ? o.longMin : (phase === "short" ? o.shortMin : o.focusMin)
    return Math.max(1, Number(m) || 1) * 60000
  }
  function fresh() { return { phase: "focus", running: false, endMs: 0, remainMs: -1, round: 1 } }


  function view(id) {
    const st = root.states[id] ?? root.fresh()
    const o = root.opts(id)
    const total = root.phaseMs(st.phase, o)
    let remain = total
    if (st.running) remain = Math.max(0, st.endMs - root.now)
    else if (st.remainMs >= 0) remain = st.remainMs
    remain = Math.min(remain, total)
    const rounds = root.roundsOf(o)
    return {
      phase: st.phase, running: st.running,
      remainMs: remain, totalMs: total,
      progress: total > 0 ? 1 - remain / total : 0,
      round: Math.min(st.round, rounds), rounds: rounds
    }
  }

  function set(id, patch) {
    const s = Object.assign({}, root.states)
    s[id] = Object.assign({}, root.states[id] ?? root.fresh(), patch)
    root.states = s
    root.refreshRunning()
  }
  function forget(id) {
    if (root.states[id] === undefined) return
    const s = Object.assign({}, root.states)
    delete s[id]
    root.states = s
    root.refreshRunning()
  }
  function refreshRunning() {
    let any = false
    for (const k of Object.keys(root.states)) if (root.states[k].running) { any = true; break }
    root.anyRunning = any
  }

  // ─── Acciones ──────────────────────────────────────────────────
  function toggle(id) {
    const v = root.view(id)
    if (v.running) {
      root.set(id, { running: false, remainMs: v.remainMs })
    } else {
      root.now = Date.now()
      root.set(id, { running: true, endMs: root.now + v.remainMs, remainMs: v.remainMs })
    }
  }
  function reset(id) { root.set(id, { running: false, remainMs: -1 }) }
  function restart(id) { root.set(id, root.fresh()) }
  function skip(id) { root.advance(id, false) }


  function advance(id, finished) {
    const st = root.states[id] ?? root.fresh()
    const o = root.opts(id)
    const rounds = root.roundsOf(o)

    let phase = "focus"
    let round = st.round
    if (st.phase === "focus") phase = (st.round >= rounds) ? "long" : "short"
    else round = (st.phase === "long") ? 1 : st.round + 1

    const go = finished ? (o.autoNext === true) : st.running
    const total = root.phaseMs(phase, o)
    root.now = Date.now()
    root.set(id, { phase: phase, round: round, running: go,
                   endMs: go ? root.now + total : 0, remainMs: go ? total : -1 })
    if (finished) root.alert(st.phase, o)
  }

  // ─── Reloj ─────────────────────────────────────────────────────
  function rebase() {
    const now = Date.now()
    const s = Object.assign({}, root.states)
    let changed = false
    for (const id of Object.keys(s)) {
      const st = s[id]
      if (!st.running) continue
      const total = root.phaseMs(st.phase, root.opts(id))
      if (st.endMs - now <= total) continue
      s[id] = Object.assign({}, st, { endMs: now + total })
      changed = true
    }
    if (changed) {
      root.states = s
      root.now = now
    }
  }
  Connections {
    target: WidgetConfig
    function onWidgetRemoved(id) { root.forget(id) }
    function onWidgetsChanged() { root.rebase() }
  }
  Timer {
    interval: 250
    repeat: true
    running: root.anyRunning
    onTriggered: {
      root.now = Date.now()
      for (const id of Object.keys(root.states)) {
        const st = root.states[id]
        if (!st.running) continue
        const cfg = WidgetConfig.byId[id]
        if (cfg && !cfg.enabled) {
          root.set(id, { running: false, remainMs: Math.max(0, st.endMs - root.now) })
        } else if (root.now >= st.endMs) {
          root.advance(id, true)
        }
      }
    }
  }

  // ─── Avisos ────────────────────────────────────────────────────
  function alert(fromPhase, o) {
    if (o.notify !== false)
      NotificationsBackend.pushAlarm(Translations.t("wgPomoTitle"),
        Translations.t(fromPhase === "focus" ? "wgPomoFocusEnd" : "wgPomoBreakEnd"), false)
    if (o.sound !== false) root.playSound(o)
  }


  function playSound(o) {
    const v = o ? o : root.opts(root.dashId)
    AlertSound.play(v.soundFile, v.volume, ["complete", "alarm-clock-elapsed", "message-new-instant"])
  }

  function testAlert() { root.alert("focus", root.opts(root.dashId)) }
}
