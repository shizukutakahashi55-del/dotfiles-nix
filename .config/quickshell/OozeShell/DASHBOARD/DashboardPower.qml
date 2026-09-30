import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../COMMON"
import "../LANG"
import "../POWER"
import "../BATTERY"

// DashboardPower — acciones de POWER/PowerActions.qml (el mismo backend
// que usa POWER/PowerMenu.qml), en botones GRANDES uno al lado del otro.
//
// Antes eran tres botones flotando en un panel vacío. Ahora la sección tiene
// tres capas:
//   1. Tarjeta de sesión (arriba): foto + nombre + equipo, y chips con el
//      tiempo encendido y la batería (si la hay).
//   2. Los botones: badge con anillos, nombre, una línea que explica qué
//      hace cada uno y una barrita de acento arriba.
//   3. Pie con la pista de confirmación.
//
// Confirmación (igual que antes): un clic marca "¿Seguro?", un segundo clic
// antes de 3 s ejecuta. Nuevo: una barrita se va vaciando en el botón para
// que se vea cuánto tiempo queda.
Item {
    id: root

    // Acá solo van apagar / reiniciar / cerrar sesión: suspender e hibernar
    // no se muestran en el dock (siguen existiendo en PowerActions y en el
    // PowerMenu de pantalla completa).
    readonly property var hiddenIds: ["suspend", "hibernate"]
    readonly property var visibleActions:
        PowerActions.actions.filter(a => root.hiddenIds.indexOf(a.id) < 0)

    // Línea descriptiva de cada acción (clave de traducción)
    readonly property var hintKeys: ({
        shutdown: "powerShutdownHint",
        reboot:   "powerRebootHint",
        logout:   "powerLogoutHint"
    })

    // El ancho de los botones sigue al nombre MÁS LARGO del idioma actual
    // ("Cerrar sesión", "シャットダウン"…): todos iguales, y ninguno corta.
    FontMetrics { id: labelFm; font.pixelSize: Theme.dfs(13); font.bold: true; font.family: Theme.fontFamily }
    readonly property real labelMaxW: {
        let m = Math.ceil(labelFm.advanceWidth(Translations.t("dashboardConfirm")))
        for (const a of root.visibleActions)
            m = Math.max(m, Math.ceil(labelFm.advanceWidth(Translations.t(a.labelKey))))
        return m
    }
    readonly property int btnW: Math.max(Theme.ds(132), root.labelMaxW + Theme.ds(28))
    readonly property int btnH: Theme.ds(168)
    readonly property int btnGap: Theme.ds(12)
    readonly property int infoH: Theme.ds(46)
    readonly property int preferredWidth: Math.min(Theme.ds(560), Math.max(Theme.ds(440),
        root.visibleActions.length * (root.btnW + root.btnGap) + Theme.ds(28)))
    // margen sup. + tarjeta + aire + botones + aire + pie + margen inf.
    readonly property int preferredHeight: Theme.ds(12) + root.infoH + Theme.ds(10)
        + root.btnH + Theme.ds(10) + Theme.ds(16) + Theme.ds(14)

    property string pendingId: ""
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
                text: chip.icon
                color: chip.tone
                font.pixelSize: Theme.dfs(12)
                font.family: Theme.monoFamily
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
                        text: "@" + root.hostName
                        color: Theme.subtext
                        font.pixelSize: Theme.dfs(10)
                        font.family: Theme.fontFamily
                        elide: Text.ElideRight
                    }
                }

                InfoChip {
                    Layout.alignment: Qt.AlignVCenter
                    visible: root.uptimeSec > 0
                    icon: "󰅐"
                    text: Translations.t("dashboardUptime") + " " + root.fmtUptime(root.uptimeSec)
                    tone: Theme.primary
                }
                InfoChip {
                    Layout.alignment: Qt.AlignVCenter
                    visible: BatteryBackend.available
                    icon: BatteryBackend.icon
                    text: Math.round(BatteryBackend.percentage * 100) + "%"
                    tone: BatteryBackend.isLow ? Theme.error : Theme.primary
                }
            }
        }

        // ── 2. Botones de acción ────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            GridLayout {
                anchors.centerIn: parent
                columns: Math.max(1, Math.min(root.visibleActions.length, 5))
                rowSpacing: root.btnGap
                columnSpacing: root.btnGap

                Repeater {
                    model: root.visibleActions

                    delegate: Rectangle {
                        id: btn
                        required property var modelData
                        readonly property bool pending: root.pendingId === modelData.id
                        readonly property bool hovered: hm.containsMouse
                        readonly property color accent: modelData.id === "shutdown" ? Theme.error : Theme.primary
                        readonly property color onAccent: modelData.id === "shutdown"
                            ? Theme.textOnError : Theme.textOnPrimary
                        readonly property string hintKey: root.hintKeys[modelData.id] ?? ""

                        Layout.preferredWidth: root.btnW
                        Layout.preferredHeight: root.btnH
                        // CoOzey: la tarjeta la dibuja el CozyBox de abajo (papel pixel
                        // con sombra dura); este Rectangle queda sin pintar.
                        radius: Theme.cozy ? 0 : Theme.ds(22)
                        color: Theme.cozy ? "transparent"
                             : (btn.pending ? btn.accent
                                : (btn.hovered ? Theme.surfaceHigh : Theme.surface))
                        border.width: Theme.cozy ? 0 : 1.5
                        border.color: btn.pending ? btn.accent
                                    : root.withAlpha(btn.accent, btn.hovered ? 0.65 : 0.25)
                        Behavior on color { ColorAnimation { duration: Theme.animDuration(160) } }
                        Behavior on border.color { ColorAnimation { duration: Theme.animDuration(160) } }

                        // Sin escala en CoOzey (escalar pixel art lo vuelve borroso):
                        // el botón se hunde hasta su sombra, como CozyButton.
                        scale: Theme.cozy ? 1.0 : (hm.pressed ? 0.94 : (btn.hovered ? 1.04 : 1.0))
                        Behavior on scale { NumberAnimation { duration: Theme.animDuration(170); easing.type: Easing.OutBack } }

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

                        // Degradado de acento desde arriba (se apaga al confirmar)
                        Rectangle {
                            visible: !Theme.cozy
                            anchors.fill: parent
                            radius: btn.radius
                            opacity: btn.pending ? 0 : (btn.hovered ? 1 : 0.7)
                            Behavior on opacity { NumberAnimation { duration: Theme.animDuration(180) } }
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: root.withAlpha(btn.accent, 0.26) }
                                GradientStop { position: 0.55; color: root.withAlpha(btn.accent, 0.06) }
                                GradientStop { position: 1.0; color: "transparent" }
                            }
                        }

                        // Barrita de acento arriba
                        Rectangle {
                            anchors.top: parent.top
                            anchors.topMargin: Theme.ds(10) + btn.sink
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: btn.hovered || btn.pending ? 40 : 26
                            height: Theme.ds(4)
                            radius: Theme.cozy ? 0 : Theme.ds(2)
                            color: btn.pending ? btn.onAccent : btn.accent
                            opacity: btn.pending ? 0.9 : 0.85
                            Behavior on width { NumberAnimation { duration: Theme.animDuration(180); easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: Theme.animDuration(160) } }
                        }

                        ColumnLayout {
                            anchors.top: parent.top
                            anchors.topMargin: Theme.ds(24) + btn.sink
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width - Theme.ds(16)
                            spacing: Theme.ds(6)

                            // Badge circular con anillos
                            Item {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth: Theme.ds(76)
                                Layout.preferredHeight: Theme.ds(76)

                                // Anillo exterior (pulsa mientras espera confirmación)
                                Rectangle {
                                    id: pulseRing
                                    visible: !Theme.cozy
                                    anchors.centerIn: parent
                                    width: Theme.ds(76)
                                    height: Theme.ds(76)
                                    radius: Theme.ds(38)
                                    color: "transparent"
                                    border.width: 2
                                    border.color: btn.pending ? btn.onAccent : btn.accent
                                    opacity: btn.pending ? 0.5 : (btn.hovered ? 0.35 : 0.14)
                                    Behavior on opacity { NumberAnimation { duration: Theme.animDuration(180) } }

                                    SequentialAnimation on scale {
                                        running: btn.pending && Theme.uiAnimationsEnabled
                                        loops: Animation.Infinite
                                        onRunningChanged: if (!running) pulseRing.scale = 1
                                        NumberAnimation { from: 0.92; to: 1.08; duration: Theme.animDuration(520); easing.type: Easing.InOutSine }
                                        NumberAnimation { from: 1.08; to: 0.92; duration: Theme.animDuration(520); easing.type: Easing.InOutSine }
                                    }
                                }

                                // Disco central
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: Theme.ds(58)
                                    height: Theme.ds(58)
                                    radius: Theme.cozy ? 0 : Theme.ds(29)
                                    color: Theme.cozy ? "transparent"
                                         : (btn.pending ? root.withAlpha(btn.onAccent, 0.20)
                                            : root.withAlpha(btn.accent, btn.hovered ? 0.30 : 0.18))
                                    border.width: Theme.cozy ? 0 : Theme.bw1
                                    border.color: btn.pending ? root.withAlpha(btn.onAccent, 0.55)
                                                              : root.withAlpha(btn.accent, 0.45)
                                    Behavior on color { ColorAnimation { duration: Theme.animDuration(160) } }
                                    Behavior on border.color { ColorAnimation { duration: Theme.animDuration(160) } }

                                    // CoOzey: insignia cuadrada de esquinas escalonadas
                                    CozyBox {
                                        visible: Theme.cozy
                                        anchors.fill: parent
                                        notch: 4
                                        shadow: false
                                        shine: true
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
                                        font.pixelSize: Theme.dfs(28)
                                        font.family: Theme.monoFamily
                                        Behavior on color { ColorAnimation { duration: Theme.animDuration(160) } }

                                        // Sin suavizado: parpadeo de dos cuadros, como un sprite
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
                                Layout.alignment: Qt.AlignHCenter
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: btn.pending
                                    ? Translations.t("dashboardConfirm")
                                    : Translations.t(btn.modelData.labelKey)
                                color: btn.pending ? btn.onAccent : Theme.text
                                font.pixelSize: Theme.dfs(13)
                                font.bold: true
                                font.family: Theme.fontFamily
                                // Respaldo: si aun así no cupiera, baja a 2 líneas
                                // antes que cortar con "…"
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                Behavior on color { ColorAnimation { duration: Theme.animDuration(160) } }
                            }

                            // Qué hace (alto fijo: los tres botones quedan alineados)
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.fillWidth: true
                                Layout.preferredHeight: Theme.ds(26)
                                visible: btn.hintKey !== ""
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignTop
                                text: Translations.t(btn.hintKey)
                                color: btn.pending ? root.withAlpha(btn.onAccent, 0.85) : Theme.subtext
                                font.pixelSize: Theme.dfs(10)
                                font.family: Theme.fontFamily
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                Behavior on color { ColorAnimation { duration: Theme.animDuration(160) } }
                            }
                        }

                        // Cuenta atrás: la barra se vacía en los 3 s de confirmación
                        Rectangle {
                            id: countdown
                            visible: btn.pending
                            readonly property real full: btn.width - Theme.ds(32)
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: Theme.ds(12) + (Theme.cozy ? Theme.shadowY : 0) + btn.sink
                            anchors.horizontalCenter: parent.horizontalCenter
                            height: Theme.ds(4)
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
        }

        // ── 3. Pie: cómo se confirma ────────────────────────────
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredHeight: Theme.ds(16)
            spacing: Theme.ds(6)
            Text {
                text: "󰋽"
                color: Theme.subtext
                opacity: 0.8
                font.pixelSize: Theme.dfs(12)
                font.family: Theme.monoFamily
            }
            Text {
                text: Translations.t("dashboardPowerHint")
                color: Theme.subtext
                font.pixelSize: Theme.dfs(10)
                font.family: Theme.fontFamily
            }
        }
    }
}
