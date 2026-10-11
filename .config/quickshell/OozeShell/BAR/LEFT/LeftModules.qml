// LeftModules.qml — LEFT

import Quickshell
import Quickshell.Io
import Quickshell.Wayland

import QtQuick
import QtQuick.Layouts

import "../../COMMON"
import "../../LANG"
import "../../MPRIS"

// ─────────────────────────────────────────────────────────────────


// ─────────────────────────────────────────────────────────────────
Item {
    id: leftModules


    signal mprisButtonClicked()

    signal powerButtonClicked()


    property bool mprisOpen: false
    property bool wallpaperChanging: false

    property bool popupOpen: false


    property real frameArmLeft: 0
    property real frameArmTop: 0

    property var targetScreen

    // ── Configuración ────────────────────────────────────────────
    property bool hideOnFullscreen: true
    property bool hideOnWallpaperChange: true
    property int leftMargin: 6
    property int songMaxWidth: 260

    readonly property bool suppressed:
        (hideOnFullscreen && FullscreenState.isOn(targetScreen))
        || (hideOnWallpaperChange && wallpaperChanging)

    // ── Modo Islas: publicar dónde está esta isla (coords de pantalla) ──

    readonly property string screenName: targetScreen ? targetScreen.name : ""
    readonly property var islandRect: {
        if (!Theme.islandsMode || !targetScreen) return null
        return {
            x: Math.max(leftModules.leftMargin, leftModules.frameArmLeft) + Theme.barEdge,
            y: Theme.barAtBottom ? targetScreen.height - Theme.barEdge - pill.height : Theme.barEdge,
            w: pill.width,
            h: pill.height
        }
    }
    function publishIsland() {
        if (leftModules.screenName === "") return
        if (leftModules.islandRect) IslandState.report(leftModules.screenName, "left", leftModules.islandRect)
        else IslandState.clear(leftModules.screenName, "left")
    }
    onIslandRectChanged: publishIsland()
    Connections {
      target: IslandState
      function onRefreshRequested() { leftModules.publishIsland() }
    }
    Component.onCompleted: publishIsland()


    readonly property real extent: Theme.barVertical
        ? Theme.barEdge + Math.max(leftModules.leftMargin, leftModules.frameArmTop) + pill.height
        : 0

    // ============================================================

    // ============================================================


    readonly property string mprisStatus:
        MprisBackend.activePlayers.length > 0 ? MprisBackend.currentStatus : ""
    readonly property string mprisArtist: MprisBackend.currentArtist
    readonly property string mprisTitle: MprisBackend.currentTitle

    readonly property string songLabel:
        (mprisArtist !== "" && mprisTitle !== "")
            ? mprisArtist + " - " + mprisTitle
            : (mprisTitle !== "" ? mprisTitle : mprisArtist)

    readonly property bool hasSong: songLabel !== ""


    readonly property string songTip: {
        if (!hasSong) return Translations.t("mprisNoPlaying")
        if (mprisTitle !== "" && mprisArtist !== "") return mprisTitle + "\n" + mprisArtist
        return songLabel
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

    readonly property bool tipAllowed: !popupOpen && !suppressed
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
        target: pill
        function onWidthChanged() { Qt.callLater(leftModules.tipRefresh) }
    }

    function tipLeave(item) {
        if (tipTarget !== item) return
        tipShowTimer.stop()
        tipHideTimer.restart()
    }


    Timer { id: tipShowTimer; interval: 500; repeat: false; onTriggered: leftModules.tipShown = true }

    Timer { id: tipHideTimer; interval: 150; repeat: false; onTriggered: leftModules.tipShown = false }


    onSuppressedChanged: { if (suppressed) tipShown = false }

    component PillButton: SkinRect {
        id: btn

        property string tip: ""
        property bool active: false
        property real hoverScale: 1.06


        default property alias content: row.data

        signal clicked(var mouse)
        signal scrolled(var wheel)
        signal hoverEntered()
        signal hoverExited()


        Layout.preferredHeight: Theme.barVertical ? Math.max(30, row.implicitHeight + 12) : 30
        Layout.preferredWidth: Theme.barVertical ? 40 : Math.max(34, row.implicitWidth + 16)

        radius: Theme.cardRadius
        raised: Theme.cozy && (area.containsMouse || btn.active)
        depth: 2

        color: (area.containsMouse || btn.active) ? Theme.surface : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }

        scale: Theme.cozy ? 1.0 : (area.pressed ? 0.90 : (area.containsMouse ? btn.hoverScale : 1.0))
        Behavior on scale { NumberAnimation { duration: Theme.animDuration(160); easing.type: Easing.OutBack } }


        BarFlow {
            id: row
            anchors.centerIn: parent
            gap: Theme.barVertical ? 1 : 6
        }

        MouseArea {
            id: area

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton

            onEntered: btn.hoverEntered()
            onExited: btn.hoverExited()
            onClicked: mouse => btn.clicked(mouse)
            onWheel: wheel => btn.scrolled(wheel)
        }
    }

    // ============================================================

    // ============================================================

    PanelWindow {
        id: leftPanel

        screen: leftModules.targetScreen

        anchors {
            top: !Theme.barAtBottom
            bottom: Theme.barAtBottom
            left: !Theme.barAtRight
            right: Theme.barVertical && Theme.barAtRight
        }
        margins.top: Theme.barEdge + (Theme.barVertical ? Math.max(leftModules.leftMargin, leftModules.frameArmTop) : 0)
        margins.bottom: Theme.barEdge

        margins.left: Theme.barVertical ? 0 : Math.max(leftModules.leftMargin, leftModules.frameArmLeft) + Theme.barEdge
        margins.right: 0
        Behavior on margins.left { NumberAnimation { duration: Theme.animDuration(200); easing.type: Easing.OutCubic } }
        Behavior on margins.top { NumberAnimation { duration: Theme.animDuration(200); easing.type: Easing.OutCubic } }

        implicitWidth: Theme.barVertical
            ? Theme.barThickness + Math.round(340 * Theme.barScale)
            : Math.max(pill.width + 20, Math.round(360 * Theme.barScale))
        implicitHeight: Theme.barVertical
            ? pill.height + Math.round(120 * Theme.barScale)
            : Theme.barHeight + Math.round(120 * Theme.barScale)

        color: "transparent"


        visible: !leftModules.suppressed && !Theme.barRebuilding

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-left-modules"

        exclusiveZone: -1

        mask: Region { item: pill }


        property var glassPanels: []
        BackgroundEffect.blurRegion: GlassRegion {
            panels: leftPanel.glassPanels
            rect: pill
            rectOn: Theme.glassBlurOn && Theme.islandsMode
            rectRadius: Theme.islandRadius
        }

        Item {
            id: pill


            x: (Theme.barVertical && Theme.barAtRight) ? parent.width - width : 0

            y: (!Theme.barVertical && Theme.barAtBottom) ? parent.height - height : 0

            width: Theme.barVertical ? Theme.barThickness : modulesRow.implicitWidth * Theme.barScale + 14
            height: Theme.barVertical ? modulesRow.implicitHeight * Theme.barScale + 14 : Theme.barHeight

            SkinRect {
                anchors.fill: parent
                radius: Theme.islandRadius
                raised: Theme.cozy && Theme.islandsMode
                depth: 2
                notch: 0
                inkColor: Theme.ink
                color: Theme.islandBg
            }

            BarFlow {
                id: modulesRow

                anchors.centerIn: parent
                gap: 2
                scale: Theme.barScale

                // ── POWER ────────────────────────────────────
                PillButton {
                    id: powerBtn

                    tip: Translations.t("powerMenuTip")

                    onHoverEntered: leftModules.tipEnter(powerBtn)
                    onHoverExited: leftModules.tipLeave(powerBtn)

                    onClicked: leftModules.powerButtonClicked()

                    Text {
                        text: "⏻"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fs(17)
                    }
                }

                Rectangle {
                    Layout.preferredWidth: Theme.barVertical ? 18 : 1
                    Layout.preferredHeight: Theme.barVertical ? 1 : 15
                    Layout.alignment: Qt.AlignCenter
                    radius: 1
                    color: Theme.primary
                    opacity: 0.25
                }

                // ── IDIOMA (clic: siguiente layout) ──────────
                PillButton {
                    id: langBtn

                    tip: Translations.t("langSwitchTip")

                    onHoverEntered: leftModules.tipEnter(langBtn)
                    onHoverExited: leftModules.tipLeave(langBtn)

                    onClicked: KeyboardLayout.next()


                    Text {
                        visible: Theme.barVertical
                        Layout.alignment: Qt.AlignHCenter
                        text: "󰌌"
                        color: Theme.subtext
                        font.family: Theme.monoFamily
                        font.pixelSize: Theme.fs(14)
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: (Theme.barVertical ? "" : "󰌌 ") + KeyboardLayout.label
                        color: Theme.text
                        font.family: Theme.monoFamily
                        font.pixelSize: Theme.fs(13)
                    }
                }

                Rectangle {
                    Layout.preferredWidth: Theme.barVertical ? 18 : 1
                    Layout.preferredHeight: Theme.barVertical ? 1 : 15
                    Layout.alignment: Qt.AlignCenter
                    radius: 1
                    color: Theme.primary
                    opacity: 0.25
                }

                // ── MPRIS ─────────────────────────────


                PillButton {
                    id: mprisBtn

                    active: leftModules.mprisOpen
                    hoverScale: 1.03


                    tip: leftModules.songTip

                    onHoverEntered: leftModules.tipEnter(mprisBtn)
                    onHoverExited: leftModules.tipLeave(mprisBtn)

                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton)
                            MprisBackend.runCtl(["next"])
                        else
                            leftModules.mprisButtonClicked()
                    }

                    onScrolled: wheel => {
                        MprisBackend.runCtl([wheel.angleDelta.y > 0 ? "previous" : "next"])
                    }

                    Text {
                        text: leftModules.mprisStatus === "Playing" ? "󰎈"
                            : leftModules.mprisStatus === "Paused"  ? "󰏤"
                            : "󰝛"
                        color: leftModules.mprisStatus === "Playing" ? Theme.primary : Theme.subtext
                        font.family: Theme.monoFamily
                        font.pixelSize: Theme.fs(16)
                        Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
                    }


                    Text {
                        visible: !Theme.barVertical && !Theme.mprisCompact
                        Layout.maximumWidth: leftModules.songMaxWidth

                        text: leftModules.hasSong
                            ? leftModules.songLabel
                            : Translations.t("mprisNoPlaying")
                        elide: Text.ElideRight

                        color: leftModules.hasSong ? Theme.text : Theme.subtext
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fs(12)
                    }
                }

                // ── Plegar / desplegar el mpris ───────────────


                BarToggle {
                    id: mprisToggle

                    visible: !Theme.barVertical
                    collapsed: Theme.mprisCompact
                    contentAfter: false
                    tip: Translations.t(Theme.mprisCompact ? "barExpand" : "barCollapse")

                    onToggled: Theme.setMprisCompact(!Theme.mprisCompact)
                    onHoverEntered: leftModules.tipEnter(mprisToggle)
                    onHoverExited: leftModules.tipLeave(mprisToggle)
                }
            }
        }

        // ── Tooltip compartido ──────────────────────────────────

        FusedTip {
            id: tip

            open: leftModules.tipOpen
            text: leftModules.tipText


            // ── Modo Islas ──────────────────────────────────────────


            z: Theme.islandsMode ? -1 : 0
            island: "left"
            islandRectLocal: Theme.islandsMode
                ? ({ x: pill.x, y: pill.y, w: pill.width, h: pill.height }) : null
            align: "center"
            alignCenter: leftModules.tipCenterX

            x: Theme.barVertical
                ? (Theme.barAtRight ? pill.x - tip.width : Theme.barThickness)
                : (tip.islandActive
                    ? tip.placedAlong
                    : Math.max(Theme.frameSideArm, Math.min(parent.width - width - Theme.frameSideArm, leftModules.tipCenterX - width / 2)))
            y: Theme.barVertical
                ? Math.max(0, Math.min(parent.height - height, leftModules.tipCenterY - height / 2))
                : (tip.hull ? tip.placedDepth
                            : (Theme.barAtBottom ? pill.y - tip.height : Theme.barHeight))


            Behavior on x {
                enabled: tip.shown && !Theme.barVertical && !tip.hull
                NumberAnimation { duration: Theme.animDuration(160); easing.type: Easing.OutCubic }
            }
            Behavior on y {
                enabled: tip.shown && Theme.barVertical
                NumberAnimation { duration: Theme.animDuration(160); easing.type: Easing.OutCubic }
            }
        }
    }
}
