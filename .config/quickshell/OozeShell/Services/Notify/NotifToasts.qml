// NotifToasts — popups de notificaciones nuevas.

import Quickshell
import Quickshell.Wayland

import QtQuick

import "../../COMMON"

Item {
    id: root

    property string targetScreen: ""

    property int panelWidth: 400
    property int edgeMargin: 10
    property int maxToasts: 4

    readonly property var liveRows: NotificationsBackend.displayPopups.slice(0, root.maxToasts)
    property var liveIds: []
    property var exitRows: []
    property var swipedIds: ({})
    onLiveRowsChanged: root.syncExit()
    function syncExit() {
        const ids = {}
        for (const n of root.liveRows) ids[n.notifId] = true
        for (const id of root.liveIds) {
            if (root.swipedIds[id]) {
                delete root.swipedIds[id]
                continue
            }
            if (!ids[id] && !root.exitRows.some(n => n.notifId === id)) {
                const it = NotificationsBackend.list.find(n => n.notifId === id)
                if (it) root.exitRows = [...root.exitRows, it]
            }
        }
        root.liveIds = Object.keys(ids)
        if (root.exitRows.length > 0) exitTimer.restart()
    }
    Timer {
        id: exitTimer
        interval: 240
        repeat: false
        onTriggered: root.exitRows = []
    }


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
                    ? Theme.barFace + 24
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
            item: toastMask
        }


        property var glassPanels: []
        GlassRegion { id: blurReg; panels: win.glassPanels }
        Component.onCompleted: {
          if (WM.hasBackgroundBlur) BackgroundEffect.blurRegion = blurReg
        }

        Item {
            id: toastMask
            readonly property bool live: root.wanted || panel.progress > 0.001

            x: panel.x + panel.shiftX
            y: panel.y + panel.shiftY
            width: live ? panel.width : 0
            height: live ? panel.height : 0
        }

        FusedPanel {
            id: panel

            open: root.wanted

            panelWidth:
                root.panelWidth

            contentHeight:
                list.height + 24

            instantResize: true


            detached:
                FullscreenState.isOn(
                    win.screen
                ) || Theme.islandsMode || Theme.pillMode || panel.floatWin

            faceOffset:
                Theme.pillMode
                    ? root.pillClearance
                    : Theme.barFace +
                      (Theme.islandsMode ? 6 : 0)


            align: "center"

            alignMargin:
                root.edgeMargin +
                Theme.barEdge


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
                            root.liveRows

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


                        opacity: 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.animDuration(180)
                            }
                        }


                        Behavior on y {
                            NumberAnimation {
                                duration: Theme.animDuration(160)
                                easing.type: Easing.OutCubic
                            }
                        }

                        Component.onCompleted: {
                            toastItem.opacity = 1
                        }

                        property real dragX: 0
                        property bool dismissing: false
                        readonly property real swipeThreshold: width * 0.3

                        function dismiss() {
                            if (toastItem.dismissing) return
                            toastItem.dismissing = true
                            toastItem.dragX = -toastItem.width
                            dismissTimer.restart()
                        }

                        Timer {
                            id: dismissTimer
                            interval: Theme.animDuration(160)
                            repeat: false
                            onTriggered: {
                                const swiped = Object.assign({}, root.swipedIds)
                                swiped[toastItem.modelData.notifId] = true
                                root.swipedIds = swiped
                                toastItem.modelData.close()
                            }
                        }

                        DragHandler {
                            id: swipe
                            target: null
                            xAxis.enabled: true
                            yAxis.enabled: false
                            enabled: !toastItem.dismissing
                            onActiveTranslationChanged: {
                                if (swipe.active)
                                    toastItem.dragX = Math.min(0, swipe.activeTranslation.x)
                            }
                            onActiveChanged: {
                                if (swipe.active) return
                                if (toastItem.dragX < -toastItem.swipeThreshold)
                                    toastItem.dismiss()
                                else
                                    toastItem.dragX = 0
                            }
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

                            opacity:
                                toastItem.dismissing
                                    ? 0
                                    : 1 - Math.min(1, Math.abs(toastItem.dragX) / toastItem.width) * 0.6

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.animDuration(120)
                                }
                            }

                            transform: Translate {
                                x: toastItem.dragX

                                Behavior on x {
                                    enabled: !swipe.active
                                    NumberAnimation {
                                        duration: Theme.animDuration(160)
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }

                            notif:
                                toastItem.modelData

                            showApp: true

                            outerRadius:
                                panel.cornerRadius /
                                panel.scaleFactor

                            outerInset: list.x
                        }
                    }
                }

                Repeater {
                    model: ScriptModel {
                        values:
                            root.exitRows

                        objectProp: "notifId"
                    }

                    delegate: Item {
                        id: exitItem

                        required property var modelData

                        property real reveal: 1

                        Behavior on reveal {
                            NumberAnimation {
                                duration: Theme.animDuration(200)
                                easing.type: Easing.InCubic
                            }
                        }

                        Component.onCompleted: exitItem.reveal = 0

                        width:
                            list.width

                        height:
                            exitCard.implicitHeight * exitItem.reveal

                        opacity:
                            exitItem.reveal

                        clip: true
                        enabled: false

                        NotifCard {
                            id: exitCard

                            width:
                                parent.width

                            x: (1 - exitItem.reveal) * 80

                            notif:
                                exitItem.modelData

                            showApp: true

                            outerRadius:
                                panel.cornerRadius /
                                panel.scaleFactor

                            outerInset: list.x
                        }
                    }
                }
            }
        }
    }
}
