import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../COMMON"
import "../TASKBAR"
import "../DASHBOARD"
import "../NOTIFY"

// Pill — la superficie de Theme.pillMode 
Item {
    id: root

    property var targetScreen
    readonly property string screenName: targetScreen ? targetScreen.name : ""

    // shell.qml los conecta a los mismos popups de siempre.
    signal notificationButtonClicked(var screen)
    signal requestNetwork(var screen)
    signal requestBluetooth(var screen)
    signal requestAppearance(var screen)
    signal requestWalls(var screen)
    signal requestAdvancedSettings(var screen)
    signal trayMenuOpened()

    // Algún popup de shell.qml abierto (cierra el menú de la bandeja)
    property bool popupOpen: false

    readonly property bool dashboardOpenHere:
        AppState.dashboardOpen && AppState.dashboardScreen === root.screenName

    // ── Precarga del Dashboard ───────────────────────────────────────
    // Hover sostenido sobre la píldora → carga la sección activa; se suelta
    // unos segundos después de irse el mouse.
    property bool warm: false
    Timer { id: warmOn;  interval: 150;  onTriggered: root.warm = true }
    Timer { id: warmOff; interval: 4000; onTriggered: root.warm = false }
    function noteHover(inside) {
        if (inside) { warmOff.stop(); if (!root.warm && !root.dashboardOpenHere) warmOn.restart() }
        else { warmOn.stop(); warmOff.restart() }
    }

    // ── Drop del taskbar plegado (TASKBAR/TaskbarMenu.qml, sin tocar) ──
    property bool taskbarMenuOpen: false
    function closeTaskbarMenu() { root.taskbarMenuOpen = false }
    function openTaskbarMenu(iconItem) {
        if (root.taskbarMenuOpen) { root.closeTaskbarMenu(); return }
        const c = iconItem.mapToItem(null, iconItem.width / 2, iconItem.height / 2)
        taskbarMenu.anchorX = c.x
        taskbarMenu.anchorY = c.y
        root.taskbarMenuOpen = true
    }

    // ── Auto-hide ───────────────────────────────────────────────────
    // Estado LOCAL por pantalla (con varios monitores, el mouse en uno no
    // debe esconder/mostrar la píldora del otro); se refleja además en
    // AppState.pillHiddenNow para quien quiera leerlo.
    property bool hiddenHere: false
    readonly property bool keepVisible:
        !AppState.pillAutoHide
        || root.dashboardOpenHere
        || root.taskbarMenuOpen
        || surfaceHover.containsMouse
        || trigger.containsMouse
        || root.popupOpen
        || (AppState.pillTraySync && sideTray.keepVisible)

    function applyHidden(v) {
        root.hiddenHere = v
        AppState.pillHiddenNow = v
    }
    onKeepVisibleChanged: {
        if (root.keepVisible) { hideTimer.stop(); root.applyHidden(false) }
        else hideTimer.restart()
    }
    Component.onCompleted: {
        if (!root.keepVisible) hideTimer.restart()
        root.reportIsland()
    }
    Component.onDestruction: IslandState.clearPill(root.screenName, "center")

    // ── Isla para los popups ─────────────────────────────────────────
    // Los menús/ventanas (FusedPanel) nacen de ESTE rectángulo, en
    // coordenadas de pantalla y en su tamaño compacto (no el del dock).
    readonly property var islandRect: ({
        x: Math.round((pillWin.width - root.pillW) / 2),
        y: Theme.barAtBottom ? pillWin.height - root.pillH - root.edgeGap : root.edgeGap,
        w: root.pillW, h: root.pillH, r: 18
    })
    function reportIsland() {
        if (root.screenName === "" || pillWin.width <= 0 || pillWin.height <= 0) return
        IslandState.report(root.screenName, "center", root.islandRect)
    }
    onIslandRectChanged: root.reportIsland()

    Timer {
        id: hideTimer
        interval: 1500
        repeat: false
        onTriggered: { if (!root.keepVisible) root.applyHidden(true) }
    }

    // ── Medidas ─────────────────────────────────────────────────────
    // Separación con el borde de pantalla, alto y escala salen de Theme
    // (Ajustes → Interfaz → Píldora): tamaño propio, sin depender de la barra.
    readonly property int edgeGap: Theme.pillEdgeGap
    readonly property int peek: 4            // lo que asoma cuando está oculta
    readonly property real ps: Theme.pillScale
    readonly property int pillW: Math.round(row.implicitWidth * root.ps) + 16
    readonly property int pillH: Theme.pillHeight
    readonly property int triggerH: 6        // franja de reveal del auto-hide
    readonly property int clearance: 5       // aire extra sobre esa franja

    // ── Espacio que las ventanas NO deben invadir ────────────────────
    // (empuja las ventanas de Mango vía exclusiveZone; ver `reserveWin`)
    //   • Auto-hide: solo la franja de reveal + `clearance`, así una ventana
    //     pegada al borde no despierta la píldora sin querer. Es CONSTANTE
    //     (no cambia al revelarse) para que las ventanas no se muevan cada
    //     vez que la píldora sube/baja: al revelarse flota encima.
    //     Mango suma la zona a gappoh/gappov, por eso se resta el gap actual.
    //   • Fija (sin auto-hide): la píldora entera (gap + alto), y las
    //     ventanas quedan a gaps_out de ella.
    readonly property int reserveZone: AppState.pillAutoHide
        ? Math.max(0, root.triggerH + root.clearance - AppState.gapsOut)
        : root.edgeGap + root.pillH

    // Ancho de píldora suavizado: si aparece/desaparece el ícono del taskbar
    // la píldora se ajusta con animación en vez de dar un salto.
    property real pillWAnim: root.pillW
    Behavior on pillWAnim { NumberAnimation { duration: Theme.animDuration(200); easing.type: Easing.OutCubic } }

    // Tamaño del dock (lo pide la sección activa). Se anima SOLO cuando el
    // dock ya está abierto (cambio de sección); al abrir desde cero se
    // asigna directo, para que la transición no persiga un objetivo móvil.
    property real dockW: dashboard.fullWidth
    property real dockH: dashboard.fullHeight
    Behavior on dockW { enabled: surface.progress > 0.02; NumberAnimation { duration: Theme.animDuration(260); easing.type: Easing.OutCubic } }
    Behavior on dockH { enabled: surface.progress > 0.02; NumberAnimation { duration: Theme.animDuration(260); easing.type: Easing.OutCubic } }

    // Pastilla independiente a la izquierda: Workspaces. Aparece sola al
    // cambiar de espacio de trabajo y se vuelve a esconder
    // (PILL/PillWorkspacesSide.qml).
    PillWorkspacesSide {
        id: sideWorkspaces
        targetScreen: root.targetScreen
        edgeGap: root.edgeGap
        pillH: root.pillH
    }

    // Pastilla independiente a la derecha: Tray + Batería (PILL/PillTray.qml).
    PillTray {
        id: sideTray
        targetScreen: root.targetScreen
        edgeGap: root.edgeGap
        pillH: root.pillH
        peek: root.peek
        syncedHidden: root.hiddenHere
        popupOpen: root.popupOpen
        onTrayMenuOpened: root.trayMenuOpened()
    }

    // Ventana "fantasma" que solo reserva espacio en el borde: transparente,
    // click-through (máscara vacía) y en Background. pillWin ocupa toda la
    // pantalla (4 anclas) y por eso no puede llevar exclusiveZone: el
    // compositor lo ignora salvo que esté anclada a UN borde.
    PanelWindow {
        id: reserveWin

        screen: root.targetScreen
        anchors {
            top: !Theme.barAtBottom
            bottom: Theme.barAtBottom
            left: true
            right: true
        }
        implicitHeight: Math.max(1, root.reserveZone)
        color: "transparent"
        visible: root.reserveZone > 0 && !Theme.barRebuilding

        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "oozeshell-pill-reserve"
        exclusiveZone: root.reserveZone
        mask: Region {}
    }

    PanelWindow {
        id: pillWin

        screen: root.targetScreen
        anchors { top: true; left: true; right: true; bottom: true }
        color: "transparent"
        visible: !Theme.barRebuilding

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "oozeshell-pill"
        exclusiveZone: -1

        // La ventana cubre toda la pantalla; el mask limita los clics a la
        // superficie, la franja de reveal del auto-hide y el drop del taskbar.
        mask: Region {
            item: surface
            Region { item: outsideCatcher }
            Region { item: trigger }
            Region { item: taskbarMenu }
        }

        // Teclado: solo pide foco mientras el dock está abierto (cerrado no
        // debe tocar el foco de las demás apps). Mismo criterio que
        // COMMON/FusedWindow.qml.
        WlrLayershell.keyboardFocus: root.dashboardOpenHere
            ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        Connections {
            target: root
            function onDashboardOpenHereChanged() {
                if (root.dashboardOpenHere) keyCatcher.forceActiveFocus()
            }
        }

        // Escape cierra el dock.
        Item {
            id: keyCatcher
            anchors.fill: parent
            focus: true
            Keys.onPressed: event => {
                if (!root.dashboardOpenHere) return
                if (event.key === Qt.Key_Escape) {
                    AppState.closeDashboard()
                    event.accepted = true
                } else if (dashboard.handleKey(event.key, event.modifiers)) {
                    // La sección activa (Overview) usó la tecla
                    event.accepted = true
                }
            }
        }

        // "Clic afuera": pantalla completa, solo mientras el dock está
        // abierto (cerrado mide 0x0 → todo sigue siendo click-through).
        // Va ANTES de `surface` para quedar debajo: los clics sobre el dock
        // los recibe el dock, el resto cae acá y lo cierra.
        Item {
            id: outsideCatcher
            width: root.dashboardOpenHere ? parent.width : 0
            height: root.dashboardOpenHere ? parent.height : 0
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onClicked: AppState.closeDashboard()
            }
        }

        // Franja invisible en el borde: despierta la píldora oculta.
        Item {
            id: trigger
            readonly property bool armed: AppState.pillAutoHide && root.hiddenHere
            property alias containsMouse: triggerMouse.containsMouse
            width: 360
            height: armed ? root.triggerH : 0
            x: Math.round((parent.width - width) / 2)
            y: Theme.barAtBottom ? parent.height - height : 0
            MouseArea {
                id: triggerMouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
            }
        }

        // ================================================
        // SUPERFICIE ÚNICA: píldora ⇄ dock
        // ================================================
        // UN solo `progress` (0 = píldora, 1 = dock) gobierna todo: ancho,
        // alto, radio y los fundidos del contenido. Así nada se desfasa y
        // la animación se invierte sola al cerrar. x/y NO llevan Behavior
        // propio (se derivan del tamaño): antes lo tenían y la caja se
        // descentraba mientras crecía.
        Item {
            id: surface

            readonly property bool open: root.dashboardOpenHere

            // Abrir: resorte suave (deja pasar un pelín). Cerrar: sin rebote.
            property real progress: open ? 1 : 0
            // CoOzey: rebote más corto (el pixel art con mucho rebote se ve
            // "tembloroso"). Cerrar usa OutCubic: InOutCubic arrancaba lento
            // y se sentía como retraso al pulsar.
            Behavior on progress {
                NumberAnimation {
                    duration: Theme.animDuration(surface.open ? (Theme.cozy ? 380 : 420) : 280)
                    easing.type: surface.open ? Easing.OutBack : Easing.OutCubic
                    easing.overshoot: Theme.cozy ? 0.45 : 0.9
                }
            }

            // Tramo [a,b] del progreso → 0..1 (sin overshoot). Los fundidos
            // van escalonados: la píldora se va primero, el dock llega tarde.
            function stage(a, b) {
                return Math.max(0, Math.min(1, (surface.progress - a) / (b - a)))
            }
            function ease(t) { return t * t * (3 - 2 * t) }
            readonly property real pillT: 1 - ease(stage(0.0, 0.30))
            readonly property real dashT: ease(stage(0.38, 0.85))

            // Auto-hide: desplazamiento animado (0 = visible, 1 = escondida)
            property real hideT: (root.hiddenHere && !open) ? 1 : 0
            Behavior on hideT { NumberAnimation { duration: Theme.animDuration(260); easing.type: Easing.OutCubic } }
            readonly property real slide: hideT * (root.pillH + root.edgeGap - root.peek)

            // Pares (múltiplos de 2) → el centrado cae en píxel entero y los
            // bordes no "vibran" mientras crece.
            width: Math.round((root.pillWAnim + (root.dockW - root.pillWAnim) * progress) / 2) * 2
            height: Math.round(root.pillH + (root.dockH - root.pillH) * progress)

            x: Math.round((parent.width - width) / 2)
            y: Math.round(Theme.barAtBottom
                ? parent.height - height - root.edgeGap + slide
                : root.edgeGap - slide)

            clip: true

            SkinRect {
                anchors.fill: parent
                // CoOzey: la píldora y el Dashboard comparten una caja pixel
                // con escalones; OozeSoft conserva la cápsula redondeada.
                radius: Theme.cozy ? 4 : (18 * root.ps + (22 - 18 * root.ps) * Math.min(1, surface.progress))
                color: Theme.bg
                inkColor: Theme.ink
                raised: Theme.cozy
                depth: 3
            }

            // Traga los clics sobre la superficie. `outsideCatcher` (arriba) es
            // hermano de `surface` y está DEBAJO: un clic en un hueco del dock
            // (el padding de un campo de texto, el borde de una tarjeta, el
            // espacio entre botones) no lo aceptaba nadie y caía a ese
            // "clic afuera", que cerraba el dock a mitad de escribir. Va
            // primero, así queda debajo de todo el contenido y solo atrapa lo
            // que nadie más atiende.
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
            }

            // Presencia del mouse (para el auto-hide); no consume clics.
            MouseArea {
                id: surfaceHover
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                onContainsMouseChanged: root.noteHover(containsMouse)
            }

            // ── Estado píldora ──────────────────────────────
            // Tamaño FIJO (el de la píldora): no se reacomoda mientras la
            // superficie crece, solo se encoge un poco y se desvanece.
            Item {
                id: pillContent
                width: root.pillW
                height: root.pillH
                x: Math.round((surface.width - width) / 2)
                y: Theme.barAtBottom ? surface.height - height : 0

                opacity: surface.pillT
                visible: opacity > 0.01
                enabled: !surface.open
                scale: Theme.cozy ? 1.0 : 1 - 0.08 * (1 - surface.pillT)
                transformOrigin: Item.Center

                RowLayout {
                    id: row
                    anchors.centerIn: parent
                    spacing: 4
                    // Escala propia de la píldora (implicitWidth queda sin escalar:
                    // pillW ya la aplica)
                    scale: root.ps
                    transformOrigin: Item.Center

                    PillNotifications {
                        active: NotificationsBackend.centerOpen
                        onClicked: root.notificationButtonClicked(root.targetScreen)
                    }

                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 16
                        Layout.alignment: Qt.AlignCenter
                        radius: 1
                        color: Theme.primary
                        opacity: 0.25
                    }

                    PillClock {
                        active: root.dashboardOpenHere
                        onClicked: AppState.toggleDashboard(AppState.dashboardSection || "power", root.screenName)
                        onRightClicked: AppState.toggleDashboard("calendar", root.screenName)
                    }

                    Rectangle {
                        visible: pillTaskbar.count > 0
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 16
                        Layout.alignment: Qt.AlignCenter
                        radius: 1
                        color: Theme.primary
                        opacity: 0.25
                    }

                    PillTaskbar {
                        id: pillTaskbar
                        visible: pillTaskbar.count > 0
                        targetScreen: root.targetScreen
                        onMenuRequested: item => root.openTaskbarMenu(item)
                    }
                }
            }

            // ── Estado dock ─────────────────────────────────
            // Mide lo que pide la sección (dockW/dockH, animados al cambiar
            // de sección) y NO cambia mientras la superficie crece: solo se
            // descubre (clip del padre). Entra tarde (dashT), asentándose
            // desde arriba y con un escalado mínimo.
            Dashboard {
                id: dashboard
                // Enteros: dockW/dockH se animan como real y el texto
                // "vibraba" al caer en medios píxeles.
                width: Math.round(root.dockW)
                height: Math.round(root.dockH)
                x: Math.round((surface.width - width) / 2)
                y: Math.round((Theme.barAtBottom ? surface.height - height : 0)
                   + (Theme.barAtBottom ? 1 : -1) * 10 * (1 - surface.dashT))

                screenName: root.screenName
                open: surface.open
                // Sigue cargado mientras se cierra: si no, el contenido
                // desaparecía de golpe en vez de fundirse.
                keepLoaded: surface.progress > 0.001
                // Precarga: con el mouse sobre la píldora la sección ya está
                // instanciada cuando se hace clic (antes se creaba en el
                // primer frame de la animación = tirón).
                warm: root.warm

                opacity: surface.dashT
                visible: opacity > 0.01
                enabled: surface.open
                scale: Theme.cozy ? 1.0 : 0.965 + 0.035 * surface.dashT
                transformOrigin: Theme.barAtBottom ? Item.Bottom : Item.Top

                onRequestNetwork: root.requestNetwork(root.targetScreen)
                onRequestBluetooth: root.requestBluetooth(root.targetScreen)
                onRequestAppearance: root.requestAppearance(root.targetScreen)
                onRequestWalls: root.requestWalls(root.targetScreen)
                onRequestAdvancedSettings: root.requestAdvancedSettings(root.targetScreen)
            }
        }

        // ================================================
        // DROP DEL TASKBAR PLEGADO
        // ================================================
        TaskbarMenu {
            id: taskbarMenu
            open: root.taskbarMenuOpen
            windows: pillTaskbar.windows
            targetScreen: root.screenName
            onCloseRequested: root.closeTaskbarMenu()
        }
    }
}
