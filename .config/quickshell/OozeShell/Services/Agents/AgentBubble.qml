import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../COMMON"
import "../Lang"

Item {
  id: root

  property bool open: false
  signal closeRequested()

  readonly property var sp: AgentsService.sizeSpec
  readonly property int fp: AgentsService.fontPx
  readonly property int edge: root.sp.edge
  readonly property int slideDistance: Math.round(28 * Theme.windowScale)
  readonly property int maxH: Math.round(root.sp.maxH * Theme.windowScale)
  readonly property int minH: Math.round(root.sp.minH * Theme.windowScale)
  readonly property bool hasMessages: AgentsService.messages.length > 0

  component Glyph: Rectangle {
    id: g
    property string text: ""
    property bool active: false
    signal clicked()
    implicitWidth: root.sp.glyph
    implicitHeight: root.sp.glyph
    radius: Theme.cozy ? 4 : 8
    color: gArea.containsMouse ? Theme.surfaceHigh : "transparent"
    Text {
      anchors.centerIn: parent
      text: g.text
      color: g.active ? Theme.primary : Theme.subtext
      font.pixelSize: Theme.sfs(root.fp + 2)
      font.family: Theme.monoFamily
    }
    MouseArea {
      id: gArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: g.clicked()
    }
  }

  PanelWindow {
    id: win

    screen: Quickshell.screens.find(s => s.name === AgentsService.screenName) ?? Quickshell.screens[0]
    visible: root.open || card.opacity > 0.02
    color: "transparent"
    exclusiveZone: -1
    anchors { top: true; bottom: true; left: true; right: true }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "oozeshell-agent"
    WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    Item {
      anchors.fill: parent
      focus: true
      Keys.onEscapePressed: root.closeRequested()
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.closeRequested()
    }

    SkinRect {
      id: card

      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.rightMargin: root.edge + (Theme.barVertical && Theme.barAtRight ? Theme.barFace : 0)
      anchors.bottomMargin: root.edge + (Theme.barAtBottom ? Theme.barFace : 0)

      width: Math.round(root.sp.w * Theme.windowScale)
      height: Math.min(root.hasMessages ? root.maxH : root.minH, win.height - root.edge * 2 - 60)
      radius: (root.sp.radius > 0 && !Theme.cozy) ? root.sp.radius : Theme.cardRadius
      color: Theme.surface
      border.width: Theme.bw1 + 0.5
      border.color: Theme.primary
      inkColor: Theme.primary

      property real slide: root.open ? 0 : 1

      opacity: root.open ? 1 : 0
      transform: Translate { y: card.slide * root.slideDistance }
      Behavior on opacity {
        NumberAnimation {
          duration: Theme.animDuration(root.open ? 180 : 140)
          easing.type: root.open ? Easing.OutCubic : Easing.InCubic
        }
      }
      Behavior on slide {
        NumberAnimation {
          duration: Theme.animDuration(root.open ? 220 : 160)
          easing.type: root.open ? Easing.OutCubic : Easing.InCubic
        }
      }
      Behavior on height { NumberAnimation { duration: Theme.animDuration(180); easing.type: Easing.OutCubic } }

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
      }

      Item {
        anchors { fill: parent; margins: root.sp.pad }

        RowLayout {
          id: header
          anchors { left: parent.left; right: parent.right; top: parent.top }
          height: root.sp.head
          spacing: 5

          Text {
            text: "󰚩"
            color: Theme.primary
            font.pixelSize: Theme.sfs(root.fp + 3)
            font.family: Theme.monoFamily
          }
          Text {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: Translations.t("agentsChatTitle")
            color: Theme.text
            font.bold: true
            font.pixelSize: Theme.sfs(root.fp)
            font.family: Theme.fontFamily
          }
          Glyph {
            visible: root.hasMessages
            text: "󰑕"
            onClicked: AgentsService.newChat()
          }
          Glyph {
            text: "󰅖"
            onClicked: root.closeRequested()
          }
        }

        Rectangle {
          id: sep
          anchors { left: parent.left; right: parent.right; top: header.bottom; topMargin: 6 }
          height: 1
          color: Theme.divider
        }

        Text {
          anchors { left: parent.left; right: parent.right; top: sep.bottom; bottom: inputBox.top; margins: 10 }
          visible: !root.hasMessages && (root.sp.hint || !AgentsService.configured)
          wrapMode: Text.WordWrap
          verticalAlignment: Text.AlignVCenter
          horizontalAlignment: Text.AlignHCenter
          text: AgentsService.configured ? Translations.t("agentsHint") : Translations.t("agentsNotConfigured")
          color: Theme.subtext
          font.pixelSize: Theme.sfs(root.fp)
          font.family: Theme.fontFamily
        }

        ListView {
          id: list
          anchors { left: parent.left; right: parent.right; top: sep.bottom; bottom: inputBox.top; topMargin: 8; bottomMargin: 8 }
          visible: root.hasMessages
          clip: true
          spacing: 8
          boundsBehavior: Flickable.StopAtBounds
          model: AgentsService.messages
          onCountChanged: Qt.callLater(list.positionViewAtEnd)

          footer: Item {
            width: list.width
            height: AgentsService.busy ? 30 : 0
            Text {
              visible: AgentsService.busy
              anchors { left: parent.left; leftMargin: 6; verticalCenter: parent.verticalCenter }
              text: Translations.t("agentsThinking")
              color: Theme.subtext
              font.pixelSize: Theme.sfs(root.fp)
              font.family: Theme.fontFamily
              SequentialAnimation on opacity {
                running: AgentsService.busy
                loops: Animation.Infinite
                NumberAnimation { from: 1; to: 0.3; duration: 700 }
                NumberAnimation { from: 0.3; to: 1; duration: 700 }
              }
            }
          }

          delegate: Item {
            id: row
            required property var modelData
            readonly property bool mine: modelData.role === "user"
            readonly property bool failed: modelData.error === true
            property bool copied: false

            width: list.width
            height: bub.height

            Timer {
              id: copiedTimer
              interval: 1300
              onTriggered: row.copied = false
            }

            Rectangle {
              id: bub
              anchors.right: row.mine ? parent.right : undefined
              anchors.left: row.mine ? undefined : parent.left
              width: row.mine ? Math.min(row.width - 40, mineText.implicitWidth + 24) : row.width - 8
              height: row.mine ? mineText.implicitHeight + 20 : bodyCol.implicitHeight + 16
              radius: Theme.cozy ? 4 : 12
              color: row.mine ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2)
                              : (row.failed ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.14) : Theme.bg)
              border.width: row.mine ? 0 : Theme.bw1
              border.color: row.failed ? Theme.error : Theme.edge

              Text {
                id: mineText
                visible: row.mine
                x: 12
                y: 10
                width: bub.width - 24
                text: row.modelData.text
                wrapMode: Text.Wrap
                color: Theme.text
                font.pixelSize: Theme.sfs(root.fp)
                font.family: Theme.fontFamily
              }

              Column {
                id: bodyCol
                visible: !row.mine
                x: 12
                y: 8
                width: bub.width - 24
                spacing: 4

                TextEdit {
                  width: parent.width
                  readOnly: true
                  selectByMouse: true
                  wrapMode: TextEdit.Wrap
                  textFormat: row.failed ? TextEdit.PlainText : TextEdit.MarkdownText
                  text: row.modelData.text
                  color: row.failed ? Theme.error : Theme.text
                  selectionColor: Theme.primary
                  selectedTextColor: Theme.textOnPrimary
                  font.pixelSize: Theme.sfs(root.fp)
                  font.family: Theme.fontFamily
                }

                Item {
                  visible: !row.failed
                  width: parent.width
                  height: root.sp.copy
                  Glyph {
                    anchors.right: parent.right
                    implicitHeight: root.sp.copy
                    implicitWidth: root.sp.copy
                    active: row.copied
                    text: row.copied ? "󰄬" : "󰆏"
                    onClicked: {
                      AgentsService.copyText(row.modelData.text)
                      row.copied = true
                      copiedTimer.restart()
                    }
                  }
                }
              }
            }
          }
        }

        SkinRect {
          id: inputBox
          anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
          height: root.sp.input
          radius: Theme.cozy ? 4 : 12
          color: Theme.surfaceHigh
          border.width: input.activeFocus ? 1 : 0
          border.color: Theme.primary
          opacity: AgentsService.configured ? 1 : 0.5

          TextInput {
            id: input
            anchors { left: parent.left; right: pasteBtn.left; verticalCenter: parent.verticalCenter; leftMargin: 10; rightMargin: 4 }
            enabled: AgentsService.configured
            color: Theme.text
            selectionColor: Theme.primary
            selectedTextColor: Theme.textOnPrimary
            selectByMouse: true
            clip: true
            font.pixelSize: Theme.sfs(root.fp)
            font.family: Theme.fontFamily
            inputMethodHints: Qt.ImhNoPredictiveText
            Keys.onEscapePressed: root.closeRequested()
            onAccepted: root.send()
            Keys.onPressed: event => {
              const ctrlV = event.key === Qt.Key_V && (event.modifiers & Qt.ControlModifier)
              const shiftIns = event.key === Qt.Key_Insert && (event.modifiers & Qt.ShiftModifier)
              if (ctrlV || shiftIns) {
                root.pasteClipboard()
                event.accepted = true
              }
            }
          }

          Glyph {
            id: pasteBtn
            anchors { right: sendBtn.left; verticalCenter: parent.verticalCenter }
            enabled: AgentsService.configured
            text: "󰆒"
            onClicked: root.pasteClipboard()
          }

          Glyph {
            id: sendBtn
            anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
            text: AgentsService.busy ? "󰓛" : "󰒊"
            active: input.text !== "" || AgentsService.busy
            onClicked: AgentsService.busy ? AgentsService.cancel() : root.send()
          }
        }
      }
    }
  }

  Process {
    id: pasteProc
    command: ["wl-paste", "--no-newline"]
    stdout: StdioCollector {
      onStreamFinished: root.insertPasted(text)
    }
  }

  function pasteClipboard() {
    pasteProc.running = false
    pasteProc.running = true
  }

  function insertPasted(raw) {
    const t = String(raw ?? "").replace(/\s*[\r\n]+\s*/g, " ")
    if (t === "") return
    if (input.selectedText !== "") input.remove(input.selectionStart, input.selectionEnd)
    input.insert(input.cursorPosition, t)
    input.forceActiveFocus()
  }

  function send() {
    const t = input.text
    if (t.trim() === "" || AgentsService.busy) return
    input.text = ""
    AgentsService.ask(t)
  }

  Timer {
    id: focusTimer
    interval: 90
    onTriggered: input.forceActiveFocus()
  }

  onOpenChanged: if (root.open) focusTimer.restart()
}
