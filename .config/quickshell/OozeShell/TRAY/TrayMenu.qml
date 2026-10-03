// TrayMenu — menú de un ícono de la bandeja, como popup de la barra.
//
// El host (RightModules) le pasa qué ítem mostrar (trayItem) y dónde
// (anchorX / anchorY, en coordenadas de PANTALLA, centro del ícono): sale
// debajo del ícono si la barra es horizontal, y a su costado si es vertical.
import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import "../COMMON"

Item {
  id: root

  property bool open: false
  property var trayItem: null           // SystemTrayItem
  // Centro del ícono en coords de PANTALLA: anchorX si la barra es horizontal,
  // anchorY si es vertical
  property real anchorX: 0
  property real anchorY: 0
  property string targetScreen: ""
  signal closeRequested()

  property int menuWidth: 250
  // Alto máximo de la lista; si el menú es más largo, scrollea
  property int maxListHeight: 420
  property int edgeMargin: 10
  readonly property int pad: 12
  readonly property int rowHeight: 32

  // Pila de submenús abiertos: vacía = menú raíz del ítem
  property var stack: []
  readonly property var currentEntry: stack.length > 0 ? stack[stack.length - 1] : null
  readonly property var currentHandle: currentEntry ? currentEntry : (trayItem ? trayItem.menu : null)

  // Otro ícono → arrancar siempre desde el menú raíz
  onTrayItemChanged: root.stack = []

  readonly property string title: {
    if (root.currentEntry) return root.currentEntry.text
    const it = root.trayItem
    return it ? (it.tooltipTitle || it.title || it.id || "") : ""
  }

  QsMenuOpener {
    id: opener
    menu: root.currentHandle
  }

  FusedWindow {
    active: root.open || panel.shown
    targetScreen: root.targetScreen
    namespace: "oozeshell-tray"
    onCloseRequested: root.closeRequested()

    FusedPanel {
      id: panel

      open: root.open && root.trayItem !== null
      panelWidth: root.menuWidth
      contentHeight: col.implicitHeight + root.pad * 2

      // Cuelga de la barra (debajo, encima o al costado, según dónde esté) y
      // se centra en el ícono, sin salirse de la pantalla
      align: "center"
      // Modo Píldora: nace de la pastilla propia de Tray/Batería (PILL/PillTray.qml)
      island: Theme.pillMode ? "right" : ""
      alignMargin: root.edgeMargin
      alignCenter: Theme.barVertical ? root.anchorY : root.anchorX
      // Al pasar de un ícono a otro se desliza a lo largo de la barra. Solo en
      // ESE eje: el otro es el que se anima al abrir/cerrar y no hay que suavizarlo.
      // Nunca con el panel en modo isla estirada (hull): ahí `x` es el borde
      // izquierdo de la tarjeta y CAMBIA EN CADA CUADRO mientras se abre (la
      // tarjeta crece hacia la izquierda). Con el Behavior, `x` iba rezagado
      // respecto al ancho (que sí es exacto): el borde derecho se salía de la
      // isla hacia la derecha y, al reiniciarse la animación en cada cuadro, vibraba.
      Behavior on x {
        enabled: panel.shown && !Theme.barVertical && !panel.hull
        NumberAnimation { duration: Theme.animDuration(160); easing.type: Easing.OutCubic }
      }
      Behavior on y {
        enabled: panel.shown && Theme.barVertical
        NumberAnimation { duration: Theme.animDuration(160); easing.type: Easing.OutCubic }
      }

      ColumnLayout {
        id: col
        x: root.pad
        y: root.pad
        width: parent.width - root.pad * 2
        spacing: 8

        // ── Encabezado: [‹] ícono + título ─────────────────────
        RowLayout {
          Layout.fillWidth: true
          spacing: 10

          Rectangle {
            visible: root.stack.length > 0
            Layout.preferredWidth: 26
            Layout.preferredHeight: 26
            radius: 13
            color: backArea.containsMouse ? Theme.surfaceHigh : Theme.surface
            Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }

            Text {
              anchors.centerIn: parent
              text: "󰅁"
              color: Theme.text
              font.pixelSize: Theme.fs(14)
              font.family: Theme.monoFamily
            }
            MouseArea {
              id: backArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.stack = root.stack.slice(0, -1)
            }
          }

          IconImage {
            visible: root.stack.length === 0 && root.trayItem !== null
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20
            asynchronous: true
            source: root.trayItem ? root.trayItem.icon : ""
          }

          Text {
            Layout.fillWidth: true
            text: root.title
            color: Theme.text
            font.bold: true
            font.pixelSize: Theme.fs(13)
            elide: Text.ElideRight
            font.family: Theme.fontFamily
          }
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }

        // ── Lista de entradas ──────────────────────────────────
        Flickable {
          id: flick
          Layout.fillWidth: true
          Layout.preferredHeight: Math.min(list.implicitHeight, root.maxListHeight)
          contentWidth: width
          contentHeight: list.implicitHeight
          clip: true
          boundsBehavior: Flickable.StopAtBounds

          ColumnLayout {
            id: list
            width: flick.width
            spacing: 2

            Repeater {
              model: opener.children

              delegate: Item {
                id: er
                required property var modelData      // QsMenuEntry

                readonly property bool sep: modelData.isSeparator
                readonly property bool checkable:
                  modelData.buttonType !== undefined
                  && modelData.buttonType !== QsMenuButtonType.None

                Layout.fillWidth: true
                Layout.preferredHeight: er.sep ? 9 : root.rowHeight

                // separador
                Rectangle {
                  visible: er.sep
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.leftMargin: 6
                  anchors.rightMargin: 6
                  height: 1
                  color: Theme.divider
                }

                // fila
                Rectangle {
                  visible: !er.sep
                  anchors.fill: parent
                  radius: 10
                  color: (rowArea.containsMouse && er.modelData.enabled) ? Theme.surface : "transparent"
                  Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }

                  RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    // Ranura de 18px: tilde (check/radio) o ícono de la entrada
                    Item {
                      Layout.preferredWidth: 18
                      Layout.preferredHeight: 18

                      Text {
                        anchors.centerIn: parent
                        visible: er.checkable
                        text: er.modelData.checkState === Qt.Checked ? "󰄬" : ""
                        color: Theme.primary
                        font.pixelSize: Theme.fs(14)
                        font.family: Theme.monoFamily
                      }

                      IconImage {
                        anchors.fill: parent
                        visible: !er.checkable && er.modelData.icon !== ""
                        asynchronous: true
                        source: er.modelData.icon
                      }
                    }

                    Text {
                      Layout.fillWidth: true
                      text: er.modelData.text
                      color: er.modelData.enabled ? Theme.text : Theme.subtext
                      font.pixelSize: Theme.fs(12)
                      elide: Text.ElideRight
                      font.family: Theme.fontFamily
                    }

                    Text {
                      visible: er.modelData.hasChildren
                      text: "󰅂"
                      color: Theme.subtext
                      font.pixelSize: Theme.fs(13)
                      font.family: Theme.monoFamily
                    }
                  }

                  MouseArea {
                    id: rowArea
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: er.modelData.enabled
                    cursorShape: Qt.PointingHandCursor

                    onClicked: {
                      if (er.modelData.hasChildren) {
                        root.stack = root.stack.concat([er.modelData])
                      } else {
                        er.modelData.triggered()
                        root.closeRequested()
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
