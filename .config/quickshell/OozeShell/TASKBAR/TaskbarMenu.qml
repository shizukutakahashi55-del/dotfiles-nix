// TaskbarMenu — drop con la lista de ventanas, como popup de la barra.
//
// Mismo patrón que TRAY/TrayMenu.qml: un FusedPanel que cuelga de la barra
// (mismo color, curvas cóncavas, animación de spawn), dentro de un
// FusedWindow (clic afuera o Esc = cerrar). Se abre al hacer CLIC sobre el
// ícono resumen del taskbar en modo compacto (Taskbar.qml → summary →
// menuRequested); aparece centrado en ese ícono y sigue la posición de la
// barra (debajo/encima si es horizontal, al costado si es vertical) — la
// misma lógica de colocación de FusedPanel/TrayMenu, no algo propio.
//
// El host (RightModules) le pasa la lista de ventanas (windows, Toplevel[])
// y dónde anclar (anchorX / anchorY, en coordenadas de PANTALLA, centro del
// ícono tocado).
//
// Cada fila: ícono de la app + título + punto de "activa"; mismos gestos que
// las píldoras del taskbar expandido — clic activa (y cierra el drop), clic
// del medio cierra la ventana, clic derecho minimiza/trae al frente.
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import "../COMMON"
import "../LANG"

Item {
  id: root

  property bool open: false
  property var windows: []              // lista de Toplevel (la arma Taskbar.qml)
  // Centro del ícono en coords de PANTALLA: anchorX si la barra es horizontal,
  // anchorY si es vertical (igual que TrayMenu)
  property real anchorX: 0
  property real anchorY: 0
  property string targetScreen: ""
  signal closeRequested()

  property int menuWidth: 260
  // Alto máximo de la lista; si hay muchas ventanas, scrollea
  property int maxListHeight: 420
  property int edgeMargin: 10
  readonly property int pad: 12
  readonly property int rowHeight: 34

  // Misma resolución de ícono que Taskbar.qml (ver ahí el porqué del orden
  // de candidatos): Icon= del .desktop, appId tal cual / en minúsculas,
  // último tramo del appId, y por último el genérico del tema.
  readonly property int desktopRevision: DesktopEntries.applications.values.length

  function iconFor(appId) {
    void root.desktopRevision
    const id = appId || ""
    const names = []
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

  // "minimize-raise": la activa se minimiza; cualquier otra sube al frente
  // (mismo gesto que el clic derecho de las píldoras individuales)
  function minimizeRaise(t) {
    if (t.activated && !t.minimized) {
      t.minimized = true
    } else {
      t.minimized = false
      t.activate()
    }
  }

  FusedWindow {
    active: root.open || panel.shown
    targetScreen: root.targetScreen
    namespace: "oozeshell-taskbar"
    onCloseRequested: root.closeRequested()

    FusedPanel {
      id: panel

      open: root.open && root.windows.length > 0
      panelWidth: root.menuWidth
      contentHeight: col.implicitHeight + root.pad * 2

      // Cuelga de la barra (debajo, encima o al costado, según dónde esté) y
      // se centra en el ícono que se tocó, sin salirse de la pantalla
      align: "center"
      alignMargin: root.edgeMargin
      alignCenter: Theme.barVertical ? root.anchorY : root.anchorX

      // Nunca con el panel en modo isla estirada (hull): ahí `x` es el borde
      // izquierdo de la tarjeta y cambia en cada cuadro mientras se abre; con el
      // Behavior se rezagaba del ancho (exacto) y el borde derecho se salía de la
      // isla hacia la derecha, vibrando (ver TrayMenu / FusedTip en RightModules).
      // Pasa con el taskbar plegado: la isla queda más angosta que el menú.
      Behavior on x {
        enabled: panel.shown && !Theme.barVertical && !panel.hull
        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
      }
      Behavior on y {
        enabled: panel.shown && Theme.barVertical
        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
      }

      ColumnLayout {
        id: col
        x: root.pad
        y: root.pad
        width: parent.width - root.pad * 2
        spacing: 8

        // ── Encabezado ──────────────────────────────────────────
        RowLayout {
          Layout.fillWidth: true
          spacing: 10

          Text {
            text: "󰖲"
            color: Theme.primary
            font.pixelSize: Theme.fs(16)
            font.family: Theme.monoFamily
          }

          Text {
            Layout.fillWidth: true
            text: Translations.t("taskbarWindows") + " (" + root.windows.length + ")"
            color: Theme.text
            font.bold: true
            font.pixelSize: Theme.fs(13)
            elide: Text.ElideRight
            font.family: Theme.fontFamily
          }
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }

        // ── Lista de ventanas ───────────────────────────────────
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
              model: root.windows

              delegate: Rectangle {
                id: row
                required property var modelData      // Toplevel

                readonly property string iconSrc: root.iconFor(modelData ? modelData.appId : "")

                Layout.fillWidth: true
                Layout.preferredHeight: root.rowHeight
                radius: 10
                color: (rowArea.containsMouse || row.modelData.activated) ? Theme.surface : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }

                RowLayout {
                  anchors.fill: parent
                  anchors.leftMargin: 10
                  anchors.rightMargin: 10
                  spacing: 10

                  Item {
                    Layout.preferredWidth: 18
                    Layout.preferredHeight: 18

                    IconImage {
                      anchors.fill: parent
                      visible: row.iconSrc !== ""
                      source: row.iconSrc
                      opacity: row.modelData.minimized ? 0.45 : 1.0
                    }

                    // Sin ícono resoluble: glifo neutro (mismo que Taskbar.qml)
                    Text {
                      anchors.centerIn: parent
                      visible: row.iconSrc === ""
                      text: "󰀻"
                      color: Theme.subtext
                      font.pixelSize: Theme.fs(14)
                      font.family: Theme.monoFamily
                      opacity: row.modelData.minimized ? 0.45 : 1.0
                    }
                  }

                  Text {
                    Layout.fillWidth: true
                    text: row.modelData.title || row.modelData.appId
                    color: row.modelData.minimized ? Theme.subtext : Theme.text
                    font.pixelSize: Theme.fs(12)
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                  }

                  // Punto de "esta es la ventana activa"
                  Rectangle {
                    visible: row.modelData.activated
                    Layout.preferredWidth: 6
                    Layout.preferredHeight: 6
                    radius: 3
                    color: Theme.primary
                  }
                }

                MouseArea {
                  id: rowArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

                  onClicked: mouse => {
                    const t = row.modelData
                    if (mouse.button === Qt.MiddleButton) {
                      t.close()
                    } else if (mouse.button === Qt.RightButton) {
                      root.minimizeRaise(t)
                    } else {
                      if (t.minimized) t.minimized = false
                      t.activate()
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
