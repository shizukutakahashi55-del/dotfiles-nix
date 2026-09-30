// Dock — píldora flotante abajo con las apps "fijadas" (favoritas) y las
// que están abiertas ahora mismo, una por appId aunque tenga varias
// ventanas.
//
//   • Clic izquierdo → si la app está corriendo, activa una de sus
//     ventanas (si ya está al frente y es la única, la minimiza — mismo
//     gesto que el taskbar; si tiene varias, va ciclando entre ellas). Si
//     no está corriendo pero está fijada, la lanza (entry.execute()).
//   • Clic derecho    → fijar / desfijar del dock (DockBackend, se persiste).
//   • Clic del medio   → cierra TODAS las ventanas de esa app.
//   • Puntito debajo del ícono: tiene alguna ventana abierta (lleno y del
//     color primario si es la que está activa ahora).
//
// Se enciende/apaga en Ajustes → Interfaz → Dock (Theme.dockEnabled). Con el
// marco "curved" activo no se muestra (Theme.dockUsable): comparte borde con
// las líneas del marco y se pisan.
// Posición (arriba/abajo) y auto-ocultar también salen de ahí: ver
// Theme.dockEffectivePosition / Theme.dockAutoHide más abajo.
//
// Con auto-ocultar queda flotando sobre el escritorio sin empujar a las
// ventanas (mismo criterio que AudioOSD/RightModules). Fijo (sin
// auto-ocultar) SÍ reserva su alto vía exclusiveZone, para que las ventanas
// no queden tapadas por el dock. Reutiliza la
// MISMA resolución de íconos que TASKBAR/Taskbar.qml (DesktopEntries +
// Quickshell.iconPath), duplicada acá para no acoplar ambos módulos entre sí.
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import "../COMMON"
import "../LANG"

