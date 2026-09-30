// TodoAlarmSettings — tarjeta de alarmas del ToDo (Ajustes avanzados → Agenda).
import QtQuick
import QtQuick.Layouts
import "../COMMON"
import "../LANG"
import "../AGENDA"

SkinRect {
  id: card

  Layout.fillWidth: true
  implicitHeight: alarmCol.implicitHeight + 30
  radius: Theme.cardRadius
  color: Theme.surface
  border.width: Theme.bw1
  border.color: Theme.edge
  clip: true

  component Hint: Text {
    Layout.fillWidth: true
    wrapMode: Text.WordWrap
    color: Theme.subtext
    font.pixelSize: Theme.fs(10)
    font.family: Theme.fontFamily
  }

  ColumnLayout {
    id: alarmCol
    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
    spacing: 10

    SectionLabel { text: Translations.t("todoAlarmsTitle") }
    Hint { text: Translations.t("todoAlarmsHint") }
    RowLayout {
      Layout.fillWidth: true
      spacing: 10
      SettingsBtn {
        icon: TodoBackend.alarmsEnabled ? "󰂞" : "󰂛"
        text: TodoBackend.alarmsEnabled ? "ON" : "OFF"
        primary: TodoBackend.alarmsEnabled
        onClicked: TodoBackend.setAlarmsEnabled(!TodoBackend.alarmsEnabled)
      }
      SettingsBtn {
        icon: "󰂚"
        text: Translations.t("todoAlarmTest")
        onClicked: TodoBackend.testAlarm()
      }
      Item { Layout.fillWidth: true }
    }

    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }

    SectionLabel { text: Translations.t("todoAlarmSound") }
    RowLayout {
      Layout.fillWidth: true
      spacing: 10
      opacity: TodoBackend.alarmsEnabled ? 1 : 0.5
      SettingsBtn {
        icon: TodoBackend.alarmSound ? "󰕾" : "󰝟"
        text: TodoBackend.alarmSound ? "ON" : "OFF"
        primary: TodoBackend.alarmSound
        onClicked: TodoBackend.setAlarmSound(!TodoBackend.alarmSound)
      }
      Item { Layout.fillWidth: true }
    }
    Hint { text: Translations.t("todoAlarmSoundHint") }

    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }

    SectionLabel { text: Translations.t("todoAlarmPersistent") }
    RowLayout {
      Layout.fillWidth: true
      spacing: 10
      opacity: TodoBackend.alarmsEnabled ? 1 : 0.5
      SettingsBtn {
        icon: TodoBackend.alarmPersistent ? "▣" : "▢"
        text: TodoBackend.alarmPersistent ? "ON" : "OFF"
        primary: TodoBackend.alarmPersistent
        onClicked: TodoBackend.setAlarmPersistent(!TodoBackend.alarmPersistent)
      }
      Item { Layout.fillWidth: true }
    }
    Hint { text: Translations.t("todoAlarmPersistentHint") }
  }
}
