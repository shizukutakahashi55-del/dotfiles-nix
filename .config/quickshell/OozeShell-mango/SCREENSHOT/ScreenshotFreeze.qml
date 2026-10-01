// ScreenshotFreeze — selector de área con la pantalla CONGELADA.
//
// Reemplaza a slurp en areaCopy/areaSave. Al abrirse (ScreenshotBackend
// .pickerOpen) cada monitor recibe una ventana Overlay con un cuadro fijo
// de su contenido (ScreencopyView, live: false) y encima el oscurecido +
// el marco de selección. Lo que ves congelado es lo que se captura.
//
//   arrastrar        elegir el área
//   Esc / clic der.  cancelar
//
// Al soltar el mouse se esconde el oscurecido y el marco (para que no
// salgan en la captura), se deja el cuadro congelado a la vista y se corre
// grim -g sobre esa zona: grim copia lo que el compositor dibuja, que es
// justo este cuadro fijo. Recién cuando grim termina se cierra el selector.
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "../COMMON"

Scope {
    id: root

    Timer {
        id: settle
        interval: ScreenshotBackend.freezeSettleMs
        property string geo: ""
        onTriggered: {
            grim.command = ScreenshotBackend.captureCommand(settle.geo)
            grim.running = true
        }
    }

    Process {
        id: grim
        onExited: ScreenshotBackend.closePicker()
    }

    Variants {
        model: ScreenshotBackend.pickerOpen ? Quickshell.screens : []

        delegate: PanelWindow {
            id: win

            required property var modelData
            screen: modelData

            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            exclusiveZone: -1

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "oozeshell-screenshot"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            // Selección (coordenadas locales de esta pantalla)
            property real sx: 0
            property real sy: 0
            property real ex: 0
            property real ey: 0
            property bool dragging: false
            property bool hasSel: false

            readonly property real selX: Math.min(sx, ex)
            readonly property real selY: Math.min(sy, ey)
            readonly property real selW: Math.abs(ex - sx)
            readonly property real selH: Math.abs(ey - sy)
            readonly property bool ready: frozen.hasContent
            readonly property bool uiVisible: ready && !ScreenshotBackend.capturing

            // Cuadro congelado (se pide UNA vez; no es en vivo)
            ScreencopyView {
                id: frozen
                anchors.fill: parent
                captureSource: win.screen
                live: false
                paintCursor: false
                Component.onCompleted: captureFrame()
            }

            Shortcut {
                sequence: "Escape"
                onActivated: if (!ScreenshotBackend.capturing) ScreenshotBackend.closePicker()
            }

            // Oscurecido: el hueco de la selección queda sin tapar
            Item {
                anchors.fill: parent
                visible: win.uiVisible

                readonly property color dim: Qt.rgba(0, 0, 0, 0.4)

                // Sin selección: todo oscuro
                Rectangle {
                    anchors.fill: parent
                    color: parent.dim
                    visible: !win.hasSel
                }
                // Con selección: cuatro franjas alrededor
                Rectangle { visible: win.hasSel; color: parent.dim
                    x: 0; y: 0; width: parent.width; height: win.selY }
                Rectangle { visible: win.hasSel; color: parent.dim
                    x: 0; y: win.selY + win.selH; width: parent.width
                    height: parent.height - (win.selY + win.selH) }
                Rectangle { visible: win.hasSel; color: parent.dim
                    x: 0; y: win.selY; width: win.selX; height: win.selH }
                Rectangle { visible: win.hasSel; color: parent.dim
                    x: win.selX + win.selW; y: win.selY
                    width: parent.width - (win.selX + win.selW); height: win.selH }

                // Marco (por fuera del área, para no tapar ni un píxel)
                Rectangle {
                    visible: win.hasSel
                    x: win.selX - ScreenshotBackend.borderWidth
                    y: win.selY - ScreenshotBackend.borderWidth
                    width: win.selW + ScreenshotBackend.borderWidth * 2
                    height: win.selH + ScreenshotBackend.borderWidth * 2
                    color: "transparent"
                    border.width: ScreenshotBackend.borderWidth
                    border.color: Theme.primary
                }

                // Tamaño en píxeles reales
                Rectangle {
                    visible: win.hasSel && win.selW > 1
                    readonly property real above: win.selY - height - 8
                    x: Math.max(4, Math.min(parent.width - width - 4, win.selX))
                    y: above >= 4 ? above : win.selY + win.selH + 8
                    width: sizeText.implicitWidth + 16
                    height: sizeText.implicitHeight + 8
                    radius: 8
                    color: Theme.bg
                    border.width: Theme.bw1
                    border.color: Theme.edge
                    Text {
                        id: sizeText
                        anchors.centerIn: parent
                        text: Math.round(win.selW * win.screen.devicePixelRatio) + " × " +
                              Math.round(win.selH * win.screen.devicePixelRatio)
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fs(11)
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                enabled: win.ready && !ScreenshotBackend.capturing
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.CrossCursor

                onPressed: m => {
                    if (m.button === Qt.RightButton) { ScreenshotBackend.closePicker(); return }
                    win.sx = win.ex = m.x
                    win.sy = win.ey = m.y
                    win.dragging = true
                    win.hasSel = true
                }
                onPositionChanged: m => {
                    if (!win.dragging) return
                    win.ex = Math.max(0, Math.min(width, m.x))
                    win.ey = Math.max(0, Math.min(height, m.y))
                }
                onReleased: m => {
                    if (!win.dragging) return
                    win.dragging = false
                    // Un clic suelto (sin arrastrar) no captura nada
                    if (win.selW < 3 || win.selH < 3) { win.hasSel = false; return }
                    const gx = Math.round(win.screen.x + win.selX)
                    const gy = Math.round(win.screen.y + win.selY)
                    const gw = Math.round(win.selW)
                    const gh = Math.round(win.selH)
                    ScreenshotBackend.capturing = true
                    settle.geo = gx + "," + gy + " " + gw + "x" + gh
                    settle.restart()
                }
            }
        }
    }
}
