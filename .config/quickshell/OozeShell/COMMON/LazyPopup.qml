// LazyPopup — monta un popup SOLO mientras se usa y lo DESTRUYE al cerrarse.

import Quickshell
import QtQuick

LazyLoader {
  id: gate

  property bool wanted: false
  property int grace: 1200
  property bool open: false
  property int openDelay: 100
  property bool lazy: true
  property bool available: true

  active: gate.available && (!gate.lazy || gate.wanted || closeTimer.running)

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
    onTriggered: if (gate.lazy) trimDelay.restart()
  }
  property QtObject trimDelayObj: Timer {
    id: trimDelay
    interval: 1500
    onTriggered: Theme.trimMemory()
  }
}
