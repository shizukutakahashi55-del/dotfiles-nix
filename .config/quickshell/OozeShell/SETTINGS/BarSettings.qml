// BarSettings — posición de la barra y modo flotante, como submenú de Ajustes (pestaña General → Barra).

import Quickshell
import QtQuick
import QtQuick.Layouts
import "../COMMON"
import "../LANG"

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
    namespace: "oozeshell-bar-settings"
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
          icon: "▀"
          title: Translations.t("barSection")
          onBackRequested: root.backRequested()
        }

        Text {
          Layout.fillWidth: true
          text: Translations.t("barSectionHint")
          wrapMode: Text.WordWrap
          color: Theme.subtext
          font.pixelSize: Theme.fs(10)
          font.family: Theme.fontFamily
        }

        SectionLabel { text: Translations.t("barPosition") }

        RowLayout {
          Layout.fillWidth: true
          spacing: 10

          Btn {
            icon: "▀"
            text: Translations.t("barTop")
            primary: Theme.barPosition === "top"
            onClicked: Theme.setBarPosition("top")
          }
          Btn {
            icon: "▄"
            text: Translations.t("barBottom")
            primary: Theme.barPosition === "bottom"
            onClicked: Theme.setBarPosition("bottom")
          }
          Item { Layout.fillWidth: true }
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: 10

          Btn {
            icon: "▌"
            text: Translations.t("barLeft")
            primary: Theme.barPosition === "left"
            onClicked: Theme.setBarPosition("left")
          }
          Btn {
            icon: "▐"
            text: Translations.t("barRight")
            primary: Theme.barPosition === "right"
            onClicked: Theme.setBarPosition("right")
          }
          Item { Layout.fillWidth: true }
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }

        SectionLabel { text: Translations.t("barFloating") }

        RowLayout {
          Layout.fillWidth: true
          spacing: 10


          Btn {
            icon: Theme.barFloatingPref ? "▣" : "▢"
            text: Theme.barFloatingPref ? "ON" : "OFF"
            primary: Theme.barFloatingPref
            opacity: Theme.barVertical ? 0.4 : 1.0
            onClicked: { if (!Theme.barVertical) Theme.setBarFloating(!Theme.barFloatingPref) }
          }
          Item { Layout.fillWidth: true }
        }

        Text {
          Layout.fillWidth: true
          text: Theme.barVertical ? Translations.t("barFloatingOnlyH")
                                  : Translations.t("barFloatingHint")
          wrapMode: Text.WordWrap
          color: Theme.subtext
          font.pixelSize: Theme.fs(10)
          font.family: Theme.fontFamily
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }

        // ── Islas ──────────────────────────────────────────────


        SectionLabel { text: Translations.t("barIslands") }

        RowLayout {
          Layout.fillWidth: true
          spacing: 10

          Btn {
            icon: Theme.islandsPref ? "◖◗" : "▬"
            text: Theme.islandsPref ? "ON" : "OFF"
            primary: Theme.islandsPref
            opacity: Theme.barVertical ? 0.4 : 1.0
            onClicked: { if (!Theme.barVertical) Theme.setIslandsEnabled(!Theme.islandsPref) }
          }
          Item { Layout.fillWidth: true }
        }

        Text {
          Layout.fillWidth: true
          text: Theme.barVertical ? Translations.t("barIslandsOnlyH")
                                  : Translations.t("barIslandsHint")
          wrapMode: Text.WordWrap
          color: Theme.subtext
          font.pixelSize: Theme.fs(10)
          font.family: Theme.fontFamily
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }

        // ── Píldora ────────────────────────────────────────────


        SectionLabel { text: Translations.t("barPillMode") }

        RowLayout {
          Layout.fillWidth: true
          spacing: 10

          Btn {
            icon: Theme.pillModePref ? "💊" : "▬"
            text: Theme.pillModePref ? "ON" : "OFF"
            primary: Theme.pillModePref
            opacity: Theme.barVertical ? 0.4 : 1.0
            onClicked: { if (!Theme.barVertical) Theme.setPillModeEnabled(!Theme.pillModePref) }
          }
          Item { Layout.fillWidth: true }
        }


        RowLayout {
          Layout.fillWidth: true
          spacing: 10
          visible: Theme.pillMode

          Text {
            text: Translations.t("barPillAutoHide")
            color: Theme.text
            font.pixelSize: Theme.fs(12)
            font.family: Theme.fontFamily
          }
          Item { Layout.fillWidth: true }
          Btn {
            icon: Theme.pillAutoHidePref ? "󰈈" : "󰈉"
            text: Theme.pillAutoHidePref ? "ON" : "OFF"
            primary: Theme.pillAutoHidePref
            onClicked: Theme.setPillAutoHide(!Theme.pillAutoHidePref)
          }
        }


        RowLayout {
          Layout.fillWidth: true
          spacing: 10
          visible: Theme.pillMode && Theme.pillAutoHidePref

          Text {
            text: Translations.t("barPillTraySync")
            color: Theme.text
            font.pixelSize: Theme.fs(12)
            font.family: Theme.fontFamily
          }
          Item { Layout.fillWidth: true }
          Btn {
            icon: Theme.pillTraySyncPref ? "󰌷" : "󰌸"
            text: Theme.pillTraySyncPref ? "ON" : "OFF"
            primary: Theme.pillTraySyncPref
            onClicked: Theme.setPillTraySync(!Theme.pillTraySyncPref)
          }
        }

        Text {
          Layout.fillWidth: true
          text: Theme.barVertical ? Translations.t("barIslandsOnlyH")
                                  : Translations.t("barPillModeHint")
          wrapMode: Text.WordWrap
          color: Theme.subtext
          font.pixelSize: Theme.fs(10)
          font.family: Theme.fontFamily
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }

        // ── Batería (BAR/RIGHT/RightModules.qml) ────────────────


        SectionLabel { text: Translations.t("batterySection") }

        RowLayout {
          Layout.fillWidth: true
          spacing: 10

          Btn {
            icon: Theme.batteryEnabled ? "󰂄" : "󰂎"
            text: Theme.batteryEnabled ? "ON" : "OFF"
            primary: Theme.batteryEnabled
            onClicked: Theme.setBatteryEnabled(!Theme.batteryEnabled)
          }
          Item { Layout.fillWidth: true }
        }

        Text {
          Layout.fillWidth: true
          text: Translations.t("batteryHint")
          wrapMode: Text.WordWrap
          color: Theme.subtext
          font.pixelSize: Theme.fs(10)
          font.family: Theme.fontFamily
        }
      }
    }
  }
}
