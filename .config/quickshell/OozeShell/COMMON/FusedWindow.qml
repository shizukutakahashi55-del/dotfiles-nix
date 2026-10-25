// FusedWindow — ventana overlay para un popup que cuelga de la barra.

import Quickshell
import Quickshell.Wayland
import QtQuick

Item {
  id: root

  property bool active: false

  // ─── Montaje perezoso (EXPERIMENTAL, opt-in) ────────────────────────


  readonly property string lazyEnv: Quickshell.env("OOZESHELL_LAZY_WINDOWS")
  // Montaje perezoso: cada FusedWindow es un overlay a pantalla completa; mantenerlas todas
  // mapeadas en reposo (~20) cuesta cientos de MiB de VRAM. Lo gobierna el toggle de Ajustes
  // «Paneles bajo demanda» (Theme.lazyPanels) o el modo performance. OOZESHELL_LAZY_WINDOWS=1/0 lo fuerza.
  // keepMounted: ventanas de uso frecuente (launcher) que deben abrir al instante.
  property bool keepMounted: false
  readonly property bool lazyMount: !root.keepMounted
    && (root.lazyEnv === "1" || (root.lazyEnv !== "0" && (Theme.lazyPanels || Theme.shellPerf)))
  readonly property bool mounted: !root.lazyMount || root.active || closeGrace.running
  Timer { id: closeGrace; interval: 900; repeat: false }
  onActiveChanged: { if (!root.active) closeGrace.restart() }

  // ─── Espera a la animación de mapeo del compositor (solo montaje perezoso) ───


  readonly property int mapMs: {
    const v = parseInt(Quickshell.env("OOZESHELL_MAP_MS"))
    if (!isNaN(v)) return Math.max(0, v)
    // 0 por defecto: con layerrule noanim sobre oozeshell-* no hay animación de mapeo que esperar.
    // Si tu compositor anima las layers, usa OOZESHELL_MAP_MS=300.
    return 0
  }

  // ─── Listo para animar (solo importa con montaje perezoso) ───────────


  readonly property int settleMs: parseInt(Quickshell.env("OOZESHELL_SETTLE_MS")) || 80
  property bool fusedReady: !root.lazyMount
  readonly property bool surfaceUp: root.mounted && win.visible && host.width > 0 && host.height > 0
  onSurfaceUpChanged: {
    if (!root.lazyMount) return
    if (root.surfaceUp) settleTimer.restart()
    else { settleTimer.stop(); root.fusedReady = false }
  }
  Timer { id: settleTimer; interval: root.settleMs + root.mapMs; repeat: false; onTriggered: root.fusedReady = true }


  onLazyMountChanged: {
    settleTimer.stop()
    if (!root.lazyMount) root.fusedReady = true
    else if (root.surfaceUp) { root.fusedReady = false; settleTimer.restart() }
    else root.fusedReady = false
  }

  property string targetScreen: ""
  property string namespace: "oozeshell-popup"


  property bool exclusiveKeys: false
  signal closeRequested()

  signal keyPressed(int key, int modifiers, string text)

  function focusKeys() { keyCatcher.forceActiveFocus() }


  readonly property bool onIslands: (Theme.islandsMode || Theme.pillMode) && !root.detached && !Theme.floatWindows

  readonly property real screenHeight: win.screen ? win.screen.height : 1080
  readonly property real screenWidth: win.screen ? win.screen.width : 1920

  default property alias content: host.data


  readonly property bool detached: FullscreenState.isOn(win.screen) || Theme.wallpaperChanging || Theme.usingWaybar

  PanelWindow {
    id: win

    screen: Quickshell.screens.find(s => s.name === root.targetScreen) ?? Quickshell.screens[0]
    visible: root.mounted
    color: "transparent"
    exclusiveZone: -1
    anchors { top: true; left: true; right: true; bottom: true }

    WlrLayershell.layer: root.onIslands ? WlrLayer.Top : WlrLayer.Overlay
    WlrLayershell.namespace: root.namespace

    WlrLayershell.keyboardFocus: !root.active ? WlrKeyboardFocus.None
      : (root.exclusiveKeys ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand)


    mask: Region { item: backdrop }


    property var glassPanels: []
    GlassRegion { id: blurReg; panels: win.glassPanels }
    Component.onCompleted: {
      if (WM.hasBackgroundBlur) BackgroundEffect.blurRegion = blurReg
    }

    Connections {
      target: root
      function onActiveChanged() {
        if (root.active) keyCatcher.forceActiveFocus()
      }
    }

    Connections {
      target: win
      function onVisibleChanged() {
        if (win.visible && root.active) keyCatcher.forceActiveFocus()
      }
    }

    Item {
      id: backdrop


      x: (Theme.barVertical && !Theme.barAtRight && !root.onIslands) ? Theme.barFace : 0
      y: (!Theme.barVertical && !Theme.barAtBottom && !root.onIslands) ? Theme.barFace : 0
      width: root.active ? (Theme.barVertical ? parent.width - Theme.barFace : parent.width) : 0
      height: root.active
        ? (Theme.barVertical ? parent.height
                             : (root.onIslands ? parent.height : parent.height - Theme.barFace))
        : 0

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onClicked: root.closeRequested()
      }
    }

    Item {
      id: host
      anchors.fill: parent

      readonly property bool detached: root.detached

      readonly property bool fusedReady: root.fusedReady

      readonly property string screenName: win.screen ? win.screen.name : ""
    }

    Item {
      id: keyCatcher
      anchors.fill: parent
      focus: true
      Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
          root.closeRequested()
          event.accepted = true
        } else {
          root.keyPressed(event.key, event.modifiers, event.text)
        }
      }
    }
  }
}
