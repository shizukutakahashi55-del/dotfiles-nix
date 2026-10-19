// AudioModule — volumen: clic abre el mezclador, clic derecho silencia, la rueda cambia el volumen.

import QtQuick
import QtQuick.Layouts

import "../../../COMMON"
import "../../../Services/Lang"
import "../../../Services/Audio"

BarFlow {
  id: mod

  property var host: null
  readonly property bool shown: true

  property real scrollStep: 0.05

  BarPillButton {
    id: audioBtn

    active: mod.host.audioOpen
    tip: Translations.t("audioTip")

    onHoverEntered: mod.host.tipEnter(audioBtn)
    onHoverExited: mod.host.tipLeave(audioBtn)

    onClicked: mouse => {
      if (mouse.button === Qt.RightButton)
        AudioBackend.toggleMuteOsd()
      else
        mod.host.audioButtonClicked()
    }

    onScrolled: wheel => {
      AudioBackend.stepVolume((wheel.angleDelta.y > 0 ? 1 : -1) * mod.scrollStep)
    }

    Text {
      Layout.alignment: Qt.AlignHCenter
      text: AudioBackend.icon
      color: AudioBackend.muted ? Theme.subtext : Theme.text
      font.family: Theme.monoFamily
      font.pixelSize: Theme.fs(16)
      Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
    }

    Text {
      visible: !(Theme.barVertical && AudioBackend.muted)
      Layout.alignment: Qt.AlignHCenter
      text: AudioBackend.muted ? Translations.t("audioMuted")
                               : Math.round(AudioBackend.volume * 100) + "%"
      color: AudioBackend.muted ? Theme.subtext : Theme.text
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fs(12)
    }
  }
}
