// MprisModule — canción en reproducción (clic: popup, clic derecho / rueda: siguiente / anterior) y el mini botón que pliega el texto.

import QtQuick
import QtQuick.Layouts

import "../../../COMMON"
import "../../../Services/Lang"
import "../../../Services/Mpris"

BarFlow {
  id: mod

  property var host: null
  readonly property bool shown: true

  property int songMaxWidth: 260
  gap: 2

  readonly property string mprisStatus:
    MprisBackend.activePlayers.length > 0 ? MprisBackend.currentStatus : ""
  readonly property string mprisArtist: MprisBackend.currentArtist
  readonly property string mprisTitle: MprisBackend.currentTitle

  readonly property string songLabel:
    (mprisArtist !== "" && mprisTitle !== "")
      ? mprisArtist + " - " + mprisTitle
      : (mprisTitle !== "" ? mprisTitle : mprisArtist)

  readonly property bool hasSong: songLabel !== ""

  readonly property string songTip: {
    if (!hasSong) return Translations.t("mprisNoPlaying")
    if (mprisTitle !== "" && mprisArtist !== "") return mprisTitle + "\n" + mprisArtist
    return songLabel
  }

  BarPillButton {
    id: mprisBtn

    active: mod.host.mprisOpen
    hoverScale: 1.03
    tip: mod.songTip

    onHoverEntered: mod.host.tipEnter(mprisBtn)
    onHoverExited: mod.host.tipLeave(mprisBtn)

    onClicked: mouse => {
      if (mouse.button === Qt.RightButton)
        MprisBackend.runCtl(["next"])
      else
        mod.host.mprisButtonClicked()
    }

    onScrolled: wheel => {
      MprisBackend.runCtl([wheel.angleDelta.y > 0 ? "previous" : "next"])
    }

    Text {
      text: mod.mprisStatus === "Playing" ? "󰎈"
          : mod.mprisStatus === "Paused"  ? "󰏤"
          : "󰝛"
      color: mod.mprisStatus === "Playing" ? Theme.primary : Theme.subtext
      font.family: Theme.monoFamily
      font.pixelSize: Theme.fs(16)
      Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
    }

    Text {
      visible: !Theme.barVertical && !Theme.mprisCompact
      Layout.maximumWidth: mod.songMaxWidth

      text: mod.hasSong ? mod.songLabel : Translations.t("mprisNoPlaying")
      elide: Text.ElideRight

      color: mod.hasSong ? Theme.text : Theme.subtext
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fs(12)
    }
  }

  BarToggle {
    id: mprisToggle

    visible: !Theme.barVertical
    collapsed: Theme.mprisCompact
    contentAfter: false
    tip: Translations.t(Theme.mprisCompact ? "barExpand" : "barCollapse")

    onToggled: Theme.setMprisCompact(!Theme.mprisCompact)
    onHoverEntered: mod.host.tipEnter(mprisToggle)
    onHoverExited: mod.host.tipLeave(mprisToggle)
  }
}
