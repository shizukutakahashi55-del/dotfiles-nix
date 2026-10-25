// DashboardPanel.qml — DASHBOARD

import QtQuick
import "../../COMMON"
import "../../Services/Notify"


Item {
    id: root

    property bool open: false
    property string targetScreen: ""
    property int edgeMargin: 10
    property bool warm: false

    readonly property bool notifsShown: root.open && AppState.dashboardSection === "notifs"
    onNotifsShownChanged: NotificationsBackend.centerOpen = root.notifsShown
    Component.onDestruction: NotificationsBackend.centerOpen = false

    // ── Liberar memoria al cerrar ──

    Timer { id: trimTimer; interval: 3000; onTriggered: Theme.trimMemory() }
    onOpenChanged: { if (!root.open) trimTimer.restart(); else trimTimer.stop() }

    signal requestNetwork()
    signal requestBluetooth()
    signal requestAppearance()
    signal requestWalls()
    signal requestAdvancedSettings()

    FusedWindow {
        id: fw
        active: root.open || panel.shown
        targetScreen: root.targetScreen
        namespace: "oozeshell-dashboard"
        onCloseRequested: AppState.closeDashboard()
        onKeyPressed: (key, modifiers, text) => dashboard.handleKey(key, modifiers)

        FusedPanel {
            id: panel

            open: root.open
            panelWidth: dashboard.smoothWidth
            contentHeight: dashboard.smoothHeight

            moduleId: "menu"

            align: Theme.popupAlign("menu", "end")
            alignMargin: root.edgeMargin + Theme.barEdge + Theme.frameSideArm

            Dashboard {
                id: dashboard

                x: 0
                y: 0
                width: Math.round(panel.panelWidth)
                height: Math.round(panel.contentHeight)

                // Altura única para todas las pestañas, limitada por la pantalla
                // (mismo criterio que Keybinds: medidas lógicas / windowScale).
                fixedStage: true
                availableH: (fw.screenHeight
                    - (Theme.barVertical
                        ? 2 * (root.edgeMargin + Theme.barEdge + Theme.frameSideArm)
                        : Theme.barFace + 16)) / Theme.windowScale

                screenName: root.targetScreen
                open: root.open
                keepLoaded: root.open || panel.shown
                warm: root.warm

                onRequestNetwork: root.requestNetwork()
                onRequestBluetooth: root.requestBluetooth()
                onRequestAppearance: root.requestAppearance()
                onRequestWalls: root.requestWalls()
                onRequestAdvancedSettings: root.requestAdvancedSettings()
            }
        }
    }
}
