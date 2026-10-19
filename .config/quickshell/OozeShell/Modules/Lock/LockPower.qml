// LockPower

import QtQuick
import "../../COMMON"
import "../../Services/Lang"
import "../Power"

Row {
  id: root

  property real unit: 1
  property string armed: ""

  spacing: Math.round(10 * root.unit)

  // ── Entrada ──
  opacity: 0
  transform: Translate { id: rise; y: Math.round(12 * root.unit) }
  Component.onCompleted: enterAnim.start()

  ParallelAnimation {
    id: enterAnim
    PauseAnimation { duration: Theme.animDuration(240) }
    NumberAnimation { target: root; property: "opacity"; to: 1
      duration: Theme.animDuration(320); easing.type: Easing.OutCubic }
    NumberAnimation { target: rise; property: "y"; to: 0
      duration: Theme.animDuration(460); easing.type: Easing.OutCubic }
  }

  // ── Confirmación ──
  Timer {
    id: disarm
    interval: 3200
    onTriggered: root.armed = ""
  }

  // ── Botones ──
  Repeater {
    model: [
      { id: "reboot",   icon: OozeIcons.reboot, labelKey: "powerReboot" },
      { id: "shutdown", icon: OozeIcons.power,  labelKey: "powerShutdown" }
    ]

    delegate: SkinRect {
      id: btn
      required property var modelData
      readonly property bool isArmed: root.armed === modelData.id

      implicitWidth: label.implicitWidth + icon.implicitWidth + Math.round(34 * root.unit)
      implicitHeight: Math.round(32 * root.unit)
      radius: Theme.cozy ? 4 : height / 2
      color: btn.isArmed ? Theme.error
           : (hit.containsMouse ? Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.78)
                                : Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.5))
      border.width: 1
      border.color: btn.isArmed ? Theme.error : Qt.rgba(1, 1, 1, 0.16)
      Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }

      Row {
        anchors.centerIn: parent
        spacing: Math.round(8 * root.unit)

        Text {
          id: icon
          anchors.verticalCenter: parent.verticalCenter
          text: btn.modelData.icon
          color: btn.isArmed ? Theme.text : Theme.subtext
          font.pixelSize: Math.round(14 * root.unit)
          font.family: Theme.monoFamily
        }
        Text {
          id: label
          anchors.verticalCenter: parent.verticalCenter
          text: btn.isArmed ? Translations.t("lockPowerConfirm") : Translations.t(btn.modelData.labelKey)
          color: btn.isArmed ? Theme.text : Theme.subtext
          font.pixelSize: Math.round(12 * root.unit)
          font.bold: true
          font.family: Theme.fontFamily
        }
      }

      MouseArea {
        id: hit
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          if (btn.isArmed) {
            root.armed = ""
            PowerActions.run(PowerActions.byId(btn.modelData.id))
            return
          }
          root.armed = btn.modelData.id
          disarm.restart()
        }
      }
    }
  }
}
