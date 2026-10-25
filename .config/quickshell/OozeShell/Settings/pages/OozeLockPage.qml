// OozeLockPage

import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import ".."
import "../../COMMON"
import "../../Services/Lang"
import "../../Modules/Lock"

SettingsPage {
  id: page
  catId: "oozelock"

  property string lockPathStatus: ""

  // ── Comprobación de la imagen ──
  function checkLockPath() {
    if (Theme.lockWallpaperPath === "") { page.lockPathStatus = "empty"; return }
    lockPathCheck.running = false
    lockPathCheck.running = true
  }
  Component.onCompleted: page.checkLockPath()

  Process {
    id: lockPathCheck
    command: ["bash", "-c", [
      'p="$1"',
      'case "$p" in "~"|"~/"*) p="$HOME${p#\\~}";; esac',
      'p="${p/#\\$HOME/$HOME}"',
      '[ -f "$p" ] && echo ok || echo missing'
    ].join("\n"), "sh", Theme.lockWallpaperPath]
    stdout: SplitParser {
      onRead: line => page.lockPathStatus = line.trim() === "ok" ? "ok" : "missing"
    }
  }

  Connections {
    target: Theme
    function onLockWallpaperPathChanged() { page.checkLockPath() }
  }

  // ── Fondo ──
  SettingsSection {
    titleKey: "olBackgroundTitle"
    hintKey: "olBackgroundHint"

    SettingsRow {
      hint: Translations.t(Theme.lockWallpaperMode === "custom" ? "lockCustomHint" : "lockAutoHint")
      stacked: true
      SettingsChoice {
        model: [
          { value: "auto",   label: Translations.t("lockModeAuto"),   icon: "󰸉" },
          { value: "custom", label: Translations.t("lockModeCustom"), icon: "󰋩" }
        ]
        current: Theme.lockWallpaperMode
        onPicked: v => Theme.setLockWallpaperMode(v)
      }
    }

    SettingsRow {
      visible: Theme.lockWallpaperMode === "custom"
      stacked: true
      SettingsField {
        placeholder: Translations.t("lockPathPlaceholder")
        value: Theme.lockWallpaperPath
        onSubmitted: text => Theme.setLockWallpaperPath(text)
      }
    }
    SettingsNote {
      visible: Theme.lockWallpaperMode === "custom" && page.lockPathStatus !== ""
      kind: page.lockPathStatus === "ok" ? "accent" : (page.lockPathStatus === "missing" ? "error" : "info")
      text: page.lockPathStatus === "ok" ? "󰄬  " + Translations.t("lockPathOk")
          : page.lockPathStatus === "missing" ? "󰅖  " + Translations.t("lockPathMissing")
          : Translations.t("lockPathEmpty")
    }

    SettingsRow {
      titleKey: "olBlur"
      hintKey: "olBlurHint"
      enabled: !Theme.shellPerf
      ScaleSlider {
        Layout.fillWidth: false
        Layout.preferredWidth: 240
        value: LockConfig.bgBlur
        min: 0
        max: 100
        step: 5
        defaultValue: LockConfig.schema.bgBlur.def
        onEdited: v => LockConfig.setValue("bgBlur", v)
      }
    }

    SettingsRow {
      titleKey: "olDim"
      hintKey: "olDimHint"
      ScaleSlider {
        Layout.fillWidth: false
        Layout.preferredWidth: 240
        value: LockConfig.bgDim
        min: 0
        max: 80
        step: 5
        defaultValue: LockConfig.schema.bgDim.def
        onEdited: v => LockConfig.setValue("bgDim", v)
      }
    }
  }

  // ── Distribución ──
  SettingsSection {
    titleKey: "olLayoutTitle"
    hintKey: "olLayoutHint"

    SettingsRow {
      stacked: true
      LockLayoutPicker {
        current: LockConfig.layout
        onPicked: v => LockConfig.setValue("layout", v)
      }
    }
    SettingsRow {
      titleKey: "olShowPower"
      hintKey: "olShowPowerHint"
      SettingsSwitch {
        checked: LockConfig.showPower
        onToggled: LockConfig.setValue("showPower", !LockConfig.showPower)
      }
    }
  }

  // ── Reloj e información ──
  SettingsSection {
    titleKey: "olInfoTitle"
    hintKey: "olInfoHint"

    SettingsRow {
      titleKey: "olClock24h"
      SettingsSwitch {
        checked: LockConfig.clock24h
        onToggled: LockConfig.setValue("clock24h", !LockConfig.clock24h)
      }
    }
    SettingsRow {
      titleKey: "olClockStyle"
      stacked: true
      SettingsChips {
        model: [
          { value: "classic", label: Translations.t("olClockStyleClassic"), icon: "󰥔" },
          { value: "stacked", label: Translations.t("olClockStyleStacked"), icon: "󰕮" },
          { value: "mono",    label: Translations.t("olClockStyleMono"),    icon: "󰇘" },
          { value: "boxed",   label: Translations.t("olClockStyleBoxed"),   icon: "󰆾" },
          { value: "analog",  label: Translations.t("olClockStyleAnalog"),  icon: "󰅐" }
        ]
        current: LockConfig.clockStyle
        onPicked: v => LockConfig.setValue("clockStyle", v)
      }
    }
    SettingsRow {
      titleKey: "olClockScale"
      ScaleSlider {
        Layout.fillWidth: false
        Layout.preferredWidth: 240
        value: LockConfig.clockScale
        min: 60
        max: 140
        step: 10
        defaultValue: LockConfig.schema.clockScale.def
        onEdited: v => LockConfig.setValue("clockScale", v)
      }
    }
    SettingsRow {
      titleKey: "olShowDate"
      SettingsSwitch {
        checked: LockConfig.showDate
        onToggled: LockConfig.setValue("showDate", !LockConfig.showDate)
      }
    }
    SettingsRow {
      titleKey: "olShowAvatar"
      hintKey: "olShowAvatarHint"
      SettingsSwitch {
        checked: LockConfig.showAvatar
        onToggled: LockConfig.setValue("showAvatar", !LockConfig.showAvatar)
      }
    }
    SettingsRow {
      titleKey: "olShowLayout"
      hintKey: "olShowLayoutHint"
      SettingsSwitch {
        checked: LockConfig.showLayout
        onToggled: LockConfig.setValue("showLayout", !LockConfig.showLayout)
      }
    }
    SettingsRow {
      titleKey: "olShowBattery"
      hintKey: "olShowBatteryHint"
      SettingsSwitch {
        checked: LockConfig.showBattery
        onToggled: LockConfig.setValue("showBattery", !LockConfig.showBattery)
      }
    }
  }

  // ── Posición de los widgets ──
  SettingsSection {
    titleKey: "olWidgetsTitle"
    hintKey: "olWidgetsHint"

    SettingsRow {
      titleKey: "olPlacement"
      hintKey: "olPlacementHint"
      stacked: true
      SettingsChips {
        model: [
          { value: "auto",   label: Translations.t("olPlacementAuto"), icon: "󰁨" },
          { value: "top",    label: Translations.t("barTop"),    icon: "▀" },
          { value: "bottom", label: Translations.t("barBottom"), icon: "▄" },
          { value: "left",   label: Translations.t("barLeft"),   icon: "▌" },
          { value: "right",  label: Translations.t("barRight"),  icon: "▐" }
        ]
        current: LockConfig.widgetsPlacement
        onPicked: v => LockConfig.setValue("widgetsPlacement", v)
      }
    }
    SettingsRow {
      titleKey: "olSideWidth"
      hintKey: "olSideWidthHint"
      enabled: LockConfig.widgetsPlacement === "left" || LockConfig.widgetsPlacement === "right"
      ScaleSlider {
        Layout.fillWidth: false
        Layout.preferredWidth: 240
        value: LockConfig.sideWidth
        min: 260
        max: 460
        step: 20
        suffix: " px"
        valueWidth: 64
        defaultValue: LockConfig.schema.sideWidth.def
        onEdited: v => LockConfig.setValue("sideWidth", v)
      }
    }
  }

  // ── Clima ──
  SettingsSection {
    titleKey: "olWeatherTitle"
    hintKey: "olWeatherHint"

    SettingsRow {
      titleKey: "olWeatherEnable"
      SettingsSwitch {
        checked: LockConfig.weatherEnabled
        onToggled: LockConfig.setValue("weatherEnabled", !LockConfig.weatherEnabled)
      }
    }

    SettingsRow {
      titleKey: "olWeatherCity"
      hintKey: "olWeatherCityHint"
      stacked: true
      enabled: LockConfig.weatherEnabled
      SettingsField {
        placeholder: Translations.t("wgWxCityPlaceholder")
        value: LockConfig.weatherCity
        onSubmitted: text => LockConfig.setValue("weatherCity", text)
      }
    }
    SettingsNote {
      visible: LockConfig.weatherEnabled && LockConfig.city === ""
      kind: "warn"
      text: Translations.t("olWeatherNoCity")
    }
    SettingsNote {
      visible: LockConfig.weatherEnabled && LockConfig.cityFromWidget
      kind: "accent"
      text: Translations.t("olWeatherFromWidget") + " " + LockConfig.widgetCity
    }

    SettingsRow {
      titleKey: "olCardScale"
      hintKey: "olCardScaleHint"
      enabled: LockConfig.weatherEnabled
      ScaleSlider {
        Layout.fillWidth: false
        Layout.preferredWidth: 240
        value: LockConfig.weatherScale
        min: 60
        max: 140
        step: 10
        defaultValue: LockConfig.schema.weatherScale.def
        onEdited: v => LockConfig.setValue("weatherScale", v)
      }
    }

    SettingsRow {
      titleKey: "olWeatherStyle"
      hintKey: "olWeatherStyleHint"
      enabled: LockConfig.weatherEnabled
      SettingsChoice {
        model: [
          { value: "forecast", label: Translations.t("olWeatherStyleForecast"), icon: "󰖐" },
          { value: "card",     label: Translations.t("olWeatherStyleCard"),     icon: "󰖙" },
          { value: "classic",  label: Translations.t("olWeatherStyleClassic"),  icon: "󰖕" }
        ]
        current: LockConfig.weatherStyle
        onPicked: v => LockConfig.setValue("weatherStyle", v)
      }
    }

    SettingsRow {
      titleKey: "olWeatherUnits"
      enabled: LockConfig.weatherEnabled
      SettingsChoice {
        model: [
          { value: "c", label: "°C · km/h" },
          { value: "f", label: "°F · mph" }
        ]
        current: LockConfig.weatherFahrenheit ? "f" : "c"
        onPicked: v => LockConfig.setValue("weatherFahrenheit", v === "f")
      }
    }

    SettingsRow {
      titleKey: "olWeatherForecast"
      hintKey: "olWeatherForecastHint"
      enabled: LockConfig.weatherEnabled
      SettingsSwitch {
        checked: LockConfig.weatherForecast
        onToggled: LockConfig.setValue("weatherForecast", !LockConfig.weatherForecast)
      }
    }

    SettingsRow {
      titleKey: "olWeatherDays"
      hintKey: "olWeatherDaysHint"
      enabled: LockConfig.weatherEnabled && LockConfig.weatherStyle === "forecast" && LockConfig.weatherForecast
      NumberStepper {
        Layout.fillWidth: false
        Layout.preferredWidth: 150
        Layout.preferredHeight: 34
        value: LockConfig.weatherDays
        min: 3; max: 5; step: 1
        onEdited: v => LockConfig.setValue("weatherDays", v)
      }
    }

    SettingsRow {
      titleKey: "olWeatherTint"
      hintKey: "olWeatherTintHint"
      enabled: LockConfig.weatherEnabled && LockConfig.weatherStyle !== "classic"
      SettingsSwitch {
        checked: LockConfig.weatherTint
        onToggled: LockConfig.setValue("weatherTint", !LockConfig.weatherTint)
      }
    }

    SettingsRow {
      titleKey: "olWeatherRefresh"
      enabled: LockConfig.weatherEnabled
      NumberStepper {
        Layout.fillWidth: false
        Layout.preferredWidth: 150
        Layout.preferredHeight: 34
        value: LockConfig.weatherRefreshMin
        min: 10; max: 120; step: 10
        suffix: " min"
        onEdited: v => LockConfig.setValue("weatherRefreshMin", v)
      }
    }
  }

  // ── Reproductor ──
  SettingsSection {
    titleKey: "olMediaTitle"
    hintKey: "olMediaHint"

    SettingsRow {
      titleKey: "olMediaEnable"
      SettingsSwitch {
        checked: LockConfig.mediaEnabled
        onToggled: LockConfig.setValue("mediaEnabled", !LockConfig.mediaEnabled)
      }
    }
    SettingsRow {
      titleKey: "olCardScale"
      hintKey: "olCardScaleHint"
      enabled: LockConfig.mediaEnabled
      ScaleSlider {
        Layout.fillWidth: false
        Layout.preferredWidth: 240
        value: LockConfig.mediaScale
        min: 60
        max: 140
        step: 10
        defaultValue: LockConfig.schema.mediaScale.def
        onEdited: v => LockConfig.setValue("mediaScale", v)
      }
    }
    SettingsRow {
      titleKey: "olMediaStyle"
      hintKey: "olMediaStyleHint"
      enabled: LockConfig.mediaEnabled
      SettingsChoice {
        model: [
          { value: "player",  label: Translations.t("olMediaStylePlayer"),  icon: "󰎆" },
          { value: "classic", label: Translations.t("olMediaStyleClassic"), icon: "󰝚" }
        ]
        current: LockConfig.mediaStyle
        onPicked: v => LockConfig.setValue("mediaStyle", v)
      }
    }
    SettingsRow {
      titleKey: "olMediaVisualizer"
      hintKey: "olMediaVisualizerHint"
      enabled: LockConfig.mediaEnabled && LockConfig.mediaStyle === "player"
      SettingsSwitch {
        checked: LockConfig.mediaVisualizer
        onToggled: LockConfig.setValue("mediaVisualizer", !LockConfig.mediaVisualizer)
      }
    }
    SettingsRow {
      titleKey: "olMediaCover"
      enabled: LockConfig.mediaEnabled
      SettingsSwitch {
        checked: LockConfig.mediaCover
        onToggled: LockConfig.setValue("mediaCover", !LockConfig.mediaCover)
      }
    }
    SettingsRow {
      titleKey: "olMediaOnlyPlaying"
      hintKey: "olMediaOnlyPlayingHint"
      enabled: LockConfig.mediaEnabled
      SettingsSwitch {
        checked: LockConfig.mediaOnlyPlaying
        onToggled: LockConfig.setValue("mediaOnlyPlaying", !LockConfig.mediaOnlyPlaying)
      }
    }
  }

  // ── Notificaciones ──
  SettingsSection {
    titleKey: "olNotifTitle"
    hintKey: "olNotifHint"

    SettingsRow {
      titleKey: "olNotifMode"
      hint: Translations.t(LockConfig.notifMode === "apps" ? "olNotifHintApps"
                         : LockConfig.notifMode === "notifs" ? "olNotifHintList" : "olNotifHintOff")
      SettingsChoice {
        model: [
          { value: "off",    label: Translations.t("olNotifOff"),  icon: "󰂛" },
          { value: "apps",   label: Translations.t("olNotifApps"), icon: "󰀻" },
          { value: "notifs", label: Translations.t("olNotifList"), icon: "󰂚" }
        ]
        current: LockConfig.notifMode
        onPicked: v => LockConfig.setValue("notifMode", v)
      }
    }

    SettingsRow {
      titleKey: "olCardScale"
      hintKey: "olCardScaleHint"
      enabled: LockConfig.notifMode !== "off"
      ScaleSlider {
        Layout.fillWidth: false
        Layout.preferredWidth: 240
        value: LockConfig.notifScale
        min: 60
        max: 140
        step: 10
        defaultValue: LockConfig.schema.notifScale.def
        onEdited: v => LockConfig.setValue("notifScale", v)
      }
    }

    SettingsRow {
      titleKey: "olNotifMax"
      hintKey: "olNotifMaxHint"
      enabled: LockConfig.notifMode !== "off"
      NumberStepper {
        Layout.fillWidth: false
        Layout.preferredWidth: 150
        Layout.preferredHeight: 34
        value: LockConfig.notifMax
        min: 1; max: 6; step: 1
        onEdited: v => LockConfig.setValue("notifMax", v)
      }
    }
  }

  // ── Restaurar ──
  SettingsSection {
    titleKey: "olResetTitle"

    SettingsRow {
      titleKey: "olResetLabel"
      hintKey: "olResetHint"
      SettingsBtn {
        text: Translations.t("olResetBtn")
        icon: "󰑓"
        onClicked: LockConfig.reset()
      }
    }
  }
}
