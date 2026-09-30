import QtQuick
import QtQuick.Layouts
import "../COMMON"
import "../LANG"

// DashboardHeader — los íconos de sección, SIEMPRE visibles (ver
// especificación §9): nunca desaparecen ni cambian de alto, solo cambia
// cuál está resaltado y qué muestra el Loader de abajo (Dashboard.qml).
//
// Corrección pedida: cada ítem ahora lleva un NOMBRE debajo del ícono (no
// solo el glifo), y el header es más grande para que el Dashboard entero
// se sienta como el "dock" en el que crece la Pastilla.
//
// "overview" ahora es una sección más (DashboardOverview.qml): ya no abre
// un overlay aparte. `action: true` (+ `actionTriggered`) sigue disponible
// para ítems que sí sean una acción sin contenido propio.
Item {
    id: root

    property string section: "power"
    signal sectionSelected(string section)
    signal actionTriggered(string id)

    // Íconos: todos Material Design (Nerd Font), los mismos glifos que usan
    // los paneles de cada sección (Power → PowerActions, Música → controles
    // del reproductor, Audio → volumen, Ajustes → engranaje de Quick Access,
    // Espacios → el ícono de Overview de la barra). Antes mezclaban símbolos
    // Unicode sueltos y un emoji (🔊) que se dibujaba a color y con otro peso.
    readonly property var items: [
        { id: "power",       icon: "󰐥", labelKey: "dashboardSectionPower",   action: false },
        { id: "mpris",       icon: "󰝚", labelKey: "dashboardSectionMpris",   action: false },
        { id: "performance", icon: "󰓅", labelKey: "dashboardSectionPerf",    action: false },
        { id: "audio",       icon: "󰕾", labelKey: "dashboardSectionAudio",   action: false },
        { id: "calendar",    icon: "󰃭", labelKey: "dashboardSectionCalendar", action: false },
        { id: "quickaccess", icon: "󰒓", labelKey: "dashboardSectionSettings", action: false },
        { id: "overview",    icon: "󰕮", labelKey: "dashboardSectionOverview", action: false }
    ]

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: Theme.cozy ? 2 : 1
        color: Theme.cozy ? Theme.ink : Theme.divider
    }

    // ── Medidas ─────────────────────────────────────────────────
    // Cada botón mide lo que pide SU nombre (mínimo itemMinW): así en
    // cualquier idioma el texto cabe completo, sin cortarse ni pisar al
    // vecino. `requiredWidth` se lo cuenta a Dashboard.qml para que el dock
    // nunca sea más angosto que el header.
    readonly property int itemMinW: Theme.ds(58)
    readonly property int itemH: Theme.ds(48)
    readonly property int gap: Theme.ds(6)
    readonly property int padX: Theme.ds(12)      // aire a cada lado del nombre
    readonly property int sideMargin: Theme.ds(14)
    readonly property font labelFont: Qt.font({
        family: Theme.fontFamily, pixelSize: Theme.dfs(Theme.cozy ? 9 : 10)
    })

    // Mide los nombres con la misma fuente que se dibujan (se re-mide solo
    // al cambiar de idioma: Translations.t() se reevalúa en el binding).
    FontMetrics { id: fm; font: root.labelFont }

    // Ancho de cada botón, en el mismo orden que `items`
    readonly property var widths: root.items.map(it =>
        Math.max(root.itemMinW,
                 Math.ceil(fm.advanceWidth(Translations.t(it.labelKey))) + root.padX * 2))

    readonly property int requiredWidth:
        root.widths.reduce((a, b) => a + b, 0)
        + (root.items.length - 1) * root.gap + root.sideMargin * 2

    // Índice de la sección activa (-1 si es una acción sin panel)
    readonly property int activeIndex: {
        for (let i = 0; i < root.items.length; i++)
            if (!root.items[i].action && root.items[i].id === root.section) return i
        return -1
    }

    // Contenedor de tamaño explícito: el resaltado vive en SU mismo sistema
    // de coordenadas, así que solo se anima el cambio de sección (no el
    // recentrado cuando el dock cambia de ancho).
    Item {
        id: rowBox
        anchors.centerIn: parent
        width: root.requiredWidth - root.sideMargin * 2
        height: root.itemH

        // Resaltado único: se desliza Y se ajusta al ancho del botón activo.
        // Su posición se calcula con `widths` (no con Repeater.itemAt(), que
        // no avisa cuando los botones ya existen y dejaba el resaltado
        // invisible).
        SkinRect {
            id: slider
            readonly property int idx: root.activeIndex
            visible: idx >= 0
            height: root.itemH
            radius: Theme.ds(12)
            raised: true
            depth: Theme.cozy ? 3 : 2
            inkColor: Theme.ink
            color: Theme.primary
            // Se anima `sx`/`sw` (real) y se dibuja redondeado: con medios
            // píxeles el contorno pixel de CoOzey parpadeaba al deslizarse.
            property real sx: {
                let acc = 0
                for (let i = 0; i < slider.idx; i++) acc += root.widths[i] + root.gap
                return acc
            }
            property real sw: slider.idx >= 0 ? root.widths[slider.idx] : root.itemMinW
            x: Math.round(slider.sx)
            width: Math.round(slider.sw)
            Behavior on sx {
                NumberAnimation {
                    duration: Theme.animDuration(Theme.cozy ? 240 : 280)
                    easing.type: Easing.OutBack
                    easing.overshoot: Theme.cozy ? 0.45 : 0.8
                }
            }
            Behavior on sw { NumberAnimation { duration: Theme.animDuration(240); easing.type: Easing.OutCubic } }
        }

        RowLayout {
            anchors.fill: parent
            spacing: root.gap

            Repeater {
                model: root.items

                delegate: SkinRect {
                    id: btn
                    required property var modelData
                    required property int index
                    readonly property bool activeSection: !modelData.action && root.section === modelData.id

                    Layout.preferredWidth: root.widths[btn.index]
                    Layout.preferredHeight: root.itemH
                    radius: Theme.ds(12)

                    // El fondo activo lo pone `slider`; acá solo el hover.
                    color: (!btn.activeSection && hm.containsMouse) ? Theme.surface : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }

                    // CoOzey: sin escala (borrosa el pixel art)
                    scale: Theme.cozy ? 1.0 : (hm.pressed ? 0.90 : hm.containsMouse ? 1.05 : 1.0)
                    Behavior on scale { NumberAnimation { duration: Theme.animDuration(150); easing.type: Easing.OutBack } }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: Theme.ds(2)

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: btn.modelData.icon
                            color: btn.activeSection ? Theme.textOnPrimary : Theme.text
                            font.pixelSize: Theme.dfs(16)
                            font.family: Theme.monoFamily
                            Behavior on color { ColorAnimation { duration: Theme.animDuration(200) } }
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: Translations.t(btn.modelData.labelKey)
                            color: btn.activeSection ? Theme.textOnPrimary : Theme.subtext
                            font: root.labelFont
                            Behavior on color { ColorAnimation { duration: Theme.animDuration(200) } }
                        }
                    }

                    MouseArea {
                        id: hm
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (btn.modelData.action) root.actionTriggered(btn.modelData.id)
                            else root.sectionSelected(btn.modelData.id)
                        }
                    }
                }
            }
        }
    }
}
