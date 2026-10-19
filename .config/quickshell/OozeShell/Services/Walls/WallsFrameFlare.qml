// WallsFrameFlare — el marco inferior "respira" mientras se aplica un

import QtQuick
import "../../COMMON"

Item {
    id: root

    property color fillColor: Theme.bg


    property real restRadius: Theme.frameCornerRadius


    readonly property bool floating: Theme.wallpaperChanging

    // ── Despegue de los costados ──────────────────────────────────
    readonly property real gapTarget: 22
    property real gap: root.floating ? root.gapTarget : 0
    Behavior on gap { NumberAnimation { duration: Theme.animDuration(320); easing.type: Easing.OutCubic } }

    // ── Esquinas: de rectas a cápsula ────────────────────────────
    readonly property real pillRadius: Math.min(root.restRadius, root.height / 2)
    property real radius: root.floating ? root.pillRadius : 0
    Behavior on radius { NumberAnimation { duration: Theme.animDuration(320); easing.type: Easing.OutCubic } }

    Rectangle {
        id: pill
        anchors.fill: parent
        anchors.leftMargin: root.gap
        anchors.rightMargin: root.gap
        color: root.fillColor
        topLeftRadius: root.radius
        topRightRadius: root.radius
        bottomLeftRadius: root.radius
        bottomRightRadius: root.radius
    }


    Rectangle {
        anchors.fill: pill
        radius: pill.radius
        color: "transparent"
        border.width: Theme.bw1
        border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.55)
        visible: root.floating
        opacity: 0

        SequentialAnimation on opacity {
            running: root.floating && Theme.uiAnimationsEnabled
            loops: Animation.Infinite
            NumberAnimation { from: 0;   to: 0.9; duration: Theme.animDuration(620); easing.type: Easing.InOutSine }
            NumberAnimation { from: 0.9; to: 0;   duration: Theme.animDuration(620); easing.type: Easing.InOutSine }
        }
    }
}
