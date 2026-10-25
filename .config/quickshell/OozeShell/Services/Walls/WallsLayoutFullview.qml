// WallsLayoutFullview — WALLS
// Carrusel grande, centrado en pantalla, con tarjetas inclinadas (paralelogramo).
// No es pantalla completa: el panel flota en el centro.

import QtQuick
import QtQuick.Layouts
import "../../COMMON"

Item {
  id: root

  required property var walls
  property real progress: 1

  readonly property int pad: 28
  readonly property int gap: 18
  // tan(inclinación): 0.22 ≈ 12.4°
  readonly property real skew: 0.22
  readonly property real cardRatio: 0.52

  implicitHeight: col.implicitHeight + root.pad * 2

  ColumnLayout {
    id: col
    x: 0
    y: root.pad
    width: parent.width
    spacing: root.gap

    WallsSearchBar {
      id: search
      walls: root.walls
      Layout.fillWidth: true
      Layout.leftMargin: root.pad
      Layout.rightMargin: root.pad
    }

    WallsCards {
      id: cards
      walls: root.walls
      progress: root.progress
      cardRatio: root.cardRatio
      skew: root.skew
      hoverLift: 14
      gap: 10
      // la inclinación saca cada tarjeta skew*alto/2 por cada lado
      edgeMargin: Math.ceil(root.skew * cards.cardH / 2) + 16
      Layout.fillWidth: true
      Layout.preferredHeight: implicitHeight
    }

    WallsHeader {
      walls: root.walls
      showCounter: true
      Layout.fillWidth: true
      Layout.leftMargin: root.pad
      Layout.rightMargin: root.pad
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
