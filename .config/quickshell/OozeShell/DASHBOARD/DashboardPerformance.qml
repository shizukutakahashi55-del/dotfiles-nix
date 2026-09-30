import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import "../COMMON"
import "../LANG"
import "../MENU"
import "../POWER"

// DashboardPerformance — la parte de "sistema" del Menú ❄: CPU / RAM / GPU
// (mismos SystemStats + Sparkline que MENU/Menu.qml) y los tres perfiles de
// energía (mismo POWER/PowerProfile.qml).
//
// Decoración: cada métrica es una tarjeta propia con su color de acento
// (tonos vecinos al primary del tema), un medidor circular animado con el
// valor al centro, chip de ícono y la gráfica de historial abajo. Si una
// métrica pasa del 85 % el medidor se pone en el color de error. Los
// perfiles de energía llevan badge de ícono y el activo se enciende con
// degradado y borde.
//
// (MENU/MetricCard.qml no se toca: lo sigue usando el Menú.)
Item {
    id: root
    readonly property int preferredWidth: Theme.ds(480)
    readonly property int preferredHeight: Theme.ds(256)
    function withAlpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
    // Rota el matiz del color del tema: da acentos vecinos que combinan
    function shifted(c, d) {
        const h = c.hslHue < 0 ? 0 : c.hslHue
        return Qt.hsla((h + d + 1) % 1, Math.max(0.35, c.hslSaturation),
                       Math.max(0.5, Math.min(0.72, c.hslLightness)), 1)
    }

    SystemStats {
        id: stats
        active: true      // este panel solo existe mientras el Dashboard está abierto
    }

    Component.onCompleted: PowerProfile.setWanted("dashboard", true)
    Component.onDestruction: PowerProfile.setWanted("dashboard", false)

    // ── Tarjeta de métrica ──────────────────────────────────────
    component StatCard: SkinRect {
        id: sc
        property string icon: ""
        property string label: ""
        property string detail: ""
        property real value: -1          // 0..100; negativo = N/A
        property var history: []
        property int maxSamples: 30
        property color accent: Theme.primary

        readonly property bool hot: sc.value >= 85
        readonly property color ringColor: sc.hot ? Theme.error : sc.accent

        // Valor mostrado en el medidor (se anima)
        property real shown: sc.value < 0 ? 0 : sc.value
        Behavior on shown { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }

        Layout.minimumHeight: Theme.ds(150)

        radius: Theme.ds(18)
        raised: Theme.cozy
        depth: 2
        inkColor: Theme.ink
        color: Theme.cozy ? "transparent" : Theme.surface
        border.width: Theme.cozy ? 0 : Theme.bw1
        border.color: root.withAlpha(sc.ringColor, 0.28)
        Behavior on border.color { ColorAnimation { duration: 300 } }

        // CoOzey: tarjeta de papel pixel; el acento tiñe el degradado
        CozyBox {
            visible: Theme.cozy
            anchors.fill: parent
            anchors.bottomMargin: Theme.shadowY
            notch: 4
            dither: true
            fillTop: Theme.mix(Theme.surface, sc.ringColor, 0.24)
            fillBottom: Theme.mix(Theme.surface, sc.ringColor, 0.04)
        }

        // Brillo de acento desde arriba
        Rectangle {
            visible: !Theme.cozy
            anchors.fill: parent
            radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0.0; color: root.withAlpha(sc.ringColor, 0.16) }
                GradientStop { position: 0.55; color: root.withAlpha(sc.ringColor, 0.03) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.ds(10)
            spacing: Theme.ds(4)

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.ds(6)

                Rectangle {
                    Layout.preferredWidth: Theme.ds(22)
                    Layout.preferredHeight: Theme.ds(22)
                    radius: Theme.cozy ? 3 : Theme.ds(8)
                    color: root.withAlpha(sc.ringColor, Theme.cozy ? 0.32 : 0.20)
                    border.width: Theme.cozy ? 2 : 0
                    border.color: Theme.ink
                    Behavior on color { ColorAnimation { duration: 300 } }
                    Text {
                        anchors.centerIn: parent
                        text: sc.icon
                        color: sc.ringColor
                        font.pixelSize: Theme.dfs(12)
                        font.family: Theme.monoFamily
                        Behavior on color { ColorAnimation { duration: 300 } }
                    }
                }
                Text {
                    text: sc.label
                    color: Theme.text
                    font.pixelSize: Theme.dfs(10)
                    font.bold: true
                    font.family: Theme.fontFamily
                }
                Item { Layout.fillWidth: true }
                Text {
                    visible: sc.detail !== ""
                    text: sc.detail
                    color: Theme.subtext
                    font.pixelSize: Theme.dfs(9)
                    font.family: Theme.fontFamily
                }
            }

            // Medidor circular
            Item {
                id: gaugeArea
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.ds(60)

                readonly property real size: Theme.ds(58)
                readonly property real stroke: Theme.ds(6)

                // Pista del medidor: un Rectangle redondo con borde = anillo de UNA
                // sola capa. Antes era un arco de 359.9° con color translúcido: el
                // renderer parte el arco en tramos y donde se solapan (uniones y
                // tapas redondas) el alfa se sumaba y quedaban marcas más oscuras.
                PixelRing {
                    visible: Theme.cozy
                    anchors.centerIn: parent
                    width: gaugeArea.size
                    height: gaugeArea.size
                    value: sc.shown
                    segments: 20
                    cell: Theme.ds(6)
                    color: sc.ringColor
                    track: root.withAlpha(sc.ringColor, 0.16)
                }

                Rectangle {
                    visible: !Theme.cozy
                    anchors.centerIn: parent
                    width: gaugeArea.size
                    height: gaugeArea.size
                    radius: width / 2
                    color: "transparent"
                    border.width: gaugeArea.stroke
                    border.color: root.withAlpha(sc.ringColor, 0.14)
                    Behavior on border.color { ColorAnimation { duration: 300 } }
                }

                Shape {
                    id: gauge
                    visible: !Theme.cozy
                    anchors.centerIn: parent
                    width: gaugeArea.size
                    height: gaugeArea.size
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        strokeColor: sc.shown > 0.4 ? sc.ringColor : "transparent"
                        strokeWidth: gaugeArea.stroke
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        PathAngleArc {
                            centerX: gauge.width / 2; centerY: gauge.height / 2
                            radiusX: (gauge.width - gaugeArea.stroke) / 2
                            radiusY: (gauge.height - gaugeArea.stroke) / 2
                            startAngle: -90
                            sweepAngle: 359.9 * Math.max(0, Math.min(100, sc.shown)) / 100
                        }
                    }
                }

                Text {
                    anchors.centerIn: gauge
                    text: sc.value < 0 ? "N/A" : Math.round(sc.value) + "%"
                    color: Theme.text
                    font.pixelSize: Theme.dfs(sc.value < 0 ? 11 : 13)
                    font.bold: true
                    font.family: Theme.fontFamily
                }
            }

            // Gráfica: ocupa todo el alto que sobra, sobre un fondo propio
            // para que se lea (línea más gruesa y área más marcada)
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: Theme.ds(40)
                radius: Theme.cozy ? 3 : Theme.ds(10)
                color: root.withAlpha(Theme.bg, Theme.cozy ? 0.70 : 0.55)
                border.width: Theme.bw1
                border.color: Theme.cozy ? Theme.ink : root.withAlpha(sc.ringColor, 0.16)

                PixelSteps {
                    visible: Theme.cozy
                    anchors.fill: parent
                    anchors.margins: Theme.ds(3)
                    values: sc.history
                    maxSamples: sc.maxSamples
                    color: sc.ringColor
                    cellH: Theme.ds(4)
                }
                Sparkline {
                    visible: !Theme.cozy
                    anchors.fill: parent
                    anchors.margins: Theme.ds(3)
                    values: sc.history
                    maxSamples: sc.maxSamples
                    lineColor: sc.ringColor
                    areaAlpha: 0.34
                    lineWidth: 2.2
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.ds(14)
        spacing: Theme.ds(10)

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: Theme.ds(150)
            spacing: Theme.ds(10)

            StatCard {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                icon: "󰻠"
                label: "CPU"
                accent: Theme.primary
                value: stats.cpu
                history: stats.cpuHistory
                maxSamples: stats.maxSamples
            }
            StatCard {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                icon: "󰍛"
                label: "RAM"
                accent: root.shifted(Theme.primary, 0.12)
                value: stats.ram
                detail: stats.ramTotalGb > 0
                    ? stats.ramUsedGb.toFixed(1) + "/" + stats.ramTotalGb.toFixed(0) + "G" : ""
                history: stats.ramHistory
                maxSamples: stats.maxSamples
            }
            StatCard {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                icon: "󰢮"
                label: "GPU"
                accent: root.shifted(Theme.primary, -0.12)
                value: stats.gpu
                history: stats.gpuHistory
                maxSamples: stats.maxSamples
            }
        }

        // ── Perfiles de energía ─────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: false
            Layout.preferredHeight: Theme.ds(34)
            Layout.minimumHeight: Theme.ds(34)
            Layout.maximumHeight: Theme.ds(34)
            spacing: Theme.ds(8)

            Repeater {
                model: PowerProfile.profiles
                delegate: Item {
                    id: pwrCell
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.fillHeight: true
                    readonly property bool sel: PowerProfile.current === modelData.key

                    // CoOzey: botón de juego; el perfil activo se "enciende"
                    CozyButton {
                        visible: Theme.cozy
                        anchors.fill: parent
                        depth: 3
                        active: pwrCell.sel
                        face: pwrCell.sel ? Theme.primary : Theme.surface
                        faceHover: pwrCell.sel ? Theme.mix(Theme.primary, "#ffffff", 0.15) : Theme.surfaceHigh
                        onClicked: PowerProfile.set(pwrCell.modelData.key)
                        RowLayout {
                            anchors.centerIn: parent
                            spacing: Theme.ds(6)
                            Rectangle {
                                Layout.preferredWidth: Theme.ds(20)
                                Layout.preferredHeight: Theme.ds(20)
                                radius: 3
                                color: pwrCell.sel ? root.withAlpha(Theme.textOnPrimary, 0.22)
                                                   : root.withAlpha(Theme.primary, 0.20)
                                border.width: 2
                                border.color: Theme.ink
                                Text {
                                    anchors.centerIn: parent
                                    text: pwrCell.modelData.icon
                                    color: pwrCell.sel ? Theme.textOnPrimary : Theme.primary
                                    font.pixelSize: Theme.dfs(11)
                                    font.family: Theme.monoFamily
                                }
                            }
                            Text {
                                text: Translations.t(pwrCell.modelData.labelKey)
                                Layout.maximumWidth: Math.max(Theme.ds(20), pwrCell.width - Theme.ds(20) - Theme.ds(6) - Theme.ds(22))
                                elide: Text.ElideRight
                                color: pwrCell.sel ? Theme.textOnPrimary : Theme.text
                                font.pixelSize: Theme.dfs(10)
                                font.bold: pwrCell.sel
                                font.family: Theme.fontFamily
                            }
                        }
                    }

                  Rectangle {
                    id: pbtn
                    visible: !Theme.cozy
                    anchors.fill: parent
                    readonly property var modelData: pwrCell.modelData
                    readonly property bool sel: pwrCell.sel
                    readonly property bool hovered: pm.containsMouse
                    radius: Theme.ds(12)
                    color: sel ? Theme.primary : (hovered ? Theme.surfaceHigh : Theme.surface)
                    border.width: 1.5
                    border.color: sel ? Theme.primary
                                      : root.withAlpha(Theme.primary, hovered ? 0.55 : 0.18)
                    Behavior on color { ColorAnimation { duration: 180 } }
                    Behavior on border.color { ColorAnimation { duration: 180 } }
                    scale: Theme.cozy ? 1.0 : (pm.pressed ? 0.96 : (hovered ? 1.02 : 1.0))
                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                    // Brillo superior del perfil activo
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        opacity: pbtn.sel ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.20) }
                            GradientStop { position: 0.7; color: "transparent" }
                        }
                    }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: Theme.ds(6)

                        Rectangle {
                            Layout.preferredWidth: Theme.ds(22)
                            Layout.preferredHeight: Theme.ds(22)
                            radius: Theme.ds(11)
                            color: pbtn.sel ? root.withAlpha(Theme.textOnPrimary, 0.22)
                                            : root.withAlpha(Theme.primary, 0.16)
                            Behavior on color { ColorAnimation { duration: 180 } }
                            Text {
                                anchors.centerIn: parent
                                text: pbtn.modelData.icon
                                color: pbtn.sel ? Theme.textOnPrimary : Theme.primary
                                font.pixelSize: Theme.dfs(12)
                                font.family: Theme.monoFamily
                                Behavior on color { ColorAnimation { duration: 180 } }
                            }
                        }
                        Text {
                            text: Translations.t(pbtn.modelData.labelKey)
                            // Nunca más ancho que el botón (idiomas largos)
                            Layout.maximumWidth: Math.max(Theme.ds(20), pbtn.width - Theme.ds(22) - Theme.ds(6) - Theme.ds(16))
                            elide: Text.ElideRight
                            color: pbtn.sel ? Theme.textOnPrimary : Theme.text
                            font.pixelSize: Theme.dfs(10)
                            font.bold: pbtn.sel
                            font.family: Theme.fontFamily
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }
                    }

                    MouseArea {
                        id: pm
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: PowerProfile.set(pbtn.modelData.key)
                    }
                  }
                }
            }
        }
    }
}
