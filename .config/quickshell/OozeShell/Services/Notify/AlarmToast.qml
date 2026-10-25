import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../../COMMON"

Item {
  id: root

  property string targetScreen: ""
  property int cardWidth: 360
  property int maxCards: 3
  property int showMs: 10000
  property int seq: 0

  // ─── Cola ──────────────────────────────────────────────────────
  ListModel { id: queue }

  function push(title, body, persistent) {
    queue.append({ uid: ++root.seq, title: title, body: body, persistent: persistent })
    while (queue.count > root.maxCards) queue.remove(0)
  }

  function drop(uid) {
    for (let i = 0; i < queue.count; i++) {
      if (queue.get(i).uid === uid) { queue.remove(i); return }
    }
  }

  Connections {
    target: NotificationsBackend
    function onAlarmRaised(summary, body, persistent) { root.push(summary, body, persistent) }
  }

  // ─── Ventana ───────────────────────────────────────────────────
  PanelWindow {
    id: win

    screen: Quickshell.screens.find(s => s.name === root.targetScreen) ?? Quickshell.screens[0]
    visible: queue.count > 0
    color: "transparent"
    exclusiveZone: -1

    anchors { bottom: true; left: true; right: true }
    implicitHeight: 460

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "oozeshell-alarm-toast"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region { item: stack }

    Column {
      id: stack
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 104 + (Theme.barAtBottom ? Theme.barFace : 0)
      width: root.cardWidth
      spacing: 8

      Repeater {
        model: queue

        delegate: Rectangle {
          id: card

          required property int uid
          required property string title
          required property string body
          required property bool persistent

          readonly property int fullHeight: 76
          property bool shown: false
          property bool closing: false

          function dismiss() {
            if (card.closing) return
            card.closing = true
            goneTimer.start()
          }

          width: root.cardWidth
          height: (card.shown && !card.closing) ? card.fullHeight : 0
          clip: true
          radius: Theme.panelRadius
          color: Theme.panelBg
          opacity: Math.max(0, Math.min(1, height / fullHeight))
          scale: 0.94 + 0.06 * opacity

          Behavior on height { NumberAnimation { duration: Theme.animDuration(180); easing.type: Easing.OutCubic } }

          Component.onCompleted: card.shown = true

          Timer {
            interval: root.showMs
            running: !card.persistent && !card.closing && !area.containsMouse
            repeat: false
            onTriggered: card.dismiss()
          }

          Timer {
            id: goneTimer
            interval: 240
            repeat: false
            onTriggered: root.drop(card.uid)
          }

          RowLayout {
            width: card.width - 32
            height: card.fullHeight - 16
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            spacing: 12

            Rectangle {
              Layout.preferredWidth: 40
              Layout.preferredHeight: 40
              Layout.alignment: Qt.AlignVCenter
              radius: 12
              color: Theme.primary

              Text {
                anchors.centerIn: parent
                text: OozeIcons.bellRing
                color: Theme.textOnPrimary
                font.pixelSize: 22
                font.family: Theme.monoFamily
              }
            }

            ColumnLayout {
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignVCenter
              spacing: 2

              Text {
                Layout.fillWidth: true
                text: card.title
                elide: Text.ElideRight
                color: Theme.text
                font.pixelSize: 13
                font.bold: true
                font.family: Theme.fontFamily
              }
              Text {
                Layout.fillWidth: true
                text: card.body
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
                color: Theme.subtext
                font.pixelSize: 11
                font.family: Theme.fontFamily
              }
            }

            Text {
              Layout.alignment: Qt.AlignVCenter
              text: "󰅖"
              color: area.containsMouse ? Theme.text : Theme.subtext
              font.pixelSize: 16
              font.family: Theme.monoFamily
            }
          }

          MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: card.dismiss()
          }
        }
      }
    }
  }
}
