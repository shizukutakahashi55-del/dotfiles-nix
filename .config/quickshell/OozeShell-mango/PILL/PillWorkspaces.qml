import QtQuick
import QtQuick.Layouts
import "../COMMON"

// PillWorkspaces — misma lógica que BAR/CENTER/CenterModules.qml (leer
// MangoIpc.workspacesFor(), activar con modelData.activate()): layout
// nuevo, backend de Mango (tags).
RowLayout {
    id: root
    spacing: Theme.cozy ? 3 : 2

    // Pantalla de la que se muestran los tags (la pone PillWorkspacesSide)
    property string screenName: ""

    readonly property var sortedWorkspaces: MangoIpc.workspacesFor(root.screenName, false)

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

                if (modelData.active) return "❄"
                switch (modelData.id) {
                    case 1: return "󰎤"
                    case 2: return "󰎧"
                    case 3: return "󰎪"
                    case 4: return "󰎭"
                    case 5: return "󰎱"
                    default: return String(modelData.id)
                }
            }

            MouseArea {
                id: wsMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: modelData.activate()
            }
        }
    }
}
