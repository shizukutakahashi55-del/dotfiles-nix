// DashboardNotifications.qml — DASHBOARD

import QtQuick
import "../../COMMON"
import "../../Services/Notify"


Item {
    id: root

    readonly property int preferredWidth: Math.max(Theme.ds(400), 400)
    readonly property int maxWidth: Math.max(Theme.ds(500), 480)
    readonly property int preferredHeight: list.implicitHeight

    signal closeRequested()

    // ── Teclado ──
    function handleKey(key, modifiers) {
        if (key === Qt.Key_C || key === Qt.Key_Delete || key === Qt.Key_Backspace) {
            NotificationsBackend.clearAll(); return true
        }
        if (key === Qt.Key_D) { NotificationsBackend.toggleDnd(); return true }
        return false
    }

    NotifList {
        id: list
        x: 0
        y: 0
        width: parent.width
        maxListHeight: Theme.ds(290)
        listActive: true
        entriesAnimated: true
        onCloseRequested: root.closeRequested()
    }
}
