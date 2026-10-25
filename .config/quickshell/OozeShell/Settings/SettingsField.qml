// SettingsField — campo de texto de una línea. Confirma con Enter o al perder el foco (`submitted`) y vuelve a mostrar el valor que viene de afuera.

import QtQuick
import QtQuick.Layouts
import "../COMMON"

SkinRect {
  id: fld

  property string value: ""
  property string placeholder: ""
  property bool secret: false
  property bool mono: false
  property alias input: fieldInput

  signal submitted(string text)

  Layout.fillWidth: true
  Layout.minimumWidth: 160
  Layout.preferredWidth: 260
  Layout.preferredHeight: 34
  implicitHeight: 34
  radius: Theme.cozy ? 4 : 10
  color: Theme.surfaceHigh
  border.width: fieldInput.activeFocus ? 1 : 0
  border.color: Theme.primary

  TextInput {
    id: fieldInput
    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
    verticalAlignment: TextInput.AlignVCenter
    text: fld.value
    echoMode: fld.secret && !fieldInput.activeFocus ? TextInput.Password : TextInput.Normal
    color: Theme.text
    selectionColor: Theme.primary
    selectedTextColor: Theme.textOnPrimary
    selectByMouse: true
    font.pixelSize: Theme.sfs(12)
    font.family: fld.mono ? Theme.monoFamily : Theme.fontFamily
    clip: true
    inputMethodHints: Qt.ImhNoPredictiveText
    onEditingFinished: {
      fld.submitted(text)
      text = Qt.binding(() => fld.value)
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      visible: fieldInput.text === "" && !fieldInput.activeFocus && fld.placeholder !== ""
      text: fld.placeholder
      color: Theme.subtext
      font.pixelSize: Theme.sfs(12)
      font.family: Theme.fontFamily
    }
  }
}
