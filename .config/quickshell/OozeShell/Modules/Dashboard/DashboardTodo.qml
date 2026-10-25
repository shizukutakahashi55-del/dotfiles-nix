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
    readonly property int rowH: Theme.ds(40)
    readonly property int inputH: Theme.ds(40)

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

        // ── Encabezado ──
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.ds(10)

            Item {
                Layout.preferredWidth: Theme.ds(34)
                Layout.preferredHeight: Theme.ds(34)

                MdShape {
                    anchors.fill: parent
                    shape: "cookie7"
                    color: Qt.alpha(Theme.primary, 0.20)
                }
                Text {
                    anchors.centerIn: parent
                    text: OozeIcons.confirm
                    color: Theme.primary
                    font.pixelSize: Theme.dfs(15)
                    font.family: Theme.monoFamily
                }
            }
            Text {
                Layout.fillWidth: true
                text: Translations.t("agendaToday")
                color: Theme.text
                font.bold: true
                font.pixelSize: Theme.dfs(15)
                font.family: Theme.fontFamily
                elide: Text.ElideRight
            }
            Rectangle {
                readonly property int n: TodoBackend.pendingFor(root.todayKey)
                visible: n > 0
                implicitHeight: Theme.ds(24)
                implicitWidth: pendingText.implicitWidth + Theme.ds(18)
                radius: Theme.cozy ? 3 : height / 2
                color: Qt.alpha(Theme.primary, 0.18)

                Text {
                    id: pendingText
                    anchors.centerIn: parent
                    text: parent.n + " " + Translations.t("agendaPending")
                    color: Theme.primary
                    font.bold: true
                    font.pixelSize: Theme.dfs(10)
                    font.family: Theme.fontFamily
                }
            }
        }

        // ── Lista ──
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
                spacing: MdTokens.listGap
                boundsBehavior: Flickable.StopAtBounds
                model: root.tasks

                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool isFirst: row.index === 0
                    readonly property bool isLast: row.index === (row.ListView.view.count - 1)

                    width: ListView.view.width
                    height: root.rowH
                    topLeftRadius: row.isFirst ? MdTokens.rL : MdTokens.innerRadius
                    topRightRadius: row.isFirst ? MdTokens.rL : MdTokens.innerRadius
                    bottomLeftRadius: row.isLast ? MdTokens.rL : MdTokens.innerRadius
                    bottomRightRadius: row.isLast ? MdTokens.rL : MdTokens.innerRadius
                    color: row.modelData.done ? MdTokens.container : MdTokens.containerHigh
                    border.width: Theme.cozy ? 2 : 0
                    border.color: Theme.ink
                    Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }

                    HoverHandler { id: rowHover }

                    Rectangle {
                        anchors.fill: parent
                        topLeftRadius: parent.topLeftRadius
                        topRightRadius: parent.topRightRadius
                        bottomLeftRadius: parent.bottomLeftRadius
                        bottomRightRadius: parent.bottomRightRadius
                        color: MdTokens.stateLayer(Theme.text, rowHover.hovered, false)
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: TodoBackend.toggle(row.modelData.id)
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.ds(12)
                        anchors.rightMargin: Theme.ds(8)
                        spacing: Theme.ds(10)

                        Rectangle {
                            Layout.preferredWidth: Theme.ds(20)
                            Layout.preferredHeight: Theme.ds(20)
                            radius: Theme.cozy ? 2 : Theme.ds(row.modelData.done ? 10 : 6)
                            color: row.modelData.done ? Theme.primary : "transparent"
                            border.width: row.modelData.done ? 0 : 2
                            border.color: Theme.subtext
                            Behavior on radius { NumberAnimation { duration: Theme.animDuration(180); easing.type: Easing.OutBack } }
                            Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }

                            Text {
                                anchors.centerIn: parent
                                visible: row.modelData.done
                                text: "󰄬"
                                color: Theme.textOnPrimary
                                font.pixelSize: Theme.dfs(13)
                                font.family: Theme.monoFamily
                            }
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
                            Layout.preferredHeight: Theme.ds(24)
                            Layout.preferredWidth: timeRow.implicitWidth + Theme.ds(14)
                            radius: Theme.cozy ? 3 : height / 2
                            color: timeMouse.containsMouse
                                ? Theme.error
                                : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, row.modelData.done ? 0.08 : 0.18)
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
                        MdIconButton {
                            Layout.alignment: Qt.AlignVCenter
                            size: Theme.ds(28)
                            variant: "standard"
                            accent: Theme.error
                            onAccent: Theme.textOnError
                            glyph: "󰆴"
                            glyphSize: Theme.dfs(13)
                            opacity: rowHover.hovered ? 1 : 0.45
                            Behavior on opacity { NumberAnimation { duration: Theme.animDuration(120) } }
                            onClicked: TodoBackend.remove(row.modelData.id)
                        }
                    }
                }
            }
        }

        // ── Limpiar hechas ──
        Rectangle {
            visible: TodoBackend.doneFor(root.todayKey) > 0
            Layout.alignment: Qt.AlignHCenter
            implicitHeight: Theme.ds(26)
            implicitWidth: clearText.implicitWidth + Theme.ds(24)
            radius: Theme.cozy ? 3 : height / 2
            color: clearMouse.containsMouse ? Qt.alpha(Theme.primary, 0.18) : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }

            Text {
                id: clearText
                anchors.centerIn: parent
                text: Translations.t("agendaClearDone")
                color: clearMouse.containsMouse ? Theme.primary : Theme.subtext
                font.pixelSize: Theme.dfs(11)
                font.family: Theme.fontFamily
            }
            MouseArea {
                id: clearMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: TodoBackend.clearDone(root.todayKey)
            }
        }

        // ── Entrada ──
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.ds(6)

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: root.inputH
                radius: Theme.cozy ? 4 : height / 2
                color: MdTokens.control
                border.width: input.activeFocus ? 2 : (Theme.cozy ? 0 : 1)
                border.color: input.activeFocus ? Theme.primary : MdTokens.edgeSoft

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.IBeamCursor
                    onClicked: input.forceActiveFocus()
                }

                TextInput {
                    id: input
                    anchors { fill: parent; leftMargin: Theme.ds(16); rightMargin: Theme.ds(16) }
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
                Layout.preferredWidth: Theme.ds(80)
                Layout.preferredHeight: root.inputH
                radius: Theme.cozy ? 4 : height / 2
                color: MdTokens.control
                opacity: TodoBackend.alarmsEnabled ? 1 : 0.55
                border.width: (bad || timeInput.activeFocus) ? 2 : (Theme.cozy ? 0 : 1)
                border.color: bad ? Theme.error : (timeInput.activeFocus ? Theme.primary : MdTokens.edgeSoft)

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.IBeamCursor
                    onClicked: timeInput.forceActiveFocus()
                }

                TextInput {
                    id: timeInput
                    anchors { fill: parent; leftMargin: Theme.ds(12); rightMargin: Theme.ds(12) }
                    verticalAlignment: TextInput.AlignVCenter
                    horizontalAlignment: TextInput.AlignHCenter
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
                        horizontalAlignment: Text.AlignHCenter
                        visible: timeInput.text === ""
                        text: "hh:mm"
                        color: Theme.subtext
                        font: timeInput.font
                    }
                }
            }

            MdIconButton {
                Layout.alignment: Qt.AlignVCenter
                size: root.inputH
                variant: "filled"
                checkable: true
                toggled: input.text.trim() !== ""
                glyph: "󰐕"
                opacity: input.text.trim() !== "" ? 1 : 0.55
                onClicked: root.submit()
            }
        }
    }
}
