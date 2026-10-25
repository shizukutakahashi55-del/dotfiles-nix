// DashboardQuickAccess.qml — DASHBOARD

import QtQuick
import QtQuick.Layouts
import "../../COMMON"
import "../../Services/Lang"
import "../../Services/Network"
import "../../Services/Bluetooth"
import "../../Services/Brightness"
import "../../Services/Caffeine"
import "../../Services/Screenshot"


Item {
    id: root
    readonly property bool compact: Theme.pillMode
    readonly property int cols: root.compact ? 4 : 2
    readonly property int compactTileH: Theme.ds(74)

    readonly property int preferredWidth: Theme.ds(440)
    readonly property int preferredHeight: root.compact
        ? Theme.ds(24) + 2 * root.compactTileH + Theme.ds(6) + Theme.ds(8) + Theme.ds(36)
            + (BrightnessBackend.available ? Theme.ds(54) : 0)
        : Theme.ds(314) + (BrightnessBackend.available ? Theme.ds(50) : 0)
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
          sub: Translations.t(Theme.performanceMode ? "perfToastOn" : "perfToastOff") },
        { id: "recArea",     icon: RecorderBackend.gArea, title: Translations.t("recTileArea"),
          active: RecorderBackend.active && RecorderBackend.mode === "area",
          sub: RecorderBackend.active && RecorderBackend.mode === "area"
               ? RecorderBackend.elapsedText : Translations.t("recTileAreaSub") },
        { id: "recScreen",   icon: RecorderBackend.gScreen, title: Translations.t("recTileScreen"),
          active: RecorderBackend.active && RecorderBackend.mode === "screen",
          sub: RecorderBackend.active && RecorderBackend.mode === "screen"
               ? RecorderBackend.elapsedText : Translations.t("recTileScreenSub") }
    ]

    // ── Teclado ──
    property int sel: 0
    property bool kbd: false
    DashboardNav { id: nav }
    HoverHandler { onPointChanged: root.kbd = false }

    function handleKey(key, modifiers) {
        if (nav.isDir(key)) {
            if (!root.kbd) { root.kbd = true; return true }
            const n = nav.move(root.sel, root.tiles.length, root.cols, key)
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
        else if (id === "recArea" || id === "recScreen") {
            if (RecorderBackend.active) RecorderBackend.stop()
            else { AppState.closeDashboard(); RecorderBackend.launchLater(id === "recArea" ? "area" : "screen") }
        }
        else requestWalls()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.ds(12)
        spacing: Theme.ds(8)

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: root.cols
            rowSpacing: Theme.ds(6)
            columnSpacing: Theme.ds(6)

            // ── Fichas compactas (píldora) ──

            Repeater {
                model: root.compact ? root.tiles : []
                delegate: DashboardTile {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: root.compactTileH
                    icon: modelData.icon
                    title: modelData.title
                    sub: modelData.sub
                    lit: modelData.active === true
                    selected: root.kbd && root.sel === index
                    onClicked: root.fire(modelData.id)
                }
            }

            // ── Fichas anchas (barra) ──

            Repeater {
                model: root.compact ? [] : root.tiles
                delegate: Rectangle {
                    id: tile
                    required property var modelData
                    required property int index
                    readonly property bool lit: modelData.active === true
                    readonly property bool hot: tm.containsMouse || (root.kbd && root.sel === tile.index)
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1


                    radius: Theme.cozy ? 0 : MdTokens.rL
                    border.width: (root.kbd && root.sel === tile.index && !Theme.cozy) ? 2 : ((Theme.cozy || tile.lit) ? 0 : 1)
                    border.color: (root.kbd && root.sel === tile.index && !Theme.cozy) ? Theme.primary : MdTokens.edgeSoft
                    color: Theme.cozy ? "transparent"
                         : (tile.lit ? (tile.hot ? Qt.lighter(Theme.primary, 1.08) : Theme.primary)
                                     : (tile.hot ? MdTokens.containerHighest : MdTokens.containerHigh))
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
                        fillTop: Theme.mix(Theme.surface, Theme.primary, tile.lit ? 0.66 : (tile.hot ? 0.26 : 0.10))
                        fillBottom: Theme.mix(Theme.surface, Theme.primary, tile.lit ? 0.38 : (tile.hot ? 0.08 : 0.0))
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.ds(8)
                        anchors.topMargin: Theme.ds(8) + tile.sink
                        anchors.bottomMargin: Theme.ds(8) + Theme.shadowY - tile.sink
                        spacing: Theme.ds(8)
                        Item {
                            Layout.preferredWidth: Theme.ds(38)
                            Layout.preferredHeight: Theme.ds(38)
                            Layout.alignment: Qt.AlignVCenter

                            MdShape {
                                visible: !Theme.cozy
                                anchors.fill: parent
                                shape: tile.lit ? "cookie12" : "cookie9"
                                color: tile.lit ? Qt.alpha(Theme.textOnPrimary, 0.24) : Qt.alpha(Theme.primary, tile.hot ? 0.40 : 0.26)
                                rotation: tile.hot ? 14 : 0
                                Behavior on rotation { NumberAnimation { duration: Theme.animDuration(220); easing.type: Easing.OutBack } }
                                Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
                            }
                            Text {
                                anchors.centerIn: parent
                                text: tile.modelData.icon
                                color: (tile.lit && !Theme.cozy) ? Theme.textOnPrimary : Theme.primary
                                font.pixelSize: Theme.dfs(17)
                                font.family: Theme.monoFamily
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text {
                                Layout.fillWidth: true
                                font.bold: true
                                text: tile.modelData.title
                                color: (tile.lit && !Theme.cozy) ? Theme.textOnPrimary : Theme.text
                                font.pixelSize: Theme.dfs(12)
                                font.family: Theme.fontFamily
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                visible: tile.modelData.sub !== ""
                                text: tile.modelData.sub
                                color: (tile.lit && !Theme.cozy) ? Theme.withAlpha(Theme.textOnPrimary, 0.82) : Theme.mix(Theme.subtext, Theme.text, 0.4)
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
            Layout.preferredHeight: Theme.ds(46)
            radius: Theme.cozy ? 4 : MdTokens.rL
            color: Theme.cozy ? Theme.surface : MdTokens.control
            border.width: Theme.cozy ? 0 : 1
            border.color: MdTokens.edgeSoft
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
                        height: bSlider.grabbed ? 20 : 16
                        radius: height / 2
                        color: Qt.alpha(Theme.primary, 0.22)
                        Behavior on height { NumberAnimation { duration: Theme.animDuration(100) } }

                        Rectangle {
                            width: Math.max(parent.height, bTrack.width * Math.max(0, Math.min(1, brightCard.value)) - 4)
                            height: parent.height
                            radius: parent.radius
                            color: Theme.primary
                        }
                        Rectangle {
                            x: Math.max(0, Math.min(bTrack.width - width, bTrack.width * Math.max(0, Math.min(1, brightCard.value)) - width / 2))
                            anchors.verticalCenter: parent.verticalCenter
                            width: 4
                            height: bSlider.grabbed ? 30 : 26
                            radius: 2
                            color: Theme.text
                            Behavior on height { NumberAnimation { duration: Theme.animDuration(100) } }
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
            radius: Theme.cozy ? 0 : height / 2
            color: Theme.cozy ? "transparent"
                 : (am.containsMouse ? Theme.primary : MdTokens.control)
            border.width: Theme.cozy ? 0 : 1
            border.color: am.containsMouse ? Theme.primary : MdTokens.edgeSoft
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
