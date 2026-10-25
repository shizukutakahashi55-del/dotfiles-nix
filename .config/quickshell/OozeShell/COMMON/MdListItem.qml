// MdListItem — COMMON

import QtQuick
import QtQuick.Layouts

Rectangle {
  id: root

  property string headline: ""
  property string supporting: ""
  property string glyph: ""
  property string leadShape: "cookie9"
  property bool first: true
  property bool last: true
  property bool interactive: false
  property bool selected: false
  property color accent: Theme.primary

  default property alias body: bodySlot.data
  property alias trailing: trailSlot.data

  signal clicked()

  readonly property real outer: MdTokens.rL
  readonly property real inner: MdTokens.innerRadius

  Layout.fillWidth: true
  implicitHeight: col.implicitHeight + 20
  topLeftRadius: root.first ? root.outer : root.inner
  topRightRadius: root.first ? root.outer : root.inner
  bottomLeftRadius: root.last ? root.outer : root.inner
  bottomRightRadius: root.last ? root.outer : root.inner
  color: root.selected ? MdTokens.containerHigh : MdTokens.container
  border.width: Theme.cozy ? 2 : 0
  border.color: Theme.ink
  Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }

  Rectangle {
    anchors.fill: parent
    topLeftRadius: parent.topLeftRadius
    topRightRadius: parent.topRightRadius
    bottomLeftRadius: parent.bottomLeftRadius
    bottomRightRadius: parent.bottomRightRadius
    color: MdTokens.stateLayer(Theme.text, hoverArea.containsMouse && root.interactive, hoverArea.pressed && root.interactive)
  }

  MouseArea {
    id: hoverArea
    anchors.fill: parent
    hoverEnabled: root.interactive
    enabled: root.interactive
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }

  ColumnLayout {
    id: col
    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 14; rightMargin: 14 }
    spacing: 10

    RowLayout {
      Layout.fillWidth: true
      spacing: 14

      Item {
        visible: root.glyph !== ""
        Layout.preferredWidth: 42
        Layout.preferredHeight: 42
        Layout.alignment: Qt.AlignVCenter

        MdShape {
          anchors.fill: parent
          shape: root.leadShape
          color: Theme.withAlpha(root.accent, 0.18)
        }
        Text {
          anchors.centerIn: parent
          text: root.glyph
          color: root.accent
          font.family: Theme.monoFamily
          font.pixelSize: Theme.sfs(16)
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        Layout.alignment: Qt.AlignVCenter
        spacing: 1

        Text {
          Layout.fillWidth: true
          visible: root.headline !== ""
          text: root.headline
          color: Theme.text
          font.bold: true
          font.pixelSize: Theme.sfs(13)
          font.family: Theme.fontFamily
          elide: Text.ElideRight
        }
        Text {
          Layout.fillWidth: true
          visible: root.supporting !== ""
          text: root.supporting
          color: Theme.subtext
          font.pixelSize: Theme.sfs(10)
          font.family: Theme.fontFamily
          wrapMode: Text.WordWrap
        }
      }

      RowLayout {
        id: trailSlot
        Layout.alignment: Qt.AlignVCenter
        spacing: 8
      }
    }

    ColumnLayout {
      id: bodySlot
      Layout.fillWidth: true
      spacing: 8
    }
  }
}
