// MÓDULO — Overview: cuadrícula de todas las ventanas abiertas.

import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../../COMMON"
import "../../Services/Lang"

Item {
  id: root

  property bool open: false
  property string targetScreen: ""
  signal closeRequested()

  // ─── Medidas ────────────────────────────────────────────────────
  readonly property real panelFrac: 0.9
  readonly property int pad: 22
  readonly property int gap: 16
  readonly property int cardHead: 46
  readonly property int minCardW: 250
  readonly property int maxCardW: 460

  // ─── Ventanas ───────────────────────────────────────────────────
  property var clients: WM.clients
  property var monitors: WM.monitors

  readonly property bool multiMonitor: root.monitors.length > 1

  readonly property var windows: {
    const out = []
    const list = root.clients
    for (let i = 0; i < list.length; i++) {
      const c = list[i]
      if (!c.address || c.mapped === false || c.hidden === true) continue
      out.push({
        address: c.address,
        cls: c["class"] || c.initialClass || "",
        title: c.title || "",
        wsId: c.workspace ? c.workspace.id : 0,
        wsName: c.workspace ? String(c.workspace.name) : "",
        monitor: c.monitor || "",
        floating: !!c.floating,
        focusRank: c.focusHistoryID ?? 999
      })
    }
    out.sort((a, b) => a.focusRank - b.focusRank)
    return out
  }
  readonly property int count: root.windows.length

  readonly property real aspect: {
    const m = root.monitors.find(x => x.name === root.targetScreen) ?? root.monitors[0]
    if (!m || !m.width || !m.height) return 9 / 16
    const rot = (m.transform % 2) === 1
    const w = rot ? m.height : m.width
    const h = rot ? m.width : m.height
    return Math.max(0.45, Math.min(0.75, h / w))
  }

  // ─── Disposición ────────────────────────────────────────────────
  readonly property real gridW: area.width
  readonly property real gridH: area.height

  readonly property int columns: {
    const n = Math.max(1, root.count)
    const maxCols = Math.max(1, Math.min(n, Math.floor((root.gridW + root.gap) / (root.minCardW + root.gap))))
    let best = maxCols
    let bestW = -1
    for (let c = 1; c <= maxCols; c++) {
      const cw = Math.min(root.maxCardW, (root.gridW - (c - 1) * root.gap) / c)
      const ch = cw * root.aspect + root.cardHead
      const rows = Math.ceil(n / c)
      if (rows * ch + (rows - 1) * root.gap > root.gridH) continue
      if (cw >= bestW - 0.5) { best = c; bestW = cw }
    }
    return best
  }
  readonly property int rows: Math.max(1, Math.ceil(root.count / root.columns))
  readonly property real cardW: Math.min(root.maxCardW, (root.gridW - (root.columns - 1) * root.gap) / root.columns)
  readonly property real cardH: root.cardW * root.aspect + root.cardHead

  readonly property var keyHints: ["← ↑ ↓ →", "↵", "1–9", "Esc"]

  // ─── Componentes ────────────────────────────────────────────────
  component KeyCap: Rectangle {
    id: cap
    property string label: ""
    property bool accent: false
    implicitWidth: Math.max(26, capText.implicitWidth + 14)
    implicitHeight: 24
    radius: 7
    color: cap.accent ? Theme.primary : Theme.surface
    border.width: Theme.bw1
    border.color: cap.accent ? "transparent" : Theme.edge

    Text {
      id: capText
      anchors.centerIn: parent
      text: cap.label
      color: cap.accent ? Theme.textOnPrimary : Theme.subtext
      font.bold: true
      font.pixelSize: Theme.fs(10)
      font.family: Theme.fontFamily
    }
  }

  // ─── Selección ──────────────────────────────────────────────────
  property int selected: 0
  onCountChanged: if (selected >= count) selected = Math.max(0, count - 1)

  onOpenChanged: {
    if (root.open) {
      WM.retainClients("overview")
      WM.refreshClients()
      root.selected = 0
    } else {
      WM.releaseClients("overview")
    }
  }

  // ─── Utilidades ─────────────────────────────────────────────────
  function iconFor(appId) {
    const entry = appId !== "" ? DesktopEntries.heuristicLookup(appId) : null
    const name = (entry && entry.icon) ? entry.icon : appId
    return Quickshell.iconPath(name, "application-x-executable")
  }

  function badgeFor(w) {
    return w.wsId > 0 ? String(w.wsId) : w.wsName
  }

  // ─── Acciones ───────────────────────────────────────────────────
  property string pendingAddress: ""

  function activate(w) {
    if (!w) return
    root.pendingAddress = w.address
    root.closeRequested()
    focusTimer.restart()
  }

  Timer {
    id: focusTimer
    interval: 140
    repeat: false
    onTriggered: {
      const a = root.pendingAddress
      root.pendingAddress = ""
      if (a !== "") WM.focusWindow(a)
    }
  }

  // ─── Teclado ────────────────────────────────────────────────────
  function stepBy(d) {
    if (root.count > 0) root.selected = (root.selected + d + root.count) % root.count
  }

  function jump(dir) {
    let t = root.selected + dir * root.columns
    if (t >= root.count && Math.floor(root.selected / root.columns) < Math.floor((root.count - 1) / root.columns))
      t = root.count - 1
    if (t >= 0 && t < root.count) root.selected = t
  }

  function handleKey(key, modifiers) {
    const shift = (modifiers & Qt.ShiftModifier) !== 0

    switch (key) {
      case Qt.Key_Left:
      case Qt.Key_H:       root.stepBy(-1); return
      case Qt.Key_Right:
      case Qt.Key_L:       root.stepBy(1); return
      case Qt.Key_Up:
      case Qt.Key_K:       root.jump(-1); return
      case Qt.Key_Down:
      case Qt.Key_J:       root.jump(1); return
      case Qt.Key_Tab:     root.stepBy(shift ? -1 : 1); return
      case Qt.Key_Backtab: root.stepBy(-1); return
      case Qt.Key_Home:    root.selected = 0; return
      case Qt.Key_End:     root.selected = Math.max(0, root.count - 1); return
      case Qt.Key_Return:
      case Qt.Key_Enter:
      case Qt.Key_Space:   root.activate(root.windows[root.selected]); return
    }

    if (key >= Qt.Key_1 && key <= Qt.Key_9) root.activate(root.windows[key - Qt.Key_1])
  }

  // ─── Superficie ─────────────────────────────────────────────────
  PanelWindow {
    id: win

    screen: Quickshell.screens.find(s => s.name === root.targetScreen) ?? Quickshell.screens[0]
    visible: root.open || panel.opacity > 0.01
    color: "transparent"
    exclusiveZone: -1
    anchors { top: true; left: true; right: true; bottom: true }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "oozeshell-overview"
    WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Connections {
      target: root
      function onOpenChanged() {
        if (root.open) keyCatcher.forceActiveFocus()
      }
    }
    onVisibleChanged: if (visible && root.open) keyCatcher.forceActiveFocus()

    // ── Fondo ────────────────────────────────────────────────
    Rectangle {
      anchors.fill: parent
      color: Qt.rgba(0, 0, 0, 0.5)
      opacity: panel.opacity

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onClicked: root.closeRequested()
      }
    }

    // ── Panel ────────────────────────────────────────────────
    SkinRect {
      id: panel
      anchors.centerIn: parent
      width: Math.round(parent.width * root.panelFrac)
      height: Math.round(parent.height * root.panelFrac)
      color: Theme.panelBg
      radius: Theme.cardRadius + 8
      border.width: Theme.bw1
      border.color: Theme.edge

      opacity: root.open ? 1 : 0
      scale: root.open ? 1 : 0.96
      Behavior on opacity { NumberAnimation { duration: Theme.animDuration(160); easing.type: Easing.OutCubic } }
      Behavior on scale { NumberAnimation { duration: Theme.animDuration(220); easing.type: Easing.OutCubic } }

      MouseArea { anchors.fill: parent }

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.pad
        spacing: 16

        // ── Cabecera ─────────────────────────────────────────
        RowLayout {
          id: header
          Layout.fillWidth: true
          spacing: 12

          Rectangle {
            Layout.preferredWidth: 38
            Layout.preferredHeight: 38
            radius: 12
            color: Qt.alpha(Theme.primary, 0.16)

            Text {
              anchors.centerIn: parent
              text: "󰖲"
              color: Theme.primary
              font.pixelSize: Theme.fs(20)
              font.family: Theme.monoFamily
            }
          }

          Text {
            text: Translations.t("overviewTitle")
            color: Theme.text
            font.bold: true
            font.pixelSize: Theme.fs(17)
            font.family: Theme.fontFamily
          }

          Rectangle {
            visible: root.count > 0
            Layout.preferredWidth: Math.max(24, countText.implicitWidth + 14)
            Layout.preferredHeight: 22
            radius: 11
            color: Theme.surface
            border.width: Theme.bw1
            border.color: Theme.edge

            Text {
              id: countText
              anchors.centerIn: parent
              text: root.count
              color: Theme.subtext
              font.bold: true
              font.pixelSize: Theme.fs(11)
              font.family: Theme.fontFamily
            }
          }

          Item { Layout.fillWidth: true }

          Repeater {
            model: root.keyHints
            KeyCap {
              required property string modelData
              label: modelData
            }
          }

          Rectangle {
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            Layout.leftMargin: 6
            radius: 10
            color: closeArea.containsMouse ? Qt.alpha(Theme.error, 0.18) : Theme.surface
            border.width: Theme.bw1
            border.color: closeArea.containsMouse ? Theme.error : Theme.edge
            Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }

            Text {
              anchors.centerIn: parent
              text: "󰅖"
              color: closeArea.containsMouse ? Theme.error : Theme.subtext
              font.pixelSize: Theme.fs(14)
              font.family: Theme.monoFamily
            }
            MouseArea {
              id: closeArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.closeRequested()
            }
          }
        }

        // ── Cuadrícula ───────────────────────────────────────
        Item {
          id: area
          Layout.fillWidth: true
          Layout.fillHeight: true

          ColumnLayout {
            anchors.centerIn: parent
            visible: root.count === 0
            spacing: 10

            Text {
              Layout.alignment: Qt.AlignHCenter
              text: "󰖲"
              color: Theme.subtext
              opacity: 0.5
              font.pixelSize: Theme.fs(48)
              font.family: Theme.monoFamily
            }
            Text {
              Layout.alignment: Qt.AlignHCenter
              text: Translations.t("overviewEmpty")
              color: Theme.subtext
              font.pixelSize: Theme.fs(14)
              font.family: Theme.fontFamily
            }
          }

          GridView {
            id: grid
            anchors.centerIn: parent
            width: root.columns * cellWidth
            height: Math.min(area.height, root.rows * cellHeight)
            cellWidth: root.cardW + root.gap
            cellHeight: root.cardH + root.gap
            clip: true
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            model: root.windows
            currentIndex: root.selected

            onCurrentIndexChanged: positionViewAtIndex(currentIndex, GridView.Contain)

            delegate: Item {
              id: cell
              required property var modelData
              required property int index

              width: grid.cellWidth
              height: grid.cellHeight

              readonly property bool isSelected: root.selected === cell.index
              readonly property bool isFocused: cell.modelData.focusRank === 0
              readonly property bool onActiveWs: WM.activeWorkspaceId(cell.modelData.monitor) === cell.modelData.wsId
              readonly property var toplevel: root.open ? WM.toplevelFor(cell.modelData.address) : null
              property bool shown: false

              Timer {
                interval: Math.min(cell.index, 12) * 30
                running: root.open
                onTriggered: cell.shown = true
              }
              Connections {
                target: root
                function onOpenChanged() { if (!root.open) cell.shown = false }
              }

              Rectangle {
                id: card
                x: root.gap / 2
                y: root.gap / 2 + (cell.shown ? 0 : 16)
                width: root.cardW
                height: root.cardH
                radius: 16
                color: cell.isSelected ? Theme.surfaceHigh : Theme.surface
                border.width: 2
                border.color: cell.isSelected ? Theme.primary : Theme.edge
                opacity: cell.shown ? 1 : 0

                scale: cardArea.pressed ? 0.97 : (cell.isSelected ? 1.025 : 1.0)

                Behavior on y { NumberAnimation { duration: Theme.animDuration(260); easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: Theme.animDuration(220) } }
                Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
                Behavior on border.color { ColorAnimation { duration: Theme.animDuration(150) } }
                Behavior on scale { NumberAnimation { duration: Theme.animDuration(160); easing.type: Easing.OutBack } }

                MouseArea {
                  id: cardArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onPositionChanged: root.selected = cell.index
                  onClicked: root.activate(cell.modelData)
                }

                // ── Cabecera de la tarjeta ──
                RowLayout {
                  x: 12
                  y: 0
                  width: parent.width - 24
                  height: root.cardHead
                  spacing: 10

                  IconImage {
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    asynchronous: true
                    source: root.iconFor(cell.modelData.cls)
                  }

                  ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: 0

                    Text {
                      Layout.fillWidth: true
                      text: cell.modelData.title !== "" ? cell.modelData.title : cell.modelData.cls
                      color: cell.isFocused ? Theme.primary : Theme.text
                      font.bold: true
                      font.pixelSize: Theme.fs(12)
                      font.family: Theme.fontFamily
                      elide: Text.ElideRight
                    }
                    Text {
                      Layout.fillWidth: true
                      visible: cell.modelData.cls !== ""
                      text: cell.modelData.cls + (root.multiMonitor && cell.modelData.monitor !== "" ? "  ·  " + cell.modelData.monitor : "")
                      color: Theme.subtext
                      font.pixelSize: Theme.fs(10)
                      font.family: Theme.fontFamily
                      elide: Text.ElideRight
                    }
                  }

                  Rectangle {
                    visible: cell.modelData.floating
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: 22
                    radius: 7
                    color: Theme.bg

                    Text {
                      anchors.centerIn: parent
                      text: "󰹙"
                      color: Theme.subtext
                      font.pixelSize: Theme.fs(12)
                      font.family: Theme.monoFamily
                    }
                  }

                  Rectangle {
                    Layout.preferredWidth: Math.max(24, badgeText.implicitWidth + 14)
                    Layout.preferredHeight: 24
                    radius: 8
                    color: cell.onActiveWs ? Theme.primary : Theme.bg

                    Text {
                      id: badgeText
                      anchors.centerIn: parent
                      text: root.badgeFor(cell.modelData)
                      color: cell.onActiveWs ? Theme.textOnPrimary : Theme.text
                      font.bold: true
                      font.pixelSize: Theme.fs(11)
                      font.family: Theme.fontFamily
                    }
                  }
                }

                // ── Miniatura ──
                Rectangle {
                  id: thumb
                  x: 10
                  y: root.cardHead
                  width: parent.width - 20
                  height: parent.height - root.cardHead - 10
                  radius: 10
                  color: Theme.bg
                  border.width: Theme.bw1
                  border.color: Theme.edge
                  clip: true

                  IconImage {
                    anchors.centerIn: parent
                    width: Math.min(72, Math.min(thumb.width, thumb.height) * 0.42)
                    height: width
                    visible: !shot.hasContent
                    opacity: 0.9
                    asynchronous: true
                    source: root.iconFor(cell.modelData.cls)
                  }

                  ScreencopyView {
                    id: shot
                    readonly property real fit: (implicitWidth > 0 && implicitHeight > 0)
                      ? Math.min(thumb.width / implicitWidth, thumb.height / implicitHeight) : 1
                    anchors.centerIn: parent
                    width: implicitWidth > 0 ? implicitWidth * fit : thumb.width
                    height: implicitHeight > 0 ? implicitHeight * fit : thumb.height
                    captureSource: cell.toplevel
                    live: cell.onActiveWs
                    paintCursor: false
                    visible: hasContent
                    Component.onCompleted: if (!live && captureSource) captureFrame()
                    onCaptureSourceChanged: if (!live && captureSource) captureFrame()
                  }

                  KeyCap {
                    visible: cell.index < 9
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 8
                    accent: cell.isSelected
                    label: String(cell.index + 1)
                  }
                }
              }
            }
          }
        }
      }
    }

    // ── Teclado ──────────────────────────────────────────────
    Item {
      id: keyCatcher
      anchors.fill: parent
      focus: true
      Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
          root.closeRequested()
          event.accepted = true
        } else {
          root.handleKey(event.key, event.modifiers)
          event.accepted = true
        }
      }
    }
  }
}
