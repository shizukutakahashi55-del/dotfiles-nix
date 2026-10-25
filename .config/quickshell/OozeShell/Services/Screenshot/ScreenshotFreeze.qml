// ScreenshotFreeze — selector de área con la pantalla CONGELADA.

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "../../COMMON"

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


            Item {
                anchors.fill: parent
                visible: win.uiVisible

                readonly property color dim: Qt.rgba(0, 0, 0, 0.4)


                Rectangle {
                    anchors.fill: parent
                    color: parent.dim
                    visible: !win.hasSel
                }

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

                    if (win.selW < 3 || win.selH < 3) { win.hasSel = false; return }
                    const gx = Math.round(win.screen.x + win.selX)
                    const gy = Math.round(win.screen.y + win.selY)
                    const gw = Math.round(win.selW)
                    const gh = Math.round(win.selH)
                    const geo = gx + "," + gy + " " + gw + "x" + gh
                    if (ScreenshotBackend.pickerMode === "record") {
                        ScreenshotBackend.closePicker()
                        RecorderBackend.pickerDone(gx + "," + gy + " " + (gw - gw % 2) + "x" + (gh - gh % 2))
                        return
                    }
                    ScreenshotBackend.capturing = true
                    settle.geo = geo
                    settle.restart()
                }
            }
        }
    }
}
