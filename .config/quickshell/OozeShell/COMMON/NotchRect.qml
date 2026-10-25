// NotchRect.qml — COMMON

import QtQuick


Item {
  id: root
  property color topColor: "#888888"
  property color bottomColor: root.topColor
  property bool solid: true
  property int notch: 4

  readonly property int n: Math.max(0, Math.min(root.notch, Math.floor(Math.min(root.width, root.height) / 2)))

  function at(y) {
    if (root.solid || root.height <= 0) return root.topColor
    return Theme.mix(root.topColor, root.bottomColor, Math.max(0, Math.min(1, y / root.height)))
  }


  Gradient { id: gCenter
    GradientStop { position: 0.0; color: root.at(root.n) }
    GradientStop { position: 1.0; color: root.at(root.height - root.n) }
  }
  Gradient { id: gTop
    GradientStop { position: 0.0; color: root.at(0) }
    GradientStop { position: 1.0; color: root.at(root.n) }
  }
  Gradient { id: gBottom
    GradientStop { position: 0.0; color: root.at(root.height - root.n) }
    GradientStop { position: 1.0; color: root.at(root.height) }
  }


  Rectangle {
    x: 0; y: root.n
    width: root.width; height: Math.max(0, root.height - 2 * root.n)
    color: root.topColor
    gradient: root.solid ? null : gCenter
  }

  Rectangle {
    x: root.n; y: 0
    width: Math.max(0, root.width - 2 * root.n); height: root.n
    color: root.topColor
    gradient: root.solid ? null : gTop
  }

  Rectangle {
    x: root.n; y: root.height - root.n
    width: Math.max(0, root.width - 2 * root.n); height: root.n
    color: root.topColor
    gradient: root.solid ? null : gBottom
  }
}
