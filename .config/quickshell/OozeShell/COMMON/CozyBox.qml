import QtQuick

// CozyBox — la "tarjeta de papel" semi pixel art de CoOzey.
Item {
  id: root
  property color fillTop: Theme.mix(Theme.surface, Theme.text, 0.05)
  property color fillBottom: Theme.surface
  property color ink: Theme.ink
  property int notch: 4
  property int inkW: 2
  property bool shadow: true
  property int shadowOffset: Math.max(2, Theme.shadowY)
  property bool shine: true
  property bool dither: false
  default property alias content: body.data
  readonly property alias contentItem: body

  NotchRect {
    visible: root.shadow
    x: 0; y: root.shadowOffset
    width: root.width; height: root.height
    topColor: Theme.shadowInk
    notch: root.notch
  }
  NotchRect {
    anchors.fill: parent
    topColor: root.ink
    notch: root.notch
  }
  NotchRect {
    x: root.inkW; y: root.inkW
    width: Math.max(0, root.width - 2 * root.inkW)
    height: Math.max(0, root.height - 2 * root.inkW)
    solid: false
    topColor: root.fillTop
    bottomColor: root.fillBottom
    notch: root.notch
  }

  // filo de luz (arriba) y sombra fina (abajo), como el bisel de un sprite
  Rectangle {
    visible: root.shine
    x: root.inkW + root.notch; y: root.inkW
    width: Math.max(0, root.width - 2 * (root.inkW + root.notch)); height: 2
    color: Theme.paperShine
  }
  Rectangle {
    visible: root.shine
    x: root.inkW + root.notch; y: root.height - root.inkW - 2
    width: Math.max(0, root.width - 2 * (root.inkW + root.notch)); height: 2
    color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.22)
  }

  // tramado (dither) al pie: dos filas de puntos en damero
  Canvas {
    id: dith
    visible: root.dither
    x: root.inkW + root.notch
    y: root.height - root.inkW - 8
    width: Math.max(0, root.width - 2 * (root.inkW + root.notch))
    height: 6
    onWidthChanged: requestPaint()
    onVisibleChanged: requestPaint()
    Connections { target: root; function onInkChanged() { dith.requestPaint() } }
    onPaint: {
      const ctx = getContext("2d")
      ctx.reset()
      ctx.fillStyle = Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.16)
      for (let row = 0; row < 3; row++)
        for (let x = (row % 2) * 2; x < width; x += 4)
          ctx.fillRect(x, row * 2, 2, 2)
    }
  }

  Item {
    id: body
    anchors.fill: parent
    anchors.margins: root.inkW
  }
}
