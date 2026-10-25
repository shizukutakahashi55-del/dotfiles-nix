// CityBox

import QtQuick
import "../../../COMMON"
import "../../../Services/Lang"

Rectangle {
  id: box
  property alias field: field
  signal submitted(string text)
  signal cancelled()
  signal focusLost()
  signal focusGained()

  implicitHeight: Math.max(30, Theme.fs(12) + 16)
  radius: Theme.cozy ? Theme.cardRadius : Math.round(height / 2)

  color: field.activeFocus ? Theme.surfaceHigh : Theme.surface
  Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }

  Text {
    id: ico
    anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
    text: "󰍎"
    color: Theme.primary
    font.family: Theme.monoFamily
    font.pixelSize: Theme.fs(13)
  }
  TextInput {
    id: field
    anchors { left: ico.right; leftMargin: 8; right: go.left; rightMargin: 4; verticalCenter: parent.verticalCenter }
    clip: true
    selectByMouse: true
    color: Theme.text
    selectionColor: Theme.primary
    selectedTextColor: Theme.textOnPrimary
    font.pixelSize: Theme.fs(12)
    font.family: Theme.fontFamily
    inputMethodHints: Qt.ImhNoPredictiveText
    onAccepted: box.submitted(text)
    Keys.onEscapePressed: box.cancelled()
    onActiveFocusChanged: { if (activeFocus) box.focusGained(); else box.focusLost() }
    Text {
      anchors.verticalCenter: parent.verticalCenter
      visible: field.text === "" && field.preeditText === ""
      text: Translations.t("wgWxCityPlaceholder")
      color: Theme.subtext
      font: field.font
      elide: Text.ElideRight
      width: parent.width
    }
  }
  Rectangle {
    id: go
    anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
    width: box.height - 8; height: width; radius: width / 2
    color: goMa.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.35)
                              : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)
    Text {
      anchors.centerIn: parent
      text: "󰁔"
      color: Theme.primary
      font.family: Theme.monoFamily
      font.pixelSize: Theme.fs(12)
    }
    MouseArea {
      id: goMa
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: box.submitted(field.text)
    }
  }
}
