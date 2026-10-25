// Bar.qml — BAR

import Quickshell
import Quickshell.Wayland
import QtQuick

import "./CENTER"
import "./LEFT"
import "./RIGHT"
import "./components"
import "../../COMMON"


Variants {
    id: barModule


    model: Theme.pillMode ? [] : Quickshell.screens


    signal menuButtonClicked(var screen)

    signal notificationButtonClicked(var screen)

    signal agendaButtonClicked(var screen)

    signal mprisButtonClicked(var screen)

    signal powerButtonClicked(var screen)

    signal audioButtonClicked(var screen)


    signal trayMenuOpened()


    property bool menuOpen: false
    property bool notifyOpen: false
    property bool agendaOpen: false
    property bool mprisOpen: false

    property bool audioOpen: false


    property bool popupOpen: false


    property bool wallpaperChanging: false


    property bool hideOnFullscreen: true
    property bool hideOnWallpaperChange: true


    property bool screenCorners: true

    // ── Brazos del marco para las esquinas (ver Modules/Bar/components/FrameCorner.qml) ──


    readonly property bool framArmsActive: Theme.frameOn && WM.has("screenFrame") && barModule.screenCorners && Theme.frameCurved
        && !Theme.barSeparated && !Theme.barRebuilding


    readonly property real cornerOffset: Theme.barDrawn ? Theme.barOffset : 0

    readonly property real frameTv: (Theme.frameThicknessVis > 0.01) ? Theme.frameThicknessVis : 0
    readonly property real armTop:    (barModule.framArmsActive && Theme.frameBarSide !== "top")    ? barModule.frameTv : 0
    readonly property real armBottom: (barModule.framArmsActive && Theme.frameBarSide !== "bottom") ? barModule.frameTv : 0
    readonly property real armLeft:   (barModule.framArmsActive && Theme.frameBarSide !== "left")   ? barModule.frameTv : 0
    readonly property real armRight:  (barModule.framArmsActive && Theme.frameBarSide !== "right")  ? barModule.frameTv : 0
    readonly property real armTopWin:    (barModule.framArmsActive && Theme.frameBarSide !== "top")
        ? Math.max(Theme.frameThickness, Math.ceil(barModule.armTop)) : 0
    readonly property real armBottomWin: (barModule.framArmsActive && Theme.frameBarSide !== "bottom")
        ? Math.max(Theme.frameThickness, Math.ceil(barModule.armBottom)) : 0


    delegate: Component {


        Item {
            id: screenRoot
            property var modelData


            readonly property bool suppressed:
                (barModule.hideOnFullscreen && FullscreenState.isOn(modelData))
                || (barModule.hideOnWallpaperChange && barModule.wallpaperChanging)

            // ── Islas con contenido (modo flotante: la barra se encoge hacia lo que tiene) ──

            readonly property bool peekHold: Theme.barPeek && (
                panelHover.hovered || leftModules.pillHovered || centerModules.pillHovered || rightModules.pillHovered
                || barModule.popupOpen || barModule.menuOpen || barModule.notifyOpen
                || barModule.agendaOpen || barModule.mprisOpen || barModule.audioOpen
                || leftModules.trayMenuOpen || centerModules.trayMenuOpen || rightModules.trayMenuOpen
                || leftModules.taskbarMenuOpen || centerModules.taskbarMenuOpen || rightModules.taskbarMenuOpen
                || BarCalendar.isOpen(screenRoot.modelData ? screenRoot.modelData.name : ""))
            onPeekHoldChanged: Theme.setBarHold(screenRoot.modelData ? screenRoot.modelData.name : "", screenRoot.peekHold)

            readonly property bool anyOccupied: leftModules.occupied || centerModules.occupied || rightModules.occupied
            readonly property bool bothSidesOccupied: leftModules.occupied && rightModules.occupied
            readonly property real barInset: leftModules.leftMargin
            readonly property real spanStart: Math.min(
                leftModules.occupied ? leftModules.spanX : 1e9,
                centerModules.occupied ? centerModules.spanX : 1e9,
                rightModules.occupied ? rightModules.spanX : 1e9) - screenRoot.barInset
            readonly property real spanEnd: Math.max(
                leftModules.occupied ? leftModules.spanX + leftModules.spanW : -1e9,
                centerModules.occupied ? centerModules.spanX + centerModules.spanW : -1e9,
                rightModules.occupied ? rightModules.spanX + rightModules.spanW : -1e9) + screenRoot.barInset

        // ─── Fondo de la barra ───────────────────────────────────


        PanelWindow {
            id: barPanel
            screen: modelData

            visible: true

            exclusionMode: Theme.barHidden ? ExclusionMode.Ignore : ExclusionMode.Auto

            WlrLayershell.layer: WM.barBgLayer
            WlrLayershell.namespace: "quickshell-bar-background"

            mask: Region {
                width: (Theme.barDrawn && !Theme.islandsMode && !screenRoot.suppressed) ? barPanel.width : 0
                height: (Theme.barDrawn && !Theme.islandsMode && !screenRoot.suppressed) ? barPanel.height : 0
            }


            anchors {
                top: !Theme.barAtBottom
                bottom: Theme.barAtBottom || Theme.barVertical
                left: !Theme.barVertical || !Theme.barAtRight
                right: !Theme.barVertical || Theme.barAtRight
            }
            margins.top: Theme.barEdge
            margins.bottom: Theme.barEdge
            margins.left: Theme.barEdge
            margins.right: Theme.barEdge

            implicitWidth: Theme.barVertical ? Theme.barThickness : 0
            implicitHeight: Theme.barVertical ? 0 : Theme.barHeight


            color: "transparent"


            GlassRegion {
              id: blurReg
                rect: barBg
                rectOn: Theme.glassBlurOn && !Theme.islandsMode && !screenRoot.suppressed && Theme.barDrawn
                rectRadius: Theme.barRadius
            }
            Component.onCompleted: {
              if (WM.hasBackgroundBlur) BackgroundEffect.blurRegion = blurReg
            }

            HoverHandler { id: panelHover }

            SkinRect {
                id: barBg

                readonly property bool shrink: Theme.barFloating && !Theme.islandsMode
                    && screenRoot.anyOccupied && !screenRoot.bothSidesOccupied
                readonly property real spanL: shrink ? Math.max(0, screenRoot.spanStart - Theme.barEdge) : 0
                readonly property real spanR: shrink ? Math.min(parent.width, screenRoot.spanEnd - Theme.barEdge) : parent.width

                y: 0
                height: parent.height
                x: barBg.spanL
                width: Math.max(0, barBg.spanR - barBg.spanL)
                readonly property string screenKey: screenRoot.modelData ? screenRoot.modelData.name : ""
                function publishSpan() {
                    if (barBg.shrink && barBg.screenKey !== "")
                        IslandState.setSpan(barBg.screenKey, Theme.barEdge + barBg.spanL, barBg.spanR - barBg.spanL)
                    else
                        IslandState.clearSpan(barBg.screenKey)
                }
                onShrinkChanged: barBg.publishSpan()
                onSpanLChanged: barBg.publishSpan()
                onSpanRChanged: barBg.publishSpan()
                Component.onCompleted: barBg.publishSpan()
                Component.onDestruction: IslandState.clearSpan(barBg.screenKey)
                Connections {
                    target: IslandState
                    function onRefreshRequested() { barBg.publishSpan() }
                }
                Behavior on x { NumberAnimation { duration: Theme.animDuration(200); easing.type: Easing.OutCubic } }
                Behavior on width { NumberAnimation { duration: Theme.animDuration(200); easing.type: Easing.OutCubic } }

                color: Theme.panelBg
                radius: Theme.barRadius
                raised: Theme.cozy && Theme.barFloating
                depth: 2
                notch: 0
                inkColor: Theme.ink


                opacity: (screenRoot.suppressed || Theme.islandsMode || !Theme.barDrawn) ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: Theme.animDuration(220); easing.type: Easing.OutCubic } }


                Rectangle {
                    readonly property real t: Theme.inkWidth
                    visible: Theme.cozy && !Theme.barSeparated
                    color: Theme.ink
                    x: Theme.barVertical ? (Theme.barAtRight ? 0 : parent.width - t) : 0
                    y: Theme.barVertical ? 0 : (Theme.barAtBottom ? 0 : parent.height - t)
                    width: Theme.barVertical ? t : parent.width
                    height: Theme.barVertical ? parent.height : t
                }
            }


        }

        // ─── Esquinas de pantalla (las 4) ────────────────────────


        // ── Superiores: justo debajo de la barra (o en el borde de arriba si


        PanelWindow {
            id: cornersTop
            screen: modelData
            anchors { top: true; left: true; right: true }

            margins.top: (Theme.barVertical || Theme.barAtBottom) ? 0 : barModule.cornerOffset


            implicitHeight: Theme.frameCornerRadius + barModule.armTopWin
            color: "transparent"


            exclusiveZone: -1
            visible: Theme.frameOn && WM.has("screenFrame") && barModule.screenCorners && !Theme.barSeparated && Theme.frameCornerRadius > 0
            WlrLayershell.namespace: "quickshell-screen-corners-top"


            WlrLayershell.layer: WM.islandLayer


            mask: Region {}

            Item {
                anchors.fill: parent

                opacity: screenRoot.suppressed ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: Theme.animDuration(150); easing.type: Easing.OutCubic } }


                FrameCorner {
                    anchors.left: parent.left
                    anchors.leftMargin: (Theme.barVertical && !Theme.barAtRight) ? barModule.cornerOffset : 0
                    anchors.top: parent.top
                    armX: barModule.armLeft
                    armY: barModule.armTop
                }
                FrameCorner {
                    anchors.right: parent.right
                    anchors.rightMargin: (Theme.barVertical && Theme.barAtRight) ? barModule.cornerOffset : 0
                    anchors.top: parent.top
                    atRight: true
                    armX: barModule.armRight
                    armY: barModule.armTop
                }
            }
        }

        // ── Inferiores: pegadas al borde de abajo (o justo encima de la barra
        PanelWindow {
            id: cornersBottom
            screen: modelData
            anchors { bottom: true; left: true; right: true }
            margins.bottom: (!Theme.barVertical && Theme.barAtBottom) ? barModule.cornerOffset : 0
            implicitHeight: Theme.frameCornerRadius + barModule.armBottomWin
            color: "transparent"

            exclusiveZone: -1
            visible: Theme.frameOn && WM.has("screenFrame") && barModule.screenCorners && !Theme.barSeparated && Theme.frameCornerRadius > 0
            WlrLayershell.namespace: "quickshell-screen-corners-bottom"

            WlrLayershell.layer: WM.islandLayer

            mask: Region {}

            Item {
                anchors.fill: parent
                opacity: screenRoot.suppressed ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: Theme.animDuration(150); easing.type: Easing.OutCubic } }

                FrameCorner {
                    anchors.left: parent.left
                    anchors.leftMargin: (Theme.barVertical && !Theme.barAtRight) ? barModule.cornerOffset : 0
                    anchors.bottom: parent.bottom
                    atBottom: true
                    armX: barModule.armLeft
                    armY: barModule.armBottom
                }
                FrameCorner {
                    anchors.right: parent.right
                    anchors.rightMargin: (Theme.barVertical && Theme.barAtRight) ? barModule.cornerOffset : 0
                    anchors.bottom: parent.bottom
                    atRight: true
                    atBottom: true
                    armX: barModule.armRight
                    armY: barModule.armBottom
                }
            }
        }

        // ─── Marco continuo (estilo "curved") ──────────────────────


        Border {
            id: frameBorder
            screen: modelData
            suppressed: screenRoot.suppressed
            active: Theme.frameOn && WM.has("screenFrame") && barModule.screenCorners && Theme.frameCurved
                    && !Theme.barSeparated
        }


        BarRevealZone {
            screen: modelData
            suppressed: screenRoot.suppressed
            covered: frameBorder.coversBarSide
        }

        CenterModules {
            id: centerModules
            targetScreen: modelData

            topReserve: leftModules.extent
            bottomReserve: rightModules.extent
            mprisOpen: barModule.mprisOpen
            notifyOpen: barModule.notifyOpen
            agendaOpen: barModule.agendaOpen
            audioOpen: barModule.audioOpen
            menuOpen: barModule.menuOpen
            popupOpen: barModule.popupOpen
            wallpaperChanging: barModule.wallpaperChanging

            onMprisButtonClicked: barModule.mprisButtonClicked(modelData)
            onPowerButtonClicked: barModule.powerButtonClicked(modelData)
            onNotificationButtonClicked: barModule.notificationButtonClicked(modelData)
            onClockRightClicked: barModule.agendaButtonClicked(modelData)
            onAudioButtonClicked: barModule.audioButtonClicked(modelData)
            onMenuButtonClicked: barModule.menuButtonClicked(modelData)
            onTrayMenuOpened: barModule.trayMenuOpened()
        }

        LeftModules {
            id: leftModules
            targetScreen: modelData

            centerHeight: centerModules.pillExtent
            mprisOpen: barModule.mprisOpen
            notifyOpen: barModule.notifyOpen
            agendaOpen: barModule.agendaOpen
            audioOpen: barModule.audioOpen
            menuOpen: barModule.menuOpen
            popupOpen: barModule.popupOpen
            wallpaperChanging: barModule.wallpaperChanging

            frameArmLeft: barModule.armLeft
            frameArmTop: barModule.armTop

            onMprisButtonClicked: barModule.mprisButtonClicked(modelData)
            onPowerButtonClicked: barModule.powerButtonClicked(modelData)
            onNotificationButtonClicked: barModule.notificationButtonClicked(modelData)
            onClockRightClicked: barModule.agendaButtonClicked(modelData)
            onAudioButtonClicked: barModule.audioButtonClicked(modelData)
            onMenuButtonClicked: barModule.menuButtonClicked(modelData)
            onTrayMenuOpened: barModule.trayMenuOpened()
        }

        RightModules {
            id: rightModules
            targetScreen: modelData

            centerHeight: centerModules.pillExtent
            mprisOpen: barModule.mprisOpen
            notifyOpen: barModule.notifyOpen
            agendaOpen: barModule.agendaOpen
            audioOpen: barModule.audioOpen
            menuOpen: barModule.menuOpen
            popupOpen: barModule.popupOpen
            wallpaperChanging: barModule.wallpaperChanging

            frameArmRight: barModule.armRight
            frameArmBottom: barModule.armBottom

            onMprisButtonClicked: barModule.mprisButtonClicked(modelData)
            onPowerButtonClicked: barModule.powerButtonClicked(modelData)
            onNotificationButtonClicked: barModule.notificationButtonClicked(modelData)
            onClockRightClicked: barModule.agendaButtonClicked(modelData)
            onAudioButtonClicked: barModule.audioButtonClicked(modelData)
            onMenuButtonClicked: barModule.menuButtonClicked(modelData)
            onTrayMenuOpened: barModule.trayMenuOpened()
        }
        }
    }
}
