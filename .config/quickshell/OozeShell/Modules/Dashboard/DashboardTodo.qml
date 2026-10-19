// DashboardTodo.qml — DASHBOARD

import QtQuick
import QtQuick.Layouts
import "../../COMMON"
import "../../Services/Agenda"
import "../../Services/Lang"


Item {
    id: root

    readonly property string todayKey: TodoBackend.dateKey(new Date())
    readonly property var tasks: TodoBackend.tasksFor(root.todayKey)

    readonly property int pad: Theme.ds(14)
    readonly property int rowH: Theme.ds(36)
    readonly property int inputH: Theme.ds(38)

    readonly property int preferredWidth: Theme.ds(400)
    readonly property int maxWidth: Theme.ds(460)
    readonly property int preferredHeight: Theme.ds(330)

    signal closeRequested()

    // ── Teclado ──
    function focusInput() { input.forceActiveFocus() }

    function submit() {
        if (input.text.trim() === "") return
        const tm = TodoBackend.normTime(timeInput.text)
        if (timeInput.text.trim() !== "" && tm === "") { timeInput.forceActiveFocus(); return }
        TodoBackend.add(input.text, root.todayKey, tm)
        input.text = ""
        timeInput.text = ""
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.pad
        spacing: Theme.ds(8)

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.ds(8)

            Text {
                text: OozeIcons.confirm
                color: Theme.primary
                font.pixelSize: Theme.dfs(16)
                font.family: Theme.monoFamily
            }
            Text {
                Layout.fillWidth: true
                text: Translations.t("agendaToday")
                color: Theme.text
                font.bold: true
                font.pixelSize: Theme.dfs(13)
                font.family: Theme.fontFamily
                elide: Text.ElideRight
            }
            Text {
                readonly property int n: TodoBackend.pendingFor(root.todayKey)
                visible: n > 0
                text: n + " " + Translations.t("agendaPending")
                color: Theme.primary
                font.pixelSize: Theme.dfs(10)
                font.family: Theme.fontFamily
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: Theme.ds(120)

            Text {
                anchors.centerIn: parent
                visible: root.tasks.length === 0
                text: Translations.t("agendaNoTasks")
                color: Theme.subtext
                font.pixelSize: Theme.dfs(12)
                font.family: Theme.fontFamily
            }

            ListView {
                id: list
                anchors.fill: parent
                clip: true
                spacing: Theme.ds(3)
                boundsBehavior: Flickable.StopAtBounds
                model: root.tasks

                delegate: Rectangle {
                    id: row
                    required property var modelData
                    width: ListView.view.width
                    height: root.rowH
                    radius: Theme.ds(10)
                    color: rowHover.hovered ? Theme.surfaceHigh : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }

                    HoverHandler { id: rowHover }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: TodoBackend.toggle(row.modelData.id)
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.ds(8)
                        anchors.rightMargin: Theme.ds(6)
                        spacing: Theme.ds(8)

                        Text {
                            text: row.modelData.done ? "󰄳" : "󰄰"
                            color: row.modelData.done ? Theme.primary : Theme.subtext
                            font.pixelSize: Theme.dfs(16)
                            font.family: Theme.monoFamily
                        }
                        Text {
                            Layout.fillWidth: true
                            text: row.modelData.text
                            color: row.modelData.done ? Theme.subtext : Theme.text
                            font.pixelSize: Theme.dfs(12)
                            font.strikeout: row.modelData.done
                            font.family: Theme.fontFamily
                            elide: Text.ElideRight
                        }
                        Rectangle {
                            visible: row.modelData.time !== ""
                            Layout.preferredHeight: Theme.ds(22)
                            Layout.preferredWidth: timeRow.implicitWidth + Theme.ds(12)
                            radius: Theme.ds(8)
                            color: timeMouse.containsMouse
                                ? Theme.error
                                : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, row.modelData.done ? 0.08 : 0.16)
                            Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }

                            Row {
                                id: timeRow
                                anchors.centerIn: parent
                                spacing: Theme.ds(4)
                                Text {
                                    text: timeMouse.containsMouse ? "󰂛" : "󰂞"
                                    color: timeMouse.containsMouse ? Theme.textOnPrimary
                                         : (row.modelData.done ? Theme.subtext : Theme.primary)
                                    font.pixelSize: Theme.dfs(11)
                                    font.family: Theme.monoFamily
                                }
                                Text {
                                    text: row.modelData.time
                                    color: timeMouse.containsMouse ? Theme.textOnPrimary
                                         : (row.modelData.done ? Theme.subtext : Theme.primary)
                                    font.pixelSize: Theme.dfs(11)
                                    font.bold: true
                                    font.family: Theme.fontFamily
                                }
                            }
                            MouseArea {
                                id: timeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: TodoBackend.clearTime(row.modelData.id)
                            }
                        }
                        Rectangle {
                            Layout.preferredWidth: Theme.ds(26)
                            Layout.preferredHeight: Theme.ds(26)
                            radius: Theme.ds(8)
                            opacity: (rowHover.hovered || delMouse.containsMouse) ? 1 : 0.4
                            Behavior on opacity { NumberAnimation { duration: Theme.animDuration(120) } }
                            color: delMouse.containsMouse ? Theme.error : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "󰆴"
                                color: delMouse.containsMouse ? Theme.textOnPrimary : Theme.subtext
                                font.pixelSize: Theme.dfs(13)
                                font.family: Theme.monoFamily
                            }
                            MouseArea {
                                id: delMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: TodoBackend.remove(row.modelData.id)
                            }
                        }
                    }
                }
            }
        }

        Text {
            visible: TodoBackend.doneFor(root.todayKey) > 0
            Layout.alignment: Qt.AlignHCenter
            text: Translations.t("agendaClearDone")
            color: clearMouse.containsMouse ? Theme.primary : Theme.subtext
            font.pixelSize: Theme.dfs(11)
            font.family: Theme.fontFamily

            MouseArea {
                id: clearMouse
                anchors.fill: parent
                anchors.margins: -Theme.ds(4)
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: TodoBackend.clearDone(root.todayKey)
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.ds(6)

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: root.inputH
                radius: Theme.ds(12)
                color: Theme.surfaceHigh
                border.width: input.activeFocus ? 1.5 : 0
                border.color: Theme.primary

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.IBeamCursor
                    onClicked: input.forceActiveFocus()
                }

                TextInput {
                    id: input
                    anchors { fill: parent; leftMargin: Theme.ds(12); rightMargin: Theme.ds(12) }
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.text
                    selectionColor: Theme.primary
                    selectedTextColor: Theme.textOnPrimary
                    font.pixelSize: Theme.dfs(12)
                    font.family: Theme.fontFamily
                    clip: true
                    selectByMouse: true
                    onAccepted: root.submit()

                    Keys.onEscapePressed: event => {
                        if (input.text !== "") input.text = ""
                        else { input.focus = false; root.closeRequested() }
                        event.accepted = true
                    }

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        visible: input.text === ""
                        text: Translations.t("agendaNewTask")
                        color: Theme.subtext
                        font: input.font
                        elide: Text.ElideRight
                    }
                }
            }

            Rectangle {
                readonly property bool bad: timeInput.text.trim() !== "" && TodoBackend.normTime(timeInput.text) === ""
                Layout.preferredWidth: Theme.ds(84)
                Layout.preferredHeight: root.inputH
                radius: Theme.ds(12)
                color: Theme.surfaceHigh
                opacity: TodoBackend.alarmsEnabled ? 1 : 0.55
                border.width: (bad || timeInput.activeFocus) ? 1.5 : 0
                border.color: bad ? Theme.error : Theme.primary

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.IBeamCursor
                    onClicked: timeInput.forceActiveFocus()
                }

                TextInput {
                    id: timeInput
                    anchors { fill: parent; leftMargin: Theme.ds(10); rightMargin: Theme.ds(10) }
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.text
                    selectionColor: Theme.primary
                    selectedTextColor: Theme.textOnPrimary
                    font.pixelSize: Theme.dfs(12)
                    font.family: Theme.monoFamily
                    maximumLength: 5
                    clip: true
                    selectByMouse: true
                    validator: RegularExpressionValidator { regularExpression: /^[0-9:]{0,5}$/ }
                    onAccepted: root.submit()

                    Keys.onEscapePressed: event => {
                        if (timeInput.text !== "") timeInput.text = ""
                        else { timeInput.focus = false; root.closeRequested() }
                        event.accepted = true
                    }

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        visible: timeInput.text === ""
                        text: "hh:mm"
                        color: Theme.subtext
                        font: timeInput.font
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: root.inputH
                Layout.preferredHeight: root.inputH
                radius: Theme.ds(12)
                color: addMouse.containsMouse ? Qt.lighter(Theme.primary, 1.12) : Theme.primary
                opacity: input.text.trim() !== "" ? 1 : 0.5
                Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }
                scale: addMouse.pressed ? 0.95 : 1.0
                Behavior on scale { NumberAnimation { duration: Theme.animDuration(120); easing.type: Easing.OutBack } }

                Text {
                    anchors.centerIn: parent
                    text: "󰐕"
                    color: Theme.textOnPrimary
                    font.pixelSize: Theme.dfs(15)
                    font.family: Theme.monoFamily
                }
                MouseArea {
                    id: addMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.submit()
                }
            }
        }
    }
}
