// DisksSection — SYSTEM MONITOR

import QtQuick
import QtQuick.Layouts
import "../../COMMON"
import "../../Services/Lang"
import "../../Backends"

Item {
  id: root

  readonly property var m: SystemMonitor

  ListView {
    id: list
    anchors.fill: parent
    clip: true
    spacing: 12
    model: root.m.disks
    boundsBehavior: Flickable.StopAtBounds

    delegate: MonitorCard {
      id: diskCard
      required property var modelData

      readonly property real ratio: Math.max(0, Math.min(1, modelData.ratio))
      readonly property bool full: diskCard.ratio >= 0.9
      readonly property var rate: root.m.diskRate(modelData.name)

      width: list.width
      title: modelData.label || modelData.name
      icon: OozeIcons.disk
      accent: diskCard.full ? Theme.error : Theme.primary
      note: (modelData.kind || "") + (modelData.temp >= 0 ? " · " + modelData.temp + " °C" : "")

      Column {
        width: parent.width
        spacing: 10

        RowLayout {
          width: parent.width
          spacing: 8

          Item {
            Layout.preferredWidth: pctText.implicitWidth + pctUnit.implicitWidth + 3
            Layout.preferredHeight: pctText.implicitHeight

            Text {
              id: pctText
              text: diskCard.modelData.percent >= 0 ? Math.round(diskCard.modelData.percent) : "—"
              color: Theme.text
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fs(26)
              font.bold: true
            }
            Text {
              id: pctUnit
              visible: diskCard.modelData.percent >= 0
              text: "%"
              color: Theme.subtext
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fs(13)
              anchors.left: pctText.right
              anchors.leftMargin: 3
              anchors.baseline: pctText.baseline
            }
          }

          Item { Layout.fillWidth: true }

          Text {
            text: root.m.fmtSize(diskCard.modelData.used) + " / " + root.m.fmtSize(diskCard.modelData.size)
            color: Theme.subtext
            font.family: Theme.monoFamily
            font.pixelSize: Theme.fs(11)
          }
        }

        Rectangle {
          width: parent.width
          height: 8
          radius: 4
          color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.08)

          Rectangle {
            width: Math.max(parent.height, parent.width * diskCard.ratio)
            height: parent.height
            radius: parent.radius
            color: diskCard.full ? Theme.error : Theme.primary

            Behavior on width { NumberAnimation { duration: Theme.animDuration(260); easing.type: Easing.OutCubic } }
          }
        }

        Flow {
          width: parent.width
          spacing: 6

          MonitorChip { label: "↓ " + root.m.fmtRate(diskCard.rate.r) }
          MonitorChip { label: "↑ " + root.m.fmtRate(diskCard.rate.w) }
          MonitorChip {
            visible: !!diskCard.modelData.mount
            label: diskCard.modelData.mount || ""
          }
        }
      }
    }
  }

  Text {
    visible: root.m.disks.length === 0
    anchors.centerIn: parent
    text: Translations.t("sysmonNoData")
    color: Theme.subtext
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fs(11)
  }
}
