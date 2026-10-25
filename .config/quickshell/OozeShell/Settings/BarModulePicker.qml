// BarModulePicker

import QtQuick
import QtQuick.Layouts
import "../COMMON"
import "../Services/Lang"

Item {
  id: picker

  Layout.fillWidth: true
  Layout.preferredHeight: col.implicitHeight
  implicitHeight: col.implicitHeight

  property string dragId: ""
  property string hoverSide: ""
  property int hoverIndex: -1
  property point ghostPos: Qt.point(0, 0)
  property real markX: 0
  property real markY: 0
  property real markH: 30

  readonly property bool dragging: picker.dragId !== ""
  readonly property var freeList: picker.freeModules()

  function sideTitle(side) {
    const k = Theme.barVertical
      ? { left: "barModTop", center: "barModMiddle", right: "barModBottom" }
      : { left: "barModLeft", center: "barModCenter", right: "barModRight" }
    return Translations.t(k[side])
  }

  function sideShort(side) {
    const k = Theme.barVertical
      ? { left: "barModTopShort", center: "barModMiddleShort", right: "barModBottomShort" }
      : { left: "barModLeftShort", center: "barModCenterShort", right: "barModRightShort" }
    return Translations.t(k[side])
  }

  function freeModules() {
    const out = []
    for (let i = 0; i < Theme.barModuleIds.length; i++)
      if (Theme.barSideOf(Theme.barModuleIds[i]) === "") out.push(Theme.barModuleIds[i])
    return out
  }

  function toLocal(sx, sy) {
    return picker.mapFromItem(null, sx, sy)
  }

  function sideAt(pt) {
    for (let i = 0; i < laneRepeater.count; i++) {
      const lane = laneRepeater.itemAt(i)
      if (!lane) continue
      const p = picker.mapToItem(lane, pt.x, pt.y)
      if (p.x >= 0 && p.x <= lane.width && p.y >= -col.spacing / 2 && p.y <= lane.height + col.spacing / 2)
        return lane.sideId
    }
    const f = picker.mapToItem(freeZone, pt.x, pt.y)
    if (f.x >= 0 && f.x <= freeZone.width && f.y >= -col.spacing / 2 && f.y <= freeZone.height + col.spacing / 2)
      return "free"
    return ""
  }

  function laneOf(side) {
    for (let i = 0; i < laneRepeater.count; i++) {
      const lane = laneRepeater.itemAt(i)
      if (lane && lane.sideId === side) return lane
    }
    return null
  }

  function locate(lane, pt) {
    const flow = lane.flow
    const p = picker.mapToItem(flow, pt.x, pt.y)
    const kids = []
    for (let i = 0; i < flow.children.length; i++) {
      const c = flow.children[i]
      if (c.modId !== undefined && c.modId !== picker.dragId) kids.push(c)
    }
    let idx = kids.length
    for (let i = 0; i < kids.length; i++) {
      const c = kids[i]
      const above = p.y < c.y
      const sameRow = p.y >= c.y && p.y <= c.y + c.height
      if (above || (sameRow && p.x < c.x + c.width / 2)) { idx = i; break }
    }
    picker.hoverIndex = idx
    if (kids.length === 0) {
      picker.markX = 0
      picker.markY = 0
      picker.markH = 30
    } else if (idx < kids.length) {
      picker.markX = kids[idx].x - flow.spacing / 2
      picker.markY = kids[idx].y
      picker.markH = kids[idx].height
    } else {
      const last = kids[kids.length - 1]
      picker.markX = last.x + last.width + flow.spacing / 2
      picker.markY = last.y
      picker.markH = last.height
    }
  }

  function updateDrag(sx, sy) {
    const pt = picker.toLocal(sx, sy)
    picker.ghostPos = pt
    const side = picker.sideAt(pt)
    picker.hoverSide = side
    const lane = picker.laneOf(side)
    if (lane) picker.locate(lane, pt)
    else picker.hoverIndex = -1
  }

  function beginDrag(id, sx, sy) {
    picker.dragId = id
    picker.updateDrag(sx, sy)
  }

  function cancelDrag() {
    picker.dragId = ""
    picker.hoverSide = ""
    picker.hoverIndex = -1
  }

  function endDrag(sx, sy) {
    picker.updateDrag(sx, sy)
    const id = picker.dragId
    const side = picker.hoverSide
    const idx = picker.hoverIndex
    picker.cancelDrag()
    if (id === "" || side === "") return
    Qt.callLater(function() {
      if (side === "free") Theme.placeBarModule(id, "", -1)
      else Theme.placeBarModule(id, side, idx)
    })
  }

  component Chip: Rectangle {
    id: chip

    property string modId: ""
    property bool being: false

    signal dragBegan(real sx, real sy)
    signal dragMoved(real sx, real sy)
    signal dragEnded(real sx, real sy)
    signal dragCanceled()
    signal removeRequested()

    width: chipRow.implicitWidth + 20
    height: 30
    radius: Theme.cozy ? 4 : 9
    color: chipArea.containsMouse ? Theme.mix(Theme.surfaceHigh, Theme.primary, 0.18) : Theme.surfaceHigh
    border.width: Theme.bw1
    border.color: chipArea.containsMouse
      ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.5)
      : Theme.edge
    opacity: chip.being ? 0.3 : 1.0
    Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }

    RowLayout {
      id: chipRow
      anchors.verticalCenter: parent.verticalCenter
      anchors.left: parent.left
      anchors.leftMargin: 10
      spacing: 8

      Text {
        text: "⠿"
        color: Theme.subtext
        font.pixelSize: Theme.sfs(12)
        font.family: Theme.monoFamily
      }
      Text {
        text: Translations.t("barMod_" + chip.modId)
        color: Theme.text
        font.pixelSize: Theme.sfs(11)
        font.bold: true
        font.family: Theme.fontFamily
      }
      Item { Layout.preferredWidth: 12 }
    }

    MouseArea {
      id: chipArea
      anchors.fill: parent
      hoverEnabled: true
      preventStealing: true
      cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

      property point pressPt: Qt.point(0, 0)
      property bool moved: false

      onPressed: m => {
        chipArea.pressPt = Qt.point(m.x, m.y)
        chipArea.moved = false
      }
      onPositionChanged: m => {
        if (!chipArea.pressed) return
        if (!chipArea.moved && Math.abs(m.x - chipArea.pressPt.x) + Math.abs(m.y - chipArea.pressPt.y) < 6) return
        const s = chip.mapToItem(null, m.x, m.y)
        if (!chipArea.moved) {
          chipArea.moved = true
          chip.dragBegan(s.x, s.y)
        } else {
          chip.dragMoved(s.x, s.y)
        }
      }
      onReleased: m => {
        if (!chipArea.moved) return
        chipArea.moved = false
        const s = chip.mapToItem(null, m.x, m.y)
        chip.dragEnded(s.x, s.y)
      }
      onCanceled: {
        if (!chipArea.moved) return
        chipArea.moved = false
        chip.dragCanceled()
      }
    }

    MouseArea {
      id: closeArea
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      width: 24
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: chip.removeRequested()

      Text {
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: -2
        text: "✕"
        color: closeArea.containsMouse ? Theme.error : Theme.subtext
        font.pixelSize: Theme.sfs(10)
        font.family: Theme.monoFamily
      }
    }
  }

  ColumnLayout {
    id: col
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    spacing: 10

    Repeater {
      id: laneRepeater
      model: Theme.barSides

      delegate: Rectangle {
        id: lane

        readonly property string sideId: modelData
        readonly property var items: Theme.barModulesOf(lane.sideId)
        readonly property bool target: picker.dragging && picker.hoverSide === lane.sideId
        property alias flow: laneFlow

        Layout.fillWidth: true
        implicitHeight: laneCol.implicitHeight + 20
        radius: Theme.cozy ? 4 : 12
        color: lane.target
          ? Theme.mix(Theme.surface, Theme.primary, 0.12)
          : Theme.mix(Theme.surface, Theme.bg, 0.5)
        border.width: Theme.bw1
        border.color: lane.target ? Theme.primary : Theme.edge
        Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }
        Behavior on border.color { ColorAnimation { duration: Theme.animDuration(120) } }

        ColumnLayout {
          id: laneCol
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.margins: 10
          spacing: 8

          Text {
            Layout.fillWidth: true
            text: picker.sideTitle(lane.sideId)
            color: Theme.text
            font.pixelSize: Theme.sfs(12)
            font.bold: true
            font.family: Theme.fontFamily
          }

          Text {
            visible: lane.items.length === 0 || (lane.items.length === 1 && lane.items[0] === picker.dragId)
            Layout.fillWidth: true
            text: Translations.t("barModulesEmpty")
            wrapMode: Text.WordWrap
            color: Theme.subtext
            font.pixelSize: Theme.sfs(10)
            font.family: Theme.fontFamily
          }

          Flow {
            id: laneFlow
            Layout.fillWidth: true
            spacing: 8

            Repeater {
              model: lane.items

              delegate: Chip {
                modId: modelData
                being: picker.dragId === modelData
                onDragBegan: (sx, sy) => picker.beginDrag(modelData, sx, sy)
                onDragMoved: (sx, sy) => picker.updateDrag(sx, sy)
                onDragEnded: (sx, sy) => picker.endDrag(sx, sy)
                onDragCanceled: picker.cancelDrag()
                onRemoveRequested: Theme.placeBarModule(modelData, "", -1)
              }
            }
          }
        }

        Rectangle {
          visible: lane.target && picker.hoverIndex >= 0
          z: 5
          width: 3
          radius: 1.5
          color: Theme.primary
          x: laneCol.x + laneFlow.x + picker.markX - 1.5
          y: laneCol.y + laneFlow.y + picker.markY
          height: picker.markH
        }
      }
    }

    Rectangle {
      id: freeZone

      readonly property bool target: picker.dragging && picker.hoverSide === "free"

      Layout.fillWidth: true
      implicitHeight: freeCol.implicitHeight + 20
      radius: Theme.cozy ? 4 : 12
      color: freeZone.target
        ? Theme.mix(Theme.surface, Theme.error, 0.10)
        : Theme.mix(Theme.surface, Theme.bg, 0.5)
      border.width: Theme.bw1
      border.color: freeZone.target ? Theme.error : Theme.edge
      Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }
      Behavior on border.color { ColorAnimation { duration: Theme.animDuration(120) } }

      ColumnLayout {
        id: freeCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 10
        spacing: 8

        Text {
          Layout.fillWidth: true
          text: Translations.t("barModulesFree")
          color: Theme.text
          font.pixelSize: Theme.sfs(12)
          font.bold: true
          font.family: Theme.fontFamily
        }

        Text {
          visible: picker.freeList.length === 0
          Layout.fillWidth: true
          text: Translations.t("barModulesFreeEmpty")
          wrapMode: Text.WordWrap
          color: Theme.subtext
          font.pixelSize: Theme.sfs(10)
          font.family: Theme.fontFamily
        }

        Repeater {
          model: picker.freeList

          delegate: RowLayout {
            id: freeRow

            readonly property string modId: modelData

            Layout.fillWidth: true
            spacing: 6

            Text {
              Layout.fillWidth: true
              elide: Text.ElideRight
              text: Translations.t("barMod_" + freeRow.modId)
              color: Theme.subtext
              font.pixelSize: Theme.sfs(12)
              font.family: Theme.fontFamily
            }

            Repeater {
              model: Theme.barSides

              delegate: SettingsBtn {
                icon: "+"
                text: picker.sideShort(modelData)
                onClicked: Theme.placeBarModule(freeRow.modId, modelData, -1)
              }
            }
          }
        }
      }
    }
  }

  Rectangle {
    id: ghost
    visible: picker.dragging
    z: 100
    width: ghostRow.implicitWidth + 24
    height: 30
    radius: Theme.cozy ? 4 : 9
    color: Theme.primary
    opacity: 0.92
    x: picker.ghostPos.x - ghost.width / 2
    y: picker.ghostPos.y - ghost.height / 2

    RowLayout {
      id: ghostRow
      anchors.centerIn: parent
      spacing: 8
      Text {
        text: "⠿"
        color: Theme.textOnPrimary
        font.pixelSize: Theme.sfs(12)
        font.family: Theme.monoFamily
      }
      Text {
        text: picker.dragging ? Translations.t("barMod_" + picker.dragId) : ""
        color: Theme.textOnPrimary
        font.pixelSize: Theme.sfs(11)
        font.bold: true
        font.family: Theme.fontFamily
      }
    }
  }
}
