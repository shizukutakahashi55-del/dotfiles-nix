import Quickshell
import Quickshell.Io
import Quickshell.Wayland

import QtQuick
import QtQuick.Layouts

import "../../COMMON"
import "../../LANG"
import "../../MPRIS"

// ─────────────────────────────────────────────────────────────────
// LeftModules — reemplaza los módulos izquierdos de Waybar:
//   ⏻ power (POWER/PowerMenu.qml)  |  idioma  |  mpris
//
// Mismo criterio que CenterModules: píldora del color de la barra en la
// capa Overlay, y se oculta en fullscreen y mientras se recargan los
// colores por un cambio de wallpaper.
//
// El mpris se puede plegar con su mini botón ◂▸ (Theme.mprisCompact, se
// guarda en ui.json): queda solo el ícono de estado (▶ / ⏸ / ♪) y el tooltip
// sigue mostrando la canción.
//
// Tooltips: hay UNO solo (FusedTip, el mismo de RightModules), que cuelga de
// la barra con las curvas cóncavas, el color y la animación de los popups.
// Los botones no dibujan el suyo: avisan tipEnter / tipLeave y este host lo
// muestra (se desliza de un botón al siguiente en vez de cerrarse y abrirse).
// Contrato: cualquier Item con tooltip tiene una propiedad `string tip`.
// ─────────────────────────────────────────────────────────────────
Item {
    id: leftModules

    // Clic izquierdo en el mpris: shell.qml abre/cierra el panel Mpris
    signal mprisButtonClicked()
    // Clic en el ⏻: shell.qml abre/cierra el menú de energía (POWER/PowerMenu.qml)
    signal powerButtonClicked()

    // Los setea Bar.qml
    property bool mprisOpen: false
    property bool wallpaperChanging: false
    // Hay algún popup abierto: los tooltips se esconden mientras tanto
    property bool popupOpen: false

    // Marco curvo (Bar.qml -> barModule.armLeft/armTop): grosor del brazo
    // recto del marco pegado al borde donde vive este bloque. 0 si el marco
    // está apagado, es estilo "corners", o el brazo lo tapa la barra. Se usa
    // para que la píldora arranque justo donde termina el marco (fusionados)
    // en vez de dejar un hueco raro entre los dos.
    property real frameArmLeft: 0
    property real frameArmTop: 0

    property var targetScreen

    // ── Configuración ────────────────────────────────────────────
    property bool hideOnFullscreen: true
    property bool hideOnWallpaperChange: true
    property int leftMargin: 6
    property int songMaxWidth: 260

    readonly property bool suppressed:
        (hideOnFullscreen && FullscreenState.isOn(targetScreen))
        || (hideOnWallpaperChange && wallpaperChanging)

    // ── Modo Islas: publicar dónde está esta isla (coords de pantalla) ──
    // FusedPanel lo lee (IslandState) para saber de dónde nace cada popup.
    readonly property string screenName: targetScreen ? targetScreen.name : ""
    readonly property var islandRect: {
        if (!Theme.islandsMode || !targetScreen) return null
        return {
            x: Math.max(leftModules.leftMargin, leftModules.frameArmLeft) + Theme.barEdge,
            y: Theme.barAtBottom ? targetScreen.height - Theme.barEdge - pill.height : Theme.barEdge,
            w: pill.width,
            h: pill.height
        }
    }
    function publishIsland() {
        if (leftModules.screenName === "") return
        if (leftModules.islandRect) IslandState.report(leftModules.screenName, "left", leftModules.islandRect)
        else IslandState.clear(leftModules.screenName, "left")
    }
    onIslandRectChanged: publishIsland()
    Component.onCompleted: publishIsland()

    // Barra vertical: hasta dónde llega este bloque desde el borde de ARRIBA
    // (Bar.qml se lo pasa al módulo central para que no lo pise). En
    // horizontal no se usa.
    readonly property real extent: Theme.barVertical
        ? Theme.barEdge + Math.max(leftModules.leftMargin, leftModules.frameArmTop) + pill.height
        : 0

    // ============================================================
    // ESTADO: MPRIS  (nativo, ver MPRIS/MprisBackend.qml)
    // ============================================================

    // Nativo (Quickshell.Services.Mpris vía MprisBackend): sin procesos ni
    // `playerctl -F`; llega por señales D-Bus y no cuesta nada sin players.
    readonly property string mprisStatus:
        MprisBackend.activePlayers.length > 0 ? MprisBackend.currentStatus : ""   // Playing | Paused | Stopped | ""
    readonly property string mprisArtist: MprisBackend.currentArtist
    readonly property string mprisTitle: MprisBackend.currentTitle

    readonly property string songLabel:
        (mprisArtist !== "" && mprisTitle !== "")
            ? mprisArtist + " - " + mprisTitle
            : (mprisTitle !== "" ? mprisTitle : mprisArtist)

    readonly property bool hasSong: songLabel !== ""

    // Tooltip del mpris: título arriba y artista abajo (en la barra horizontal
    // se ve "artista - título" pero recortado a songMaxWidth; en la vertical
    // no se ve nada, solo el ícono)
    readonly property string songTip: {
        if (!hasSong) return Translations.t("mprisNoPlaying")
        if (mprisTitle !== "" && mprisArtist !== "") return mprisTitle + "\n" + mprisArtist
        return songLabel
    }

    // ============================================================
    // TOOLTIP COMPARTIDO (FusedTip)
    // ============================================================

    property var tipTarget: null      // Item que está bajo el mouse
    property real tipCenterX: 0       // su centro, en coords de esta ventana
    property real tipCenterY: 0       // (X si la barra es horizontal, Y si es vertical)
    property bool tipShown: false     // pasó el retardo y sigue encima
    property string tipText: ""       // último texto no vacío (para la animación de cierre)

    // Texto en vivo: si cambia la canción con el mouse encima, el tooltip la sigue
    readonly property string liveTip: tipTarget ? String(tipTarget.tip ?? "") : ""
    onLiveTipChanged: { if (liveTip !== "") tipText = liveTip }

    readonly property bool tipAllowed: !popupOpen && !suppressed
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

    // Si la isla cambia de tamaño con el tooltip armado (plegar el mpris, otra
    // canción, otro idioma…) los botones se corren: se vuelve a medir el centro
    // del botón, si no el tooltip queda donde estaba.
    function tipRefresh() {
        if (!tipTarget) return
        const c = tipTarget.mapToItem(null, tipTarget.width / 2, tipTarget.height / 2)
        tipCenterX = c.x
        tipCenterY = c.y
    }

    Connections {
        target: pill
        function onWidthChanged() { Qt.callLater(leftModules.tipRefresh) }
    }

    function tipLeave(item) {
        if (tipTarget !== item) return
        tipShowTimer.stop()
        tipHideTimer.restart()
    }

    // Retardo de aparición (como el `delay: 600` de los ToolTip de antes)
    Timer { id: tipShowTimer; interval: 500; repeat: false; onTriggered: leftModules.tipShown = true }
    // Colchón al cruzar de un botón a otro: si entra otro antes, no se cierra
    Timer { id: tipHideTimer; interval: 150; repeat: false; onTriggered: leftModules.tipShown = false }

    // Si se oculta la barra, el tooltip no debe quedar "armado"
    onSuppressedChanged: { if (suppressed) tipShown = false }

    // ============================================================
    // ESTADO: IDIOMA DEL TECLADO
    // ============================================================
    // Vive en COMMON/KeyboardLayout.qml (singleton compartido con el botón
    // de teclado del Menu): así los dos siempre muestran lo mismo.
    // El teclado de referencia se configura ahí (KeyboardLayout.keyboardName).

    // ============================================================
    // BOTÓN REUTILIZABLE (mismo look que los del módulo central)
    // ============================================================
    // Sin ToolTip propio: emite hoverEntered / hoverExited y el host muestra
    // el tooltip compartido usando la propiedad `tip`.

    component PillButton: SkinRect {
        id: btn

        property string tip: ""
        property bool active: false
        property real hoverScale: 1.06

        // Lo que se declare adentro va a la fila interna
        default property alias content: row.data

        signal clicked(var mouse)
        signal scrolled(var wheel)
        signal hoverEntered()
        signal hoverExited()

        // Horizontal: 30 de alto y el ancho del contenido. Vertical: 40 de
        // ancho (la barra mide 44) y el alto del contenido apilado.
        Layout.preferredHeight: Theme.barVertical ? Math.max(30, row.implicitHeight + 12) : 30
        Layout.preferredWidth: Theme.barVertical ? 40 : Math.max(34, row.implicitWidth + 16)

        radius: Theme.cardRadius
        raised: Theme.cozy && (area.containsMouse || btn.active)
        depth: 2

        color: (area.containsMouse || btn.active) ? Theme.surface : "transparent"
        Behavior on color { ColorAnimation { duration: 150 } }

        scale: Theme.cozy ? 1.0 : (area.pressed ? 0.90 : (area.containsMouse ? btn.hoverScale : 1.0))
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }

        // Fila (horizontal) o columna (vertical: ícono arriba, texto abajo)
        BarFlow {
            id: row
            anchors.centerIn: parent
            gap: Theme.barVertical ? 1 : 6
        }

        MouseArea {
            id: area

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton

            onEntered: btn.hoverEntered()
            onExited: btn.hoverExited()
            onClicked: mouse => btn.clicked(mouse)
            onWheel: wheel => btn.scrolled(wheel)
        }
    }

    // ============================================================
    // VENTANA
    // ============================================================

    PanelWindow {
        id: leftPanel

        screen: leftModules.targetScreen

        // Barra arriba → ancla arriba; barra abajo → abajo. Flotante: corrida
        // Theme.barEdge hacia adentro para quedar sobre la píldora de la barra.
        // Barra vertical: este bloque queda arriba, pegado al costado de la barra.
        anchors {
            top: !Theme.barAtBottom
            bottom: Theme.barAtBottom
            left: !Theme.barAtRight
            right: Theme.barVertical && Theme.barAtRight
        }
        margins.top: Theme.barEdge + (Theme.barVertical ? Math.max(leftModules.leftMargin, leftModules.frameArmTop) : 0)
        margins.bottom: Theme.barEdge
        // Fusión con el marco: nunca menos que el margen de siempre (así se
        // ve igual que hoy con el marco apagado), pero si el brazo recto es
        // más grueso que ese margen, la píldora se corre para arrancar justo
        // donde termina el marco — sin hueco, y sin clavarse dentro de él.
        margins.left: Theme.barVertical ? 0 : Math.max(leftModules.leftMargin, leftModules.frameArmLeft) + Theme.barEdge
        margins.right: 0
        Behavior on margins.left { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on margins.top { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        // Más grande que la píldora: deja lugar al tooltip (hasta 300 px de
        // texto + relleno + curvas, y varias líneas si hace word-wrap).
        // Solo la píldora recibe clics (mask); el resto es click-through.
        // Vertical: el ancho incluye lugar para el tooltip y el alto suma un
        // poco más que la píldora (el tooltip se centra en el botón).
        implicitWidth: Theme.barVertical
            ? Theme.barThickness + Math.round(340 * Theme.barScale)
            : Math.max(pill.width + 20, Math.round(360 * Theme.barScale))
        implicitHeight: Theme.barVertical
            ? pill.height + Math.round(120 * Theme.barScale)
            : Theme.barHeight + Math.round(120 * Theme.barScale)

        color: "transparent"

        // Oculta de verdad (no solo transparente)
        visible: !leftModules.suppressed && !Theme.barRebuilding

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-left-modules"

        exclusiveZone: -1

        mask: Region { item: pill }

        Item {
            id: pill

            // Vertical: pegada al lado de la barra (la ventana es más ancha por el tooltip)
            x: (Theme.barVertical && Theme.barAtRight) ? parent.width - width : 0
            // Barra abajo: pegada al borde inferior; los tooltips van arriba
            y: (!Theme.barVertical && Theme.barAtBottom) ? parent.height - height : 0
            // La fila se dibuja escalada (Ajustes → Barra)
            width: Theme.barVertical ? Theme.barThickness : modulesRow.implicitWidth * Theme.barScale + 14
            height: Theme.barVertical ? modulesRow.implicitHeight * Theme.barScale + 14 : Theme.barHeight

            SkinRect {
                anchors.fill: parent
                radius: Theme.islandRadius
                raised: Theme.cozy && Theme.islandsMode
                depth: 2
                inkColor: Theme.ink
                color: Theme.bg
            }

            BarFlow {
                id: modulesRow

                anchors.centerIn: parent
                gap: 2
                scale: Theme.barScale

                // ── POWER ────────────────────────────────────
                PillButton {
                    id: powerBtn

                    tip: Translations.t("powerMenuTip")

                    onHoverEntered: leftModules.tipEnter(powerBtn)
                    onHoverExited: leftModules.tipLeave(powerBtn)

                    onClicked: leftModules.powerButtonClicked()

                    Text {
                        text: "⏻"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fs(17)
                    }
                }

                Rectangle {
                    Layout.preferredWidth: Theme.barVertical ? 18 : 1
                    Layout.preferredHeight: Theme.barVertical ? 1 : 15
                    Layout.alignment: Qt.AlignCenter
                    radius: 1
                    color: Theme.primary
                    opacity: 0.25
                }

                // ── IDIOMA (clic: siguiente layout) ──────────
                PillButton {
                    id: langBtn

                    tip: Translations.t("langSwitchTip")

                    onHoverEntered: leftModules.tipEnter(langBtn)
                    onHoverExited: leftModules.tipLeave(langBtn)

                    onClicked: KeyboardLayout.next()

                    // Vertical: el ícono va arriba de la etiqueta (ahorra ancho)
                    Text {
                        visible: Theme.barVertical
                        Layout.alignment: Qt.AlignHCenter
                        text: "󰌌"
                        color: Theme.subtext
                        font.family: Theme.monoFamily
                        font.pixelSize: Theme.fs(14)
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: (Theme.barVertical ? "" : "󰌌 ") + KeyboardLayout.label
                        color: Theme.text
                        font.family: Theme.monoFamily
                        font.pixelSize: Theme.fs(13)
                    }
                }

                Rectangle {
                    Layout.preferredWidth: Theme.barVertical ? 18 : 1
                    Layout.preferredHeight: Theme.barVertical ? 1 : 15
                    Layout.alignment: Qt.AlignCenter
                    radius: 1
                    color: Theme.primary
                    opacity: 0.25
                }

                // ── MPRIS ─────────────────────────────
                //   clic izq → abre el panel Mpris
                //   clic der → siguiente canción
                //   scroll   → anterior / siguiente
                PillButton {
                    id: mprisBtn

                    active: leftModules.mprisOpen
                    hoverScale: 1.03

                    // Título + artista completos: en la barra vertical no caben
                    // y en la horizontal se recortan a songMaxWidth
                    tip: leftModules.songTip

                    onHoverEntered: leftModules.tipEnter(mprisBtn)
                    onHoverExited: leftModules.tipLeave(mprisBtn)

                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton)
                            MprisBackend.runCtl(["next"])
                        else
                            leftModules.mprisButtonClicked()
                    }

                    onScrolled: wheel => {
                        MprisBackend.runCtl([wheel.angleDelta.y > 0 ? "previous" : "next"])
                    }

                    Text {
                        text: leftModules.mprisStatus === "Playing" ? "󰎈"
                            : leftModules.mprisStatus === "Paused"  ? "󰏤"
                            : "󰝛"
                        color: leftModules.mprisStatus === "Playing" ? Theme.primary : Theme.subtext
                        font.family: Theme.monoFamily
                        font.pixelSize: Theme.fs(16)
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    // Plegado (o barra vertical): solo queda el ícono de arriba
                    Text {
                        visible: !Theme.barVertical && !Theme.mprisCompact
                        Layout.maximumWidth: leftModules.songMaxWidth

                        text: leftModules.hasSong
                            ? leftModules.songLabel
                            : Translations.t("mprisNoPlaying")
                        elide: Text.ElideRight

                        color: leftModules.hasSong ? Theme.text : Theme.subtext
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fs(12)
                    }
                }

                // ── Plegar / desplegar el mpris ───────────────
                // En barra vertical el mpris ya es solo ícono: no hay nada
                // que plegar, así que el botón no se muestra.
                BarToggle {
                    id: mprisToggle

                    visible: !Theme.barVertical
                    collapsed: Theme.mprisCompact
                    contentAfter: false
                    tip: Translations.t(Theme.mprisCompact ? "barExpand" : "barCollapse")

                    onToggled: Theme.setMprisCompact(!Theme.mprisCompact)
                    onHoverEntered: leftModules.tipEnter(mprisToggle)
                    onHoverExited: leftModules.tipLeave(mprisToggle)
                }
            }
        }

        // ── Tooltip compartido ──────────────────────────────────
        // Pegado a la barra (debajo de ella, encima si la barra está abajo, o
        // al costado de la píldora si es vertical), centrado en el botón y sin
        // salirse de esta ventana. Solo se dibuja: no recibe clics.
        FusedTip {
            id: tip

            open: leftModules.tipOpen
            text: leftModules.tipText

            // Horizontal: y fijo pegado a la barra; x se centra en el botón.
            // Vertical: x fijo pegado a la píldora (a su derecha si la barra está
            // a la izquierda, a su izquierda si está a la derecha); y se centra.
            // ── Modo Islas ──────────────────────────────────────────
            // Nace de la isla izquierda: cuelga de ella si cabe en su tramo
            // plano; si es más ancho (mpris con canción larga, isla plegada…)
            // la isla se estira hasta ser el tooltip (hull) y por eso va DETRÁS
            // de la píldora. Ver FusedTip / FusedPanel.
            z: Theme.islandsMode ? -1 : 0
            island: "left"
            islandRectLocal: Theme.islandsMode
                ? ({ x: pill.x, y: pill.y, w: pill.width, h: pill.height }) : null
            align: "center"
            alignCenter: leftModules.tipCenterX

            x: Theme.barVertical
                ? (Theme.barAtRight ? pill.x - tip.width : Theme.barThickness)
                : (tip.islandActive
                    ? tip.placedAlong
                    : Math.max(0, Math.min(parent.width - width, leftModules.tipCenterX - width / 2)))
            y: Theme.barVertical
                ? Math.max(0, Math.min(parent.height - height, leftModules.tipCenterY - height / 2))
                : (tip.hull ? tip.placedDepth
                            : (Theme.barAtBottom ? pill.y - tip.height : Theme.barHeight))

            // Se desliza entre botones SOLO a lo largo de la barra; el otro eje
            // es el que se anima al abrir/cerrar (queda pegado a la barra)
            Behavior on x {
                enabled: tip.shown && !Theme.barVertical && !tip.hull
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }
            Behavior on y {
                enabled: tip.shown && Theme.barVertical
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }
        }
    }
}
