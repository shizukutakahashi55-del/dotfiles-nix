import QtQuick
import QtQuick.Layouts
import "../COMMON"
import "../Services/Lang"
import "../Services/Notify"

ColumnLayout {
  id: sp

  property string soundFile: ""
  property int volume: 100
  property var defaults: []

  signal soundPicked(string path)
  signal volumeEdited(int v)

  readonly property var entries: [{ path: "", name: Translations.t("sndDefault"), user: false }].concat(AlertSound.library)

  Layout.fillWidth: true
  spacing: 0

  Component.onCompleted: AlertSound.refresh()

  Connections {
    target: AlertSound
    function onImported(path) { sp.soundPicked(path) }
  }

  // ─── Volumen ───────────────────────────────────────────────────
  SettingsRow {
    titleKey: "sndVolume"
    stacked: true

    RowLayout {
      Layout.fillWidth: true
      spacing: 8

      ScaleSlider {
        min: 0
        max: 100
        step: 5
        defaultValue: 100
        value: sp.volume
        onEdited: v => sp.volumeEdited(v)
      }
      SettingsBtn {
        icon: OozeIcons.volume
        text: Translations.t("sndTest")
        onClicked: AlertSound.play(sp.soundFile, sp.volume, sp.defaults)
      }
    }
  }

  // ─── Lista de sonidos ──────────────────────────────────────────
  SettingsRow {
    titleKey: "sndChoose"
    stacked: true

    SkinRect {
      Layout.fillWidth: true
      Layout.preferredHeight: Math.min(190, list.contentHeight + 8)
      radius: Theme.cozy ? 4 : 12
      color: Theme.surfaceHigh
      clip: true

      ListView {
        id: list
        anchors { fill: parent; margins: 4 }
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        spacing: 2
        model: sp.entries

        delegate: Rectangle {
          id: entry

          required property var modelData

          readonly property bool active: sp.soundFile === entry.modelData.path

          width: list.width
          height: 30
          radius: Theme.cozy ? 3 : 9
          color: entry.active ? Theme.primary : (entryArea.containsMouse ? Theme.surface : "transparent")
          Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }

          RowLayout {
            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
            spacing: 8

            Text {
              text: OozeIcons.music
              color: entry.active ? Theme.textOnPrimary : Theme.primary
              font.pixelSize: Theme.sfs(13)
              font.family: Theme.monoFamily
            }
            Text {
              Layout.fillWidth: true
              text: entry.modelData.name
              elide: Text.ElideRight
              color: entry.active ? Theme.textOnPrimary : Theme.text
              font.pixelSize: Theme.sfs(12)
              font.family: Theme.fontFamily
            }
            Text {
              visible: entry.modelData.user
              text: Translations.t("sndMine")
              color: entry.active ? Theme.textOnPrimary : Theme.subtext
              font.pixelSize: Theme.sfs(10)
              font.family: Theme.fontFamily
            }
          }

          MouseArea {
            id: entryArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              sp.soundPicked(entry.modelData.path)
              AlertSound.play(entry.modelData.path, sp.volume, sp.defaults)
            }
          }
        }
      }
    }
  }

  // ─── Agregar sonido ────────────────────────────────────────────
  SettingsRow {
    titleKey: "sndAdd"
    hintKey: "sndAddHint"
    stacked: true

    ColumnLayout {
      Layout.fillWidth: true
      spacing: 6

      RowLayout {
        Layout.fillWidth: true
        spacing: 8

        SettingsField {
          id: addField
          Layout.minimumWidth: 0
          placeholder: "~/Music/alarm.ogg"
          mono: true
          onSubmitted: text => { if (text.trim() !== "") AlertSound.importFile(text) }
        }
        SettingsBtn {
          icon: "󰐕"
          text: Translations.t("sndAddBtn")
          primary: true
          onClicked: {
            const t = addField.input.text.trim()
            if (t === "") return
            AlertSound.importFile(t)
            addField.input.text = ""
          }
        }
      }

      Text {
        Layout.fillWidth: true
        visible: AlertSound.importStatus !== ""
        text: Translations.t("sndImport_" + AlertSound.importStatus)
        wrapMode: Text.WordWrap
        color: AlertSound.importStatus === "ok" ? Theme.primary : Theme.subtext
        font.pixelSize: Theme.sfs(10)
        font.family: Theme.fontFamily
      }
    }
  }
}
