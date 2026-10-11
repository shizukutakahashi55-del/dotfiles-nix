// WidgetWindow — una superficie layer-shell por widget.

import Quickshell
import Quickshell.Wayland
import QtQuick
import "../COMMON"

PanelWindow {
  id: win

  required property string widgetId

  readonly property var cfg: WidgetConfig.byId[win.widgetId] ?? null
  readonly property var entry: win.cfg ? WidgetRegistry.get(win.cfg.type) : null
  readonly property bool nativeMissing: win.entry !== null && win.entry.needsNative && !Theme.nativeActive


  property bool dragging: false
  property real dragX: 0
  property real dragY: 0


  property bool resizing: false
  property real liveX: 0
  property real liveY: 0
  property real liveW: 0
  property real liveH: 0
  readonly property real minW: 60
  readonly property real minH: 40

  readonly property bool editing: WidgetConfig.editMode


  readonly property real fx: win.resizing ? win.liveX : (win.dragging ? win.dragX : (win.cfg ? win.cfg.x : 0))
  readonly property real fy: win.resizing ? win.liveY : (win.dragging ? win.dragY : (win.cfg ? win.cfg.y : 0))
  readonly property real fw: win.resizing ? win.liveW : (win.cfg ? win.cfg.w : 200)
  readonly property real fh: win.resizing ? win.liveH : (win.cfg ? win.cfg.h : 120)

  screen: Quickshell.screens.find(s => win.cfg && s.name === win.cfg.monitor) ?? Quickshell.screens[0]
  visible: win.cfg !== null
  color: "transparent"
  exclusiveZone: -1


  anchors { top: true; left: true; right: win.editing; bottom: win.editing }
  margins {
    left: (win.editing || !win.cfg) ? 0 : win.cfg.x
    top: (win.editing || !win.cfg) ? 0 : win.cfg.y
  }
  implicitWidth: win.cfg ? win.cfg.w : 200
  implicitHeight: win.cfg ? win.cfg.h : 120

  WlrLayershell.layer: WidgetConfig.layer === "background" ? WlrLayer.Background : WlrLayer.Bottom

  WlrLayershell.namespace: "oozeshell-widget-" + win.widgetId


  WlrLayershell.keyboardFocus: (!win.editing && loader.item && loader.item.wantsKeyboard === true)
    ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

  property Region noInput: Region {}
  property Region frameInput: Region { item: frame }


  readonly property Item widgetInput: (loader.item && loader.item.inputArea) ? loader.item.inputArea : null
  property Region widgetInputRegion: Region { item: win.widgetInput }
  mask: win.editing ? win.frameInput : (win.widgetInput ? win.widgetInputRegion : win.noInput)


  Item {
    id: frame
    x: win.editing ? win.fx : 0
    y: win.editing ? win.fy : 0
    width: win.editing ? win.fw : (win.cfg ? win.cfg.w : 200)
    height: win.editing ? win.fh : (win.cfg ? win.cfg.h : 120)

    Loader {
      id: loader
      anchors.fill: parent
      active: win.entry !== null && !win.nativeMissing
      source: win.entry ? win.entry.source : ""
    }
    Binding { target: loader.item; property: "cfg"; value: win.cfg; when: loader.item !== null }
    Binding { target: loader.item; property: "editMode"; value: win.editing; when: loader.item !== null }

    Binding { target: loader.item; property: "screenW"; value: win.screen ? win.screen.width : 1920; when: loader.item !== null }
    Binding { target: loader.item; property: "screenH"; value: win.screen ? win.screen.height : 1080; when: loader.item !== null }
    Binding { target: loader.item; property: "originX"; value: win.editing ? win.fx : (win.cfg ? win.cfg.x : 0); when: loader.item !== null }
    Binding { target: loader.item; property: "originY"; value: win.editing ? win.fy : (win.cfg ? win.cfg.y : 0); when: loader.item !== null }


    Text {
      anchors.centerIn: parent
      width: parent.width - 16
      visible: win.nativeMissing || loader.status === Loader.Error
      wrapMode: Text.WordWrap
      horizontalAlignment: Text.AlignHCenter
      color: Theme.subtext
      font.pixelSize: Theme.fs(10)
      font.family: Theme.fontFamily
      text: win.nativeMissing
        ? "⚠ " + win.widgetId + ": falta el módulo nativo\n(bash tools/build-native.sh)"
        : "⚠ " + win.widgetId + ": no se pudo cargar"
    }

    // ─── Modo edición: marco + arrastre libre ───────────────────
    Rectangle {
      anchors.fill: parent
      visible: win.editing
      color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, (win.dragging || win.resizing) ? 0.16 : 0.08)
      border.color: Theme.primary
      border.width: (win.dragging || win.resizing) ? 2 : 1
      radius: 8
      Text {
        anchors { left: parent.left; top: parent.top; margins: 6 }
        text: win.widgetId
              + (win.dragging ? "  " + Math.round(win.dragX) + ", " + Math.round(win.dragY) : "")
              + (win.resizing ? "  " + Math.round(win.liveW) + " × " + Math.round(win.liveH) : "")
        color: Theme.primary
        font.pixelSize: Theme.fs(9)
        font.family: Theme.fontFamily
      }
    }
    MouseArea {
      id: dragArea
      anchors.fill: parent
      enabled: win.editing
      cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

      property real grabX: 0
      property real grabY: 0
      function stagePos(m) { return dragArea.mapToItem(null, m.x, m.y) }
      onPressed: (m) => {
        const p = dragArea.stagePos(m)
        grabX = p.x - frame.x
        grabY = p.y - frame.y
        win.dragX = frame.x
        win.dragY = frame.y
        win.dragging = true
      }
      onPositionChanged: (m) => {
        if (!pressed) return
        const p = dragArea.stagePos(m)

        win.dragX = Math.round(Math.max(0, Math.min(win.width - frame.width, p.x - grabX)))
        win.dragY = Math.round(Math.max(0, Math.min(win.height - frame.height, p.y - grabY)))
      }
      onReleased: {
        if (win.cfg && win.dragging) WidgetConfig.update(win.widgetId, { x: win.dragX, y: win.dragY })
        win.dragging = false
      }
      onCanceled: win.dragging = false
    }

    // ─── Redimensionar: 8 manijas (esquinas + bordes) ───────────
    Repeater {
      model: win.editing ? [
        { ex: -1, ey: -1 }, { ex: 0, ey: -1 }, { ex: 1, ey: -1 },
        { ex: -1, ey: 0 },                      { ex: 1, ey: 0 },
        { ex: -1, ey: 1 },  { ex: 0, ey: 1 },  { ex: 1, ey: 1 }
      ] : []

      delegate: MouseArea {
        id: grip
        required property var modelData
        readonly property int ex: grip.modelData.ex
        readonly property int ey: grip.modelData.ey
        readonly property bool corner: grip.ex !== 0 && grip.ey !== 0
        readonly property real g: 16
        readonly property real e: 10

        width: grip.corner ? grip.g : (grip.ex === 0 ? Math.max(0, frame.width - 2 * grip.g) : grip.e)
        height: grip.corner ? grip.g : (grip.ey === 0 ? Math.max(0, frame.height - 2 * grip.g) : grip.e)
        x: grip.ex < 0 ? 0 : (grip.ex > 0 ? frame.width - grip.width : grip.g)
        y: grip.ey < 0 ? 0 : (grip.ey > 0 ? frame.height - grip.height : grip.g)
        hoverEnabled: true
        cursorShape: grip.corner ? (grip.ex * grip.ey === 1 ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor)
                                 : (grip.ex !== 0 ? Qt.SizeHorCursor : Qt.SizeVerCursor)


        property real x0: 0
        property real y0: 0
        property real w0: 1
        property real h0: 1
        property real px0: 0
        property real py0: 0

        Rectangle {
          anchors.centerIn: parent
          width: grip.corner ? 9 : (grip.ex === 0 ? Math.min(28, grip.width) : 4)
          height: grip.corner ? 9 : (grip.ey === 0 ? Math.min(28, grip.height) : 4)
          radius: 2
          color: Theme.primary
          opacity: (grip.pressed || grip.containsMouse) ? 1 : 0.65
        }

        onPressed: (m) => {
          const p = grip.mapToItem(null, m.x, m.y)
          grip.px0 = p.x; grip.py0 = p.y
          grip.x0 = frame.x; grip.y0 = frame.y
          grip.w0 = Math.max(1, frame.width); grip.h0 = Math.max(1, frame.height)
          win.liveX = grip.x0; win.liveY = grip.y0
          win.liveW = grip.w0; win.liveH = grip.h0
          win.resizing = true
        }
        onPositionChanged: (m) => {
          if (!pressed || !win.resizing) return
          const p = grip.mapToItem(null, m.x, m.y)
          const dx = p.x - grip.px0
          const dy = p.y - grip.py0

          let nw = grip.ex !== 0 ? grip.w0 + grip.ex * dx : grip.w0
          let nh = grip.ey !== 0 ? grip.h0 + grip.ey * dy : grip.h0
          nw = Math.max(win.minW, nw)
          nh = Math.max(win.minH, nh)

          if (grip.corner && (m.modifiers & Qt.ShiftModifier)) {
            const k = Math.max(nw / grip.w0, nh / grip.h0)
            nw = Math.max(win.minW, grip.w0 * k)
            nh = Math.max(win.minH, grip.h0 * k)
          }

          let nx = grip.ex < 0 ? grip.x0 + (grip.w0 - nw) : grip.x0
          let ny = grip.ey < 0 ? grip.y0 + (grip.h0 - nh) : grip.y0

          if (nx < 0) { nw += nx; nx = 0 }
          if (ny < 0) { nh += ny; ny = 0 }
          if (nx + nw > win.width) nw = win.width - nx
          if (ny + nh > win.height) nh = win.height - ny
          win.liveX = Math.round(nx); win.liveY = Math.round(ny)
          win.liveW = Math.round(Math.max(win.minW, nw)); win.liveH = Math.round(Math.max(win.minH, nh))
        }
        onReleased: {
          if (win.cfg && win.resizing)
            WidgetConfig.update(win.widgetId, { x: win.liveX, y: win.liveY, w: win.liveW, h: win.liveH })
          win.resizing = false
        }
        onCanceled: win.resizing = false
      }
    }
  }
}
