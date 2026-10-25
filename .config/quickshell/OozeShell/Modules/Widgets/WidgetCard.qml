// WidgetCard

import QtQuick
import "../../COMMON"

Item {
  id: card

  property real alpha: 0.6
  property bool tile: false
  property bool pill: false
  property real scaleRadius: 1
  property Item host: null

  readonly property color base: card.tile ? Theme.surface : Theme.bg
  property real radius: (card.pill && !Theme.cozy && !card.tile)
    ? Math.round(card.height / 2)
    : Math.round((card.tile ? Theme.cardRadius : Theme.panelRadius - 2) * card.scaleRadius)
  property color color: Qt.rgba(card.base.r, card.base.g, card.base.b,
                                card.tile ? Math.max(0.35, card.alpha) : card.alpha)

  readonly property bool bordered: !card.tile && card.host !== null && card.host.showBorder === true

  default property alias content: body.data

  Component.onCompleted: {
    let p = card.parent
    while (p && p.isWidgetBase !== true) p = p.parent
    card.host = p
  }

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

  WidgetBorder {
    anchors.fill: parent
    visible: card.bordered
    radius: card.radius
  }

  Item { id: body; anchors.fill: parent }
}
