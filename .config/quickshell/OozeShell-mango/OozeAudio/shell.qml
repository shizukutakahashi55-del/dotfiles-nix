import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "./components"
import "./data"

FloatingWindow {
    id: root

    title: "OozeAudio"

    implicitWidth: 900
    implicitHeight: 700

    minimumSize: Qt.size(700, 500)

    color: "#15151b"

    // =============================================================
    // WINDOW DRAG
    // =============================================================

    MouseArea {
        id: windowDrag

        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }

        height: 70

        acceptedButtons: Qt.LeftButton

        onPressed: {
            root.startSystemMove()
        }
    }

    // =============================================================
    // MAIN LAYOUT
    // =============================================================

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 18

        Header {}

        ConnectionsPanel {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        EditorPanel {
            createDialog: createDialog
        }
    }

    // =============================================================
    // CREATE DIALOG
    // =============================================================

    CreateDialog {
        id: createDialog
    }

    // =============================================================
    // ERROR TOAST
    // =============================================================

    Rectangle {
        id: errorToast

        visible: false
        opacity: 0

        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 24

        radius: 10
        color: "#402525"
        border.color: "#a55"
        border.width: 1

        width: errorText.implicitWidth + 32
        height: errorText.implicitHeight + 20

        Text {
            id: errorText
            anchors.centerIn: parent
            color: "#ffb3b3"
            font.pixelSize: 13
        }

        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }

        Timer {
            id: hideTimer
            interval: 4000
            onTriggered: {
                errorToast.opacity = 0;
                errorToast.visible = false;
            }
        }
    }

    Connections {
        target: AudioService

        function onCommandFailed(message) {
            errorText.text = message;
            errorToast.visible = true;
            errorToast.opacity = 1;
            hideTimer.restart();
        }
    }
}
