// WidgetBlur — fondo difuminado de un widget (el «cristal esmerilado»).

import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import "../COMMON"

ClippingRectangle {
  id: root

  property bool allowed: true
  property Item host: null
  property real strength: root.host ? root.host.blurStrength : 0

  readonly property real amount: Math.max(0, Math.min(1, root.strength / 100))

  readonly property bool blurOn: root.allowed && root.amount > 0.001 && !Theme.performanceMode
                             && root.host !== null && root.width > 2 && root.height > 2
                             && (root.parent ? root.parent.visible : true)


  readonly property int ds: 4
  readonly property real blurMax: 24

  readonly property real pad: Math.ceil(root.amount * root.blurMax * root.ds)


  property real offX: 0
  property real offY: 0
  function locate() {
    if (!root.host) return
    const p = root.mapToItem(root.host, 0, 0)
    root.offX = p.x
    root.offY = p.y
  }

  color: "transparent"
  visible: root.blurOn

  Component.onCompleted: {
    let p = root.parent
    while (p && p.isWidgetBase !== true) p = p.parent
    root.host = p
    root.locate()
  }
  onWidthChanged: root.locate()
  onHeightChanged: root.locate()
  onXChanged: root.locate()
  onYChanged: root.locate()


  Connections {
    target: root.host
    function onWidthChanged() { root.locate() }
    function onHeightChanged() { root.locate() }
  }

  Loader {
    anchors.fill: parent
    active: root.blurOn && WidgetBackdrop.url !== ""

    sourceComponent: Item {
      id: stage
      anchors.fill: parent


      Image {
        id: wall
        visible: false
        width: root.host.screenW
        height: root.host.screenH
        source: WidgetBackdrop.url
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(Math.max(16, Math.round(root.host.screenW / root.ds)),
                            Math.max(16, Math.round(root.host.screenH / root.ds)))
        asynchronous: true
        cache: true
        smooth: true
      }


      ShaderEffectSource {
        id: crop
        visible: false
        sourceItem: wall
        sourceRect: Qt.rect(root.host.originX + root.offX - root.pad,
                            root.host.originY + root.offY - root.pad,
                            root.width + 2 * root.pad,
                            root.height + 2 * root.pad)
        width: root.width + 2 * root.pad
        height: root.height + 2 * root.pad
        textureSize: Qt.size(Math.max(1, Math.ceil(crop.width / root.ds)),
                             Math.max(1, Math.ceil(crop.height / root.ds)))
        smooth: true
      }

      MultiEffect {
        x: -root.pad
        y: -root.pad
        width: crop.width
        height: crop.height
        source: crop
        autoPaddingEnabled: false
        blurEnabled: true
        blur: root.amount
        blurMax: root.blurMax
        saturation: 0.12
        opacity: wall.status === Image.Ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.animDuration(250) } }
      }
    }
  }
}
