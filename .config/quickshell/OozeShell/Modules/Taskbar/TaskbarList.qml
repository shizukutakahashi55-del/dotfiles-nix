// TaskbarList — contenido del drop con la lista de ventanas (encabezado y filas). No dibuja fondo: lo aloja quien lo use.

import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import "../../COMMON"
import "../../Services/Lang"

Item {
  id: root

  property var windows: []

  property int maxListHeight: 420
  readonly property int pad: 12
  readonly property int rowHeight: 34

  property bool showClose: false
  signal closeRequested()

  implicitHeight: col.implicitHeight + root.pad * 2


  readonly property int desktopRevision: DesktopEntries.applications.values.length

  function iconFor(appId) {
    void root.desktopRevision
    const id = appId || ""
    const names = []
    if (id !== "") {
      const entry = DesktopEntries.heuristicLookup(id)
      if (entry && entry.icon) names.push(entry.icon)
      names.push(id, id.toLowerCase())
      const last = id.split(".").pop().toLowerCase()
      if (last !== id.toLowerCase()) names.push(last)
    }
    for (let i = 0; i < names.length; i++) {
      const n = names[i]
      if (!n) continue
      if (n.charAt(0) === "/") return "file://" + n
      const p = Quickshell.iconPath(n, true)
      if (p !== "") return p
    }
    return Quickshell.iconPath("application-x-executable", true)
  }


  function minimizeRaise(t) {
    if (t.activated && !t.minimized) {
      t.minimized = true
    } else {
      t.minimized = false
      t.activate()
    }
  }

      ColumnLayout {
        id: col
        x: root.pad
        y: root.pad
        width: parent.width - root.pad * 2
        spacing: 8

        // ── Encabezado ──────────────────────────────────────────
        RowLayout {
          Layout.fillWidth: true
          spacing: 10


          Rectangle {
            visible: root.showClose
            Layout.preferredWidth: 26
            Layout.preferredHeight: 26
            radius: 13
            color: backArea.containsMouse ? Theme.surfaceHigh : Theme.surface
            Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }

            Text {
              anchors.centerIn: parent
              text: "󰅁"
              color: Theme.text
              font.pixelSize: Theme.fs(14)
              font.family: Theme.monoFamily
            }
            MouseArea {
              id: backArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.closeRequested()
            }
          }

          Text {
            text: "󰖲"
            color: Theme.primary
            font.pixelSize: Theme.fs(16)
            font.family: Theme.monoFamily
          }

          Text {
            Layout.fillWidth: true
            text: Translations.t("taskbarWindows") + " (" + root.windows.length + ")"
            color: Theme.text
            font.bold: true
            font.pixelSize: Theme.fs(13)
            elide: Text.ElideRight
            font.family: Theme.fontFamily
          }
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }

        // ── Lista de ventanas ───────────────────────────────────
        Flickable {
          id: flick
          Layout.fillWidth: true
          Layout.preferredHeight: Math.min(list.implicitHeight, root.maxListHeight)
          contentWidth: width
          contentHeight: list.implicitHeight
          clip: true
          boundsBehavior: Flickable.StopAtBounds

          ColumnLayout {
            id: list
            width: flick.width
            spacing: 2

            Repeater {
              model: root.windows

              delegate: Rectangle {
                id: row
                required property var modelData

                readonly property string iconSrc: root.iconFor(modelData ? modelData.appId : "")

                Layout.fillWidth: true
                Layout.preferredHeight: root.rowHeight
                radius: 10
                color: (rowArea.containsMouse || row.modelData.activated) ? Theme.surface : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }

                RowLayout {
                  anchors.fill: parent
                  anchors.leftMargin: 10
                  anchors.rightMargin: 10
                  spacing: 10

                  Item {
                    Layout.preferredWidth: 18
                    Layout.preferredHeight: 18

                    IconImage {
                      anchors.fill: parent
                      visible: row.iconSrc !== ""
                      source: row.iconSrc
                      opacity: row.modelData.minimized ? 0.45 : 1.0
                    }


                    Text {
                      anchors.centerIn: parent
                      visible: row.iconSrc === ""
                      text: "󰀻"
                      color: Theme.subtext
                      font.pixelSize: Theme.fs(14)
                      font.family: Theme.monoFamily
                      opacity: row.modelData.minimized ? 0.45 : 1.0
                    }
                  }

                  Text {
                    Layout.fillWidth: true
                    text: row.modelData.title || row.modelData.appId
                    color: row.modelData.minimized ? Theme.subtext : Theme.text
                    font.pixelSize: Theme.fs(12)
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                  }


                  Rectangle {
                    visible: row.modelData.activated
                    Layout.preferredWidth: 6
                    Layout.preferredHeight: 6
                    radius: 3
                    color: Theme.primary
                  }
                }

                MouseArea {
                  id: rowArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

                  onClicked: mouse => {
                    const t = row.modelData
                    if (mouse.button === Qt.MiddleButton) {
                      t.close()
                    } else if (mouse.button === Qt.RightButton) {
                      root.minimizeRaise(t)
                    } else {
                      if (t.minimized) t.minimized = false
                      t.activate()
                      root.closeRequested()
                    }
                  }
                }
              }
            }
          }
        }
      }
}
