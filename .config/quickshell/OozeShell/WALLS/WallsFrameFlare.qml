// WallsFrameFlare — el marco inferior "respira" mientras se aplica un
// wallpaper nuevo (Walls.qml → applyItem → Theme.wallpaperChanging).
//
// Normalmente, con el estilo "curved" del marco activo, el borde de abajo
// (BAR/Border.qml) es una franja recta pegada a los 3 bordes libres de la
// pantalla, continua con las esquinas (BAR/components/FrameCorner.qml).
// Mientras Theme.wallpaperChanging es true — desde que elegís un
// wallpaper en Walls hasta que el Theme ya aplicó la paleta nueva — esta
// franja se "despega": se encoge en un margen animado a los costados, sus
// 4 esquinas se redondean en cápsula y un brillo suave la recorre. Es el
// mismo lenguaje visual de "modo flotante" que ya usa FusedPanel para los
// popups (ver ese archivo, sección "Modo flotante") aplicado al marco.
// Al terminar, vuelve sola a la franja recta de siempre.
//
// La ventana que la contiene (BAR/Border.qml) NO se mueve ni cambia de
// tamaño: solo lo de ADENTRO se anima, así no hace falta tocar la
// geometría real de la superficie Wayland (mismo truco que usa
// FusedPanel/FusedWindow, que tampoco mueven su PanelWindow).
//
// Vive en WALLS/ (no en BAR/) porque lo que dispara y define esta
// animación es, justamente, la aplicación de un wallpaper — no la
// estructura del marco en sí.
//
// Uso (ver BAR/Border.qml, franja de abajo):
//   WallsFrameFlare { anchors.fill: parent }
import QtQuick
import "../COMMON"

Item {
    id: root

    property color fillColor: Theme.bg
    // Radio "de reposo" del marco: la cápsula flotante nunca se ve MÁS
    // redondeada que el resto del marco del que nace.
    property real restRadius: Theme.frameCornerRadius
    // Se está aplicando un wallpaper (Walls.qml lo dispara; Theme.qml lo
    // expone global, sin necesidad de que Border.qml nos lo pase a mano)
    readonly property bool floating: Theme.wallpaperChanging

    // ── Despegue de los costados ──────────────────────────────────
    readonly property real gapTarget: 22
    property real gap: root.floating ? root.gapTarget : 0
    Behavior on gap { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

    // ── Esquinas: de rectas a cápsula ────────────────────────────
    readonly property real pillRadius: Math.min(root.restRadius, root.height / 2)
    property real radius: root.floating ? root.pillRadius : 0
    Behavior on radius { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

    Rectangle {
        id: pill
        anchors.fill: parent
        anchors.leftMargin: root.gap
        anchors.rightMargin: root.gap
        color: root.fillColor
        topLeftRadius: root.radius
        topRightRadius: root.radius
        bottomLeftRadius: root.radius
        bottomRightRadius: root.radius
    }

    // Brillo suave que "respira" mientras se aplica el wallpaper: la única
    // señal de que hay algo en curso (no hay una barra de progreso real
    // que mostrar acá).
    Rectangle {
        anchors.fill: pill
        radius: pill.radius
        color: "transparent"
        border.width: Theme.bw1
        border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.55)
        visible: root.floating
        opacity: 0

        SequentialAnimation on opacity {
            running: root.floating
            loops: Animation.Infinite
            NumberAnimation { from: 0;   to: 0.9; duration: 620; easing.type: Easing.InOutSine }
            NumberAnimation { from: 0.9; to: 0;   duration: 620; easing.type: Easing.InOutSine }
        }
    }
}
