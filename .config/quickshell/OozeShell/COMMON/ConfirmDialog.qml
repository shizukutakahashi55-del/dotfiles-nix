// ConfirmDialog — popup modal de confirmación, centrado en pantalla.
//
// Pensado para acciones que no se pueden deshacer (apagar, reiniciar, cerrar
// sesión). A diferencia de FusedWindow no cuelga de la barra: oscurece TODA
// la pantalla (barra incluida) y captura mouse y teclado mientras está abierto.
//
//   • Clic afuera / Esc        = cancelar
//   • Enter                    = activar el botón resaltado
//   • ← → / Tab                = cambiar de botón (arranca en "confirmar")
//
// Igual que FusedWindow, la ventana queda SIEMPRE montada (transparente y
// click-through mientras está cerrada), así Hyprland no le aplica su propia
// animación de layer y la nuestra (fade + escala) se ve limpia.
//
// Vive FUERA del panel que lo dispara a propósito: el menú se cierra al hacer
// clic en un botón de energía y el diálogo tiene que sobrevivirle.
//
// Uso:
//   ConfirmDialog {
//     open: algo
//     targetScreen: root.targetMonitor
//     icon: "󰐥"
//     title: "¿Apagar el equipo?"
//     message: "Se cerrarán las apps abiertas."
//     confirmText: "Apagar"
//     cancelText: "Cancelar"
//     danger: true
//     onConfirmed: ...
//     onCancelled: ...
//   }
import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../COMMON"

Item {
  id: root

  property bool open: false
  property string targetScreen: ""
  property string namespace: "oozeshell-confirm"

  property string icon: ""
  property string title: ""
  property string message: ""
  property string confirmText: "OK"
  property string cancelText: "Cancel"
  // true = botón de confirmar en rojo (acciones destructivas)
  property bool danger: false

  signal confirmed()
  signal cancelled()

  // Botón resaltado con el teclado: 0 = cancelar, 1 = confirmar
  property int focusIndex: 1

  onOpenChanged: if (root.open) root.focusIndex = 1

  function activateFocused() {
    if (root.focusIndex === 1) root.confirmed()
    else root.cancelled()
  }

  PanelWindow {
    id: win

    screen: Quickshell.screens.find(s => s.name === root.targetScreen) ?? Quickshell.screens[0]
    visible: true
    color: "transparent"
    exclusiveZone: -1
    anchors { top: true; left: true; right: true; bottom: true }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: root.namespace
    // Modal: mientras está abierto se queda con el teclado (Esc / Enter)
    WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Cerrado: región vacía = todo click-through
    mask: Region { item: hitArea }

    Connections {
      target: root
      function onOpenChanged() {
        if (root.open) keyCatcher.forceActiveFocus()
      }
    }

    // ── Fondo oscurecido ──
    Rectangle {
      anchors.fill: parent
      color: "#000000"
      opacity: root.open ? 0.5 : 0
      visible: opacity > 0
      Behavior on opacity { NumberAnimation { duration: 180 } }
    }

    // ── Zona que captura input (clic afuera = cancelar) ──
    Item {
      id: hitArea
      width: root.open ? parent.width : 0
      height: root.open ? parent.height : 0

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onClicked: root.cancelled()
      }
    }

    Item {
      id: keyCatcher
      anchors.fill: parent
      focus: true
      Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
          root.cancelled()
          event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
          root.activateFocused()
          event.accepted = true
        } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Right
                   || event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
          root.focusIndex = root.focusIndex === 1 ? 0 : 1
          event.accepted = true
        }
      }
    }

    // ── Tarjeta ──
    Rectangle {
      id: card
      anchors.centerIn: parent
      width: 340
      height: content.implicitHeight + 48
      radius: Theme.panelRadius
      color: Theme.bg
      border.width: Theme.bw1
      border.color: Theme.edge

      opacity: root.open ? 1 : 0
      visible: opacity > 0
      // Respeta la escala de "Ventanas" (Ajustes → Interfaz)
      scale: (root.open ? 1.0 : 0.92) * Theme.windowScale
      Behavior on opacity { NumberAnimation { duration: 180 } }
      Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

      // Los clics sobre la tarjeta no deben llegar al fondo (que cancela)
      MouseArea { anchors.fill: parent }

      ColumnLayout {
        id: content
        x: 24
        y: 24
        width: parent.width - 48
        spacing: 12

        // Ícono
        Rectangle {
          Layout.alignment: Qt.AlignHCenter
          Layout.preferredWidth: 56
          Layout.preferredHeight: 56
          radius: 28
          color: root.danger
            ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.16)
            : Theme.surface
          Text {
            anchors.centerIn: parent
            text: root.icon
            color: root.danger ? Theme.error : Theme.primary
            font.pixelSize: Theme.fs(26)
            font.family: Theme.monoFamily
          }
        }

        Text {
          Layout.fillWidth: true
          text: root.title
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.WordWrap
          color: Theme.text
          font.pixelSize: Theme.fs(15)
          font.bold: true
          font.family: Theme.fontFamily
        }

        Text {
          Layout.fillWidth: true
          visible: text !== ""
          text: root.message
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.WordWrap
          color: Theme.subtext
          font.pixelSize: Theme.fs(11)
          font.family: Theme.fontFamily
        }

        // Botones: Cancelar | Confirmar
        RowLayout {
          Layout.fillWidth: true
          Layout.topMargin: 8
          spacing: 10

          Repeater {
            model: [ { confirm: false }, { confirm: true } ]
            delegate: Rectangle {
              id: btn
              readonly property bool isConfirm: modelData.confirm
              readonly property bool focused: root.focusIndex === (btn.isConfirm ? 1 : 0)

              Layout.fillWidth: true
              Layout.preferredWidth: 1
              Layout.preferredHeight: 40
              radius: 10

              color: btn.isConfirm
                ? (root.danger
                    ? (btnArea.containsMouse ? Qt.lighter(Theme.error, 1.12) : Theme.error)
                    : (btnArea.containsMouse ? Qt.lighter(Theme.primary, 1.12) : Theme.primary))
                : (btnArea.containsMouse ? Theme.surfaceHigh : Theme.surface)
              Behavior on color { ColorAnimation { duration: 150 } }

              // Anillo del botón resaltado con el teclado
              border.width: btn.focused ? 2 : 0
              border.color: btn.isConfirm ? Theme.text : Theme.primary

              scale: btnArea.pressed ? 0.96 : 1.0
              Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }

              Text {
                anchors.centerIn: parent
                width: parent.width - 16
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: btn.isConfirm ? root.confirmText : root.cancelText
                color: btn.isConfirm
                  ? (root.danger ? Theme.textOnError : Theme.textOnPrimary)
                  : Theme.text
                font.pixelSize: Theme.fs(12)
                font.bold: true
                font.family: Theme.fontFamily
              }

              MouseArea {
                id: btnArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: btn.isConfirm ? root.confirmed() : root.cancelled()
              }
            }
          }
        }
      }
    }
  }
}
