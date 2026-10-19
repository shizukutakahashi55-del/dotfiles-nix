// PowerCard — tarjeta de una acción de energía (apagar, reiniciar…).

import QtQuick
import QtQuick.Layouts
import "../../COMMON"

SkinRect {
  id: root

  property string icon: ""
  property string label: ""
  property string hint: ""
  property string keyLabel: ""
  property bool danger: false
  property bool selected: false
  property real unit: 1
  signal clicked()
  signal entered()

  readonly property color accent: root.danger ? Theme.error : Theme.primary
  function a(c, v) { return Qt.rgba(c.r, c.g, c.b, v) }

  implicitWidth: Math.round(158 * unit)
  implicitHeight: Math.round(196 * unit)
  radius: Theme.cozy ? Theme.cardRadius : Math.round(26 * unit)
  raised: true
  notch: 6
  depth: 4
  inkColor: root.selected ? root.accent : Theme.ink

  color: root.a(Theme.mix(Theme.surface, root.accent, root.selected ? 0.18 : 0.0),
                root.selected ? 0.94 : 0.82)
  border.width: root.selected ? 2 : Theme.bw1
  border.color: root.selected ? root.accent : root.a(root.accent, 0.25)
  Behavior on color { ColorAnimation { duration: Theme.animDuration(160) } }
  Behavior on border.color { ColorAnimation { duration: Theme.animDuration(160) } }


  scale: Theme.cozy ? 1.0 : (area.pressed ? 0.96 : (root.selected ? 1.04 : 1.0))
  Behavior on scale { NumberAnimation { duration: Theme.animDuration(170); easing.type: Easing.OutBack } }


  Rectangle {
    visible: !Theme.cozy
    anchors.fill: parent
    radius: root.radius
    opacity: root.selected ? 1 : 0.55
    Behavior on opacity { NumberAnimation { duration: Theme.animDuration(180) } }
    gradient: Gradient {
      GradientStop { position: 0.0; color: root.a(root.accent, 0.26) }
      GradientStop { position: 0.55; color: root.a(root.accent, 0.06) }
      GradientStop { position: 1.0; color: "transparent" }
    }
  }


  Rectangle {
    anchors.top: parent.top
    anchors.topMargin: Math.round(12 * root.unit)
    anchors.horizontalCenter: parent.horizontalCenter
    width: Math.round((root.selected ? 44 : 28) * root.unit)
    height: Math.max(3, Math.round(4 * root.unit))
    radius: Theme.cozy ? 0 : height / 2
    color: root.accent
    opacity: 0.85
    Behavior on width { NumberAnimation { duration: Theme.animDuration(180); easing.type: Easing.OutCubic } }
  }


  Rectangle {
    visible: root.keyLabel !== ""
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.topMargin: Math.round(10 * root.unit)
    anchors.rightMargin: Math.round(10 * root.unit)
    width: Math.round(22 * root.unit)
    height: width
    radius: Theme.cozy ? 0 : Math.round(7 * root.unit)
    color: root.a(root.accent, 0.16)
    opacity: root.selected ? 1 : 0.6
    Behavior on opacity { NumberAnimation { duration: Theme.animDuration(150) } }
    Text {
      anchors.centerIn: parent
      text: root.keyLabel
      color: root.accent
      font.pixelSize: Math.round(11 * root.unit)
      font.bold: true
      font.family: Theme.fontFamily
    }
  }

  ColumnLayout {
    anchors.top: parent.top
    anchors.topMargin: Math.round(30 * root.unit)
    anchors.horizontalCenter: parent.horizontalCenter
    width: parent.width - Math.round(16 * root.unit)
    spacing: Math.round(8 * root.unit)


    Item {
      Layout.alignment: Qt.AlignHCenter
      Layout.preferredWidth: Math.round(84 * root.unit)
      Layout.preferredHeight: Math.round(84 * root.unit)

      Rectangle {
        visible: !Theme.cozy
        anchors.centerIn: parent
        width: parent.width
        height: width
        radius: width / 2
        color: "transparent"
        border.width: 2
        border.color: root.accent
        opacity: root.selected ? 0.4 : 0.14
        Behavior on opacity { NumberAnimation { duration: Theme.animDuration(180) } }
      }

      Rectangle {
        anchors.centerIn: parent
        width: Math.round(64 * root.unit)
        height: width
        radius: Theme.cozy ? 0 : width / 2
        color: Theme.cozy ? "transparent" : root.a(root.accent, root.selected ? 0.30 : 0.18)
        border.width: Theme.cozy ? 0 : Theme.bw1
        border.color: root.a(root.accent, 0.45)
        Behavior on color { ColorAnimation { duration: Theme.animDuration(160) } }

        CozyBox {
          visible: Theme.cozy
          anchors.fill: parent
          notch: 4
          shadow: false
          fillTop: Theme.mix(Theme.bg, root.accent, root.selected ? 0.55 : 0.40)
          fillBottom: Theme.mix(Theme.bg, root.accent, root.selected ? 0.30 : 0.20)
        }

        Text {
          anchors.centerIn: parent
          text: root.icon
          color: root.accent
          font.pixelSize: Math.round(30 * root.unit)
          font.family: Theme.monoFamily
        }
      }
    }

    Text {
      Layout.alignment: Qt.AlignHCenter
      Layout.fillWidth: true
      horizontalAlignment: Text.AlignHCenter
      text: root.label
      color: Theme.text
      font.pixelSize: Math.round(15 * root.unit)
      font.bold: true
      font.family: Theme.fontFamily
      wrapMode: Text.WordWrap
      maximumLineCount: 2
      elide: Text.ElideRight
    }


    Text {
      Layout.alignment: Qt.AlignHCenter
      Layout.fillWidth: true
      Layout.preferredHeight: Math.round(30 * root.unit)
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignTop
      text: root.hint
      color: Theme.subtext
      font.pixelSize: Math.round(11 * root.unit)
      font.family: Theme.fontFamily
      wrapMode: Text.WordWrap
      maximumLineCount: 2
      elide: Text.ElideRight
    }
  }

  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onEntered: root.entered()
    onClicked: root.clicked()
  }
}
