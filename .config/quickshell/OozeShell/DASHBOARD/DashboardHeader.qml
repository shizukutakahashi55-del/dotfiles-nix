// DashboardHeader.qml — DASHBOARD

import QtQuick
import QtQuick.Layouts
import "../COMMON"
import "../LANG"


Item {
    id: root

    property string section: "power"
    signal sectionSelected(string section)

    signal sectionHover(string section)
    signal actionTriggered(string id)


    readonly property var items: [
        { id: "power",       icon: OozeIcons.power,       labelKey: "dashboardSectionPower",    action: false },
        { id: "mpris",       icon: OozeIcons.music,       labelKey: "dashboardSectionMpris",    action: false },
        { id: "performance", icon: OozeIcons.performance, labelKey: "dashboardSectionPerf",     action: false },
        { id: "audio",       icon: OozeIcons.volume,      labelKey: "dashboardSectionAudio",    action: false },
        { id: "calendar",    icon: OozeIcons.calendar,    labelKey: "dashboardSectionCalendar", action: false },
        { id: "quickaccess", icon: OozeIcons.settings,    labelKey: "dashboardSectionSettings", action: false },
        { id: "overview",    icon: OozeIcons.overview,    labelKey: "dashboardSectionOverview", action: WM.hasNativeOverview }
    ]

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: Theme.cozy ? 2 : 1
        color: Theme.cozy ? Theme.ink : Theme.divider
    }

    // ── Medidas ─────────────────────────────────────────────────


    readonly property int itemMinW: Theme.ds(58)
    readonly property int itemH: Theme.ds(48)
    readonly property int gap: Theme.ds(6)
    readonly property int padX: Theme.ds(12)
    readonly property int sideMargin: Theme.ds(14)
    readonly property font labelFont: Qt.font({
        family: Theme.fontFamily, pixelSize: Theme.dfs(Theme.cozy ? 9 : 10)
    })


    FontMetrics { id: fm; font: root.labelFont }


    readonly property var widths: root.items.map(it =>
        Math.max(root.itemMinW,
                 Math.ceil(fm.advanceWidth(Translations.t(it.labelKey))) + root.padX * 2))

    readonly property int requiredWidth:
        root.widths.reduce((a, b) => a + b, 0)
        + (root.items.length - 1) * root.gap + root.sideMargin * 2


    readonly property int activeIndex: {
        for (let i = 0; i < root.items.length; i++)
            if (!root.items[i].action && root.items[i].id === root.section) return i
        return -1
    }


    Item {
        id: rowBox
        anchors.centerIn: parent
        width: root.requiredWidth - root.sideMargin * 2
        height: root.itemH


        SkinRect {
            id: slider
            readonly property int idx: root.activeIndex
            visible: idx >= 0
            height: root.itemH
            radius: Theme.ds(12)
            raised: true
            depth: Theme.cozy ? 3 : 2
            inkColor: Theme.ink
            color: Theme.primary


            property real sx: {
                let acc = 0
                for (let i = 0; i < slider.idx; i++) acc += root.widths[i] + root.gap
                return acc
            }
            property real sw: slider.idx >= 0 ? root.widths[slider.idx] : root.itemMinW
            x: Math.round(slider.sx)
            width: Math.round(slider.sw)
            Behavior on sx {
                NumberAnimation {
                    duration: Theme.animDuration(Theme.cozy ? 240 : 280)
                    easing.type: Easing.OutBack
                    easing.overshoot: Theme.cozy ? 0.45 : 0.8
                }
            }
            Behavior on sw { NumberAnimation { duration: Theme.animDuration(240); easing.type: Easing.OutCubic } }
        }

        RowLayout {
            anchors.fill: parent
            spacing: root.gap

            Repeater {
                model: root.items

                delegate: SkinRect {
                    id: btn
                    required property var modelData
                    required property int index
                    readonly property bool activeSection: !modelData.action && root.section === modelData.id

                    Layout.preferredWidth: root.widths[btn.index]
                    Layout.preferredHeight: root.itemH
                    radius: Theme.ds(12)


                    color: (!btn.activeSection && hm.containsMouse) ? Theme.surface : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }


                    scale: Theme.cozy ? 1.0 : (hm.pressed ? 0.90 : hm.containsMouse ? 1.05 : 1.0)
                    Behavior on scale { NumberAnimation { duration: Theme.animDuration(150); easing.type: Easing.OutBack } }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: Theme.ds(2)

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: btn.modelData.icon
                            color: btn.activeSection ? Theme.textOnPrimary : Theme.text
                            font.pixelSize: Theme.dfs(16)
                            font.family: Theme.monoFamily
                            Behavior on color { ColorAnimation { duration: Theme.animDuration(200) } }
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: Translations.t(btn.modelData.labelKey)
                            color: btn.activeSection ? Theme.textOnPrimary : Theme.subtext
                            font: root.labelFont
                            Behavior on color { ColorAnimation { duration: Theme.animDuration(200) } }
                        }
                    }

                    Timer {
                        id: dwell
                        interval: 100
                        onTriggered: root.sectionHover(btn.modelData.id)
                    }

                    MouseArea {
                        id: hm
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: if (!btn.modelData.action && !btn.activeSection) dwell.restart()
                        onExited: dwell.stop()
                        onClicked: {
                            if (btn.modelData.action) root.actionTriggered(btn.modelData.id)
                            else root.sectionSelected(btn.modelData.id)
                        }
                    }
                }
            }
        }
    }
}
