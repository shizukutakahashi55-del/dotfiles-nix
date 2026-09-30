// LazyPopup — monta un popup SOLO mientras se usa y lo DESTRUYE al cerrarse.
//
// Por qué: cada popup (FusedWindow) es una superficie layer-shell a pantalla
// completa. Aunque esté invisible, sigue reservando búferes ARGB del tamaño de
// la pantalla + su propia escena de Qt Quick (VRAM). Con `visible: false` la
// escena sigue viva; para liberarla hay que destruir el objeto → LazyLoader.
//
// Uso (en shell.qml):
//   LazyPopup {
//     wanted: root.networkOpen
//     NetworkMenu { open: gate.open ... }     // ← usar `gate.open`, NO root.networkOpen
//   }
//
// `open` va un instante DESPUÉS de crear el popup: FusedPanel anima con un
// Behavior sobre `open`, y un Behavior no anima el valor inicial. Si el popup
// naciera con open=true saldría ya abierto, sin animación.
// Al cerrar: `open` baja al instante (se ve la animación de cierre) y el popup
// se destruye tras `grace` ms (debe ser mayor que la animación de cierre).
import Quickshell
import QtQuick

LazyLoader {
  id: gate

  property bool wanted: false
  property int grace: 1200          // ms; > duración de cierre de FusedPanel
  property bool open: false         // lo que lee el popup hijo
  property int openDelay: 100       // ms entre crear el popup y subir `open` (launcher: menos)

  active: gate.wanted || closeTimer.running

  onWantedChanged: {
    if (gate.wanted) {
      closeTimer.stop()
      // Ya montado (reabierto durante la gracia): abrir de inmediato.
      // Si no, se crea ahora y `open` sube tras un instante (openTimer).
      if (gate.item) gate.open = true
      else openTimer.restart()
    } else {
      openTimer.stop()
      gate.open = false
      closeTimer.restart()
    }
  }

  // Los Timer van en propiedades (no como hijos): el hijo por defecto de
  // LazyLoader es `component`, y un Timer suelto chocaría con eso.
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
