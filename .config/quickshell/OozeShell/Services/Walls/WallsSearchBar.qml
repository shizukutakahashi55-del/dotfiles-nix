// WallsSearchBar — WALLS

import QtQuick
import QtQuick.Layouts
import "../Lang"
import "../../COMMON"

RowLayout {
  id: bar

  required property var walls
  property bool compact: false
  // Estrecho (rail): sin atajo "Ctrl + K" y botones solo con icono
  property bool narrow: false
  // Lista + preview: aleatorio, vista previa y contador suben a esta fila
  property bool showActions: false

  readonly property int h: bar.compact ? 36 : 44
  readonly property int fs: bar.compact ? 12 : 14

  spacing: bar.compact ? 8 : 12

  // ─── CAMPO ───
  SkinRect {
    id: field
    Layout.fillWidth: true
    Layout.preferredHeight: bar.h
    notch: 4
    raised: Theme.cozy
    depth: 3
    inkColor: Theme.primary
    color: Theme.bg
    border.color: Theme.primary
    border.width: input.activeFocus ? 2.5 : 1.5

    Text {
      id: glass
      anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
      text: "󰍉"
      color: Theme.primary
      font.pixelSize: bar.fs + 6
      font.family: Theme.monoFamily
    }

    Item {
      anchors {
        left: glass.right; leftMargin: 12
        right: tail.left; rightMargin: 10
        verticalCenter: parent.verticalCenter
      }
      height: input.implicitHeight

      Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: input.text === "" && !input.preeditText
        text: bar.walls.remoteSearch ? Translations.t("wallsSearchOnlinePlaceholder") : Translations.t("wallsSearchPlaceholder")
        color: Theme.tint(0.45)
        font.pixelSize: bar.fs
        font.family: Theme.fontFamily
        elide: Text.ElideRight
        width: parent.width
      }

      TextInput {
        id: input
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        color: Theme.text
        selectionColor: Theme.primary
        selectedTextColor: Theme.textOnPrimary
        font.pixelSize: bar.fs
        font.family: Theme.fontFamily
        clip: true
        selectByMouse: true
        inputMethodHints: Qt.ImhNoPredictiveText
        maximumLength: 80
        onTextEdited: bar.walls.searchText = input.text

        Keys.onPressed: event => bar.handleKey(event, input)
      }
    }

    Row {
      id: tail
      anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
      spacing: 10

      Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: bar.walls.searchPending || (bar.walls.remoteSearch && bar.walls.onlineLoading)
        text: "…"
        color: Theme.primary
        font.pixelSize: bar.fs + 4
        font.family: Theme.fontFamily
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: input.text !== ""
        text: "󰅖"
        color: clearArea.containsMouse ? Theme.primary : Theme.tint(0.6)
        font.pixelSize: bar.fs + 2
        font.family: Theme.monoFamily
        MouseArea {
          id: clearArea
          anchors.fill: parent
          anchors.margins: -6
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: { bar.walls.clearSearch(); input.forceActiveFocus() }
        }
      }

      Rectangle {
        visible: !bar.narrow
        anchors.verticalCenter: parent.verticalCenter
        width: hint.implicitWidth + 18
        height: bar.h - 18
        radius: Theme.cozy ? 0 : 6
        color: Theme.tint(0.1)
        Text {
          id: hint
          anchors.centerIn: parent
          text: "Ctrl + K"
          color: Theme.tint(0.6)
          font.pixelSize: bar.fs - 2
          font.family: Theme.monoFamily
        }
      }
    }

    MouseArea {
      anchors.fill: parent
      z: -1
      cursorShape: Qt.IBeamCursor
      onClicked: input.forceActiveFocus()
    }
  }

  // ─── ONLINE: IMÁGENES / LIVE ───
  WallsKindToggle {
    visible: bar.walls.onlineMode && !bar.narrow
    walls: bar.walls
    fontSize: bar.fs - 1
    Layout.preferredWidth: visible ? 220 : 0
    Layout.preferredHeight: bar.h
  }

  // ─── FILTROS / ORDEN ───
  WallsBarButton {
    icon: "󰈲"
    label: bar.narrow ? "" : Translations.t("wallsFilters")
    padX: bar.narrow ? 12 : 18
    fontSize: bar.fs - 1
    active: bar.walls.popup === "filters"
    badge: bar.walls.filterExt !== ""
    Layout.preferredHeight: bar.h
    onClicked: bar.walls.popup = bar.walls.popup === "filters" ? "" : "filters"
  }

  WallsBarButton {
    icon: "󰒻"
    label: bar.narrow ? "▾" : Translations.t("wallsSort") + " ▾"
    padX: bar.narrow ? 12 : 18
    fontSize: bar.fs - 1
    active: bar.walls.popup === "sort"
    Layout.preferredHeight: bar.h
    onClicked: bar.walls.popup = bar.walls.popup === "sort" ? "" : "sort"
  }

  // ─── ALEATORIO / VISTA PREVIA / CONTADOR ───
  WallsBubble {
    visible: bar.showActions
    Layout.preferredWidth: visible ? barActions.implicitWidth + 20 : 0
    Layout.preferredHeight: bar.h

    WallsActionChips {
      id: barActions
      walls: bar.walls
      chipHeight: bar.compact ? 24 : 26
      chipPad: bar.compact ? 16 : 20
      fontSize: 10
      spacing: bar.compact ? 6 : 8
      anchors.centerIn: parent
    }
  }

  WallsCounter {
    visible: bar.showActions
    walls: bar.walls
    pillHeight: bar.h
    fontSize: 10
  }

  Connections {
    target: bar.walls
    function onFocusSearchRequested() { input.forceActiveFocus(); input.selectAll() }
    function onSearchTextChanged() { if (input.text !== bar.walls.searchText) input.text = bar.walls.searchText }
  }

  function handleKey(event, input) {
    const ctrl = (event.modifiers & Qt.ControlModifier) !== 0
    const empty = input.text === ""
    const w = bar.walls
    event.accepted = true
    switch (event.key) {
      case Qt.Key_Escape:
        if (w.popup !== "") w.popup = ""
        else if (!empty) w.clearSearch()
        else w.closeRequested()
        return
      case Qt.Key_Tab: w.cycleMode(); return
      case Qt.Key_Return:
      case Qt.Key_Enter:
        if (w.searchPending) w.submitSearch()
        else w.applyItem(w.activeModel.get(w.currentIndex))
        return
      case Qt.Key_Down: w.step(1); return
      case Qt.Key_Up: w.step(-1); return
      case Qt.Key_PageDown: w.step(5); return
      case Qt.Key_PageUp: w.step(-5); return
      case Qt.Key_Left: if (empty) { w.step(-1); return } break
      case Qt.Key_Right: if (empty) { w.step(1); return } break
      case Qt.Key_Home: if (empty) { w.goTo(0); return } break
      case Qt.Key_End: if (empty) { w.goTo(w.activeModel.count - 1); return } break
    }
    if (ctrl) {
      switch (event.key) {
        case Qt.Key_K: input.selectAll(); return
        case Qt.Key_R: w.randomIndex(); return
        case Qt.Key_P: w.previewOn = !w.previewOn; return
        case Qt.Key_U: w.clearSearch(); return
      }
    }
    event.accepted = false
  }
}
