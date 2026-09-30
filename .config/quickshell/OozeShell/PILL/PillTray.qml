import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../COMMON"
import "../LANG"
import "../TRAY"
import "../BATTERY"
import "../PRIVACY"

// PillTray — pastilla INDEPENDIENTE a la derecha, con la bandeja del
// sistema (TRAY/Tray.qml, sin tocar), la batería y los indicadores de
// privacidad (mic / compartir pantalla, solo visibles mientras se usan). Es su propia ventana y
// su propia geometría: no depende del tamaño de la píldora principal ni
// del dock (especificación: "Tray independiente"), y se abre/cierra
// aunque el dock esté cerrado.
//
// Lo único que comparte con Pill.qml es el auto-hide: `hidden` llega desde
// allá (para que las dos se escondan juntas) y `keepVisible` vuelve para
// que el mouse sobre esta pastilla también cuente como "en uso".
Item {
    id: root

    property var targetScreen
    readonly property string screenName: targetScreen ? targetScreen.name : ""

    // Mismos valores que Pill.qml (borde superior, alto, lo que asoma oculta)
    property int edgeGap: Theme.pillEdgeGap
    property int pillH: Theme.pillHeight
    // Ancho de la pastilla con la escala propia de la píldora
    readonly property real surfaceW: Math.round(content.implicitWidth * Theme.pillScale) + 16
    property int peek: 4
    // Modo sincronizado (AppState.pillTraySync): sigue a la píldora central.
    property bool syncedHidden: false
    readonly property bool sync: AppState.pillTraySync
    // Modo independiente: esta pastilla decide sola cuándo esconderse.
    property bool hiddenOwn: false
    readonly property bool hidden: root.sync ? root.syncedHidden : root.hiddenOwn
    property bool popupOpen: false

    // shell.qml cierra los demás popups (igual que RightModules)
    signal trayMenuOpened()

    readonly property bool showTray: AppState.trayVisible && tray.count > 0
    readonly property bool showBattery: Theme.batteryEnabled && BatteryBackend.available
    // Privacy: solo existe mientras algo usa el mic o comparte pantalla
    readonly property bool showPrivacy: privacy.present
    readonly property bool hasContent: root.showTray || root.showBattery || root.showPrivacy

    // "En uso" (mouse encima o menú abierto). En modo sincronizado se lo
    // reporta a Pill.qml; en independiente lo usa esta misma pastilla.
    readonly property bool keepVisible:
        surfaceHover.containsMouse || triggerMouse.containsMouse || root.trayMenuOpen

    readonly property bool ownKeep: !AppState.pillAutoHide || root.keepVisible
    onOwnKeepChanged: {
        if (root.ownKeep) { ownHideTimer.stop(); root.hiddenOwn = false }
        else ownHideTimer.restart()
    }
    Component.onCompleted: {
        if (!root.ownKeep) ownHideTimer.restart()
        root.reportIsland()
    }
    Component.onDestruction: IslandState.clear(root.screenName, "right")

    // ── Isla para el menú de la bandeja ──────────────────────────────
    // El TrayMenu (FusedPanel) nace de esta pastilla, no de la central.
    readonly property var islandRect: ({
        x: win.width - root.surfaceW - root.edgeGap,
        y: Theme.barAtBottom ? win.height - root.pillH - root.edgeGap : root.edgeGap,
        w: root.surfaceW, h: root.pillH, r: 16
    })
    function reportIsland() {
        if (root.screenName === "" || win.width <= 0 || win.height <= 0 || !root.hasContent) {
            IslandState.clear(root.screenName, "right")
            return
        }
        IslandState.report(root.screenName, "right", root.islandRect)
    }
    onIslandRectChanged: root.reportIsland()
    onHasContentChanged: root.reportIsland()
    Timer {
        id: ownHideTimer
        interval: 1500
        onTriggered: { if (!root.ownKeep) root.hiddenOwn = true }
    }

    // ── Menú de la bandeja (TRAY/TrayMenu.qml, sin tocar) ───────────
    property bool trayMenuOpen: false
    function closeTrayMenu() { root.trayMenuOpen = false }
    function openTrayMenu(iconItem, entry) {
        if (root.trayMenuOpen && trayMenu.trayItem === entry) { root.closeTrayMenu(); return }
        root.hideTip()
        root.trayMenuOpened()
        trayMenu.trayItem = entry
        const c = iconItem.mapToItem(null, iconItem.width / 2, iconItem.height / 2)
        trayMenu.anchorX = c.x
        trayMenu.anchorY = c.y
        root.trayMenuOpen = true
    }
    onPopupOpenChanged: { if (root.popupOpen) { root.closeTrayMenu(); root.hideTip() } }
    onHiddenChanged: { if (root.hidden) { root.closeTrayMenu(); root.hideTip() } }

    TrayMenu {
        id: trayMenu
        open: root.trayMenuOpen
        targetScreen: root.screenName
        onCloseRequested: root.closeTrayMenu()
    }

    // ── Tooltip sencillo (debajo de la pastilla) ────────────────────
    property var tipTarget: null
    property string tipText: ""
    property bool tipShown: false
    function tipEnter(item) {
        tipHide.stop()
        tipTarget = item
        tipText = String(item.tip ?? "")
        if (!tipShown) tipShow.restart()
    }
    function tipLeave(item) {
        if (tipTarget !== item) return
        tipShow.stop()
        tipHide.restart()
    }
    function hideTip() { tipShow.stop(); tipHide.stop(); tipShown = false }
    Timer { id: tipShow; interval: 500; onTriggered: root.tipShown = true }
    Timer { id: tipHide; interval: 150; onTriggered: root.tipShown = false }

    readonly property string batteryTip: {
        if (!BatteryBackend.available) return ""
        const pct = Math.round(BatteryBackend.percentage * 100) + "%"
        const state = BatteryBackend.fullyCharged ? Translations.t("batteryFull")
                    : BatteryBackend.charging     ? Translations.t("batteryCharging")
                                                   : Translations.t("batteryDischarging")
        const secs = BatteryBackend.charging ? BatteryBackend.timeToFull : BatteryBackend.timeToEmpty
        const time = BatteryBackend.formatSecs(secs)
        const label = BatteryBackend.charging ? Translations.t("batteryTimeToFull")
                                               : Translations.t("batteryTimeToEmpty")
        return pct + " — " + state + (time !== "" ? ("\n" + label + " " + time) : "")
    }

    PanelWindow {
        id: win

        screen: root.targetScreen
        anchors { top: true; left: true; right: true; bottom: true }
        color: "transparent"
        visible: root.hasContent && !Theme.barRebuilding

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "oozeshell-pill-tray"
        exclusiveZone: -1

        mask: Region {
            item: surface
            Region { item: trigger }
        }

        // Franja de reveal (cuando está oculta), pegada al borde derecho
        Item {
            id: trigger
            width: 120
            height: root.hidden ? 6 : 0
            x: parent.width - width - root.edgeGap
            y: Theme.barAtBottom ? parent.height - height : 0
            MouseArea {
                id: triggerMouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
            }
        }

        Item {
            id: surface

            width: root.surfaceW
            height: root.pillH

            readonly property real hideOffset: root.hidden ? (height + root.edgeGap - root.peek) : 0
            x: parent.width - width - root.edgeGap
            y: Theme.barAtBottom
                ? parent.height - height - root.edgeGap + hideOffset
                : root.edgeGap - hideOffset

            Behavior on width { NumberAnimation { duration: Theme.animDuration(200); easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: Theme.animDuration(260); easing.type: Easing.OutCubic } }

            SkinRect {
                anchors.fill: parent
                radius: Theme.cozy ? 4 : 16
                color: Theme.bg
                inkColor: Theme.ink
                raised: Theme.cozy
                depth: 2
            }

            MouseArea {
                id: surfaceHover
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
            }

            RowLayout {
                id: content
                anchors.centerIn: parent
                spacing: 4
                scale: Theme.pillScale
                transformOrigin: Item.Center

                // Privacy: mic / pantalla (rojo, aparece y desaparece solo)
                Privacy {
                    id: privacy
                    visible: privacy.present
                    onTipEnter: item => root.tipEnter(item)
                    onTipLeave: item => root.tipLeave(item)
                }

                Rectangle {
                    visible: root.showPrivacy && (root.showTray || root.showBattery)
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 16
                    Layout.alignment: Qt.AlignCenter
                    radius: 1
                    color: Theme.primary
                    opacity: 0.25
                }

                Tray {
                    id: tray
                    visible: AppState.trayVisible && tray.count > 0
                    iconSize: 18
                    activeItem: root.trayMenuOpen ? trayMenu.trayItem : null
                    onTipEnter: item => root.tipEnter(item)
                    onTipLeave: item => root.tipLeave(item)
                    onMenuRequested: (iconItem, entry) => root.openTrayMenu(iconItem, entry)
                }

                Rectangle {
                    visible: root.showTray && root.showBattery
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 16
                    Layout.alignment: Qt.AlignCenter
                    radius: 1
                    color: Theme.primary
                    opacity: 0.25
                }

                SkinRect {
                    id: batteryBtn
                    visible: root.showBattery
                    readonly property string tip: root.batteryTip

                    Layout.preferredHeight: 28
                    Layout.preferredWidth: batteryRow.implicitWidth + 16
                    radius: 10
                    color: bm.containsMouse ? Theme.surface : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }

                    RowLayout {
                        id: batteryRow
                        anchors.centerIn: parent
                        spacing: 5
                        Text {
                            text: BatteryBackend.icon
                            color: BatteryBackend.isLow ? Theme.error : Theme.text
                            font.family: Theme.monoFamily
                            font.pixelSize: Theme.fs(16)
                            Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
                        }
                        Text {
                            text: Math.round(BatteryBackend.percentage * 100) + "%"
                            color: BatteryBackend.isLow ? Theme.error : Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fs(12)
                        }
                    }
                    MouseArea {
                        id: bm
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: root.tipEnter(batteryBtn)
                        onExited: root.tipLeave(batteryBtn)
                    }
                }
            }
        }

        // Tooltip: debajo (o encima, con la barra abajo) de la pastilla
        Rectangle {
            id: tipBox
            visible: opacity > 0.01
            opacity: (root.tipShown && !root.trayMenuOpen && !root.popupOpen && !root.hidden
                      && root.tipTarget !== null && root.tipText !== "") ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.animDuration(120) } }

            width: tipLabel.implicitWidth + 20
            height: tipLabel.implicitHeight + 14
            radius: 10
            color: Theme.bg
            border.width: Theme.bw1
            border.color: Theme.edge

            x: Math.max(6, Math.min(parent.width - width - 6,
                root.tipTarget ? root.tipTarget.mapToItem(null, root.tipTarget.width / 2, 0).x - width / 2
                               : 0))
            y: Theme.barAtBottom ? surface.y - height - 6 : surface.y + surface.height + 6

            Text {
                id: tipLabel
                anchors.centerIn: parent
                text: root.tipText
                color: Theme.text
                font.pixelSize: Theme.fs(11)
                font.family: Theme.fontFamily
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
