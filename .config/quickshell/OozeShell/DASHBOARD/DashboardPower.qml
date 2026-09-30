import QtQuick
import QtQuick.Layouts
import "../COMMON"
import "../LANG"
import "../POWER"

// DashboardPower — acciones de POWER/PowerActions.qml (el mismo backend
// que usa POWER/PowerMenu.qml), en botones GRANDES uno al lado del otro:
// el Dashboard es más ancho que una lista vertical necesita, así que se
// usa ese espacio en horizontal.
//
// Cada botón tiene su color de acento (apagar = error, el resto = primary),
// un badge circular con anillos tras el ícono, una barrita de acento arriba,
// degradado suave, borde que se enciende al pasar el mouse y un "pulso"
// mientras espera la confirmación.
//
// Mismo mecanismo de confirmación que antes (un clic marca "¿Seguro?", un
// segundo clic antes de 3s recién ejecuta) — solo cambió el aspecto.
Item {
    id: root

    // Acá solo van apagar / reiniciar / cerrar sesión: suspender e hibernar
    // no se muestran en el dock (siguen existiendo en PowerActions y en el
    // PowerMenu de pantalla completa).
    readonly property var hiddenIds: ["suspend", "hibernate"]
    readonly property var visibleActions:
        PowerActions.actions.filter(a => root.hiddenIds.indexOf(a.id) < 0)

    // El ancho de los botones sigue al nombre MÁS LARGO del idioma actual
    // ("Cerrar sesión", "シャットダウン"…): todos iguales, y ninguno corta.
    FontMetrics { id: labelFm; font.pixelSize: Theme.dfs(13); font.bold: true; font.family: Theme.fontFamily }
    readonly property real labelMaxW: {
        let m = Math.ceil(labelFm.advanceWidth(Translations.t("dashboardConfirm")))
        for (const a of root.visibleActions)
            m = Math.max(m, Math.ceil(labelFm.advanceWidth(Translations.t(a.labelKey))))
        return m
    }
    readonly property int btnW: Math.max(Theme.ds(124), root.labelMaxW + Theme.ds(28))
    readonly property int btnH: Theme.ds(156)
    readonly property int btnGap: Theme.ds(12)
    readonly property int preferredWidth: Math.min(Theme.ds(560), Math.max(Theme.ds(400),
        root.visibleActions.length * (root.btnW + root.btnGap) + Theme.ds(28)))

    property string pendingId: ""
    Timer { id: pendingTimer; interval: 3000; onTriggered: root.pendingId = "" }

    function withAlpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

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
                Behavior on color { ColorAnimation { duration: 160 } }
                Behavior on border.color { ColorAnimation { duration: 160 } }

                // Sin escala en CoOzey (escalar pixel art lo vuelve borroso):
                // el botón se hunde hasta su sombra, como CozyButton.
                scale: Theme.cozy ? 1.0 : (hm.pressed ? 0.94 : (btn.hovered ? 1.05 : 1.0))
                Behavior on scale { NumberAnimation { duration: 170; easing.type: Easing.OutBack } }

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
                    radius: parent.radius
                    opacity: btn.pending ? 0 : (btn.hovered ? 1 : 0.65)
                    Behavior on opacity { NumberAnimation { duration: 180 } }
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: root.withAlpha(btn.accent, 0.22) }
                        GradientStop { position: 0.6; color: root.withAlpha(btn.accent, 0.04) }
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
                    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 160 } }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 4 + btn.sink
                    width: parent.width - 14
                    spacing: Theme.ds(12)

                    // Badge circular con anillos
                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: Theme.ds(84)
                        Layout.preferredHeight: Theme.ds(84)

                        // Anillo exterior (pulsa mientras espera confirmación)
                        Rectangle {
                            id: pulseRing
                            visible: !Theme.cozy
                            anchors.centerIn: parent
                            width: Theme.ds(84)
                            height: Theme.ds(84)
                            radius: Theme.ds(42)
                            color: "transparent"
                            border.width: 2
                            border.color: btn.pending ? btn.onAccent : btn.accent
                            opacity: btn.pending ? 0.5 : (btn.hovered ? 0.35 : 0.14)
                            Behavior on opacity { NumberAnimation { duration: 180 } }

                            SequentialAnimation on scale {
                                running: btn.pending
                                loops: Animation.Infinite
                                onRunningChanged: if (!running) pulseRing.scale = 1
                                NumberAnimation { from: 0.92; to: 1.08; duration: 520; easing.type: Easing.InOutSine }
                                NumberAnimation { from: 1.08; to: 0.92; duration: 520; easing.type: Easing.InOutSine }
                            }
                        }

                        // Disco central
                        Rectangle {
                            anchors.centerIn: parent
                            width: Theme.ds(64)
                            height: Theme.ds(64)
                            radius: Theme.cozy ? 0 : Theme.ds(32)
                            color: Theme.cozy ? "transparent"
                                 : (btn.pending ? root.withAlpha(btn.onAccent, 0.20)
                                    : root.withAlpha(btn.accent, btn.hovered ? 0.30 : 0.18))
                            border.width: Theme.cozy ? 0 : Theme.bw1
                            border.color: btn.pending ? root.withAlpha(btn.onAccent, 0.55)
                                                      : root.withAlpha(btn.accent, 0.45)
                            Behavior on color { ColorAnimation { duration: 160 } }
                            Behavior on border.color { ColorAnimation { duration: 160 } }

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
                                font.pixelSize: Theme.dfs(30)
                                font.family: Theme.monoFamily
                                Behavior on color { ColorAnimation { duration: 160 } }

                                // Sin suavizado: parpadeo de dos cuadros, como un sprite
                                SequentialAnimation {
                                    running: Theme.cozy && btn.pending
                                    loops: Animation.Infinite
                                    onRunningChanged: if (!running) iconText.opacity = 1
                                    PropertyAction { target: iconText; property: "opacity"; value: 1 }
                                    PauseAnimation { duration: 420 }
                                    PropertyAction { target: iconText; property: "opacity"; value: 0.35 }
                                    PauseAnimation { duration: 260 }
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
                        Behavior on color { ColorAnimation { duration: 160 } }
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
