// SystemMonitorWindow — SYSTEM MONITOR
// Ventana de aplicación (FloatingWindow) abierta SOLO por bind/IPC.
// IPC objetivo: "sysmon" (ver Core/Ipc/SystemMonitorIpc.qml).

import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../COMMON"
import "../../Services/Lang"
import "../../Backends"

FloatingWindow {
  id: win

  readonly property var sections: [
    { k: "overview",  l: Translations.t("sysmonOverview"),  icon: OozeIcons.overview },
    { k: "processes", l: Translations.t("sysmonProcesses"), icon: OozeIcons.cpu },
    { k: "disks",     l: Translations.t("sysmonDisks"),     icon: OozeIcons.disk },
    { k: "network",   l: Translations.t("sysmonNetwork"),   icon: OozeIcons.network }
  ]

  visible: AppState.sysMonOpen
  title: "OozeShell — " + Translations.t("sysmonTitle")
  color: "transparent"
  screen: Quickshell.screens.find(s => s.name === AppState.sysMonScreen) ?? Quickshell.screens[0]
  implicitWidth: Math.round(980 * Theme.windowScale)
  implicitHeight: Math.round(640 * Theme.windowScale)
  minimumSize: Qt.size(Math.round(760 * Theme.windowScale), Math.round(480 * Theme.windowScale))

  function syncWanted() {
    SystemMonitor.setWanted("app", win.visible)
    ProcessList.setWanted("app", win.visible && AppState.sysMonSection === "processes")
  }

  Component.onCompleted: {
    SystemMonitor.intervalMs = 1000
    SystemMonitor.maxSamples = 60
    ProcessList.intervalMs = 1500
    ProcessList.limit = 500
    win.syncWanted()
  }
  onVisibleChanged: {
    win.syncWanted()
    if (win.visible) surface.forceActiveFocus()
  }
  Component.onDestruction: {
    SystemMonitor.setWanted("app", false)
    ProcessList.setWanted("app", false)
  }

  Connections {
    target: AppState
    function onSysMonSectionChanged() { win.syncWanted() }
  }

  Rectangle {
    id: surface
    anchors.fill: parent
    focus: true
    Keys.onEscapePressed: AppState.closeSystemMonitor()
    radius: Theme.panelRadius
    color: Theme.bg
    border.width: Theme.bw1
    border.color: Theme.edge

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: 18
      spacing: 16

      Item {
        id: header
        Layout.fillWidth: true
        implicitHeight: 40

        RowLayout {
          anchors.fill: parent
          spacing: 12

          Item {
            implicitWidth: titleRow.implicitWidth
            implicitHeight: parent.height

            Row {
              id: titleRow
              anchors.verticalCenter: parent.verticalCenter
              spacing: 11

              Rectangle {
                width: 36
                height: 36
                radius: Theme.cardRadius
                color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16)
                anchors.verticalCenter: parent.verticalCenter

                Text {
                  anchors.centerIn: parent
                  text: OozeIcons.performance
                  color: Theme.primary
                  font.family: Theme.monoFamily
                  font.pixelSize: Theme.fs(17)
                }
              }

              Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Text {
                  text: Translations.t("sysmonTitle")
                  color: Theme.text
                  font.family: Theme.fontFamily
                  font.pixelSize: Theme.fs(15)
                  font.bold: true
                }
                Text {
                  visible: text !== ""
                  text: SystemMonitor.hostname + (SystemMonitor.kernel !== "" ? " · " + SystemMonitor.kernel : "")
                  color: Theme.subtext
                  font.family: Theme.monoFamily
                  font.pixelSize: Theme.fs(9)
                }
              }
            }

            MouseArea {
              anchors.fill: parent
              acceptedButtons: Qt.LeftButton | Qt.RightButton
              onPressed: win.startSystemMove()
            }
          }

          MonitorChip {
            label: SystemMonitor.backend + " · " + ProcessList.backend
            Layout.alignment: Qt.AlignVCenter
          }

          Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            MouseArea {
              anchors.fill: parent
              acceptedButtons: Qt.LeftButton | Qt.RightButton
              onPressed: win.startSystemMove()
            }
          }

          SegmentedControl {
            Layout.alignment: Qt.AlignVCenter
            model: win.sections
            current: AppState.sysMonSection
            onPicked: function (key) { AppState.sysMonSection = key }
          }

          Rectangle {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 32
            implicitHeight: 32
            radius: Theme.cardRadius
            color: closeArea.containsMouse ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.2) : Theme.surface
            border.width: Theme.bw1
            border.color: closeArea.containsMouse ? "transparent" : Theme.divider

            Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }

            Text {
              anchors.centerIn: parent
              text: OozeIcons.close
              color: closeArea.containsMouse ? Theme.error : Theme.subtext
              font.family: Theme.monoFamily
              font.pixelSize: Theme.fs(12)
            }
            MouseArea {
              id: closeArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: AppState.closeSystemMonitor()
            }
          }
        }
      }

      Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        OverviewSection {
          anchors.fill: parent
          opacity: AppState.sysMonSection === "overview" ? 1 : 0
          visible: opacity > 0.01
          Behavior on opacity { NumberAnimation { duration: Theme.animDuration(160) } }
        }
        ProcessesSection {
          anchors.fill: parent
          opacity: AppState.sysMonSection === "processes" ? 1 : 0
          visible: opacity > 0.01
          Behavior on opacity { NumberAnimation { duration: Theme.animDuration(160) } }
        }
        DisksSection {
          anchors.fill: parent
          opacity: AppState.sysMonSection === "disks" ? 1 : 0
          visible: opacity > 0.01
          Behavior on opacity { NumberAnimation { duration: Theme.animDuration(160) } }
        }
        NetworkSection {
          anchors.fill: parent
          opacity: AppState.sysMonSection === "network" ? 1 : 0
          visible: opacity > 0.01
          Behavior on opacity { NumberAnimation { duration: Theme.animDuration(160) } }
        }
      }
    }

    MouseArea {
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      width: 18
      height: 18
      cursorShape: Qt.SizeFDiagCursor
      onPressed: win.startSystemResize(Qt.RightEdge | Qt.BottomEdge)
    }
  }
}
