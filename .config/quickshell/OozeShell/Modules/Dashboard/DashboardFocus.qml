// DashboardFocus.qml — DASHBOARD

import QtQuick
import QtQuick.Layouts
import "../../COMMON"


Item {
    id: root

    readonly property int preferredWidth: Theme.ds(480)
    readonly property int maxWidth: Theme.ds(480)
    readonly property int preferredHeight: Theme.ds(252)
    readonly property int minHeight: Theme.ds(252)

    signal closeRequested()

    // ── Teclado ──
    function handleKey(key, modifiers) {
        if (key === Qt.Key_A || key === Qt.Key_N || key === Qt.Key_Slash) { todo.focusInput(); return true }
        return pomodoro.handleKey(key, modifiers)
    }

    // ── Tarjetas ──
    RowLayout {
        anchors.fill: parent
        anchors.margins: Theme.cozy ? 0 : Theme.ds(10)
        spacing: Theme.cozy ? 0 : Theme.ds(8)

        Rectangle {
            Layout.preferredWidth: Theme.ds(176)
            Layout.fillHeight: true
            radius: Theme.cozy ? 0 : MdTokens.rXl
            color: Theme.cozy ? "transparent" : MdTokens.containerHigh

            DashboardPomodoro {
                id: pomodoro
                anchors.fill: parent
                ringSize: Theme.ds(108)
                ctlSize: Theme.ds(32)
                onCloseRequested: root.closeRequested()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: Theme.ds(270)
            radius: Theme.cozy ? 0 : MdTokens.rXl
            color: Theme.cozy ? "transparent" : MdTokens.container

            DashboardTodo {
                id: todo
                anchors.fill: parent
                onCloseRequested: root.closeRequested()
            }
        }
    }
}
