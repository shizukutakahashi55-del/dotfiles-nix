// WidgetCard — el fondo/tarjeta de TODOS los widgets, SIN bordes.

import QtQuick
import "../COMMON"

Item {
  id: card

  property real alpha: 0.6
  property bool tile: false
  property real scaleRadius: 1

  readonly property color base: card.tile ? Theme.surface : Theme.bg
  property real radius: Math.round((card.tile ? Theme.cardRadius : Theme.panelRadius - 2) * card.scaleRadius)
  property color color: Qt.rgba(card.base.r, card.base.g, card.base.b,
                                card.tile ? Math.max(0.35, card.alpha) : card.alpha)

  default property alias content: body.data

  WidgetBlur {
    anchors.fill: parent
    radius: card.radius
    allowed: !card.tile
  }

  Rectangle {
    anchors.fill: parent
    radius: card.radius
    color: card.color
  }

  Item { id: body; anchors.fill: parent }
}
