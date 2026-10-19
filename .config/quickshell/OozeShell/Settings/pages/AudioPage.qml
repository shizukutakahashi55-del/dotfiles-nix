// AudioPage — categoría "Audio": ajustes generales, enrutado por aplicación, salidas virtuales (OozeAudio) y volumen de las salidas físicas.

import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import ".."
import "../../COMMON"
import "../../Services/Lang"
import "../../Services/OozeAudio/data"
import "../../Services/Audio"

SettingsPage {
  id: page
  catId: "audio"

  property string newName: ""
  property string confirmDelete: ""
  property string error: ""

  Component.onCompleted: AudioService.refreshAll()

  Connections {
    target: AudioService
    function onCommandFailed(message) {
      page.error = message
      errorTimer.restart()
    }
  }
  Timer { id: errorTimer; interval: 5000; repeat: false; onTriggered: page.error = "" }

  Process {
    id: qpwgraphProc
    command: ["bash", "-c", "command -v qpwgraph >/dev/null 2>&1 && exec qpwgraph || echo '__ooze_qpwgraph_missing__' >&2"]
    stderr: StdioCollector {
      id: qpwgraphErr
      onStreamFinished: {
        if (qpwgraphErr.text.indexOf("__ooze_qpwgraph_missing__") !== -1) {
          page.error = Translations.t("advAudioQpwgraphMissing")
          errorTimer.restart()
        }
      }
    }
  }
  function openQpwgraph() {
    qpwgraphProc.running = false
    qpwgraphProc.running = true
  }

  function createOutput() {
    const n = page.newName.trim()
    if (n === "") return
    AudioService.createOutput(n)
    page.newName = ""
  }

  component AudioRow: SkinRect {
    id: row
    property string nodeId: ""
    property string nodeName: ""
    property string title: ""
    property string subtitle: ""
    property int volume: 100
    property bool muted: false
    property bool deletable: false
    property bool confirmingDelete: false

    property bool showConnections: false
    signal volumeMoved(real v)
    signal muteToggled()
    signal deleteRequested()

    Layout.fillWidth: true
    implicitHeight: rowContent.implicitHeight + 20
    radius: Theme.cozy ? 4 : 10
    color: Theme.bg
    clip: true

    ColumnLayout {
      id: rowContent
      anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
      spacing: 8

      RowLayout {
        Layout.fillWidth: true
        spacing: 10

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 0
          Text {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: row.title
            color: Theme.text
            font.bold: true
            font.pixelSize: Theme.sfs(12)
            font.family: Theme.fontFamily
          }
          Text {
            visible: row.subtitle !== ""
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: row.subtitle
            color: Theme.subtext
            font.pixelSize: Theme.sfs(10)
            font.family: Theme.fontFamily
          }
        }

        SkinRect {
          Layout.preferredWidth: 30
          Layout.preferredHeight: 26
          radius: 9
          color: row.muted ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.16)
               : (muteArea.containsMouse ? Theme.surfaceHigh : "transparent")
          Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }
          Text {
            anchors.centerIn: parent
            text: row.muted ? "󰝟" : "󰕾"
            color: row.muted ? Theme.error : Theme.subtext
            font.pixelSize: Theme.sfs(13)
            font.family: Theme.monoFamily
          }
          MouseArea {
            id: muteArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.muteToggled()
          }
        }

        SkinRect {
          visible: row.deletable
          Layout.preferredWidth: 30
          Layout.preferredHeight: 26
          radius: 9
          color: row.confirmingDelete
            ? Theme.error
            : (delArea.containsMouse ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.16) : "transparent")
          Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }
          Text {
            anchors.centerIn: parent
            text: row.confirmingDelete ? "󰄬" : "󰆴"
            color: row.confirmingDelete ? Theme.textOnPrimary : Theme.subtext
            font.pixelSize: Theme.sfs(12)
            font.family: Theme.monoFamily
          }
          MouseArea {
            id: delArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.deleteRequested()
          }
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: 10
        enabled: !row.muted
        opacity: row.muted ? 0.4 : 1
        Behavior on opacity { NumberAnimation { duration: Theme.animDuration(120) } }

        Text {
          Layout.fillWidth: true
          text: Translations.t("advAudioVolume")
          color: Theme.subtext
          font.pixelSize: Theme.sfs(11)
          font.family: Theme.fontFamily
        }

        NumberStepper {
          Layout.preferredWidth: 130
          value: row.volume
          min: 0; max: 150; step: 5
          suffix: "%"
          onEdited: v => row.volumeMoved(v)
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        Layout.topMargin: 2
        spacing: 4
        visible: row.showConnections && AudioService.destinationCandidates().length > 0

        Text {
          text: Translations.t("advAudioConnectTo")
          color: Theme.subtext
          font.pixelSize: Theme.sfs(10)
          font.family: Theme.fontFamily
        }

        Flow {
          Layout.fillWidth: true
          spacing: 6

          Repeater {
            model: AudioService.destinationCandidates()
            delegate: SkinRect {
              id: chip
              required property var modelData
              readonly property bool connected: AudioService.isConnected(row.nodeName, modelData.name)

              width: chipRow.implicitWidth + 18
              height: 26
              radius: 8
              color: chip.connected
                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)
                : (chipArea.containsMouse ? Theme.surfaceHigh : Theme.surface)
              border.width: chip.connected ? 1 : 0
              border.color: Theme.primary
              Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }

              RowLayout {
                id: chipRow
                anchors.centerIn: parent
                spacing: 5
                Text {
                  visible: chip.connected
                  text: "󰄬"
                  color: Theme.primary
                  font.pixelSize: Theme.sfs(10)
                  font.family: Theme.monoFamily
                }
                Text {
                  text: chip.modelData.desc
                  color: chip.connected ? Theme.text : Theme.subtext
                  font.pixelSize: Theme.sfs(10)
                  font.family: Theme.fontFamily
                }
              }

              MouseArea {
                id: chipArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: AudioService.setConnection(row.nodeName, chip.modelData.name, !chip.connected)
              }
            }
          }
        }
      }
    }
  }

  SettingsSection {
    titleKey: "setGeneral"

    SettingsNote {
      visible: page.error !== ""
      kind: "error"
      text: page.error
    }

    SettingsRow {
      titleKey: "advAudioOpenQpwgraph"

      SettingsBtn {
        icon: "󰏌"
        text: ""
        onClicked: page.openQpwgraph()
      }
      SettingsIconBtn {
        spinning: AudioService.busy
        onClicked: AudioService.refreshAll()
      }
    }

    SettingsRow {
      titleKey: "advAudioMonitorsToggleLabel"
      SettingsSwitch {
        checked: Theme.audioMonitorsCardEnabled
        onToggled: Theme.setAudioMonitorsCardEnabled(!Theme.audioMonitorsCardEnabled)
      }
    }
  }

  SettingsSection {
    titleKey: "advAudioAppsTitle"
    hintKey: "advAudioAppsHint"

    SettingsRow {
      stacked: true
      divider: false
      AppsRouting {}
    }
  }

  SettingsSection {
    titleKey: "advAudioOutputsTitle"
    hintKey: "advAudioOutputsHint"

    SettingsNote {
      kind: "warn"
      text: "󰀦  " + Translations.t("advAudioVirtualWarning")
    }

    SettingsRow {
      titleKey: "advAudioCreate"
      stacked: true

      SettingsField {
        id: newField
        placeholder: Translations.t("advAudioNewOutputPlaceholder")
        value: page.newName

        Connections {
          target: newField.input
          function onTextChanged() { page.newName = newField.input.text }
          function onAccepted() { page.createOutput() }
        }
      }
      SettingsBtn {
        text: Translations.t("advAudioCreate")
        icon: "󰐕"
        primary: true
        enabled: !AudioService.busy && page.newName.trim() !== ""
        onClicked: page.createOutput()
      }
    }

    SettingsRow {
      visible: AudioService.outputs.length > 0
      stacked: true

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 8

        Repeater {
          model: AudioService.outputs
          delegate: AudioRow {
            required property var modelData
            nodeId: modelData.id
            nodeName: modelData.name
            title: modelData.desc
            subtitle: modelData.name
            volume: modelData.volume
            muted: modelData.muted
            deletable: true
            showConnections: true
            confirmingDelete: page.confirmDelete === modelData.name
            onVolumeMoved: v => AudioService.setVolume("outputs", modelData.id, v)
            onMuteToggled: AudioService.setMute("outputs", modelData.id, !modelData.muted)
            onDeleteRequested: {
              if (page.confirmDelete === modelData.name) {
                AudioService.deleteOutput(modelData.desc)
                page.confirmDelete = ""
              } else {
                page.confirmDelete = modelData.name
              }
            }
          }
        }
      }
    }

    SettingsNote {
      visible: AudioService.outputs.length === 0
      text: Translations.t("advAudioNoOutputs")
    }
  }

  SettingsSection {
    visible: Theme.audioMonitorsCardEnabled
    titleKey: "advAudioMonitorsTitle"
    hintKey: "advAudioMonitorsHint"

    SettingsRow {
      visible: AudioService.destinationCandidates().length > 0
      stacked: true

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 8

        Repeater {
          model: AudioService.destinationCandidates()
          delegate: AudioRow {
            required property var modelData
            nodeId: modelData.id
            title: modelData.desc
            subtitle: modelData.name
            volume: modelData.volume
            muted: modelData.muted
            deletable: false
            onVolumeMoved: v => AudioService.setVolume("sinks", modelData.id, v)
            onMuteToggled: AudioService.setMute("sinks", modelData.id, !modelData.muted)
          }
        }
      }
    }

    SettingsNote {
      visible: AudioService.destinationCandidates().length === 0
      text: Translations.t("advAudioNoMonitors")
    }
  }
}
