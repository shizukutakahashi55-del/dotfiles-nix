// PomodoroService — el temporizador de los widgets Pomodoro (uno por widget).

pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import "../../../Services/Lang"
import "../../../Services/Notify"
import ".."

Singleton {
  id: root

  property var states: ({})
  property real now: Date.now()
  property bool anyRunning: false

  // ─── Opciones y duraciones ─────────────────────────────────────
  function opts(id) {
    const t = WidgetRegistry.get("pomodoro")
    const c = WidgetConfig.byId[id]
    return Object.assign({}, t ? t.defaults : {}, c ? c.options : {})
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
    if (o.sound !== false) root.playSound()
  }


  function playSound() {
    soundProc.running = false
    soundProc.running = true
  }
  Process {
    id: soundProc
    command: ["bash", "-c",
      "s=''; IFS=:; " +
      "for d in $XDG_DATA_DIRS /run/current-system/sw/share /usr/share /usr/local/share; do " +
      "for n in complete alarm-clock-elapsed message-new-instant; do " +
      "f=\"$d/sounds/freedesktop/stereo/$n.oga\"; [ -f \"$f\" ] && s=\"$f\" && break 2; " +
      "done; done; unset IFS; " +
      "if [ -n \"$s\" ]; then " +
      "(command -v pw-play >/dev/null && pw-play \"$s\") || (command -v paplay >/dev/null && paplay \"$s\") || " +
      "(command -v canberra-gtk-play >/dev/null && canberra-gtk-play -i complete); " +
      "else command -v canberra-gtk-play >/dev/null && canberra-gtk-play -i complete; fi; exit 0"]
    running: false
  }
}
