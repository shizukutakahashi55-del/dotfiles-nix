// LockMedia

import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import "../../COMMON"
import "../../Services/Lang"
import "../../Services/Mpris"

SkinRect {
  id: root

  property real unit: 1
  property bool active: true
  property bool showCover: true
  property bool onlyPlaying: false
  property string look: "player"
  property bool visualizer: true
  property int cardWidth: Math.round(420 * root.unit)

  // ── Estado ──
  readonly property bool hasPlayer: MprisBackend.activePlayers.length > 0
  readonly property bool playing: MprisBackend.currentStatus === "Playing"
  readonly property bool hasSong: MprisBackend.currentTitle !== "" || MprisBackend.currentArtist !== ""
  readonly property bool ready: root.hasPlayer && root.hasSong && (!root.onlyPlaying || root.playing)
  readonly property bool modern: root.look === "player"
  readonly property bool spectrum: root.modern && root.visualizer

  // ── Espectro ──
  readonly property int n: AudioLevels.bars
  readonly property bool live: root.spectrum && root.ready && root.playing && AudioLevels.available && !AudioLevels.silent
  property var shown: []
  property bool settled: true

  FrameAnimation {
    running: root.spectrum && (root.live || !root.settled)
    onTriggered: root.step(frameTime * 1000)
  }

  function step(dtMs) {
    const n = root.n
    const src = root.live ? AudioLevels.bands : []
    const ka = 1 - Math.exp(-dtMs / 45)
    const kr = 1 - Math.exp(-dtMs / 130)
    const prev = root.shown
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
    root.shown = out
    root.settled = !moving && !root.live
  }
  function val(i) { const v = root.shown[i]; return v === undefined ? 0 : v }

  // ── Paleta ──
  function shifted(c, d) {
    const h = c.hslHue < 0 ? 0 : c.hslHue
    return Qt.hsla((h + d + 1) % 1, Math.max(0.35, c.hslSaturation),
                   Math.max(0.5, Math.min(0.72, c.hslLightness)), 1)
  }
  function mix(a, b, t) { return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1) }
  readonly property color toneA: Theme.primary
  readonly property color toneC: root.shifted(Theme.primary, -0.12)

  // ── Geometría ──
  readonly property int pad: Math.round(16 * root.unit)
  readonly property int coverSize: Math.round((root.modern ? 124 : 72) * root.unit)

  implicitWidth: root.cardWidth
  implicitHeight: (root.modern ? player.implicitHeight : body.implicitHeight) + root.pad * 2

  radius: Theme.cardRadius
  color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.55)
  border.width: 1
  border.color: Qt.rgba(1, 1, 1, 0.14)

  visible: opacity > 0
  opacity: root.active && root.ready ? 1 : 0
  Behavior on opacity { NumberAnimation { duration: Theme.animDuration(280); easing.type: Easing.OutCubic } }

  function glyph(cp) { return String.fromCodePoint(cp) }

  // ── Reproductor ──
  RowLayout {
    id: player
    visible: root.modern
    anchors { left: parent.left; right: parent.right; top: parent.top; margins: root.pad }
    spacing: Math.round(14 * root.unit)

    ClippingRectangle {
      visible: root.showCover
      Layout.preferredWidth: root.coverSize
      Layout.preferredHeight: root.coverSize
      Layout.alignment: Qt.AlignVCenter
      radius: Theme.cozy ? 3 : Math.round(root.coverSize * 0.16)
      color: Theme.surface

      Image {
        anchors.fill: parent
        source: root.modern ? MprisBackend.currentArt : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        sourceSize: Qt.size(256, 256)
      }
      Text {
        anchors.centerIn: parent
        visible: MprisBackend.currentArt === ""
        text: root.glyph(0xF075A)
        color: Theme.subtext
        font.pixelSize: Math.round(root.coverSize * 0.4)
        font.family: Theme.monoFamily
      }
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: MprisBackend.runCtl(["play-pause"])
      }
    }

    ColumnLayout {
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignVCenter
      spacing: Math.round(4 * root.unit)

      // ── Título y artista ──
      Text {
        Layout.fillWidth: true
        text: MprisBackend.currentTitle !== "" ? MprisBackend.currentTitle : Translations.t("mprisNoPlaying")
        color: Theme.text
        font.pixelSize: Math.round(16 * root.unit)
        font.bold: true
        font.family: Theme.fontFamily
        elide: Text.ElideRight
      }
      Text {
        Layout.fillWidth: true
        visible: MprisBackend.currentArtist !== ""
        text: MprisBackend.currentArtist
        color: Theme.subtext
        font.pixelSize: Math.round(12 * root.unit)
        font.family: Theme.fontFamily
        elide: Text.ElideRight
      }

      // ── Barras del espectro ──
      Item {
        id: viz
        visible: root.spectrum
        Layout.fillWidth: true
        Layout.preferredHeight: Math.round(34 * root.unit)

        Repeater {
          model: root.spectrum ? root.n : 0

          delegate: Rectangle {
            required property int index
            readonly property real slot: viz.width / root.n
            readonly property real v: root.val(index)
            readonly property real gap: Math.max(2, slot * 0.3)
            x: index * slot + gap / 2
            width: Math.max(2, slot - gap)
            height: Math.max(3, Math.round(v * viz.height))
            y: viz.height - height
            radius: Theme.cozy ? 0 : Math.min(width / 2, 3)
            color: root.mix(root.toneA, root.toneC, root.n > 1 ? index / (root.n - 1) : 0)
            opacity: 0.55 + 0.45 * v
          }
        }
      }

      // ── Controles ──
      LockControls {
        Layout.alignment: Qt.AlignHCenter
        unit: root.unit
        shrink: 0.85
        playing: root.playing
      }

      // ── Progreso ──
      RowLayout {
        Layout.fillWidth: true
        spacing: Math.round(8 * root.unit)

        Text {
          text: MprisBackend.formatTime(MprisBackend.currentPosition)
          color: Theme.subtext
          font.pixelSize: Math.round(11 * root.unit)
          font.family: Theme.fontFamily
        }

        Item {
          Layout.fillWidth: true
          Layout.preferredHeight: Math.round(16 * root.unit)

          Rectangle {
            id: pTrack
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: pSeek.containsMouse ? Math.round(6 * root.unit) : Math.round(4 * root.unit)
            radius: height / 2
            color: Qt.alpha(Theme.subtext, 0.28)
            Behavior on height { NumberAnimation { duration: Theme.animDuration(100) } }

            Rectangle {
              width: pTrack.width * MprisBackend.progressRatio
              height: parent.height
              radius: parent.radius
              color: Theme.primary
            }
          }

          MouseArea {
            id: pSeek
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
              if (MprisBackend.currentLength <= 0) return
              const pos = (mouse.x / width) * MprisBackend.currentLength
              MprisBackend.runCtl(["position", (pos / 1000000).toFixed(2)])
            }
          }
        }

        Text {
          text: MprisBackend.formatTime(MprisBackend.currentLength)
          color: Theme.subtext
          font.pixelSize: Math.round(11 * root.unit)
          font.family: Theme.fontFamily
        }
      }
    }
  }

  // ── Clásico ──
  ColumnLayout {
    id: body
    visible: !root.modern
    anchors { left: parent.left; right: parent.right; top: parent.top; margins: root.pad }
    spacing: Math.round(12 * root.unit)

    RowLayout {
      Layout.fillWidth: true
      spacing: Math.round(14 * root.unit)

      // ── Portada ──
      ClippingRectangle {
        visible: root.showCover
        Layout.preferredWidth: root.coverSize
        Layout.preferredHeight: root.coverSize
        Layout.alignment: Qt.AlignVCenter
        radius: Theme.cozy ? 4 : Math.round(12 * root.unit)
        color: Theme.surfaceHigh

        Image {
          id: art
          anchors.fill: parent
          source: root.modern ? "" : MprisBackend.currentArt
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          smooth: true
          sourceSize: Qt.size(256, 256)
        }
        Text {
          anchors.centerIn: parent
          visible: art.status !== Image.Ready
          text: root.glyph(0xF075A)
          color: Theme.primary
          font.pixelSize: Math.round(30 * root.unit)
          font.family: Theme.monoFamily
        }
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: MprisBackend.runCtl(["play-pause"])
        }
      }

      // ── Título y artista ──
      ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        spacing: Math.round(2 * root.unit)

        Text {
          Layout.fillWidth: true
          text: MprisBackend.currentTitle !== "" ? MprisBackend.currentTitle : Translations.t("mprisNoPlaying")
          color: Theme.text
          font.pixelSize: Math.round(16 * root.unit)
          font.bold: true
          font.family: Theme.fontFamily
          elide: Text.ElideRight
        }
        Text {
          Layout.fillWidth: true
          text: MprisBackend.currentArtist !== "" ? MprisBackend.currentArtist : "—"
          color: Theme.subtext
          font.pixelSize: Math.round(13 * root.unit)
          font.family: Theme.fontFamily
          elide: Text.ElideRight
        }
        Text {
          Layout.fillWidth: true
          visible: MprisBackend.activePlayers.length > 0
          text: MprisBackend.cleanPlayerName(MprisBackend.currentPlayer())
          color: Theme.primary
          font.pixelSize: Math.round(11 * root.unit)
          font.bold: true
          font.family: Theme.fontFamily
          elide: Text.ElideRight
        }
      }
    }

    // ── Progreso ──
    RowLayout {
      Layout.fillWidth: true
      spacing: Math.round(10 * root.unit)

      Text {
        Layout.preferredWidth: Math.round(38 * root.unit)
        text: MprisBackend.formatTime(MprisBackend.currentPosition)
        color: Theme.subtext
        font.pixelSize: Math.round(11 * root.unit)
        font.family: Theme.fontFamily
      }

      Item {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.round(16 * root.unit)

        Rectangle {
          id: track
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width
          height: seek.containsMouse ? Math.round(6 * root.unit) : Math.round(4 * root.unit)
          radius: height / 2
          color: Theme.tint(0.16)
          Behavior on height { NumberAnimation { duration: Theme.animDuration(100) } }

          Rectangle {
            width: track.width * MprisBackend.progressRatio
            height: parent.height
            radius: parent.radius
            color: Theme.primary
          }
        }

        MouseArea {
          id: seek
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: mouse => {
            if (MprisBackend.currentLength <= 0) return
            const pos = (mouse.x / width) * MprisBackend.currentLength
            MprisBackend.runCtl(["position", (pos / 1000000).toFixed(2)])
          }
        }
      }

      Text {
        Layout.preferredWidth: Math.round(38 * root.unit)
        horizontalAlignment: Text.AlignRight
        text: MprisBackend.formatTime(MprisBackend.currentLength)
        color: Theme.subtext
        font.pixelSize: Math.round(11 * root.unit)
        font.family: Theme.fontFamily
      }
    }

    // ── Controles ──
    LockControls {
      Layout.alignment: Qt.AlignHCenter
      unit: root.unit
      playing: root.playing
    }
  }
}
