// AgendaPopup — el calendario nuevo (AGENDA/AgendaView.qml) como popup de la barra. Se abre con CLIC DERECHO en el reloj (barra clásica e islas); el

import QtQuick
import "../COMMON"
import "../AGENDA"

Item {
  id: root

  property bool open: false
  property string targetScreen: ""
  signal closeRequested()

  property int edgeMargin: 10


  onOpenChanged: if (root.open) view.reset()

  FusedWindow {
    id: fw
    active: root.open || panel.shown
    targetScreen: root.targetScreen
    namespace: "oozeshell-agenda"
    onCloseRequested: root.closeRequested()

    FusedPanel {
      id: panel

      open: root.open
      panelWidth: view.implicitWidth
      contentHeight: view.implicitHeight
      island: "center"

      align: "center"
      alignMargin: root.edgeMargin + Theme.barEdge + Theme.frameSideArm

      AgendaView {
        id: view
        width: panel.panelWidth
        height: panel.contentHeight
        onCloseRequested: root.closeRequested()
      }
    }
  }
}
