// DashboardCalendar.qml — DASHBOARD

import QtQuick
import "../AGENDA"
import "../COMMON"


Item {
    id: root


    readonly property int preferredWidth: view.implicitWidth
    readonly property int maxWidth: Theme.ds(700)
    readonly property int preferredHeight: view.implicitHeight


    signal closeRequested()

    AgendaView {
        id: view
        dash: true
        anchors.fill: parent
        onCloseRequested: root.closeRequested()
    }
}
