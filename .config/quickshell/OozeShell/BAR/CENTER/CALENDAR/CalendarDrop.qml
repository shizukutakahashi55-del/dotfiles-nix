// CalendarDrop — calendario que cuelga del reloj de la barra.
//

import QtQuick
import QtQuick.Layouts
import "../../../COMMON"

FusedPanel {
  id: cal

  panelWidth: 268
  contentHeight: col.implicitHeight + pad * 2

  readonly property int pad: 14
  readonly property real cellW: (panelWidth - pad * 2 - 6 * 4) / 7
  readonly property var dayLetters: ["L", "M", "X", "J", "V", "S", "D"]

  property var today: new Date()
  property int monthOffset: 0

  readonly property var viewDate: new Date(today.getFullYear(), today.getMonth() + monthOffset, 1)

  onOpenChanged: {
    if (open) {
      today = new Date()
      monthOffset = 0
    }
  }

  function daysInMonth(y, m) { return new Date(y, m + 1, 0).getDate() }
  // Lunes = 0 ... Domingo = 6
  function firstWeekdayOffset(y, m) { return (new Date(y, m, 1).getDay() + 6) % 7 }

  property var calCells: {
    const y = viewDate.getFullYear()
    const m = viewDate.getMonth()
    const total = daysInMonth(y, m)
    const offset = firstWeekdayOffset(y, m)
    const cells = []
    for (let i = 0; i < offset; i++) cells.push(0)
    for (let d = 1; d <= total; d++) cells.push(d)
    return cells
  }

  readonly property bool viewingCurrentMonth: monthOffset === 0

  ColumnLayout {
    id: col
    x: cal.pad
    y: cal.pad
    width: parent.width - cal.pad * 2
    spacing: 8

    // ── Mes / año + flechas ──────────────────────────────────
    RowLayout {
      Layout.fillWidth: true
      spacing: 4

      Rectangle {
        Layout.preferredWidth: 26
        Layout.preferredHeight: 26
        radius: 8
        color: prevArea.containsMouse ? Theme.surface : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }
        Text {
          anchors.centerIn: parent
          text: "󰅁"
          color: Theme.text
          font.pixelSize: Theme.fs(15)
          font.family: Theme.monoFamily
        }
        MouseArea {
          id: prevArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: cal.monthOffset -= 1
        }
      }

      Text {
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        text: {
          const t = Qt.formatDate(cal.viewDate, "MMMM yyyy")
          return t.charAt(0).toUpperCase() + t.slice(1)
        }
        color: cal.viewingCurrentMonth ? Theme.text : Theme.primary
        font.pixelSize: Theme.fs(12)
        font.bold: true
        font.family: Theme.fontFamily
        Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: cal.monthOffset = 0
        }
      }

      Rectangle {
        Layout.preferredWidth: 26
        Layout.preferredHeight: 26
        radius: 8
        color: nextArea.containsMouse ? Theme.surface : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }
        Text {
          anchors.centerIn: parent
          text: "󰅂"
          color: Theme.text
          font.pixelSize: Theme.fs(15)
          font.family: Theme.monoFamily
        }
        MouseArea {
          id: nextArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: cal.monthOffset += 1
        }
      }
    }

    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }

    GridLayout {
      Layout.fillWidth: true
      columns: 7
      columnSpacing: 4
      rowSpacing: 4

      Repeater {
        model: cal.dayLetters
        delegate: Text {
          Layout.preferredWidth: cal.cellW
          horizontalAlignment: Text.AlignHCenter
          text: modelData
          color: Theme.subtext
          font.pixelSize: Theme.fs(10)
          font.family: Theme.monoFamily
        }
      }

      Repeater {
        model: cal.calCells
        delegate: Rectangle {
          readonly property bool isToday: cal.viewingCurrentMonth && modelData === cal.today.getDate()

          Layout.preferredWidth: cal.cellW
          Layout.preferredHeight: 26
          radius: 8
          color: isToday ? Theme.primary : "transparent"

          Text {
            anchors.centerIn: parent
            text: modelData === 0 ? "" : modelData
            color: parent.isToday ? Theme.textOnPrimary : Theme.text
            font.pixelSize: Theme.fs(11)
            font.bold: parent.isToday
            font.family: Theme.fontFamily
          }
        }
      }
    }
  }
}
