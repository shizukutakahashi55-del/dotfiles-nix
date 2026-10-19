// SettingsChips — chips que saltan de línea para elegir entre muchas opciones. model: [{ value, label, icon?, color? }]. `activeFn(value)` permite selección múltiple.

import QtQuick
import QtQuick.Layouts
import "../COMMON"

Flow {
  id: root

  property var model: []
  property var current: null
  property var activeFn: null

  signal picked(var value)

  Layout.fillWidth: true
  spacing: 8

  Repeater {
    model: root.model

    delegate: SkinRect {
      id: chip
      required property var modelData

      readonly property bool active: root.activeFn ? !!root.activeFn(chip.modelData.value)
                                                   : chip.modelData.value === root.current

      implicitWidth: chipRow.implicitWidth + 24
      implicitHeight: 30
      radius: Theme.cozy ? 4 : 15
      color: chip.active ? Theme.primary
           : (chipArea.containsMouse ? Theme.surfaceHigh : Theme.bg)
      border.width: chip.active ? 0 : Theme.bw1
      border.color: Theme.edge
      opacity: chip.modelData.enabled === false ? 0.45 : 1
      Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }

      Row {
        id: chipRow
        anchors.centerIn: parent
        spacing: 6

        Rectangle {
          visible: (chip.modelData.color ?? "") !== ""
          anchors.verticalCenter: parent.verticalCenter
          width: 12
          height: 12
          radius: Theme.cozy ? 0 : 6
          color: chip.modelData.color ?? "transparent"
          border.width: Theme.bw1
          border.color: chip.active ? Theme.textOnPrimary : Theme.edge
        }
        Text {
          visible: (chip.modelData.icon ?? "") !== ""
          anchors.verticalCenter: parent.verticalCenter
          text: chip.modelData.icon ?? ""
          color: chip.active ? Theme.textOnPrimary : Theme.primary
          font.pixelSize: Theme.sfs(12)
          font.family: Theme.monoFamily
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: chip.modelData.label
          color: chip.active ? Theme.textOnPrimary : Theme.text
          font.bold: chip.active
          font.pixelSize: Theme.sfs(11)
          font.family: Theme.fontFamily
        }
      }

      MouseArea {
        id: chipArea
        anchors.fill: parent
        enabled: chip.modelData.enabled !== false
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.picked(chip.modelData.value)
      }
    }
  }
}
