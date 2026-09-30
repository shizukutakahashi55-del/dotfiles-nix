import QtQuick
import QtQuick.Layouts
import "../COMMON"
import "../LANG"
import "../NOTIFY"

// PillNotifications — ícono de campana de la Pill.
//   clic izquierdo  → abre/cierra el panel Notify existente (Pill.qml
//                      reenvía la señal `clicked()`, igual que antes hacía
//                      CenterModules a través de Bar.qml)
//   clic derecho    → No Molestar, directo en NotificationsBackend
//
// Reutiliza el backend (NOTIFY/NotificationsBackend.qml) tal cual: acá
// solo hay presentación nueva, sin lógica propia.
SkinRect {
    id: root

    signal clicked()
    property bool active: false
    readonly property string tip: Translations.t("notifTitle") + "\n" + Translations.t("notifDndHint")

    Layout.preferredWidth: 36
    Layout.preferredHeight: 30
    radius: 10

    color: (mouse.containsMouse || root.active) ? Theme.surface : "transparent"
    Behavior on color { ColorAnimation { duration: 150 } }

    scale: Theme.cozy ? 1.0 : (mouse.pressed ? 0.84 : mouse.containsMouse ? 1.08 : 1.0)
    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }

    Text {
        anchors.centerIn: parent
        text: NotificationsBackend.dnd ? "󰂛" : (NotificationsBackend.count > 0 ? "󰂚" : "󰂜")
        color: NotificationsBackend.dnd ? Theme.subtext : Theme.text
        font.family: Theme.monoFamily
        font.pixelSize: Theme.fs(16)
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    Rectangle {
        visible: !NotificationsBackend.dnd && NotificationsBackend.count > 0
        width: 6; height: 6; radius: 3
        color: Theme.primary
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 5
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouseEv => {
            if (mouseEv.button === Qt.RightButton) NotificationsBackend.toggleDnd()
            else root.clicked()
        }
    }
}
