import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../COMMON"
import "../LANG"

Item {
  id: clipRoot

  property string targetScreen: ""
  property bool panelOpen: false
  property bool depsMissing: false
  property var entries: []
  property int maxEntries: 60
  property int cardWidth: 330
  property int cardHeight: 400
  property int edgeMargin: 18

  function toggle() { clipRoot.panelOpen = !clipRoot.panelOpen }
  function open() { clipRoot.panelOpen = true }
  function close() { clipRoot.panelOpen = false }

  function refresh() {
    if (clipLoader.running) return
    clipLoader.running = true
  }

  function copyEntry(id) {
    const n = parseInt(id)
    if (isNaN(n)) return
    clipCopier.entryId = String(n)
    clipCopier.running = false
    clipCopier.running = true
    clipRoot.panelOpen = false
  }

  function deleteEntry(id) {
    const n = parseInt(id)
    if (isNaN(n)) return
    clipDeleter.entryId = String(n)
    clipDeleter.running = false
    clipDeleter.running = true
  }

  function wipeAll() {
    clipWiper.running = false
    clipWiper.running = true
  }

  onPanelOpenChanged: if (clipRoot.panelOpen) clipRoot.refresh()

  Process {
    id: clipWatcher
    running: true
    command: ["bash", "-c",
      "command -v wl-paste >/dev/null 2>&1 && command -v cliphist >/dev/null 2>&1 || { echo missing; exit 0; }; exec wl-paste --watch cliphist store"]
    stdout: SplitParser {
      onRead: line => { if (line.trim() === "missing") clipRoot.depsMissing = true }
    }
  }

  Process {
    id: clipLoader
    property var buffer: []
    command: ["bash", "-c", "cliphist list 2>/dev/null | head -n " + clipRoot.maxEntries]
    stdout: SplitParser { onRead: line => clipLoader.buffer.push(line) }
    onRunningChanged: {
      if (running) {
        clipLoader.buffer = []
      } else {
        const parsed = []
        for (let i = 0; i < clipLoader.buffer.length; i++) {
          const raw = clipLoader.buffer[i]
          const tab = raw.indexOf("\t")
          if (tab <= 0) continue
          parsed.push({ id: raw.slice(0, tab), text: raw.slice(tab + 1) })
        }
        clipRoot.entries = parsed
      }
    }
  }

  Process {
    id: clipCopier
    property string entryId: ""
    command: ["bash", "-c", "cliphist decode " + entryId + " | wl-copy"]
  }

  Process {
    id: clipDeleter
    property string entryId: ""
    command: ["bash", "-c",
      "cliphist list | awk -F'\\t' -v id=" + entryId + " '$1==id' | cliphist delete"]
    onRunningChanged: if (!running) clipRoot.refresh()
  }

  Process {
    id: clipWiper
    command: ["cliphist", "wipe"]
    onRunningChanged: if (!running) clipRoot.entries = []
  }

  Timer {
    id: clipRefreshTimer
    interval: 1500
    repeat: true
    running: clipRoot.panelOpen
    onTriggered: clipRoot.refresh()
  }

  PanelWindow {
    id: clipWindow

    screen: Quickshell.screens.find(s => s.name === clipRoot.targetScreen) ?? Quickshell.screens[0]
    visible: true
    color: "transparent"
    exclusiveZone: -1

    anchors { top: true; bottom: true; left: true; right: true }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "oozeshell-clipboard"
    WlrLayershell.keyboardFocus: clipRoot.panelOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    mask: Region { item: clipRoot.panelOpen ? clipBackdrop : clipPanelCard }

    Item {
      id: clipKeyCatcher
      anchors.fill: parent
      focus: clipRoot.panelOpen
      Keys.onEscapePressed: clipRoot.close()
    }

    MouseArea {
      id: clipBackdrop
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
      onPressed: clipRoot.close()
    }

    Rectangle {
      id: clipPanelCard
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.rightMargin: clipRoot.edgeMargin + (Theme.barPosition === "right" ? Theme.barOffset : 0)
      anchors.bottomMargin: clipRoot.edgeMargin + (Theme.barAtBottom ? Theme.barOffset : 0)

      readonly property real progress: Math.max(0, Math.min(1, height / clipRoot.cardHeight))

      width: clipRoot.cardWidth
      height: clipRoot.panelOpen ? clipRoot.cardHeight : 0
      clip: true
      radius: Theme.panelRadius
      color: Theme.bg
      opacity: progress
      scale: 0.94 + 0.06 * progress
      transformOrigin: Item.BottomRight

      Behavior on height { NumberAnimation { duration: Theme.animDuration(200); easing.type: Easing.OutCubic } }

      MouseArea {
        id: clipPanelBlocker
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
      }

      Item {
        id: clipPanelContent
        width: clipRoot.cardWidth
        height: clipRoot.cardHeight
        anchors.bottom: parent.bottom

        RowLayout {
          id: clipHeader
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: 14
          height: 30
          spacing: 8

          Text {
            id: clipHeaderTitle
            Layout.fillWidth: true
            text: Translations.t("clipTitle")
            color: Theme.text
            font.pixelSize: 14
            font.bold: true
            font.family: Theme.fontFamily
          }

          Rectangle {
            id: clipClearButton
            visible: clipRoot.entries.length > 0
            Layout.preferredHeight: 26
            Layout.preferredWidth: clipClearLabel.implicitWidth + 20
            radius: 8
            color: clipClearMouse.containsMouse ? Theme.error : Theme.surface
            Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }

            Text {
              id: clipClearLabel
              anchors.centerIn: parent
              text: Translations.t("clipClear")
              color: clipClearMouse.containsMouse ? Theme.textOnPrimary : Theme.subtext
              font.pixelSize: 11
              font.family: Theme.fontFamily
            }

            MouseArea {
              id: clipClearMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: clipRoot.wipeAll()
            }
          }
        }

        ListView {
          id: clipList
          anchors.top: clipHeader.bottom
          anchors.topMargin: 6
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          anchors.leftMargin: 10
          anchors.rightMargin: 10
          anchors.bottomMargin: 10
          clip: true
          spacing: 5
          model: clipRoot.entries
          boundsBehavior: Flickable.StopAtBounds
          visible: clipRoot.entries.length > 0

          delegate: Rectangle {
            id: clipItemDelegate
            required property var modelData

            width: clipList.width
            height: 40
            radius: 8
            color: clipItemMouse.containsMouse ? Qt.alpha(Theme.primary, 0.2) : Theme.surface
            Behavior on color { ColorAnimation { duration: Theme.animDuration(100) } }

            MouseArea {
              id: clipItemMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: clipRoot.copyEntry(clipItemDelegate.modelData.id)
            }

            Text {
              id: clipItemText
              anchors.left: parent.left
              anchors.leftMargin: 10
              anchors.right: clipItemDelete.left
              anchors.rightMargin: 6
              anchors.verticalCenter: parent.verticalCenter
              text: clipItemDelegate.modelData.text
              elide: Text.ElideRight
              maximumLineCount: 1
              color: Theme.text
              font.pixelSize: 12
              font.family: Theme.fontFamily
            }

            Rectangle {
              id: clipItemDelete
              width: 24
              height: 24
              radius: 6
              anchors.right: parent.right
              anchors.rightMargin: 8
              anchors.verticalCenter: parent.verticalCenter
              visible: clipItemMouse.containsMouse || clipItemDeleteMouse.containsMouse
              color: clipItemDeleteMouse.containsMouse ? Theme.error : "transparent"

              Text {
                anchors.centerIn: parent
                text: "✕"
                font.pixelSize: 11
                font.family: Theme.fontFamily
                color: clipItemDeleteMouse.containsMouse ? Theme.textOnPrimary : Theme.subtext
              }

              MouseArea {
                id: clipItemDeleteMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: clipRoot.deleteEntry(clipItemDelegate.modelData.id)
              }
            }
          }
        }

        Text {
          id: clipEmptyState
          anchors.centerIn: parent
          anchors.verticalCenterOffset: 14
          width: parent.width - 48
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.WordWrap
          visible: clipRoot.entries.length === 0
          text: clipRoot.depsMissing ? Translations.t("clipMissing") : Translations.t("clipEmpty")
          color: clipRoot.depsMissing ? Theme.error : Theme.subtext
          font.pixelSize: 12
          font.family: Theme.fontFamily
        }
      }
    }
  }
}
