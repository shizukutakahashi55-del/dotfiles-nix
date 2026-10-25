// WidgetBlur — silueta del widget para el blur real del compositor (ext-background-effect-v1).

import QtQuick
import QtQml
import "../../COMMON"

Item {
  id: root

  property bool allowed: true
  property real radius: 0
  property Item host: null
  property real strength: root.host ? root.host.blurStrength : 0

  readonly property real amount: Math.max(0, Math.min(1, root.strength / 100))

  readonly property bool active: root.allowed && root.amount > 0.001 && !Theme.shellPerf
                             && root.host !== null && root.width > 2 && root.height > 2
                             && (root.parent ? root.parent.visible : true)

  property real offX: 0
  property real offY: 0
  property var chain: []

  function locate() {
    if (!root.host) return
    const p = root.mapToItem(root.host, 0, 0)
    root.offX = p.x
    root.offY = p.y
  }

  Component.onCompleted: {
    const c = []
    let p = root
    while (p && p.isWidgetBase !== true) { c.push(p); p = p.parent }
    root.host = p
    root.chain = c
    if (root.host) root.host.registerBlur(root)
    root.locate()
  }

  Component.onDestruction: {
    if (root.host) root.host.unregisterBlur(root)
  }

  onWidthChanged: root.locate()
  onHeightChanged: root.locate()

  Instantiator {
    model: root.chain
    delegate: Connections {
      required property var modelData
      target: modelData
      function onXChanged() { root.locate() }
      function onYChanged() { root.locate() }
      function onWidthChanged() { root.locate() }
      function onHeightChanged() { root.locate() }
    }
  }
}
