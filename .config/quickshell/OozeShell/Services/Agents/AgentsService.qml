pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../COMMON"
import "../../Core/Toml.js" as Toml

Singleton {
  id: root

  readonly property string dir: Quickshell.env("HOME") + "/.config/oozeshell"
  readonly property string file: root.dir + "/agents.toml"
  readonly property string legacyFile: root.dir + "/agents.json"
  readonly property string toolsDir: decodeURIComponent(Qt.resolvedUrl("../../Tools").toString().replace("file://", ""))
  readonly property string secretsScript: root.toolsDir + "/agent-secrets.sh"
  readonly property string askScript: root.toolsDir + "/agent-ask.sh"

  readonly property var agents: [
    { id: "anthropic",  name: "Claude",        kind: "api",   model: "claude-sonnet-5-5", bin: "",       login: [] },
    { id: "openai",     name: "OpenAI",        kind: "api",   model: "gpt-4o-mini",       bin: "",       login: [] },
    { id: "gemini",     name: "Gemini",        kind: "api",   model: "gemini-2.5-flash",  bin: "",       login: [] },
    { id: "openrouter", name: "OpenRouter",    kind: "api",   model: "openrouter/free",   bin: "",       login: [] },
    { id: "groq",       name: "Groq",          kind: "api",   model: "openai/gpt-oss-120b", bin: "",     login: [] },
    { id: "claude-cli", name: "Claude Code",   kind: "cli",   model: "",                  bin: "claude", login: ["claude"] },
    { id: "gemini-cli", name: "Gemini CLI",    kind: "cli",   model: "",                  bin: "gemini", login: ["gemini"] },
    { id: "codex-cli",  name: "Codex",         kind: "cli",   model: "",                  bin: "codex",  login: ["codex", "login"] },
    { id: "ollama",     name: "Ollama",        kind: "local", model: "llama3.2",          bin: "ollama", login: [] }
  ]

  property bool unlocked: false
  property string agent: ""
  property var models: ({})
  property string sizeLevel: "minimal"
  property string fontLevel: "small"
  readonly property var sizeSpecs: ({
    minimal: { w: 280, maxH: 280, minH: 78,  pad: 8,  head: 22, input: 28, glyph: 20, copy: 18, edge: 10, hint: false, radius: 18 },
    compact: { w: 264, maxH: 300, minH: 82,  pad: 8,  head: 22, input: 28, glyph: 20, copy: 18, edge: 10, hint: false, radius: 20 },
    small:   { w: 320, maxH: 420, minH: 140, pad: 10, head: 26, input: 32, glyph: 24, copy: 22, edge: 12, hint: true,  radius: 0 },
    normal:  { w: 400, maxH: 560, minH: 190, pad: 14, head: 30, input: 38, glyph: 28, copy: 24, edge: 16, hint: true,  radius: 0 },
    large:   { w: 480, maxH: 680, minH: 230, pad: 16, head: 34, input: 44, glyph: 32, copy: 28, edge: 18, hint: true,  radius: 0 }
  })
  readonly property var fontSizes: ({ small: 11, normal: 12, large: 14 })
  readonly property var sizeSpec: root.sizeSpecs[root.sizeLevel] ?? root.sizeSpecs.minimal
  readonly property int fontPx: root.fontSizes[root.fontLevel] ?? root.fontSizes.small
  property string systemPrompt: "Responde en el idioma del usuario, de forma clara y breve."
  property bool loaded: false

  property bool open: false
  property string screenName: ""
  property var messages: []
  property bool busy: false

  property var secrets: ({})
  property string backend: ""
  property var installed: ({})
  property string keyMsg: ""
  property string keyMsgFor: ""

  function byId(id) {
    for (const a of root.agents) if (a.id === id) return a
    return null
  }

  readonly property var current: root.byId(root.agent)
  readonly property string currentName: root.current ? root.current.name : ""
  readonly property string currentModel: root.agent !== "" ? root.modelFor(root.agent) : ""

  function modelFor(id) {
    const a = root.byId(id)
    if (!a) return ""
    const m = root.models[id]
    return (typeof m === "string" && m !== "") ? m : a.model
  }

  function isReady(id) {
    const a = root.byId(id)
    if (!a) return false
    if (a.kind === "api") return (root.secrets[id] ?? "none") !== "none"
    if (a.kind === "cli") return root.installed[a.bin] === true
    return root.installed[a.bin] === true
  }

  readonly property bool configured: root.agent !== "" && root.isReady(root.agent)

  function applyConfig(text) {
    let j = {}
    try { j = Toml.parseAny(text) } catch (e) { j = {} }
    root.unlocked = j.unlocked === true
    root.agent = (typeof j.agent === "string" && root.byId(j.agent)) ? j.agent : ""
    const m = {}
    if (j.models && typeof j.models === "object") {
      for (const a of root.agents) {
        const v = j.models[a.id]
        if (typeof v === "string" && /^[A-Za-z0-9._:\/-]{1,100}$/.test(v)) m[a.id] = v
      }
    }
    root.models = m
    root.sizeLevel = (typeof j.sizeLevel === "string" && root.sizeSpecs[j.sizeLevel]) ? j.sizeLevel : "minimal"
    root.fontLevel = (typeof j.fontLevel === "string" && root.fontSizes[j.fontLevel]) ? j.fontLevel : "small"
    if (typeof j.systemPrompt === "string") root.systemPrompt = j.systemPrompt.slice(0, 600)
    root.loaded = true
  }

  FileView {
    id: cfgView
    path: root.file
    onLoaded: root.applyConfig(cfgView.text())
    onLoadFailed: legacyView.path = root.legacyFile
  }

  FileView {
    id: legacyView
    onLoaded: { root.applyConfig(legacyView.text()); root.save() }
    onLoadFailed: root.loaded = true
  }

  Process { id: saveProc }

  function save() {
    const data = Toml.stringify({
      unlocked: root.unlocked,
      agent: root.agent,
      models: root.models,
      systemPrompt: root.systemPrompt,
      sizeLevel: root.sizeLevel,
      fontLevel: root.fontLevel
    })
    saveProc.command = ["bash", "-c",
      "mkdir -p \"$(dirname \"$2\")\" && printf %s \"$1\" > \"$2.tmp\" && mv -f \"$2.tmp\" \"$2\" && { [ -f \"$3\" ] && mv -f \"$3\" \"$3.bak\"; true; }",
      "sh", data, root.file, root.legacyFile]
    saveProc.running = false
    saveProc.running = true
  }

  function setAgent(id) {
    if (!root.byId(id) || id === root.agent) return
    root.agent = id
    root.messages = []
    root.save()
  }

  function setModel(id, value) {
    const v = String(value ?? "").trim()
    if (!root.byId(id)) return
    if (v !== "" && !/^[A-Za-z0-9._:\/-]{1,100}$/.test(v)) return
    const m = Object.assign({}, root.models)
    if (v === "") delete m[id]
    else m[id] = v
    root.models = m
    root.save()
  }

  function setSystemPrompt(value) {
    root.systemPrompt = String(value ?? "").slice(0, 600)
    root.save()
  }

  function setSizeLevel(v) {
    if (!root.sizeSpecs[v] || v === root.sizeLevel) return
    root.sizeLevel = v
    root.save()
  }

  function setFontLevel(v) {
    if (!root.fontSizes[v] || v === root.fontLevel) return
    root.fontLevel = v
    root.save()
  }

  function unlock() { root.unlocked = true; root.save() }
  function lock() { root.unlocked = false; root.save() }

  Process {
    id: secretsProc
    command: ["bash", "-c",
      "S=\"$1\"; for p in anthropic openai gemini openrouter groq; do echo \"$p=$(bash \"$S\" status \"$p\")\"; done; echo \"backend=$(bash \"$S\" backend)\"",
      "sh", root.secretsScript]
    stdout: StdioCollector {
      onStreamFinished: {
        const s = {}
        let b = ""
        for (const line of text.split("\n")) {
          const i = line.indexOf("=")
          if (i < 0) continue
          const k = line.slice(0, i)
          const v = line.slice(i + 1).trim()
          if (k === "backend") b = v
          else s[k] = v
        }
        root.secrets = s
        root.backend = b
      }
    }
  }

  Process {
    id: detectProc
    command: ["bash", root.askScript, "detect"]
    stdout: StdioCollector {
      onStreamFinished: {
        const m = {}
        for (const line of text.split("\n")) {
          const v = line.trim()
          if (v !== "") m[v] = true
        }
        root.installed = m
      }
    }
  }

  function refresh() {
    secretsProc.running = false
    secretsProc.running = true
    detectProc.running = false
    detectProc.running = true
  }

  Component.onCompleted: root.refresh()

  Process {
    id: keyProc
    property string forAgent: ""
    stdout: StdioCollector { id: keyOut }
    onExited: (code) => {
      keyProc.environment = ({})
      root.keyMsgFor = keyProc.forAgent
      if (code === 0) root.keyMsg = keyOut.text.trim() === "keyring" ? "agentsKeySavedKeyring" : "agentsKeySavedFile"
      else if (code === 2) root.keyMsg = "agentsKeyInvalid"
      else if (code === 3) root.keyMsg = "agentsKeyNoBackend"
      else root.keyMsg = "agentsKeyFail"
      root.refresh()
    }
  }

  function saveKey(id, key) {
    const a = root.byId(id)
    if (!a || a.kind !== "api" || keyProc.running) return
    keyProc.forAgent = id
    keyProc.command = ["bash", root.secretsScript, "set", id]
    keyProc.environment = ({ OOZE_AGENT_KEY: String(key) })
    keyProc.running = true
  }

  Process {
    id: removeProc
    onExited: { root.keyMsg = ""; root.refresh() }
  }

  function removeKey(id) {
    const a = root.byId(id)
    if (!a || a.kind !== "api") return
    removeProc.command = ["bash", root.secretsScript, "remove", id]
    removeProc.running = false
    removeProc.running = true
  }

  Process {
    id: askProc
    stdout: StdioCollector {
      id: askOut
      onStreamFinished: root.finishAsk(askOut.text)
    }
    onExited: askProc.environment = ({})
  }

  function pushMessage(role, text, error) {
    root.messages = root.messages.concat([{ role: role, text: text, error: !!error }])
  }

  function ask(text) {
    const q = String(text ?? "").trim()
    if (q === "" || root.busy) return
    if (!root.configured) return
    root.pushMessage("user", q, false)
    const payload = {
      system: root.systemPrompt,
      messages: root.messages.filter(m => !m.error).slice(-12)
        .map(m => ({ role: m.role, content: m.text.slice(0, 8000) }))
    }
    root.busy = true
    askProc.command = ["bash", root.askScript, "ask", root.agent, root.modelFor(root.agent)]
    askProc.environment = ({ OOZE_AGENT_PAYLOAD: JSON.stringify(payload) })
    askProc.running = true
  }

  function finishAsk(out) {
    if (!root.busy) return
    root.busy = false
    let r = null
    try { r = JSON.parse(String(out).trim().split("\n").pop()) } catch (e) { r = null }
    if (r && r.ok === true && typeof r.text === "string") root.pushMessage("assistant", r.text, false)
    else root.pushMessage("assistant", (r && r.error) ? String(r.error) : "Sin respuesta del agente", true)
  }

  function cancel() {
    if (!root.busy) return
    root.busy = false
    askProc.running = false
  }

  function newChat() {
    root.cancel()
    root.messages = []
  }

  function copyText(t) {
    Quickshell.execDetached(["bash", "-c", "printf %s \"$1\" | wl-copy", "sh", String(t)])
  }

  function copyLast() {
    for (let i = root.messages.length - 1; i >= 0; i--) {
      const m = root.messages[i]
      if (m.role === "assistant" && !m.error) { root.copyText(m.text); return true }
    }
    return false
  }

  function openBubble(screen) {
    root.screenName = screen || root.screenName
    root.refresh()
    root.open = true
  }
  function closeBubble() { root.open = false }
  function toggleBubble(screen) {
    if (root.open) root.closeBubble()
    else root.openBubble(screen)
  }

  function openLogin(id) {
    const a = root.byId(id)
    if (!a || a.login.length === 0) return
    Quickshell.execDetached(Theme.terminalCmd.concat(a.login))
  }
}
