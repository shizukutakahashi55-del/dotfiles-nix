// LockDashSection

import QtQuick
import QtQuick.Layouts
import "../../COMMON"

Item {
  id: root

  property real unit: 1
  property bool shown: false
  property bool divider: false
  property string icon: ""
  property string title: ""
  property string trailing: ""
  property color trailingColor: Theme.subtext
  property int bodySpacing: Math.round(10 * root.unit)
  default property alias content: body.data

  readonly property int pad: Math.round(18 * root.unit)

  // ── Geometría ──
  Layout.fillWidth: true
  Layout.preferredHeight: root.shown ? col.implicitHeight : 0
  Behavior on Layout.preferredHeight {
    NumberAnimation { duration: Theme.animDuration(260); easing.type: Easing.OutCubic }
  }

  clip: true
  visible: opacity > 0
  opacity: root.shown ? 1 : 0
  Behavior on opacity { NumberAnimation { duration: Theme.animDuration(240); easing.type: Easing.OutCubic } }

  // ── Estructura ──
  ColumnLayout {
    id: col
    anchors { left: parent.left; right: parent.right; top: parent.top }
    spacing: 0

    // ── Divisor ──
    Rectangle {
      visible: root.divider
      Layout.fillWidth: true
      Layout.leftMargin: root.pad
      Layout.rightMargin: root.pad
      Layout.preferredHeight: 1
      color: Theme.divider
    }

    ColumnLayout {
      Layout.fillWidth: true
      Layout.leftMargin: root.pad
      Layout.rightMargin: root.pad
      Layout.topMargin: Math.round(14 * root.unit)
      Layout.bottomMargin: Math.round(16 * root.unit)
      spacing: Math.round(12 * root.unit)

      // ── Cabecera ──
      RowLayout {
        Layout.fillWidth: true
        spacing: Math.round(8 * root.unit)

        Text {
          text: root.icon
          color: Theme.primary
          font.pixelSize: Math.round(15 * root.unit)
          font.family: Theme.monoFamily
        }
        Text {
          text: root.title.toUpperCase()
          color: Theme.subtext
          font.pixelSize: Math.round(11 * root.unit)
          font.bold: true
          font.letterSpacing: Math.round(2 * root.unit)
          font.family: Theme.fontFamily
        }
        Text {
          Layout.fillWidth: true
          Layout.minimumWidth: 0
          horizontalAlignment: Text.AlignRight
          text: root.trailing
          color: root.trailingColor
          font.pixelSize: Math.round(11 * root.unit)
          font.family: Theme.fontFamily
          elide: Text.ElideRight
        }
      }

      // ── Contenido ──
      ColumnLayout {
        id: body
        Layout.fillWidth: true
        spacing: root.bodySpacing
      }
    }
  }
}
