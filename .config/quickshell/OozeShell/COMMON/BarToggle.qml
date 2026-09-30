// BarToggle — mini botón para plegar / desplegar un módulo de la barra
// (mpris, taskbar). Plegado, el módulo queda reducido a un solo ícono.
//
// Es una tira angosta con un triángulo. Regla de la flecha:
//   • módulo DESPLEGADO → apunta HACIA el contenido (lo va a plegar)
//   • módulo PLEGADO    → apunta hacia AFUERA (lo va a desplegar)
// `contentAfter` dice de qué lado del botón está el contenido, en el orden
// del BarFlow: true = el contenido va después (a la derecha / abajo),
// false = va antes (a la izquierda / arriba). Con eso la flecha es correcta
// tanto en barra horizontal (◂ ▸) como vertical (▴ ▾).
//
// Sin tooltip propio (igual que los demás botones de la barra): emite
// hoverEntered / hoverExited y el host muestra el tooltip compartido
// (FusedTip) leyendo la propiedad `tip`.
//
//   BarToggle {
//     id: toggle
//     collapsed: Theme.mprisCompact
//     contentAfter: false
//     tip: Translations.t(collapsed ? "barExpand" : "barCollapse")
//     onToggled: Theme.setMprisCompact(!Theme.mprisCompact)
//     onHoverEntered: host.tipEnter(toggle)
//     onHoverExited: host.tipLeave(toggle)
//   }
import QtQuick
import QtQuick.Layouts
import "../COMMON"

Rectangle {
  id: toggle

  property bool collapsed: false
  property bool contentAfter: false
  property string tip: ""

  signal toggled()
  signal hoverEntered()
  signal hoverExited()

  readonly property string glyph: {
    const v = Theme.barVertical
    const towards = toggle.contentAfter ? (v ? "▾" : "▸") : (v ? "▴" : "◂")
    const away    = toggle.contentAfter ? (v ? "▴" : "◂") : (v ? "▾" : "▸")
    return toggle.collapsed ? away : towards
  }

  // Horizontal: tira angosta con el alto de los botones (30). Vertical: tira
  // baja con el ancho de los botones (la barra vertical mide 44).
  Layout.preferredWidth: Theme.barVertical ? 30 : 16
  Layout.preferredHeight: Theme.barVertical ? 16 : 30
  Layout.alignment: Qt.AlignCenter

  radius: 8
  color: area.containsMouse ? Theme.surface : "transparent"
  Behavior on color { ColorAnimation { duration: 150 } }

  scale: area.pressed ? 0.90 : (area.containsMouse ? 1.06 : 1.0)
  Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }

  Text {
    anchors.centerIn: parent
    text: toggle.glyph
    color: Theme.subtext
    font.family: Theme.monoFamily
    font.pixelSize: Theme.fs(20)
    // Discreto en reposo, se enciende al pasar el mouse
    opacity: area.containsMouse ? 1.0 : 0.75
    Behavior on opacity { NumberAnimation { duration: 150 } }
  }

  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onEntered: toggle.hoverEntered()
    onExited: toggle.hoverExited()
    onClicked: toggle.toggled()
  }
}
