import QtQuick
import "../../COMMON"

Rectangle {
  id: root

  property var model: []
  property string current: ""
  property int itemHeight: 26
  property int hPad: 12
  property int fontSize: 11
  property Item activeItem: null
  property bool animate: false
  readonly property int inset: root.border.width + 2

  signal picked(string key)

  readonly property int currentIndex: {
    for (let i = 0; i < root.model.length; i++)
      if (root.model[i].k === root.current) return i
    return -1
  }

  function syncActive() {
    root.activeItem = root.currentIndex >= 0 ? rep.itemAt(root.currentIndex) : null
  }

  onCurrentIndexChanged: root.syncActive()
  Component.onCompleted: Qt.callLater(function () { root.animate = true })

  implicitWidth: row.implicitWidth + root.inset * 2
  implicitHeight: root.itemHeight + root.inset * 2
  radius: Theme.cardRadius
  color: Theme.surface
  border.width: Theme.bw1
  border.color: Theme.divider

  Rectangle {
    visible: root.activeItem !== null
    x: row.x + (root.activeItem ? root.activeItem.x : 0)
    y: row.y
    width: root.activeItem ? root.activeItem.width : 0
    height: root.itemHeight
    radius: Math.max(2, Theme.cardRadius - 3)
    color: Theme.primary

    Behavior on x {
      enabled: root.animate
      NumberAnimation { duration: Theme.animDuration(200); easing.type: Easing.OutCubic }
    }
    Behavior on width {
      enabled: root.animate
      NumberAnimation { duration: Theme.animDuration(200); easing.type: Easing.OutCubic }
    }
  }

  Row {
    id: row
    x: root.inset
    y: root.inset

    Repeater {
      id: rep
      model: root.model
      onItemAdded: root.syncActive()

      delegate: Item {
        id: seg
        required property var modelData

        readonly property bool on: root.current === seg.modelData.k

        width: content.implicitWidth + root.hPad * 2
        height: root.itemHeight

        Row {
          id: content
          anchors.centerIn: parent
          spacing: 6

          Text {
            visible: (seg.modelData.icon || "") !== ""
            text: seg.modelData.icon || ""
            color: seg.on ? Theme.textOnPrimary : Theme.subtext
            font.family: Theme.monoFamily
            font.pixelSize: Theme.fs(root.fontSize + 1)
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
          }
          Text {
            text: seg.modelData.l
            color: seg.on ? Theme.textOnPrimary : (area.containsMouse ? Theme.text : Theme.subtext)
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fs(root.fontSize)
            font.bold: seg.on
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
          }
        }

        MouseArea {
          id: area
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.picked(seg.modelData.k)
        }
      }
    }
  }
}
