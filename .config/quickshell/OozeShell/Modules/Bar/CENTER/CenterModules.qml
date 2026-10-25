// CenterModules.qml — CENTER (isla central)

import Quickshell
import Quickshell.Wayland

import QtQuick

import "./CALENDAR"
import "../../../COMMON"
import "../components"

BarHost {
    id: centerModules

    side: "center"

    occupied: modulesRow.occupied
    othersHeight: modulesRow.othersHeight
    pillItem: centerContainer
    pillHovered: centerHover.hovered

    spanX: centerContainer.x
    spanW: centerContainer.width

    islandRect: Theme.islandsMode ? ({
        x: centerContainer.x, y: centerContainer.y,
        w: centerContainer.width, h: centerContainer.height
    }) : null

    readonly property real pillExtent: Theme.barVertical ? centerContainer.height : 0

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

        visible: true

        WlrLayershell.layer: WM.islandLayer
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
        GlassRegion {
          id: blurReg
            panels: centerPanel.glassPanels
            rect: centerContainer
            rectOn: Theme.glassBlurOn && Theme.islandsMode && centerModules.live
            rectRadius: Theme.islandRadius
        }
        Component.onCompleted: {
          if (WM.hasBackgroundBlur) BackgroundEffect.blurRegion = blurReg
        }

        Item {
            id: centerContainer

            HoverHandler { id: centerHover }

            visible: centerModules.live

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

            width: !centerModules.live ? 0
                : (Theme.barVertical ? Theme.barThickness : modulesRow.width * Theme.barScale + 14)
            height: !centerModules.live ? 0
                : (Theme.barVertical ? modulesRow.height * Theme.barScale + 14 : Theme.barHeight)

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

            BarSectionRow {
                id: modulesRow

                side: "center"
                host: centerModules

                anchors.centerIn: parent
                scale: Theme.barScale
            }
        }

        CalendarDrop {
            id: calDrop

            open: BarCalendar.isOpen(centerModules.screenName)

            island: BarCalendar.side
            screenName: centerModules.screenName
            z: -1

            align: "center"
            alignMargin: 8
            alignCenter: BarCalendar.anchor
        }

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
                if (!BarCalendar.clockHover && !calDrop.hovered)
                    BarCalendar.hide()
            }
        }

        Connections {
            target: calDrop

            function onHoveredChanged() {
                if (!calDrop.hovered)
                    calendarCloseTimer.restart()
            }
        }

        Connections {
            target: BarCalendar

            function onClockHoverChanged() {
                if (!BarCalendar.clockHover && BarCalendar.isOpen(centerModules.screenName))
                    calendarCloseTimer.restart()
            }
        }
    }
}
