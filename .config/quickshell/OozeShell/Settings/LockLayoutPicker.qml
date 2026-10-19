// LockLayoutPicker — selector de distribución de OozeLock con miniaturas. Dibuja cada preset desde LockLayouts, así nunca se desincroniza.

import QtQuick
import QtQuick.Layouts
import "../COMMON"
import "../Services/Lang"
import "../Modules/Lock"

Flow {
  id: root

  property string current: "center"

  signal picked(string value)

  Layout.fillWidth: true
  spacing: 12

  readonly property var names: ({
    "center":       "olLayoutCenter",
    "stack-left":   "olLayoutStackLeft",
    "stack-right":  "olLayoutStackRight",
    "split-center": "olLayoutSplitCenter",
    "split-right":  "olLayoutSplitRight",
    "split-left":   "olLayoutSplitLeft"
  })

  Repeater {
    model: LockLayouts.ids

    delegate: Item {
      id: card
      required property string modelData
      readonly property var plan: LockLayouts.spec(card.modelData)
      readonly property bool active: root.current === card.modelData

      width: 132
      height: 112

      // ── Miniatura ──
      SkinRect {
        id: screen
        width: parent.width
        height: 82
        radius: Theme.cozy ? 4 : 10
        color: Theme.bg
        border.width: card.active ? 2 : Theme.bw1
        border.color: card.active ? Theme.primary : (hit.containsMouse ? Theme.subtext : Theme.edge)
        Behavior on border.color { ColorAnimation { duration: Theme.animDuration(150) } }

        readonly property real m: 7
        readonly property real strip: 12

        function px(h, w) { return h === "left" ? m : h === "right" ? width - w - m : (width - w) / 2 }

        readonly property real cw: width * 0.32
        readonly property real ch: height * 0.15
        readonly property real aw: width * 0.30
        readonly property real ah: height * 0.30
        readonly property real groupTop: (height - ch - ah) / 2 - 11

        // ── Reloj ──
        Rectangle {
          width: screen.cw
          height: screen.ch
          x: screen.px(card.plan.clock.h, width)
          y: card.plan.joined ? screen.groupTop : screen.m
          radius: 2
          color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.55)
        }

        // ── Acceso ──
        Item {
          width: screen.aw
          height: screen.ah
          x: screen.px(card.plan.auth.h, width)
          y: card.plan.joined ? screen.groupTop + screen.ch + 2
           : card.plan.auth.v === "bottom" ? screen.height - screen.m - screen.strip - height
           : (screen.height - height) / 2

          Rectangle {
            width: 12
            height: 12
            radius: 6
            x: card.plan.auth.h === "left" ? 0 : card.plan.auth.h === "right" ? parent.width - width : (parent.width - width) / 2
            y: 0
            color: "transparent"
            border.width: 2
            border.color: Theme.primary
          }
          Rectangle {
            width: parent.width
            height: 7
            radius: 3.5
            anchors.bottom: parent.bottom
            color: "transparent"
            border.width: 1
            border.color: Theme.primary
          }
        }

        // ── Widgets ──
        Rectangle {
          readonly property bool side: card.plan.widgets === "left" || card.plan.widgets === "right"
          width: side ? screen.width * 0.2 : screen.width * 0.5
          height: side ? screen.height * 0.52 : screen.height * 0.12
          x: side ? (card.plan.widgets === "left" ? screen.m : screen.width - width - screen.m) : (screen.width - width) / 2
          y: side ? (screen.height - height) / 2 + (card.plan.clock.h === card.plan.widgets ? 8 : 0)
                  : screen.height - screen.m - screen.strip - height - 2
          radius: 3
          color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.28)
          border.width: 1
          border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.6)
        }

        // ── Estado ──
        Rectangle {
          width: 14
          height: 3
          radius: 1.5
          x: screen.px(card.plan.status.h, width)
          y: screen.height - screen.m - height
          color: Theme.subtext
        }

        // ── Energía ──
        Rectangle {
          width: 18
          height: 3
          radius: 1.5
          x: screen.px(card.plan.power.h, width)
          y: card.plan.power.v === "top" ? screen.m : screen.height - screen.m - height
          color: Theme.subtext
          opacity: 0.6
        }
      }

      // ── Nombre ──
      Text {
        anchors { left: parent.left; right: parent.right; top: screen.bottom; topMargin: 6 }
        horizontalAlignment: Text.AlignHCenter
        text: Translations.t(root.names[card.modelData])
        color: card.active ? Theme.primary : Theme.text
        font.bold: card.active
        font.pixelSize: Theme.sfs(11)
        font.family: Theme.fontFamily
        elide: Text.ElideRight
      }

      MouseArea {
        id: hit
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.picked(card.modelData)
      }
    }
  }
}
