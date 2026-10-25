import QtQuick
import QtQuick.Layouts
import "../COMMON"

SkinRect {
  id: btn

  property string icon: ""

  signal clicked()

  Layout.preferredWidth: 30
  Layout.preferredHeight: 30
  Layout.alignment: Qt.AlignVCenter
  implicitWidth: 30
  implicitHeight: 30
  radius: 15
  color: btnArea.containsMouse ? Theme.surfaceHigh : Theme.surface
  Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }

  CatIcon {
    anchors.centerIn: parent
    icon: btn.icon
    color: Theme.text
    size: Theme.sfs(15)
  }

  MouseArea {
    id: btnArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: btn.clicked()
  }
}
