import Quickshell
import Quickshell.Wayland
import QtQuick

import "./CENTER"
import "./LEFT"
import "./RIGHT"
import "./components"
import "../COMMON"


Variants {
    id: barModule
    // Modo Píldora reemplaza a la barra/islas por completo.

    model: Theme.pillMode ? [] : Quickshell.screens

    // Se emite cuando tocan el botón de menú en cualquier pantalla.

    signal menuButtonClicked(var screen)
    // Idem para el botón de notificaciones (CenterModules) -> Notify.
    signal notificationButtonClicked(var screen)
    // Idem para el botón del Overview (junto al reloj) -> OVERVIEW/Overview.qml.
    signal overviewButtonClicked(var screen)
    // Clic derecho en el reloj (CenterModules) -> AGENDA/AgendaPopup.qml.
    signal agendaButtonClicked(var screen)
    // Idem para el mpris del módulo izquierdo -> panel Mpris.
    signal mprisButtonClicked(var screen)
    // Idem para el ⏻ del módulo izquierdo -> POWER/PowerMenu.qml.
    signal powerButtonClicked(var screen)
    // Idem para el botón de audio del módulo derecho -> panel AudioMenu.
    signal audioButtonClicked(var screen)
    // Se abrió el menú de un ícono de la bandeja (módulo derecho): shell.qml
    // cierra los demás popups, así no se apilan.
    signal trayMenuOpened()

    // shell.qml los mantiene al día: sirven para que el botón/campana
    // se vea "activo" mientras su popup está abierto (y así se lea
    // como una sola pieza con el panel que cuelga de él).
    property bool menuOpen: false
    property bool notifyOpen: false
    property bool overviewOpen: false
    property bool agendaOpen: false
    property bool mprisOpen: false
    // Idem para el panel de audio.
    property bool audioOpen: false
    // Hay ALGÚN popup abierto (menu/notify/network/audio/mpris). Los módulos
    // izquierdo y derecho lo usan para esconder sus tooltips; el derecho además
    // cierra el menú de la bandeja.
    property bool popupOpen: false
    // Se están recargando los colores por un cambio de wallpaper (o de
    // esquema): la barra, el botón ❄ y los módulos se esconden mientras dure.
    // Abrir el selector de wallpapers NO los esconde.
    property bool wallpaperChanging: false

    // Mismo criterio que Left/Center/RightModules: poné cualquiera en false
    // para que la barra y el botón ❄ dejen de esconderse por ese motivo.
    property bool hideOnFullscreen: true
    property bool hideOnWallpaperChange: true
    // Esquinas curvas en las 4 esquinas del área de trabajo (radio:
    // Theme.screenCorner). shell.qml lo mantiene al día: se persiste y se
    // cambia desde el botón del Menú o por IPC (`corners toggle`).
    // Con la barra flotante (Theme.barFloating) el marco se apaga solo y
    // vuelve cuando se desactiva el modo flotante: esta preferencia no se pierde.
    property bool screenCorners: true

    // ── Brazos del marco para las esquinas (ver BAR/components/FrameCorner.qml) ──
    // Mismo gate que usa Border.active: marco prendido, estilo "curved",
    // barra no separada/flotante y no reconstruyéndose. Sin esto (estilo
    // "corners", o marco apagado) los 4 brazos quedan en 0 y FrameCorner
    // se comporta exactamente como antes (cuadrado r×r simple).
    readonly property bool framArmsActive: Theme.frameOn && barModule.screenCorners && Theme.frameCurved
        && !Theme.barSeparated && !Theme.barRebuilding
    // Grosor del borde recto contiguo a cada lado de pantalla, o 0 si ese
    // lado lo cubre la barra (no hay borde ahí: BAR/Border.qml no lo dibuja,
    // ver showTop/showBottom/showLeft/showRight en ese archivo — misma
    // condición acá para que ambos calcen exacto).
    readonly property real armTop:    (barModule.framArmsActive && Theme.frameThickness > 0 && Theme.barPosition !== "top")    ? Theme.frameThickness : 0
    readonly property real armBottom: (barModule.framArmsActive && Theme.frameThickness > 0 && Theme.barPosition !== "bottom") ? Theme.frameThickness : 0
    readonly property real armLeft:   (barModule.framArmsActive && Theme.frameThickness > 0 && Theme.barPosition !== "left")   ? Theme.frameThickness : 0
    readonly property real armRight:  (barModule.framArmsActive && Theme.frameThickness > 0 && Theme.barPosition !== "right")  ? Theme.frameThickness : 0

    // La pieza de esquina (cuarto de círculo que "muerde" el ángulo recto)
    // vive en BAR/components/FrameCorner.qml: fusiona lo que era esto
    // mismo definido acá inline con BAR/components/ConcaveCurves.qml (antes
    // sin usar), y lee su radio de Theme.frameCornerRadius según el estilo
    // activo ("corners" | "curved", Ajustes → Avanzado → Interfaz → Marco).

    delegate: Component {
        // Envuelto en Item porque hay varias ventanas por pantalla: el
        // fondo de la barra (capa Bottom, detrás de Waybar), el botón de
        // menú y el módulo central (capa Overlay, encima de Waybar).
        Item {
            id: screenRoot
            property var modelData

            // Barra + botón ❄ se esconden igual que los módulos: fullscreen
            // en ESTA pantalla, o recarga de colores por cambio de wallpaper.
            readonly property bool suppressed:
                (barModule.hideOnFullscreen && FullscreenState.isOn(modelData))
                || (barModule.hideOnWallpaperChange && barModule.wallpaperChanging)

        // ─── Fondo de la barra ───────────────────────────────────
        // Mismo color (Theme.bg) que todos los popups: por eso se
        // ven como una sola pieza. 
        PanelWindow {
            id: barPanel
            screen: modelData
            // Se recrea al mover/flotar la barra (ver Theme.barRebuilding)
            visible: !Theme.barRebuilding

            // Posición: arriba, abajo, izquierda o derecha (Ajustes → Interfaz).
            // Horizontal: pegada a un borde y a los dos costados. Vertical: pegada
            // a un costado y a arriba+abajo. En modo flotante (solo horizontal) la
            // barra se despega Theme.barEdge de los bordes. El espacio que reserva
            // (exclusive zone) lo calcula el compositor: grosor + margen.
            anchors {
                top: !Theme.barAtBottom
                bottom: Theme.barAtBottom || Theme.barVertical
                left: !Theme.barVertical || !Theme.barAtRight
                right: !Theme.barVertical || Theme.barAtRight
            }
            margins.top: Theme.barEdge
            margins.bottom: Theme.barEdge
            margins.left: Theme.barEdge
            margins.right: Theme.barEdge
            // El tamaño solo cuenta en el eje que NO está anclado a los dos lados
            implicitWidth: Theme.barVertical ? Theme.barThickness : 0
            implicitHeight: Theme.barVertical ? 0 : Theme.barHeight

            // La ventana NO se desmapea (visible: false): reserva el espacio
            // de la barra (exclusive zone) y, si desaparece, Mango reacomoda
            // todas las ventanas hacia arriba y de nuevo hacia abajo cada vez
            // que se abre el selector. Solo se apaga el fondo, con un fade corto.
            color: "transparent"

            SkinRect {
                anchors.fill: parent
                color: Theme.bg
                radius: Theme.barRadius
                raised: Theme.cozy && Theme.barFloating
                depth: 2
                notch: 0   // bordes rectos: sin esquinas escalonadas
                inkColor: Theme.ink
                // Modo Islas: el fondo se apaga (fade) y quedan solo las tres
                // píldoras. La ventana sigue ahí: reserva el espacio de la barra.
                opacity: (screenRoot.suppressed || Theme.islandsMode) ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: Theme.animDuration(220); easing.type: Easing.OutCubic } }

                // CoOzey: contorno de "tinta" en la cara de la barra (la que da al
                // escritorio), como el borde de una tabla de madera.
                Rectangle {
                    readonly property real t: Theme.inkWidth
                    visible: Theme.cozy && !Theme.barSeparated
                    color: Theme.ink
                    x: Theme.barVertical ? (Theme.barAtRight ? 0 : parent.width - t) : 0
                    y: Theme.barVertical ? 0 : (Theme.barAtBottom ? 0 : parent.height - t)
                    width: Theme.barVertical ? t : parent.width
                    height: Theme.barVertical ? parent.height : t
                }
            }

            // // ─── Enviar detrás de Waybar ─────────────────────────
            // WlrLayershell.layer: WlrLayer.Bottom
            // WlrLayershell.namespace: "quickshell-background-bar"
            // exclusiveZone: 1
        }

        // ─── Esquinas de pantalla (las 4) ────────────────────────
        // Piecitas del color de la barra (Theme.bg) pegadas a las cuatro
        // esquinas del área de trabajo: dos justo debajo de la barra y dos
        // en el borde inferior. Cada una "muerde" el ángulo recto, así que
        // lo que se ve (escritorio/ventanas) queda con las 4 esquinas
        // redondeadas, como un marco que nace de la barra.
        //
        // Se activan/desactivan desde el Menú (botón junto al usuario) o
        // por IPC (`corners toggle`). Van en la capa Top (igual que la
        // barra, debajo de los popups) y son 100 % click-through.

        // ── Superiores: justo debajo de la barra (o en el borde de arriba si
        //    la barra está abajo) ──
        // El marco NO se puede activar con la barra flotante: dos siluetas
        // redondeadas a la vez (píldora + esquinas) se pisan visualmente.
        PanelWindow {
            id: cornersTop
            screen: modelData
            anchors { top: true; left: true; right: true }
            // Solo la barra ARRIBA empuja esta franja hacia abajo
            margins.top: (Theme.barVertical || Theme.barAtBottom) ? 0 : Theme.barOffset
            // Alto = radio + brazo de arriba (si el borde de arriba existe,
            // p. ej. barra abajo/vertical): antes era solo el radio, y la
            // curva no tenía lugar para "abrirse" hasta el ancho real del
            // borde antes de calzar con él.
            implicitHeight: Theme.frameCornerRadius + barModule.armTop
            color: "transparent"
            // Reserva ese alto (radio + brazo de borde) para que las
            // ventanas no queden bajo la curva: antes era -1 (overlay puro)
            // y el compositor las centraba/maximizaba como si el marco no
            // existiera.
            exclusiveZone: -1
            visible: Theme.frameOn && barModule.screenCorners && !Theme.barSeparated && !Theme.barRebuilding && Theme.frameCornerRadius > 0
            WlrLayershell.namespace: "quickshell-screen-corners-top"
            // Overlay (no Top): así queda SIEMPRE por encima del fondo de la
            // barra sin importar el orden real de creación/recreación de las
            // ventanas (Theme.barRebuilding), que es lo que causaba el
            // cuadradito de color de barra asomando por fuera del arco.
            WlrLayershell.layer: WlrLayer.Overlay

            // Región vacía = todo el input pasa a lo que hay debajo
            mask: Region {}

            Item {
                anchors.fill: parent
                // Mismo fade que el fondo de la barra (fullscreen / wallpaper)
                opacity: screenRoot.suppressed ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: Theme.animDuration(150); easing.type: Easing.OutCubic } }

                // Barra vertical: la esquina del lado de la barra se corre
                // para quedar pegada a ella (no debajo de la barra)
                FrameCorner {
                    anchors.left: parent.left
                    anchors.leftMargin: (Theme.barVertical && !Theme.barAtRight) ? Theme.barOffset : 0
                    anchors.top: parent.top
                    armX: barModule.armLeft
                    armY: barModule.armTop
                }
                FrameCorner {
                    anchors.right: parent.right
                    anchors.rightMargin: (Theme.barVertical && Theme.barAtRight) ? Theme.barOffset : 0
                    anchors.top: parent.top
                    atRight: true
                    armX: barModule.armRight
                    armY: barModule.armTop
                }
            }
        }

        // ── Inferiores: pegadas al borde de abajo (o justo encima de la barra
        //    si la barra está abajo) ──
        PanelWindow {
            id: cornersBottom
            screen: modelData
            anchors { bottom: true; left: true; right: true }
            margins.bottom: (!Theme.barVertical && Theme.barAtBottom) ? Theme.barOffset : 0
            implicitHeight: Theme.frameCornerRadius + barModule.armBottom
            color: "transparent"
            // Ídem cornersTop: reserva el espacio real de la curva inferior.
            exclusiveZone: -1
            visible: Theme.frameOn && barModule.screenCorners && !Theme.barSeparated && !Theme.barRebuilding && Theme.frameCornerRadius > 0
            WlrLayershell.namespace: "quickshell-screen-corners-bottom"
            // Ídem de arriba: Overlay fijo, no Top por orden de creación.
            WlrLayershell.layer: WlrLayer.Overlay

            mask: Region {}

            Item {
                anchors.fill: parent
                opacity: screenRoot.suppressed ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: Theme.animDuration(150); easing.type: Easing.OutCubic } }

                FrameCorner {
                    anchors.left: parent.left
                    anchors.leftMargin: (Theme.barVertical && !Theme.barAtRight) ? Theme.barOffset : 0
                    anchors.bottom: parent.bottom
                    atBottom: true
                    armX: barModule.armLeft
                    armY: barModule.armBottom
                }
                FrameCorner {
                    anchors.right: parent.right
                    anchors.rightMargin: (Theme.barVertical && Theme.barAtRight) ? Theme.barOffset : 0
                    anchors.bottom: parent.bottom
                    atRight: true
                    atBottom: true
                    armX: barModule.armRight
                    armY: barModule.armBottom
                }
            }
        }

        // ─── Marco continuo (estilo "curved") ──────────────────────
        // 3 líneas de borde (BAR/Border.qml) que completan, junto con las
        // esquinas de arriba, el marco cuando el estilo activo es "curved"
        // (Ajustes → Avanzado → Interfaz → Marco). En estilo "corners" esto
        // queda simplemente invisible (active: false) y no dibuja nada.
        Border {
            screen: modelData
            suppressed: screenRoot.suppressed
            active: Theme.frameOn && barModule.screenCorners && Theme.frameCurved
                    && !Theme.barSeparated && !Theme.barRebuilding
        }

        // ─── Botón de menú ────────────────────────────────────────
        // Capa Overlay: se dibuja por encima de Waybar.
        PanelWindow {
            id: menuButtonPanel
            screen: modelData
            // Sigue a la barra. Horizontal: esquina derecha, arriba o abajo (y
            // corrido Theme.barEdge hacia adentro si es flotante). Vertical: el
            // extremo INFERIOR de la barra, del lado donde esté (izq. o der.).
            anchors {
                top: !Theme.barVertical && !Theme.barAtBottom
                bottom: Theme.barVertical || Theme.barAtBottom
                right: !Theme.barVertical || Theme.barAtRight
                left: Theme.barVertical && !Theme.barAtRight
            }
            margins.top: Math.max(Theme.barEdge, barModule.armTop)
            margins.bottom: Math.max(Theme.barEdge, barModule.armBottom)
            // Marco curvo: el botón ❄ es el elemento más pegado al borde
            // derecho de todo el módulo derecho.
            margins.right: Math.max(Theme.barEdge, barModule.armRight)
            Behavior on margins.top { NumberAnimation { duration: Theme.animDuration(200); easing.type: Easing.OutCubic } }
            Behavior on margins.bottom { NumberAnimation { duration: Theme.animDuration(200); easing.type: Easing.OutCubic } }
            Behavior on margins.right { NumberAnimation { duration: Theme.animDuration(200); easing.type: Easing.OutCubic } }
            // Theme.menuButtonWidth: RightModules lo usa para quedarse junto a
            // este botón (a su izquierda, o encima si la barra es vertical)
            // sin pisarlo
            implicitWidth: Theme.barVertical ? Theme.barThickness : Theme.menuButtonWidth
            implicitHeight: Theme.barVertical ? Theme.menuButtonWidth : Theme.barHeight
            color: "transparent"
            // Sin exclusive zone, así que acá sí se puede desmapear sin
            // mover nada (igual que las ventanas de los módulos).
            // Modo Islas: el ❄ vive dentro de la isla derecha (RightModules)
            visible: !screenRoot.suppressed && !Theme.barRebuilding && !Theme.islandsMode
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell-menu-button"
            exclusiveZone: -1

            Rectangle {
                id: menuBtnBg
                anchors.centerIn: parent
                width: 30
                height: 26
                radius: 8
                color: (menuBtnArea.containsMouse || barModule.menuOpen) ? Theme.surface : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }

                // Pequeño "rebote" al presionar (× escala de la barra)
                scale: Theme.barScale * (menuBtnArea.pressed ? 0.85 : (menuBtnArea.containsMouse ? 1.12 : 1.0))
                Behavior on scale { NumberAnimation { duration: Theme.animDuration(140); easing.type: Easing.OutBack } }

                Text {
                    anchors.centerIn: parent
                    text: "❄"
                    color: Theme.text
                    font.pixelSize: Theme.fs(30)
                    font.family: Theme.fontFamily
                }

                MouseArea {
                    id: menuBtnArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: barModule.menuButtonClicked(modelData)
                }
            }
        }

        CenterModules {
            id: centerModules
            targetScreen: modelData
            // Barra vertical: el bloque central se corre para no pisar a los
            // otros dos (que crecen desde arriba y desde abajo)
            topReserve: leftModules.extent
            bottomReserve: rightModules.extent
            notifyOpen: barModule.notifyOpen
            overviewOpen: barModule.overviewOpen
            agendaOpen: barModule.agendaOpen
            popupOpen: barModule.popupOpen
            wallpaperChanging: barModule.wallpaperChanging
            onNotificationButtonClicked: barModule.notificationButtonClicked(modelData)
            onOverviewButtonClicked: barModule.overviewButtonClicked(modelData)
            onClockRightClicked: barModule.agendaButtonClicked(modelData)
        }

        LeftModules {
            id: leftModules
            targetScreen: modelData
            mprisOpen: barModule.mprisOpen
            popupOpen: barModule.popupOpen
            wallpaperChanging: barModule.wallpaperChanging
            // Marco curvo: cuánto brazo recto hay pegado al borde donde vive
            // este bloque, para que la píldora arranque justo donde termina
            // el marco (fusionados) en vez de dejar un hueco raro (o pisarlo
            // si el marco es más grueso que el margen de siempre).
            frameArmLeft: barModule.armLeft
            frameArmTop: barModule.armTop
            onMprisButtonClicked: barModule.mprisButtonClicked(modelData)
            onPowerButtonClicked: barModule.powerButtonClicked(modelData)
        }

        RightModules {
            id: rightModules
            targetScreen: modelData
            // Barra vertical: alto del bloque central, para limitar cuántas
            // ventanas del taskbar entran sin pisarlo
            centerHeight: centerModules.pillExtent
            audioOpen: barModule.audioOpen
            menuOpen: barModule.menuOpen
            popupOpen: barModule.popupOpen
            wallpaperChanging: barModule.wallpaperChanging
            // Ídem LeftModules: el botón ❄ ya se fusiona solo (ver
            // menuButtonPanel más arriba); estos brazos son para que la
            // píldora mantenga su mismo respiro de siempre CONTRA el botón,
            // ya corrido, en horizontal (derecha) y en vertical (abajo).
            frameArmRight: barModule.armRight
            frameArmBottom: barModule.armBottom
            onAudioButtonClicked: barModule.audioButtonClicked(modelData)
            // Modo Islas: el ❄ está dentro de la isla derecha
            onMenuButtonClicked: barModule.menuButtonClicked(modelData)
            onTrayMenuOpened: barModule.trayMenuOpened()
        }
        }
    }
}
