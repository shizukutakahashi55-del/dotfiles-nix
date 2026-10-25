// TodoBackend — tareas (ToDo) del calendario nuevo (Services/Agenda/AgendaView.qml)

pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../Notify"
import "../Lang"
import "../../Core/Toml.js" as Toml

Singleton {
  id: root


  property var items: []

  property bool showTodo: false
  property int nextId: 1

  property bool loaded: false

  // ─── Opciones (Ajustes avanzados → Agenda) ─────────────────
  property bool alarmsEnabled: true
  property bool alarmSound: true
  property bool alarmPersistent: true
  property string alarmSoundFile: ""
  property int alarmVolume: 100

  readonly property string dir: Quickshell.env("HOME") + "/.config/oozeshell"
  readonly property string file: root.dir + "/todos.toml"
  readonly property string legacyFile: root.dir + "/todos.json"


  readonly property var pending: {
    const m = {}
    const all = root.items
    for (let i = 0; i < all.length; i++)
      if (!all[i].done) m[all[i].date] = (m[all[i].date] || 0) + 1
    return m
  }

  function dateKey(d) {
    const p = n => (n < 10 ? "0" : "") + n
    return d.getFullYear() + "-" + p(d.getMonth() + 1) + "-" + p(d.getDate())
  }


  function normTime(str) {
    const s = String(str ?? "").trim()
    if (s === "") return ""
    let h, m
    const c = s.match(/^(\d{1,2}):(\d{1,2})$/)
    if (c) { h = parseInt(c[1]); m = parseInt(c[2]) }
    else if (/^\d{1,2}$/.test(s)) { h = parseInt(s); m = 0 }
    else if (/^\d{3,4}$/.test(s)) { h = parseInt(s.slice(0, s.length - 2)); m = parseInt(s.slice(-2)) }
    else return ""
    if (isNaN(h) || isNaN(m) || h > 23 || m > 59) return ""
    const p = n => (n < 10 ? "0" : "") + n
    return p(h) + ":" + p(m)
  }


  function tasksFor(key) {
    const list = root.items.filter(it => it.date === key)
    const pend = list.filter(t => !t.done)
    const timed = pend.filter(t => t.time !== "").sort((a, b) => a.time < b.time ? -1 : (a.time > b.time ? 1 : 0))
    const plain = pend.filter(t => t.time === "")
    return timed.concat(plain).concat(list.filter(t => t.done))
  }

  function pendingFor(key) { return root.pending[key] || 0 }
  function doneFor(key) { return root.items.filter(it => it.date === key && it.done).length }

  function dueMs(it) {
    const p = it.date.split("-")
    const t = it.time.split(":")
    return new Date(parseInt(p[0]), parseInt(p[1]) - 1, parseInt(p[2]), parseInt(t[0]), parseInt(t[1])).getTime()
  }

  function add(text, key, time) {
    const t = String(text).trim()
    if (t === "" || !key) return
    const tm = root.normTime(time)
    const n = root.items.slice()
    const it = { id: root.nextId, text: t, done: false, date: key, time: tm, notified: false }

    if (tm !== "" && root.dueMs(it) <= Date.now()) it.notified = true
    n.push(it)
    root.nextId += 1
    root.items = n
    root.save()
    root.checkAlarms()
  }

  function toggle(id) {
    root.items = root.items.map(it =>
      it.id === id ? Object.assign({}, it, { done: !it.done }) : it)
    root.save()
  }


  function clearTime(id) {
    root.items = root.items.map(it =>
      it.id === id ? Object.assign({}, it, { time: "", notified: false }) : it)
    root.save()
  }

  function remove(id) {
    root.items = root.items.filter(it => it.id !== id)
    root.save()
  }

  function clearDone(key) {
    root.items = root.items.filter(it => !(it.date === key && it.done))
    root.save()
  }

  function setShowTodo(on) {
    if (!!on === root.showTodo) return
    root.showTodo = !!on
    root.save()
  }

  function setAlarmsEnabled(on) { root.alarmsEnabled = !!on; root.save(); if (on) root.checkAlarms() }
  function setAlarmSound(on) { root.alarmSound = !!on; root.save() }
  function setAlarmPersistent(on) { root.alarmPersistent = !!on; root.save() }
  function setAlarmSoundFile(path) { root.alarmSoundFile = String(path ?? ""); root.save() }
  function setAlarmVolume(v) { root.alarmVolume = AlertSound.clampVolume(v); root.save() }

  // ─── Alarmas ───────────────────────────────────────────────────


  function fireAlarm(it, late) {
    const title = Translations.t("todoAlarmTitle")
    let body = it.time + "  ·  " + it.text
    if (late) body += "  (" + Translations.t("todoAlarmLate") + ")"
    NotificationsBackend.pushAlarm(title, body, root.alarmPersistent)
    if (root.alarmSound) root.playSound()
  }


  function testAlarm() {
    const d = new Date()
    const p = n => (n < 10 ? "0" : "") + n
    root.fireAlarm({ time: p(d.getHours()) + ":" + p(d.getMinutes()), text: Translations.t("todoAlarmTestBody") }, false)
  }

  function checkAlarms() {
    if (!root.loaded || !root.alarmsEnabled) return
    const now = Date.now()
    let changed = false
    const out = root.items.map(it => {
      if (it.done || it.notified || it.time === "") return it
      const due = root.dueMs(it)
      if (now < due) return it
      changed = true
      if (now - due <= 6 * 3600 * 1000) root.fireAlarm(it, now - due > 90000)
      return Object.assign({}, it, { notified: true })
    })
    if (changed) { root.items = out; root.save() }
  }

  Timer {
    interval: 15000
    running: root.loaded && root.alarmsEnabled
    repeat: true
    triggeredOnStart: true
    onTriggered: root.checkAlarms()
  }


  function playSound() {
    AlertSound.play(root.alarmSoundFile, root.alarmVolume, ["alarm-clock-elapsed", "complete", "message-new-instant"])
  }

  // ─── Persistencia ──────────────────────────────────────────────
  property bool saveAgain: false

  function save() {
    saveProc.text = Toml.stringify({
      showTodo: root.showTodo, nextId: root.nextId, items: root.items,
      alarmsEnabled: root.alarmsEnabled, alarmSound: root.alarmSound,
      alarmPersistent: root.alarmPersistent,
      alarmSoundFile: root.alarmSoundFile, alarmVolume: root.alarmVolume
    })

    if (saveProc.running) root.saveAgain = true
    else saveProc.running = true
  }

  Process {
    id: saveProc
    property string text: ""

    command: ["bash", "-c",
      "mkdir -p '" + root.dir + "' && cat > '" + root.file + ".tmp' << 'OOZE_TODO_EOF'\n" + text + "OOZE_TODO_EOF\n" +
      "mv -f '" + root.file + ".tmp' '" + root.file + "' && { [ -f '" + root.legacyFile + "' ] && mv -f '" + root.legacyFile + "' '" + root.legacyFile + ".bak'; true; }"]
    running: false
    onRunningChanged: {
      if (running || !root.saveAgain) return
      root.saveAgain = false
      Qt.callLater(() => { saveProc.running = true })
    }
  }

  Process {
    id: loadProc
    command: ["bash", "-c", "cat '" + root.file + "' 2>/dev/null || cat '" + root.legacyFile + "' 2>/dev/null"]
    running: true
    property string buffer: ""
    stdout: SplitParser { onRead: line => loadProc.buffer += line + "\n" }
    onRunningChanged: {
      if (running) return
      const raw = loadProc.buffer.trim()
      loadProc.buffer = ""
      if (raw !== "") {
        try {
          const j = Toml.parseAny(raw)
          const src = Array.isArray(j.items) ? j.items : []
          const out = []
          let maxId = 0
          for (let i = 0; i < src.length; i++) {
            const it = src[i]
            if (!it || typeof it.text !== "string" || typeof it.date !== "string") continue
            const id = parseInt(it.id) || (maxId + 1)
            maxId = Math.max(maxId, id)
            out.push({
              id: id, text: it.text, done: it.done === true, date: it.date,

              time: typeof it.time === "string" ? root.normTime(it.time) : "",
              notified: it.notified === true
            })
          }
          root.items = out
          root.nextId = Math.max(parseInt(j.nextId) || 1, maxId + 1)
          root.showTodo = j.showTodo === true
          if (typeof j.alarmsEnabled === "boolean") root.alarmsEnabled = j.alarmsEnabled
          if (typeof j.alarmSound === "boolean") root.alarmSound = j.alarmSound
          if (typeof j.alarmPersistent === "boolean") root.alarmPersistent = j.alarmPersistent
          if (typeof j.alarmSoundFile === "string") root.alarmSoundFile = j.alarmSoundFile
          if (typeof j.alarmVolume === "number") root.alarmVolume = AlertSound.clampVolume(j.alarmVolume)
        } catch (e) {
          console.log("[todo] error leyendo todos.toml:", e)
        }
      }
      root.loaded = true
      if (Toml.isJson(raw)) root.save()
    }
  }
}
