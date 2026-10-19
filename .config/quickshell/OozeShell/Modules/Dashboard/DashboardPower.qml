// DashboardPower.qml — DASHBOARD

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../../COMMON"
import "../../Services/Lang"
import "../Power"
import "../../Services/Battery"


Item {
    id: root


    readonly property var hiddenIds: []
    readonly property var visibleActions:
        PowerActions.actions.filter(a => root.hiddenIds.indexOf(a.id) < 0)


    readonly property var hintKeys: ({
        shutdown: "powerShutdownHint",
        reboot:   "powerRebootHint",
        suspend:  "powerSuspendHint",
        hibernate:"powerHibernateHint",
        lock:     "powerLockHint",
        logout:   "powerLogoutHint"
    })


    FontMetrics { id: labelFm; font.pixelSize: Theme.dfs(12); font.bold: true; font.family: Theme.fontFamily }
    readonly property real labelMaxW: {
        let m = Math.ceil(labelFm.advanceWidth(Translations.t("dashboardConfirm")))
        for (const a of root.visibleActions)
            m = Math.max(m, Math.ceil(labelFm.advanceWidth(Translations.t(a.labelKey))))
        return m
    }
    readonly property int btnH: Theme.ds(58)
    readonly property int btnGap: Theme.ds(8)
    readonly property int infoH: Theme.ds(46)
    readonly property int cols: Math.max(1, Math.min(root.visibleActions.length, 3))
    readonly property int rows: Math.max(1, Math.ceil(root.visibleActions.length / root.cols))

    readonly property int tileMinW: Theme.ds(12 + 36 + 10 + 10) + root.labelMaxW
    readonly property int preferredWidth: Math.max(Theme.ds(440),
        root.cols * root.tileMinW + (root.cols - 1) * root.btnGap + Theme.ds(28))
    readonly property int maxWidth: Theme.ds(560)

    readonly property int preferredHeight: Theme.ds(12) + root.infoH + Theme.ds(10)
        + root.rows * root.btnH + (root.rows - 1) * root.btnGap + Theme.ds(10) + Theme.ds(16) + Theme.ds(14)

    property string pendingId: ""

    // ── Teclado ──
    property int sel: 0
    property bool kbd: false
    DashboardNav { id: nav }
    HoverHandler { onPointChanged: root.kbd = false }

    function activate(btnItem) {
        if (root.pendingId === btnItem.id) {
            pendingTimer.stop()
            root.pendingId = ""
            PowerActions.run(btnItem)
        } else {
            root.pendingId = btnItem.id
            pendingTimer.restart()
        }
    }

    function handleKey(key, modifiers) {
        if (nav.isDir(key)) {
            if (!root.kbd) { root.kbd = true; return true }
            const n = nav.move(root.sel, root.visibleActions.length, root.cols, key)
            if (n < 0) return false
            root.sel = n
            root.pendingId = ""
            return true
        }
        if (nav.isAccept(key)) {
            if (!root.kbd) { root.kbd = true; return true }
            const a = root.visibleActions[root.sel]
            if (a) root.activate(a)
            return true
        }
        return false
    }

    property string hoverId: ""
    readonly property string footHint: {
        if (root.pendingId === "" && root.hoverId !== "" && root.hintKeys[root.hoverId])
            return Translations.t(root.hintKeys[root.hoverId])
        return Translations.t("dashboardPowerHint")
    }
    Timer { id: pendingTimer; interval: 3000; onTriggered: root.pendingId = "" }

    function withAlpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    // ── Datos de la sesión: equipo y tiempo encendido ───────────
    property string hostName: ""
    property real uptimeSec: 0
    function fmtUptime(s) {
        const d = Math.floor(s / 86400)
        const h = Math.floor((s % 86400) / 3600)
        const m = Math.floor((s % 3600) / 60)
        if (d > 0) return d + "d " + h + "h"
        if (h > 0) return h + "h " + m + "min"
        return m + "min"
    }
    Process {
        id: infoProc
        command: ["bash", "-c", "read -r up _ < /proc/uptime; echo \"${up%%.*} $(uname -n)\""]
        running: false
        stdout: SplitParser {
            onRead: line => {
                const p = line.trim().split(" ")
                root.uptimeSec = parseInt(p[0]) || 0
                root.hostName = p.slice(1).join(" ")
            }
        }
    }
    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: { if (!infoProc.running) infoProc.running = true }
    }

    // ── Chip informativo (ícono + texto) ────────────────────────
    component InfoChip: Rectangle {
        id: chip
        property string icon: ""
        property string text: ""
        property color tone: Theme.primary

        property bool battery: false
        implicitWidth: chipRow.implicitWidth + Theme.ds(14)
        implicitHeight: Theme.ds(24)
        radius: Theme.cozy ? 3 : Theme.ds(12)
        color: root.withAlpha(chip.tone, Theme.cozy ? 0.24 : 0.14)
        border.width: Theme.cozy ? 2 : 0
        border.color: Theme.ink
        RowLayout {
            id: chipRow
            anchors.centerIn: parent
            spacing: Theme.ds(5)
            Text {
                visible: !chip.battery
                text: chip.icon
                color: chip.tone
                font.pixelSize: Theme.dfs(12)
                font.family: Theme.monoFamily
            }
            BatteryIcon {
                visible: chip.battery
                Layout.alignment: Qt.AlignVCenter
                percentage: BatteryBackend.percentage
                charging: BatteryBackend.charging
                full: BatteryBackend.fullyCharged
                low: BatteryBackend.isLow
                iconHeight: Math.max(10, Theme.dfs(11))
            }
            Text {
                text: chip.text
                color: Theme.text
                font.pixelSize: Theme.dfs(11)
                font.bold: true
                font.family: Theme.fontFamily
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.ds(14)
        anchors.rightMargin: Theme.ds(14)
        anchors.topMargin: Theme.ds(12)
        anchors.bottomMargin: Theme.ds(14)
        spacing: Theme.ds(10)

        // ── 1. Tarjeta de sesión ────────────────────────────────
        SkinRect {
            Layout.fillWidth: true
            Layout.preferredHeight: root.infoH
            radius: Theme.ds(14)
            color: Theme.surface
            border.width: Theme.cozy ? 0 : Theme.bw1
            border.color: root.withAlpha(Theme.primary, 0.14)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.ds(8)
                anchors.rightMargin: Theme.ds(10)
                spacing: Theme.ds(10)

                Avatar {
                    Layout.alignment: Qt.AlignVCenter
                    size: Theme.ds(32)
                    source: UserProfile.avatarUrl
                    letter: (UserProfile.shownName || "?").charAt(0).toUpperCase()
                }

                ColumnLayout {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.fillWidth: true
                    spacing: 0
                    Text {
                        Layout.fillWidth: true
                        text: UserProfile.shownName
                        color: Theme.text
                        font.pixelSize: Theme.dfs(13)
                        font.bold: true
                        font.family: Theme.fontFamily
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: root.hostName !== ""
                        text: OozeIcons.nixos + "  @" + root.hostName
                        color: Theme.subtext
                        font.pixelSize: Theme.dfs(10)
                        font.family: Theme.monoFamily
                        elide: Text.ElideRight
                    }
                }

                InfoChip {
                    Layout.alignment: Qt.AlignVCenter
                    visible: root.uptimeSec > 0
                    icon: OozeIcons.uptime
                    text: Translations.t("dashboardUptime") + " " + root.fmtUptime(root.uptimeSec)
                    tone: Theme.primary
                }
                InfoChip {
                    Layout.alignment: Qt.AlignVCenter
                    visible: BatteryBackend.available
                    battery: true
                    text: Math.round(BatteryBackend.percentage * 100) + "%"
                    tone: BatteryBackend.isLow ? Theme.error : Theme.primary
                }
            }
        }

        // ── 2. Botones de acción ────────────────────────────────
        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: root.cols
            rowSpacing: root.btnGap
            columnSpacing: root.btnGap

            Repeater {
                model: root.visibleActions

                delegate: Rectangle {
                    id: btn
                    required property var modelData
                    required property int index
                    readonly property bool pending: root.pendingId === modelData.id
                    readonly property bool hovered: hm.containsMouse || (root.kbd && root.sel === btn.index)
                    readonly property color accent: modelData.id === "shutdown" ? Theme.error : Theme.primary
                    readonly property color onAccent: modelData.id === "shutdown"
                        ? Theme.textOnError : Theme.textOnPrimary
                    readonly property string hintKey: root.hintKeys[modelData.id] ?? ""
                    onHoveredChanged: {
                        if (btn.hovered) root.hoverId = btn.modelData.id
                        else if (root.hoverId === btn.modelData.id) root.hoverId = ""
                    }


                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: root.btnH


                    radius: Theme.cozy ? 0 : Theme.ds(14)
                    color: Theme.cozy ? "transparent"
                         : (btn.pending ? btn.accent
                            : (btn.hovered ? Theme.surfaceHigh : Theme.surface))
                    border.width: Theme.cozy ? 0 : 1
                    border.color: btn.pending ? btn.accent
                                : root.withAlpha(btn.accent, btn.hovered ? 0.55 : 0.22)
                    Behavior on color { ColorAnimation { duration: Theme.animDuration(160) } }
                    Behavior on border.color { ColorAnimation { duration: Theme.animDuration(160) } }


                    scale: Theme.cozy ? 1.0 : (hm.pressed ? 0.97 : 1.0)
                    Behavior on scale { NumberAnimation { duration: Theme.animDuration(120) } }

                    readonly property int sink: (Theme.cozy && hm.pressed) ? Theme.shadowY : 0

                    CozyBox {
                        visible: Theme.cozy
                        x: 0
                        y: btn.sink
                        width: parent.width
                        height: parent.height - Theme.shadowY
                        notch: 4
                        shadow: !hm.pressed
                        shadowOffset: Theme.shadowY
                        dither: !btn.pending
                        fillTop: btn.pending ? Theme.mix(btn.accent, "#ffffff", 0.18)
                               : Theme.mix(Theme.surface, btn.accent, btn.hovered ? 0.34 : 0.20)
                        fillBottom: btn.pending ? btn.accent
                                  : Theme.mix(Theme.surface, btn.accent, btn.hovered ? 0.12 : 0.04)
                    }


                    Rectangle {
                        visible: !Theme.cozy
                        anchors.fill: parent
                        radius: btn.radius
                        opacity: btn.pending ? 0 : (btn.hovered ? 1 : 0.75)
                        Behavior on opacity { NumberAnimation { duration: Theme.animDuration(180) } }
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: root.withAlpha(btn.accent, 0.22) }
                            GradientStop { position: 0.6; color: root.withAlpha(btn.accent, 0.05) }
                            GradientStop { position: 1.0; color: "transparent" }
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.ds(12)
                        anchors.rightMargin: Theme.ds(10)
                        anchors.topMargin: Theme.ds(6) + btn.sink
                        anchors.bottomMargin: Theme.ds(6) + Theme.shadowY - btn.sink
                        spacing: Theme.ds(10)


                        Item {
                            Layout.alignment: Qt.AlignVCenter
                            Layout.preferredWidth: Theme.ds(36)
                            Layout.preferredHeight: Theme.ds(36)

                            Rectangle {
                                id: pulseRing
                                visible: !Theme.cozy
                                anchors.centerIn: parent
                                width: Theme.ds(36)
                                height: Theme.ds(36)
                                radius: Theme.ds(18)
                                color: "transparent"
                                border.width: 1.5
                                border.color: btn.pending ? btn.onAccent : btn.accent
                                opacity: btn.pending ? 0.55 : (btn.hovered ? 0.4 : 0.2)
                                Behavior on opacity { NumberAnimation { duration: Theme.animDuration(180) } }

                                SequentialAnimation on scale {
                                    running: btn.pending && Theme.uiAnimationsEnabled
                                    loops: Animation.Infinite
                                    onRunningChanged: if (!running) pulseRing.scale = 1
                                    NumberAnimation { from: 0.92; to: 1.08; duration: Theme.animDuration(520); easing.type: Easing.InOutSine }
                                    NumberAnimation { from: 1.08; to: 0.92; duration: Theme.animDuration(520); easing.type: Easing.InOutSine }
                                }
                            }


                            Rectangle {
                                anchors.centerIn: parent
                                width: Theme.ds(30)
                                height: Theme.ds(30)
                                radius: Theme.cozy ? 0 : Theme.ds(15)
                                color: Theme.cozy ? "transparent"
                                     : (btn.pending ? root.withAlpha(btn.onAccent, 0.20)
                                        : root.withAlpha(btn.accent, btn.hovered ? 0.30 : 0.18))
                                Behavior on color { ColorAnimation { duration: Theme.animDuration(160) } }


                                CozyBox {
                                    visible: Theme.cozy
                                    anchors.fill: parent
                                    notch: 3
                                    shadow: false
                                    fillTop: btn.pending ? Theme.mix(btn.accent, Theme.ink, 0.15)
                                           : Theme.mix(Theme.bg, btn.accent, btn.hovered ? 0.55 : 0.40)
                                    fillBottom: btn.pending ? Theme.mix(btn.accent, Theme.ink, 0.40)
                                              : Theme.mix(Theme.bg, btn.accent, btn.hovered ? 0.30 : 0.20)
                                }

                                Text {
                                    id: iconText
                                    anchors.centerIn: parent
                                    text: btn.modelData.icon
                                    color: btn.pending ? btn.onAccent : btn.accent
                                    font.pixelSize: Theme.dfs(17)
                                    font.family: Theme.monoFamily
                                    Behavior on color { ColorAnimation { duration: Theme.animDuration(160) } }


                                    SequentialAnimation {
                                        running: (Theme.cozy && btn.pending) && Theme.uiAnimationsEnabled
                                        loops: Animation.Infinite
                                        onRunningChanged: if (!running) iconText.opacity = 1
                                        PropertyAction { target: iconText; property: "opacity"; value: 1 }
                                        PauseAnimation { duration: Theme.animDuration(420) }
                                        PropertyAction { target: iconText; property: "opacity"; value: 0.35 }
                                        PauseAnimation { duration: Theme.animDuration(260) }
                                    }
                                }
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignVCenter
                            Layout.fillWidth: true
                            text: btn.pending
                                ? Translations.t("dashboardConfirm")
                                : Translations.t(btn.modelData.labelKey)
                            color: btn.pending ? btn.onAccent : Theme.text
                            font.pixelSize: Theme.dfs(12)
                            font.bold: true
                            font.family: Theme.fontFamily
                            elide: Text.ElideRight
                            Behavior on color { ColorAnimation { duration: Theme.animDuration(160) } }
                        }
                    }


                    Rectangle {
                        id: countdown
                        visible: btn.pending
                        readonly property real full: btn.width - Theme.ds(28)
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: Theme.ds(5) + (Theme.cozy ? Theme.shadowY : 0) + btn.sink
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: Theme.ds(3)
                        radius: Theme.cozy ? 0 : Theme.ds(2)
                        color: btn.onAccent
                        opacity: 0.85
                        width: countdown.full
                        NumberAnimation on width {
                            running: btn.pending
                            from: countdown.full
                            to: 0
                            duration: pendingTimer.interval
                        }
                    }

                    MouseArea {
                        id: hm
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (btn.pending) {
                                pendingTimer.stop()
                                root.pendingId = ""
                                PowerActions.run(btn.modelData)
                            } else {
                                root.pendingId = btn.modelData.id
                                pendingTimer.restart()
                            }
                        }
                    }
                }
            }
        }

        // ── 3. Pie: cómo se confirma ────────────────────────────
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredHeight: Theme.ds(16)
            spacing: Theme.ds(6)
            Text {
                text: OozeIcons.hint
                color: Theme.subtext
                opacity: 0.8
                font.pixelSize: Theme.dfs(12)
                font.family: Theme.monoFamily
            }
            Text {
                text: root.footHint
                color: Theme.subtext
                font.pixelSize: Theme.dfs(10)
                font.family: Theme.fontFamily
            }
        }
    }
}
