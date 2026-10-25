// DashboardTile.qml — DASHBOARD

import QtQuick
import QtQuick.Layouts
import "../../COMMON"


Rectangle {
    id: root

    property string icon: ""
    property string title: ""
    property string sub: ""
    property bool lit: false
    property bool selected: false

    signal clicked()
    signal entered()

    readonly property bool hot: mouse.containsMouse || root.selected
    readonly property int sink: (Theme.cozy && mouse.pressed) ? Theme.shadowY : 0

    radius: Theme.cozy ? 0 : MdTokens.rL
    border.width: (root.selected && !Theme.cozy) ? 2 : ((Theme.cozy || root.lit) ? 0 : 1)
    border.color: (root.selected && !Theme.cozy) ? Theme.primary : MdTokens.edgeSoft
    color: Theme.cozy ? "transparent"
         : (root.lit ? (root.hot ? Qt.lighter(Theme.primary, 1.08) : Theme.primary)
                     : (root.hot ? MdTokens.containerHighest : MdTokens.containerHigh))
    Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
    scale: Theme.cozy ? 1.0 : (mouse.pressed ? 0.97 : 1.0)
    Behavior on scale { NumberAnimation { duration: Theme.animDuration(120) } }

    // ── Fondo cozy ──

    CozyBox {
        visible: Theme.cozy
        x: 0
        y: root.sink
        width: parent.width
        height: parent.height - Theme.shadowY
        notch: 4
        shadow: !mouse.pressed
        shadowOffset: Theme.shadowY
        fillTop: Theme.mix(Theme.surface, Theme.primary, root.lit ? 0.66 : (root.hot ? 0.26 : 0.10))
        fillBottom: Theme.mix(Theme.surface, Theme.primary, root.lit ? 0.38 : (root.hot ? 0.08 : 0.0))
    }

    // ── Contenido ──

    ColumnLayout {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: root.sink - Math.round(Theme.shadowY / 2)
        width: parent.width - Theme.ds(10)
        spacing: Theme.ds(3)

        Item {
            Layout.preferredWidth: Theme.ds(32)
            Layout.preferredHeight: Theme.ds(32)
            Layout.alignment: Qt.AlignHCenter

            MdShape {
                visible: !Theme.cozy
                anchors.fill: parent
                shape: root.lit ? "cookie12" : "cookie9"
                color: root.lit ? Qt.alpha(Theme.textOnPrimary, 0.24) : Qt.alpha(Theme.primary, root.hot ? 0.40 : 0.26)
                rotation: root.hot ? 14 : 0
                Behavior on rotation { NumberAnimation { duration: Theme.animDuration(220); easing.type: Easing.OutBack } }
                Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
            }
            Text {
                anchors.centerIn: parent
                text: root.icon
                color: (root.lit && !Theme.cozy) ? Theme.textOnPrimary : Theme.primary
                font.pixelSize: Theme.dfs(16)
                font.family: Theme.monoFamily
            }
        }

        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: root.title
            color: (root.lit && !Theme.cozy) ? Theme.textOnPrimary : Theme.text
            font.pixelSize: Theme.dfs(11)
            font.bold: true
            font.family: Theme.fontFamily
            elide: Text.ElideRight
        }

        Text {
            Layout.fillWidth: true
            visible: root.sub !== ""
            horizontalAlignment: Text.AlignHCenter
            text: root.sub
            color: (root.lit && !Theme.cozy) ? Theme.withAlpha(Theme.textOnPrimary, 0.82) : Theme.mix(Theme.subtext, Theme.text, 0.4)
            font.pixelSize: Theme.dfs(9)
            font.family: Theme.fontFamily
            elide: Text.ElideRight
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.entered()
        onClicked: root.clicked()
    }
}
