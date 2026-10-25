// DashboardCalendar.qml — DASHBOARD

import QtQuick
import "../../Services/Agenda"
import "../../COMMON"


Item {
    id: root


    readonly property int preferredWidth: view.implicitWidth
    readonly property int maxWidth: Theme.ds(700)
    readonly property int preferredHeight: view.implicitHeight


    signal closeRequested()

    // ── Teclado ──
    function handleKey(key, modifiers) {
        if (key === Qt.Key_Up || key === Qt.Key_K) { view.monthOffset -= 1; return true }
        if (key === Qt.Key_Down || key === Qt.Key_J) { view.monthOffset += 1; return true }
        if (key === Qt.Key_T || key === Qt.Key_Home || key === Qt.Key_Space) { view.goToday(); return true }
        return false
    }

    AgendaView {
        id: view
        dash: true
        anchors.fill: parent
        onCloseRequested: root.closeRequested()
    }
}
