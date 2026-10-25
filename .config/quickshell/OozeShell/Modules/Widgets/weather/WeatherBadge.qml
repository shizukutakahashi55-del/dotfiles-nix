// WeatherBadge — icono de clima sobre un shape de Material Design.

import QtQuick
import ".."
import "../../../COMMON"

Item {
  id: root

  property int code: 0
  property bool isDay: true
  property string shape: "cookie7"

  implicitWidth: 48
  implicitHeight: 48

  MdShape {
    anchors.fill: parent
    shape: root.shape
    color: Qt.alpha(Theme.primary, root.isDay ? 0.20 : 0.12)
  }

  WeatherIcon {
    anchors.centerIn: parent
    width: Math.round(Math.min(root.width, root.height) * 0.62)
    height: width
    code: root.code
    isDay: root.isDay
  }
}
