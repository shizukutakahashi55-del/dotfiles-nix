import QtQuick
import QtQuick.Layouts
import "../COMMON"
import "../LANG"
import "../NETWORK"
import "../BLUETOOTH"

// DashboardQuickAccess — los accesos rápidos de MENU/Menu.qml (Red,
// Bluetooth, Apariencia, Wallpaper) y un botón que lleva a Ajustes
// avanzados. Cada acceso solo EMITE una señal: quien abre el popup real
// (NetworkMenu, Appearance…) es shell.qml, igual que con Menu.qml.
Item {
    id: root
    readonly property int preferredWidth: Theme.ds(440)
    signal requestNetwork()
    signal requestBluetooth()
    signal requestAppearance()
    signal requestWalls()
    signal requestAdvancedSettings()

    Component.onCompleted: NetworkBackend.menuWatch = true
    Component.onDestruction: NetworkBackend.menuWatch = false

    readonly property var tiles: [
        { id: "network",    icon: NetworkBackend.statusIcon,   title: Translations.t("netTitle"),
          sub: NetworkBackend.summary },
        { id: "bluetooth",  icon: BluetoothBackend.statusIcon, title: Translations.t("btTitle"),
          sub: BluetoothBackend.summary },
        { id: "appearance", icon: "󰏘", title: Translations.t("appearanceTitle"), sub: "" },
        { id: "walls",      icon: "󰸉", title: Translations.t("menuWallpaper"),    sub: "" }
    ]

    function fire(id) {
        if (id === "network") requestNetwork()
        else if (id === "bluetooth") requestBluetooth()
        else if (id === "appearance") requestAppearance()
        else requestWalls()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.ds(14)
        spacing: Theme.ds(10)

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 2
            rowSpacing: Theme.ds(8)
            columnSpacing: Theme.ds(8)

            Repeater {
                model: root.tiles
                delegate: Rectangle {
                    id: tile
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    // CoOzey: la tarjeta la dibuja el CozyBox de abajo; se hunde
                    // hasta su sombra al pulsar (sin escala: borrosa el pixel art)
                    radius: Theme.cozy ? 0 : Theme.ds(12)
                    color: Theme.cozy ? "transparent"
                         : (tm.containsMouse ? Theme.surfaceHigh : Theme.surface)
                    Behavior on color { ColorAnimation { duration: 150 } }
                    scale: Theme.cozy ? 1.0 : (tm.pressed ? 0.97 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 120 } }
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
                        fillTop: Theme.mix(Theme.surface, Theme.primary, tm.containsMouse ? 0.26 : 0.12)
                        fillBottom: Theme.mix(Theme.surface, Theme.primary, tm.containsMouse ? 0.08 : 0.02)
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.ds(12)
                        anchors.topMargin: Theme.ds(12) + tile.sink
                        anchors.bottomMargin: Theme.ds(12) + Theme.shadowY - tile.sink
                        spacing: Theme.ds(10)
                        Text {
                            text: tile.modelData.icon
                            color: Theme.primary
                            font.pixelSize: Theme.dfs(20)
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

        Rectangle {
            id: advBtn
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.ds(40)
            radius: Theme.cozy ? 0 : Theme.ds(12)
            color: Theme.cozy ? "transparent"
                 : (am.containsMouse ? Theme.primary : Theme.surface)
            Behavior on color { ColorAnimation { duration: 150 } }
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
                    text: "󰒓"
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
