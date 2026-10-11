// Overview — vista general de los workspaces (botón junto al reloj).
// Es un FusedPanel: cuelga de la barra, centrado bajo el botón, con el mismo color, curvas y animación que Menu / Notify / Calendario.

import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../COMMON"
import "../LANG"

Item {
  id: root

  property bool open: false
  property string targetScreen: ""
  signal closeRequested()

  // ─── Medidas (lógicas: FusedPanel las escala según Ajustes → Ventanas) ──
  readonly property int cardW: 220
  readonly property int cardPad: 8
  readonly property int headH: 26
  readonly property int gap: 10
  readonly property int maxColumns: 5
  readonly property int minColumns: 3

  readonly property int pad: 16
  readonly property real miniW: cardW - cardPad * 2
  readonly property real miniH: miniW * aspect
  readonly property real cardH: cardPad * 2 + headH + 6 + miniH

  // ─── Workspaces ─────────────────────────────────────────────────


  readonly property var workspaceList: WM.workspacesFor(root.targetScreen, false)
  readonly property int count: workspaceList.length

  // ─── Disposición ────────────────────────────────────────────────


  readonly property bool vertical: Theme.barVertical


  readonly property real fitBaseScale: Math.min(Theme.windowScale, 1)

  readonly property int rowsFit: {
    const availH = (fw.screenHeight - 16 - Theme.flare * 2) / root.fitBaseScale
                   - root.pad * 2 - header.implicitHeight - col.spacing
    return Math.max(1, Math.floor((availH + root.gap) / (root.cardH + root.gap)))
  }

  readonly property int stackRows: Math.max(1, Math.min(count, rowsFit))

  readonly property int columns: vertical
    ? Math.max(1, Math.ceil(count / stackRows))
    : Math.max(1, Math.min(count, maxColumns))


  readonly property int stride: vertical ? stackRows : columns


  readonly property int panelColumns: vertical ? columns : Math.max(columns, minColumns)
  readonly property real contentWidth: panelColumns * cardW + (panelColumns - 1) * gap + pad * 2


  readonly property string keysHint: "← → ↑ ↓  ·  ↵  ·  1–9  ·  Esc"


  property int selected: 0
  onCountChanged: if (selected >= count) selected = Math.max(0, count - 1)

  function activeIndex() {
    const list = root.workspaceList

    let i = list.findIndex(w => w.active && (WM.wsMonitorName(w) || root.targetScreen) === root.targetScreen)
    if (i < 0) i = list.findIndex(w => w.active)
    return Math.max(0, i)
  }

  onOpenChanged: {
    if (root.open) {

      WM.retainClients("overview")
      root.refresh(true)
      root.selected = root.activeIndex()
    } else {
      WM.releaseClients("overview")
    }
  }

  // ─── Ventanas y monitores (capa común: COMMON/WM.qml) ───────────
  property var clients: WM.clients
  property var monitors: WM.monitors


  readonly property real aspect: {
    const m = root.monitors.find(x => x.name === root.targetScreen) ?? root.monitors[0]
    if (!m || !m.width || !m.height) return 9 / 16
    const rot = (m.transform % 2) === 1
    const w = rot ? m.height : m.width
    const h = rot ? m.width : m.height
    return Math.max(0.35, Math.min(1.0, h / w))
  }


  function refresh(withMonitors) { WM.refreshClients() }


  function monitorOf(c) {
    return root.monitors.find(m => m.name === c.monitor) ?? root.monitors[0] ?? null
  }


  function relRect(c) {
    const m = root.monitorOf(c)
    if (!m || !c.at || !c.size) return { x: 0, y: 0, w: 1, h: 1 }
    const rot = (m.transform % 2) === 1
    const s = m.scale > 0 ? m.scale : 1
    const mw = (rot ? m.height : m.width) / s
    const mh = (rot ? m.width : m.height) / s
    const x = Math.max(0, Math.min(1, (c.at[0] - m.x) / mw))
    const y = Math.max(0, Math.min(1, (c.at[1] - m.y) / mh))
    return {
      x: x, y: y,
      w: Math.max(0, Math.min(1 - x, c.size[0] / mw)),
      h: Math.max(0, Math.min(1 - y, c.size[1] / mh))
    }
  }


  function windowsOf(wsId) {
    const out = []
    const list = root.clients
    for (let i = 0; i < list.length; i++) {
      const c = list[i]
      if (!c.workspace || c.workspace.id !== wsId) continue

      if (WM.perMonitorWorkspaces && c.monitor !== root.targetScreen) continue

      if (!c.at) continue
      const r = root.relRect(c)
      out.push({
        address: c.address,
        cls: c["class"] || c.initialClass || "",
        title: c.title || "",
        rx: r.x, ry: r.y, rw: r.w, rh: r.h,
        floating: !!c.floating,
        focused: c.focusHistoryID === 0
      })
    }
    out.sort((a, b) => (a.floating ? 1 : 0) - (b.floating ? 1 : 0))
    return out
  }


  function iconFor(appId) {
    const entry = appId !== "" ? DesktopEntries.heuristicLookup(appId) : null
    const name = (entry && entry.icon) ? entry.icon : appId
    return Quickshell.iconPath(name, "application-x-executable")
  }

  // ─── Captura de ventanas ────────────────────────────────────────

  function toplevelFor(address) { return WM.toplevelFor(address) }

  // ─── Acciones ───────────────────────────────────────────────────
  function goTo(ws) {
    if (!ws) return
    ws.activate()
    root.closeRequested()
  }


  function goToId(id) {
    const ws = root.workspaceList.find(w => w.id === id)
    if (ws) ws.activate()
    else WM.workspace(id, root.targetScreen)
    root.closeRequested()
  }

  function focusWindow(ws, address) {
    ws.activate()


    WM.focusWindow(address)
    root.closeRequested()
  }

  // ─── Teclado ────────────────────────────────────────────────────
  function step(d) {
    if (root.count > 0) root.selected = (root.selected + d + root.count) % root.count
  }


  function jump(dir) {
    const s = root.stride
    let t = root.selected + dir * s

    if (t >= root.count && Math.floor(root.selected / s) < Math.floor((root.count - 1) / s))
      t = root.count - 1
    if (t >= 0 && t < root.count) root.selected = t
  }


  function arrow(dx, dy) {
    if (!root.vertical) {
      if (dx !== 0) root.step(dx)
      else root.jump(dy)
    } else {
      if (dy !== 0) root.step(dy)
      else if (root.columns > 1) root.jump(dx)
      else root.step(dx)
    }
  }

  function handleKey(key, modifiers) {
    const shift = (modifiers & Qt.ShiftModifier) !== 0

    switch (key) {
      case Qt.Key_Left:
      case Qt.Key_H:       root.arrow(-1, 0); return
      case Qt.Key_Right:
      case Qt.Key_L:       root.arrow(1, 0); return
      case Qt.Key_Up:
      case Qt.Key_K:       root.arrow(0, -1); return
      case Qt.Key_Down:
      case Qt.Key_J:       root.arrow(0, 1); return
      case Qt.Key_Tab:     root.step(shift ? -1 : 1); return
      case Qt.Key_Backtab: root.step(-1); return
      case Qt.Key_Home:    root.selected = 0; return
      case Qt.Key_End:     root.selected = Math.max(0, root.count - 1); return
      case Qt.Key_Return:
      case Qt.Key_Enter:
      case Qt.Key_Space:   root.goTo(root.workspaceList[root.selected]); return
    }

    if (key >= Qt.Key_1 && key <= Qt.Key_9) root.goToId(key - Qt.Key_0)
    else if (key === Qt.Key_0) root.goToId(10)
  }

  // ═══════════════════════════════════════════════════════════════
  FusedWindow {
    id: fw
    active: root.open || panel.shown
    targetScreen: root.targetScreen
    namespace: "oozeshell-overview"
    exclusiveKeys: true
    onCloseRequested: root.closeRequested()
    onKeyPressed: (key, modifiers, text) => root.handleKey(key, modifiers)

    FusedPanel {
      id: panel

      open: root.open
      panelWidth: root.contentWidth
      contentHeight: col.implicitHeight + root.pad * 2


      readonly property real fitWidth:
        (fw.screenWidth - (Theme.barVertical ? Theme.barFace + 24
                                             : 24 + Theme.flare * 2)) / root.contentWidth
      readonly property real fitHeight: Theme.barVertical
        ? (fw.screenHeight - 16 - Theme.flare * 2) / (col.implicitHeight + root.pad * 2)
        : Infinity
      uiScale: Math.min(Theme.windowScale,
                        Math.max(0.6, Math.min(fitWidth, fitHeight)))


      align: "center"

      ColumnLayout {
        id: col
        x: root.pad
        y: root.pad
        width: parent.width - root.pad * 2
        spacing: 12

        // ── Título + atajos ──────────────────────────────────


        ColumnLayout {
          id: header
          Layout.fillWidth: true
          spacing: 4

          RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
              text: "󰕮"
              color: Theme.primary
              font.pixelSize: Theme.fs(20)
              font.family: Theme.monoFamily
            }
            Text {
              Layout.fillWidth: root.vertical
              text: Translations.t("overviewTitle")
              color: Theme.text
              font.bold: true
              font.pixelSize: Theme.fs(14)
              font.family: Theme.fontFamily
              elide: Text.ElideRight
            }
            Item { Layout.fillWidth: true; visible: !root.vertical }
            Text {
              visible: !root.vertical
              text: root.keysHint
              color: Theme.subtext
              font.pixelSize: Theme.fs(10)
              font.family: Theme.fontFamily
            }
          }

          Text {
            visible: root.vertical
            Layout.fillWidth: true
            text: root.keysHint
            color: Theme.subtext
            font.pixelSize: Theme.fs(10)
            font.family: Theme.fontFamily
            elide: Text.ElideRight
          }
        }

        // ── Tarjetas ─────────────────────────────────────────


        GridLayout {
          Layout.alignment: Qt.AlignHCenter
          flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
          rows: root.vertical ? root.stackRows : -1
          columns: root.vertical ? -1 : root.columns
          columnSpacing: root.gap
          rowSpacing: root.gap

          Repeater {
            model: root.workspaceList

            delegate: Rectangle {
              id: card
              required property var modelData
              required property int index

              readonly property bool isSelected: root.selected === card.index
              readonly property bool isCurrent: card.modelData.active
              readonly property var wins: root.windowsOf(card.modelData.id)

              Layout.preferredWidth: root.cardW
              Layout.preferredHeight: root.cardH
              radius: 12
              color: card.isSelected ? Theme.surfaceHigh : Theme.surface
              border.width: 2
              border.color: card.isSelected ? Theme.primary : "transparent"
              Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
              Behavior on border.color { ColorAnimation { duration: Theme.animDuration(150) } }

              scale: cardArea.pressed ? 0.97 : 1.0
              Behavior on scale { NumberAnimation { duration: Theme.animDuration(140); easing.type: Easing.OutBack } }


              MouseArea {
                id: cardArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPositionChanged: root.selected = card.index
                onClicked: root.goTo(card.modelData)
              }

              ColumnLayout {
                x: root.cardPad
                y: root.cardPad
                width: parent.width - root.cardPad * 2
                spacing: 6

                // ── Número + estado ──
                RowLayout {
                  Layout.fillWidth: true
                  Layout.preferredHeight: root.headH
                  spacing: 8

                  Rectangle {
                    Layout.preferredWidth: root.headH
                    Layout.preferredHeight: root.headH
                    radius: 8
                    color: card.isCurrent ? Theme.primary : Theme.bg
                    Behavior on color { ColorAnimation { duration: Theme.animDuration(160) } }

                    Text {
                      anchors.centerIn: parent
                      text: card.modelData.id
                      color: card.isCurrent ? Theme.textOnPrimary : Theme.text
                      font.bold: true
                      font.pixelSize: Theme.fs(12)
                      font.family: Theme.fontFamily
                    }
                  }


                  Text {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    visible: text !== ""
                    text: String(card.modelData.name) !== String(card.modelData.id)
                          ? String(card.modelData.name) : ""
                    color: Theme.subtext
                    font.pixelSize: Theme.fs(11)
                    font.family: Theme.fontFamily
                    elide: Text.ElideRight
                  }
                  Item { Layout.fillWidth: true }


                  Text {
                    visible: text !== ""
                    text: card.modelData.urgent ? "♡" : (card.isCurrent ? "❄" : "")
                    color: card.modelData.urgent ? Theme.error : Theme.primary
                    font.pixelSize: Theme.fs(15)
                    font.family: Theme.fontFamily
                  }
                  Text {
                    visible: card.wins.length > 0
                    text: card.wins.length
                    color: Theme.subtext
                    font.pixelSize: Theme.fs(11)
                    font.family: Theme.fontFamily
                  }
                }

                // ── Miniatura del monitor ──
                Rectangle {
                  Layout.preferredWidth: root.miniW
                  Layout.preferredHeight: root.miniH
                  radius: 8
                  color: Theme.bg
                  border.width: Theme.bw1
                  border.color: Theme.edge

                  Text {
                    anchors.centerIn: parent
                    visible: card.wins.length === 0
                    text: Translations.t("overviewEmpty")
                    color: Theme.subtext
                    font.pixelSize: Theme.fs(11)
                    font.family: Theme.fontFamily
                  }


                  Item {
                    id: inner
                    anchors.fill: parent
                    anchors.margins: 3

                    Repeater {
                      model: card.wins

                      delegate: Rectangle {
                        id: win
                        required property var modelData

                        x: win.modelData.rx * inner.width
                        y: win.modelData.ry * inner.height
                        width: Math.max(6, win.modelData.rw * inner.width)
                        height: Math.max(6, win.modelData.rh * inner.height)
                        z: win.modelData.floating ? 2 : 1
                        radius: 4
                        color: Theme.surface
                        clip: true


                        readonly property var toplevel: root.open
                                                        ? root.toplevelFor(win.modelData.address) : null


                        IconImage {
                          anchors.centerIn: parent
                          width: Math.min(28, Math.min(win.width, win.height) * 0.6)
                          height: width
                          visible: width >= 10 && !shot.hasContent
                          asynchronous: true
                          source: root.iconFor(win.modelData.cls)
                        }


                        ScreencopyView {
                          id: shot
                          anchors.fill: parent
                          captureSource: win.toplevel
                          live: card.isCurrent
                          paintCursor: false
                          visible: hasContent
                          Component.onCompleted: if (!live && captureSource) captureFrame()
                          onCaptureSourceChanged: if (!live && captureSource) captureFrame()
                        }


                        Rectangle {
                          anchors.fill: parent
                          radius: 4
                          z: 3
                          color: winArea.containsMouse
                                 ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.14)
                                 : "transparent"
                          border.width: win.modelData.focused ? 2 : Theme.bw1
                          border.color: win.modelData.focused ? Theme.primary : Theme.edge
                          Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }
                        }


                        MouseArea {
                          id: winArea
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onPositionChanged: root.selected = card.index
                          onClicked: root.focusWindow(card.modelData, win.modelData.address)
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
