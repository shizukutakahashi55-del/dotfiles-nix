// LockField — campo de contraseña del lock.
// Píldora (OozeSoft) o caja pixel (CoOzey) con: candado a la izquierda, los caracteres como puntos que "brotan" al teclear, y a la derecha un indicador de Caps Lock (solo si está activo) + botón de enviar.

import QtQuick
import "../COMMON"

Item {
  id: root

  property string password: ""
  property bool checking: false
  property bool failed: false
  property bool capsOn: false
  property color capsColor: Theme.primary
  property int failCount: 0
  property real unit: 1
  property string placeholder: ""
  property string checkingText: ""
  signal submit()

  implicitWidth: Math.round(380 * unit)
  implicitHeight: Math.round(58 * unit)


  readonly property color stateColor: root.failed ? Theme.error
                                    : root.capsOn ? root.capsColor
                                    : Theme.primary
  readonly property int sideL: Math.round(52 * unit)
  readonly property int sideR: Math.round(100 * unit)

  // ── Sacudida al fallar ──
  transform: Translate { id: shake; x: 0 }
  SequentialAnimation {
    id: shakeAnim
    NumberAnimation { target: shake; property: "x"; to: -14; duration: Theme.animDuration(50) }
    NumberAnimation { target: shake; property: "x"; to: 14;  duration: Theme.animDuration(90) }
    NumberAnimation { target: shake; property: "x"; to: -9;  duration: Theme.animDuration(80) }
    NumberAnimation { target: shake; property: "x"; to: 6;   duration: Theme.animDuration(70) }
    NumberAnimation { target: shake; property: "x"; to: 0;   duration: Theme.animDuration(60) }
  }
  onFailCountChanged: shakeAnim.restart()

  // ── Halo (solo OozeSoft; en CoOzey manda el contorno de tinta) ──
  Rectangle {
    anchors.centerIn: parent
    width: parent.width + Math.round(16 * root.unit)
    height: parent.height + Math.round(16 * root.unit)
    radius: height / 2
    visible: !Theme.cozy && !Theme.performanceMode
    color: Qt.rgba(root.stateColor.r, root.stateColor.g, root.stateColor.b, 0.18)
    opacity: (root.capsOn || root.failed) ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.animDuration(220) } }
  }

  // ── Caja ──
  SkinRect {
    id: box
    anchors.fill: parent
    radius: Theme.cozy ? Theme.cardRadius : height / 2
    color: Theme.surfaceHigh
    border.width: 2
    border.color: root.checking ? Theme.text : root.stateColor
    inkColor: root.checking ? Theme.text : root.stateColor
    Behavior on border.color { ColorAnimation { duration: Theme.animDuration(150) } }
  }

  // ── Candado ──
  Text {
    anchors.left: parent.left
    anchors.leftMargin: Math.round(20 * root.unit)
    anchors.verticalCenter: parent.verticalCenter
    text: "󰌾"
    color: root.capsOn ? root.capsColor : Theme.subtext
    font.pixelSize: Math.round(20 * root.unit)
    font.family: Theme.fontFamily
    Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
  }

  // ── Texto de estado (vacío) ──
  Text {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.leftMargin: root.sideL
    anchors.rightMargin: root.sideR
    anchors.verticalCenter: parent.verticalCenter
    visible: root.password.length === 0
    horizontalAlignment: Text.AlignHCenter
    elide: Text.ElideRight
    text: root.checking ? root.checkingText : root.placeholder
    color: Theme.subtext
    font.pixelSize: Math.round(14 * root.unit)
    font.family: Theme.fontFamily
  }

  // ── Puntos ──

  Item {
    id: dotsView
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.leftMargin: root.sideL
    anchors.rightMargin: root.sideR
    anchors.verticalCenter: parent.verticalCenter
    height: Math.round(20 * root.unit)
    visible: root.password.length > 0

    Row {
      id: dotsRow
      anchors.centerIn: parent
      spacing: Math.round(8 * root.unit)
      scale: width > 0 ? Math.min(1, dotsView.width / width) : 1
      transformOrigin: Item.Center

      Repeater {
        model: root.password.length
        delegate: Rectangle {
          width: Math.round(11 * root.unit)
          height: width
          radius: Theme.cozy ? 0 : width / 2
          color: root.capsOn ? root.capsColor : Theme.text
          scale: 0
          Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }
          Behavior on scale {
            NumberAnimation {
              duration: Theme.animDuration(180)
              easing.type: Easing.BezierSpline
              easing.bezierCurve: Motion.spatialFast
            }
          }
          Component.onCompleted: scale = 1
        }
      }
    }
  }

  // ── Derecha: Caps + enviar ──
  Row {
    anchors.right: parent.right
    anchors.rightMargin: Math.round(9 * root.unit)
    anchors.verticalCenter: parent.verticalCenter
    spacing: Math.round(8 * root.unit)

    Rectangle {
      width: Math.round(32 * root.unit)
      height: width
      radius: Theme.cozy ? 0 : Math.round(10 * root.unit)
      color: Qt.rgba(root.capsColor.r, root.capsColor.g, root.capsColor.b, 0.2)
      border.width: 1
      border.color: Qt.rgba(root.capsColor.r, root.capsColor.g, root.capsColor.b, 0.75)
      opacity: root.capsOn ? 1 : 0
      scale: root.capsOn ? 1 : 0.7
      Behavior on opacity { NumberAnimation { duration: Theme.animDuration(160) } }
      Behavior on scale { NumberAnimation { duration: Theme.animDuration(200); easing.type: Easing.OutBack } }

      Text {
        anchors.centerIn: parent
        text: "⇪"
        color: root.capsColor
        font.pixelSize: Math.round(20 * root.unit)
        font.bold: true
        font.family: Theme.fontFamily
      }
    }

    Rectangle {
      id: go
      width: Math.round(42 * root.unit)
      height: width
      radius: Theme.cozy ? 0 : width / 2
      color: Theme.primary
      opacity: (root.password.length > 0 || root.checking) ? 1 : 0.35
      Behavior on opacity { NumberAnimation { duration: Theme.animDuration(150) } }

      Text {
        id: goGlyph
        anchors.centerIn: parent
        text: root.checking ? "󰑐" : "󰁔"
        color: Theme.textOnPrimary
        font.pixelSize: Math.round(20 * root.unit)
        font.family: Theme.fontFamily
        RotationAnimator on rotation {
          running: root.checking && Theme.uiAnimationsEnabled
          from: 0; to: 360; duration: 900; loops: Animation.Infinite
        }
        onTextChanged: if (!root.checking) rotation = 0
      }

      MouseArea {
        anchors.fill: parent
        enabled: !root.checking && root.password.length > 0
        cursorShape: Qt.PointingHandCursor
        onClicked: root.submit()
      }
    }
  }
}
