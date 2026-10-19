// NetworkSection — SYSTEM MONITOR

import QtQuick
import QtQuick.Layouts
import "../../COMMON"
import "../../Services/Lang"
import "../Menu"
import "../../Backends"

Item {
  id: root

  readonly property var m: SystemMonitor
  readonly property color downAccent: Theme.primary
  readonly property color upAccent: Qt.hsla((Theme.primary.hslHue + 0.42) % 1,
    Math.max(0.4, Theme.primary.hslSaturation), 0.62, 1)

  Column {
    anchors.fill: parent
    spacing: 12

    RowLayout {
      width: parent.width
      spacing: 12

      MonitorCard {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 1
        title: Translations.t("sysmonDown")
        icon: "↓"
        accent: root.downAccent

        Column {
          width: parent.width
          spacing: 8
          Text {
            text: root.m.fmtRate(root.m.netDown)
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fs(28)
            font.bold: true
          }
          Sparkline {
            width: parent.width
            height: 64
            values: root.m.netDownGraph
            maxSamples: 60
            maxValue: 100
            fitData: true
            gradientArea: true
            lineColor: root.downAccent
            areaAlpha: 0.16
          }
        }
      }

      MonitorCard {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 1
        title: Translations.t("sysmonUp")
        icon: "↑"
        accent: root.upAccent

        Column {
          width: parent.width
          spacing: 8
          Text {
            text: root.m.fmtRate(root.m.netUp)
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fs(28)
            font.bold: true
          }
          Sparkline {
            width: parent.width
            height: 64
            values: root.m.netUpGraph
            maxSamples: 60
            maxValue: 100
            fitData: true
            gradientArea: true
            lineColor: root.upAccent
            areaAlpha: 0.16
          }
        }
      }
    }

    MonitorCard {
      width: parent.width
      title: Translations.t("sysmonIface")
      icon: OozeIcons.network
      accent: Theme.primary

      RowLayout {
        width: parent.width
        spacing: 8

        Text {
          text: root.m.netIface !== "" ? root.m.netIface : "—"
          color: Theme.text
          font.family: Theme.monoFamily
          font.pixelSize: Theme.fs(13)
          font.bold: true
        }

        Item { Layout.fillWidth: true }

        MonitorChip { label: "↓ " + root.m.fmtRate(root.m.netDown); tint: root.downAccent }
        MonitorChip { label: "↑ " + root.m.fmtRate(root.m.netUp); tint: root.upAccent }
      }
    }
  }
}
