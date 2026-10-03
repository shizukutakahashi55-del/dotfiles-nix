import QtQuick

Item {
  id: root

  property bool active: false
  property bool hovered: false
  property bool pressed: false
  property string label: ""
  // Número dentro de una cajita dibujada (OozeSoft, workspace inactivo). Se
  // dibuja en vez de usar los glifos "numeric-N-box" de la Nerd Font: esos
  // solo existen hasta el 9 y 6–10 salían como texto suelto.
  property string boxText: ""
  property int fontPx: Theme.fs(17)

  // ── OozeSoft ──
  Rectangle {
    visible: !Theme.cozy
    anchors.fill: parent
    radius: 9
    color: root.active ? Theme.primary : root.hovered ? Theme.surface : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.animDuration(160) } }
  }

  // ── CoOzey ──
  SkinRect {
    visible: Theme.cozy
    anchors.fill: parent
    notch: 3
    color: root.active ? Theme.primary
         : root.hovered ? Theme.surfaceHigh
         : Theme.mix(Theme.bg, Theme.surface, 0.75)
    // el activo lleva la tinta completa; los demás, un contorno más suave
    inkColor: root.active ? Theme.ink : Theme.mix(Theme.ink, Theme.surfaceHigh, 0.45)
  }

  Rectangle {
    id: numBox
    visible: root.boxText !== "" && root.label === ""
    anchors.centerIn: parent
    readonly property real side: Math.round(root.fontPx * 0.95)
    height: side
    width: Math.max(side, numTxt.implicitWidth + 8)
    radius: Math.max(3, Math.round(side * 0.22))
    // el workspace actual: caja invertida (número resaltado sobre el chip primario)
    color: root.active ? Theme.textOnPrimary : root.hovered ? Theme.text : Theme.mix(Theme.text, Theme.bg, 0.12)
    Text {
      id: numTxt
      anchors.centerIn: parent
      text: root.boxText
      color: root.active ? Theme.primary : Theme.bg
      font.family: Theme.fontFamily
      font.bold: true
      font.pixelSize: Math.round(numBox.side * 0.68)
    }
  }

  Text {
    visible: !numBox.visible
    anchors.centerIn: parent
    anchors.verticalCenterOffset: (Theme.cozy && root.pressed) ? 1 : 0
    text: root.label
    color: root.active ? Theme.textOnPrimary
         : (Theme.cozy && !root.hovered) ? Theme.subtext
         : Theme.text
    font.family: Theme.fontFamily
    font.pixelSize: root.fontPx
    font.bold: Theme.cozy && root.active
    Behavior on color { ColorAnimation { duration: Theme.animDuration(Theme.cozy ? 0 : 160) } }
  }
}
