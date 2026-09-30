// NotifToasts — popups de notificaciones nuevas.

import Quickshell
import Quickshell.Wayland

import QtQuick

import "../COMMON"
import "../NOTIFY"

Item {
    id: root

    property string targetScreen: ""

    property int panelWidth: 400
    property int edgeMargin: 10
    property int maxToasts: 4

    // Modo Píldora: la píldora flota a 10 px del borde y mide 38 px de alto
    // (mismos valores que PILL/Pill.qml). Los toasts se despegan y quedan
    // con un respiro de 6 px debajo/encima de ella.
    readonly property int pillClearance: Theme.pillEdgeGap + Theme.pillHeight + 6

    readonly property bool wanted:
        NotificationsBackend.displayPopups.length > 0 &&
        !NotificationsBackend.centerOpen

    PanelWindow {
        id: win

        screen:
            Quickshell.screens.find(
                s => s.name === root.targetScreen
            ) ?? Quickshell.screens[0]

        visible:
            !Theme.barRebuilding

        color: "transparent"

        exclusiveZone: -1

        // Pantalla completa (top+bottom) y pegada al costado de la barra
        // (right/left según Theme.barVertical/barAtRight), igual que
        // antes: FusedPanel calcula su posición asumiendo que tiene toda
        // esa franja disponible para colocarse a lo largo de la barra.
        anchors {
            top: true
            bottom: true

            right:
                !Theme.barVertical ||
                Theme.barAtRight

            left:
                Theme.barVertical &&
                !Theme.barAtRight
        }

        implicitWidth:
            Math.round(
                root.panelWidth *
                Theme.windowScale
            )
            +
            (
                Theme.barVertical
                    ? Theme.barOffset + 24
                    : Theme.flare * 2 +
                      root.edgeMargin +
                      Theme.barEdge +
                      8
            )

        WlrLayershell.layer:
            WlrLayer.Overlay

        WlrLayershell.namespace:
            "oozeshell-toasts"

        WlrLayershell.keyboardFocus:
            WlrKeyboardFocus.None

        mask: Region {
            item: panel
        }

        FusedPanel {
            id: panel

            open: root.wanted

            panelWidth:
                root.panelWidth

            contentHeight:
                list.height + 24

            instantResize: true

            // Modo Islas / Píldora: los toasts no cuelgan de ninguna isla
            // (llegan en una franja aparte, arriba a la derecha): tarjeta
            // flotante, con un respiro debajo de las islas o de la píldora.
            detached:
                FullscreenState.isOn(
                    win.screen
                ) || Theme.islandsMode || Theme.pillMode

            faceOffset:
                Theme.pillMode
                    ? root.pillClearance
                    : Theme.barOffset +
                      (Theme.islandsMode ? 6 : 0)

            // Único cambio real: centrado a lo largo de la barra en vez
            // de pegado a su extremo (antes "end").
            align: "center"

            alignMargin:
                root.edgeMargin +
                Theme.barEdge

            // Column en vez de ListView: un Column recalcula su alto DE UNA,
            // en la misma pasada, apenas cambia el implicitHeight de
            // cualquier hijo — no en un frame aparte como el ListView. Los
            // toasts no necesitan agrupar por app ni reordenar como el
            // panel principal, solo apilarse y desaparecer, así que no hace
            // falta pagar el costo del ListView (transiciones add/remove/
            // displaced + forceLayout() + settle loop) para conseguir eso.
            // Con esto, la clase entera de bug de overlap por timing queda
            // eliminada acá: no hay una segunda pasada de layout con la que
            // desincronizarse.
            //
            // Trade-off: se pierde la animación de salida en tijera
            // (slide+fade al cerrarse) — el Repeater destruye el delegate
            // apenas sale del modelo, sin transición de remove. Queda el
            // fade de entrada.
            Column {
                id: list

                x: 12
                y: 12

                width:
                    parent.width - 24

                spacing: 8

                Repeater {
                    model: ScriptModel {
                        values:
                            NotificationsBackend
                                .displayPopups
                                .slice(
                                    0,
                                    root.maxToasts
                                )

                        objectProp: "notifId"
                    }

                    delegate: Item {
                        id: toastItem

                        required property var modelData

                        width:
                            list.width

                        implicitHeight:
                            toastCard.implicitHeight

                        height:
                            implicitHeight

                        // Fade de entrada. Arranca en 0 y sube apenas el
                        // delegate termina de crearse.
                        opacity: 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.animDuration(180)
                            }
                        }

                        // El Column reposiciona sus hijos apenas cambia el
                        // alto de cualquiera de ellos (llega un toast nuevo
                        // arriba, uno se cierra, o NotifCard todavía está
                        // asentando su alto real). Sin este Behavior ese
                        // reacomodo era instantáneo: si coincidía con el
                        // fade de entrada de un toast de otro tamaño, se
                        // veía como que se pisaban un instante. Con esto,
                        // en vez de saltar a la posición nueva, desliza.
                        Behavior on y {
                            NumberAnimation {
                                duration: Theme.animDuration(160)
                                easing.type: Easing.OutCubic
                            }
                        }

                        Component.onCompleted: {
                            toastItem.opacity = 1
                        }

                        NotifCard {
                            id: toastCard

                            anchors {
                                left: parent.left
                                right: parent.right
                                top: parent.top
                            }

                            width:
                                parent.width

                            notif:
                                toastItem.modelData

                            showApp: true
                        }
                    }
                }
            }
        }
    }
}