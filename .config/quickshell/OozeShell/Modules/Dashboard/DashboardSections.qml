// DashboardSections.qml — DASHBOARD

import QtQuick
import "../../COMMON"


QtObject {
    readonly property var all: [
        { id: "power",       icon: OozeIcons.power,       labelKey: "dashboardSectionPower",    action: false },
        { id: "mpris",       icon: OozeIcons.music,       labelKey: "dashboardSectionMpris",    action: false },
        { id: "performance", icon: OozeIcons.performance, labelKey: "dashboardSectionPerf",     action: false },
        { id: "audio",       icon: OozeIcons.volume,      labelKey: "dashboardSectionAudio",    action: false },
        { id: "notifs",      icon: OozeIcons.bell,        labelKey: "dashboardSectionNotifs",   action: false },
        { id: "focus",       icon: OozeIcons.pomodoro,    labelKey: "dashboardSectionFocus",    action: false },
        { id: "calendar",    icon: OozeIcons.calendar,    labelKey: "dashboardSectionCalendar", action: false },
        { id: "quickaccess", icon: OozeIcons.settings,    labelKey: "dashboardSectionSettings", action: false }
    ]

    readonly property var barExcluded: ["power", "mpris"]
    readonly property var pillExcluded: ["notifs"]

    readonly property var forBar: all.filter(it => barExcluded.indexOf(it.id) < 0)
    readonly property var forPill: all.filter(it => pillExcluded.indexOf(it.id) < 0)
}
