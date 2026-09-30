import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import "../COMMON"
import "../LANG"
import "../MENU"
import "../POWER"

// DashboardPerformance — la parte de "sistema" del Menú ❄: CPU / RAM / GPU
// (mismo SystemStats que MENU/Menu.qml) y los tres perfiles de
// energía (mismo POWER/PowerProfile.qml).
//
// Cada métrica es una tarjeta con: chip de ícono + nombre, un medidor circular
// grande con el valor en el centro y, debajo, fichas con promedio / máximo /
// temperatura. Sin gráficas de historial: solo los círculos.
// Si una métrica pasa del 85 % el medidor se pone en el color de error.
//
// (MENU/MetricCard.qml no se toca: lo sigue usando el Menú.)
Item {
    id: root
    readonly property int preferredWidth: Theme.ds(560)
    readonly property int maxWidth: Theme.ds(580)
    readonly property int preferredHeight: Theme.ds(312)
    function withAlpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
    // Rota el matiz del color del tema: da acentos vecinos que combinan
    function shifted(c, d) {
        const h = c.hslHue < 0 ? 0 : c.hslHue
        return Qt.hsla((h + d + 1) % 1, Math.max(0.35, c.hslSaturation),
                       Math.max(0.5, Math.min(0.72, c.hslLightness)), 1)
    }

    // 1 muestra por segundo, 60 s de historial (CoOzey dibuja 30 columnas:
    // más finas se vuelven ruido)
    SystemStats {
        id: stats
        active: true      // este panel solo existe mientras el Dashboard está abierto
        intervalMs: 1000
        maxSamples: 60
    }

    Component.onCompleted: PowerProfile.setWanted("dashboard", true)
    Component.onDestruction: PowerProfile.setWanted("dashboard", false)

    // Pista de cada perfil (clave de traducción)
    readonly property var profileHintKeys: ({
        "power-saver": "powerProfileSaverHint",
        "balanced":    "powerProfileBalancedHint",
        "performance": "powerProfilePerformanceHint"
    })

    // ── Ficha "etiqueta / valor" bajo el medidor ────────────────
    component Chip: Rectangle {
        id: chip
        property string label: ""
        property string value: ""
        property color tone: Theme.text
        property color accent: Theme.primary
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.fillHeight: true
        radius: Theme.cozy ? 3 : Theme.ds(10)
        color: root.withAlpha(Theme.bg, Theme.cozy ? 0.70 : 0.55)
        border.width: Theme.bw1
        border.color: Theme.cozy ? Theme.ink : root.withAlpha(chip.accent, 0.18)
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 0
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: chip.label
                color: Theme.subtext
                font.pixelSize: Theme.dfs(9)
                font.family: chip.label.length === 1 ? Theme.monoFamily : Theme.fontFamily
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: chip.value
                color: chip.tone
                font.pixelSize: Theme.dfs(12)
                font.bold: true
                font.family: Theme.fontFamily
            }
        }
    }

    // ── Tarjeta de métrica ──────────────────────────────────────
    component StatCard: SkinRect {
        id: sc
        property string icon: ""
        property string label: ""
        property string detail: ""
        property real value: -1          // 0..100; negativo = N/A
        property real temp: -1           // °C; negativo = sin sensor
        property var history: []
        property int maxSamples: 60
        property color accent: Theme.primary

        readonly property bool hot: sc.value >= 85
        readonly property color ringColor: sc.hot ? Theme.error : sc.accent
        readonly property bool na: sc.value < 0

        // Valor mostrado en el medidor (se anima)
        property real shown: sc.value < 0 ? 0 : sc.value
        Behavior on shown { NumberAnimation { duration: Theme.animDuration(500); easing.type: Easing.OutCubic } }

        // Promedio y máximo de lo que hay en pantalla
        readonly property real avg: sc.history.length
            ? sc.history.reduce((a, b) => a + b, 0) / sc.history.length : 0
        readonly property real peak: sc.history.length ? Math.max.apply(null, sc.history) : 0

        Layout.minimumHeight: Theme.ds(184)

        // OJO: el contenido de un SkinRect vive en su `body` (un Item sin
        // radio), así que los hijos NO pueden usar `parent.radius`. Por eso
        // el brillo de abajo usa `sc.radius`: antes leía el radio del body
        // (indefinido → 0) y dibujaba esquinas CUADRADAS sobre la tarjeta
        // redondeada (las "esquinas raras" de OozeSoft).
        radius: Theme.ds(18)
        raised: Theme.cozy
        depth: 2
        inkColor: Theme.ink
        color: Theme.cozy ? "transparent" : Theme.surface
        border.width: Theme.cozy ? 0 : Theme.bw1
        border.color: root.withAlpha(sc.ringColor, 0.28)
        Behavior on border.color { ColorAnimation { duration: Theme.animDuration(300) } }

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

        // Brillo de acento desde arriba (con el radio de la TARJETA)
        Rectangle {
            visible: !Theme.cozy
            anchors.fill: parent
            anchors.margins: Theme.bw1
            radius: Math.max(0, sc.radius - Theme.bw1)
            gradient: Gradient {
                GradientStop { position: 0.0; color: root.withAlpha(sc.ringColor, 0.18) }
                GradientStop { position: 0.55; color: root.withAlpha(sc.ringColor, 0.04) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.ds(10)
            spacing: Theme.ds(6)

            // ── Cabecera ────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.ds(6)

                Rectangle {
                    Layout.preferredWidth: Theme.ds(24)
                    Layout.preferredHeight: Theme.ds(24)
                    radius: Theme.cozy ? 3 : Theme.ds(8)
                    color: root.withAlpha(sc.ringColor, Theme.cozy ? 0.32 : 0.20)
                    border.width: Theme.cozy ? 2 : 0
                    border.color: Theme.ink
                    Behavior on color { ColorAnimation { duration: Theme.animDuration(300) } }
                    Text {
                        anchors.centerIn: parent
                        text: sc.icon
                        color: sc.ringColor
                        font.pixelSize: Theme.dfs(13)
                        font.family: Theme.monoFamily
                        Behavior on color { ColorAnimation { duration: Theme.animDuration(300) } }
                    }
                }
                Text {
                    text: sc.label
                    color: Theme.text
                    font.pixelSize: Theme.dfs(12)
                    font.bold: true
                    font.family: Theme.fontFamily
                }
                Item { Layout.fillWidth: true }
                Text {
                    visible: sc.detail !== ""
                    text: sc.detail
                    color: Theme.subtext
                    font.pixelSize: Theme.dfs(10)
                    font.family: Theme.fontFamily
                }
            }

            // ── Medidor circular ────────────────────────────────
            // Ocupa todo el alto que sobra: el círculo crece con la tarjeta.
            Item {
                id: gaugeArea
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: Theme.ds(70)

                readonly property real size: Math.max(Theme.ds(64),
                    Math.min(gaugeArea.width, gaugeArea.height, Theme.ds(132)))
                readonly property real stroke: Math.max(Theme.ds(7), gaugeArea.size * 0.11)

                PixelRing {
                    visible: Theme.cozy
                    anchors.centerIn: parent
                    width: gaugeArea.size
                    height: gaugeArea.size
                    value: sc.shown
                    segments: 24
                    cell: Math.round(gaugeArea.size / 10)
                    color: sc.ringColor
                    track: root.withAlpha(sc.ringColor, 0.16)
                }

                // Pista: anillo de UNA sola capa (un arco de 359.9° con color
                // translúcido dejaba marcas más oscuras donde se solapaba)
                Rectangle {
                    visible: !Theme.cozy
                    anchors.centerIn: parent
                    width: gaugeArea.size
                    height: gaugeArea.size
                    radius: width / 2
                    color: "transparent"
                    border.width: gaugeArea.stroke
                    border.color: root.withAlpha(sc.ringColor, 0.16)
                    Behavior on border.color { ColorAnimation { duration: Theme.animDuration(300) } }
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
                    anchors.centerIn: parent
                    text: sc.na ? "N/A" : Math.round(sc.value) + "%"
                    color: Theme.text
                    font.pixelSize: Theme.dfs(sc.na ? 14 : Math.max(18, Math.round(gaugeArea.size / 4.4)))
                    font.bold: true
                    font.family: Theme.fontFamily
                }
            }

            // ── Fichas: promedio / máximo / temperatura ─────────
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.ds(38)
                spacing: Theme.ds(6)
                visible: !sc.na

                Chip {
                    accent: sc.ringColor
                    label: Translations.t("perfAvg")
                    value: Math.round(sc.avg) + "%"
                }
                Chip {
                    accent: sc.ringColor
                    label: Translations.t("perfMax")
                    value: Math.round(sc.peak) + "%"
                    tone: sc.peak >= 85 ? Theme.error : Theme.text
                }
                Chip {
                    accent: sc.ringColor
                    visible: sc.temp >= 0
                    label: "󰔏"
                    value: Math.round(sc.temp) + "°C"
                    tone: sc.temp >= 85 ? Theme.error : sc.ringColor
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.ds(14)
        spacing: Theme.ds(8)

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: Theme.ds(184)
            spacing: Theme.ds(10)

            StatCard {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                icon: "󰻠"
                label: "CPU"
                accent: Theme.primary
                value: stats.cpu
                temp: stats.cpuTemp
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
                temp: stats.gpuTemp
                history: stats.gpuHistory
                maxSamples: stats.maxSamples
            }
        }

        // ── Perfiles de energía ─────────────────────────────────
        // Encabezado: nombre de la sección + qué hace el perfil activo
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.ds(14)
            Layout.leftMargin: Theme.ds(2)
            Layout.rightMargin: Theme.ds(2)
            spacing: Theme.ds(8)

            SectionLabel {
                text: Translations.t("powerProfileTip")
                font.pixelSize: Theme.dfs(9)
            }
            Item { Layout.fillWidth: true }
            Text {
                text: Translations.t(root.profileHintKeys[PowerProfile.current] ?? "")
                color: Theme.subtext
                font.pixelSize: Theme.dfs(10)
                font.family: Theme.fontFamily
                elide: Text.ElideRight
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: false
            Layout.preferredHeight: Theme.ds(36)
            Layout.minimumHeight: Theme.ds(36)
            Layout.maximumHeight: Theme.ds(36)
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
                                font.pixelSize: Theme.dfs(11)
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
                    Behavior on color { ColorAnimation { duration: Theme.animDuration(180) } }
                    Behavior on border.color { ColorAnimation { duration: Theme.animDuration(180) } }
                    scale: pm.pressed ? 0.96 : (hovered ? 1.02 : 1.0)
                    Behavior on scale { NumberAnimation { duration: Theme.animDuration(150); easing.type: Easing.OutBack } }

                    // Brillo superior del perfil activo
                    Rectangle {
                        anchors.fill: parent
                        radius: pbtn.radius
                        opacity: pbtn.sel ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Theme.animDuration(200) } }
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
                            Behavior on color { ColorAnimation { duration: Theme.animDuration(180) } }
                            Text {
                                anchors.centerIn: parent
                                text: pbtn.modelData.icon
                                color: pbtn.sel ? Theme.textOnPrimary : Theme.primary
                                font.pixelSize: Theme.dfs(12)
                                font.family: Theme.monoFamily
                                Behavior on color { ColorAnimation { duration: Theme.animDuration(180) } }
                            }
                        }
                        Text {
                            text: Translations.t(pbtn.modelData.labelKey)
                            // Nunca más ancho que el botón (idiomas largos)
                            Layout.maximumWidth: Math.max(Theme.ds(20), pbtn.width - Theme.ds(22) - Theme.ds(6) - Theme.ds(16))
                            elide: Text.ElideRight
                            color: pbtn.sel ? Theme.textOnPrimary : Theme.text
                            font.pixelSize: Theme.dfs(11)
                            font.bold: pbtn.sel
                            font.family: Theme.fontFamily
                            Behavior on color { ColorAnimation { duration: Theme.animDuration(180) } }
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
