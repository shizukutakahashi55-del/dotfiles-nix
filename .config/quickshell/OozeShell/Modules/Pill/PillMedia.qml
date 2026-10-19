// PillMedia.qml — PILL

import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import "../../COMMON"
import "../../Services/Mpris"
import "../../Services/Lang"

RowLayout {
    id: root

    property bool active: false
    signal openRequested()

    readonly property int thumb: 28
    readonly property int textW: 150

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
    ClippingRectangle {
        Layout.preferredWidth: root.thumb
        Layout.preferredHeight: root.thumb
        Layout.alignment: Qt.AlignVCenter
        radius: Theme.cozy ? 3 : 9
        color: Theme.surfaceHigh
        border.width: Theme.cozy ? 2 : 0
        border.color: Theme.ink
        opacity: root.playing ? 1 : 0.55
        Behavior on opacity { NumberAnimation { duration: Theme.animDuration(200) } }

        Image {
            id: art
            anchors.fill: parent
            source: Theme.shellPerf ? "" : MprisBackend.currentArt
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            smooth: true
            sourceSize: Qt.size(64, 64)
        }

        Text {
            anchors.centerIn: parent
            visible: art.status !== Image.Ready
            text: "󰝚"
            color: Theme.primary
            font.family: Theme.monoFamily
            font.pixelSize: Theme.fs(15)
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openRequested()
        }
    }

    // ── Marquesina ──
    Item {
        id: marquee
        Layout.preferredWidth: root.textW
        Layout.preferredHeight: 22
        Layout.alignment: Qt.AlignVCenter
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

    // ── Controles ──
    component Ctl: SkinRect {
        id: ctl
        property string glyph: ""
        property bool strong: false
        property bool available: true
        signal clicked()

        Layout.preferredWidth: 26
        Layout.preferredHeight: 26
        Layout.alignment: Qt.AlignVCenter
        radius: 13
        color: (ctlMouse.containsMouse || ctl.strong) ? Theme.surface : "transparent"
        opacity: ctl.available ? 1 : 0.4
        Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }

        scale: Theme.cozy ? 1.0 : (ctlMouse.pressed ? 0.88 : 1.0)
        Behavior on scale { NumberAnimation { duration: Theme.animDuration(140); easing.type: Easing.OutBack } }

        Text {
            anchors.centerIn: parent
            text: ctl.glyph
            color: ctl.strong ? Theme.primary : Theme.text
            font.family: Theme.monoFamily
            font.pixelSize: Theme.fs(ctl.strong ? 16 : 14)
        }

        MouseArea {
            id: ctlMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: ctl.available
            cursorShape: Qt.PointingHandCursor
            onClicked: ctl.clicked()
        }
    }

    Ctl { available: root.hasPlayer; glyph: "󰒮"; onClicked: MprisBackend.runCtl(["previous"]) }
    Ctl { available: root.hasPlayer; glyph: root.playing ? "󰏤" : "󰐊"; strong: true; onClicked: MprisBackend.runCtl(["play-pause"]) }
    Ctl { available: root.hasPlayer; glyph: "󰒭"; onClicked: MprisBackend.runCtl(["next"]) }
}
