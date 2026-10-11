// CenterModules.qml — CENTER

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


    property bool notifyOpen: false


    signal overviewButtonClicked()


    property bool overviewOpen: false


    signal clockRightClicked()


    property bool agendaOpen: false


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

    // ============================================================


    property bool wallpaperChanging: false


    property bool hideOnFullscreen: true
    property bool hideOnWallpaperChange: true

    readonly property bool suppressed:
        (hideOnFullscreen && FullscreenState.isOn(targetScreen))
        || (hideOnWallpaperChange && wallpaperChanging)


    onSuppressedChanged: {
        if (suppressed) {
            calendarCloseTimer.stop()
            clockButton.calOpen = false
            tipShown = false
        }
    }

    // ============================================================

    // ============================================================

    property var tipTarget: null
    property real tipCenterX: 0
    property real tipCenterY: 0
    property bool tipShown: false
    property string tipText: ""

    readonly property string liveTip: tipTarget ? String(tipTarget.tip ?? "") : ""
    onLiveTipChanged: { if (liveTip !== "") tipText = liveTip }


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

    // ============================================================

    PanelWindow {
        id: centerPanel

        screen: centerModules.targetScreen

        anchors {
            top: true
            left: true
            right: true
            bottom: true

        }

        color: "transparent"


        visible: !centerModules.suppressed && !Theme.barRebuilding

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-center-modules"

        exclusiveZone: -1


        mask: Region {
            item: centerContainer
            Region { item: calMask }
        }


        Item {
            id: calMask
            x: calDrop.x + calDrop.shiftX + calDrop.slideX
            y: calDrop.y + calDrop.shiftY + calDrop.slideY
            width: calDrop.inputLive ? calDrop.width : 0
            height: calDrop.inputLive ? calDrop.height : 0
        }


        property var glassPanels: []
        BackgroundEffect.blurRegion: GlassRegion {
            panels: centerPanel.glassPanels
            rect: centerContainer
            rectOn: Theme.glassBlurOn && Theme.islandsMode
            rectRadius: Theme.islandRadius
        }

        // ========================================================

        // ========================================================

        Item {
            id: centerContainer


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

                return Math.round(Math.max(lo, Math.min(ideal, hi)))
            }


            width: Theme.barVertical ? Theme.barThickness : modulesRow.width * Theme.barScale + 14
            height: Theme.barVertical ? modulesRow.height * Theme.barScale + 14 : Theme.barHeight


            Rectangle {
                visible: !(Theme.cozy && Theme.islandsMode)
                anchors.fill: parent
                radius: Theme.islandRadius
                color: Theme.islandBg
                border.width: Theme.islandsMode ? Theme.inkWidth : 0
                border.color: Theme.ink
            }

            SkinRect {
                visible: Theme.cozy && Theme.islandsMode
                anchors.fill: parent
                notch: 0
                color: Theme.islandBg
                inkColor: Theme.ink
            }

            BarFlow {
                id: modulesRow

                anchors.centerIn: parent
                gap: 2


                scale: Theme.barScale

                // =================================================


                // =================================================

                SkinRect {
                    id: notificationButton


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

                // =================================================

                BarFlow {
                    id: workspaces


                    gap: 2


                    readonly property var sortedWorkspaces: WM.dotsWorkspacesFor(centerModules.screenName ?? "")

                    WorkspaceDots {
                        workspaces: workspaces.sortedWorkspaces
                        vertical: Theme.barVertical
                    }
                }

                // =================================================

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


                // =================================================

                Rectangle {
                    id: clockButton

                    property bool calOpen: false


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

        // ========================================================


        CalendarDrop {
            id: calDrop

            open: clockButton.calOpen


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

        // ========================================================

        FusedTip {
            id: tip

            open: centerModules.tipOpen
            text: centerModules.tipText


            z: Theme.islandsMode ? -1 : 0
            island: "center"
            screenName: centerModules.screenName

            align: "center"
            alignMargin: 8
            alignCenter: Theme.barVertical ? centerModules.tipCenterY : centerModules.tipCenterX


            Behavior on x {
                enabled: tip.shown && !Theme.barVertical && !tip.hull
                NumberAnimation { duration: Theme.animDuration(160); easing.type: Easing.OutCubic }
            }
            Behavior on y {
                enabled: tip.shown && Theme.barVertical
                NumberAnimation { duration: Theme.animDuration(160); easing.type: Easing.OutCubic }
            }
        }


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
