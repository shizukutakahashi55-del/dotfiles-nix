// WeatherService — datos del clima (Open-Meteo, sin API key), compartidos.

pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import "../../../Services/Lang"

Singleton {
  id: root

  property var watchers: ({})
  property var results: ({})
  readonly property bool wanted: Object.keys(root.watchers).length > 0


  property var geo: ({})
  property var names: ({})
  property var inflight: ({})
  property var lastOk: ({})
  property var lastTry: ({})
  property var failCount: ({})
  property var dead: ({})
  property bool pendingData: false

  function keyOf(city) { return String(city || "").trim().toLowerCase() }
  function get(city) { return root.results[root.keyOf(city)] ?? null }

  function watch(id, city, refreshMin) {
    const key = root.keyOf(city)
    if (key === "") { root.unwatch(id); return }
    const w = Object.assign({}, root.watchers)
    w[id] = { key: key, ms: Math.max(10, Number(refreshMin) || 20) * 60000 }
    root.watchers = w
    root.names[key] = String(city || "").trim()
    root.updatePending()
    root.check()
  }
  function unwatch(id) {
    if (!(id in root.watchers)) return
    const w = Object.assign({}, root.watchers)
    delete w[id]
    root.watchers = w
  }

  // ── red (curl) ──
  property var queue: []
  property var job: null
  readonly property bool curlBusy: root.job !== null

  function getJson(url, cb) {
    root.queue = root.queue.concat([{ url: url, cb: cb }])
    root.pump()
  }
  function pump() {
    if (root.job !== null || root.queue.length === 0 || curl.running) return
    const q = root.queue.slice()
    root.job = q.shift()
    root.job.t0 = Date.now()
    root.queue = q
    curl.command = ["curl", "-sS", "-L", "--connect-timeout", "5", "--max-time", "15",
                    "-A", "OozeShell-Weather/1.0", "-w", "\n%{http_code}", root.job.url]
    curl.running = false
    curl.running = true
    watchdog.restart()
  }
  function finishJob(err, json) {
    const j = root.job
    if (j === null) return
    console.log("[weather]", (err === "" ? "ok" : "FALLO " + err), (Date.now() - (j.t0 || Date.now())) + " ms",
                String(j.url).replace(/^https:\/\//, "").slice(0, 60))
    root.job = null
    watchdog.stop()
    exitGrace.stop()
    try { j.cb(err, json) } catch (e) { console.log("[weather] callback:", e) }
    Qt.callLater(root.pump)
  }
  function parseReply(text) {
    const t = String(text)
    const i = t.lastIndexOf("\n")
    const code = parseInt(i >= 0 ? t.slice(i + 1) : t) || 0
    const body = i >= 0 ? t.slice(0, i) : ""
    if (code !== 200) { root.finishJob("http " + code, null); return }
    let j = null
    try { j = JSON.parse(body) } catch (e) { root.finishJob("parse", null); return }
    root.finishJob("", j)
  }

  Process {
    id: curl
    running: false
    stdout: StdioCollector { onStreamFinished: root.parseReply(text) }
    stderr: SplitParser { onRead: line => console.log("[weather]", line) }

    onExited: { if (root.job !== null) exitGrace.restart() }
    onRunningChanged: { if (!running) Qt.callLater(root.pump) }
  }
  Timer { id: exitGrace; interval: 400; onTriggered: root.finishJob("curl", null) }
  Timer { id: watchdog; interval: 20000; onTriggered: { curl.running = false; root.finishJob("timeout", null) } }


  function norm(s) {
    return String(s || "").toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "").trim()
  }

  function resolve(key, cb) {
    if (root.geo[key]) { cb("", root.geo[key]); return }
    const raw = root.names[key] || ""
    const m = /^\s*(-?\d+(?:\.\d+)?)\s*[,;\s]\s*(-?\d+(?:\.\d+)?)\s*$/.exec(raw)
    if (m) {
      root.geo[key] = { lat: parseFloat(m[1]), lon: parseFloat(m[2]), name: "" }
      cb("", root.geo[key]); return
    }
    if (key === "") { cb("nocity", null); return }

    const parts = raw.split(",").map(x => x.trim()).filter(x => x !== "")
    const place = parts[0] || raw
    const hint = root.norm(parts.slice(1).join(" "))
    root.getJson("https://geocoding-api.open-meteo.com/v1/search?count=10&format=json&language="
      + encodeURIComponent(Translations.current || "en") + "&name=" + encodeURIComponent(place),
      function (err, j) {
        const list = (!err && j && j.results) ? j.results : []
        if (list.length === 0) { cb(err || "notfound", null); return }
        let r = list[0]
        if (hint !== "") {
          const hit = list.find(x => [x.country_code, x.country, x.admin1, x.admin2]
            .some(f => f && (root.norm(f) === hint || root.norm(f).indexOf(hint) >= 0 || hint.indexOf(root.norm(f)) >= 0)))
          if (hit) r = hit
        }
        root.geo[key] = { lat: r.latitude, lon: r.longitude, name: r.name || place,
                          region: [r.admin1, r.country_code].filter(x => x).join(", ") }
        cb("", root.geo[key])
      })
  }

  function store(key, patch) {
    const o = Object.assign({}, root.results)
    o[key] = Object.assign({}, root.results[key] || {}, patch)
    root.results = o
  }

  function fail(key, err) {
    root.inflight[key] = false
    root.failCount[key] = (root.failCount[key] || 0) + 1
    if (err === "notfound") root.dead[key] = true
    root.store(key, { error: err })
    root.updatePending()
  }
  function backoff(key) { return Math.min(30000, 3000 * Math.pow(2, Math.max(0, (root.failCount[key] || 1) - 1))) }
  function updatePending() {
    let p = false
    for (const id in root.watchers) {
      const k = root.watchers[id].key
      if (!root.lastOk[k] && !root.dead[k]) { p = true; break }
    }
    root.pendingData = p
  }

  function fetchKey(key) {
    if (root.inflight[key]) return
    root.inflight[key] = true
    root.lastTry[key] = Date.now()
    root.resolve(key, function (err, g) {
      if (err || !g) { root.fail(key, err || "geo"); return }
      const url = "https://api.open-meteo.com/v1/forecast?latitude=" + g.lat + "&longitude=" + g.lon
        + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m,is_day,surface_pressure"
        + "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max"
        + "&forecast_days=5&timezone=auto"
      root.getJson(url, function (err2, j) {
        if (err2 || !j || !j.current || !j.daily) { root.fail(key, err2 || "data"); return }
        root.inflight[key] = false
        root.failCount[key] = 0
        const c = j.current, d = j.daily
        const daily = []
        for (let i = 0; i < d.time.length; i++)
          daily.push({ date: d.time[i], code: d.weather_code[i], max: d.temperature_2m_max[i],
                       min: d.temperature_2m_min[i], pop: d.precipitation_probability_max[i] })
        root.lastOk[key] = Date.now()
        root.updatePending()
        root.store(key, {
          error: "", ts: Date.now(), name: g.name, region: g.region || "",
          current: { temp: c.temperature_2m, feels: c.apparent_temperature, humidity: c.relative_humidity_2m,
                     code: c.weather_code, wind: c.wind_speed_10m, isDay: c.is_day === 1,
                     pressure: c.surface_pressure },
          daily: daily
        })
      })
    })
  }


  function check() {
    const due = {}
    for (const id in root.watchers) {
      const w = root.watchers[id]
      due[w.key] = Math.min(due[w.key] ?? Infinity, w.ms)
    }
    const now = Date.now()
    for (const key in due) {
      if (root.inflight[key] || root.dead[key]) continue
      const ok = root.lastOk[key]
      const tried = root.lastTry[key] ?? 0
      const retryOk = now - tried >= (ok ? 120000 : root.backoff(key))
      if (ok ? (now - ok >= due[key] && retryOk) : retryOk) root.fetchKey(key)
    }
  }

  Timer {
    interval: 60000
    running: root.wanted
    repeat: true
    onTriggered: root.check()
  }

  Timer {
    interval: 2000
    running: root.wanted && root.pendingData
    repeat: true
    onTriggered: root.check()
  }

  // ── presentación (compartida por los estilos) ──
  function group(code) {
    if (code === 0) return "clear"
    if (code === 1) return "mostlyClear"
    if (code === 2) return "partly"
    if (code === 3) return "overcast"
    if (code === 45 || code === 48) return "fog"
    if (code >= 51 && code <= 57) return "drizzle"
    if (code === 66 || code === 67) return "freezing"
    if (code >= 61 && code <= 65) return "rain"
    if (code >= 71 && code <= 77) return "snow"
    if (code >= 80 && code <= 82) return "showers"
    if (code === 85 || code === 86) return "snow"
    if (code >= 95) return "thunder"
    return "overcast"
  }
  function describe(code) { return Translations.t("wgWx_" + root.group(code)) }
}
