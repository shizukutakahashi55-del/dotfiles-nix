import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../COMMON"
import "../LANG"
import "../MPRIS"

// DashboardMpris — reproductor del dock. Usa MPRIS/MprisBackend.qml
Item {
    id: root
    readonly property int preferredWidth: Theme.ds(460)
    readonly property bool hasPlayer: MprisBackend.activePlayers.length > 0
    readonly property bool playing: MprisBackend.currentStatus === "Playing"
    readonly property bool hasArt: art.status === Image.Ready

    function withAlpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    // ── Vida útil: solo sondea/escucha mientras esta sección existe ──
    Component.onCompleted: {
        MprisBackend.setWanted("dashboard", true)
        AudioLevels.setWanted("dashboardMpris", root.playing)
    }
    Component.onDestruction: {
        MprisBackend.setWanted("dashboard", false)
        AudioLevels.setWanted("dashboardMpris", false)
    }
    onPlayingChanged: AudioLevels.setWanted("dashboardMpris", root.playing)

    // ── Seek ────────────────────────────────────────────────────
    property bool seeking: false
    property real seekRatio: 0
    readonly property real shownRatio: root.seeking ? root.seekRatio : MprisBackend.progressRatio
    readonly property int shownPosition: root.seeking
        ? Math.round(root.seekRatio * MprisBackend.currentLength) : MprisBackend.currentPosition

    // ── Espectro ────────────────────────────────────────────────
    readonly property bool liveAudio: AudioLevels.available && !AudioLevels.silent
    property real phase: 0
    NumberAnimation on phase {
        from: 0; to: 1; duration: Theme.animDuration(2600); loops: Animation.Infinite
        running: (root.playing && !root.liveAudio && root.hasPlayer) && Theme.uiAnimationsEnabled
    }
    function level(i) {
        if (!root.playing) return 0.05
        if (root.liveAudio) return Math.max(0.06, AudioLevels.bands[i] || 0)
        return 0.10 + 0.20 * (0.5 + 0.5 * Math.sin(root.phase * 6.2832 + i * 0.55))
    }

    // ════════════════════════════════════════════════════════════
    // TARJETA
    // ════════════════════════════════════════════════════════════
    Item {
        id: card
        anchors.fill: parent
        anchors.margins: Theme.ds(10)

        // ── CoOzey: marco pixel (sombra dura, tinta, degradado cálido) ──
        CozyBox {
            visible: Theme.cozy
            anchors.fill: parent
            anchors.bottomMargin: Theme.shadowY
            notch: 4
            dither: true
            fillTop: Theme.mix(Theme.surface, Theme.primary, 0.22)
            fillBottom: Theme.surface
        }

        // ── Fondo (recortado con esquinas redondeadas) ──
        Item {
            id: bg
            anchors.fill: parent
            anchors.margins: Theme.cozy ? 2 : 0
            anchors.bottomMargin: Theme.cozy ? 2 + Theme.shadowY : 0
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: cardMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1.0
            }

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: root.withAlpha(Theme.primary, 0.22) }
                    GradientStop { position: 1.0; color: Theme.surface }
                }
            }

            // Portada difuminada
            Image {
                id: art
                anchors.fill: parent
                source: MprisBackend.currentArt
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                // El fondo de la tarjeta no necesita la resolución original
                // de la carátula; limitarlo evita texturas enormes en GPU.
                sourceSize: Qt.size(640, 360)
                opacity: root.hasArt ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.animDuration(400) } }
                layer.enabled: root.hasArt
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blur: 1.0
                    blurMax: 48
                    saturation: 0.25
                    brightness: -0.08
                    autoPaddingEnabled: false
                }
            }

            // Velo para que el texto siempre se lea
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: root.withAlpha(Theme.bg, 0.55) }
                    GradientStop { position: 1.0; color: root.withAlpha(Theme.bg, 0.86) }
                }
            }

            // CoOzey: espectro de LEDs (celdas apiladas) en vez de barras redondas
            Row {
                id: ledSpectrum
                visible: Theme.cozy
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 6
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 3
                readonly property int n: 24
                readonly property int barW: Math.max(3, Math.floor((bg.width - 28 - (n - 1) * spacing) / n))

                Repeater {
                    model: 24
                    delegate: PixelLevels {
                        required property int index
                        width: ledSpectrum.barW
                        height: Theme.ds(48)
                        cells: 8
                        level: root.level(index)
                        color: Theme.primary
                        litOpacity: root.playing ? 0.40 : 0.16
                    }
                }
            }

            // Espectro al pie
            Row {
                id: spectrum
                visible: !Theme.cozy
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.ds(3)
                readonly property int n: 24
                readonly property real barW: (bg.width - 20 - (n - 1) * spacing) / n

                Repeater {
                    model: 24
                    delegate: Rectangle {
                        required property int index
                        width: spectrum.barW
                        height: Theme.ds(4) + root.level(index) * Theme.ds(64)
                        radius: width / 2
                        color: Theme.primary
                        opacity: root.playing ? 0.30 : 0.12
                        Behavior on height { NumberAnimation { duration: Theme.animDuration(90) } }
                        Behavior on opacity { NumberAnimation { duration: Theme.animDuration(300) } }
                    }
                }
            }

            // Filo de luz arriba
            Rectangle {
                visible: !Theme.cozy
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: root.withAlpha(Theme.primary, 0.25)
            }
        }
        Item {
            id: cardMask
            anchors.fill: bg
            layer.enabled: true
            visible: false
            Rectangle { visible: !Theme.cozy; anchors.fill: parent; radius: Theme.ds(18); color: "black" }
            NotchRect { visible: Theme.cozy; anchors.fill: parent; topColor: "black"; notch: 4 }
        }
        // Marco fino
        Rectangle {
            visible: !Theme.cozy
            anchors.fill: parent
            radius: Theme.ds(18)
            color: "transparent"
            border.width: Theme.bw1
            border.color: root.withAlpha(Theme.primary, root.playing ? 0.35 : 0.18)
            Behavior on border.color { ColorAnimation { duration: Theme.animDuration(300) } }
        }

        // ── Sin reproducción ───────────────────────────────────
        ColumnLayout {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -14
            visible: !root.hasPlayer
            spacing: Theme.ds(10)

            Item {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Theme.ds(84)
                Layout.preferredHeight: Theme.ds(84)
                Rectangle {
                    anchors.centerIn: parent
                    width: Theme.ds(84); height: Theme.ds(84); radius: Theme.cozy ? 4 : Theme.ds(42)
                    color: "transparent"
                    border.width: 2
                    border.color: root.withAlpha(Theme.primary, 0.14)
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: Theme.ds(62); height: Theme.ds(62); radius: Theme.cozy ? 4 : Theme.ds(31)
                    color: root.withAlpha(Theme.primary, 0.14)
                    border.width: Theme.bw1
                    border.color: Theme.cozy ? Theme.ink : root.withAlpha(Theme.primary, 0.40)
                    Text {
                        anchors.centerIn: parent
                        text: "󰝚"
                        color: Theme.primary
                        font.pixelSize: Theme.dfs(28)
                        font.family: Theme.monoFamily
                    }
                }
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: Translations.t("mprisNoPlaying")
                color: Theme.text
                font.pixelSize: Theme.dfs(14)
                font.bold: true
                font.family: Theme.fontFamily
            }
        }

        // ── Reproduciendo ──────────────────────────────────────
        RowLayout {
            anchors.fill: parent
            anchors.margins: Theme.ds(14)
            spacing: Theme.ds(16)
            visible: root.hasPlayer

            // Portada
            Item {
                Layout.preferredWidth: Theme.ds(136)
                Layout.preferredHeight: Theme.ds(136)
                Layout.alignment: Qt.AlignVCenter

                // CoOzey: sombra dura bajo la portada
                Rectangle {
                    visible: Theme.cozy
                    x: 3; y: 5
                    width: parent.width; height: parent.height
                    radius: 3
                    color: Theme.shadowInk
                }
                Rectangle {
                    id: halo
                    anchors.centerIn: parent
                    width: Theme.ds(150); height: Theme.ds(150); radius: Theme.cozy ? 4 : Theme.ds(26)
                    color: root.withAlpha(Theme.primary, root.playing ? 0.20 : 0.07)
                    Behavior on color { ColorAnimation { duration: Theme.animDuration(300) } }
                    SequentialAnimation on opacity {
                        running: root.playing && Theme.uiAnimationsEnabled
                        loops: Animation.Infinite
                        NumberAnimation { from: 0.5; to: 1.0; duration: Theme.animDuration(1100); easing.type: Easing.InOutSine }
                        NumberAnimation { from: 1.0; to: 0.5; duration: Theme.animDuration(1100); easing.type: Easing.InOutSine }
                        onRunningChanged: if (!running) halo.opacity = 1
                    }
                }

                Item {
                    id: coverBox
                    anchors.fill: parent
                    scale: Theme.cozy ? 1.0 : (coverMouse.pressed ? 0.97 : (coverMouse.containsMouse ? 1.02 : 1.0))
                    Behavior on scale { NumberAnimation { duration: Theme.animDuration(160); easing.type: Easing.OutBack } }
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: coverMask
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 1.0
                    }
                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: root.withAlpha(Theme.primary, 0.35) }
                            GradientStop { position: 1.0; color: Theme.surface }
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: !root.hasArt
                        text: "󰎆"
                        color: Theme.primary
                        font.pixelSize: Theme.dfs(48)
                        font.family: Theme.monoFamily
                    }
                    Image {
                        anchors.fill: parent
                        source: MprisBackend.currentArt
                        fillMode: Image.PreserveAspectCrop
                        visible: root.hasArt
                        asynchronous: true
                        // La portada se muestra ~136×136; 2× da margen para
                        // HiDPI sin conservar la resolución original.
                        sourceSize: Qt.size(272, 272)
                    }
                    // Velo de play/pausa al pasar el mouse
                    Rectangle {
                        anchors.fill: parent
                        color: root.withAlpha(Theme.bg, 0.45)
                        opacity: coverMouse.containsMouse ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Theme.animDuration(160) } }
                        Text {
                            anchors.centerIn: parent
                            text: root.playing ? "󰏤" : "󰐊"
                            color: Theme.text
                            font.pixelSize: Theme.dfs(34)
                            font.family: Theme.monoFamily
                        }
                    }
                }
                Item {
                    id: coverMask
                    anchors.fill: parent
                    layer.enabled: true
                    visible: false
                    Rectangle { anchors.fill: parent; radius: Theme.cozy ? 3 : Theme.ds(18); color: "black" }
                }
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.cozy ? 3 : Theme.ds(18)
                    color: "transparent"
                    border.width: Theme.cozy ? 3 : 1.5
                    border.color: Theme.cozy ? Theme.ink : root.withAlpha(Theme.primary, root.playing ? 0.55 : 0.28)
                    Behavior on border.color { ColorAnimation { duration: Theme.animDuration(300) } }
                }
                MouseArea {
                    id: coverMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: MprisBackend.runCtl(["play-pause"])
                }
            }

            // Información + controles
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Theme.ds(5)

                // Cabecera: estado + chip del player
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.ds(7)

                    Rectangle {
                        id: liveDot
                        Layout.preferredWidth: Theme.ds(7)
                        Layout.preferredHeight: Theme.ds(7)
                        radius: Theme.cozy ? 0 : Theme.ds(3.5)
                        color: Theme.primary
                        opacity: root.playing ? 1 : 0.35
                        SequentialAnimation on opacity {
                            running: root.playing && Theme.uiAnimationsEnabled
                            loops: Animation.Infinite
                            NumberAnimation { from: 1.0; to: 0.3; duration: Theme.animDuration(700); easing.type: Easing.InOutSine }
                            NumberAnimation { from: 0.3; to: 1.0; duration: Theme.animDuration(700); easing.type: Easing.InOutSine }
                            onRunningChanged: if (!running) liveDot.opacity = 0.35
                        }
                    }
                    Text {
                        text: Translations.t("mprisTitle")
                        color: Theme.subtext
                        font.pixelSize: Theme.dfs(9)
                        font.letterSpacing: 1
                        font.family: Theme.fontFamily
                    }

                    Item { Layout.fillWidth: true }

                    // Chip del player (clic = siguiente player)
                    Rectangle {
                        id: chip
                        readonly property bool multi: MprisBackend.activePlayers.length > 1
                        radius: Theme.cozy ? 4 : Theme.ds(10)
                        implicitHeight: Theme.ds(22)
                        implicitWidth: chipRow.implicitWidth + Theme.ds(16)
                        color: chipMouse.containsMouse && chip.multi
                            ? root.withAlpha(Theme.primary, 0.28) : root.withAlpha(Theme.primary, 0.14)
                        border.width: Theme.bw1
                        border.color: Theme.cozy ? Theme.ink : root.withAlpha(Theme.primary, 0.32)
                        Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }

                        RowLayout {
                            id: chipRow
                            anchors.centerIn: parent
                            spacing: Theme.ds(5)
                            Text {
                                text: {
                                    void MprisBackend.activePlayers
                                    void MprisBackend.activePlayerIndex
                                    return MprisBackend.playerIcon(MprisBackend.currentPlayer())
                                }
                                color: Theme.primary
                                font.pixelSize: Theme.dfs(11)
                                font.family: Theme.fontFamily
                            }
                            Text {
                                text: {
                                    void MprisBackend.activePlayers
                                    void MprisBackend.activePlayerIndex
                                    return MprisBackend.cleanPlayerName(MprisBackend.currentPlayer())
                                        + (chip.multi ? "  " + (MprisBackend.activePlayerIndex + 1)
                                                        + "/" + MprisBackend.activePlayers.length : "")
                                }
                                color: Theme.primary
                                font.pixelSize: Theme.dfs(9)
                                font.bold: true
                                font.family: Theme.fontFamily
                            }
                        }
                        MouseArea {
                            id: chipMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: chip.multi
                            cursorShape: chip.multi ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: MprisBackend.selectPlayer(MprisBackend.activePlayerIndex + 1)
                        }
                    }
                }

                Item { Layout.fillHeight: true; Layout.minimumHeight: Theme.ds(2) }

                // Título y artista
                Text {
                    Layout.fillWidth: true
                    text: MprisBackend.currentTitle !== "" ? MprisBackend.currentTitle
                                                           : Translations.t("mprisNoPlaying")
                    color: Theme.text
                    font.pixelSize: Theme.dfs(17)
                    font.bold: true
                    font.family: Theme.fontFamily
                    elide: Text.ElideRight
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.ds(6)
                    visible: MprisBackend.currentArtist !== ""
                    Text {
                        text: "󰠃"
                        color: Theme.primary
                        font.pixelSize: Theme.dfs(12)
                        font.family: Theme.monoFamily
                    }
                    Text {
                        Layout.fillWidth: true
                        text: MprisBackend.currentArtist
                        color: Theme.subtext
                        font.pixelSize: Theme.dfs(12)
                        font.family: Theme.fontFamily
                        elide: Text.ElideRight
                    }
                }

                // Progreso: clic o arrastre para saltar
                Item {
                    id: progress
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.ds(18)
                    Layout.topMargin: 2

                    PixelBar {
                        visible: Theme.cozy
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: Theme.ds(14)
                        ratio: root.shownRatio
                        cell: Theme.ds(6)
                        gap: 2
                    }
                    Rectangle {
                        id: trackBg
                        visible: !Theme.cozy
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: (seekMouse.containsMouse || root.seeking) ? 7 : 5
                        radius: height / 2
                        color: root.withAlpha(Theme.text, 0.14)
                        Behavior on height { NumberAnimation { duration: Theme.animDuration(120) } }

                        Rectangle {
                            width: Math.max(0, trackBg.width * root.shownRatio)
                            height: parent.height
                            radius: parent.radius
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: root.withAlpha(Theme.primary, 0.45) }
                                GradientStop { position: 1.0; color: Theme.primary }
                            }
                        }
                    }
                    Rectangle {
                        x: Math.max(0, Math.min(trackBg.width - width,
                             trackBg.width * root.shownRatio - width / 2))
                        anchors.verticalCenter: parent.verticalCenter
                        width: (seekMouse.containsMouse || root.seeking) ? 14 : 10
                        height: width
                        radius: width / 2
                        color: Theme.text
                        border.width: 2
                        border.color: Theme.primary
                        visible: !Theme.cozy && MprisBackend.currentLength > 0
                        Behavior on width { NumberAnimation { duration: Theme.animDuration(120) } }
                    }

                    MouseArea {
                        id: seekMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: MprisBackend.currentLength > 0
                        cursorShape: Qt.PointingHandCursor
                        function ratioAt(x) { return Math.max(0, Math.min(1, x / width)) }
                        onPressed: mouse => { root.seeking = true; root.seekRatio = ratioAt(mouse.x) }
                        onPositionChanged: mouse => { if (pressed) root.seekRatio = ratioAt(mouse.x) }
                        onReleased: {
                            const secs = (root.seekRatio * MprisBackend.currentLength / 1000000).toFixed(2)
                            MprisBackend.runCtl(["position", secs])
                            root.seeking = false
                        }
                        onCanceled: root.seeking = false
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: MprisBackend.formatTime(root.shownPosition)
                        color: Theme.subtext; font.pixelSize: Theme.dfs(9)
                        font.family: Theme.fontFamily
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: MprisBackend.formatTime(MprisBackend.currentLength)
                        color: Theme.subtext; font.pixelSize: Theme.dfs(9)
                        font.family: Theme.fontFamily
                    }
                }

                // Controles
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: Theme.ds(14)

                    component Ctl: Rectangle {
                        id: c
                        property string glyph: ""
                        property bool big: false
                        signal clicked()
                        visible: !Theme.cozy
                        Layout.preferredWidth: big ? 46 : 36
                        Layout.preferredHeight: big ? 46 : 36
                        Layout.alignment: Qt.AlignVCenter
                        radius: width / 2
                        color: big ? Theme.primary
                                   : (cm.containsMouse ? root.withAlpha(Theme.text, 0.18) : root.withAlpha(Theme.text, 0.09))
                        border.width: big ? 0 : Theme.bw1
                        border.color: cm.containsMouse ? root.withAlpha(Theme.primary, 0.55) : root.withAlpha(Theme.text, 0.10)
                        Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
                        Behavior on border.color { ColorAnimation { duration: Theme.animDuration(150) } }
                        scale: Theme.cozy ? 1.0 : (cm.pressed ? 0.9 : (cm.containsMouse ? 1.07 : 1.0))
                        Behavior on scale { NumberAnimation { duration: Theme.animDuration(140); easing.type: Easing.OutBack } }

                        Rectangle {
                            visible: c.big
                            z: -1
                            anchors.centerIn: parent
                            width: parent.width + 12; height: width; radius: width / 2
                            color: root.withAlpha(Theme.primary, root.playing ? 0.22 : 0.08)
                            Behavior on color { ColorAnimation { duration: Theme.animDuration(300) } }
                        }
                        Text {
                            anchors.centerIn: parent
                            text: c.glyph
                            color: c.big ? Theme.textOnPrimary : Theme.text
                            font.pixelSize: Theme.dfs(c.big ? 19 : 14)
                            font.family: Theme.monoFamily
                        }
                        MouseArea {
                            id: cm
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: c.clicked()
                        }
                    }

                    Ctl { glyph: "󰒮"; onClicked: MprisBackend.runCtl(["previous"]) }
                    Ctl {
                        big: true
                        glyph: root.playing ? "󰏤" : "󰐊"
                        onClicked: MprisBackend.runCtl(["play-pause"])
                    }
                    Ctl { glyph: "󰒭"; onClicked: MprisBackend.runCtl(["next"]) }

                    // CoOzey: mismos tres controles, versión "botón de juego"
                    component CCtl: CozyButton {
                        id: cc
                        property string glyph: ""
                        property bool big: false
                        visible: Theme.cozy
                        Layout.preferredWidth: big ? Theme.ds(56) : Theme.ds(42)
                        Layout.preferredHeight: (big ? Theme.ds(46) : Theme.ds(36)) + depth
                        Layout.alignment: Qt.AlignVCenter
                        face: big ? Theme.primary : Theme.surface
                        faceHover: big ? Theme.mix(Theme.primary, "#ffffff", 0.18) : Theme.surfaceHigh
                        active: big
                        Text {
                            anchors.centerIn: parent
                            text: cc.glyph
                            color: cc.big ? Theme.textOnPrimary : Theme.text
                            font.pixelSize: Theme.dfs(cc.big ? 20 : 15)
                            font.family: Theme.monoFamily
                        }
                    }
                    CCtl { glyph: "󰒮"; onClicked: MprisBackend.runCtl(["previous"]) }
                    CCtl {
                        big: true
                        glyph: root.playing ? "󰏤" : "󰐊"
                        onClicked: MprisBackend.runCtl(["play-pause"])
                    }
                    CCtl { glyph: "󰒭"; onClicked: MprisBackend.runCtl(["next"]) }
                }

                Item { Layout.fillHeight: true; Layout.minimumHeight: Theme.ds(2) }
            }
        }
    }
}
