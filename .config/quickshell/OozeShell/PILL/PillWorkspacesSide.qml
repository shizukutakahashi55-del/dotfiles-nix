import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../COMMON"

// PillWorkspacesSide — pastilla INDEPENDIENTE a la izquierda con los
// Workspaces (PILL/PillWorkspaces.qml). Espejo de PillTray, pero en vez de
// estar siempre visible, aparece sola cuando cambia el espacio de trabajo
// de ESTA pantalla y se vuelve a esconder tras un momento.
//
// También se puede despertar con el mouse (franja de 6 px en la esquina
// del borde) y no se esconde mientras el mouse está encima.
Item {
    id: root

    property var targetScreen
    readonly property string screenName: targetScreen ? targetScreen.name : ""

    // Mismos valores que Pill.qml
    property int edgeGap: Theme.pillEdgeGap
    property int pillH: Theme.pillHeight
    // Cuánto se queda visible tras un cambio de workspace (ms)
    property int showTime: 1800

    // Fullscreen real en esta pantalla: la ventana (capa Overlay) se oculta
    // para no tapar ni robar clics al juego/video. Igual que las barras.
    readonly property bool suppressed: FullscreenState.isOn(targetScreen)
    onSuppressedChanged: { if (root.suppressed) { root.flash = false; root.hoverKeep = false } }

    // ── Detección de cambio de workspace en ESTA pantalla ───────────
    readonly property int activeId: WM.activeWorkspaceId(root.screenName)
    property int lastId: -999
    property bool flash: false

    onActiveIdChanged: {
        // El primer valor (arranque del shell) no cuenta como "cambio"
        if (root.lastId !== -999 && root.activeId !== root.lastId && root.activeId !== -999) {
            root.flash = true
            hideTimer.restart()
        }
        root.lastId = root.activeId
    }
    Component.onCompleted: root.lastId = root.activeId

    Timer {
        id: hideTimer
        interval: root.showTime
        onTriggered: root.flash = false
    }

    // Mouse sobre la zona (ver `zone` abajo). `hoverKeep` lo mantiene un
    // instante tras salir, así un roce fuera de la píldora no la esconde y
    // reaparece a los parpadeos.
    readonly property bool hovered: zoneHover.hovered
    property bool hoverKeep: false
    onHoveredChanged: {
        if (root.hovered) { leaveTimer.stop(); root.hoverKeep = true }
        else {
            leaveTimer.restart()
            // Si estaba visible por un cambio de workspace, dale su tiempo completo
            if (root.flash) hideTimer.restart()
        }
    }
    Timer {
        id: leaveTimer
        interval: 450
        onTriggered: root.hoverKeep = false
    }

    readonly property bool shown: root.flash || root.hoverKeep

    PanelWindow {
        id: win

        screen: root.targetScreen
        anchors { top: true; left: true; right: true; bottom: true }
        color: "transparent"
        visible: !Theme.barRebuilding && !root.suppressed

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "oozeshell-pill-workspaces"
        exclusiveZone: -1

        // Solo recibe clics donde está la pastilla (si es visible) y en la
        // franja de reveal; el resto de la pantalla sigue siendo click-through.
        mask: Region { item: zone }

        // ZONA DE MOUSE ÚNICA. Antes había una franja de 6 px (solo oculta) y
        // el hover de la píldora por separado: al aparecer la píldora, la
        // franja desaparecía y el mouse quedaba en el hueco de `edgeGap` entre
        // el borde y la píldora → "sin hover" → se escondía → reaparecía la
        // franja → parpadeo. Ahora es UNA sola zona que, al mostrarse, crece
        // para cubrir borde + hueco + píldora (siempre contiene a la franja
        // de antes), así el mouse nunca la abandona en la transición.
        //   oculta  → franja de 6 px pegada al borde (esquina izquierda)
        //   visible → desde el borde hasta un poco debajo de la píldora
        // HoverHandler (no MouseArea): detecta el mouse aunque encima haya
        // botones con su propio MouseArea (los workspaces) y no consume clics.
        Item {
            id: zone
            readonly property real fullH: root.edgeGap + root.pillH + 6
            width: root.edgeGap + Math.max(120, surface.width) + 8
            height: root.shown ? fullH : 6
            x: 0
            y: Theme.barAtBottom ? parent.height - height : 0

            HoverHandler { id: zoneHover }
        }

        Item {
            id: surface

            // 0 = escondida, 1 = visible
            property real t: root.shown ? 1 : 0
            Behavior on t { NumberAnimation { duration: Theme.animDuration(260); easing.type: Easing.OutCubic } }

            width: Math.round(content.implicitWidth * Theme.pillScale) + 16
            height: root.pillH

            visible: t > 0.01
            opacity: t

            readonly property real slide: (1 - t) * (height + root.edgeGap)
            x: root.edgeGap
            y: Math.round(Theme.barAtBottom
                ? parent.height - height - root.edgeGap + slide
                : root.edgeGap - slide)

            Behavior on width { NumberAnimation { duration: Theme.animDuration(200); easing.type: Easing.OutCubic } }

            SkinRect {
                anchors.fill: parent
                radius: 16                 // solo OozeSoft; en CoOzey son esquinas pixel
                color: Theme.bg
                inkColor: Theme.ink
                raised: Theme.cozy
                depth: 2
            }

            RowLayout {
                id: content
                anchors.centerIn: parent
                spacing: 4
                scale: Theme.pillScale
                transformOrigin: Item.Center

                PillWorkspaces { screenName: root.screenName }
            }
        }
    }
}
