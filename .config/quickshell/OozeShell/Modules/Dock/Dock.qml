// Dock — panel FUSIONADO al borde de la pantalla con las apps "fijadas"

import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import "../../COMMON"
import "../../Services/Lang"

Variants {
  id: dockModule
  model: Quickshell.screens


  property bool popupOpen: false

  delegate: Component {
    PanelWindow {
      id: win
      required property var modelData
      screen: modelData

      visible: Theme.dockUsable && win.dockItems.length > 0

      readonly property bool atTop: Theme.dockEffectivePosition === "top"
      anchors { top: win.atTop; bottom: !win.atTop; left: true; right: true }

      readonly property real pillHeight: Math.round(58 * Theme.dockScale * Theme.dockHeightFactor)
      readonly property real handleHeight: Math.round(6 * Theme.dockScale)
      readonly property real tipAllowance: Math.round(260 * Theme.dockScale)


      readonly property real menuAllowance: Math.round(170 * Theme.barScale)


      readonly property real restGap: Theme.dockFloating ? Theme.dockFloatGap : 0


      implicitHeight: win.pillHeight + Theme.dockFloatGap + Math.round(10 * Theme.dockScale)
                      + Math.max(win.tipAllowance, win.menuAllowance)
      color: "transparent"

      // ─── Zona reservada (el dock no encima las apps) ──────────────

      readonly property int clearance: 5
      readonly property int reserveZone: Theme.dockAutoHide
        ? 0
        : Math.max(0, Math.round(win.handleHeight) + win.clearance - AppState.gapsOut)

      exclusiveZone: Theme.dockAutoHide
        ? -1
        : Math.round(win.pillHeight + win.restGap) + win.reserveZone

      WlrLayershell.namespace: "quickshell-dock"


      property var glassPanels: []
      GlassRegion { id: blurReg; panels: win.glassPanels }
      WlrLayershell.layer: WlrLayer.Top


      mask: Region {
        item: dockPanel
        regions: [ Region { item: edgeStrip }, Region { item: outsideCatcher } ]
      }


      WlrLayershell.keyboardFocus: win.menuOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

      // ─── Auto-ocultar (Ajustes → Interfaz → Dock → Auto-ocultar) ─────

      property bool revealed: !Theme.dockAutoHide

      Connections {
        target: Theme
        function onDockAutoHideChanged() {
          win.revealed = !Theme.dockAutoHide || win.dockHovered
        }
      }

      Timer { id: hideTimer; interval: 700; repeat: false
        onTriggered: { if (!win.menuShown && !win.dockHovered) win.revealed = false }
      }


      Timer {
        interval: 1500; repeat: true
        running: Theme.dockAutoHide && win.revealed && !win.menuShown && !win.dockHovered
        onTriggered: win.revealed = false
      }


      function hoverReveal() {
        if (!Theme.dockAutoHide) return
        if (win.dockHovered) { hideTimer.stop(); win.revealed = true }
        else if (!win.menuShown) hideTimer.restart()
      }
      onDockHoveredChanged: {
        win.hoverReveal()

        if (win.menuOpen) {
          if (win.dockHovered) menuLeaveTimer.stop()
          else menuLeaveTimer.restart()
        }
      }


      function onThisScreen(t) {
        const scr = t.screens
        if (!scr || scr.length === undefined || scr.length === 0) return true
        for (let i = 0; i < scr.length; i++)
          if (scr[i] && win.modelData && scr[i].name === win.modelData.name) return true
        return false
      }


      readonly property int desktopRevision: DesktopEntries.applications.values.length

      function iconFor(appId) {
        void win.desktopRevision
        const id = appId || ""
        const names = []
        if (id !== "") {
          const entry = DesktopEntries.heuristicLookup(id)
          if (entry && entry.icon) names.push(entry.icon)
          names.push(id, id.toLowerCase())
          const last = id.split(".").pop().toLowerCase()
          if (last !== id.toLowerCase()) names.push(last)
        }
        for (let i = 0; i < names.length; i++) {
          const n = names[i]
          if (!n) continue
          if (n.charAt(0) === "/") return "file://" + n
          const p = Quickshell.iconPath(n, true)
          if (p !== "") return p
        }
        return Quickshell.iconPath("application-x-executable", true)
      }


      readonly property var runningByApp: {
        const map = {}
        const order = []
        const list = ToplevelManager.toplevels.values
        for (let i = 0; i < list.length; i++) {
          const t = list[i]
          if (!win.onThisScreen(t)) continue
          const id = t.appId || "?"
          if (!map[id]) { map[id] = []; order.push(id) }
          map[id].push(t)
        }
        return { map: map, order: order }
      }


      readonly property var dockItems: {
        const out = []
        const seen = {}
        const pins = DockBackend.pinnedApps
        for (let i = 0; i < pins.length; i++) {
          const id = pins[i]
          if (seen[id]) continue
          seen[id] = true
          out.push({ appId: id, toplevels: win.runningByApp.map[id] || [] })
        }
        for (let i = 0; i < win.runningByApp.order.length; i++) {
          const id = win.runningByApp.order[i]
          if (seen[id]) continue
          seen[id] = true
          out.push({ appId: id, toplevels: win.runningByApp.map[id] })
        }
        return out
      }


      readonly property bool dbg: Quickshell.env("OOZE_DOCK_DEBUG") === "1"

      property var dockIds: []
      function syncDockIds() {
        const next = win.dockItems.map(i => i.appId)
        if (next.join("\n") !== win.dockIds.join("\n")) win.dockIds = next
      }
      onDockItemsChanged: win.syncDockIds()
      Component.onCompleted: {
        if (WM.hasBackgroundBlur) BackgroundEffect.blurRegion = blurReg
        win.syncDockIds()
      }

      // ─── Menú contextual (clic derecho) ───────────────────────────


      property bool menuShown: false
      property string menuAppId: ""
      property var menuTarget: null
      property real menuCenterX: 0

      readonly property bool menuOpen: win.menuShown && win.menuAppId !== ""
        && win.dockIds.indexOf(win.menuAppId) >= 0 && !dockModule.popupOpen

      readonly property bool menuPinned: DockBackend.isPinned(win.menuAppId)
      readonly property bool menuRunning: (win.runningByApp.map[win.menuAppId] || []).length > 0


      readonly property var menuEntry: {
        void win.desktopRevision
        return win.menuAppId !== "" ? DesktopEntries.heuristicLookup(win.menuAppId) : null
      }

      readonly property var menuActions: {
        const out = []
        if (win.menuEntry)
          out.push({ key: "new", icon: "󰐕", label: Translations.t("dockNewWindow"), danger: false })
        out.push({
          key: "pin",
          icon: win.menuPinned ? "󰤱" : "󰐃",
          label: win.menuPinned ? Translations.t("dockUnpin") : Translations.t("dockPin"),
          danger: false
        })
        if (win.menuRunning)
          out.push({ key: "close", icon: "󰅖", label: Translations.t("dockCloseWindows"), danger: true })
        return out
      }

      function nameFor(appId) {
        void win.desktopRevision
        const entry = appId ? DesktopEntries.heuristicLookup(appId) : null
        return (entry && entry.name) ? entry.name : (appId || "")
      }

      function openMenu(cell) {

        tipShowTimer.stop()
        win.tipShown = false
        menuLeaveTimer.stop()
        win.revealed = true
        win.menuAppId = cell.appId
        win.menuTarget = cell
        win.menuCenterX = cell.mapToItem(null, cell.width / 2, cell.height / 2).x
        win.menuShown = true
      }

      function closeMenu() {
        menuLeaveTimer.stop()
        win.menuShown = false
      }

      function menuRefresh() {
        if (!win.menuTarget) return
        win.menuCenterX = win.menuTarget.mapToItem(null, win.menuTarget.width / 2, win.menuTarget.height / 2).x
      }

      function menuCellGone(cell) {
        if (win.menuTarget !== cell) return
        win.menuTarget = null
        win.menuShown = false
      }

      function newWindow(appId) {
        const entry = DesktopEntries.heuristicLookup(appId)
        if (!entry) return
        const acts = entry.actions || []
        for (let i = 0; i < acts.length; i++) {
          if (/^new[-_ ]?window$/i.test(acts[i].id || "")) { acts[i].execute(); return }
        }
        entry.execute()
      }

      function runMenuAction(key) {
        const id = win.menuAppId
        if (key === "new") win.newWindow(id)
        else if (key === "pin") DockBackend.togglePin(id)
        else if (key === "close") win.closeItem({ toplevels: win.runningByApp.map[id] || [] })
        win.closeMenu()
      }


      onMenuShownChanged: {
        if (!win.menuShown) win.hoverReveal()
      }
      onMenuOpenChanged: {
        if (win.menuOpen) keyCatcher.forceActiveFocus()
        else menuLeaveTimer.stop()
      }


      Timer { id: menuLeaveTimer; interval: 600; repeat: false; onTriggered: win.closeMenu() }

      Timer {
        interval: 1500; repeat: true
        running: win.menuOpen && !win.dockHovered
        onTriggered: win.closeMenu()
      }

      function activateItem(item) {
        const tops = item.toplevels
        if (tops && tops.length > 0) {
          if (tops.length === 1) {
            const t = tops[0]
            if (t.activated && !t.minimized) t.minimized = true
            else { t.minimized = false; t.activate() }
          } else {
            const idx = tops.findIndex(t => t.activated)
            const next = tops[(idx + 1 + tops.length) % tops.length]
            next.minimized = false
            next.activate()
          }
        } else {
          const entry = DesktopEntries.heuristicLookup(item.appId)
          if (entry) entry.execute()
        }
      }

      function closeItem(item) {
        const tops = item.toplevels || []
        for (let i = 0; i < tops.length; i++) tops[i].close()
      }


      Item {
        id: outsideCatcher
        x: 0
        y: 0
        width: win.menuOpen ? win.width : 0
        height: win.menuOpen ? win.height : 0

        MouseArea {
          anchors.fill: parent
          acceptedButtons: Qt.AllButtons
          onClicked: win.closeMenu()
        }
      }

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
          if (event.key === Qt.Key_Escape && win.menuOpen) {
            win.closeMenu()
            event.accepted = true
          }
        }
      }


      readonly property bool dockHovered:
        dockPanel.hovered || stripHover.hovered || (win.menuOpen && menu.hovered)


      Item {
        id: edgeStrip
        readonly property real stripW: Math.max(dockPanel.scaledWidth, Math.round(160 * Theme.dockScale))
        width: Theme.dockAutoHide ? stripW : 0
        height: Theme.dockAutoHide ? win.handleHeight : 0
        x: Math.round((win.width - width) / 2)
        y: win.atTop ? 0 : win.height - height

        HoverHandler { id: stripHover }


        Rectangle {
          visible: Theme.dockAutoHide && !win.revealed
          anchors.horizontalCenter: parent.horizontalCenter
          y: win.atTop ? 2 : parent.height - height - 2
          width: Math.round(44 * Theme.dockScale)
          height: 3
          radius: height / 2
          color: Theme.subtext
          opacity: 0.45
        }
      }


      readonly property var bodyRect: ({
        x: dockPanel.x + dockPanel.startInset,
        y: dockPanel.y,
        w: dockPanel.scaledWidth,
        h: dockPanel.height
      })

      FusedPanel {
        id: dockPanel


        edge: win.atTop ? "top" : "bottom"


        faceOffset: win.restGap


        Behavior on faceOffset {
          NumberAnimation { duration: Theme.animDuration(180); easing.type: Easing.OutCubic }
        }
        detached: Theme.dockFloating


        color: Theme.dockBg
        glassBlur: Theme.dockBlur
        blurSeam: 0
        screenName: win.modelData ? win.modelData.name : ""
        align: "center"

        uiScale: 1.0
        fitScreen: false
        islandAware: false


        open: win.revealed

        panelWidth: row.implicitWidth + (Theme.cozy ? 12 : 24)
        contentHeight: win.pillHeight

        RowLayout {
          id: row
          anchors.centerIn: parent
          spacing: Theme.cozy ? 4 : 6

          Repeater {


            model: ScriptModel { values: win.dockIds }

            delegate: Item {
              id: cell
              required property string modelData
              readonly property string appId: modelData

              readonly property var toplevels: win.runningByApp.map[cell.appId] || []
              readonly property bool running: cell.toplevels.length > 0
              readonly property bool active: running && cell.toplevels.some(t => t.activated)
              readonly property string iconSrc: win.iconFor(cell.appId)


              property bool hot: false
              Timer { id: hotOff; interval: 90; repeat: false; onTriggered: cell.hot = false }


              readonly property color idleColor: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0)

              onHotChanged: if (win.dbg) console.log("dock", cell.appId, "hot", cell.hot)
              onActiveChanged: if (win.dbg) console.log("dock", cell.appId, "active", cell.active)
              Component.onCompleted: if (win.dbg) console.log("dock cell created", cell.appId)


              readonly property int maxTipLines: 10
              readonly property string tip: {
                const tops = cell.toplevels
                if (tops.length > 0) {
                  const n = Math.min(tops.length, cell.maxTipLines)
                  let s = ""
                  for (let i = 0; i < n; i++)
                    s += (i > 0 ? "\n" : "") + (tops[i].title || cell.appId)
                  if (tops.length > n) s += "\n… +" + (tops.length - n)
                  return s
                }
                return cell.appId
              }


              Component.onDestruction: { if (win.dbg) console.log("dock cell destroyed", cell.appId); win.tipCellGone(cell); win.menuCellGone(cell) }

              Layout.preferredWidth: 46 * Theme.dockScale
              Layout.preferredHeight: 46 * Theme.dockScale


              SkinRect {
                anchors.fill: parent
                readonly property color accent: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b,
                                                        cell.hot ? 0.26 : 0.16)
                color: Theme.cozy
                  ? (cell.hot ? Theme.surfaceHigh : (cell.active ? Theme.surface : cell.idleColor))
                  : (cell.active ? accent : (cell.hot ? Theme.surfaceHigh : cell.idleColor))
                radius: Theme.cozy ? 0 : Math.max(8, Math.round(13 * Theme.dockScale))
                raised: Theme.cozy && (cell.active || cell.hot)
                depth: Theme.cozy ? 2 : 0
                notch: Theme.cozy ? 3 : 0
                inkColor: cell.active ? Theme.primary : Theme.ink
                border.width: 0
                Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }
              }


              scale: cell.hot ? (Theme.cozy ? 1.05 : 1.08) : 1.0
              Behavior on scale {
                NumberAnimation {
                  duration: Theme.animDuration(Theme.cozy ? 100 : 170)
                  easing.type: Theme.cozy ? Easing.OutCubic : Easing.OutBack
                }
              }

              IconImage {
                anchors.centerIn: parent

                anchors.verticalCenterOffset: (!Theme.cozy && cell.hot) ? -Math.round(2 * Theme.dockScale) : 0
                Behavior on anchors.verticalCenterOffset {
                  NumberAnimation { duration: Theme.animDuration(150); easing.type: Easing.OutCubic }
                }
                width: 26 * Theme.dockScale
                height: width
                visible: cell.iconSrc !== ""
                source: cell.iconSrc
              }

              Text {
                anchors.centerIn: parent
                visible: cell.iconSrc === ""
                text: "󰀻"
                color: Theme.subtext
                font.pixelSize: Theme.fs(20)
                font.family: Theme.monoFamily
              }


              Rectangle {
                visible: cell.running
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.cozy ? 2 : Math.max(2, Math.round(3 * Theme.dockScale))
                width: Theme.cozy ? (cell.active ? 9 : 6)
                                  : Math.round((cell.active ? 14 : 4) * Theme.dockScale)
                height: Theme.cozy ? 3 : (cell.active ? 3 : 4)
                radius: Theme.cozy ? 0 : height / 2
                color: cell.active ? Theme.primary : Theme.subtext
                opacity: (Theme.cozy || cell.active) ? 1.0 : 0.7
                Behavior on width {
                  enabled: !Theme.cozy
                  NumberAnimation { duration: Theme.animDuration(160); easing.type: Easing.OutCubic }
                }
              }

              MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                onContainsMouseChanged: {
                  if (area.containsMouse) { hotOff.stop(); cell.hot = true }
                  else hotOff.restart()
                }

                onEntered: win.tipEnter(cell)
                onExited: win.tipLeave(cell)


                onPressed: mouse => {
                  if (mouse.button === Qt.RightButton) {
                    if (win.menuOpen && win.menuAppId === cell.appId) win.closeMenu()
                    else win.openMenu(cell)
                    mouse.accepted = false
                  }
                }

                onClicked: mouse => {
                  if (mouse.button === Qt.MiddleButton) {
                    win.closeMenu()
                    win.closeItem(cell)
                  } else {
                    win.closeMenu()
                    win.activateItem(cell)
                  }
                }
              }
            }
          }
        }
      }

      // ─── Tooltip compartido (FusedTip) ───────────────────────────

      property var tipTarget: null
      property real tipCenterX: 0
      property bool tipShown: false
      property string tipText: ""

      readonly property string liveTip: tipTarget ? String(tipTarget.tip ?? "") : ""
      onLiveTipChanged: { if (liveTip !== "") win.tipText = liveTip }

      readonly property bool tipAllowed: !dockModule.popupOpen && !win.menuOpen
      readonly property bool tipOpen:
        win.revealed && win.tipAllowed && win.tipShown
        && win.tipTarget !== null && win.tipTarget.visible && win.tipText !== ""

      function tipEnter(item) {
        tipHideTimer.stop()
        win.tipTarget = item
        win.tipText = win.liveTip
        const c = item.mapToItem(null, item.width / 2, item.height / 2)
        win.tipCenterX = c.x
        if (!win.tipShown) tipShowTimer.restart()
      }


      function tipRefresh() {
        if (!win.tipTarget) return
        win.tipCenterX = win.tipTarget.mapToItem(null, win.tipTarget.width / 2, win.tipTarget.height / 2).x
      }

      Connections {
        target: dockPanel
        function onWidthChanged() { Qt.callLater(win.tipRefresh); Qt.callLater(win.menuRefresh) }
      }

      function tipLeave(item) {
        if (win.tipTarget !== item) return
        tipShowTimer.stop()
        tipHideTimer.restart()
      }

      function tipCellGone(item) {
        if (win.tipTarget !== item) return
        win.tipTarget = null
        win.tipShown = false
        tipShowTimer.stop()
      }

      Timer { id: tipShowTimer; interval: 500; repeat: false; onTriggered: win.tipShown = true }
      Timer { id: tipHideTimer; interval: 150; repeat: false; onTriggered: win.tipShown = false }

      FusedTip {
        id: tip
        open: win.tipOpen
        text: win.tipText
        edge: win.atTop ? "top" : "bottom"

        maxDepth: win.height - win.pillHeight - 8

        island: "center"
        islandStyle: "hang"
        islandRadius: Theme.panelRadius
        islandRectLocal: win.bodyRect
        forceFloat: Theme.dockFloating
        align: "center"
        alignCenter: win.tipCenterX

        x: tip.islandActive
           ? tip.placedAlong
           : Math.max(0, Math.min(win.width - width, win.tipCenterX - width / 2))


        readonly property real seam: tip.floating ? 0 : 1
        y: win.atTop
           ? (dockPanel.y + dockPanel.height - tip.seam + (tip.floating ? 6 : 0))
           : (dockPanel.y - tip.height + tip.seam - (tip.floating ? 6 : 0))

        Behavior on x {
          enabled: tip.shown
          NumberAnimation { duration: Theme.animDuration(160); easing.type: Easing.OutCubic }
        }
      }

      // ─── Menú contextual (FusedPanel) ────────────────────────────


      FusedPanel {
        id: menu
        open: win.menuOpen

        edge: win.atTop ? "top" : "bottom"

        island: "center"
        islandStyle: "hang"
        islandRadius: Theme.panelRadius
        islandRectLocal: win.bodyRect
        align: "center"
        alignCenter: win.menuCenterX

        readonly property bool tooWideForHang: menu.islandRectLocal !== null
          && menu.scaledWidth + 2 * (menu.islandRadius + menu.flare) > menu.islandRectLocal.w
        readonly property bool floating: menu.tooWideForHang || Theme.dockFloating
        detached: menu.floating

        flare: Theme.tipFlare
        bodyRadius: Theme.panelRadius
        duration: Theme.animDuration(Theme.tipMs)


        uiScale: Theme.barScale
        fitScreen: false

        readonly property int pad: 8
        readonly property int rowH: 34

        panelWidth: 204
        contentHeight: col.implicitHeight + menu.pad * 2

        readonly property real seam: menu.floating ? 0 : 1
        x: menu.islandActive
           ? menu.placedAlong
           : Math.max(0, Math.min(win.width - width, win.menuCenterX - width / 2))
        y: win.atTop
           ? (dockPanel.y + dockPanel.height - menu.seam + (menu.floating ? 6 : 0))
           : (dockPanel.y - menu.height + menu.seam - (menu.floating ? 6 : 0))


        Behavior on x {
          enabled: menu.shown
          NumberAnimation { duration: Theme.animDuration(160); easing.type: Easing.OutCubic }
        }

        ColumnLayout {
          id: col
          x: 0
          y: menu.pad
          width: parent.width
          spacing: 2


          RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: menu.pad + 4
            Layout.rightMargin: menu.pad + 4
            Layout.preferredHeight: 38
            spacing: 10

            IconImage {
              Layout.preferredWidth: 24
              Layout.preferredHeight: 24
              source: win.iconFor(win.menuAppId)
            }

            Text {
              Layout.fillWidth: true
              text: win.nameFor(win.menuAppId)
              color: Theme.text
              font.pixelSize: Theme.fs(13)
              font.bold: true
              font.family: Theme.fontFamily
              elide: Text.ElideRight
            }
          }

          Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: menu.pad + 4
            Layout.rightMargin: menu.pad + 4
            Layout.topMargin: 2
            Layout.bottomMargin: 4
            height: 1
            color: Theme.divider
          }

          Repeater {
            model: win.menuActions

            delegate: Item {
              id: menuRow
              required property var modelData
              Layout.fillWidth: true
              Layout.leftMargin: menu.pad
              Layout.rightMargin: menu.pad
              Layout.preferredHeight: menu.rowH

              SkinRect {
                anchors.fill: parent
                color: rowArea.containsMouse
                  ? Theme.surfaceHigh
                  : Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0)
                radius: Theme.cozy ? 0 : 10
                raised: Theme.cozy && rowArea.containsMouse
                depth: Theme.cozy ? 2 : 0
                notch: Theme.cozy ? 3 : 0
                inkColor: Theme.ink
                border.width: 0
                Behavior on color { ColorAnimation { duration: Theme.animDuration(100) } }
              }

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 10

                Text {
                  Layout.preferredWidth: 18
                  horizontalAlignment: Text.AlignHCenter
                  text: menuRow.modelData.icon
                  color: menuRow.modelData.danger ? Theme.error : Theme.primary
                  font.pixelSize: Theme.fs(15)
                  font.family: Theme.monoFamily
                }

                Text {
                  Layout.fillWidth: true
                  text: menuRow.modelData.label
                  color: menuRow.modelData.danger ? Theme.error : Theme.text
                  font.pixelSize: Theme.fs(12)
                  font.family: Theme.fontFamily
                  elide: Text.ElideRight
                }
              }

              MouseArea {
                id: rowArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: win.runMenuAction(menuRow.modelData.key)
              }
            }
          }
        }
      }
    }
  }
}
