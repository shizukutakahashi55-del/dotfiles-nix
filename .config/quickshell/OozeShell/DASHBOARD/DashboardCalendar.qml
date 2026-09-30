import QtQuick
import "../AGENDA"
import "../COMMON"

// DashboardCalendar — sección "Calendario" del Dashboard (modo Píldora):
// mes + día grande al costado, con el ToDo como toggle del panel lateral.
// El contenido es AGENDA/AgendaView.qml, el mismo que abre el clic derecho
// en el reloj en la barra clásica / islas.
Item {
    id: root

    // Dashboard.qml lee estas medidas para dimensionar el dock
    readonly property int preferredWidth: view.implicitWidth
    readonly property int maxWidth: Theme.ds(700)
    readonly property int preferredHeight: view.implicitHeight

    // Esc dentro del campo de nueva tarea → cierra el dock
    signal closeRequested()

    AgendaView {
        id: view
        dash: true
        anchors.fill: parent
        onCloseRequested: root.closeRequested()
    }
}
