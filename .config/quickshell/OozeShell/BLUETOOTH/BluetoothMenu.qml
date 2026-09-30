// BluetoothMenu — panel de Bluetooth (dispositivos, conectar, emparejar).
//
// Mismo lenguaje que NetworkMenu: es un FusedPanel que cuelga de la barra
// arriba a la derecha, con el mismo ancho que el Menu.
//
// Flujo:
//   • clic en un dispositivo conectado    → lo desconecta
//   • clic en uno emparejado              → lo conecta
//   • clic en uno nuevo                   → lo empareja y conecta
//   • ícono de papelera (al pasar el mouse sobre uno emparejado) → lo olvida
//   • la flecha ‹ vuelve al Menu
//
// Atajo de teclado (IPC):
//   quickshell ipc -p .../shell.qml call -- bluetooth toggle
import Quickshell
import QtQuick
import QtQuick.Layouts
import "../COMMON"
import "../LANG"

Item {
  id: root

  property bool open: false
  property string targetScreen: ""
  signal closeRequested()
  signal backRequested()

  property int cardWidth: 420
  property int edgeMargin: 10
  readonly property int pad: 18
  readonly property real maxListHeight: Math.max(150, Math.min(300, (fw.screenHeight - Theme.barOffset) / Theme.windowScale - 320))

  // Solo escanea mientras el panel está abierto
  onOpenChanged: BluetoothBackend.panelWatch = root.open

  FusedWindow {
    id: fw
    active: root.open || panel.shown
    targetScreen: root.targetScreen
    namespace: "oozeshell-bluetooth"
    onCloseRequested: root.closeRequested()

    FusedPanel {
      id: panel

      open: root.open
      panelWidth: root.cardWidth
      contentHeight: col.implicitHeight + root.pad * 2

      // Cuelga de la barra, del lado de su botón (derecha si es horizontal,
      // abajo si es vertical). FusedPanel se coloca solo según Theme.barPosition.
      align: "end"
      alignMargin: root.edgeMargin + Theme.barEdge + Theme.frameSideArm

      ColumnLayout {
        id: col
        x: root.pad
        y: root.pad
        width: parent.width - root.pad * 2
        spacing: 12

        // ── Encabezado: volver, título, refrescar, interruptor ──
        RowLayout {
          Layout.fillWidth: true
          spacing: 10

          SkinRect {
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            radius: 15
            color: backArea.containsMouse ? Theme.surfaceHigh : Theme.surface
            Behavior on color { ColorAnimation { duration: 120 } }

            Text {
              anchors.centerIn: parent
              text: "󰅁"
              color: Theme.text
              font.pixelSize: Theme.fs(16)
              font.family: Theme.monoFamily
            }
            MouseArea {
              id: backArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.backRequested()
            }
          }

          Text {
            text: BluetoothBackend.statusIcon
            color: Theme.primary
            font.pixelSize: Theme.fs(20)
            font.family: Theme.fontFamily
          }

          Text {
            text: Translations.t("btTitle")
            color: Theme.text
            font.bold: true
            font.pixelSize: Theme.fs(16)
            font.family: Theme.fontFamily
          }

          Item { Layout.fillWidth: true }

          // Buscar dispositivos (enciende/apaga el escaneo)
          SkinRect {
            visible: BluetoothBackend.enabled
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            radius: 15
            color: scanArea.containsMouse ? Theme.surfaceHigh : Theme.surface
            Behavior on color { ColorAnimation { duration: 120 } }

            Text {
              anchors.centerIn: parent
              text: "󰑐"
              color: BluetoothBackend.scanning ? Theme.primary : Theme.text
              font.pixelSize: Theme.fs(15)
              font.family: Theme.monoFamily

              RotationAnimation on rotation {
                running: BluetoothBackend.scanning
                from: 0
                to: 360
                duration: 900
                loops: Animation.Infinite
              }
            }
            MouseArea {
              id: scanArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: BluetoothBackend.scanRequested = !BluetoothBackend.scanRequested
            }
          }

          // Interruptor Bluetooth
          SkinRect {
            visible: BluetoothBackend.available
            Layout.preferredWidth: 40
            Layout.preferredHeight: 22
            radius: 11
            color: BluetoothBackend.enabled ? Theme.primary : Theme.surfaceHigh
            Behavior on color { ColorAnimation { duration: 150 } }

            SkinRect {
              width: 16
              height: 16
              radius: 8
              anchors.verticalCenter: parent.verticalCenter
              x: BluetoothBackend.enabled ? 21 : 3
              color: BluetoothBackend.enabled ? Theme.textOnPrimary : Theme.subtext
              Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
              Behavior on color { ColorAnimation { duration: 150 } }
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: BluetoothBackend.setEnabled(!BluetoothBackend.enabled)
            }
          }
        }

        // ── Sin adaptador / apagado / sin dispositivos ───────
        ColumnLayout {
          visible: !BluetoothBackend.available
                   || !BluetoothBackend.enabled
                   || BluetoothBackend.devices.length === 0
          Layout.fillWidth: true
          Layout.topMargin: 10
          Layout.bottomMargin: 10
          spacing: 6

          Text {
            Layout.alignment: Qt.AlignHCenter
            text: (BluetoothBackend.available && BluetoothBackend.enabled) ? "󰂯" : "󰂲"
            color: Theme.subtext
            font.pixelSize: Theme.fs(30)
            font.family: Theme.monoFamily
          }
          Text {
            Layout.alignment: Qt.AlignHCenter
            text: !BluetoothBackend.available
              ? Translations.t("btNoAdapter")
              : (!BluetoothBackend.enabled
                  ? Translations.t("btOff")
                  : (BluetoothBackend.scanning
                      ? Translations.t("btScanning")
                      : Translations.t("btNoDevices")))
            color: Theme.subtext
            font.pixelSize: Theme.fs(11)
            font.family: Theme.fontFamily
          }
        }

        // ── Lista de dispositivos ────────────────────────────
        ListView {
          id: list
          visible: BluetoothBackend.available
                   && BluetoothBackend.enabled
                   && BluetoothBackend.devices.length > 0
          Layout.fillWidth: true
          Layout.preferredHeight: Math.min(contentHeight, root.maxListHeight)
          clip: true
          spacing: 2
          cacheBuffer: 100000
          boundsBehavior: Flickable.StopAtBounds
          interactive: contentHeight > height

          model: ScriptModel {
            values: BluetoothBackend.devices
            objectProp: "address"
          }

          delegate: SkinRect {
            id: row
            required property var modelData

            readonly property bool busy: BluetoothBackend.isBusy(row.modelData)
            readonly property string status: BluetoothBackend.statusText(row.modelData)

            width: ListView.view.width
            height: 48
            radius: 10
            color: row.modelData.connected
              ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16)
              : (rowHover.hovered ? Theme.surface : "transparent")
            Behavior on color { ColorAnimation { duration: 120 } }

            // El hover va aparte del MouseArea: así sigue "encima" del
            // renglón aunque el mouse esté sobre el botón de olvidar
            HoverHandler { id: rowHover }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: BluetoothBackend.activate(row.modelData)
            }

            RowLayout {
              anchors { fill: parent; leftMargin: 12; rightMargin: 10 }
              spacing: 12

              Text {
                text: BluetoothBackend.deviceGlyph(row.modelData.icon)
                color: row.modelData.connected ? Theme.primary : Theme.text
                font.pixelSize: Theme.fs(18)
                font.family: Theme.monoFamily
              }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                  Layout.fillWidth: true
                  text: row.modelData.name
                  color: Theme.text
                  font.bold: row.modelData.connected
                  font.pixelSize: Theme.fs(12)
                  font.family: Theme.fontFamily
                  elide: Text.ElideRight
                }

                Text {
                  visible: row.status !== ""
                  Layout.fillWidth: true
                  text: row.status
                  color: (row.busy || row.modelData.connected) ? Theme.primary : Theme.subtext
                  font.pixelSize: Theme.fs(10)
                  font.family: Theme.fontFamily
                  elide: Text.ElideRight
                }
              }

              // Olvidar (solo emparejados, con el mouse encima)
              SkinRect {
                visible: row.modelData.paired && rowHover.hovered && !row.busy
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                radius: 14
                color: forgetArea.containsMouse ? Theme.surfaceHigh : Theme.bg
                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                  anchors.centerIn: parent
                  text: "󰆴"
                  color: forgetArea.containsMouse ? Theme.error : Theme.subtext
                  font.pixelSize: Theme.fs(14)
                  font.family: Theme.monoFamily
                }
                MouseArea {
                  id: forgetArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: BluetoothBackend.forget(row.modelData)
                }
              }
            }
          }
        }
      }
    }
  }
}
