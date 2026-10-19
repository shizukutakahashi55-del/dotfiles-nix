// DashboardQuickAccess.qml — DASHBOARD

import QtQuick
import QtQuick.Layouts
import "../../COMMON"
import "../../Services/Lang"
import "../../Services/Network"
import "../../Services/Bluetooth"
import "../../Services/Brightness"
import "../../Services/Caffeine"


Item {
    id: root
    readonly property int preferredWidth: Theme.ds(440)
    readonly property int preferredHeight: Theme.ds(240) + (BrightnessBackend.available ? Theme.ds(50) : 0)
    signal requestNetwork()
    signal requestBluetooth()
    signal requestAppearance()
    signal requestWalls()
    signal requestAdvancedSettings()

    Component.onCompleted: { NetworkBackend.menuWatch = true; BrightnessBackend.acquireWatch() }
    Component.onDestruction: { NetworkBackend.menuWatch = false; BrightnessBackend.releaseWatch() }

    readonly property var tiles: [
        { id: "network",    icon: NetworkBackend.statusIcon,   title: Translations.t("netTitle"),
          sub: NetworkBackend.summary },
        { id: "bluetooth",  icon: BluetoothBackend.statusIcon, title: Translations.t("btTitle"),
          sub: BluetoothBackend.summary },
        { id: "appearance", icon: OozeIcons.appearance, title: Translations.t("appearanceTitle"), sub: "" },
        { id: "walls",      icon: OozeIcons.walls, title: Translations.t("menuWallpaper"),    sub: "" },
        { id: "caffeine",   icon: CaffeineBackend.active ? OozeIcons.caffeine : OozeIcons.caffeineOff,
          title: Translations.t("caffeineTitle"), active: CaffeineBackend.active,
          sub: Translations.t(CaffeineBackend.active ? "caffeineOn" : "caffeineOff") },
        { id: "performance", icon: OozeIcons.performance,
          title: Translations.t("perfToastTitle"), active: Theme.performanceMode,
          sub: Translations.t(Theme.performanceMode ? "perfToastOn" : "perfToastOff") }
    ]

    // ── Teclado ──
    property int sel: 0
    property bool kbd: false
    DashboardNav { id: nav }
    HoverHandler { onPointChanged: root.kbd = false }

    function handleKey(key, modifiers) {
        if (nav.isDir(key)) {
            if (!root.kbd) { root.kbd = true; return true }
            const n = nav.move(root.sel, root.tiles.length, 2, key)
            if (n < 0) return false
            root.sel = n
            return true
        }
        if (nav.isAccept(key)) {
            if (!root.kbd) { root.kbd = true; return true }
            const t = root.tiles[root.sel]
            if (t) root.fire(t.id)
            return true
        }
        return false
    }

    function fire(id) {
        if (id === "network") requestNetwork()
        else if (id === "bluetooth") requestBluetooth()
        else if (id === "appearance") requestAppearance()
        else if (id === "caffeine") CaffeineBackend.toggle()
        else if (id === "performance") Theme.setPerformanceMode(!Theme.performanceMode)
        else requestWalls()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.ds(12)
        spacing: Theme.ds(8)

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 2
            rowSpacing: Theme.ds(6)
            columnSpacing: Theme.ds(6)

            Repeater {
                model: root.tiles
                delegate: Rectangle {
                    id: tile
                    required property var modelData
                    required property int index
                    readonly property bool lit: modelData.active === true
                    readonly property bool hot: tm.containsMouse || (root.kbd && root.sel === tile.index)
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1


                    radius: Theme.cozy ? 0 : Theme.ds(12)
                    border.width: (root.kbd && root.sel === tile.index && !Theme.cozy) ? 2 : 0
                    border.color: Theme.primary
                    color: Theme.cozy ? "transparent"
                         : (tile.lit ? Theme.mix(Theme.surface, Theme.primary, tile.hot ? 0.34 : 0.24)
                                     : (tile.hot ? Theme.surfaceHigh : Theme.surface))
                    Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
                    scale: Theme.cozy ? 1.0 : (tm.pressed ? 0.97 : 1.0)
                    Behavior on scale { NumberAnimation { duration: Theme.animDuration(120) } }
                    readonly property int sink: (Theme.cozy && tm.pressed) ? Theme.shadowY : 0

                    CozyBox {
                        visible: Theme.cozy
                        x: 0
                        y: tile.sink
                        width: parent.width
                        height: parent.height - Theme.shadowY
                        notch: 4
                        shadow: !tm.pressed
                        shadowOffset: Theme.shadowY
                        fillTop: Theme.mix(Theme.surface, Theme.primary, tile.lit ? 0.40 : (tile.hot ? 0.26 : 0.12))
                        fillBottom: Theme.mix(Theme.surface, Theme.primary, tile.lit ? 0.18 : (tile.hot ? 0.08 : 0.02))
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.ds(8)
                        anchors.topMargin: Theme.ds(8) + tile.sink
                        anchors.bottomMargin: Theme.ds(8) + Theme.shadowY - tile.sink
                        spacing: Theme.ds(8)
                        Text {
                            text: tile.modelData.icon
                            color: Theme.primary
                            font.pixelSize: Theme.dfs(17)
                            font.family: Theme.monoFamily
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text {
                                Layout.fillWidth: true
                                text: tile.modelData.title
                                color: Theme.text
                                font.pixelSize: Theme.dfs(12)
                                font.family: Theme.fontFamily
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                visible: tile.modelData.sub !== ""
                                text: tile.modelData.sub
                                color: Theme.subtext
                                font.pixelSize: Theme.dfs(9)
                                font.family: Theme.fontFamily
                                elide: Text.ElideRight
                            }
                        }
                    }
                    MouseArea {
                        id: tm
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.fire(tile.modelData.id)
                    }
                }
            }
        }

        // ── Brillo de pantalla ───────────────────────────────────

        SkinRect {
            id: brightCard
            visible: BrightnessBackend.available
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.ds(40)
            radius: Theme.cozy ? 4 : Theme.ds(12)
            color: Theme.surface
            readonly property real value: BrightnessBackend.brightness

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.ds(12)
                anchors.rightMargin: Theme.ds(12)
                spacing: Theme.ds(10)

                Text {
                    text: brightCard.value < 0.5 ? OozeIcons.brightnessLow : OozeIcons.brightnessHigh
                    color: Theme.primary
                    font.pixelSize: Theme.dfs(18)
                    font.family: Theme.monoFamily
                }

                Item {
                    id: bSlider
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.ds(28)
                    readonly property bool grabbed: bArea.containsMouse || bArea.pressed

                    PixelBar {
                        visible: Theme.cozy
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: Math.max(12, Theme.ds(16))
                        ratio: brightCard.value
                        colorA: Theme.mix(Theme.primary, Theme.bg, 0.40)
                        colorB: Theme.primary
                    }

                    Rectangle {
                        id: bTrack
                        visible: !Theme.cozy
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: bSlider.grabbed ? 8 : 6
                        radius: height / 2
                        color: Theme.surfaceHigh
                        Behavior on height { NumberAnimation { duration: Theme.animDuration(100) } }

                        Rectangle {
                            width: bTrack.width * Math.max(0, Math.min(1, brightCard.value))
                            height: parent.height
                            radius: parent.radius
                            color: Theme.primary
                        }
                        Rectangle {
                            x: bTrack.width * Math.max(0, Math.min(1, brightCard.value)) - width / 2
                            anchors.verticalCenter: parent.verticalCenter
                            width: bSlider.grabbed ? 14 : 0
                            height: width
                            radius: width / 2
                            color: Theme.text
                            Behavior on width { NumberAnimation { duration: Theme.animDuration(100) } }
                        }
                    }

                    MouseArea {
                        id: bArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        function setFrom(mx) {
                            BrightnessBackend.dragging = true
                            BrightnessBackend.setBrightness(Math.max(0, Math.min(1, mx / width)))
                        }
                        function done() { BrightnessBackend.dragging = false; BrightnessBackend.commit() }
                        onPressed: mouse => setFrom(mouse.x)
                        onPositionChanged: mouse => { if (pressed) setFrom(mouse.x) }
                        onReleased: done()
                        onCanceled: done()
                        onWheel: wheel => {
                            BrightnessBackend.stepBrightness(wheel.angleDelta.y > 0 ? 0.05 : -0.05)
                        }
                    }
                }

                Text {
                    Layout.preferredWidth: Theme.ds(36)
                    horizontalAlignment: Text.AlignRight
                    text: Math.round(brightCard.value * 100) + "%"
                    color: Theme.text
                    font.pixelSize: Theme.dfs(11)
                    font.bold: true
                    font.family: Theme.fontFamily
                }
            }
        }

        Rectangle {
            id: advBtn
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.ds(36)
            radius: Theme.cozy ? 0 : Theme.ds(12)
            color: Theme.cozy ? "transparent"
                 : (am.containsMouse ? Theme.primary : Theme.surface)
            Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
            readonly property int sink: (Theme.cozy && am.pressed) ? Theme.shadowY : 0

            CozyBox {
                visible: Theme.cozy
                x: 0
                y: advBtn.sink
                width: parent.width
                height: parent.height - Theme.shadowY
                notch: 4
                shadow: !am.pressed
                shadowOffset: Theme.shadowY
                fillTop: Theme.mix(am.containsMouse ? Theme.primary : Theme.surface, "#ffffff", 0.10)
                fillBottom: am.containsMouse ? Theme.primary : Theme.surface
            }

            RowLayout {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: advBtn.sink - Math.round(Theme.shadowY / 2)
                spacing: Theme.ds(8)
                Text {
                    text: OozeIcons.settings
                    color: am.containsMouse ? Theme.textOnPrimary : Theme.primary
                    font.pixelSize: Theme.dfs(15)
                    font.family: Theme.monoFamily
                }
                Text {
                    text: Translations.t("settingsAdvancedSection")
                    color: am.containsMouse ? Theme.textOnPrimary : Theme.text
                    font.pixelSize: Theme.dfs(11)
                    font.family: Theme.fontFamily
                }
            }
            MouseArea {
                id: am
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.requestAdvancedSettings()
            }
        }
    }
}
