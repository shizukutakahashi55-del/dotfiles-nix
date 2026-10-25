// PowerMenu.qml — POWER

import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../COMMON"
import "../../Services/Lang"

// ─────────────────────────────────────────────────────────────────


// ─────────────────────────────────────────────────────────────────
Item {
  id: root

  property bool open: false
  property string targetScreen: ""
  property int edgeMargin: 10

  readonly property int pad: 14
  readonly property int cardW: 300

  signal closeRequested()


  readonly property var actions: PowerActions.actions


  property var pending: null

  property int sel: 0

  readonly property int count: root.pending ? 2 : root.actions.length
  readonly property color pendingAccent:
    (root.pending && root.pending.id === "shutdown") ? Theme.error : Theme.primary

  function withAlpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

  onOpenChanged: {
    if (!root.open) return
    root.pending = null
    root.sel = 0
  }

  function move(delta) {
    root.sel = (root.sel + delta + root.count) % root.count
  }

  function choose(i) {
    if (i < 0 || i >= root.actions.length) return
    root.pending = root.actions[i]
    root.sel = 1
  }

  function back() {
    root.pending = null
    root.sel = 0
  }

  function activate() {
    if (!root.pending) {
      root.choose(root.sel)
    } else if (root.sel === 1) {
      root.run(root.pending)
    } else {
      root.back()
    }
  }


  property var toRun: null
  function run(a) {
    root.toRun = a
    root.closeRequested()
    runTimer.restart()
  }
  Timer {
    id: runTimer
    interval: 180
    repeat: false
    onTriggered: {
      PowerActions.run(root.toRun)
      root.toRun = null
    }
  }

  function handleKey(key, modifiers) {
    if (key === Qt.Key_Escape) {
      if (root.pending) root.back()
      else root.closeRequested()
      return
    }
    if (!root.pending && key >= Qt.Key_1 && key <= Qt.Key_9
        && (key - Qt.Key_1) < root.actions.length) {
      root.choose(key - Qt.Key_1)
      return
    }
    switch (key) {
      case Qt.Key_Return:
      case Qt.Key_Enter:
      case Qt.Key_Space:
        root.activate()
        break
      case Qt.Key_Down:
      case Qt.Key_J:
      case Qt.Key_Right:
      case Qt.Key_Tab:
      case Qt.Key_L:
        root.move(1)
        break
      case Qt.Key_Up:
      case Qt.Key_K:
      case Qt.Key_Left:
      case Qt.Key_Backtab:
      case Qt.Key_H:
        root.move(-1)
        break
    }
  }

  FusedWindow {
    id: fw
    active: root.open || panel.shown
    targetScreen: root.targetScreen
    namespace: "oozeshell-powermenu"
    exclusiveKeys: true
    onCloseRequested: root.closeRequested()
    onKeyPressed: (key, modifiers, text) => root.handleKey(key, modifiers)

    FusedPanel {
      id: panel

      open: root.open
      panelWidth: root.cardW
      contentHeight: col.implicitHeight + root.pad * 2


      moduleId: "power"


      align: Theme.popupAlign("power", "start")
      alignMargin: root.edgeMargin + Theme.barEdge

      ColumnLayout {
        id: col
        x: root.pad
        y: root.pad
        width: parent.width - root.pad * 2
        spacing: 6

        RowLayout {
          Layout.fillWidth: true
          spacing: 8
          Text {
            text: OozeIcons.nixos
            color: Theme.primary
            font.pixelSize: Theme.fs(15)
            font.family: Theme.monoFamily
          }
          Text {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: Translations.t("menuSectionPower")
            color: Theme.text
            font.pixelSize: Theme.fs(13)
            font.bold: true
            font.family: Theme.fontFamily
          }
          Text {
            text: OozeIcons.power
            color: Theme.subtext
            font.pixelSize: Theme.fs(13)
            font.family: Theme.monoFamily
          }
        }

        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: 1
          color: Theme.divider
        }

        Repeater {
          model: root.pending ? ["no", "yes"] : root.actions

          delegate: SkinRect {
            id: rowBtn
            required property var modelData
            required property int index

            readonly property bool isToggle: typeof modelData === "string"
            readonly property bool isYes: rowBtn.isToggle && modelData === "yes"
            readonly property var action: rowBtn.isToggle
              ? (rowBtn.isYes ? root.pending : null) : rowBtn.modelData
            readonly property bool selected: rowBtn.isToggle
              ? (root.sel === rowBtn.index)
              : (!root.pending && root.sel === rowBtn.index)
            readonly property color accent: (rowBtn.action && rowBtn.action.id === "shutdown")
              ? Theme.error : Theme.primary
            readonly property color onAccent: (rowBtn.action && rowBtn.action.id === "shutdown")
              ? Theme.textOnError : Theme.textOnPrimary

            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(Theme.fs(34))
            radius: Theme.cardRadius - 2
            color: Theme.surface
            clip: true

            Rectangle {
              anchors.left: parent.left
              anchors.top: parent.top
              anchors.bottom: parent.bottom
              width: rowBtn.selected ? parent.width : 0
              radius: rowBtn.radius
              color: rowBtn.accent
              Behavior on width { NumberAnimation { duration: Theme.animDuration(160); easing.type: Easing.OutCubic } }
            }

            RowLayout {
              z: 1
              anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
              spacing: 12
              Text {
                Layout.preferredWidth: 28
                horizontalAlignment: Text.AlignHCenter
                text: rowBtn.isToggle
                  ? (rowBtn.isYes ? rowBtn.action.icon : OozeIcons.close)
                  : rowBtn.action.icon
                color: rowBtn.selected ? rowBtn.onAccent : rowBtn.accent
                font.pixelSize: Theme.fs(18)
                font.family: Theme.monoFamily
                Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }
              }
              Text {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: {
                  if (!rowBtn.isToggle) return Translations.t(rowBtn.action.labelKey)
                  return rowBtn.isYes
                    ? Translations.t("dashboardConfirm")
                    : Translations.t("powerCancel")
                }
                color: rowBtn.selected ? rowBtn.onAccent : Theme.text
                font.pixelSize: Theme.fs(13)
                font.weight: Font.Medium
                font.family: Theme.fontFamily
                Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }
              }
              Text {
                visible: !rowBtn.isToggle
                text: String(rowBtn.index + 1)
                color: rowBtn.selected ? rowBtn.onAccent : Theme.subtext
                font.pixelSize: Theme.fs(11)
                font.family: Theme.monoFamily
                Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }
              }
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onEntered: root.sel = rowBtn.index
              onClicked: {
                if (rowBtn.isToggle) {
                  root.sel = rowBtn.index
                  root.activate()
                } else {
                  root.choose(rowBtn.index)
                }
              }
            }
          }
        }

        Text {
          Layout.fillWidth: true
          horizontalAlignment: Text.AlignCenter
          text: root.pending ? Translations.t(root.pending.confirmKey) : Translations.t("dashboardPowerHint")
          color: Theme.subtext
          font.pixelSize: Theme.fs(10)
          font.family: Theme.fontFamily
          wrapMode: Text.Wrap
        }
      }
    }
  }
}
