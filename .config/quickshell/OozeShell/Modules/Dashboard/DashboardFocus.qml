// DashboardFocus.qml — DASHBOARD

import QtQuick
import QtQuick.Layouts
import "../../COMMON"


Item {
    id: root

    readonly property int preferredWidth: Theme.ds(460)
    readonly property int maxWidth: Theme.ds(460)
    readonly property int preferredHeight: Theme.ds(330)

    signal closeRequested()

    // ── Teclado ──
    function handleKey(key, modifiers) {
        if (key === Qt.Key_A || key === Qt.Key_N || key === Qt.Key_Slash) { todo.focusInput(); return true }
        return pomodoro.handleKey(key, modifiers)
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        DashboardPomodoro {
            id: pomodoro
            Layout.preferredWidth: Theme.ds(168)
            Layout.fillHeight: true
            ringSize: Theme.ds(128)
            ctlSize: Theme.ds(36)
            onCloseRequested: root.closeRequested()
        }

        DashboardTodo {
            id: todo
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: Theme.ds(290)
            onCloseRequested: root.closeRequested()
        }
    }
}
