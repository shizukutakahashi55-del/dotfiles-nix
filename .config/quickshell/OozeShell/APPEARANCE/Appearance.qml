// OozeShell — Panel de Apariencia + Layouts, como submenú del Menu.
// Atajo de teclado (IPC):
//   quickshell ipc -p .../shell.qml call -- appearance toggle
import Quickshell
import QtQuick
import QtQuick.Layouts
import "../COMMON"
import "../LANG"

Item {
  id: root

  property bool open: false
  property var values: ({})          // snapshot de root.appearance
  property string currentLayout: "dwindle"
  property string targetScreen: ""

  property int cardWidth: 420
  property int edgeMargin: 10
  readonly property int pad: 18

  signal closeRequested()
  signal backRequested()

  // key = campo en root.appearance, real = nuevo valor
  signal previewChanged(string key, real value)
  signal valueCommitted(string key, real value)
  signal toggleChanged(string key, bool value)
  signal layoutChosen(string name)

  // Layouts, iconos y etiquetas según el WM (COMMON/WmAppearance.qml)
  readonly property var layoutOrder: WmAppearance.layoutNames
  readonly property var layoutIcons: WmAppearance.layoutIcons
  readonly property var layoutLabels: WmAppearance.layoutLabels

  // Lo que el WM actual no soporta no se muestra (WM.has en COMMON/WM.qml)
  function specAllowed(key) {
    switch (key) {
      case "gapsIn":            return WM.wm !== "niri"   // Niri: un solo gap (gaps out)
      case "activeOpacity":
      case "inactiveOpacity":   return WM.wm !== "niri"   // Niri: sin opacidad activa/inactiva
      case "blurSize":
      case "blurPasses":        return WM.has("blur")
      case "shadowRange":       return WM.has("shadow")
      case "shadowRenderPower": return WM.has("shadow") && WM.wm === "hyprland"
      default:                  return true
    }
  }
  readonly property var visibleSliders: root.sliderSpecs.filter(sp => root.specAllowed(sp.key))

  readonly property var toggleSpecs: {
    const out = []
    if (WM.has("blur"))   out.push({ key: "blurEnabled", label: Translations.t("appearanceBlur"), def: true })
    if (WmAppearance.hasBlurOptimized && WM.has("blur"))
      out.push({ key: "blurOptimized", label: Translations.t("appearanceBlurOpt"), def: true })
    if (WM.has("shadow")) out.push({ key: "shadowEnabled", label: Translations.t("appearanceShadow"), def: false })
    out.push({ key: "animationsEnabled", label: Translations.t("appearanceAnimations"), def: true })
    return out
  }

  // Sliders, en el orden en que se dibujan (2 columnas)
  readonly property var sliderSpecs: [
    { key: "gapsIn",          label: "Gaps in",          min: 0,   max: 30,  step: 1,    dec: 0, def: 3   },
    { key: "gapsOut",         label: "Gaps out",         min: 0,   max: 60,  step: 1,    dec: 0, def: 6   },
    { key: "borderSize",      label: "Border size",      min: 0,   max: 10,  step: 1,    dec: 0, def: 2   },
    { key: "rounding",        label: "Rounding",         min: 0,   max: 30,  step: 1,    dec: 0, def: 10  },
    { key: "activeOpacity",   label: "Active opacity",   min: 0.2, max: 1.0, step: 0.01, dec: 2, def: 1.0 },
    { key: "inactiveOpacity", label: "Inactive opacity", min: 0.2, max: 1.0, step: 0.01, dec: 2, def: 1.0 },
    { key: "blurSize",        label: "Blur size",        min: 0,   max: 15,  step: 1,    dec: 0, def: 3   },
    { key: "blurPasses",      label: "Blur passes",      min: 0,   max: 5,   step: 1,    dec: 0, def: 1   },
    { key: "shadowRange",     label: "Shadow range",     min: 0,   max: 50,  step: 1,    dec: 0, def: 3   },
    { key: "shadowRenderPower", label: "Shadow power",   min: 1,   max: 4,   step: 1,    dec: 0, def: 1   }
  ]

  // AppearanceSlider pide su paleta por propiedad: se la damos desde el
  // Theme (cambia sola al cambiar de wallpaper)
  readonly property var sliderColors: ({
    accent: Theme.primary,
    text: Theme.text,
    subtext: Theme.subtext,
    track: Theme.surfaceHigh
  })

  FusedWindow {
    id: fw
    active: root.open || panel.shown
    targetScreen: root.targetScreen
    namespace: "oozeshell-appearance"
    onCloseRequested: root.closeRequested()

    FusedPanel {
      id: panel

      open: root.open
      panelWidth: root.cardWidth
      contentHeight: col.implicitHeight + root.pad * 2

      // Cuelga de la barra, del lado de su botón (derecha si es horizontal,
      // abajo si es vertical). FusedPanel se coloca solo según Theme.barPosition.
      align: "end"
      alignMargin: root.edgeMargin + Theme.barEdge + Theme.frameSideArm

      ColumnLayout {
        id: col
        x: root.pad
        y: root.pad
        width: parent.width - root.pad * 2
        spacing: 14

        PanelHeader {
          Layout.fillWidth: true
          icon: "󰏘"
          title: Translations.t("appearanceTitle")
          onBackRequested: root.backRequested()
        }

        // ─── Sliders numéricos ───────────────────────────────
        GridLayout {
          Layout.fillWidth: true
          columns: 2
          columnSpacing: 18
          rowSpacing: 10

          Repeater {
            model: root.visibleSliders

            delegate: AppearanceSlider {
              Layout.fillWidth: true
              Layout.preferredWidth: 1
              Layout.preferredHeight: 44
              // sin efecto mientras la sombra está apagada: se atenúan
              opacity: (modelData.key.indexOf("shadow") === 0 && !(root.values.shadowEnabled ?? false)) ? 0.45 : 1
              Behavior on opacity { NumberAnimation { duration: Theme.animDuration(150) } }

              label: modelData.label
              keyName: modelData.key
              minValue: modelData.min
              maxValue: modelData.max
              stepValue: modelData.step
              decimals: modelData.dec
              value: root.values[modelData.key] ?? modelData.def
              colors: root.sliderColors

              onPreviewChanged: (k, v) => root.previewChanged(k, v)
              onCommitted: (k, v) => root.valueCommitted(k, v)
            }
          }
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }

        // ─── Toggles ─────────────────────────────────────────
        RowLayout {
          Layout.fillWidth: true
          spacing: 12

          Repeater {
            model: root.toggleSpecs

            delegate: Item {
              id: tog
              readonly property bool on: root.values[modelData.key] ?? modelData.def

              // partes iguales; si un texto no entra, se corta con "…"
              Layout.fillWidth: true
              Layout.preferredWidth: 1
              Layout.preferredHeight: 26

              RowLayout {
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: 8

                Rectangle {
                  Layout.preferredWidth: 34
                  Layout.preferredHeight: 20
                  radius: 10
                  color: tog.on ? Theme.primary : Theme.surfaceHigh
                  Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }

                  Rectangle {
                    width: 14
                    height: 14
                    radius: 7
                    anchors.verticalCenter: parent.verticalCenter
                    x: tog.on ? 17 : 3
                    color: tog.on ? Theme.textOnPrimary : Theme.subtext
                    Behavior on x { NumberAnimation { duration: Theme.animDuration(150); easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
                  }
                }

                Text {
                  Layout.fillWidth: true
                  text: modelData.label
                  color: Theme.text
                  font.pixelSize: Theme.fs(11)
                  font.family: Theme.fontFamily
                  elide: Text.ElideRight
                }
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleChanged(modelData.key, !tog.on)
              }
            }
          }
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }

        // ─── Layouts ─────────────────────────────────────────
        Text {
          text: Translations.t("appearanceLayout")
          color: Theme.text
          font.pixelSize: Theme.fs(12)
          font.bold: true
          font.family: Theme.fontFamily
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: 8

          Repeater {
            model: root.layoutOrder

            delegate: Rectangle {
              id: chip
              readonly property bool active: modelData === root.currentLayout

              Layout.fillWidth: true
              Layout.preferredWidth: 1
              Layout.preferredHeight: 50
              radius: 12
              color: active ? Theme.primary : (chipArea.containsMouse ? Theme.surfaceHigh : Theme.surface)
              Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }

              Column {
                anchors.centerIn: parent
                spacing: 3

                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: root.layoutIcons[modelData] ?? ""
                  color: chip.active ? Theme.textOnPrimary : Theme.text
                  font.pixelSize: Theme.fs(16)
                  font.family: Theme.fontFamily
                }
                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: root.layoutLabels[modelData] ?? modelData
                  color: chip.active ? Theme.textOnPrimary : Theme.subtext
                  font.pixelSize: Theme.fs(9)
                  font.family: Theme.fontFamily
                }
              }

              MouseArea {
                id: chipArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.layoutChosen(modelData)
              }
            }
          }
        }
      }
    }
  }
}
