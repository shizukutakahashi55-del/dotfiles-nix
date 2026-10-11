// Bar.qml — BAR

import Quickshell
import Quickshell.Wayland
import QtQuick

import "./CENTER"
import "./LEFT"
import "./RIGHT"
import "./components"
import "../COMMON"


Variants {
    id: barModule


    model: Theme.pillMode ? [] : Quickshell.screens


    signal menuButtonClicked(var screen)

    signal notificationButtonClicked(var screen)

    signal overviewButtonClicked(var screen)

    signal agendaButtonClicked(var screen)

    signal mprisButtonClicked(var screen)

    signal powerButtonClicked(var screen)

    signal audioButtonClicked(var screen)


    signal trayMenuOpened()


    property bool menuOpen: false
    property bool notifyOpen: false
    property bool overviewOpen: false
    property bool agendaOpen: false
    property bool mprisOpen: false

    property bool audioOpen: false


    property bool popupOpen: false


    property bool wallpaperChanging: false


    property bool hideOnFullscreen: true
    property bool hideOnWallpaperChange: true


    property bool screenCorners: true

    // ── Brazos del marco para las esquinas (ver BAR/components/FrameCorner.qml) ──


    readonly property bool framArmsActive: Theme.frameOn && barModule.screenCorners && Theme.frameCurved
        && !Theme.barSeparated && !Theme.barRebuilding


    readonly property real frameTv: (Theme.frameThicknessVis > 0.01) ? Theme.frameThicknessVis : 0
    readonly property real armTop:    (barModule.framArmsActive && Theme.barPosition !== "top")    ? barModule.frameTv : 0
    readonly property real armBottom: (barModule.framArmsActive && Theme.barPosition !== "bottom") ? barModule.frameTv : 0
    readonly property real armLeft:   (barModule.framArmsActive && Theme.barPosition !== "left")   ? barModule.frameTv : 0
    readonly property real armRight:  (barModule.framArmsActive && Theme.barPosition !== "right")  ? barModule.frameTv : 0
    readonly property real armTopWin:    (barModule.framArmsActive && Theme.barPosition !== "top")
        ? Math.max(Theme.frameThickness, Math.ceil(barModule.armTop)) : 0
    readonly property real armBottomWin: (barModule.framArmsActive && Theme.barPosition !== "bottom")
        ? Math.max(Theme.frameThickness, Math.ceil(barModule.armBottom)) : 0


    delegate: Component {


        Item {
            id: screenRoot
            property var modelData


            readonly property bool suppressed:
                (barModule.hideOnFullscreen && FullscreenState.isOn(modelData))
                || (barModule.hideOnWallpaperChange && barModule.wallpaperChanging)

        // ─── Fondo de la barra ───────────────────────────────────


        PanelWindow {
            id: barPanel
            screen: modelData

            visible: !Theme.barRebuilding


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


            BackgroundEffect.blurRegion: GlassRegion {
                rect: barBg
                rectOn: Theme.glassBlurOn && !Theme.islandsMode && !screenRoot.suppressed
                rectRadius: Theme.barRadius
            }

            SkinRect {
                id: barBg
                anchors.fill: parent
                color: Theme.panelBg
                radius: Theme.barRadius
                raised: Theme.cozy && Theme.barFloating
                depth: 2
                notch: 0
                inkColor: Theme.ink


                opacity: (screenRoot.suppressed || Theme.islandsMode) ? 0 : 1
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

            // // ─── Enviar detrás de Waybar ─────────────────────────


        }

        // ─── Esquinas de pantalla (las 4) ────────────────────────


        // ── Superiores: justo debajo de la barra (o en el borde de arriba si
        //    la barra está abajo) ──


        PanelWindow {
            id: cornersTop
            screen: modelData
            anchors { top: true; left: true; right: true }

            margins.top: (Theme.barVertical || Theme.barAtBottom) ? 0 : Theme.barOffset


            implicitHeight: Theme.frameCornerRadius + barModule.armTopWin
            color: "transparent"


            exclusiveZone: -1
            visible: Theme.frameOn && barModule.screenCorners && !Theme.barSeparated && !Theme.barRebuilding && Theme.frameCornerRadius > 0
            WlrLayershell.namespace: "quickshell-screen-corners-top"


            WlrLayershell.layer: WlrLayer.Overlay


            mask: Region {}

            Item {
                anchors.fill: parent

                opacity: screenRoot.suppressed ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: Theme.animDuration(150); easing.type: Easing.OutCubic } }


                FrameCorner {
                    anchors.left: parent.left
                    anchors.leftMargin: (Theme.barVertical && !Theme.barAtRight) ? Theme.barOffset : 0
                    anchors.top: parent.top
                    armX: barModule.armLeft
                    armY: barModule.armTop
                }
                FrameCorner {
                    anchors.right: parent.right
                    anchors.rightMargin: (Theme.barVertical && Theme.barAtRight) ? Theme.barOffset : 0
                    anchors.top: parent.top
                    atRight: true
                    armX: barModule.armRight
                    armY: barModule.armTop
                }
            }
        }

        // ── Inferiores: pegadas al borde de abajo (o justo encima de la barra
        //    si la barra está abajo) ──
        PanelWindow {
            id: cornersBottom
            screen: modelData
            anchors { bottom: true; left: true; right: true }
            margins.bottom: (!Theme.barVertical && Theme.barAtBottom) ? Theme.barOffset : 0
            implicitHeight: Theme.frameCornerRadius + barModule.armBottomWin
            color: "transparent"

            exclusiveZone: -1
            visible: Theme.frameOn && barModule.screenCorners && !Theme.barSeparated && !Theme.barRebuilding && Theme.frameCornerRadius > 0
            WlrLayershell.namespace: "quickshell-screen-corners-bottom"

            WlrLayershell.layer: WlrLayer.Overlay

            mask: Region {}

            Item {
                anchors.fill: parent
                opacity: screenRoot.suppressed ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: Theme.animDuration(150); easing.type: Easing.OutCubic } }

                FrameCorner {
                    anchors.left: parent.left
                    anchors.leftMargin: (Theme.barVertical && !Theme.barAtRight) ? Theme.barOffset : 0
                    anchors.bottom: parent.bottom
                    atBottom: true
                    armX: barModule.armLeft
                    armY: barModule.armBottom
                }
                FrameCorner {
                    anchors.right: parent.right
                    anchors.rightMargin: (Theme.barVertical && Theme.barAtRight) ? Theme.barOffset : 0
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
            screen: modelData
            suppressed: screenRoot.suppressed
            active: Theme.frameOn && barModule.screenCorners && Theme.frameCurved
                    && !Theme.barSeparated && !Theme.barRebuilding
        }


        CenterModules {
            id: centerModules
            targetScreen: modelData


            topReserve: leftModules.extent
            bottomReserve: rightModules.extent
            notifyOpen: barModule.notifyOpen
            overviewOpen: barModule.overviewOpen
            agendaOpen: barModule.agendaOpen
            popupOpen: barModule.popupOpen
            wallpaperChanging: barModule.wallpaperChanging
            onNotificationButtonClicked: barModule.notificationButtonClicked(modelData)
            onOverviewButtonClicked: barModule.overviewButtonClicked(modelData)
            onClockRightClicked: barModule.agendaButtonClicked(modelData)
        }

        LeftModules {
            id: leftModules
            targetScreen: modelData
            mprisOpen: barModule.mprisOpen
            popupOpen: barModule.popupOpen
            wallpaperChanging: barModule.wallpaperChanging


            frameArmLeft: barModule.armLeft
            frameArmTop: barModule.armTop
            onMprisButtonClicked: barModule.mprisButtonClicked(modelData)
            onPowerButtonClicked: barModule.powerButtonClicked(modelData)
        }

        RightModules {
            id: rightModules
            targetScreen: modelData


            centerHeight: centerModules.pillExtent
            audioOpen: barModule.audioOpen
            menuOpen: barModule.menuOpen
            popupOpen: barModule.popupOpen
            wallpaperChanging: barModule.wallpaperChanging


            frameArmRight: barModule.armRight
            frameArmBottom: barModule.armBottom
            onAudioButtonClicked: barModule.audioButtonClicked(modelData)

            onMenuButtonClicked: barModule.menuButtonClicked(modelData)
            onTrayMenuOpened: barModule.trayMenuOpened()
        }
        }
    }
}
