import QtQuick
import QtQuick.Layouts
import "../COMMON"

// PillWorkspaces — misma lógica que BAR/CENTER/CenterModules.qml (leer
// WM.workspacesFor(), normales primero y especiales después,
// activar con modelData.activate()): layout nuevo, backend de WM de
// siempre, nada propio.
RowLayout {
    id: root
    spacing: Theme.cozy ? 3 : 2

    // Pantalla de esta pastilla ("" = la enfocada). En Mango y Niri cada
    // monitor tiene sus propios workspaces; en Hyprland la lista es global.
    property string screenName: ""
    readonly property var sortedWorkspaces: WM.barWorkspacesFor(root.screenName)

    Repeater {
        model: root.sortedWorkspaces

        delegate: WorkspaceChip {
            required property var modelData

            Layout.preferredWidth: modelData.active ? 27 : 24
            Layout.preferredHeight: 28

            active: modelData.active
            hovered: wsMouse.containsMouse
            pressed: wsMouse.pressed

            Behavior on Layout.preferredWidth {
                NumberAnimation { duration: Theme.animDuration(180); easing.type: Theme.cozy ? Easing.OutCubic : Easing.OutBack }
            }

            scale: Theme.cozy ? 1.0 : (wsMouse.pressed ? 0.82 : wsMouse.containsMouse ? 1.06 : 1.0)
            Behavior on scale { NumberAnimation { duration: Theme.animDuration(140); easing.type: Easing.OutBack } }

            label: {
                if (modelData.urgent) return "♡"

                // CoOzey: números reales para que 1–10 (y cualquier
                // workspace superior) siempre tenga una etiqueta visible.
                if (Theme.cozy) return String(modelData.id)

                // Especiales de Hyprland (id <= 0): un símbolo, sin caja
                if (modelData.id <= 0) return "✦"
                // Resto: número dentro de la cajita (boxText)
                return ""
            }
            boxText: modelData.id > 0 ? String(modelData.id) : ""

            MouseArea {
                id: wsMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: WM.clickWorkspace(modelData)
            }
        }
    }
}
