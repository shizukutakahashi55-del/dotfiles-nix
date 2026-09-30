import QtQuick

Item {
  id: root

  property bool active: false
  property bool hovered: false
  property bool pressed: false
  property string label: ""
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

  Text {
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
