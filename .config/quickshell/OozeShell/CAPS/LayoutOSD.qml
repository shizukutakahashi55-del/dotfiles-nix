// LayoutOSD — aviso flotante al cambiar el idioma del teclado (layout xkb),
// con el mismo look que CapsOSD/AudioOSD pero pegado a la IZQUIERDA (abajo).
// No crea ninguna notificación: es solo esta píldora, que aparece ~1.4 s y
// se esconde sola.
//
// El aviso lo dispara KeyboardLayout.layoutSwitched (COMMON/KeyboardLayout.qml),
// que cubre el botón de la barra, `keyboardlayout next` y el toggle nativo de
// Hyprland (grp:alt_shift_toggle).
//
// Prueba manual (sin cambiar el teclado):
//   quickshell ipc -p .../shell.qml call -- layoutosd show English
//
// Vive montado siempre (como CapsOSD): visible pero click-through (mask
// vacío) mientras no hay nada que mostrar.
import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../COMMON"

Item {
  id: root

  property string targetScreen: ""
  property int cardWidth: 230
  property int showMs: 1400

  property string layoutName: ""
  property string layoutLabel: ""
  property bool osdVisible: false

  function show(name, label) {
    root.layoutName = name
    root.layoutLabel = label
    root.osdVisible = true
    hideTimer.restart()
  }

  Timer {
    id: hideTimer
    interval: root.showMs
    repeat: false
    onTriggered: root.osdVisible = false
  }

  Connections {
    target: KeyboardLayout
    function onLayoutSwitched(name, label) { root.show(name, label) }
  }

  PanelWindow {
    id: win

    screen: Quickshell.screens.find(s => s.name === root.targetScreen) ?? Quickshell.screens[0]
    visible: true
    color: "transparent"
    exclusiveZone: -1

    anchors { bottom: true; left: true }
    implicitWidth: root.cardWidth + 34 + 40
    implicitHeight: 200

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "oozeshell-layout-osd"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // El mask sigue el alto animado del card: 0 = sin zona de clics
    mask: Region { item: card }

    Rectangle {
      id: card
      anchors.left: parent.left
      anchors.bottom: parent.bottom
      // Barra a la izquierda o abajo: se corre para no quedar debajo de ella
      anchors.leftMargin: 34 + ((Theme.barVertical && !Theme.barAtRight) ? Theme.barOffset : 0)
      anchors.bottomMargin: 34 + (Theme.barAtBottom ? Theme.barOffset : 0)

      readonly property int fullHeight: 58

      width: root.cardWidth
      height: root.osdVisible ? fullHeight : 0
      clip: true
      radius: Theme.panelRadius
      color: Theme.bg

      opacity: Math.max(0, Math.min(1, height / fullHeight))
      scale: 0.94 + 0.06 * opacity
      transformOrigin: Item.Left

      Behavior on height { NumberAnimation { duration: Theme.animDuration(160); easing.type: Easing.OutCubic } }

      RowLayout {
        width: card.width - 32
        height: card.fullHeight - 16
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        spacing: 12

        // Chip con la etiqueta corta (ESP / ENG…)
        Rectangle {
          Layout.preferredWidth: 42
          Layout.preferredHeight: 34
          radius: 10
          color: Theme.primary

          Text {
            anchors.centerIn: parent
            text: root.layoutLabel
            color: Theme.textOnPrimary
            font.pixelSize: 14
            font.bold: true
            font.family: Theme.fontFamily
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 0

          Text {
            text: "Teclado"
            color: Theme.text
            font.pixelSize: 13
            font.bold: true
            font.family: Theme.fontFamily
          }
          Text {
            Layout.fillWidth: true
            text: root.layoutName
            elide: Text.ElideRight
            color: Theme.primary
            font.pixelSize: 11
            font.family: Theme.fontFamily
          }
        }
      }
    }
  }
}
