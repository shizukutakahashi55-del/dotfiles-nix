// SettingsChoice — selector segmentado para elegir UNA opción entre pocas (2 a 4). model: [{ value, label, icon? }]. Con más opciones se usa SettingsChips.

import QtQuick
import QtQuick.Layouts
import "../COMMON"

SkinRect {
  id: root

  property var model: []
  property var current: null

  signal picked(var value)

  Layout.alignment: Qt.AlignVCenter
  Layout.preferredWidth: seg.implicitWidth + 6
  Layout.preferredHeight: 34
  implicitWidth: seg.implicitWidth + 6
  implicitHeight: 34
  radius: Theme.cozy ? 4 : 11
  color: Theme.bg
  border.width: Theme.bw1
  border.color: Theme.edge

  Row {
    id: seg
    x: 3
    y: 3
    spacing: 2

    Repeater {
      model: root.model

      delegate: SkinRect {
        id: opt
        required property var modelData

        readonly property bool active: root.current === opt.modelData.value

        width: optRow.implicitWidth + 24
        height: root.height - 6
        radius: Theme.cozy ? 3 : 8
        color: opt.active ? Theme.primary : (optArea.containsMouse ? Theme.surfaceHigh : "transparent")
        opacity: opt.modelData.enabled === false ? 0.45 : 1
        Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }

        Row {
          id: optRow
          anchors.centerIn: parent
          spacing: 6

          Text {
            visible: (opt.modelData.icon ?? "") !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: opt.modelData.icon ?? ""
            color: opt.active ? Theme.textOnPrimary : Theme.primary
            font.pixelSize: Theme.sfs(12)
            font.family: Theme.monoFamily
          }
          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: opt.modelData.label
            color: opt.active ? Theme.textOnPrimary : Theme.text
            font.bold: opt.active
            font.pixelSize: Theme.sfs(11)
            font.family: Theme.fontFamily
          }
        }

        MouseArea {
          id: optArea
          anchors.fill: parent
          enabled: opt.modelData.enabled !== false
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.picked(opt.modelData.value)
        }
      }
    }
  }
}
