// MonitorCard — SYSTEM MONITOR

import QtQuick
import "../../COMMON"

Rectangle {
  id: root

  property string title: ""
  property string icon: ""
  property color accent: Theme.primary
  property string note: ""

  default property alias content: body.data

  readonly property int pad: 14
  implicitHeight: outer.implicitHeight + root.pad * 2

  radius: Theme.cardRadius
  color: Theme.surface
  border.width: Theme.bw1
  border.color: Theme.divider

  Rectangle {
    anchors.fill: parent
    anchors.margins: root.border.width
    radius: Math.max(0, root.radius - root.border.width)
    gradient: Gradient {
      GradientStop { position: 0.0; color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.09) }
      GradientStop { position: 0.6; color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.0) }
    }
  }

  Column {
    id: outer
    x: root.pad
    y: root.pad
    width: Math.max(0, root.width - root.pad * 2)
    spacing: 12

    Item {
      id: head
      width: parent.width
      height: 26

      Rectangle {
        id: chip
        visible: root.icon !== ""
        width: 26
        height: 26
        radius: Math.max(3, Theme.cardRadius - 3)
        color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.16)
        anchors.verticalCenter: parent.verticalCenter

        Text {
          anchors.centerIn: parent
          text: root.icon
          color: root.accent
          font.family: Theme.monoFamily
          font.pixelSize: Theme.fs(13)
        }
      }

      Text {
        text: root.title
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fs(12)
        font.bold: true
        anchors.left: chip.visible ? chip.right : parent.left
        anchors.leftMargin: chip.visible ? 9 : 0
        anchors.verticalCenter: parent.verticalCenter
      }

      MonitorChip {
        visible: root.note !== ""
        label: root.note
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    Column {
      id: body
      width: parent.width
      spacing: 10
    }
  }
}
