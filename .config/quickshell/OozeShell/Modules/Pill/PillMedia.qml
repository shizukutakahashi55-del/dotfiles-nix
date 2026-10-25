// PillMedia.qml — PILL

import QtQuick
import QtQuick.Layouts
import "../../COMMON"
import "../../Services/Mpris"
import "../../Services/Lang"

RowLayout {
    id: root

    property bool active: false
    signal openRequested()

    readonly property int thumb: 30
    readonly property int textW: 150

    readonly property bool wantsPosition: root.active && root.hasPlayer
    onWantsPositionChanged: MprisBackend.setWanted("pill", root.wantsPosition)
    Component.onCompleted: MprisBackend.setWanted("pill", root.wantsPosition)
    Component.onDestruction: MprisBackend.setWanted("pill", false)

    // ── Estado ──
    readonly property bool hasPlayer: MprisBackend.activePlayers.length > 0
    readonly property bool playing: hasPlayer && MprisBackend.currentStatus === "Playing"
    readonly property string title: MprisBackend.currentTitle
    readonly property string artist: MprisBackend.currentArtist
    readonly property string label: title !== "" && artist !== ""
        ? title + "  —  " + artist
        : (title !== "" ? title : artist)
    readonly property bool hasSong: hasPlayer && label !== ""

    spacing: 8

    // ── Portada ──
    Item {
        Layout.preferredWidth: root.thumb
        Layout.preferredHeight: root.thumb
        Layout.alignment: Qt.AlignVCenter

        MdCover {
            anchors.fill: parent
            source: MprisBackend.currentArt
            shape: "square"
            decodeSize: 64
            dimmed: !root.playing
            scale: coverMouse.pressed ? 0.92 : (coverMouse.containsMouse ? 1.06 : 1.0)
            Behavior on scale { NumberAnimation { duration: Theme.animDuration(160); easing.type: Easing.OutBack } }
        }

        MouseArea {
            id: coverMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openRequested()
        }
    }

    // ── Texto + barra serpiente ──
    ColumnLayout {
        Layout.preferredWidth: root.textW
        Layout.alignment: Qt.AlignVCenter
        spacing: 1

        Item {
            id: marquee
            Layout.fillWidth: true
            Layout.preferredHeight: 17
            clip: true

            readonly property string shownLabel: root.hasSong ? root.label : Translations.t("mprisNoPlaying")
            readonly property real textWidth: Math.ceil(metrics.advanceWidth)
            readonly property bool overflow: textWidth > width
            readonly property bool scrolling: overflow && Theme.uiAnimationsEnabled
            readonly property int gap: 40

            TextMetrics {
                id: metrics
                text: marquee.shownLabel
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fs(12)
            }

            Row {
                id: track
                spacing: marquee.gap
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    text: marquee.shownLabel
                    width: marquee.scrolling ? implicitWidth : marquee.width
                    elide: marquee.scrolling ? Text.ElideNone : Text.ElideRight
                    color: root.hasSong ? Theme.text : Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(12)
                }
                Text {
                    visible: marquee.scrolling
                    text: marquee.shownLabel
                    color: root.hasSong ? Theme.text : Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(12)
                }
            }

            Connections {
                target: marquee
                function onShownLabelChanged() { track.x = 0 }
            }

            SequentialAnimation {
                running: marquee.scrolling && root.playing && root.active
                loops: Animation.Infinite
                onRunningChanged: { if (!running) track.x = 0 }

                PauseAnimation { duration: 1400 }
                NumberAnimation {
                    target: track
                    property: "x"
                    from: 0
                    to: -(marquee.textWidth + marquee.gap)
                    duration: Math.max(1, (marquee.textWidth + marquee.gap) * 26)
                    easing.type: Easing.Linear
                }
            }

            Rectangle {
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                width: 10
                opacity: marquee.scrolling && track.x < -1 ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 120 } }
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Theme.bg }
                    GradientStop { position: 1.0; color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0) }
                }
            }
            Rectangle {
                anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
                width: 14
                opacity: marquee.scrolling ? 1 : 0
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0) }
                    GradientStop { position: 1.0; color: Theme.bg }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                onClicked: ev => {
                    if (ev.button === Qt.MiddleButton) MprisBackend.runCtl(["play-pause"])
                    else root.openRequested()
                }
            }
        }

        MdWavy {
            Layout.fillWidth: true
            Layout.preferredHeight: 9
            visible: root.hasPlayer && !Theme.cozy
            value: MprisBackend.progressRatio
            playing: root.playing && root.active
            reactive: true
            amplitude: 2.2
            wavelength: 16
            thickness: 3
        }

        PixelBar {
            Layout.fillWidth: true
            Layout.preferredHeight: 6
            visible: root.hasPlayer && Theme.cozy
            ratio: MprisBackend.progressRatio
            cell: 4
            gap: 1
        }
    }


    // ── Controles ──
    MdIconButton {
        Layout.alignment: Qt.AlignVCenter
        size: 28
        variant: "standard"
        enabled: root.hasPlayer
        glyph: "󰒮"
        onClicked: MprisBackend.runCtl(["previous"])
    }
    MdIconButton {
        Layout.alignment: Qt.AlignVCenter
        size: 34
        variant: "filled"
        enabled: root.hasPlayer
        glyph: root.playing ? "󰏤" : "󰐊"
        onClicked: MprisBackend.runCtl(["play-pause"])
    }
    MdIconButton {
        Layout.alignment: Qt.AlignVCenter
        size: 28
        variant: "standard"
        enabled: root.hasPlayer
        glyph: "󰒭"
        onClicked: MprisBackend.runCtl(["next"])
    }
}
