// AudioMenu — panel de audio con tres pestañas: SALIDA, ENTRADA y MIXER.
// ── Mixer ──────────────────────────────────────────────────────────
// Una fila por app con audio activo (AudioBackend.streamNodes: nodos
// PipeWire "Stream/Output/Audio" vía Quickshell.Services.Pipewire), cada
// una con su propio slider de volumen y mute — el volumen que SÍ es
// específico de esa app.

import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import "../COMMON"
import "../LANG"
import "../AUDIO"
import "../BRIGHTNESS"

Item {
  id: root

  property bool open: false
  property string targetScreen: ""
  signal closeRequested()

  property int cardWidth: 380
  property int edgeMargin: 10
  readonly property int pad: 18

  // Pestaña activa: 0 = Salida, 1 = Entrada, 2 = Mixer (apps)
  property int tab: 0

  onOpenChanged: {
    AudioBackend.menuWatch = root.open
    BrightnessBackend.watch = root.open
    // Siempre se abre en Salida (lo más usado); no "recuerda" el mic
    if (root.open) root.tab = 0
  }

  // ── Slider reutilizable (salida / entrada) ──────────────────────
  component VolumeRow: RowLayout {
    id: volRow
    Layout.fillWidth: true
    spacing: 10

    property string icon: ""
    property real value: 0
    property bool muted: false
    property color activeColor: Theme.primary

    signal iconClicked()

    signal moved(real v)
    signal committed()

    SkinRect {
      Layout.preferredWidth: 30
      Layout.preferredHeight: 30
      radius: 15
      color: iconArea.containsMouse ? Theme.surfaceHigh : Theme.surface
      Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }

      Text {
        anchors.centerIn: parent
        text: volRow.icon
        color: volRow.muted ? Theme.subtext : volRow.activeColor
        font.pixelSize: Theme.fs(15)
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
      Layout.preferredHeight: 30

      readonly property bool grabbed: sliderArea.containsMouse || sliderArea.pressed

      PixelBar {

        visible: Theme.cozy

        anchors.verticalCenter: parent.verticalCenter

        width: parent.width

        height: 16

        ratio: volRow.value

        colorA: Theme.mix((volRow.muted ? Theme.subtext : volRow.activeColor), Theme.bg, 0.40)

        colorB: (volRow.muted ? Theme.subtext : volRow.activeColor)

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
          width: track.width * volRow.value
          height: parent.height
          radius: parent.radius
          color: volRow.muted ? Theme.subtext : volRow.activeColor
          Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
        }

        Rectangle {
          x: track.width * volRow.value - width / 2
          anchors.verticalCenter: parent.verticalCenter
          width: slider.grabbed ? 16 : 0
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

        function setFrom(mx) { volRow.moved(mx / width) }

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
      Layout.preferredWidth: 38
      horizontalAlignment: Text.AlignRight
      text: Math.round(volRow.value * 100) + "%"
      color: volRow.muted ? Theme.subtext : Theme.text
      font.pixelSize: Theme.fs(12)
      font.bold: true
      font.family: Theme.fontFamily
    }
  }

  // ── Fila de dispositivo (sink / source) ─────────────────────────
  component DeviceRow: SkinRect {
    id: devRow
    required property var modelData

    Layout.fillWidth: true
    Layout.preferredHeight: 38
    radius: 10
    color: modelData.active ? Theme.surfaceHigh : (devArea.containsMouse ? Theme.surface : "transparent")
    Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }

    signal picked()

    RowLayout {
      anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
      spacing: 8

      Text {
        text: devRow.modelData.active ? "󰄬" : "󰝛"
        color: devRow.modelData.active ? Theme.primary : Theme.subtext
        font.pixelSize: Theme.fs(13)
        font.family: Theme.monoFamily
      }
      Text {
        Layout.fillWidth: true
        text: devRow.modelData.name
        color: Theme.text
        font.pixelSize: Theme.fs(11)
        elide: Text.ElideRight
        font.family: Theme.fontFamily
      }
      Text {
        visible: devRow.modelData.muted
        text: "󰝟"
        color: Theme.subtext
        font.pixelSize: Theme.fs(11)
        font.family: Theme.monoFamily
      }
      Text {
        text: Math.round(devRow.modelData.volume * 100) + "%"
        color: Theme.subtext
        font.pixelSize: Theme.fs(10)
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

  FusedWindow {
    active: root.open || panel.shown
    targetScreen: root.targetScreen
    namespace: "oozeshell-audio"
    onCloseRequested: root.closeRequested()

    FusedPanel {
      id: panel

      open: root.open
      panelWidth: root.cardWidth
      contentHeight: col.implicitHeight + root.pad * 2

      // Cuelga de la barra, del lado de su botón (derecha si es horizontal,
      // abajo si es vertical). FusedPanel se coloca solo según Theme.barPosition.
      align: "end"
      alignMargin: root.edgeMargin + Theme.barEdge + Theme.frameSideArm

      ColumnLayout {
        id: col
        x: root.pad
        y: root.pad
        width: parent.width - root.pad * 2
        spacing: 14

        // ── Título ────────────────────────────────────────────
        RowLayout {
          Layout.fillWidth: true
          spacing: 10
          Text {
            text: AudioBackend.icon
            color: Theme.primary
            font.pixelSize: Theme.fs(20)
            font.family: Theme.monoFamily
          }
          Text {
            text: Translations.t("audioTitle")
            color: Theme.text
            font.bold: true
            font.pixelSize: Theme.fs(16)
            font.family: Theme.fontFamily
          }
          Item { Layout.fillWidth: true }
        }

        // ── Pestañas: Salida | Entrada | Mixer ────────────────
        // Un "resaltador" (primary) que se desliza bajo la pestaña activa
        SkinRect {
          id: tabBar
          Layout.fillWidth: true
          Layout.preferredHeight: 38
          radius: 13
          color: Theme.surface

          readonly property real segW: (width - 6) / 3

          SkinRect {
            x: 3 + root.tab * tabBar.segW
            y: 3
            width: tabBar.segW
            height: tabBar.height - 6
            radius: 10
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
                  anchors.leftMargin: 6
                  anchors.rightMargin: 6
                  spacing: 4

                  Text {
                    text: seg.index === 0 ? AudioBackend.icon
                        : seg.index === 1 ? AudioBackend.micIcon
                        : "󰀻"
                    color: seg.current ? Theme.textOnPrimary : Theme.subtext
                    font.pixelSize: Theme.fs(14)
                    font.family: Theme.monoFamily
                    Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
                  }
                  Text {
                    Layout.fillWidth: true
                    text: seg.index === 0 ? Translations.t("audioOutputTab")
                        : seg.index === 1 ? Translations.t("audioInputTab")
                        : Translations.t("audioMixerTab")
                    color: seg.current ? Theme.textOnPrimary : Theme.subtext
                    font.pixelSize: Theme.fs(12)
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

        // ── Pestaña SALIDA ────────────────────────────────────
        ColumnLayout {
          Layout.fillWidth: true
          spacing: 12
          visible: root.tab === 0

          // Brillo de pantalla (brightnessctl). Arriba del volumen a
          // propósito: es lo primero que se ajusta al abrir el panel.
          // No se muestra si no hay backlight controlable (de escritorio).
          VolumeRow {
            visible: BrightnessBackend.available
            icon: BrightnessBackend.brightness < 0.5 ? "󰃞" : "󰃟"
            value: BrightnessBackend.brightness
            muted: false
            activeColor: Theme.primary
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

          Text {
            text: Translations.t("audioOutputsLabel")
            color: Theme.subtext
            font.pixelSize: Theme.fs(10)
            font.family: Theme.fontFamily
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            visible: AudioBackend.sinks.length > 0

            Repeater {
              model: AudioBackend.sinks
              // `modelData` lo completa el propio Repeater (es una
              // `required property` de DeviceRow)
              delegate: DeviceRow {
                onPicked: AudioBackend.setDefaultSink(modelData.id)
              }
            }
          }

          Text {
            visible: AudioBackend.sinks.length === 0
            Layout.alignment: Qt.AlignHCenter
            text: Translations.t("audioNoDevices")
            color: Theme.subtext
            font.pixelSize: Theme.fs(11)
            font.family: Theme.fontFamily
          }
        }

        // ── Pestaña ENTRADA (micrófono) ───────────────────────
        ColumnLayout {
          Layout.fillWidth: true
          spacing: 12
          visible: root.tab === 1

          VolumeRow {
            icon: AudioBackend.micIcon
            value: AudioBackend.micVolume
            muted: AudioBackend.micMuted
            onIconClicked: AudioBackend.toggleMicMuteOsd()
            onMoved: v => AudioBackend.setMicVolume(v)
            onCommitted: AudioBackend.commitMic()
          }

          Text {
            text: Translations.t("audioInputsLabel")
            color: Theme.subtext
            font.pixelSize: Theme.fs(10)
            font.family: Theme.fontFamily
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            visible: AudioBackend.sources.length > 0

            Repeater {
              model: AudioBackend.sources
              delegate: DeviceRow {
                onPicked: AudioBackend.setDefaultSource(modelData.id)
              }
            }
          }

          Text {
            visible: AudioBackend.sources.length === 0
            Layout.alignment: Qt.AlignHCenter
            text: Translations.t("audioNoDevices")
            color: Theme.subtext
            font.pixelSize: Theme.fs(11)
            font.family: Theme.fontFamily
          }
        }

        // ── Pestaña MIXER (volumen por app) ───────────────────
        // Una fila por stream activo (AudioBackend.streamNodes): ícono de la
        // app + su propio slider de volumen/mute, sin tocar el volumen
        // general del dispositivo.
        ColumnLayout {
          Layout.fillWidth: true
          spacing: 12
          visible: root.tab === 2

          Text {
            text: Translations.t("audioMixerLabel")
            color: Theme.subtext
            font.pixelSize: Theme.fs(10)
            font.family: Theme.fontFamily
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 10
            visible: AudioBackend.streamNodes.length > 0

            Repeater {
              // ScriptModel hace diff: si aparece/desaparece una app, las
              // demás filas NO se recrean (no se corta un arrastre).
              model: ScriptModel { values: AudioBackend.streamNodes }
              delegate: ColumnLayout {
                id: mixRow
                required property var modelData
                readonly property PwNode node: modelData
                Layout.fillWidth: true
                spacing: 4

                // Garantiza que este nodo esté bindeado (audio/properties)
                PwObjectTracker { objects: [mixRow.node] }

                RowLayout {
                  Layout.fillWidth: true
                  spacing: 6
                  AppIcon {
                    appId: AudioBackend.streamApp(mixRow.node)
                    size: 16
                  }
                  Text {
                    Layout.fillWidth: true
                    text: AudioBackend.streamLabel(mixRow.node)
                    color: Theme.text
                    font.pixelSize: Theme.fs(11)
                    font.bold: true
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                  }
                  // Etiqueta discreta para no confundir la salida virtual
                  // (OozeAudio/pw-loopback) con una app real reproduciendo
                  SkinRect {
                    visible: AudioBackend.isOozeLoopback(mixRow.node)
                    radius: 8
                    color: Theme.surfaceHigh
                    implicitWidth: virtualTag.implicitWidth + 12
                    implicitHeight: virtualTag.implicitHeight + 4
                    Text {
                      id: virtualTag
                      anchors.centerIn: parent
                      text: Translations.t("audioMixerVirtualTag")
                      color: Theme.subtext
                      font.pixelSize: Theme.fs(9)
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
          }

          Text {
            visible: AudioBackend.streamNodes.length === 0
            Layout.alignment: Qt.AlignHCenter
            text: Translations.t("audioNoStreams")
            color: Theme.subtext
            font.pixelSize: Theme.fs(11)
            font.family: Theme.fontFamily
          }
        }
      }
    }
  }
}
