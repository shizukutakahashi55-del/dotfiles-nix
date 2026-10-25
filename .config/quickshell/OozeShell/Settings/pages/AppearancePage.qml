// AppearancePage — categoría "Apariencia": tema, paleta, estilo de interfaz, CoOzey y apariencia de Hyprland (gaps, bordes, blur, sombra y animaciones).

import QtQuick
import QtQuick.Layouts
import ".."
import "../../COMMON"
import "../../Services/Lang"
import "../../Modules/Appearance"

SettingsPage {
  id: page
  catId: "appearance"

  readonly property var av: page.host ? page.host.appearanceValues : ({})
  readonly property var specs: page.host ? page.host.hyprSliderSpecs : []
  readonly property var toggles: page.host ? page.host.hyprToggles : []
  readonly property var profiles: page.host ? page.host.animProfiles : []
  readonly property string profile: page.host ? page.host.animProfile : ""
  readonly property var currentProfile: page.profiles.find(p => p.key === page.profile)

  SettingsSection {
    titleKey: "themeSection"

    SettingsRow {
      titleKey: "themeModeLabel"
      hintKey: "themeModeHint"
      SettingsChoice {
        model: [
          { value: "dark",     label: Translations.t("themeDark"),     icon: "󰖔" },
          { value: "light",    label: Translations.t("themeLight"),    icon: "󰖨" },
          { value: "colorful", label: Translations.t("themeColorful"), icon: "󰏘" }
        ]
        current: Theme.themeMode
        onPicked: v => Theme.setThemeMode(v)
      }
    }

    SettingsRow {
      visible: Theme.themeMode === "colorful" && !Theme.paletteMode
      titleKey: "themeColorfulDepth"
      ScaleSlider {
        Layout.fillWidth: false
        Layout.preferredWidth: 240
        value: Theme.colorfulDepth
        min: 0
        max: 100
        step: 5
        defaultValue: 50
        onEdited: v => Theme.setColorfulDepth(v)
      }
    }

    SettingsNote {
      visible: Theme.paletteMode
      kind: "accent"
      text: Translations.t("themeModePalettesNote")
    }
  }

  SettingsSection {
    titleKey: "advPaletteTitle"

    SettingsRow {
      stacked: true
      SettingsChoice {
        model: [
          { value: false, label: Translations.t("advPaletteModeAuto") },
          { value: true,  label: Translations.t("advPaletteModeManual") }
        ]
        current: Theme.paletteMode
        onPicked: v => Theme.setPaletteMode(v)
      }
    }

    SettingsNote {
      visible: Theme.paletteMode
      text: Translations.t("advPaletteManualHint")
    }

    SettingsRow {
      visible: Theme.paletteMode
      titleKey: "advPaletteSystem"
      SettingsSwitch {
        checked: Theme.paletteSystemSync
        onToggled: Theme.setPaletteSystemSync(!Theme.paletteSystemSync)
      }
    }

    SettingsRow {
      visible: Theme.paletteMode
      stacked: true
      PaletteGrid {
        model: Theme.paletteOrder.map(i => ({
          value: i,
          label: Theme.manualPalettes[i].label,
          color: Theme.manualPalettes[i].primary,
          bg: Theme.manualPalettes[i].bg,
          group: Theme.manualPalettes[i].family ?? "classic"
        }))
        current: Theme.manualPaletteIndex
        onPicked: v => Theme.setManualPaletteIndex(v)
      }
    }
  }

  SettingsSection {
    titleKey: "advStyleTitle"

    SettingsRow {
      stacked: true

      RowLayout {
        Layout.fillWidth: true
        spacing: 10

        Repeater {
          model: [
            { id: "soft", nameKey: "advStyleSoft", hintKey: "advStyleSoftHint" },
            { id: "cozy", nameKey: "advStyleCozy", hintKey: "advStyleCozyHint" }
          ]

          delegate: SkinRect {
            id: scard
            required property var modelData
            readonly property bool active: Theme.uiStyle === scard.modelData.id
            readonly property bool isCozy: scard.modelData.id === "cozy"

            Layout.fillWidth: true
            Layout.preferredWidth: 1
            implicitHeight: scol.implicitHeight + 24
            radius: scard.isCozy ? 4 : 12
            color: scardArea.containsMouse ? Theme.surfaceHigh : Theme.bg
            inkColor: scard.active ? Theme.primary : Theme.ink
            border.width: scard.active ? 2 : (scard.isCozy ? 2 : 1)
            border.color: scard.active ? Theme.primary : (scard.isCozy ? Theme.ink : Theme.divider)
            Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }

            ColumnLayout {
              id: scol
              anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
              spacing: 8

              Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 54
                radius: scard.isCozy ? 4 : 10
                color: Theme.surface
                border.width: scard.isCozy ? 2 : 1
                border.color: scard.isCozy ? Theme.ink : Theme.divider
                clip: true

                Rectangle {
                  anchors { left: parent.left; right: parent.right; top: parent.top
                            margins: scard.isCozy ? 2 : 1 }
                  height: 12
                  radius: scard.isCozy ? 2 : 8
                  color: Theme.bg
                  border.width: scard.isCozy ? 2 : 0
                  border.color: Theme.ink
                }
                Rectangle {
                  x: 8; y: 22; width: parent.width * 0.5; height: 22
                  radius: scard.isCozy ? 2 : 7
                  color: Theme.surfaceHigh
                  border.width: scard.isCozy ? 2 : 1
                  border.color: scard.isCozy ? Theme.ink : Theme.divider
                }
                Rectangle {
                  x: parent.width * 0.5 + 16; y: 26
                  width: parent.width * 0.5 - 30; height: 14
                  radius: scard.isCozy ? 4 : 7
                  color: Theme.primary
                  border.width: scard.isCozy ? 2 : 0
                  border.color: Theme.ink
                }
              }

              RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Text {
                  Layout.fillWidth: true
                  text: Translations.t(scard.modelData.nameKey)
                  color: Theme.text
                  font.bold: true
                  font.pixelSize: Theme.sfs(12)
                  font.family: scard.isCozy ? Theme.cozyFamily : Theme.monoFamily
                  elide: Text.ElideRight
                }
                Text {
                  visible: scard.active
                  text: "󰄬"
                  color: Theme.primary
                  font.pixelSize: Theme.sfs(14)
                  font.family: Theme.monoFamily
                }
              }
              Text {
                Layout.fillWidth: true
                text: Translations.t(scard.modelData.hintKey)
                wrapMode: Text.WordWrap
                color: Theme.subtext
                font.pixelSize: Theme.sfs(10)
                font.family: scard.isCozy ? Theme.cozyFamily : Theme.monoFamily
              }
            }

            MouseArea {
              id: scardArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: Theme.setUiStyle(scard.modelData.id)
            }
          }
        }
      }
    }
  }

  SettingsSection {
    visible: Theme.cozy
    titleKey: "cozyTitle"
    hintKey: "cozyHint"

    SettingsRow {
      visible: !Theme.paletteMode
      titleKey: "cozyWarm"
      NumberStepper {
        Layout.fillWidth: false
        Layout.preferredWidth: 140
        Layout.preferredHeight: 34
        value: Theme.cozyWarm
        min: 0; max: 100; step: 10
        suffix: "%"
        onEdited: v => Theme.setCozyWarm(v)
      }
    }

    SettingsRow {
      titleKey: "cozyUsePalettes"
      SettingsBtn {
        icon: "󰉼"
        text: ""
        onClicked: Theme.enableCozy(null)
      }
    }
  }

  SettingsSection {
    titleKey: "advHyprTitle"
    hintKey: "advHyprHint"

    Repeater {
      model: page.toggles
      delegate: SettingsRow {
        required property var modelData
        title: modelData.label
        SettingsSwitch {
          checked: page.av[modelData.key] ?? modelData.def
          onToggled: page.host.appearanceToggleChanged(modelData.key, !(page.av[modelData.key] ?? modelData.def))
        }
      }
    }

    SettingsRow {
      stacked: true

      GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: 24
        rowSpacing: 14

        Repeater {
          model: page.specs
          delegate: AppearanceSlider {
            required property var modelData
            readonly property bool locked: modelData.key.indexOf("shadow") === 0 && !(page.av.shadowEnabled ?? false)

            Layout.fillWidth: true
            Layout.preferredWidth: 1
            enabled: !locked
            opacity: locked ? 0.4 : 1
            label: modelData.label
            keyName: modelData.key
            minValue: modelData.min
            maxValue: modelData.max
            stepValue: modelData.step
            decimals: modelData.dec
            value: page.av[modelData.key] ?? modelData.def
            colors: page.host.hyprSliderColors
            onPreviewChanged: (k, v) => page.host.appearancePreviewChanged(k, v)
            onCommitted: (k, v) => page.host.appearanceValueCommitted(k, v)
          }
        }
      }
    }

    SettingsRow {
      titleKey: "advAnimStyle"
      hint: page.currentProfile ? Translations.tw(page.currentProfile.hint, WM.wm) : ""
      stacked: true
      enabled: page.av.animationsEnabled ?? true

      SettingsChips {
        model: page.profiles.map(p => ({ value: p.key, label: Translations.t(p.label) }))
        current: page.profile
        onPicked: v => page.host.animProfileChosen(v)
      }
    }
  }
}
