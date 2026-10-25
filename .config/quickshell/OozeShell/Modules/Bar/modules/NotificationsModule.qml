// NotificationsModule — campana de notificaciones (clic: panel, clic derecho: No molestar).

import QtQuick
import QtQuick.Layouts

import "../../../COMMON"
import "../../../Services/Lang"
import "../../../Services/Notify"

BarFlow {
  id: mod

  property var host: null
  readonly property bool shown: true

  SkinRect {
    id: notificationButton

    readonly property string tip:
      Translations.t("notifTitle") + "\n" + Translations.t("notifDndHint")

    Layout.preferredWidth: Theme.barVertical ? 40 : 36
    Layout.preferredHeight: 30

    radius: 10

    color: (notificationMouse.containsMouse || mod.host.notifyOpen)
      ? Theme.surface
      : "transparent"

    Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }

    scale: notificationMouse.pressed
      ? 0.84
      : notificationMouse.containsMouse ? 1.08 : 1.0

    Behavior on scale {
      NumberAnimation { duration: Theme.animDuration(160); easing.type: Easing.OutBack }
    }

    Text {
      anchors.centerIn: parent

      text: NotificationsBackend.dnd
        ? "󰂛"
        : (NotificationsBackend.count > 0 ? "󱅫" : "󰂚")

      color: NotificationsBackend.dnd ? Theme.subtext : Theme.text

      font.family: Theme.monoFamily
      font.pixelSize: Theme.fs(19)

      Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
    }

    MouseArea {
      id: notificationMouse

      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      acceptedButtons: Qt.LeftButton | Qt.RightButton

      onEntered: mod.host.tipEnter(notificationButton)
      onExited: mod.host.tipLeave(notificationButton)

      onClicked: mouse => {
        if (mouse.button === Qt.RightButton)
          NotificationsBackend.toggleDnd()
        else
          mod.host.notificationButtonClicked()
      }
    }
  }
}
