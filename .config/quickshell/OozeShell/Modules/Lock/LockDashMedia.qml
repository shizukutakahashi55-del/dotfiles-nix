// LockDashMedia

import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import "../../COMMON"
import "../../Services/Lang"
import "../../Services/Mpris"

LockDashSection {
  id: root

  property bool active: true
  property bool showCover: true
  property bool onlyPlaying: false
  property bool visualizer: true

  // ── Estado ──
  readonly property bool hasPlayer: MprisBackend.activePlayers.length > 0
  readonly property bool playing: MprisBackend.currentStatus === "Playing"
  readonly property bool hasSong: MprisBackend.currentTitle !== "" || MprisBackend.currentArtist !== ""
  readonly property bool ready: root.hasPlayer && root.hasSong && (!root.onlyPlaying || root.playing)
  readonly property int coverSize: Math.round(68 * root.unit)

  function glyph(cp) { return String.fromCodePoint(cp) }

  // ── Sección ──
  shown: root.active && root.ready
  icon: root.glyph(0xF0386)
  title: Translations.t("lockDashMedia")
  trailing: root.hasPlayer ? MprisBackend.cleanPlayerName(MprisBackend.currentPlayer()) : ""
  trailingColor: root.playing ? Theme.primary : Theme.subtext

  // ── Pista ──
  RowLayout {
    Layout.fillWidth: true
    spacing: Math.round(14 * root.unit)

    ClippingRectangle {
      visible: root.showCover
      Layout.preferredWidth: root.coverSize
      Layout.preferredHeight: root.coverSize
      Layout.alignment: Qt.AlignVCenter
      radius: Theme.cozy ? 3 : Math.round(root.coverSize * 0.18)
      color: Theme.surface

      Image {
        anchors.fill: parent
        source: MprisBackend.currentArt
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
      Layout.minimumWidth: 0
      Layout.alignment: Qt.AlignVCenter
      spacing: Math.round(3 * root.unit)

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
    }
  }

  // ── Espectro ──
  LockSpectrum {
    Layout.fillWidth: true
    Layout.preferredHeight: root.visualizer ? Math.round(26 * root.unit) : 0
    visible: root.visualizer
    unit: root.unit
    wanted: root.visualizer && root.shown
    playing: root.playing
  }

  // ── Progreso ──
  RowLayout {
    Layout.fillWidth: true
    spacing: Math.round(8 * root.unit)

    Text {
      Layout.preferredWidth: Math.round(34 * root.unit)
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
        radius: Theme.cozy ? 0 : height / 2
        color: Qt.alpha(Theme.subtext, 0.28)
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
      Layout.preferredWidth: Math.round(34 * root.unit)
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
    shrink: 0.82
    playing: root.playing
  }
}
