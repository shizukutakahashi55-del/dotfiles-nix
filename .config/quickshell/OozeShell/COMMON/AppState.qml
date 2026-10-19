// AppState.qml — COMMON

pragma Singleton
import QtQuick


QtObject {
    id: root

    // ── Dashboard ────────────────────────────────────────────────


    property bool dashboardOpen: false
    property string dashboardScreen: ""

    property string dashboardSection: "power"

    function openDashboard(section, screen) {
        if (section) root.dashboardSection = section
        if (screen) root.dashboardScreen = screen
        root.dashboardOpen = true
    }
    function closeDashboard() {
        root.dashboardOpen = false
    }


    function toggleDashboard(section, screen) {
        const samePlace = !screen || screen === root.dashboardScreen
        if (root.dashboardOpen && samePlace && (!section || section === root.dashboardSection)) {
            root.closeDashboard()
        } else {
            root.openDashboard(section, screen)
        }
    }

    // ── System Monitor (ventana de aplicación, solo por bind/IPC) ───
    property bool sysMonOpen: false
    property string sysMonScreen: ""
    property string sysMonSection: "overview"

    function openSystemMonitor(section, screen) {
        if (section) root.sysMonSection = section
        if (screen) root.sysMonScreen = screen
        root.sysMonOpen = true
    }
    function closeSystemMonitor() {
        root.sysMonOpen = false
    }
    function toggleSystemMonitor(section, screen) {
        if (root.sysMonOpen) root.closeSystemMonitor()
        else root.openSystemMonitor(section, screen)
    }

    // ── Tray (independiente: no depende de dashboardOpen) ───────────
    property bool trayVisible: true

    // ── Auto-hide de la Píldora (independiente de todo lo anterior) ─
    property bool pillAutoHide: false


    property bool pillHiddenNow: false


    property bool pillTraySync: false

    // ── Gaps de Hyprland (general:gaps_out) ─────────────────────


    property int gapsOut: 6
}
