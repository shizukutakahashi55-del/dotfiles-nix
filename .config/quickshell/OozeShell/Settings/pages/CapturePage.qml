// CapturePage — categoría "Capturas y grabación": carpetas, formato de capturas y de video, audio y avisos.

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import ".."
import "../../COMMON"
import "../../Services/Lang"
import "../../Services/Screenshot"

SettingsPage {
  id: page
  catId: "capture"

  ListModel { id: toolsModel }
  Process {
    id: toolsCheck
    command: ["bash", "-c",
      "export PATH=\"$HOME/.local/bin:/run/current-system/sw/bin:$PATH\"; " +
      "for t in grim wl-copy wf-recorder ffmpeg pactl notify-send xdg-open; do " +
      "if command -v \"$t\" >/dev/null 2>&1; then echo \"$t 1\"; else echo \"$t 0\"; fi; done"]
    running: true
    onRunningChanged: if (running) toolsModel.clear()
    stdout: SplitParser {
      onRead: line => {
        const f = line.trim().split(" ")
        if (f.length === 2) toolsModel.append({ "name": f[0], "ok": f[1] === "1" })
      }
    }
  }

  SettingsSection {
    titleKey: "capFoldersTitle"
    hintKey: "capFoldersHint"

    SettingsRow {
      titleKey: "capShotDir"
      stacked: true
      FolderField {
        placeholder: "~/Pictures/Screenshots"
        current: CaptureConfig.shotDir
        onChosen: path => CaptureConfig.set("shotDir", path.trim())
      }
    }

    SettingsRow {
      titleKey: "capRecDir"
      stacked: true
      FolderField {
        placeholder: "~/Videos/Recordings"
        current: CaptureConfig.recDir
        onChosen: path => CaptureConfig.set("recDir", path.trim())
      }
    }

    SettingsRow {
      stacked: true
      divider: false
      Flow {
        Layout.fillWidth: true
        spacing: 8
        SettingsBtn {
          icon: "󰉋"
          text: Translations.t("capOpenShots")
          onClicked: CaptureConfig.openFolder("shot")
        }
        SettingsBtn {
          icon: "󰉋"
          text: Translations.t("capOpenRecs")
          onClicked: CaptureConfig.openFolder("rec")
        }
      }
    }
  }

  SettingsSection {
    titleKey: "capShotTitle"

    SettingsRow {
      titleKey: "capShotFormat"
      SettingsChoice {
        model: [
          { value: "png",  label: "PNG" },
          { value: "jpeg", label: "JPEG" }
        ]
        current: CaptureConfig.shotFormat
        onPicked: v => CaptureConfig.set("shotFormat", v)
      }
    }

    SettingsRow {
      visible: CaptureConfig.shotFormat === "jpeg"
      titleKey: "capShotQuality"
      NumberStepper {
        Layout.fillWidth: false
        Layout.preferredWidth: 150
        value: CaptureConfig.shotQuality
        min: 10
        max: 100
        step: 5
        suffix: "%"
        onEdited: v => CaptureConfig.set("shotQuality", v)
      }
    }

    SettingsRow {
      titleKey: "capShotPattern"
      hintKey: "capPatternHint"
      stacked: true
      SettingsField {
        mono: true
        placeholder: "Screenshot_%Y-%m-%d_%H-%M-%S"
        value: CaptureConfig.shotPattern
        onSubmitted: text => CaptureConfig.set("shotPattern", text.trim() !== "" ? text.trim() : "Screenshot_%Y-%m-%d_%H-%M-%S")
      }
    }

    SettingsRow {
      titleKey: "capShotCursor"
      SettingsSwitch {
        checked: CaptureConfig.shotCursor
        onToggled: CaptureConfig.set("shotCursor", !CaptureConfig.shotCursor)
      }
    }

    SettingsRow {
      titleKey: "capShotClipboard"
      hintKey: "capShotClipboardHint"
      divider: false
      SettingsSwitch {
        checked: CaptureConfig.shotClipboard
        onToggled: CaptureConfig.set("shotClipboard", !CaptureConfig.shotClipboard)
      }
    }
  }

  SettingsSection {
    titleKey: "capRecTitle"

    SettingsRow {
      titleKey: "capRecFormat"
      hintKey: "capRecFormatHint"
      SettingsChoice {
        model: [
          { value: "mp4",  label: "MP4" },
          { value: "mkv",  label: "MKV" },
          { value: "webm", label: "WebM" }
        ]
        current: CaptureConfig.recFormat
        onPicked: v => CaptureConfig.set("recFormat", v)
      }
    }

    SettingsRow {
      titleKey: "capRecFps"
      SettingsChoice {
        model: [
          { value: 24, label: "24" },
          { value: 30, label: "30" },
          { value: 60, label: "60" }
        ]
        current: CaptureConfig.recFps
        onPicked: v => CaptureConfig.set("recFps", v)
      }
    }

    SettingsRow {
      titleKey: "capRecQuality"
      SettingsChoice {
        model: [
          { value: "low",    label: Translations.t("capQualityLow") },
          { value: "medium", label: Translations.t("capQualityMedium") },
          { value: "high",   label: Translations.t("capQualityHigh") },
          { value: "ultra",  label: Translations.t("capQualityUltra") }
        ]
        current: CaptureConfig.recQuality
        onPicked: v => CaptureConfig.set("recQuality", v)
      }
    }

    SettingsRow {
      titleKey: "capRecAudio"
      SettingsChoice {
        model: [
          { value: "none",   label: Translations.t("capAudioNone") },
          { value: "system", label: Translations.t("capAudioSystem") },
          { value: "mic",    label: Translations.t("capAudioMic") }
        ]
        current: CaptureConfig.recAudio
        onPicked: v => CaptureConfig.set("recAudio", v)
      }
    }

    SettingsRow {
      visible: CaptureConfig.recFormat !== "webm"
      titleKey: "capRecHw"
      hintKey: "capRecHwHint"
      stacked: true
      SettingsChoice {
        model: [
          { value: "cpu",   label: Translations.t("capEncCpu") },
          { value: "nvenc", label: Translations.t("capEncNvenc") },
          { value: "vaapi", label: Translations.t("capEncVaapi") }
        ]
        current: CaptureConfig.recEncoder
        onPicked: v => CaptureConfig.set("recEncoder", v)
      }
    }

    SettingsRow {
      titleKey: "capRecDelay"
      hintKey: "capRecDelayHint"
      NumberStepper {
        Layout.fillWidth: false
        Layout.preferredWidth: 150
        value: CaptureConfig.recDelay
        min: 0
        max: 30
        suffix: "s"
        onEdited: v => CaptureConfig.set("recDelay", v)
      }
    }

    SettingsRow {
      titleKey: "capRecPattern"
      hintKey: "capPatternHint"
      stacked: true
      divider: false
      SettingsField {
        mono: true
        placeholder: "Recording_%Y-%m-%d_%H-%M-%S"
        value: CaptureConfig.recPattern
        onSubmitted: text => CaptureConfig.set("recPattern", text.trim() !== "" ? text.trim() : "Recording_%Y-%m-%d_%H-%M-%S")
      }
    }
  }

  SettingsSection {
    titleKey: "capGeneralTitle"

    SettingsRow {
      titleKey: "capNotify"
      hintKey: "capNotifyHint"
      divider: false
      SettingsSwitch {
        checked: CaptureConfig.notify
        onToggled: CaptureConfig.set("notify", !CaptureConfig.notify)
      }
    }
  }

  SettingsSection {
    titleKey: "capToolsTitle"
    hintKey: "capToolsHint"

    SettingsRow {
      stacked: true
      divider: false
      Flow {
        Layout.fillWidth: true
        spacing: 8
        Repeater {
          model: toolsModel
          delegate: SkinRect {
            id: tool
            required property string name
            required property bool ok
            implicitWidth: toolLabel.implicitWidth + 24
            implicitHeight: 28
            radius: Theme.cozy ? 4 : 14
            color: Theme.bg
            border.width: Theme.bw1
            border.color: tool.ok ? Theme.primary : Theme.error
            Text {
              id: toolLabel
              anchors.centerIn: parent
              text: (tool.ok ? "✓ " : "✗ ") + tool.name
              color: tool.ok ? Theme.text : Theme.error
              font.pixelSize: Theme.sfs(11)
              font.family: Theme.monoFamily
            }
          }
        }
      }
    }
  }
}
