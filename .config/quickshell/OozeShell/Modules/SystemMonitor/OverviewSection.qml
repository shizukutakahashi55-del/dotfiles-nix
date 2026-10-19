// OverviewSection — SYSTEM MONITOR

import QtQuick
import QtQuick.Layouts
import "../../COMMON"
import "../../Services/Lang"
import "../../Backends"

Item {
  id: root

  readonly property var m: SystemMonitor

  function shifted(c, d) {
    const h = c.hslHue < 0 ? 0 : c.hslHue
    return Qt.hsla((h + d + 1) % 1, Math.max(0.35, c.hslSaturation),
                   Math.max(0.5, Math.min(0.72, c.hslLightness)), 1)
  }

  readonly property color ramAccent: root.shifted(Theme.primary, 0.14)
  readonly property color gpuAccent: root.shifted(Theme.primary, -0.16)

  function tempText(t) { return t >= 0 ? Math.round(t) + " °C" : "" }

  Flickable {
    anchors.fill: parent
    clip: true
    contentWidth: width
    contentHeight: col.implicitHeight
    boundsBehavior: Flickable.StopAtBounds

    Column {
      id: col
      width: parent.width
      spacing: 12

      RowLayout {
        width: parent.width
        spacing: 12

        MonitorCard {
          Layout.fillWidth: true
          Layout.fillHeight: true
          Layout.preferredWidth: 1
          title: Translations.t("sysmonCpu")
          icon: OozeIcons.cpu
          accent: Theme.primary
          note: root.tempText(root.m.cpuTemp)

          MonitorMetric {
            width: parent.width
            valueText: Math.round(root.m.cpu)
            unit: "%"
            history: root.m.cpuHistory
            accent: Theme.primary
            sub: root.m.cpuFreqMhz > 0
              ? Math.round(root.m.cpuFreqMhz) + " MHz · " + Translations.t("sysmonCores") + " " + root.m.cores.length
              : Translations.t("sysmonCores") + " " + root.m.cores.length
          }
        }

        MonitorCard {
          Layout.fillWidth: true
          Layout.fillHeight: true
          Layout.preferredWidth: 1
          title: Translations.t("sysmonRam")
          icon: OozeIcons.memory
          accent: root.ramAccent

          MonitorMetric {
            width: parent.width
            valueText: Math.round(root.m.ram)
            unit: "%"
            history: root.m.ramHistory
            accent: root.ramAccent
            sub: root.m.ramUsedGb.toFixed(1) + " / " + root.m.ramTotalGb.toFixed(1) + " GiB"
          }
        }

        MonitorCard {
          Layout.fillWidth: true
          Layout.fillHeight: true
          Layout.preferredWidth: 1
          title: Translations.t("sysmonGpu")
          icon: OozeIcons.gpu
          accent: root.gpuAccent
          note: root.tempText(root.m.gpuTemp)

          MonitorMetric {
            width: parent.width
            valueText: root.m.gpuAvailable ? Math.round(root.m.gpu) : "—"
            unit: "%"
            history: root.m.gpuHistory
            accent: root.gpuAccent
            unavailable: !root.m.gpuAvailable
            sub: root.m.gpuAvailable
              ? (root.m.gpuName !== "" ? root.m.gpuName : "")
                  + (root.m.gpuVramTotalMb > 0
                     ? " · " + (root.m.gpuVramUsedMb / 1024).toFixed(1) + " / "
                       + (root.m.gpuVramTotalMb / 1024).toFixed(1) + " GiB"
                     : "")
              : Translations.t("sysmonNoGpu")
          }
        }
      }

      MonitorCard {
        width: parent.width
        title: Translations.t("sysmonCores")
        icon: OozeIcons.cpu
        accent: Theme.primary

        GridLayout {
          width: parent.width
          columns: Math.max(1, Math.floor(width / 32))
          columnSpacing: 6
          rowSpacing: 8

          Repeater {
            model: root.m.cores

            delegate: Item {
              id: core
              required property int index
              required property real modelData

              Layout.preferredWidth: 26
              Layout.preferredHeight: 56

              Rectangle {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: 14
                height: parent.height - 16
                radius: 4
                color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.07)

                Rectangle {
                  anchors.bottom: parent.bottom
                  width: parent.width
                  radius: parent.radius
                  height: Math.max(parent.width, parent.height * Math.max(0, Math.min(100, core.modelData)) / 100)
                  opacity: core.modelData > 0.5 ? 1 : 0.25
                  color: core.modelData >= 85 ? Theme.error : Theme.primary

                  Behavior on height { NumberAnimation { duration: Theme.animDuration(260); easing.type: Easing.OutCubic } }
                  Behavior on color { ColorAnimation { duration: Theme.animDuration(200) } }
                }
              }

              Text {
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                text: core.index
                color: Theme.subtext
                font.family: Theme.monoFamily
                font.pixelSize: Theme.fs(8)
              }
            }
          }
        }
      }

      MonitorCard {
        width: parent.width
        title: Translations.t("sysmonSystem")
        icon: OozeIcons.hint
        accent: Theme.primary

        GridLayout {
          width: parent.width
          columns: 2
          columnSpacing: 24
          rowSpacing: 6

          Repeater {
            model: [
              { k: Translations.t("sysmonLoad"), v: root.m.load1 >= 0
                    ? root.m.load1.toFixed(2) + "  " + root.m.load5.toFixed(2) + "  " + root.m.load15.toFixed(2)
                    : "—" },
              { k: Translations.t("sysmonSwap"), v: root.m.swapTotalGb >= 0
                    ? root.m.swapUsedGb.toFixed(1) + " / " + root.m.swapTotalGb.toFixed(1) + " GiB"
                    : "—" },
              { k: Translations.t("sysmonHost"), v: root.m.hostname !== "" ? root.m.hostname : "—" },
              { k: Translations.t("sysmonKernel"), v: root.m.kernel !== "" ? root.m.kernel : "—" }
            ]

            delegate: RowLayout {
              id: cell
              required property var modelData
              spacing: 8
              Text {
                text: cell.modelData.k
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fs(10)
                Layout.preferredWidth: 96
              }
              Text {
                text: cell.modelData.v
                color: Theme.text
                font.family: Theme.monoFamily
                font.pixelSize: Theme.fs(11)
              }
            }
          }
        }
      }
    }
  }
}
