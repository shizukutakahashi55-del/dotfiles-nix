// TodoAlarmSettings — sección de alarmas del ToDo (Ajustes avanzados → Agenda).

import QtQuick
import QtQuick.Layouts
import "../COMMON"
import "../Services/Lang"
import "../Services/Agenda"

ColumnLayout {
  id: card

  Layout.fillWidth: true
  spacing: 12

  SettingsSection {
    titleKey: "todoAlarmsTitle"
    hintKey: "todoAlarmsHint"

    SettingsRow {
      titleKey: "todoAlarmsEnable"
      SettingsSwitch {
        checked: TodoBackend.alarmsEnabled
        onToggled: TodoBackend.setAlarmsEnabled(!TodoBackend.alarmsEnabled)
      }
    }

    SettingsRow {
      titleKey: "todoAlarmSound"
      hintKey: "todoAlarmSoundHint"
      enabled: TodoBackend.alarmsEnabled
      SettingsSwitch {
        checked: TodoBackend.alarmSound
        onToggled: TodoBackend.setAlarmSound(!TodoBackend.alarmSound)
      }
    }

    SettingsRow {
      titleKey: "todoAlarmPersistent"
      hintKey: "todoAlarmPersistentHint"
      enabled: TodoBackend.alarmsEnabled
      SettingsSwitch {
        checked: TodoBackend.alarmPersistent
        onToggled: TodoBackend.setAlarmPersistent(!TodoBackend.alarmPersistent)
      }
    }

    SettingsRow {
      titleKey: "todoAlarmTest"
      SettingsBtn {
        icon: "󰂚"
        text: ""
        onClicked: TodoBackend.testAlarm()
      }
    }
  }
}
