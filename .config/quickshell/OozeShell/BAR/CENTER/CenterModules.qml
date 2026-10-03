import Quickshell
import Quickshell.Wayland

import QtQuick
import QtQuick.Layouts

import "./CALENDAR"
import "../../COMMON"
import "../../LANG"
import "../../NOTIFY"

Item {
    id: centerModules

    signal notificationButtonClicked()

    // Lo setea Bar.qml: el panel de notificaciones está abierto
    property bool notifyOpen: false

    // Se emite al tocar el botón del Overview (junto al reloj).
    // shell.qml (vía Bar.qml) lo conecta para abrir/cerrar OVERVIEW/Overview.qml
    signal overviewButtonClicked()

    // Lo setea Bar.qml: el Overview está abierto
    property bool overviewOpen: false

    // Clic DERECHO en el reloj: abre el calendario nuevo con ToDo
    // (AGENDA/AgendaPopup.qml, lo monta shell.qml). El clic izquierdo / hover
    // siguen abriendo el calendario chico (CalendarDrop) de siempre.
    signal clockRightClicked()

    // Lo setea Bar.qml: el calendario con ToDo está abierto
    property bool agendaOpen: false

    // Lo setea Bar.qml: hay algún popup abierto (los tooltips se esconden)
    property bool popupOpen: false

    property var targetScreen


    property real topReserve: 0
    property real bottomReserve: 0
    
    // ── Modo Islas: publicar dónde está esta isla (coords de pantalla) ──

    readonly property string screenName: targetScreen ? targetScreen.name : ""
    readonly property var islandRect: Theme.islandsMode ? ({
        x: centerContainer.x, y: centerContainer.y,
        w: centerContainer.width, h: centerContainer.height
    }) : null
    function publishIsland() {
        if (centerModules.screenName === "") return
        if (centerModules.islandRect) IslandState.report(centerModules.screenName, "center", centerModules.islandRect)
        else IslandState.clear(centerModules.screenName, "center")
    }
    onIslandRectChanged: publishIsland()
    Connections {
      target: IslandState
      function onRefreshRequested() { centerModules.publishIsland() }
    }
    Component.onCompleted: publishIsland()

    readonly property real pillExtent: Theme.barVertical ? centerContainer.height : 0

    // ============================================================
    // OCULTAR (fullscreen / recarga de colores al cambiar wallpaper)
    // ============================================================
    // La ventana vive en la capa Overlay, que se dibuja por encima de las
    // ventanas en fullscreen Y de la recarga de colores. 

    property bool wallpaperChanging: false

    // Poné cualquiera en false para volver al comportamiento anterior
    property bool hideOnFullscreen: true
    property bool hideOnWallpaperChange: true

    readonly property bool suppressed:
        (hideOnFullscreen && FullscreenState.isOn(targetScreen))
        || (hideOnWallpaperChange && wallpaperChanging)

    // Si se oculta con el calendario abierto, que no reaparezca abierto
    onSuppressedChanged: {
        if (suppressed) {
            calendarCloseTimer.stop()
            clockButton.calOpen = false
            tipShown = false
        }
    }

    // ============================================================
    // TOOLTIP COMPARTIDO (FusedTip)
    // ============================================================

    property var tipTarget: null      // Item que está bajo el mouse
    property real tipCenterX: 0       // su centro, en coords de la ventana (= pantalla)
    property real tipCenterY: 0       // (X si la barra es horizontal, Y si es vertical)
    property bool tipShown: false     // pasó el retardo y sigue encima
    property string tipText: ""       // último texto no vacío (para la animación de cierre)

    readonly property string liveTip: tipTarget ? String(tipTarget.tip ?? "") : ""
    onLiveTipChanged: { if (liveTip !== "") tipText = liveTip }

    // Con un popup o el calendario abiertos no hace falta tooltip
    readonly property bool tipAllowed: !popupOpen && !suppressed && !clockButton.calOpen
    readonly property bool tipOpen:
        tipShown && tipAllowed && tipTarget !== null && tipTarget.visible && tipText !== ""

    function tipEnter(item) {
        tipHideTimer.stop()
        tipTarget = item
        tipText = liveTip
        const c = item.mapToItem(null, item.width / 2, item.height / 2)
        tipCenterX = c.x
        tipCenterY = c.y
        if (!tipShown) tipShowTimer.restart()
    }

    // Si la isla cambia de tamaño con el tooltip armado (workspaces que
    // aparecen/desaparecen) los botones se corren: se vuelve a medir el centro.
    function tipRefresh() {
        if (!tipTarget) return
        const c = tipTarget.mapToItem(null, tipTarget.width / 2, tipTarget.height / 2)
        tipCenterX = c.x
        tipCenterY = c.y
    }

    Connections {
        target: centerContainer
        function onWidthChanged() { Qt.callLater(centerModules.tipRefresh) }
        function onXChanged() { Qt.callLater(centerModules.tipRefresh) }
    }

    function tipLeave(item) {
        if (tipTarget !== item) return
        tipShowTimer.stop()
        tipHideTimer.restart()
    }

    Timer { id: tipShowTimer; interval: 500; repeat: false; onTriggered: centerModules.tipShown = true }
    Timer { id: tipHideTimer; interval: 150; repeat: false; onTriggered: centerModules.tipShown = false }

    // Los colores salen del Theme único (ya no se lee matugen acá)
    readonly property var colors: ({
        bg:        Theme.bg,
        surface:   Theme.surface,
        surface2:  Theme.surfaceHigh,
        primary:   Theme.primary,
        text:      Theme.text,
        subtext:   Theme.subtext,
        onPrimary: Theme.textOnPrimary
    })

    // ============================================================
    // VENTANA
    // ============================================================

    PanelWindow {
        id: centerPanel

        screen: centerModules.targetScreen

        anchors {
            top: true
            left: true
            right: true
            bottom: true   // necesario para que el calendario no quede
                           // cortado por el borde de la superficie
        }

        color: "transparent"

        // Oculta de verdad (no solo transparente): así tampoco queda una
        // superficie fullscreen encima del juego/video.
        visible: !centerModules.suppressed && !Theme.barRebuilding

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-center-modules"

        exclusiveZone: -1

        // La ventana cubre toda la pantalla, pero el mask limita los
        // clics a la píldora y al calendario.
        mask: Region {
            item: centerContainer
            Region { item: calDrop }
        }

        // ========================================================
        // PÍLDORA CENTRAL
        // ========================================================

        Item {
            id: centerContainer

            // Horizontal: centrada, pegada arriba o abajo (flotante: separada
            // Theme.barEdge del borde). Vertical: pegada al costado de la barra
            // y centrada en el alto del monitor, corrida si no cabe entre los
            // otros dos bloques.
            // Por x/y y no por anclas: alternarlas en caliente deja las dos
            // activas y la píldora queda centrada en la pantalla
            x: Theme.barVertical
                ? (Theme.barAtRight ? parent.width - width - Theme.barEdge : Theme.barEdge)
                : Math.round((parent.width - width) / 2)
            y: {
                if (!Theme.barVertical)
                    return Theme.barAtBottom ? parent.height - height - Theme.barEdge : Theme.barEdge
                const gap = 8
                const ideal = (parent.height - height) / 2
                const lo = centerModules.topReserve + gap
                const hi = parent.height - centerModules.bottomReserve - gap - height
                // Si no cabe, gana el borde de arriba (lo)
                return Math.round(Math.max(lo, Math.min(ideal, hi)))
            }

            // La fila se dibuja escalada (Ajustes → Barra), así que el tamaño de
            // la píldora es el de la fila POR la escala.
            width: Theme.barVertical ? Theme.barThickness : modulesRow.width * Theme.barScale + 14
            height: Theme.barVertical ? modulesRow.height * Theme.barScale + 14 : Theme.barHeight

            // Mismo color que la barra y que todos los popups
            Rectangle {
                visible: !(Theme.cozy && Theme.islandsMode)
                anchors.fill: parent
                radius: Theme.islandRadius
                color: centerModules.colors.bg
                border.width: Theme.islandsMode ? Theme.inkWidth : 0
                border.color: Theme.ink
            }
            // CoOzey + Islas: caja pixel (esquinas escalonadas) en vez de redondeada
            SkinRect {
                visible: Theme.cozy && Theme.islandsMode
                anchors.fill: parent
                notch: 0
                color: centerModules.colors.bg
                inkColor: Theme.ink
            }

            BarFlow {
                id: modulesRow

                anchors.centerIn: parent
                gap: 2

                // Escala de la barra (desde el centro: sigue centrada)
                scale: Theme.barScale

                // =================================================
                // NOTIFICACIONES
                //   clic izquierdo → abrir panel
                //   clic derecho   → No molestar (DND)
                // =================================================

                SkinRect {
                    id: notificationButton

                    // Dos líneas: título y la pista del clic derecho
                    readonly property string tip:
                        Translations.t("notifTitle") + "\n" + Translations.t("notifDndHint")

                    Layout.preferredWidth: Theme.barVertical ? 40 : 36
                    Layout.preferredHeight: 30

                    radius: 10

                    color: (notificationMouse.containsMouse || centerModules.notifyOpen)
                        ? centerModules.colors.surface
                        : "transparent"

                    Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }

                    scale: notificationMouse.pressed
                        ? 0.84
                        : notificationMouse.containsMouse ? 1.08 : 1.0

                    Behavior on scale {
                        NumberAnimation { duration: Theme.animDuration(160); easing.type: Easing.OutBack }
                    }

                    Text {
                        anchors.centerIn: parent

                        // campana apagada = DND; con punto = hay notificaciones
                        text: NotificationsBackend.dnd
                            ? "󰂛"
                            : (NotificationsBackend.count > 0 ? "󱅫" : "󰂚")

                        color: NotificationsBackend.dnd
                            ? centerModules.colors.subtext
                            : centerModules.colors.text

                        font.family: Theme.monoFamily
                        font.pixelSize: Theme.fs(19)

                        Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
                    }

                    MouseArea {
                        id: notificationMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton

                        onEntered: centerModules.tipEnter(notificationButton)
                        onExited: centerModules.tipLeave(notificationButton)

                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton)
                                NotificationsBackend.toggleDnd()
                            else
                                centerModules.notificationButtonClicked()
                        }
                    }
                }

                // =================================================
                // SEPARADOR
                // =================================================

                Rectangle {
                    Layout.preferredWidth: Theme.barVertical ? 18 : 1
                    Layout.preferredHeight: Theme.barVertical ? 1 : 15
                    Layout.alignment: Qt.AlignCenter
                    radius: 1
                    color: centerModules.colors.primary
                    opacity: 0.25
                }

                // =================================================
                // WORKSPACES
                // =================================================

                BarFlow {
                    id: workspaces

                    // CoOzey: cajas con contorno, necesitan aire entre ellas
                    gap: Theme.cozy ? 3 : 1

                    // Workspaces en orden numerico (capa común: COMMON/WM.qml)
                    readonly property var sortedWorkspaces: WM.barWorkspacesFor(centerModules.screenName ?? "")

                    Repeater {
                        model: workspaces.sortedWorkspaces

                        delegate: WorkspaceChip {
                            required property var modelData

                            // El botón activo se estira a lo largo de la barra:
                            // a lo ancho (horizontal) o a lo alto (vertical)
                            Layout.preferredWidth: Theme.barVertical ? 34 : (modelData.active ? 27 : 24)
                            Layout.preferredHeight: Theme.barVertical ? (modelData.active ? 27 : 24) : 28

                            Behavior on Layout.preferredWidth {
                                NumberAnimation { duration: Theme.animDuration(180); easing.type: Theme.cozy ? Easing.OutCubic : Easing.OutBack }
                            }

                            Behavior on Layout.preferredHeight {
                                NumberAnimation { duration: Theme.animDuration(180); easing.type: Theme.cozy ? Easing.OutCubic : Easing.OutBack }
                            }

                            active: modelData.active
                            hovered: workspaceMouse.containsMouse
                            pressed: workspaceMouse.pressed

                            // CoOzey usa números reales para que el
                            // conjunto 1–10 sea inequívoco y conserve
                            // la estética pixel. OozeSoft dibuja el número
                            // dentro de una cajita (boxText).
                            label: {
                                if (modelData.urgent)
                                    return "♡"

                                if (Theme.cozy)
                                    return String(modelData.id)

                                if (modelData.id <= 0)
                                    return "✦"

                                return ""
                            }
                            boxText: modelData.id > 0 ? String(modelData.id) : ""

                            // En CoOzey no se escala: a escala fraccionaria el
                            // texto y los bordes pixel se ven borrosos.
                            scale: Theme.cozy ? 1.0
                                : (workspaceMouse.pressed ? 0.82
                                   : workspaceMouse.containsMouse ? 1.06 : 1.0)

                            Behavior on scale {
                                NumberAnimation { duration: Theme.animDuration(140); easing.type: Easing.OutBack }
                            }

                            MouseArea {
                                id: workspaceMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor

                                onClicked: WM.clickWorkspace(modelData)
                            }
                        }
                    }
                }

                // =================================================
                // SEPARADOR
                // =================================================

                Rectangle {
                    Layout.preferredWidth: Theme.barVertical ? 18 : 1
                    Layout.preferredHeight: Theme.barVertical ? 1 : 15
                    Layout.alignment: Qt.AlignCenter
                    radius: 1
                    color: centerModules.colors.primary
                    opacity: 0.25
                }

                // =================================================
                // RELOJ (abre el calendario al pasar el mouse / clic;
                //        clic derecho → calendario con ToDo)
                // =================================================

                Rectangle {
                    id: clockButton

                    property bool calOpen: false

                    // Hora actual: la actualiza el Timer de abajo
                    property var now: new Date()

                    Layout.preferredWidth: Theme.barVertical ? 40 : 70
                    Layout.preferredHeight: Theme.barVertical ? 44 : 30

                    radius: Theme.cardRadius
                    color: (clockMouse.containsMouse || clockButton.calOpen)
                        ? centerModules.colors.surface
                        : "transparent"

                    Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }

                    scale: clockMouse.pressed
                        ? 0.90
                        : clockMouse.containsMouse ? 1.04 : 1.0

                    Behavior on scale {
                        NumberAnimation { duration: Theme.animDuration(160); easing.type: Easing.OutBack }
                    }

                    Text {
                        id: clockText

                        anchors.centerIn: parent

                        // Horizontal: "14:35". Vertical: hora arriba, minutos abajo.
                        text: Theme.barVertical
                            ? Qt.formatTime(clockButton.now, "HH") + "\n" + Qt.formatTime(clockButton.now, "mm")
                            : Qt.formatTime(clockButton.now, "HH:mm")

                        horizontalAlignment: Text.AlignHCenter
                        lineHeight: 0.9

                        color: centerModules.colors.text

                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fs(15)

                        Timer {
                            interval: 1000
                            running: true
                            repeat: true

                            onTriggered: clockButton.now = new Date()
                        }
                    }

                    MouseArea {
                        id: clockMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        acceptedButtons: Qt.LeftButton | Qt.RightButton

                        // Con el calendario grande abierto, el chico no se
                        // abre encima (se pisarían)
                        onEntered: { if (!centerModules.agendaOpen) clockButton.calOpen = true }
                        onExited: calendarCloseTimer.restart()
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton) {
                                clockButton.calOpen = false
                                centerModules.clockRightClicked()
                            } else if (!centerModules.agendaOpen) {
                                clockButton.calOpen = !clockButton.calOpen
                            }
                        }
                    }
                }

                // =================================================
                // OVERVIEW (vista general de los workspaces)
                //   clic → abrir/cerrar el panel (OVERVIEW/Overview.qml)
                // =================================================

                Rectangle {
                    id: overviewButton

                    readonly property string tip: Translations.t("overviewTip")

                    Layout.preferredWidth: Theme.barVertical ? 40 : 36
                    Layout.preferredHeight: 30

                    radius: Theme.cardRadius
                    color: (overviewMouse.containsMouse || centerModules.overviewOpen)
                        ? centerModules.colors.surface
                        : "transparent"

                    Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }

                    scale: overviewMouse.pressed
                        ? 0.84
                        : overviewMouse.containsMouse ? 1.08 : 1.0

                    Behavior on scale {
                        NumberAnimation { duration: Theme.animDuration(160); easing.type: Easing.OutBack }
                    }

                    Text {
                        anchors.centerIn: parent

                        text: "󰕮"

                        // Abierto = color primario, como si fuera parte del panel
                        color: centerModules.overviewOpen
                            ? centerModules.colors.primary
                            : centerModules.colors.text

                        font.family: Theme.monoFamily
                        font.pixelSize: Theme.fs(17)

                        Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
                    }

                    MouseArea {
                        id: overviewMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onEntered: centerModules.tipEnter(overviewButton)
                        onExited: centerModules.tipLeave(overviewButton)

                        onClicked: centerModules.overviewButtonClicked()
                    }
                }
            }
        }

        // ========================================================
        // CALENDARIO
        // ========================================================


        CalendarDrop {
            id: calDrop

            open: clockButton.calOpen

            // Modo Islas: nace de la isla central. Va DETRÁS de la píldora
            // (z negativo) para que el reloj y los botones queden encima.
            island: "center"
            screenName: centerModules.screenName
            z: -1

            align: "center"
            alignMargin: 8
            alignCenter: Theme.barVertical
                ? centerContainer.y + modulesRow.y + modulesRow.height / 2
                  + (clockButton.y + clockButton.height / 2 - modulesRow.height / 2) * Theme.barScale
                : centerContainer.x + modulesRow.x + modulesRow.width / 2
                  + (clockButton.x + clockButton.width / 2 - modulesRow.width / 2) * Theme.barScale
        }

        // ========================================================
        // TOOLTIP
        // ========================================================

        FusedTip {
            id: tip

            open: centerModules.tipOpen
            text: centerModules.tipText

            // Modo Islas: nace de la isla central (cuelga si cabe; si no, la
            // isla se estira). Va DETRÁS de la píldora. Ver FusedTip.
            z: Theme.islandsMode ? -1 : 0
            island: "center"
            screenName: centerModules.screenName

            align: "center"
            alignMargin: 8
            alignCenter: Theme.barVertical ? centerModules.tipCenterY : centerModules.tipCenterX

            // Se desliza entre botones SOLO a lo largo de la barra; el otro eje
            // es el que se anima al abrir/cerrar (queda pegado a la barra)
            Behavior on x {
                enabled: tip.shown && !Theme.barVertical && !tip.hull
                NumberAnimation { duration: Theme.animDuration(160); easing.type: Easing.OutCubic }
            }
            Behavior on y {
                enabled: tip.shown && Theme.barVertical
                NumberAnimation { duration: Theme.animDuration(160); easing.type: Easing.OutCubic }
            }
        }

        // Cierre con retraso: permite pasar el mouse del reloj al
        // calendario sin que se cierre en el medio.
        Timer {
            id: calendarCloseTimer

            interval: 250
            repeat: false

            onTriggered: {
                if (!clockMouse.containsMouse && !calDrop.hovered)
                    clockButton.calOpen = false
            }
        }

        Connections {
            target: calDrop

            function onHoveredChanged() {
                if (!calDrop.hovered)
                    calendarCloseTimer.restart()
            }
        }
    }
}
