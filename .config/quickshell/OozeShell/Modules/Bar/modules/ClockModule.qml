// ClockModule — reloj. Al pasar el mouse abre el calendario (BarCalendar, dibujado por CenterModules); clic derecho abre la agenda.

import QtQuick
import QtQuick.Layouts

import "../../../COMMON"

BarFlow {
  id: mod

  property var host: null
  readonly property bool shown: true

  readonly property bool calOpen: BarCalendar.isOpen(mod.host.screenName)

  Rectangle {
    id: clockButton

    property var now: new Date()

    Layout.preferredWidth: Theme.barVertical ? 40 : 70
    Layout.preferredHeight: Theme.barVertical ? 44 : 30

    radius: Theme.cardRadius
    color: (clockMouse.containsMouse || mod.calOpen) ? Theme.surface : "transparent"

    Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }

    scale: clockMouse.pressed
      ? 0.90
      : clockMouse.containsMouse ? 1.04 : 1.0

    Behavior on scale {
      NumberAnimation { duration: Theme.animDuration(160); easing.type: Easing.OutBack }
    }

    Text {
      id: clockText

      anchors.centerIn: parent

      text: Theme.barVertical
        ? Qt.formatTime(clockButton.now, "HH") + "\n" + Qt.formatTime(clockButton.now, "mm")
        : Qt.formatTime(clockButton.now, "HH:mm")

      horizontalAlignment: Text.AlignHCenter
      lineHeight: 0.9

      color: Theme.text

      font.family: Theme.fontFamily
      font.pixelSize: Theme.fs(15)

      Timer {
        interval: 1000
        running: true
        repeat: true

        onTriggered: clockButton.now = new Date()
      }
    }

    MouseArea {
      id: clockMouse

      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      acceptedButtons: Qt.LeftButton | Qt.RightButton

      onEntered: {
        BarCalendar.clockHover = true
        if (!mod.host.agendaOpen)
          BarCalendar.show(mod.host.screenName, mod.host.side, mod.host.alongCenterOf(clockButton))
      }
      onExited: BarCalendar.clockHover = false
      onClicked: mouse => {
        if (mouse.button === Qt.RightButton) {
          BarCalendar.hide()
          mod.host.clockRightClicked()
        } else if (!mod.host.agendaOpen) {
          BarCalendar.toggle(mod.host.screenName, mod.host.side, mod.host.alongCenterOf(clockButton))
        }
      }
    }
  }
}
