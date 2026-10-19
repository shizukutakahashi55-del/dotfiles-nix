// AudioVisualizerWidget — espectro del audio que suena. Estilos: bars · mirror · wave · circular · dots · ribbon · pulse · player

import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Shapes
import QtQuick.Layouts
import ".."
import "../../../COMMON"
import "../../../Services/Mpris"
import "../../../Services/Lang"

WidgetBase {
  id: w

  readonly property string sty: w.widgetStyle
  readonly property bool circ: w.sty === "circular"
  readonly property bool pulse: w.sty === "pulse"
  readonly property bool player: w.sty === "player"
  readonly property bool showBg: w.opt("background", false)
  readonly property real bgAlpha: Math.max(0, Math.min(100, Number(w.opt("bgOpacity", 50)))) / 100
  readonly property bool showCover: w.opt("cover", false)
  readonly property bool showTitle: w.opt("title", false)
  readonly property bool onlyPlaying: w.opt("onlyWhenPlaying", true)

  readonly property bool playing: MprisBackend.currentStatus === "Playing"
  readonly property bool wantAudio: w.widgetId !== "" && (!w.onlyPlaying || w.playing)
  readonly property bool live: w.wantAudio && AudioLevels.available && !AudioLevels.silent
  readonly property int n: AudioLevels.bars

  // ── ciclo de vida de cava ──
  property string _key: ""
  onWantAudioChanged: {
    if (w.widgetId !== "") w._key = "widget-" + w.widgetId
    if (w._key !== "") AudioLevels.setWanted(w._key, w.wantAudio)
    w.noData = false
    if (w.wantAudio) grace.restart(); else grace.stop()
  }
  readonly property string posKey: w.widgetId === "" ? "" : "audio-" + w.widgetId
  readonly property bool wantPos: w.posKey !== "" && w.player
  onWantPosChanged: MprisBackend.setWanted(w.posKey, w.wantPos)
  Component.onDestruction: {
    if (w._key !== "") AudioLevels.setWanted(w._key, false)
    if (w.posKey !== "") MprisBackend.setWanted(w.posKey, false)
  }


  property bool noData: false
  Timer { id: grace; interval: 3500; onTriggered: w.noData = !AudioLevels.available }
  Connections { target: AudioLevels; function onAvailableChanged() { if (AudioLevels.available) w.noData = false } }

  // ── suavizado (UN bucle; se detiene cuando todo está asentado) ──
  property var shown: []
  property bool settled: true
  property real acc: 0
  FrameAnimation {
    running: w.live || !w.settled
    onTriggered: {
      w.acc += frameTime * 1000
      if (w.acc < 1000 / AudioLevels.fps) return
      const dt = w.acc
      w.acc = 0
      w.step(dt)
    }
  }
  function step(dtMs) {
    const n = w.n
    const src = w.live ? AudioLevels.bands : []
    const ka = 1 - Math.exp(-dtMs / 45)
    const kr = 1 - Math.exp(-dtMs / 130)
    const prev = w.shown
    const out = new Array(n)
    let moving = false
    for (let i = 0; i < n; i++) {
      const p = i < prev.length ? prev[i] : 0
      const t = i < src.length ? src[i] : 0
      let v = p + (t - p) * (t > p ? ka : kr)
      if (Math.abs(t - v) < 0.003) v = t
      if (v !== t) moving = true
      out[i] = v
    }
    w.shown = out
    w.settled = !moving && !w.live
  }
  function val(i) { const v = w.shown[i]; return v === undefined ? 0 : v }
  function groupVal(g) {
    const n = w.n
    const a = Math.floor(g * n / 3)
    const b = Math.max(a + 1, Math.floor((g + 1) * n / 3))
    let sum = 0
    for (let i = a; i < b; i++) sum += w.val(i)
    return sum / (b - a)
  }

  // ── paleta ──
  function shifted(c, d) {
    const h = c.hslHue < 0 ? 0 : c.hslHue
    return Qt.hsla((h + d + 1) % 1, Math.max(0.35, c.hslSaturation),
                   Math.max(0.5, Math.min(0.72, c.hslLightness)), 1)
  }
  function mix(a, b, t) { return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1) }
  readonly property color toneA: Theme.primary
  readonly property color toneB: w.shifted(Theme.primary, 0.12)
  readonly property color toneC: w.shifted(Theme.primary, -0.12)

  // ── fondo (misma tarjeta que el resto del shell: OozeSoft / CoOzey) ──
  WidgetCard {
    anchors.fill: parent
    visible: w.showBg || w.player
    alpha: w.bgAlpha
  }

  // ── franja superior: portada + título (no circular: ahí la portada va al centro) ──
  readonly property bool hasInfo: MprisBackend.currentTitle !== ""
  readonly property bool stripOn: (w.showTitle || (w.showCover && !w.circ)) && w.hasInfo && !w.player
  Item {
    id: strip
    visible: w.stripOn
    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
    height: w.stripOn ? 36 : 0

    ClippingRectangle {
      id: coverSm
      visible: w.showCover && !w.circ
      width: visible ? 36 : 0
      height: 36
      radius: Theme.cozy ? 2 : 8
      color: Theme.surface
      Image {
        anchors.fill: parent
        source: coverSm.visible ? MprisBackend.currentArt : ""
        sourceSize: Qt.size(96, 96)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
      }
    }
    Column {
      visible: w.showTitle
      anchors { left: coverSm.visible ? coverSm.right : parent.left; leftMargin: coverSm.visible ? 10 : 0
                right: parent.right; verticalCenter: parent.verticalCenter }
      Text {
        width: parent.width
        text: MprisBackend.currentTitle
        color: Theme.text
        elide: Text.ElideRight
        font.bold: true
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fs(12)
      }
      Text {
        width: parent.width
        visible: MprisBackend.currentArtist !== ""
        text: MprisBackend.currentArtist
        color: Theme.subtext
        elide: Text.ElideRight
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fs(10)
      }
    }
  }

  // ── zona de dibujo ──
  Item {
    id: viz
    anchors {
      left: parent.left; right: parent.right; bottom: parent.bottom
      top: strip.bottom
      margins: 12
      topMargin: w.stripOn ? 6 : 12
    }


    Repeater {
      model: (w.sty === "bars" || w.sty === "mirror") ? w.n : 0
      delegate: Rectangle {
        required property int index
        readonly property real slot: viz.width / w.n
        readonly property real v: w.val(index)
        readonly property real gap: Math.max(2, slot * 0.25)
        x: index * slot + gap / 2
        width: Math.max(2, slot - gap)
        height: Math.max(3, Math.round(v * viz.height))
        y: w.sty === "mirror" ? Math.round((viz.height - height) / 2) : viz.height - height
        radius: Theme.cozy ? 0 : Math.min(width / 2, 4)
        color: Theme.primary
        opacity: 0.5 + 0.5 * v
      }
    }


    readonly property int cells: Math.max(3, Math.floor(viz.height / 11))
    Repeater {
      model: w.sty === "dots" ? w.n * viz.cells : 0
      delegate: Rectangle {
        required property int index
        readonly property int band: Math.floor(index / viz.cells)
        readonly property int cell: index % viz.cells
        readonly property real slot: viz.width / w.n
        readonly property real cellH: viz.height / viz.cells
        readonly property real d: Math.max(2, Math.min(slot * 0.7, cellH * 0.7))
        readonly property bool lit: cell < Math.round(w.val(band) * viz.cells)
        width: d; height: d; radius: Theme.cozy ? 0 : d / 2
        x: band * slot + (slot - d) / 2
        y: viz.height - (cell + 1) * cellH + (cellH - d) / 2
        color: Theme.primary
        opacity: lit ? 1 : 0.12
      }
    }


    readonly property real rad: Math.min(viz.width, viz.height) / 2
    readonly property real inner: viz.rad * 0.46
    Repeater {
      model: w.circ ? w.n * 2 : 0
      delegate: Item {
        required property int index
        readonly property int band: index < w.n ? index : (w.n * 2 - 1 - index)
        readonly property real v: w.val(band)
        x: viz.width / 2
        y: viz.height / 2
        width: 0; height: 0
        rotation: (index + 0.5) * 360 / (w.n * 2)
        Rectangle {
          width: Math.max(2, 2 * Math.PI * viz.inner / (w.n * 2) * 0.6)
          height: Math.max(3, v * (viz.rad - viz.inner))
          x: -width / 2
          y: -(viz.inner + height)
          radius: width / 2
          color: Theme.primary
          opacity: 0.5 + 0.5 * v
        }
      }
    }
    ClippingRectangle {
      visible: w.circ
      anchors.centerIn: parent
      width: Math.max(10, (viz.inner - 6) * 2)
      height: width
      radius: width / 2
      color: Theme.surface
      Image {
        anchors.fill: parent
        source: (w.circ && w.showCover) ? MprisBackend.currentArt : ""
        sourceSize: Qt.size(160, 160)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
      }
      Text {
        anchors.centerIn: parent
        visible: !w.showCover || MprisBackend.currentArt === ""
        text: "󰎆"
        color: Theme.subtext
        font.family: Theme.monoFamily
        font.pixelSize: parent.width * 0.4
      }
    }


    function wavePoints() {
      const W = viz.width, H = viz.height, n = w.n, steps = 4
      const pts = [Qt.point(0, H)]
      for (let i = 0; i < n - 1; i++) {
        const a = w.val(i), b = w.val(i + 1)
        for (let k = 0; k < steps; k++) {
          const t = k / steps
          const m = (1 - Math.cos(t * Math.PI)) / 2
          const v = a + (b - a) * m
          pts.push(Qt.point(((i * steps + k) / ((n - 1) * steps)) * W, H - 1 - v * (H - 3)))
        }
      }
      pts.push(Qt.point(W, H - 1 - w.val(n - 1) * (H - 3)))
      pts.push(Qt.point(W, H))
      return pts
    }
    Shape {
      visible: w.sty === "wave"
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer
      ShapePath {
        strokeColor: Theme.primary
        strokeWidth: 2
        joinStyle: ShapePath.RoundJoin
        fillColor: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.22)
        PathPolyline { path: w.sty === "wave" ? viz.wavePoints() : [] }
      }
    }

    function ribbonPoints(k) {
      const W = viz.width, H = viz.height, n = w.n, steps = 4, mid = H / 2
      const top = [], bot = []
      for (let i = 0; i < n - 1; i++) {
        const a = w.val(i), b = w.val(i + 1)
        for (let q = 0; q < steps; q++) {
          const t = q / steps
          const m = (1 - Math.cos(t * Math.PI)) / 2
          const v = (a + (b - a) * m) * k
          const x = ((i * steps + q) / ((n - 1) * steps)) * W
          top.push(Qt.point(x, mid - v * (mid - 2)))
          bot.push(Qt.point(x, mid + v * (mid - 2)))
        }
      }
      const lv = w.val(n - 1) * k
      top.push(Qt.point(W, mid - lv * (mid - 2)))
      bot.push(Qt.point(W, mid + lv * (mid - 2)))
      return top.concat(bot.reverse())
    }
    Shape {
      visible: w.sty === "ribbon"
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer
      ShapePath {
        strokeColor: Qt.alpha(w.toneC, 0.9)
        strokeWidth: 1.5
        joinStyle: ShapePath.RoundJoin
        fillColor: Qt.alpha(w.toneC, 0.14)
        PathPolyline { path: w.sty === "ribbon" ? viz.ribbonPoints(1.0) : [] }
      }
      ShapePath {
        strokeColor: Qt.alpha(w.toneB, 0.9)
        strokeWidth: 1.5
        joinStyle: ShapePath.RoundJoin
        fillColor: Qt.alpha(w.toneB, 0.2)
        PathPolyline { path: w.sty === "ribbon" ? viz.ribbonPoints(0.66) : [] }
      }
      ShapePath {
        strokeColor: Qt.alpha(w.toneA, 0.95)
        strokeWidth: 1.5
        joinStyle: ShapePath.RoundJoin
        fillColor: Qt.alpha(w.toneA, 0.3)
        PathPolyline { path: w.sty === "ribbon" ? viz.ribbonPoints(0.34) : [] }
      }
    }

    Repeater {
      model: w.pulse ? 3 : 0
      delegate: Rectangle {
        required property int index
        readonly property real v: w.groupVal(index)
        anchors.centerIn: parent
        width: Math.max(4, viz.rad * (0.5 + 0.17 * index) * (0.9 + 0.12 * v) * 2)
        height: width
        radius: width / 2
        color: "transparent"
        border.width: 1.5 + 4 * v
        border.color: index === 0 ? w.toneA : (index === 1 ? w.toneB : w.toneC)
        opacity: 0.2 + 0.8 * v
      }
    }
    ClippingRectangle {
      visible: w.pulse
      anchors.centerIn: parent
      width: Math.max(10, viz.rad * 0.68 * (1 + 0.16 * w.groupVal(0)))
      height: width
      radius: width / 2
      color: Theme.surface
      Image {
        anchors.fill: parent
        source: (w.pulse && w.showCover) ? MprisBackend.currentArt : ""
        sourceSize: Qt.size(160, 160)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
      }
      Text {
        anchors.centerIn: parent
        visible: !w.showCover || MprisBackend.currentArt === ""
        text: "󰎆"
        color: Theme.subtext
        font.family: Theme.monoFamily
        font.pixelSize: parent.width * 0.4
      }
    }
  }

  // ── player ──
  Item {
    id: pl
    visible: w.player
    anchors { fill: parent; margins: 14 }
    readonly property real cs: Math.max(24, Math.min(pl.height, Math.round(pl.width * 0.3)))

    ClippingRectangle {
      id: plCover
      width: pl.cs
      height: pl.cs
      anchors.verticalCenter: parent.verticalCenter
      radius: Theme.cozy ? 3 : Math.round(pl.cs * 0.16)
      color: Theme.surface
      Image {
        anchors.fill: parent
        source: w.player ? MprisBackend.currentArt : ""
        sourceSize: Qt.size(192, 192)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
      }
      Text {
        anchors.centerIn: parent
        visible: MprisBackend.currentArt === ""
        text: "󰎆"
        color: Theme.subtext
        font.family: Theme.monoFamily
        font.pixelSize: Math.round(pl.cs * 0.4)
      }
    }

    ColumnLayout {
      anchors { left: plCover.right; leftMargin: 14; right: parent.right; top: parent.top; bottom: parent.bottom }
      spacing: 3

      Text {
        Layout.fillWidth: true
        elide: Text.ElideRight
        text: MprisBackend.currentTitle !== "" ? MprisBackend.currentTitle : Translations.t("wgAvNoTrack")
        color: Theme.text
        font.bold: true
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fs(14)
      }
      Text {
        Layout.fillWidth: true
        elide: Text.ElideRight
        visible: MprisBackend.currentArtist !== ""
        text: MprisBackend.currentArtist
        color: Theme.subtext
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fs(11)
      }
      Item {
        id: plViz
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 10

        Repeater {
          model: w.player ? w.n : 0
          delegate: Rectangle {
            required property int index
            readonly property real slot: plViz.width / w.n
            readonly property real v: w.val(index)
            readonly property real gap: Math.max(2, slot * 0.3)
            x: index * slot + gap / 2
            width: Math.max(2, slot - gap)
            height: Math.max(3, Math.round(v * plViz.height))
            y: plViz.height - height
            radius: Theme.cozy ? 0 : Math.min(width / 2, 3)
            color: w.mix(w.toneA, w.toneC, w.n > 1 ? index / (w.n - 1) : 0)
            opacity: 0.55 + 0.45 * v
          }
        }
      }
      RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Text {
          text: MprisBackend.formatTime(MprisBackend.currentPosition)
          color: Theme.subtext
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fs(10)
        }
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: 4
          radius: 2
          color: Qt.alpha(Theme.subtext, 0.28)
          Rectangle {
            width: parent.width * MprisBackend.progressRatio
            height: parent.height
            radius: 2
            color: Theme.primary
          }
        }
        Text {
          text: MprisBackend.formatTime(MprisBackend.currentLength)
          color: Theme.subtext
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fs(10)
        }
      }
    }
  }

  // ── avisos ──
  Text {
    visible: w.noData && w.wantAudio
    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 6 }
    text: Translations.t("wgAvNoCava")
    color: Theme.subtext
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fs(9)
  }
}
