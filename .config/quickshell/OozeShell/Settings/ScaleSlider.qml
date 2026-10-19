// ScaleSlider — slider horizontal arrastrable para porcentajes (tamaño propio del Dock y de la Píldora). Mismo lenguaje visual que el resto de Ajustes.

import QtQuick
import QtQuick.Layouts
import "../COMMON"

Item {
  id: root

  property int value: 100
  property int min: 50
  property int max: 150
  property int step: 5
  property int defaultValue: 100
  property string suffix: "%"

  property int valueWidth: 48


  property bool wheelAdjust: false


  signal edited(int v)

  Layout.fillWidth: true
  implicitHeight: 32

  readonly property real ratio: root.max > root.min
      ? Math.max(0, Math.min(1, (root.value - root.min) / (root.max - root.min))) : 0

  function snap(v) {
    const n = Math.round(v / root.step) * root.step
    return Math.max(root.min, Math.min(root.max, n))
  }
  function fromX(x) {
    const r = Math.max(0, Math.min(1, x / Math.max(1, track.width)))
    return root.snap(root.min + r * (root.max - root.min))
  }


  function keyNudge(dir, t) {
    if (!root.enabled || (t && t !== dragArea)) return false
    root.edited(root.snap(root.value + dir * root.step))
    return true
  }
  function emitAt(x) {
    const n = root.fromX(x)
    if (n !== root.value) root.edited(n)
  }

  RowLayout {
    anchors.fill: parent
    spacing: 12

    // ── Pista + perilla ──
    Item {
      id: track
      Layout.fillWidth: true
      Layout.fillHeight: true


      PixelBar {
        id: pixRail
        visible: Theme.cozy
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 16
        ratio: root.ratio
      }
      Rectangle {
        readonly property real r: root.max > root.min
            ? (root.defaultValue - root.min) / (root.max - root.min) : 0
        visible: Theme.cozy
        width: 2
        height: 22
        anchors.verticalCenter: parent.verticalCenter
        x: Math.min(pixRail.width - width, Math.round(pixRail.width * r))
        color: Theme.subtext
        opacity: 0.7
      }

      Rectangle {
        id: rail
        visible: !Theme.cozy
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 6
        radius: 3
        color: Theme.surfaceHigh

        Rectangle {
          height: parent.height
          radius: 3
          color: Theme.primary
          width: Math.max(6, parent.width * root.ratio)
        }


        Rectangle {
          readonly property real r: root.max > root.min
              ? (root.defaultValue - root.min) / (root.max - root.min) : 0
          width: 2
          height: 12
          y: -3
          radius: 1
          color: Theme.subtext
          opacity: 0.6
          x: Math.min(rail.width - width, rail.width * r)
        }
      }

      Rectangle {
        id: knob
        visible: !Theme.cozy
        width: 16
        height: 16
        radius: 8
        y: Math.round((parent.height - height) / 2)
        x: Math.round((track.width - width) * root.ratio)
        color: Theme.primary
        border.width: 2
        border.color: Theme.bg
        scale: dragArea.pressed ? 1.2 : (dragArea.containsMouse ? 1.1 : 1.0)
        Behavior on scale { NumberAnimation { duration: Theme.animDuration(120); easing.type: Easing.OutCubic } }
      }

      MouseArea {
        id: dragArea
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        preventStealing: true
        onPressed: mouse => root.emitAt(mouse.x)
        onPositionChanged: mouse => { if (pressed) root.emitAt(mouse.x) }
        onWheel: wheel => {
          if (!root.wheelAdjust) { wheel.accepted = false; return }
          const dir = wheel.angleDelta.y > 0 ? 1 : -1
          root.edited(root.snap(root.value + dir * root.step))
        }
      }
    }

    // ── Valor ──
    Text {
      Layout.preferredWidth: root.valueWidth
      horizontalAlignment: Text.AlignRight
      text: root.value + root.suffix
      color: Theme.text
      font.bold: true
      font.pixelSize: Theme.sfs(12)
      font.family: Theme.fontFamily
    }

    // ── Restablecer (solo si difiere del valor por defecto) ──
    SkinRect {
      Layout.preferredWidth: 28
      Layout.preferredHeight: 28
      radius: 9
      opacity: root.value !== root.defaultValue ? 1 : 0
      color: resetArea.containsMouse ? Theme.surfaceHigh : "transparent"
      Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }
      Text {
        anchors.centerIn: parent
        text: "󰑙"
        color: Theme.subtext
        font.pixelSize: Theme.sfs(14)
        font.family: Theme.monoFamily
      }
      MouseArea {
        id: resetArea
        anchors.fill: parent
        enabled: root.enabled && root.value !== root.defaultValue
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.edited(root.defaultValue)
      }
    }
  }
}
