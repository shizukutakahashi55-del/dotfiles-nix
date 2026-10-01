// PrivacyBackend — ¿qué apps están usando tu pantalla o tu micrófono?
// (reemplaza el módulo "privacy" de Waybar)
//
// Sale directo de PipeWire (Quickshell.Services.Pipewire), sin procesos
// ni polling de wpctl: PipeWire ya sabe qué apps tienen un stream abierto.
//
//   • Compartir pantalla → streams "Stream/Input/Video" (la app que
//     RECIBE el video del portal: OBS, navegador, Discord...). Se ignoran
//     los que tienen media.role = Camera (eso es la webcam, no la pantalla).
//   • Micrófono en uso   → streams "Stream/Input/Audio" (apps que graban).
//     Se ignoran los que solo escuchan un monitor de salida
//     (stream.capture.sink, ej. cava) y las apps de `ignoreApps`.
//
// Limitación: PipeWire no expone el estado (running/idle) del stream por
// acá, así que una app que deja el micrófono abierto en pausa (ej. Discord
// silenciado) igual cuenta como "en uso". Es lo más honesto que se puede
// decir desde el punto de vista de la privacidad.
//
// Expone (solo lectura):
//   screenshare / screenApps    ¿alguien recibe tu pantalla? / quiénes
//   micActive   / micApps       ¿alguien graba el micrófono? / quiénes
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
  id: root

  // Nombres (en minúscula) de apps que NO deben disparar el indicador.
  // Ej: los medidores de nivel de pavucontrol abren un stream de captura.
  property var ignoreApps: ["cava", "pavucontrol", "pulseaudio volume control"]

  property var screenApps: []
  property var micApps: []
  readonly property bool screenshare: screenApps.length > 0
  readonly property bool micActive: micApps.length > 0

  // Sin esto, PipeWire no nos entrega las `properties` de cada nodo
  // (solo se llenan en nodos "bound").
  PwObjectTracker { objects: Pipewire.nodes.values }

  function prop(node, key) {
    const p = node.properties
    return (p && p[key] !== undefined) ? String(p[key]) : ""
  }

  function labelOf(node) {
    return prop(node, "application.name")
        || prop(node, "node.description")
        || node.description
        || node.name
        || "?"
  }

  function ignored(name) {
    return root.ignoreApps.indexOf(name.toLowerCase()) !== -1
  }

  // Sin repetidos ("Firefox" con dos streams se muestra una sola vez)
  function pushUnique(arr, name) {
    if (arr.indexOf(name) === -1) arr.push(name)
  }

  function scan() {
    const screen = []
    const mic = []
    const nodes = Pipewire.nodes.values

    for (let i = 0; i < nodes.length; i++) {
      const n = nodes[i]
      if (!n) continue

      const cls = root.prop(n, "media.class")
      if (cls !== "Stream/Input/Video" && cls !== "Stream/Input/Audio") continue

      const name = root.labelOf(n)
      if (root.ignored(name)) continue

      if (cls === "Stream/Input/Video") {
        if (root.prop(n, "media.role") === "Camera") continue
        root.pushUnique(screen, name)
      } else {
        if (root.prop(n, "stream.capture.sink") === "true") continue
        root.pushUnique(mic, name)
      }
    }

    // Solo se reasigna si cambió algo: así no se re-evalúa la UI en vano
    if (JSON.stringify(screen) !== JSON.stringify(root.screenApps)) root.screenApps = screen
    if (JSON.stringify(mic) !== JSON.stringify(root.micApps)) root.micApps = mic
  }

  // Aparece/desaparece un nodo → re-escanear al toque
  Connections {
    target: Pipewire.nodes
    function onValuesChanged() { root.scan() }
  }

  // Red de seguridad: las `properties` llegan un instante después de que
  // el nodo aparece (cuando el tracker lo bindea), y ese cambio no siempre
  // avisa por señal.
  Timer {
    interval: 2000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.scan()
  }
}
