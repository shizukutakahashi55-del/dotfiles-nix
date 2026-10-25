// ProcessesSection — SYSTEM MONITOR

import QtQuick
import QtQuick.Layouts
import "../../COMMON"
import "../../Services/Lang"
import "../../Backends"

Item {
  id: root

  readonly property var p: ProcessList
  readonly property var sys: SystemMonitor

  property string cpuMode: "total"
  property int armedPid: -1

  readonly property int pidW: 68
  readonly property int userW: 112
  readonly property int cpuW: 130
  readonly property int memW: 136
  readonly property int actW: 40
  readonly property int rowH: 32
  readonly property int nameW: Math.max(80, list.width - pidW - userW - cpuW - memW - actW)
  readonly property real memTotal: Math.max(1, root.sys.ramTotalMb)

  readonly property int hoverIdx: listHover.hovered
    ? list.indexAt(listHover.point.position.x, listHover.point.position.y + list.contentY) : -1
  readonly property int hoverPid: root.hoverIdx >= 0 && root.hoverIdx < root.p.rows.length
    ? root.p.rows[root.hoverIdx].pid : -1

  function fmtMem(mb) {
    return mb >= 1024 ? (mb / 1024).toFixed(1) + " G" : Math.round(mb) + " M"
  }

  function arrow(k) {
    return k === "pid" || k === "name" ? " ↑" : " ↓"
  }

  Timer {
    id: disarm
    interval: 3000
    onTriggered: root.armedPid = -1
  }

  RowLayout {
    id: toolbar
    anchors { top: parent.top; left: parent.left; right: parent.right }
    height: implicitHeight
    spacing: 10

    Text {
      text: root.p.total + " " + Translations.t("sysmonProcesses")
      color: Theme.subtext
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fs(11)
    }

    Item { Layout.fillWidth: true }

    SegmentedControl {
      itemHeight: 22
      hPad: 10
      fontSize: 10
      model: [
        { k: "total", l: Translations.t("sysmonCpuTotal") },
        { k: "core", l: Translations.t("sysmonCpuCore") }
      ]
      current: root.cpuMode
      onPicked: function (key) { root.cpuMode = key }
    }

    SegmentedControl {
      itemHeight: 22
      hPad: 10
      fontSize: 10
      model: [
        { k: "cpu", l: Translations.t("sysmonSortCpu") },
        { k: "mem", l: Translations.t("sysmonSortMem") },
        { k: "pid", l: Translations.t("sysmonSortPid") },
        { k: "name", l: Translations.t("sysmonSortName") }
      ]
      current: root.p.sortBy
      onPicked: function (key) { root.p.sortBy = key }
    }
  }

  Rectangle {
    id: table
    anchors { top: toolbar.bottom; topMargin: 12; left: parent.left; right: parent.right; bottom: parent.bottom }
    radius: Theme.cardRadius
    color: Theme.surface
    border.width: Theme.bw1
    border.color: Theme.divider
    clip: true

    Item {
      id: header
      anchors { top: parent.top; topMargin: 10; left: parent.left; leftMargin: 14; right: parent.right; rightMargin: 14 }
      height: 22

      Row {
        anchors.fill: parent

        Repeater {
          model: [
            { k: "pid", l: "PID", w: root.pidW },
            { k: "", l: Translations.t("sysmonUser"), w: root.userW },
            { k: "cpu", l: "CPU", w: root.cpuW },
            { k: "mem", l: "MEM", w: root.memW },
            { k: "name", l: Translations.t("sysmonName"), w: root.nameW }
          ]

          delegate: Item {
            id: col
            required property var modelData

            readonly property bool on: col.modelData.k !== "" && root.p.sortBy === col.modelData.k

            width: col.modelData.w
            height: header.height

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: col.modelData.l + (col.on ? root.arrow(col.modelData.k) : "")
              color: col.on ? Theme.primary : Theme.subtext
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fs(10)
              font.bold: true
              font.letterSpacing: 0.6
            }

            MouseArea {
              anchors.fill: parent
              enabled: col.modelData.k !== ""
              cursorShape: Qt.PointingHandCursor
              onClicked: root.p.sortBy = col.modelData.k
            }
          }
        }
      }
    }

    Rectangle {
      id: headerLine
      anchors { top: header.bottom; topMargin: 6; left: parent.left; leftMargin: 10; right: parent.right; rightMargin: 10 }
      height: 1
      color: Theme.divider
    }

    Item {
      id: listWrap
      anchors {
        top: headerLine.bottom
        topMargin: 4
        left: parent.left
        leftMargin: 10
        right: parent.right
        rightMargin: 10
        bottom: parent.bottom
        bottomMargin: 8
      }

      HoverHandler { id: listHover }

      ListView {
        id: list
        anchors.fill: parent
        clip: true
        spacing: 1
        model: root.p.rows
        boundsBehavior: Flickable.StopAtBounds
        cacheBuffer: 400

        delegate: Item {
          id: row
          required property var modelData
          required property int index

          readonly property bool hovered: root.hoverPid === row.modelData.pid
          readonly property bool armed: root.armedPid === row.modelData.pid
          readonly property real cpuRaw: row.modelData.cpu || 0
          readonly property real cpuShown: root.cpuMode === "total"
            ? row.cpuRaw / Math.max(1, root.p.numCores) : row.cpuRaw
          readonly property real memMb: row.modelData.memMb || 0
          readonly property bool hot: row.cpuRaw >= 80

          width: list.width
          height: root.rowH

          Rectangle {
            anchors.fill: parent
            radius: Math.max(3, Theme.cardRadius - 4)
            color: row.armed ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.16)
                 : (row.hovered ? Theme.surfaceHigh : "transparent")
          }

          Row {
            anchors.fill: parent
            anchors.leftMargin: 4

            Text {
              width: root.pidW; height: parent.height; verticalAlignment: Text.AlignVCenter
              text: row.modelData.pid
              color: Theme.subtext
              font.family: Theme.monoFamily
              font.pixelSize: Theme.fs(10)
            }

            Text {
              width: root.userW; height: parent.height; verticalAlignment: Text.AlignVCenter
              text: row.modelData.user
              elide: Text.ElideRight
              color: Theme.subtext
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fs(10)
            }

            Item {
              width: root.cpuW
              height: parent.height

              Text {
                id: cpuText
                width: 52
                height: parent.height
                verticalAlignment: Text.AlignVCenter
                text: row.cpuShown.toFixed(1) + "%"
                color: row.hot ? Theme.error : Theme.text
                font.family: Theme.monoFamily
                font.pixelSize: Theme.fs(10)
              }

              Rectangle {
                anchors.left: cpuText.right
                anchors.leftMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                width: root.cpuW - 52 - 6 - 16
                height: 4
                radius: 2
                color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.08)

                Rectangle {
                  width: parent.width * Math.max(0, Math.min(1, row.cpuShown / 100))
                  height: parent.height
                  radius: parent.radius
                  color: row.hot ? Theme.error : Theme.primary
                }
              }
            }

            Item {
              width: root.memW
              height: parent.height

              Text {
                id: memText
                width: 56
                height: parent.height
                verticalAlignment: Text.AlignVCenter
                text: root.fmtMem(row.memMb)
                color: Theme.text
                font.family: Theme.monoFamily
                font.pixelSize: Theme.fs(10)
              }

              Rectangle {
                anchors.left: memText.right
                anchors.leftMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                width: root.memW - 56 - 6 - 16
                height: 4
                radius: 2
                color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.08)

                Rectangle {
                  width: parent.width * Math.max(0, Math.min(1, row.memMb / root.memTotal))
                  height: parent.height
                  radius: parent.radius
                  color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.7)
                }
              }
            }

            Text {
              width: root.nameW; height: parent.height; verticalAlignment: Text.AlignVCenter
              text: row.modelData.name
              elide: Text.ElideRight
              color: Theme.text
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fs(11)
            }
          }

          Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            width: 28
            height: 22
            radius: 6
            opacity: row.hovered || row.armed ? 1 : 0
            color: row.armed ? Theme.error : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.1)

            Behavior on opacity { NumberAnimation { duration: Theme.animDuration(120) } }

            Text {
              anchors.centerIn: parent
              text: row.armed ? OozeIcons.confirm : OozeIcons.trash
              color: row.armed ? Theme.textOnError : Theme.subtext
              font.family: Theme.monoFamily
              font.pixelSize: Theme.fs(11)
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (root.armedPid === row.modelData.pid) {
                  root.p.kill(row.modelData.pid, 15)
                  root.armedPid = -1
                  disarm.stop()
                } else {
                  root.armedPid = row.modelData.pid
                  disarm.restart()
                }
              }
            }
          }
        }
      }
    }
  }
}
