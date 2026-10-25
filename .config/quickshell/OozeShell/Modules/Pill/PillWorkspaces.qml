// PillWorkspaces.qml — PILL

import QtQuick
import "../../COMMON"


WorkspaceDots {
    id: root


    property string screenName: ""

    workspaces: WM.dotsWorkspacesFor(root.screenName)
}
