// LauncherSettings — ubicación, imagen, tamaño y efectos del Launcher, como submenú de Ajustes (pestaña General → Launcher).

import Quickshell
import QtQuick
import QtQuick.Layouts
import "../COMMON"
import "../Services/Lang"

Item {
  id: root

  property bool open: false
  property string targetScreen: ""

  property int cardWidth: 420
  property int edgeMargin: 10
  readonly property int pad: 18

  signal closeRequested()
  signal backRequested()

  component Btn: SkinRect {
    id: btn
    property string text: ""
    property string icon: ""
    property bool primary: false
    signal clicked()

    implicitHeight: 34
    implicitWidth: btnRow.implicitWidth + 26
    Layout.preferredHeight: 34
    Layout.preferredWidth: btnRow.implicitWidth + 26
    radius: 10
    color: btn.primary
      ? (btnArea.containsMouse ? Qt.lighter(Theme.primary, 1.12) : Theme.primary)
      : (btnArea.containsMouse ? Theme.surfaceHigh : Theme.surface)
    Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }

    scale: btnArea.pressed ? 0.94 : 1.0
    Behavior on scale { NumberAnimation { duration: Theme.animDuration(140); easing.type: Easing.OutBack } }

    RowLayout {
      id: btnRow
      anchors.centerIn: parent
      spacing: 7
      Text {
        visible: btn.icon !== ""
        text: btn.icon
        color: btn.primary ? Theme.textOnPrimary : Theme.primary
        font.pixelSize: Theme.fs(15)
        font.family: Theme.monoFamily
      }
      Text {
        text: btn.text
        color: btn.primary ? Theme.textOnPrimary : Theme.text
        font.pixelSize: Theme.fs(12)
        font.bold: true
        font.family: Theme.fontFamily
      }
    }

    MouseArea {
      id: btnArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: btn.clicked()
    }
  }

  FusedWindow {
    id: fw
    active: root.open || panel.shown
    targetScreen: root.targetScreen
    namespace: "oozeshell-launcher-settings"
    onCloseRequested: root.closeRequested()

    FusedPanel {
      id: panel

      open: root.open
      panelWidth: root.cardWidth
      contentHeight: col.implicitHeight + root.pad * 2

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
          icon: "󰀻"
          title: Translations.t("settingsLauncherSection")
          onBackRequested: root.backRequested()
        }

        // ── Ubicación: en la barra / centrado ─────────────────
        SectionLabel { text: Translations.t("settingsLauncherPlacement") }

        RowLayout {
          Layout.fillWidth: true
          spacing: 10

          Btn {
            icon: "▀"
            text: Translations.t("settingsLauncherBar")
            primary: Theme.launcherAttached
            onClicked: Theme.setLauncherAttached(true)
          }
          Btn {
            icon: "▣"
            text: Translations.t("settingsLauncherCenter")
            primary: !Theme.launcherAttached
            onClicked: Theme.setLauncherAttached(false)
          }
          Item { Layout.fillWidth: true }
        }


        RowLayout {
          Layout.fillWidth: true
          spacing: 10

          Text {
            Layout.preferredWidth: Math.min(implicitWidth, 140)
            Layout.maximumWidth: 140
            elide: Text.ElideRight
            text: Translations.t("settingsLauncherImage")
            color: Theme.text
            font.bold: true
            font.pixelSize: Theme.fs(12)
            font.family: Theme.fontFamily
          }
          Btn {
            icon: Theme.launcherShowImage ? "▣" : "▢"
            text: Theme.launcherShowImage ? "ON" : "OFF"
            primary: Theme.launcherShowImage
            onClicked: Theme.setLauncherShowImage(!Theme.launcherShowImage)
          }
          Item { Layout.fillWidth: true }
        }


        RowLayout {
          Layout.fillWidth: true
          spacing: 10

          Text {
            Layout.preferredWidth: Math.min(implicitWidth, 140)
            Layout.maximumWidth: 140
            elide: Text.ElideRight
            text: Translations.t("settingsLauncherSize")
            color: Theme.text
            font.bold: true
            font.pixelSize: Theme.fs(12)
            font.family: Theme.fontFamily
          }
          Repeater {
            model: [
              { size: 0, label: "settingsSizeCompact" },
              { size: 1, label: "settingsSizeNormal" },
              { size: 2, label: "settingsSizeLarge" }
            ]
            delegate: Btn {
              required property var modelData
              text: Translations.t(modelData.label)
              primary: Theme.launcherSize === modelData.size
              onClicked: Theme.setLauncherSize(modelData.size)
            }
          }
          Item { Layout.fillWidth: true }
        }

        Text {
          Layout.fillWidth: true
          text: Translations.t("settingsLauncherHint")
          wrapMode: Text.WordWrap
          color: Theme.subtext
          font.pixelSize: Theme.fs(10)
          font.family: Theme.fontFamily
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }

        // ── Efectos del Launcher ──────────────────────────────


        SectionLabel { text: Translations.t("settingsEffectsSection") }

        RowLayout {
          Layout.fillWidth: true
          spacing: 10

          Text {
            Layout.preferredWidth: Math.min(implicitWidth, 140)
            Layout.maximumWidth: 140
            elide: Text.ElideRight
            text: Translations.t("settingsEffectsLabel")
            color: Theme.text
            font.bold: true
            font.pixelSize: Theme.fs(12)
            font.family: Theme.fontFamily
          }
          Btn {
            icon: "✦"
            text: Theme.effectsOn ? "ON" : "OFF"
            primary: Theme.effectsOn
            onClicked: Theme.setEffects(!Theme.effectsOn)
          }
          Item { Layout.fillWidth: true }
        }

        Text {
          Layout.fillWidth: true
          text: Translations.t("settingsEffectsHint")
          wrapMode: Text.WordWrap
          color: Theme.subtext
          font.pixelSize: Theme.fs(10)
          font.family: Theme.fontFamily
        }

        // ── Partículas y brillos (fancy) ──────────────────────


        RowLayout {
          Layout.fillWidth: true
          spacing: 10

          Text {
            Layout.preferredWidth: Math.min(implicitWidth, 140)
            Layout.maximumWidth: 140
            elide: Text.ElideRight
            text: Translations.t("settingsLauncherParticles")
            color: Theme.text
            font.bold: true
            font.pixelSize: Theme.fs(12)
            font.family: Theme.fontFamily
          }
          Btn {
            icon: "✦"
            text: Theme.launcherParticlesEnabled ? "ON" : "OFF"
            primary: Theme.launcherParticlesEnabled
            onClicked: Theme.setLauncherParticlesEnabled(!Theme.launcherParticlesEnabled)
          }
          Item { Layout.fillWidth: true }
        }

        Text {
          Layout.fillWidth: true
          text: Translations.t("settingsLauncherParticlesHint")
          wrapMode: Text.WordWrap
          color: Theme.subtext
          font.pixelSize: Theme.fs(10)
          font.family: Theme.fontFamily
        }

        // ── Wallpaper animado (gif) ───────────────────────────────


        RowLayout {
          Layout.fillWidth: true
          spacing: 10

          Text {
            Layout.preferredWidth: Math.min(implicitWidth, 140)
            Layout.maximumWidth: 140
            elide: Text.ElideRight
            text: Translations.t("settingsLauncherWallpaperLive")
            color: Theme.text
            font.bold: true
            font.pixelSize: Theme.fs(12)
            font.family: Theme.fontFamily
          }
          Btn {
            icon: "▶"
            text: Theme.launcherWallpaperLiveEnabled ? "ON" : "OFF"
            primary: Theme.launcherWallpaperLiveEnabled
            onClicked: Theme.setLauncherWallpaperLiveEnabled(!Theme.launcherWallpaperLiveEnabled)
          }
          Item { Layout.fillWidth: true }
        }

        Text {
          Layout.fillWidth: true
          text: Translations.t("settingsLauncherWallpaperLiveHint")
          wrapMode: Text.WordWrap
          color: Theme.subtext
          font.pixelSize: Theme.fs(10)
          font.family: Theme.fontFamily
        }
      }
    }
  }
}
