import QtQuick
import QtQuick.Shapes
import "../COMMON"

// ─────────────────────────────────────────────────────────────────
// MprisWaves — ondas de fondo del reproductor. Va en el `backdrop` del
// FusedPanel de Mpris (que ya lo recorta con la silueta del panel), del
// tamaño del cuerpo, y se coloca en el lado lejano a la barra.
//
// Sin datos de audio (cava ausente, o `reactive: false`) las ondas siguen
// avanzando y "respirando" como antes.
// ─────────────────────────────────────────────────────────────────
Item {
  id: root
  clip: true
  // Barra abajo → el lado lejano es ARRIBA: se voltea la caja
  rotation: root.flip ? 180 : 0

  // Mpris: panel visible (incluye la animación de cierre)
  property bool running: false
  // Mpris: el player está en "Playing"
  property bool playing: false
  // Escala de ventanas (FusedPanel.scaleFactor): el fondo va en px reales
  property real sf: 1
  property bool flip: false
  // Reaccionar al audio
  property bool reactive: true

  // Hay datos de audio llegando Y hay sonido
  readonly property bool live: root.reactive && root.playing
    && AudioLevels.available && !AudioLevels.silent

  // ─── Geometría de las ondas ─────────────────────────────────
  // Sinusoide armada con medias parábolas (Q) que alternan cresta/valle: la
  // pendiente es continua en cada unión. Se dibuja alrededor de la línea
  // y = y0. La forma cubre `w + period`: un periodo de más, que es lo que se
  // desplaza en bucle.
  function waveHumps(w, period) {
    if (period < 1 || w <= 0) return 0
    return Math.min(200, Math.ceil((w + period) / (period / 2)))
  }
  function waveEnd(w, period) { return root.waveHumps(w, period) * period / 2 }
  function waveLine(w, period, amp, y0) {
    const n = root.waveHumps(w, period)
    if (n === 0) return ""
    const half = period / 2
    let p = "M 0 " + y0.toFixed(2)
    for (let i = 0; i < n; i++) {
      const x0 = i * half
      const cy = y0 + (i % 2 === 0 ? -2 * amp : 2 * amp)
      p += " Q " + (x0 + half / 2).toFixed(2) + " " + cy.toFixed(2)
         + " " + (x0 + half).toFixed(2) + " " + y0.toFixed(2)
    }
    return p
  }

  // ─── Geometría del espectro ─────────────────────────────────
  // Puntos (espejados: graves en el centro, con las puntas atenuadas) y
  // curva suave por ellos (Catmull-Rom → Bézier cúbica).
  function spectrumLine(bands, w, h, rise, span) {
    const n = bands.length
    if (n < 2 || w <= 0 || h <= 0) return ""
    const m = n * 2
    const pts = []
    for (let k = 0; k < m; k++) {
      const b = k < n ? bands[n - 1 - k] : bands[k - n]
      const win = Math.pow(Math.sin(Math.PI * (k + 0.5) / m), 0.5)
      const v = Math.max(0, Math.min(1, b)) * win
      pts.push({ x: k * w / (m - 1), y: h - rise - v * span })
    }
    const cl = v => Math.max(0, Math.min(h, v))
    let p = "M " + pts[0].x.toFixed(1) + " " + pts[0].y.toFixed(1)
    for (let i = 0; i < m - 1; i++) {
      const p0 = pts[Math.max(0, i - 1)], p1 = pts[i]
      const p2 = pts[i + 1], p3 = pts[Math.min(m - 1, i + 2)]
      p += " C " + (p1.x + (p2.x - p0.x) / 6).toFixed(1) + " " + cl(p1.y + (p2.y - p0.y) / 6).toFixed(1)
         + " " + (p2.x - (p3.x - p1.x) / 6).toFixed(1) + " " + cl(p2.y - (p3.y - p1.y) / 6).toFixed(1)
         + " " + p2.x.toFixed(1) + " " + p2.y.toFixed(1)
    }
    return p
  }

  // ─── Capas sinusoidales ─────────────────────────────────────
  Repeater {
    visible: !Theme.cozy
    model: [
      // period/amp/rise en px lógicos; rise = altura de la línea media sobre
      // el borde; dur = ms por periodo; dir = sentido; zone = 0 graves,
      // 1 medios, 2 agudos; gain = cuánto crece la cresta con el sonido
      { period: 320, amp: 8, rise: 74, alpha: 0.08, stroke: 0.0,  dur: 16000, dir: -1, breath: 4200, zone: 0, gain: 1.2 },
      { period: 230, amp: 7, rise: 52, alpha: 0.10, stroke: 0.22, dur: 11000, dir:  1, breath: 3300, zone: 1, gain: 1.3 },
      { period: 180, amp: 5, rise: 32, alpha: 0.13, stroke: 0.30, dur:  8000, dir: -1, breath: 2700, zone: 2, gain: 1.6 }
    ]

    delegate: Item {
      id: wv
      required property var modelData

      readonly property real period: modelData.period * root.sf
      readonly property real amp: modelData.amp * root.sf
      readonly property real rise: modelData.rise * root.sf

      // Cuánto sube la cresta con el sonido (0..1 de la zona) y su tope
      readonly property real punch: root.live ? AudioLevels.zones[modelData.zone] : 0
      readonly property real ampCap: amp * (0.65 + modelData.gain) * 1.1
      readonly property real y0: ampCap + 2

      // Amplitud base: viva al sonar, baja al pausar
      property real level: root.playing ? 0.65 : 0.4
      Behavior on level { NumberAnimation { duration: Theme.animDuration(700); easing.type: Easing.InOutSine } }
      // Respiro lento (lo único que queda si no hay datos de audio)
      property real breath: 1.0
      SequentialAnimation on breath {
        running: (!Theme.cozy && root.running && root.playing) && Theme.uiAnimationsEnabled
        loops: Animation.Infinite
        NumberAnimation { to: 1.06; duration: Theme.animDuration(wv.modelData.breath); easing.type: Easing.InOutSine }
        NumberAnimation { to: 0.94; duration: Theme.animDuration(wv.modelData.breath); easing.type: Easing.InOutSine }
      }
      readonly property real ampNow:
        Math.min(ampCap, amp * (level + modelData.gain * punch) * breath)

      readonly property string line: root.waveLine(width, period, ampNow, y0)
      readonly property color fillCol: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b,
                                               modelData.alpha * (1 + 0.6 * punch))
      readonly property color strokeCol: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b,
                                                 modelData.stroke * (1 + 0.5 * punch))

      // Más ancha que el panel un periodo completo (el que se desplaza)
      width: root.width + period
      height: rise + y0
      y: root.height - height

      property real phase: 0
      x: modelData.dir > 0 ? -period * (1 - phase) : -period * phase
      NumberAnimation on phase {
        from: 0; to: 1
        duration: Theme.animDuration(wv.modelData.dur)
        loops: Animation.Infinite
        running: (!Theme.cozy && root.running) && Theme.uiAnimationsEnabled
        paused: !root.playing
      }

      Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        // Relleno (las capas se acumulan: más denso hacia el borde)
        ShapePath {
          fillColor: wv.fillCol
          strokeWidth: -1
          strokeColor: "transparent"
          PathSvg {
            path: wv.line === "" ? ""
              : wv.line
                + " L " + root.waveEnd(wv.width, wv.period).toFixed(2)
                + " " + wv.height.toFixed(2)
                + " L 0 " + wv.height.toFixed(2) + " Z"
          }
        }

        // Hilo de la cresta
        ShapePath {
          fillColor: "transparent"
          strokeColor: wv.strokeCol
          strokeWidth: wv.modelData.stroke > 0 ? 1.5 : -1
          capStyle: ShapePath.RoundCap
          PathSvg { path: wv.modelData.stroke > 0 ? wv.line : "" }
        }
      }
    }
  }

  // ─── Espectro (delante de todo) ─────────────────────────────
  Item {
    id: spec

    readonly property real rise: 16 * root.sf
    readonly property real span: 54 * root.sf
    readonly property string line:
      spec.visible ? root.spectrumLine(AudioLevels.bands, width, height, rise, span) : ""

    width: root.width
    height: rise + span + 2
    y: root.height - height

    // Solo con sonido: en silencio o en pausa se desvanece
    opacity: root.live ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.animDuration(450); easing.type: Easing.InOutSine } }
    visible: !Theme.cozy && opacity > 0.01

    Shape {
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer

      ShapePath {
        fillColor: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16)
        strokeWidth: -1
        strokeColor: "transparent"
        PathSvg {
          path: spec.line === "" ? ""
            : spec.line + " L " + spec.width.toFixed(1) + " " + spec.height.toFixed(1)
              + " L 0 " + spec.height.toFixed(1) + " Z"
        }
      }

      ShapePath {
        fillColor: "transparent"
        strokeColor: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.55)
        strokeWidth: 1.5
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
        PathSvg { path: spec.line }
      }
    }
  }

  // ─── CoOzey: colinas de píxeles ─────────────────────────────
  // Tres terrazas escalonadas (columnas de `cw` px con alturas redondeadas a
  // 4 px) que avanzan a saltos (~7 fps, como un sprite) y suben con el sonido:
  // graves la de atrás, agudos la de adelante. Cada columna lleva una tapa
  // clara de 2 px, como el borde de pasto de un juego de granja.
  Item {
    id: cozyLayer
    anchors.fill: parent
    visible: Theme.cozy
    property int tick: 0
    readonly property int cw: Math.max(6, Math.round(8 * root.sf))
    readonly property int step: 4

    Timer {
      interval: 140; repeat: true
      running: Theme.cozy && root.running && root.playing
      onTriggered: cozyLayer.tick++
    }

    Repeater {
      model: [
        // base/amp/alpha en px lógicos; k = frecuencia espacial; dir = sentido
        { base: 50, amp: 8, alpha: 0.10, k: 0.22, dir:  1, zone: 0, gain: 26 },
        { base: 34, amp: 7, alpha: 0.14, k: 0.31, dir: -1, zone: 1, gain: 22 },
        { base: 18, amp: 5, alpha: 0.20, k: 0.43, dir:  1, zone: 2, gain: 18 }
      ]
      delegate: Item {
        id: hill
        required property var modelData
        required property int index
        anchors.fill: parent
        readonly property real punch: root.live ? AudioLevels.zones[modelData.zone] : 0

        Repeater {
          model: Theme.cozy ? Math.ceil(root.width / cozyLayer.cw) + 1 : 0
          delegate: Item {
            id: col
            required property int index
            readonly property real raw: (hill.modelData.base
              + hill.modelData.amp * Math.sin(index * hill.modelData.k
                  + cozyLayer.tick * 0.35 * hill.modelData.dir + hill.index * 1.7)
              + hill.modelData.gain * hill.punch) * root.sf
            readonly property int h: Math.max(cozyLayer.step,
              Math.round(col.raw / cozyLayer.step) * cozyLayer.step)
            x: index * cozyLayer.cw
            width: cozyLayer.cw
            y: root.height - h
            height: h
            Rectangle {
              anchors.fill: parent
              gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, hill.modelData.alpha * 1.6) }
                GradientStop { position: 1.0; color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, hill.modelData.alpha * 0.5) }
              }
            }
            Rectangle {
              width: parent.width; height: 2
              color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, hill.modelData.alpha * 2.6)
            }
          }
        }
      }
    }
  }
}
