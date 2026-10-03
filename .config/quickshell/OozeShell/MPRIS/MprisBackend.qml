// MprisBackend — único lugar que lee/controla los reproductores MPRIS.
//
// v2 (optimización): ya NO usa `playerctl`. Lee directo del servicio MPRIS
// nativo de Quickshell (D-Bus, por eventos).
//
// Novedad: si no elegiste un player a mano, se sigue al que está sonando.
//
// OJO (nombres): este directorio define un tipo `Mpris` (Mpris.qml); por eso
// el servicio de Quickshell se importa con alias `QsMpris` para no chocar.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris as QsMpris

Singleton {
  id: root

  // ─── Quién necesita la POSICIÓN (lo único que cuesta) ────────
  property var wanters: ({})
  readonly property bool wanted: Object.keys(root.wanters).length > 0

  function setWanted(who, on) {
    if ((root.wanters[who] === true) === on) return
    const n = Object.assign({}, root.wanters)
    if (on) n[who] = true
    else delete n[who]
    root.wanters = n
  }

  // ─── Players (reactivo: la lista cambia por señales D-Bus) ───
  readonly property var players: QsMpris.Mpris.players.values

  function nameOf(p) {
    return ((p && p.dbusName) || "").replace(/^org\.mpris\.MediaPlayer2\./, "")
  }

  readonly property var activePlayers: root.players.map(p => root.nameOf(p))

  // -1 = automático (el que suena, o el primero); >=0 = elegido a mano
  property int manualIndex: -1
  onPlayersChanged: root.manualIndex = -1

  readonly property int activePlayerIndex: {
    const n = root.players.length
    if (n === 0) return 0
    if (root.manualIndex >= 0 && root.manualIndex < n) return root.manualIndex
    const i = root.players.findIndex(p => p.playbackState === QsMpris.MprisPlaybackState.Playing)
    return i >= 0 ? i : 0
  }

  readonly property var player:
    root.players.length > 0 ? root.players[root.activePlayerIndex] : null

  function currentPlayer() { return root.nameOf(root.player) }

  function selectPlayer(i) {
    const n = root.players.length
    if (n === 0) return
    root.manualIndex = (i + n) % n
    root.syncPosition()
  }

  // ─── Datos del player activo ─────────────────────────────────
  readonly property string currentTitle:  root.player ? (root.player.trackTitle  || "") : ""
  readonly property string currentArtist: root.player ? (root.player.trackArtist || "") : ""
  readonly property string currentArt:    root.player ? String(root.player.trackArtUrl || "") : ""

  readonly property string currentStatus: {
    if (!root.player) return "Stopped"
    switch (root.player.playbackState) {
      case QsMpris.MprisPlaybackState.Playing: return "Playing"
      case QsMpris.MprisPlaybackState.Paused:  return "Paused"
      default:                                 return "Stopped"
    }
  }

  // µs, como devolvía playerctl
  readonly property int currentLength:
    (root.player && root.player.lengthSupported) ? Math.round(root.player.length * 1000000) : 0

  property int currentPosition: 0

  readonly property real progressRatio:
    root.currentLength > 0 ? Math.max(0, Math.min(1, root.currentPosition / root.currentLength)) : 0

  function syncPosition() {
    const p = root.player
    if (!p || !p.positionSupported) { root.currentPosition = 0; return }
    p.positionChanged()   // MPRIS no avisa la posición: se le pide releerla
    root.currentPosition = Math.round(p.position * 1000000)
  }

  // Una lectura al cambiar de player, de estado, de pista, o al pedirse
  onPlayerChanged: root.syncPosition()
  onCurrentStatusChanged: root.syncPosition()
  onCurrentTitleChanged: root.syncPosition()
  onWantedChanged: if (root.wanted) root.syncPosition()

  // Único Timer: solo con alguien mirando Y algo sonando (pausado = 0 trabajo)
  Timer {
    interval: 500
    running: root.wanted && root.currentStatus === "Playing"
    repeat: true
    onTriggered: root.syncPosition()
  }

  // ─── Controles ───────────────────────────────────────────────
  function runCtl(args) {
    const p = root.player
    if (!p || !args || args.length === 0) return
    switch (args[0]) {
      case "play-pause": p.togglePlaying(); break
      case "next":       p.next(); break
      case "previous":   p.previous(); break
      case "position": {
        const secs = parseFloat(args[1])
        if (!isNaN(secs) && p.canSeek && p.positionSupported) {
          p.position = secs
          root.syncPosition()
        }
        break
      }
      default: console.log("MprisBackend: comando no soportado:", args[0])
    }
  }

  // ─── Utilidades (sin cambios) ────────────────────────────────
  function formatTime(us) {
    const s = Math.floor(us / 1000000)
    const m = Math.floor(s / 60)
    const r = s % 60
    return m + ":" + (r < 10 ? "0" : "") + r
  }

  function playerIcon(name) {
    const lower = (name || "").toLowerCase()
    if (lower.includes("spotify")) return "󰓇"
    if (lower.includes("firefox")) return "󰈹"
    if (lower.includes("chrome"))  return "󰊯"
    if (lower.includes("brave"))   return "󰈹"
    if (lower.includes("mpv"))     return "󰚺"
    if (lower.includes("vlc"))     return "󰕼"
    return "󰝚"
  }

  function cleanPlayerName(name) {
    if (!name) return "—"
    let clean = name.split(".")[0]
    clean = clean.split("-")[0]
    return clean.charAt(0).toUpperCase() + clean.slice(1)
  }
}
