// WorkspaceDots.qml — COMMON

import QtQuick
import QtQuick.Layouts


Item {
  id: root

  property var workspaces: []
  property bool vertical: false
  property int maxNameWidth: 170


  width: root.vertical ? 16 : row.implicitWidth
  height: root.vertical ? Math.max(16, column.implicitHeight) : 16

  Layout.preferredWidth: root.width
  Layout.preferredHeight: root.height

  readonly property var activeWs: {
    for (let i = 0; i < root.workspaces.length; i++)
      if (root.workspaces[i].active) return root.workspaces[i]
    return null
  }

  function wsLabel(w) {
    if (!w) return ""
    const n = String(w.name ?? w.id)


    return (n !== "" && n !== String(w.id)) ? n : "Workspace " + w.id
  }


  // (occupied === false) no se muestran hasta tener actividad.
  readonly property var shown: root.workspaces.filter(
    w => w.active || w.urgent || w.occupied !== false)

  RowLayout {
    id: row
    visible: !root.vertical
    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
    spacing: 5

    Repeater {
      model: root.shown
      delegate: Item {
        id: dotH
        required property var modelData
        readonly property bool isActive: !!modelData.active
        readonly property bool isUrgent: !!modelData.urgent && !dotH.isActive
        Layout.preferredWidth: dotH.isActive ? 20 : 8
        Layout.preferredHeight: 16
        Behavior on Layout.preferredWidth { NumberAnimation { duration: Theme.animDuration(180); easing.type: Easing.OutCubic } }

        Rectangle {
          anchors.centerIn: parent
          width: parent.width
          height: 8
          radius: 4
          color: dotH.isActive ? Theme.primary
            : dotH.isUrgent ? Theme.error
            : dotAreaH.containsMouse ? Theme.text : Theme.subtext
          opacity: dotH.isActive || dotH.isUrgent || dotAreaH.containsMouse ? 1 : 0.55
          Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
        }

        MouseArea {
          id: dotAreaH
          anchors.fill: parent
          anchors.margins: -6
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: WM.clickWorkspace(dotH.modelData)
        }
      }
    }

    Text {
      id: nameText
      visible: root.activeWs !== null


      Layout.preferredWidth: Math.min(nameText.implicitWidth, root.maxNameWidth)
      Layout.maximumWidth: root.maxNameWidth
      elide: Text.ElideRight
      text: root.wsLabel(root.activeWs)
      color: Theme.text
      font.pixelSize: Theme.fs(12)
      font.bold: true
      font.family: Theme.fontFamily
    }
  }

  ColumnLayout {
    id: column
    visible: root.vertical
    anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
    spacing: 5

    Repeater {
      model: root.shown
      delegate: Item {
        id: dotV
        required property var modelData
        readonly property bool isActive: !!modelData.active
        readonly property bool isUrgent: !!modelData.urgent && !dotV.isActive
        Layout.preferredWidth: dotV.isActive ? 20 : 8
        Layout.preferredHeight: 16

        Rectangle {
          anchors.centerIn: parent
          width: parent.width
          height: 8
          radius: 4
          color: dotV.isActive ? Theme.primary
            : dotV.isUrgent ? Theme.error
            : dotAreaV.containsMouse ? Theme.text : Theme.subtext
          opacity: dotV.isActive || dotV.isUrgent || dotAreaV.containsMouse ? 1 : 0.55
          Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
        }

        MouseArea {
          id: dotAreaV
          anchors.fill: parent
          anchors.margins: -6
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: WM.clickWorkspace(dotV.modelData)
        }
      }
    }
  }
}
