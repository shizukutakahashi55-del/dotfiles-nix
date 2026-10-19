// AppIcon — ícono de una app que NUNCA muestra el cuadriculado morado/negro.

import Quickshell
import QtQuick

Item {
  id: root

  property string icon: ""
  property string appId: ""
  property real size: 24

  property string glyph: "󰀻"
  property color glyphColor: Theme.subtext

  implicitWidth: root.size
  implicitHeight: root.size

  readonly property int desktopRevision: DesktopEntries.applications.values.length


  function resolve() {
    void root.desktopRevision

    const names = []
    if (root.icon !== "") names.push(root.icon)
    const id = root.appId
    if (id !== "") {
      const entry = DesktopEntries.heuristicLookup(id)
      if (entry && entry.icon) names.push(entry.icon)
      names.push(id, id.toLowerCase())
      const last = id.split(".").pop().toLowerCase()
      if (last !== id.toLowerCase()) names.push(last)
    }

    for (let i = 0; i < names.length; i++) {
      const n = names[i]
      if (!n) continue

      if (n.charAt(0) === "/") return "file://" + n
      const p = Quickshell.iconPath(n, true)
      if (p !== "") return p
    }
    return Quickshell.iconPath("application-x-executable", true)
  }

  readonly property string src: root.resolve()

  Image {
    anchors.fill: parent
    visible: root.src !== ""
    source: root.src
    asynchronous: true
    smooth: true
    sourceSize: Qt.size(Math.ceil(root.size), Math.ceil(root.size))
  }

  Text {
    anchors.centerIn: parent
    visible: root.src === ""
    text: root.glyph
    color: root.glyphColor
    font.pixelSize: Math.round(root.size * 0.9)
    font.family: Theme.monoFamily
  }
}
