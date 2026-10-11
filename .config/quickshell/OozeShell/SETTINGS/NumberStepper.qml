// NumberStepper — campo numérico con botones [−] valor [+] y edición directa (clic en el número → escribís y Enter). A diferencia de LevelPicker

import QtQuick
import QtQuick.Layouts
import "../COMMON"

SkinRect {
  id: root

  property int value: 100
  property int min: 0
  property int max: 100
  property int step: 1
  property string suffix: ""


  signal edited(int v)

  function clamp(v) {
    const n = Math.round(v)
    if (isNaN(n)) return root.value
    return Math.max(root.min, Math.min(root.max, n))
  }
  function step_(delta) {


    if (input.activeFocus) input.focus = false
    root.edited(root.clamp(root.value + delta))
  }
  function commit() {
    const parsed = parseInt(input.text)
    root.edited(root.clamp(isNaN(parsed) ? root.value : parsed))
    input.text = String(root.value) + root.suffix
  }


  onValueChanged: if (!input.activeFocus) input.text = String(root.value) + root.suffix
  Component.onCompleted: input.text = String(root.value) + root.suffix

  Layout.fillWidth: true
  Layout.preferredHeight: 40
  radius: 12
  color: Theme.surface

  RowLayout {
    anchors.fill: parent
    anchors.margins: 4
    spacing: 4

    SkinRect {
      id: minusBtn
      Layout.preferredWidth: 32
      Layout.fillHeight: true
      radius: 9
      color: minusArea.containsMouse ? Theme.surfaceHigh : "transparent"
      opacity: root.value <= root.min ? 0.4 : 1
      Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }

      Text {
        anchors.centerIn: parent
        text: "−"
        color: Theme.text
        font.bold: true
        font.pixelSize: Theme.fs(14)
        font.family: Theme.fontFamily
      }
      MouseArea {
        id: minusArea


        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.step_(-root.step)
      }
    }

    SkinRect {
      Layout.fillWidth: true
      Layout.fillHeight: true
      radius: 9
      color: input.activeFocus ? Theme.bg : "transparent"
      inkColor: Theme.primary
      border.width: input.activeFocus ? 1 : 0
      border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.55)
      Behavior on border.width { NumberAnimation { duration: Theme.animDuration(120) } }

      TextInput {
        id: input
        anchors.centerIn: parent
        color: Theme.text
        selectionColor: Theme.primary
        selectedTextColor: Theme.textOnPrimary
        font.pixelSize: Theme.fs(13)
        font.bold: true
        font.family: Theme.fontFamily
        horizontalAlignment: Text.AlignHCenter
        inputMethodHints: Qt.ImhDigitsOnly
        validator: IntValidator { bottom: root.min; top: root.max }
        selectByMouse: true


        onActiveFocusChanged: {
          if (activeFocus) { input.text = String(root.value); input.selectAll() }
          else root.commit()
        }
        Keys.onReturnPressed: input.focus = false
        Keys.onEnterPressed: input.focus = false
        Keys.onEscapePressed: { input.text = String(root.value) + root.suffix; input.focus = false }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.IBeamCursor
          onClicked: input.forceActiveFocus()
        }
      }
    }

    SkinRect {
      id: plusBtn
      Layout.preferredWidth: 32
      Layout.fillHeight: true
      radius: 9
      color: plusArea.containsMouse ? Theme.surfaceHigh : "transparent"
      opacity: root.value >= root.max ? 0.4 : 1
      Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }

      Text {
        anchors.centerIn: parent
        text: "+"
        color: Theme.text
        font.bold: true
        font.pixelSize: Theme.fs(14)
        font.family: Theme.fontFamily
      }
      MouseArea {
        id: plusArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.step_(root.step)
      }
    }
  }
}
