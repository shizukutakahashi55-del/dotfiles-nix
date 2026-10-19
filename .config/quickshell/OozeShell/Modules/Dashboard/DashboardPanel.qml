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
            contentHeight: dashboard.fullHeight

            moduleId: "menu"

            align: Theme.popupAlign("menu", "end")
            alignMargin: root.edgeMargin + Theme.barEdge + Theme.frameSideArm

            Dashboard {
                id: dashboard

                x: 0
                y: 0
                width: Math.round(panel.panelWidth)
                height: Math.round(panel.contentHeight)

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
