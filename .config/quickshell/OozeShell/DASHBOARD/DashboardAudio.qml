import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import "../COMMON"
import "../LANG"
import "../AUDIO"
import "../BRIGHTNESS"

// DashboardAudio — el panel de audio "normal" (AUDIO/AudioMenu.qml) con sus
// tres pestañas SALIDA / ENTRADA / MIXER, reacomodado para el dock: pestañas
// arriba, el slider fijo debajo y la lista (dispositivos o apps) con scroll
// en el resto del alto. Mismo backend (AudioBackend).
Item {
    id: root
    readonly property int preferredWidth: Theme.ds(460)
    readonly property int preferredHeight: Theme.ds(268)
    // 0 = Salida, 1 = Entrada, 2 = Mixer (apps). Siempre abre en Salida.
    property int tab: 0

    Component.onCompleted: {
        AudioBackend.menuWatch = true
        BrightnessBackend.watch = true
    }
    Component.onDestruction: {
        AudioBackend.menuWatch = false
        BrightnessBackend.watch = false
    }

    // ── Slider reutilizable (salida / entrada / apps) ───────────
    component VolumeRow: RowLayout {
        id: volRow
        Layout.fillWidth: true
        spacing: Theme.ds(10)

        property string icon: ""
        property real value: 0
        property bool muted: false
        property color activeColor: Theme.primary

        signal iconClicked()
        // (no llamarla "valueChanged": QML ya genera esa señal por `value`)
        signal moved(real v)
        signal committed()

        SkinRect {
            Layout.preferredWidth: Theme.ds(28)
            Layout.preferredHeight: Theme.ds(28)
            radius: Theme.ds(14)
            notch: 3
            color: iconArea.containsMouse ? Theme.surfaceHigh : Theme.surface
            Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }

            Text {
                anchors.centerIn: parent
                text: volRow.icon
                color: volRow.muted ? Theme.subtext : volRow.activeColor
                font.pixelSize: Theme.dfs(14)
                font.family: Theme.monoFamily
            }
            MouseArea {
                id: iconArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: volRow.iconClicked()
            }
        }

        Item {
            id: slider
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.ds(28)
            readonly property bool grabbed: sliderArea.containsMouse || sliderArea.pressed

            // CoOzey: barra de bloques (el arrastre lo sigue haciendo sliderArea)
            PixelBar {
                visible: Theme.cozy
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: Math.max(12, Theme.ds(16))
                ratio: volRow.value
                colorA: Theme.mix(volRow.muted ? Theme.subtext : volRow.activeColor, Theme.bg, 0.40)
                colorB: volRow.muted ? Theme.subtext : volRow.activeColor
            }

            Rectangle {
                id: track
                visible: !Theme.cozy
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: slider.grabbed ? 8 : 6
                radius: height / 2
                color: Theme.surfaceHigh
                Behavior on height { NumberAnimation { duration: Theme.animDuration(100) } }

                Rectangle {
                    width: track.width * Math.max(0, Math.min(1, volRow.value))
                    height: parent.height
                    radius: parent.radius
                    color: volRow.muted ? Theme.subtext : volRow.activeColor
                    Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
                }
                Rectangle {
                    x: track.width * Math.max(0, Math.min(1, volRow.value)) - width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: slider.grabbed ? 14 : 0
                    height: width
                    radius: width / 2
                    color: Theme.text
                    Behavior on width { NumberAnimation { duration: Theme.animDuration(100) } }
                }
            }

            MouseArea {
                id: sliderArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                function setFrom(mx) { volRow.moved(Math.max(0, Math.min(1, mx / width))) }
                onPressed: mouse => setFrom(mouse.x)
                onPositionChanged: mouse => { if (pressed) setFrom(mouse.x) }
                onReleased: volRow.committed()
                onCanceled: volRow.committed()
                onWheel: wheel => {
                    volRow.moved(volRow.value + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
                    volRow.committed()
                }
            }
        }

        Text {
            Layout.preferredWidth: Theme.ds(36)
            horizontalAlignment: Text.AlignRight
            text: Math.round(volRow.value * 100) + "%"
            color: volRow.muted ? Theme.subtext : Theme.text
            font.pixelSize: Theme.dfs(11)
            font.bold: true
            font.family: Theme.fontFamily
        }
    }

    // ── Fila de dispositivo (sink / source) ─────────────────────
    component DeviceRow: SkinRect {
        id: devRow
        required property var modelData
        signal picked()

        width: ListView.view ? ListView.view.width : 200
        height: Theme.ds(34)
        radius: Theme.ds(10)
        notch: 3
        // CoOzey: el dispositivo activo lleva el contorno del color primario
        inkColor: modelData.active ? Theme.primary : Theme.ink
        color: modelData.active ? Theme.surfaceHigh
             : (devArea.containsMouse ? Theme.surface : "transparent")
        Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }

        RowLayout {
            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
            spacing: Theme.ds(8)

            Text {
                text: devRow.modelData.active ? "󰄬" : "󰝛"
                color: devRow.modelData.active ? Theme.primary : Theme.subtext
                font.pixelSize: Theme.dfs(13)
                font.family: Theme.monoFamily
            }
            Text {
                Layout.fillWidth: true
                text: devRow.modelData.name
                color: Theme.text
                font.pixelSize: Theme.dfs(11)
                elide: Text.ElideRight
                font.family: Theme.fontFamily
            }
            Text {
                visible: devRow.modelData.muted
                text: "󰝟"
                color: Theme.subtext
                font.pixelSize: Theme.dfs(11)
                font.family: Theme.monoFamily
            }
            Text {
                text: Math.round(devRow.modelData.volume * 100) + "%"
                color: Theme.subtext
                font.pixelSize: Theme.dfs(10)
                font.family: Theme.fontFamily
            }
        }

        MouseArea {
            id: devArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: devRow.picked()
        }
    }

    // Texto gris centrado ("sin dispositivos" / "sin apps")
    component EmptyHint: Text {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 6
        color: Theme.subtext
        font.pixelSize: Theme.dfs(11)
        font.family: Theme.fontFamily
    }

    component SmallLabel: Text {
        color: Theme.subtext
        font.pixelSize: Theme.dfs(10)
        font.family: Theme.fontFamily
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.ds(14)
        spacing: Theme.ds(10)

        // ── Pestañas: Salida | Entrada | Mixer ──────────────────
        SkinRect {
            id: tabBar
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.ds(34)
            radius: Theme.ds(12)
            color: Theme.surface

            readonly property real segW: (width - 6) / 3

            SkinRect {
                x: 3 + root.tab * tabBar.segW
                y: 3
                width: tabBar.segW
                height: tabBar.height - 6
                radius: Theme.ds(9)
                notch: 3
                color: Theme.primary
                Behavior on x { NumberAnimation { duration: Theme.animDuration(180); easing.type: Easing.OutCubic } }
            }

            Row {
                x: 3
                y: 3

                Repeater {
                    model: 3

                    delegate: Item {
                        id: seg
                        required property int index
                        readonly property bool current: root.tab === seg.index

                        width: tabBar.segW
                        height: tabBar.height - 6
                        clip: true

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.ds(6)
                            anchors.rightMargin: Theme.ds(6)
                            spacing: Theme.ds(4)

                            Text {
                                text: seg.index === 0 ? AudioBackend.icon
                                    : seg.index === 1 ? AudioBackend.micIcon
                                    : "󰀻"
                                color: seg.current ? Theme.textOnPrimary : Theme.subtext
                                font.pixelSize: Theme.dfs(13)
                                font.family: Theme.monoFamily
                                Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: seg.index === 0 ? Translations.t("audioOutputTab")
                                    : seg.index === 1 ? Translations.t("audioInputTab")
                                    : Translations.t("audioMixerTab")
                                color: seg.current ? Theme.textOnPrimary : Theme.subtext
                                font.pixelSize: Theme.dfs(11)
                                font.bold: true
                                font.family: Theme.fontFamily
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.tab = seg.index
                        }
                    }
                }
            }
        }

        // ── Pestaña SALIDA ──────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Theme.ds(8)
            visible: root.tab === 0

            // Brillo de pantalla (solo si hay backlight controlable)
            VolumeRow {
                visible: BrightnessBackend.available
                icon: BrightnessBackend.brightness < 0.5 ? "󰃞" : "󰃟"
                value: BrightnessBackend.brightness
                onMoved: v => BrightnessBackend.setBrightness(v)
                onCommitted: BrightnessBackend.commit()
            }

            VolumeRow {
                icon: AudioBackend.icon
                value: AudioBackend.volume
                muted: AudioBackend.muted
                onIconClicked: AudioBackend.toggleMuteOsd()
                onMoved: v => AudioBackend.setVolume(v)
                onCommitted: AudioBackend.commit()
            }

            SmallLabel { text: Translations.t("audioOutputsLabel") }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: AudioBackend.sinks.length > 0
                clip: true
                spacing: Theme.ds(3)
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height
                model: AudioBackend.sinks
                delegate: DeviceRow {
                    onPicked: AudioBackend.setDefaultSink(modelData.id)
                }
            }
            EmptyHint {
                visible: AudioBackend.sinks.length === 0
                text: Translations.t("audioNoDevices")
            }
            Item { Layout.fillHeight: true; visible: AudioBackend.sinks.length === 0 }
        }

        // ── Pestaña ENTRADA (micrófono) ─────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Theme.ds(8)
            visible: root.tab === 1

            VolumeRow {
                icon: AudioBackend.micIcon
                value: AudioBackend.micVolume
                muted: AudioBackend.micMuted
                onIconClicked: AudioBackend.toggleMicMuteOsd()
                onMoved: v => AudioBackend.setMicVolume(v)
                onCommitted: AudioBackend.commitMic()
            }

            SmallLabel { text: Translations.t("audioInputsLabel") }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: AudioBackend.sources.length > 0
                clip: true
                spacing: Theme.ds(3)
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height
                model: AudioBackend.sources
                delegate: DeviceRow {
                    onPicked: AudioBackend.setDefaultSource(modelData.id)
                }
            }
            EmptyHint {
                visible: AudioBackend.sources.length === 0
                text: Translations.t("audioNoDevices")
            }
            Item { Layout.fillHeight: true; visible: AudioBackend.sources.length === 0 }
        }

        // ── Pestaña MIXER (volumen por app) ─────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Theme.ds(8)
            visible: root.tab === 2

            SmallLabel { text: Translations.t("audioMixerLabel") }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: AudioBackend.streamNodes.length > 0
                clip: true
                spacing: Theme.ds(8)
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height
                // ScriptModel hace diff: si aparece/desaparece una app, las
                // demás filas NO se recrean (no se corta un arrastre).
                model: ScriptModel { values: AudioBackend.streamNodes }
                delegate: ColumnLayout {
                    id: mixRow
                    required property var modelData
                    readonly property PwNode node: modelData
                    width: ListView.view ? ListView.view.width : 200
                    spacing: Theme.ds(3)

                    PwObjectTracker { objects: [mixRow.node] }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.ds(6)
                        AppIcon {
                            appId: AudioBackend.streamApp(mixRow.node)
                            size: 16
                        }
                        Text {
                            Layout.fillWidth: true
                            text: AudioBackend.streamLabel(mixRow.node)
                            color: Theme.text
                            font.pixelSize: Theme.dfs(11)
                            font.bold: true
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                        }
                        // La salida virtual (OozeAudio/pw-loopback) no es una app real
                        SkinRect {
                            visible: AudioBackend.isOozeLoopback(mixRow.node)
                            radius: Theme.ds(8)
                            notch: 2
                            color: Theme.surfaceHigh
                            implicitWidth: virtualTag.implicitWidth + Theme.ds(12)
                            implicitHeight: virtualTag.implicitHeight + 4
                            Text {
                                id: virtualTag
                                anchors.centerIn: parent
                                text: Translations.t("audioMixerVirtualTag")
                                color: Theme.subtext
                                font.pixelSize: Theme.dfs(9)
                                font.family: Theme.fontFamily
                            }
                        }
                    }

                    VolumeRow {
                        icon: (mixRow.node?.audio?.muted ?? false) ? "󰖁" : "󰕾"
                        value: mixRow.node?.audio?.volume ?? 0
                        muted: mixRow.node?.audio?.muted ?? false
                        onIconClicked: {
                            if (mixRow.node?.audio)
                                mixRow.node.audio.muted = !mixRow.node.audio.muted
                        }
                        onMoved: v => {
                            if (mixRow.node?.audio)
                                mixRow.node.audio.volume = Math.max(0, Math.min(1, v))
                        }
                    }
                }
            }
            EmptyHint {
                visible: AudioBackend.streamNodes.length === 0
                text: Translations.t("audioNoStreams")
            }
            Item { Layout.fillHeight: true; visible: AudioBackend.streamNodes.length === 0 }
        }
    }
}
