// FocusPage — categoría "Focus": duraciones y avisos del Pomodoro del dashboard.

import QtQuick
import QtQuick.Layouts
import ".."
import "../../COMMON"
import "../../Services/Lang"
import "../../Modules/Widgets/pomodoro"

SettingsPage {
  id: page
  catId: "focus"

  component Minutes: SettingsRow {
    id: mr
    required property string optKey
    required property int lo
    required property int hi

    titleKey: "wgOpt_" + mr.optKey
    NumberStepper {
      Layout.fillWidth: false
      Layout.preferredWidth: 150
      value: Number(PomodoroService.dashValue(mr.optKey))
      min: mr.lo
      max: mr.hi
      onEdited: v => PomodoroService.setDash(mr.optKey, v)
    }
  }

  component Toggle: SettingsRow {
    id: tr
    required property string optKey

    titleKey: "wgOpt_" + tr.optKey
    SettingsSwitch {
      checked: PomodoroService.dashValue(tr.optKey) === true
      onToggled: PomodoroService.setDash(tr.optKey, !checked)
    }
  }

  SettingsSection {
    titleKey: "focusDurationsTitle"
    hintKey: "focusDurationsHint"

    Minutes { optKey: "focusMin"; lo: 1; hi: 180 }
    Minutes { optKey: "shortMin"; lo: 1; hi: 60 }
    Minutes { optKey: "longMin"; lo: 1; hi: 120 }
    Minutes { optKey: "rounds"; lo: 1; hi: 12 }
  }

  SettingsSection {
    titleKey: "focusAlertsTitle"

    Toggle { optKey: "autoNext" }
    Toggle { optKey: "notify" }
    Toggle { optKey: "sound" }

    SettingsRow {
      titleKey: "focusTest"
      SettingsBtn {
        icon: "󰂚"
        text: ""
        onClicked: PomodoroService.testAlert()
      }
    }

    SettingsRow {
      titleKey: "focusRestart"
      SettingsBtn {
        icon: "󰜉"
        text: ""
        onClicked: PomodoroService.restart(PomodoroService.dashId)
      }
    }
  }

  SettingsSection {
    titleKey: "focusSoundTitle"

    SoundPicker {
      enabled: PomodoroService.dashValue("sound") !== false
      soundFile: String(PomodoroService.dashValue("soundFile") ?? "")
      volume: Number(PomodoroService.dashValue("volume") ?? 100)
      defaults: ["complete", "alarm-clock-elapsed", "message-new-instant"]
      onSoundPicked: path => PomodoroService.setDash("soundFile", path)
      onVolumeEdited: v => PomodoroService.setDash("volume", v)
    }
  }
}
