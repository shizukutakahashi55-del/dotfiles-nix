// PillWorkspacesSide.qml — PILL

import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../COMMON"


Item {
    id: root

    property var targetScreen
    readonly property string screenName: targetScreen ? targetScreen.name : ""


    property int edgeGap: Theme.pillEdgeGap
    property int pillH: Theme.pillHeight

    property int showTime: 2500


    readonly property bool suppressed: FullscreenState.isOn(targetScreen)
    onSuppressedChanged: { if (root.suppressed) { root.flash = false; root.hoverKeep = false } }

    // ── Detección de cambio de workspace en ESTA pantalla ───────────
    readonly property int activeId: WM.activeWorkspaceId(root.screenName)
    property int lastId: -999
    property bool flash: false

    onActiveIdChanged: {

        if (root.lastId !== -999 && root.activeId !== root.lastId && root.activeId !== -999) {
            root.flash = true
            hideTimer.restart()
        }
        root.lastId = root.activeId
    }
    Component.onCompleted: root.lastId = root.activeId

    Timer {
        id: hideTimer
        interval: root.showTime
        onTriggered: root.flash = false
    }


    readonly property bool hovered: zoneHover.hovered
    property bool hoverKeep: false
    property int leaveTime: 1200
    function touch() {
        leaveTimer.stop()
        root.hoverKeep = true
        if (!root.hovered) leaveTimer.restart()
        if (root.flash) hideTimer.restart()
    }
    onHoveredChanged: {
        if (root.hovered) { leaveTimer.stop(); root.hoverKeep = true }
        else {
            leaveTimer.restart()

            if (root.flash) hideTimer.restart()
        }
    }
    Timer {
        id: leaveTimer
        interval: root.leaveTime
        onTriggered: { if (!root.hovered) root.hoverKeep = false }
    }

    readonly property bool shown: root.flash || root.hoverKeep

    PanelWindow {
        id: win

        screen: root.targetScreen
        anchors { top: true; left: true; right: true; bottom: true }
        color: "transparent"
        visible: !Theme.barRebuilding && !root.suppressed

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "oozeshell-pill-workspaces"
        exclusiveZone: -1


        mask: Region { item: zone }


        Item {
            id: zone
            readonly property real fullH: root.edgeGap + root.pillH + 6
            width: root.edgeGap + Math.max(120, surface.width) + 8
            height: root.shown ? fullH : 6
            x: 0
            y: Theme.barAtBottom ? parent.height - height : 0

            HoverHandler { id: zoneHover }

            PointHandler {
                acceptedButtons: Qt.AllButtons
                onActiveChanged: root.touch()
            }
        }

        Item {
            id: surface


            property real t: root.shown ? 1 : 0
            Behavior on t { NumberAnimation { duration: Theme.animDuration(260); easing.type: Easing.OutCubic } }

            width: Math.round(content.implicitWidth * Theme.pillScale) + 16
            height: root.pillH

            visible: t > 0.01
            opacity: t

            readonly property real slide: (1 - t) * (height + root.edgeGap)
            x: root.edgeGap
            y: Math.round(Theme.barAtBottom
                ? parent.height - height - root.edgeGap + slide
                : root.edgeGap - slide)

            Behavior on width { NumberAnimation { duration: Theme.animDuration(200); easing.type: Easing.OutCubic } }

            SkinRect {
                anchors.fill: parent
                radius: 16
                color: Theme.bg
                inkColor: Theme.ink
                raised: Theme.cozy
                depth: 2
            }

            RowLayout {
                id: content
                anchors.centerIn: parent
                spacing: 4
                scale: Theme.pillScale
                transformOrigin: Item.Center

                PillWorkspaces { screenName: root.screenName }
            }
        }
    }
}
