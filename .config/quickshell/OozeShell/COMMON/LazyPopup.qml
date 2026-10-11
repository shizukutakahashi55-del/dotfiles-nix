// LazyPopup — monta un popup SOLO mientras se usa y lo DESTRUYE al cerrarse.
// Por qué: cada popup (FusedWindow) es una superficie layer-shell a pantalla completa. Aunque esté invisible, sigue reservando búferes ARGB del tamaño de la pantalla + su propia escena de Qt Quick (VRAM). Con `visible: …

import Quickshell
import QtQuick

LazyLoader {
  id: gate

  property bool wanted: false
  property int grace: 1200
  property bool open: false
  property int openDelay: 100

  active: gate.wanted || closeTimer.running

  onWantedChanged: {
    if (gate.wanted) {
      closeTimer.stop()


      if (gate.item) gate.open = true
      else openTimer.restart()
    } else {
      openTimer.stop()
      gate.open = false
      closeTimer.restart()
    }
  }


  property QtObject openTimerObj: Timer {
    id: openTimer
    interval: gate.openDelay
    onTriggered: gate.open = gate.wanted
  }
  property QtObject closeTimerObj: Timer {
    id: closeTimer
    interval: gate.grace
  }
}
