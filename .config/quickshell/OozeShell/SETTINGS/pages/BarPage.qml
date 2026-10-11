// BarPage — categoría "Barra": backend (Quickshell/Waybar), posición, flotante, islas, píldora (con su tamaño y el del Dashboard) y batería.

import QtQuick
import QtQuick.Layouts
import ".."
import "../../COMMON"
import "../../LANG"

SettingsPage {
  id: page
  catId: "bar"

  readonly property bool waybarReady: WM.isInstalled("waybar")

  component Label: Text {
    Layout.fillWidth: true
    wrapMode: Text.WordWrap
    color: Theme.text
    font.pixelSize: Theme.fs(12)
    font.bold: true
    font.family: Theme.fontFamily
  }

  component Hint: Text {
    Layout.fillWidth: true
    wrapMode: Text.WordWrap
    color: Theme.subtext
    font.pixelSize: Theme.fs(10)
    font.family: Theme.fontFamily
  }

  component Divider: Rectangle {
    Layout.fillWidth: true
    Layout.preferredHeight: 1
    color: Theme.divider
  }

  // ═══ Backend ═══════════════════════════════════════════════════
  SettingsSection {
    titleKey: "barBackendTitle"
    hintKey: "barBackendHint"

    Flow {
      Layout.fillWidth: true
      spacing: 8
      SettingsBtn {
        icon: "▀"
        text: Translations.t("barOoze")
        primary: Theme.barBackend !== "waybar"
        onClicked: Theme.setBarBackend("ooze")
      }
      SettingsBtn {
        icon: "▬"
        text: Translations.t("barWaybar")
        primary: Theme.barBackend === "waybar" && page.waybarReady
        enabled: page.waybarReady
        onClicked: Theme.setBarBackend("waybar")
      }
    }

    Text {
      visible: !page.waybarReady
      Layout.fillWidth: true
      wrapMode: Text.WordWrap
      text: Translations.t("barWaybarMissing")
      color: Theme.error
      font.pixelSize: Theme.fs(11)
      font.family: Theme.fontFamily
    }
    Text {
      visible: page.waybarReady && Theme.barBackend === "waybar"
      Layout.fillWidth: true
      wrapMode: Text.WordWrap
      text: Translations.t("barWaybarNote")
      color: Theme.subtext
      font.pixelSize: Theme.fs(11)
      font.family: Theme.fontFamily
    }
  }

  // ═══ Posición ══════════════════════════════════════════════════
  SettingsSection {
    titleKey: "barSection"
    hintKey: "barSectionHint"

    Label { text: Translations.t("barPosition") }
    Flow {
      Layout.fillWidth: true
      spacing: 8
      SettingsBtn {
        icon: "▀"
        text: Translations.t("barTop")
        primary: Theme.barPosition === "top"
        onClicked: Theme.setBarPosition("top")
      }
      SettingsBtn {
        icon: "▄"
        text: Translations.t("barBottom")
        primary: Theme.barPosition === "bottom"
        onClicked: Theme.setBarPosition("bottom")
      }
      SettingsBtn {
        icon: "▌"
        text: Translations.t("barLeft")
        primary: Theme.barPosition === "left"
        onClicked: Theme.setBarPosition("left")
      }
      SettingsBtn {
        icon: "▐"
        text: Translations.t("barRight")
        primary: Theme.barPosition === "right"
        onClicked: Theme.setBarPosition("right")
      }
    }

    Divider {}

    Label { text: Translations.t("barFloating") }
    Flow {
      Layout.fillWidth: true
      spacing: 8
      SettingsBtn {
        icon: Theme.barFloatingPref ? "▣" : "▢"
        text: Theme.barFloatingPref ? "ON" : "OFF"
        primary: Theme.barFloatingPref
        opacity: Theme.barVertical ? 0.4 : 1.0
        onClicked: { if (!Theme.barVertical) Theme.setBarFloating(!Theme.barFloatingPref) }
      }
    }
    Hint {
      text: Theme.barVertical ? Translations.t("barFloatingOnlyH")
                              : Translations.t("barFloatingHint")
    }
  }

  // ═══ Islas ═════════════════════════════════════════════════════
  SettingsSection {
    titleKey: "barIslands"
    hintKey: "barIslandsHint"

    Flow {
      Layout.fillWidth: true
      spacing: 8
      SettingsBtn {
        icon: Theme.islandsPref ? "◖◗" : "▬"
        text: Theme.islandsPref ? "ON" : "OFF"
        primary: Theme.islandsPref
        opacity: Theme.barVertical ? 0.4 : 1.0
        onClicked: { if (!Theme.barVertical) Theme.setIslandsEnabled(!Theme.islandsPref) }
      }
    }
    Hint {
      visible: Theme.barVertical
      text: Translations.t("barIslandsOnlyH")
    }
  }

  // ═══ Cristal ═══════════════════════════════════════════════════


  SettingsSection {
    titleKey: "barGlass"
    hintKey: "barGlassHint"

    visible: Theme.glassAllowed

    Flow {
      Layout.fillWidth: true
      spacing: 8
      SettingsBtn {
        icon: Theme.glassModePref ? "󰈈" : "󰈉"
        text: Theme.glassModePref ? "ON" : "OFF"
        primary: Theme.glassModePref
        onClicked: Theme.setGlassMode(!Theme.glassModePref)
      }
    }

    Label { text: Translations.t("barGlassOpacity") }
    ScaleSlider {
      Layout.fillWidth: true
      value: Theme.glassOpacity
      min: 10
      max: 100
      step: 5
      defaultValue: Theme.glassOpacityDefault
      enabled: Theme.glassModePref
      opacity: Theme.glassModePref ? 1.0 : 0.4
      onEdited: v => Theme.setGlassOpacity(v)
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: 10
      opacity: Theme.glassModePref ? 1.0 : 0.4
      Label { text: Translations.t("barGlassBlur") }
      SettingsBtn {
        icon: Theme.glassBlurPref ? "󰈈" : "󰈉"
        text: Theme.glassBlurPref ? "ON" : "OFF"
        primary: Theme.glassBlurPref
        enabled: Theme.glassModePref
        onClicked: Theme.setGlassBlur(!Theme.glassBlurPref)
      }
    }
    Hint { text: Translations.t("barGlassBlurHint") }

    Label { text: Translations.t("barGlassSeam") }
    ScaleSlider {
      Layout.fillWidth: true
      value: Theme.glassSeamInset
      min: 0
      max: 24
      step: 1
      defaultValue: Theme.glassSeamDefault
      enabled: Theme.glassModePref && Theme.glassBlurPref
      opacity: (Theme.glassModePref && Theme.glassBlurPref) ? 1.0 : 0.4
      onEdited: v => Theme.setGlassSeamInset(v)
    }
    Hint { text: Translations.t("barGlassSeamHint") }
    Hint {
      visible: Theme.glassModePref
      text: Translations.t("barGlassFloatHint")
    }
  }

  // ═══ Píldora ═══════════════════════════════════════════════════
  SettingsSection {
    titleKey: "barPillMode"
    hintKey: "barPillModeHint"

    Flow {
      Layout.fillWidth: true
      spacing: 8
      SettingsBtn {
        icon: Theme.pillModePref ? "💊" : "▬"
        text: Theme.pillModePref ? "ON" : "OFF"
        primary: Theme.pillModePref
        opacity: Theme.barVertical ? 0.4 : 1.0
        onClicked: { if (!Theme.barVertical) Theme.setPillModeEnabled(!Theme.pillModePref) }
      }
    }

    RowLayout {
      visible: Theme.pillMode
      Layout.fillWidth: true
      spacing: 10
      Label { text: Translations.t("barPillAutoHide") }
      SettingsBtn {
        icon: Theme.pillAutoHidePref ? "󰈈" : "󰈉"
        text: Theme.pillAutoHidePref ? "ON" : "OFF"
        primary: Theme.pillAutoHidePref
        onClicked: Theme.setPillAutoHide(!Theme.pillAutoHidePref)
      }
    }
    RowLayout {
      visible: Theme.pillMode && Theme.pillAutoHidePref
      Layout.fillWidth: true
      spacing: 10
      Label { text: Translations.t("barPillTraySync") }
      SettingsBtn {
        icon: Theme.pillTraySyncPref ? "󰌷" : "󰌸"
        text: Theme.pillTraySyncPref ? "ON" : "OFF"
        primary: Theme.pillTraySyncPref
        onClicked: Theme.setPillTraySync(!Theme.pillTraySyncPref)
      }
    }

    Divider {}


    Label { text: Translations.t("pillSize") }
    ScaleSlider {
      Layout.fillWidth: true
      value: Theme.pillScalePercent
      min: Theme.ownScaleMin
      max: Theme.ownScaleMax
      step: 5
      defaultValue: Theme.pillScaleDefault
      enabled: Theme.pillMode
      onEdited: v => Theme.setPillScalePercent(v)
    }
    Hint { text: Translations.t("pillSizeHint") }


    Label { text: Translations.t("dashSize") }
    LevelPicker {
      level: Theme.dashboardLevel
      names: ["1", "2", "3", "4", "5"]
      showNames: true
      enabled: Theme.pillMode
      opacity: Theme.pillMode ? 1.0 : 0.4
      onPicked: index => Theme.setDashboardLevel(index)
    }
    Hint { text: Translations.t("dashSizeHint") }
  }

  // ═══ Batería ══════════════════════════════════════════════════
  SettingsSection {
    titleKey: "batterySection"
    hintKey: "batteryHint"

    Flow {
      Layout.fillWidth: true
      spacing: 8
      SettingsBtn {
        icon: Theme.batteryEnabled ? "󰂄" : "󰂎"
        text: Theme.batteryEnabled ? "ON" : "OFF"
        primary: Theme.batteryEnabled
        onClicked: Theme.setBatteryEnabled(!Theme.batteryEnabled)
      }
    }
  }
}
