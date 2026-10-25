// AppsRouting — sección "Aplicaciones": una fila por app que está sonando, con su volumen, mute y la salida por la que suena (el "on <dispositivo>" de

import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import "../../COMMON"
import "../Lang"

ColumnLayout {
  id: root

  Layout.fillWidth: true
  spacing: 10


  Component.onCompleted: AudioBackend.acquireWatch()
  Component.onDestruction: AudioBackend.releaseWatch()


  readonly property var appNodes:
    AudioBackend.streamNodes.filter(n => n && !AudioBackend.isOozeLoopback(n))


  readonly property var idleRules: {
    const active = {}
    for (const n of root.appNodes) active[AudioBackend.streamKey(n)] = true
    const out = []
    const rules = AudioBackend.appRules
    for (const k of Object.keys(rules))
      if (!active[k]) out.push({ key: k, sink: rules[k] })
    return out
  }

  function sinkLabel(name) {
    const list = AudioBackend.outputTargets
    for (let i = 0; i < list.length; i++)
      if (list[i].name === name) return list[i].desc
    return name
  }

  // ── Apps sonando ────────────────────────────────────────────────
  Repeater {
    model: ScriptModel { values: root.appNodes }

    delegate: SkinRect {
      id: card
      required property var modelData
      readonly property PwNode node: modelData

      Layout.fillWidth: true
      visible: card.node !== null
      implicitHeight: card.node !== null ? cardCol.implicitHeight + 20 : 0
      radius: 10
      color: Theme.glassCtlBg
      clip: true

      PwObjectTracker { objects: [card.node] }

      readonly property bool muted: card.node?.audio?.muted ?? false
      readonly property real vol: card.node?.audio?.volume ?? 0

      ColumnLayout {
        id: cardCol
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
        spacing: 8

        RowLayout {
          Layout.fillWidth: true
          spacing: 10

          AppIcon {
            appId: AudioBackend.streamApp(card.node)
            size: 20
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Text {
              Layout.fillWidth: true
              elide: Text.ElideRight
              text: AudioBackend.streamApp(card.node)
              color: Theme.text
              font.bold: true
              font.pixelSize: Theme.fs(12)
              font.family: Theme.fontFamily
            }
            Text {
              readonly property string media: AudioBackend.nodeProp(card.node, "media.name")
              visible: media !== ""
              Layout.fillWidth: true
              elide: Text.ElideRight
              text: media
              color: Theme.subtext
              font.pixelSize: Theme.fs(10)
              font.family: Theme.fontFamily
            }
          }

          Text {
            text: Math.round(card.vol * 100) + "%"
            color: card.muted ? Theme.subtext : Theme.text
            font.pixelSize: Theme.fs(11)
            font.bold: true
            font.family: Theme.fontFamily
          }

          SkinRect {
            Layout.preferredWidth: 30
            Layout.preferredHeight: 26
            radius: 9
            color: card.muted ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.16)
                 : (muteArea.containsMouse ? Theme.surfaceHigh : "transparent")
            Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }
            Text {
              anchors.centerIn: parent
              text: card.muted ? "󰝟" : "󰕾"
              color: card.muted ? Theme.error : Theme.subtext
              font.pixelSize: Theme.fs(13)
              font.family: Theme.monoFamily
            }
            MouseArea {
              id: muteArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: { if (card.node?.audio) card.node.audio.muted = !card.node.audio.muted }
            }
          }
        }

        // ── Slider de volumen de la app ──
        Item {
          Layout.fillWidth: true
          Layout.preferredHeight: 18
          opacity: card.muted ? 0.4 : 1

          Rectangle {
            id: track
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: sliderArea.containsMouse || sliderArea.pressed ? 8 : 6
            radius: height / 2
            color: Theme.surfaceHigh
            Behavior on height { NumberAnimation { duration: Theme.animDuration(100) } }

            Rectangle {
              width: track.width * Math.min(1, card.vol)
              height: parent.height
              radius: parent.radius
              color: Theme.primary
            }
          }

          MouseArea {
            id: sliderArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            function setFrom(mx) {
              if (card.node?.audio)
                card.node.audio.volume = Math.max(0, Math.min(1, mx / width))
            }
            onPressed: mouse => setFrom(mouse.x)
            onPositionChanged: mouse => { if (pressed) setFrom(mouse.x) }
            onWheel: wheel => {
              if (card.node?.audio)
                card.node.audio.volume = Math.max(0, Math.min(1,
                  card.vol + (wheel.angleDelta.y > 0 ? 0.05 : -0.05)))
            }
          }
        }

        // ── Salida de la app ──
        StreamOutputPicker {
          node: card.node
        }
      }
    }
  }

  Text {
    visible: root.appNodes.length === 0
    Layout.fillWidth: true
    wrapMode: Text.WordWrap
    text: Translations.t("audioNoStreams")
    color: Theme.subtext
    font.italic: true
    font.pixelSize: Theme.fs(11)
    font.family: Theme.fontFamily
  }

  // ── Reglas guardadas de apps que ahora no suenan ────────────────
  ColumnLayout {
    Layout.fillWidth: true
    visible: root.idleRules.length > 0
    spacing: 6

    Text {
      text: Translations.t("advAudioSavedRules")
      color: Theme.subtext
      font.pixelSize: Theme.fs(10)
      font.family: Theme.fontFamily
    }

    Repeater {
      model: root.idleRules

      delegate: SkinRect {
        id: rule
        required property var modelData

        Layout.fillWidth: true
        implicitHeight: 36
        radius: 10
        color: Theme.glassCtlBg

        RowLayout {
          anchors { fill: parent; leftMargin: 12; rightMargin: 6 }
          spacing: 8

          AppIcon { appId: AudioBackend.cleanAppName(rule.modelData.key); size: 16 }

          Text {
            text: AudioBackend.cleanAppName(rule.modelData.key)
            color: Theme.text
            font.bold: true
            font.pixelSize: Theme.fs(11)
            font.family: Theme.fontFamily
          }
          Text {
            text: "→"
            color: Theme.subtext
            font.pixelSize: Theme.fs(11)
            font.family: Theme.fontFamily
          }
          Text {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: root.sinkLabel(rule.modelData.sink)
            color: Theme.primary
            font.pixelSize: Theme.fs(11)
            font.family: Theme.fontFamily
          }

          SkinRect {
            Layout.preferredWidth: 28
            Layout.preferredHeight: 26
            radius: 9
            color: forgetArea.containsMouse ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.16) : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }
            Text {
              anchors.centerIn: parent
              text: "󰆴"
              color: Theme.subtext
              font.pixelSize: Theme.fs(12)
              font.family: Theme.monoFamily
            }
            MouseArea {
              id: forgetArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: AudioBackend.forgetRule(rule.modelData.key)
            }
          }
        }
      }
    }
  }
}
