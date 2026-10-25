// WallsLayoutList — WALLS
// Columna de miniaturas a la izquierda + vista previa grande a la derecha.
// Panel centrado en pantalla (no pantalla completa).

import QtQuick
import QtQuick.Layouts
import "../../COMMON"

Item {
  id: root

  required property var walls
  property real progress: 1

  readonly property int pad: 20
  readonly property int gap: 14
  readonly property int listW: 210
  readonly property real innerW: Math.max(0, root.width - root.pad * 2)
  readonly property real fit: header.implicitWidth > root.innerW && header.implicitWidth > 0
                              ? root.innerW / header.implicitWidth : 1

  implicitHeight: col.implicitHeight + root.pad * 2

  ColumnLayout {
    id: col
    x: root.pad
    y: root.pad
    width: root.innerW
    spacing: root.gap

    WallsSearchBar {
      id: search
      walls: root.walls
      showActions: true
      Layout.fillWidth: true
    }

    RowLayout {
      id: body
      spacing: root.gap
      Layout.fillWidth: true
      Layout.preferredHeight: cards.implicitHeight

      WallsCards {
        id: cards
        walls: root.walls
        progress: root.progress
        vertical: true
        cardAspect: 9.0 / 16.0
        sideLen: 44
        gap: 5
        edgeMargin: 0
        hoverLift: 0
        Layout.preferredWidth: root.listW
        Layout.preferredHeight: implicitHeight
        Layout.alignment: Qt.AlignTop
      }

      WallsPreview {
        walls: root.walls
        Layout.fillWidth: true
        Layout.fillHeight: true
      }
    }

    Item {
      id: headerBox
      Layout.fillWidth: true
      Layout.preferredHeight: Math.round(header.implicitHeight * root.fit)

      WallsHeader {
        id: header
        walls: root.walls
        compact: true
        showCounter: false
        showActions: false
        width: Math.max(root.innerW, header.implicitWidth)
        x: (headerBox.width - width * root.fit) / 2
        scale: root.fit
        transformOrigin: Item.TopLeft
      }
    }
  }

  // ─── MENÚ DE FILTROS / ORDEN ───
  MouseArea {
    anchors.fill: parent
    z: 200
    enabled: root.walls.popup !== ""
    onClicked: root.walls.popup = ""
  }

  WallsPopup {
    walls: root.walls
    z: 201
    x: root.width - width - root.pad
    y: Math.min(root.pad + search.height + 8, Math.max(4, root.height - height - 4))
  }
}