Variants {
  id: dockModule
  model: Quickshell.screens

  // Lo pone shell.qml (mismo agregado que `popupOpen` de la barra): con un
  // popup abierto (menú, launcher, ajustes…) no se muestran tooltips, igual
  // que en LeftModules / CenterModules / RightModules.
  property bool popupOpen: false

  delegate: Component {
    PanelWindow {
      id: win
      required property var modelData
      screen: modelData

      // !Theme.barRebuilding: mismo anti-parpadeo que las ventanas de la
      // barra (Bar.qml) — como el Dock sigue a la barra (dockEffectivePosition
      // cambia solo si la barra pasa a horizontal/vertical o de lado), sus
      // anclas pueden voltearse al mismo tiempo que las de la barra.
      visible: Theme.dockUsable && win.dockItems.length > 0 && !Theme.barRebuilding

      // Con la barra lateral (izquierda/derecha), Theme.dockPosition manda
      // — el usuario lo elige a mano en Ajustes. Con la barra horizontal
      // (arriba/abajo), Theme ya lo resuelve solo en dockEffectivePosition:
      // el Dock se va derecho al lado CONTRARIO de la barra, así nunca se
      // superponen y no hace falta correrlo con un margen extra.
      readonly property bool atTop: Theme.dockEffectivePosition === "top"
      anchors { top: win.atTop; bottom: !win.atTop; left: true; right: true }

      // Alto del PIll y de la "manija" que queda asomando cuando está
      // auto-ocultado (ver pill.y). El extra de arriba (o abajo, según la
      // posición) es aire para que el tooltip (FusedTip) no quede cortado.
      // Igual que las ventanas de la barra (RightModules, +260): la lista de
      // ventanas de una app puede tener varias líneas y con poco aire el
      // tooltip se cortaba contra el borde de la ventana, con la punta plana
      // y sin esquinas redondeadas. La ventana es click-through fuera de la
      // píldora (mask), así que agrandarla no estorba.
      // Tamaño PROPIO del Dock (Ajustes → Interfaz → Dock → Tamaño): usa
      // Theme.dockScale, ya no la escala de la barra. La separación con el
      // borde (restGap) es fija: Theme.dockEdgeGap.
      readonly property real pillHeight: Math.round(58 * Theme.dockScale)
      readonly property real handleHeight: Math.round(6 * Theme.dockScale)
      readonly property real tipAllowance: Math.round(260 * Theme.dockScale)
      readonly property real restGap: Theme.dockEdgeGap

      implicitHeight: win.pillHeight + win.restGap + Math.round(10 * Theme.dockScale) + win.tipAllowance
      color: "transparent"

      // ─── Convivencia con el marco de esquinas ─────────────────────
      // Con CUALQUIER marco activo (esquinas o curved), el dock NO reserva
      // espacio: los cornersTop/cornersBottom de Bar.qml ya reservan la
      // franja del borde, y si el dock también reserva las dos zonas
      // exclusivas compiten → Hyprland reacomoda la barra (se "mueve").
      // Con marco activo el dock queda como overlay puro (igual que en
      // auto-ocultar): flota sobre las ventanas sin empujarlas.
      // Ojo: la property en Theme se llama `screenCorners`, NO
      // `screenCornersActive` (ese typo era el bug: siempre daba undefined
      // → frameActive siempre false → el dock reservaba con marco activo).
      readonly property bool frameActive: Theme.screenCorners
        && !Theme.barSeparated && !Theme.barRebuilding

      // Dock fijo (sin auto-ocultar) Y sin marco: reserva su alto
      // (píldora + restGap) en el borde → Hyprland empuja las ventanas por
      // encima/debajo del dock (a gaps_out de él) en vez de dejarlas
      // tapadas. Con auto-ocultar o con marco activo, -1 (no empuja nada).
      exclusiveZone: (Theme.dockAutoHide || win.frameActive)
        ? -1
        : Math.round(win.pillHeight + win.restGap)

      // ─── Espacio libre con auto-ocultar (igual que PILL/Pill.qml) ─────
      // Escondido, el dock deja asomar la manija (`handleHeight`) y flota
      // sobre las ventanas. Sin reservar nada, una ventana pegada al borde
      // (gaps_out chico) quedaba tapada por la manija y despertaba el dock
      // sin querer. Igual que la píldora, se reserva la franja de reveal +
      // `clearance` con una ventana fantasma. Hyprland SUMA la zona a
      // gaps_out, por eso se resta el gap actual (AppState.gapsOut).
      // Es CONSTANTE (no cambia al revelarse) para que las ventanas no se
      // muevan cada vez que el dock sube/baja.
      // Con marco activo tampoco se reserva (mismo motivo que exclusiveZone).
      readonly property int clearance: 5
      readonly property int reserveZone: (Theme.dockAutoHide || win.frameActive)
        ? 0
        : Math.max(0, Math.round(win.handleHeight) + win.clearance - AppState.gapsOut)

      // Ventana "fantasma": transparente, click-through y en Background,
      // anclada a UN solo borde (el del dock) para que el compositor
      // respete su exclusiveZone. La ventana del dock ocupa left+right
      // pero su zona es -1 con auto-ocultar, así que no puede reservarla.
      PanelWindow {
        id: reserveWin
        screen: win.modelData
        anchors { top: win.atTop; bottom: !win.atTop; left: true; right: true }
        implicitHeight: Math.max(1, win.reserveZone)
        color: "transparent"
        visible: win.visible && win.reserveZone > 0

        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "oozeshell-dock-reserve"
        exclusiveZone: win.reserveZone
        mask: Region {}
      }

      WlrLayershell.namespace: "quickshell-dock"
      WlrLayershell.layer: WlrLayer.Top

      mask: Region { item: pill }

      // ─── Auto-ocultar (Ajustes → Interfaz → Dock → Auto-ocultar) ─────
      // Con auto-ocultar apagado queda siempre revelado. Encendido, se
      // esconde a los `hideDelay` ms de que el mouse se va, dejando asomar
      // `handleHeight` px (la "manija") para volver a pasar el mouse. El
      // handle sigue recibiendo hover porque `mask` lo cubre igual (sigue
      // la geometría actual de `pill`, esté donde esté).
      property bool revealed: !Theme.dockAutoHide

      Connections {
        target: Theme
        function onDockAutoHideChanged() {
          win.revealed = !Theme.dockAutoHide || pillHover.hovered
        }
      }

      Timer { id: hideTimer; interval: 700; repeat: false; onTriggered: win.revealed = false }

      // ¿el toplevel `t` vive en ESTA pantalla? (igual que Taskbar.onThisScreen)
      function onThisScreen(t) {
        const scr = t.screens
        if (!scr || scr.length === undefined || scr.length === 0) return true
        for (let i = 0; i < scr.length; i++)
          if (scr[i] && win.modelData && scr[i].name === win.modelData.name) return true
        return false
      }

      // Se reevalúa cuando termina de cargar la base de .desktop (mismo
      // truco que Taskbar.desktopRevision)
      readonly property int desktopRevision: DesktopEntries.applications.values.length

      function iconFor(appId) {
        void win.desktopRevision
        const id = appId || ""
        const names = []
        if (id !== "") {
          const entry = DesktopEntries.heuristicLookup(id)
          if (entry && entry.icon) names.push(entry.icon)
          names.push(id, id.toLowerCase())
          const last = id.split(".").pop().toLowerCase()
          if (last !== id.toLowerCase()) names.push(last)
        }
        for (let i = 0; i < names.length; i++) {
          const n = names[i]
          if (!n) continue
          if (n.charAt(0) === "/") return "file://" + n
          const p = Quickshell.iconPath(n, true)
          if (p !== "") return p
        }
        return Quickshell.iconPath("application-x-executable", true)
      }

      // Ventanas abiertas de ESTA pantalla, agrupadas por appId
      readonly property var runningByApp: {
        const map = {}
        const order = []
        const list = ToplevelManager.toplevels.values
        for (let i = 0; i < list.length; i++) {
          const t = list[i]
          if (!win.onThisScreen(t)) continue
          const id = t.appId || "?"
          if (!map[id]) { map[id] = []; order.push(id) }
          map[id].push(t)
        }
        return { map: map, order: order }
      }

      // Fijadas primero (en su orden), después las abiertas que no están fijadas
      readonly property var dockItems: {
        const out = []
        const seen = {}
        const pins = DockBackend.pinnedApps
        for (let i = 0; i < pins.length; i++) {
          const id = pins[i]
          if (seen[id]) continue
          seen[id] = true
          out.push({ appId: id, toplevels: win.runningByApp.map[id] || [] })
        }
        for (let i = 0; i < win.runningByApp.order.length; i++) {
          const id = win.runningByApp.order[i]
          if (seen[id]) continue
          seen[id] = true
          out.push({ appId: id, toplevels: win.runningByApp.map[id] })
        }
        return out
      }

      function activateItem(item) {
        const tops = item.toplevels
        if (tops && tops.length > 0) {
          if (tops.length === 1) {
            const t = tops[0]
            if (t.activated && !t.minimized) t.minimized = true
            else { t.minimized = false; t.activate() }
          } else {
            const idx = tops.findIndex(t => t.activated)
            const next = tops[(idx + 1 + tops.length) % tops.length]
            next.minimized = false
            next.activate()
          }
        } else {
          const entry = DesktopEntries.heuristicLookup(item.appId)
          if (entry) entry.execute()
        }
      }

      function closeItem(item) {
        const tops = item.toplevels || []
        for (let i = 0; i < tops.length; i++) tops[i].close()
      }

      Item {
        id: pill
        anchors.horizontalCenter: parent.horizontalCenter
        width: row.implicitWidth + (Theme.cozy ? 12 : 16)
        height: win.pillHeight

        // Revelado: posición de siempre, pegada al borde con restGap.
        // Escondido: se corre hacia el borde de la pantalla hasta dejar
        // asomar solo `handleHeight` (el resto queda fuera de la ventana,
        // así que ni se dibuja ni recibe clicks — no hace falta ocultarlo
        // a mano).
        y: win.atTop
          ? (win.revealed ? win.restGap : win.handleHeight - pill.height)
          : (win.revealed ? (win.height - win.restGap - pill.height) : (win.height - win.handleHeight))

        Behavior on y {
          enabled: Theme.dockAutoHide
          NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }

        // Pasar el mouse por la píldora (aunque solo asome la manija) la
        // revela; al salir, se vuelve a esconder después de hideTimer.
        HoverHandler {
          id: pillHover
          onHoveredChanged: {
            if (!Theme.dockAutoHide) return
            if (hovered) { hideTimer.stop(); win.revealed = true }
            else hideTimer.restart()
          }
        }

        // Superficie del Dock: CoOzey usa la misma gramática pixel que
        // Wallpapers/Settings: esquinas escalonadas + tinta + sombra dura.
        // OozeSoft conserva exactamente su píldora redondeada.
        SkinRect {
          anchors.fill: parent
          color: Theme.bg
          radius: Theme.panelRadius
          raised: Theme.cozy
          depth: Theme.cozy ? 3 : 0
          notch: Theme.cozy ? 5 : 0
          inkColor: Theme.ink
          border.width: Theme.bw1
          border.color: Theme.edge
        }

        RowLayout {
          id: row
          anchors.centerIn: parent
          spacing: 4

          Repeater {
            model: win.dockItems

            delegate: Item {
              id: cell
              required property var modelData
              readonly property bool running: modelData.toplevels && modelData.toplevels.length > 0
              readonly property bool active: running && modelData.toplevels.some(t => t.activated)
              readonly property string iconSrc: win.iconFor(modelData.appId)
              // Tope de títulos listados (como Taskbar.summary): el resto
              // se resume en "… +N"
              readonly property int maxTipLines: 10
              readonly property string tip: {
                const tops = modelData.toplevels
                if (tops && tops.length > 0) {
                  const n = Math.min(tops.length, cell.maxTipLines)
                  let s = ""
                  for (let i = 0; i < n; i++)
                    s += (i > 0 ? "\n" : "") + (tops[i].title || modelData.appId)
                  if (tops.length > n) s += "\n… +" + (tops.length - n)
                  return s
                }
                return modelData.appId
              }

              // Repeater con modelo JS: al abrir/cerrar una app se recrean TODOS
              // los íconos. Si el tooltip apuntaba a uno, se suelta acá para que
              // no quede armado con un objeto muerto (y sin retardo la próxima vez).
              Component.onDestruction: win.tipCellGone(cell)

              Layout.preferredWidth: 46 * Theme.dockScale
              Layout.preferredHeight: 46 * Theme.dockScale

              // Cada app es una pequeña baldosa. En CoOzey no hay
              // cápsulas redondas: la selección se lee por bloques pixelados.
              SkinRect {
                anchors.fill: parent
                color: area.containsMouse ? Theme.surfaceHigh
                                           : (cell.active ? Theme.surface : "transparent")
                radius: Theme.cozy ? 0 : 12
                raised: Theme.cozy && (cell.active || area.containsMouse)
                depth: Theme.cozy ? 2 : 0
                notch: Theme.cozy ? 3 : 0
                inkColor: cell.active ? Theme.primary : Theme.ink
                border.width: Theme.cozy ? 0 : Theme.bw1
                border.color: Theme.edge
                Behavior on color { ColorAnimation { duration: 100 } }
              }

              scale: Theme.cozy
                ? (area.pressed ? 0.94 : (area.containsMouse ? 1.05 : 1.0))
                : (area.pressed ? 0.90 : (area.containsMouse ? 1.10 : 1.0))
              Behavior on scale { NumberAnimation { duration: Theme.cozy ? 100 : 150; easing.type: Easing.OutBack } }

              IconImage {
                anchors.centerIn: parent
                width: 26 * Theme.dockScale
                height: width
                visible: cell.iconSrc !== ""
                source: cell.iconSrc
              }

              Text {
                anchors.centerIn: parent
                visible: cell.iconSrc === ""
                text: "󰀻"
                color: Theme.subtext
                font.pixelSize: Theme.fs(20)
                font.family: Theme.monoFamily
              }

              // Puntito: tiene ventanas abiertas (relleno y primario si es la activa)
              Rectangle {
                visible: cell.running
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.cozy ? 2 : 2
                width: Theme.cozy ? (cell.active ? 9 : 6) : (cell.active ? 5 : 4)
                height: Theme.cozy ? 3 : (cell.active ? 5 : 4)
                radius: Theme.cozy ? 0 : width / 2
                color: cell.active ? Theme.primary : Theme.subtext
              }

              MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                onEntered: win.tipEnter(cell)
                onExited: win.tipLeave(cell)

                onClicked: mouse => {
                  if (mouse.button === Qt.RightButton) DockBackend.togglePin(cell.modelData.appId)
                  else if (mouse.button === Qt.MiddleButton) win.closeItem(cell.modelData)
                  else win.activateItem(cell.modelData)
                }
              }
            }
          }
        }
      }

      // ─── Tooltip compartido (FusedTip) ───────────────────────────
      // Antes cada ícono traía un ToolTip de QtQuick.Controls (se
      // posicionaba solo, a veces justo arriba del cursor y tapaba el
      // clic siguiente). Ahora es UN solo FusedTip por dock, como en
      // RightModules/LeftModules: nace del lado de afuera del dock —
      // "sube" como un globito si el dock está abajo, "baja" si está
      // arriba — centrado en el ícono, y no traga clicks (no forma parte
      // de `mask`, así que lo que esté debajo sigue siendo clickeable).
      property var tipTarget: null
      property real tipCenterX: 0
      property bool tipShown: false
      property string tipText: ""

      readonly property string liveTip: tipTarget ? String(tipTarget.tip ?? "") : ""
      onLiveTipChanged: { if (liveTip !== "") win.tipText = liveTip }

      readonly property bool tipAllowed: !dockModule.popupOpen
      readonly property bool tipOpen:
        win.revealed && win.tipAllowed && win.tipShown
        && win.tipTarget !== null && win.tipTarget.visible && win.tipText !== ""

      function tipEnter(item) {
        tipHideTimer.stop()
        win.tipTarget = item
        win.tipText = win.liveTip
        const c = item.mapToItem(null, item.width / 2, item.height / 2)
        win.tipCenterX = c.x
        if (!win.tipShown) tipShowTimer.restart()
      }

      // La píldora cambia de ancho al fijar/abrir/cerrar apps: se vuelve a medir
      // el centro del ícono, si no el tooltip queda donde estaba.
      function tipRefresh() {
        if (!win.tipTarget) return
        win.tipCenterX = win.tipTarget.mapToItem(null, win.tipTarget.width / 2, win.tipTarget.height / 2).x
      }

      Connections {
        target: pill
        function onWidthChanged() { Qt.callLater(win.tipRefresh) }
      }

      function tipLeave(item) {
        if (win.tipTarget !== item) return
        tipShowTimer.stop()
        tipHideTimer.restart()
      }

      function tipCellGone(item) {
        if (win.tipTarget !== item) return
        win.tipTarget = null
        win.tipShown = false
        tipShowTimer.stop()
      }

      Timer { id: tipShowTimer; interval: 500; repeat: false; onTriggered: win.tipShown = true }
      Timer { id: tipHideTimer; interval: 150; repeat: false; onTriggered: win.tipShown = false }

      FusedTip {
        id: tip
        open: win.tipOpen
        text: win.tipText
        edge: win.atTop ? "top" : "bottom"

        // El dock es una píldora (radio propio, con borde): el tooltip cuelga
        // de su tramo plano, centrado en el ícono, sin dejar curvas colgando
        // en el aire; si es más ancho que la píldora (pocas apps, título
        // largo) pasa a ser una burbuja flotante con un respiro (tip.floating).
        // Alto máximo hasta el borde de la ventana (como `maxDepth` en las
        // ventanas de la barra): lo que no cabe se recorta con "…" y el
        // tooltip conserva su forma.
        maxDepth: win.height - win.restGap - win.pillHeight - 8

        island: "center"
        islandStyle: "hang"
        islandRadius: Theme.panelRadius
        islandRectLocal: ({ x: pill.x, y: pill.y, w: pill.width, h: pill.height })
        align: "center"
        alignCenter: win.tipCenterX

        x: tip.islandActive
           ? tip.placedAlong
           : Math.max(0, Math.min(win.width - width, win.tipCenterX - width / 2))
        // Colgado: se mete 1px (el borde de la píldora) para tapar la línea
        // divisoria y que nazca de ella como en las islas de la barra, que no
        // tienen borde. Flotante: sin solape, separado 6px.
        readonly property real seam: tip.floating ? 0 : 1
        y: win.atTop
           ? (pill.y + pill.height - tip.seam + (tip.floating ? 6 : 0))
           : (pill.y - tip.height + tip.seam - (tip.floating ? 6 : 0))

        Behavior on x {
          enabled: tip.shown
          NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }
      }
    }
  }
}