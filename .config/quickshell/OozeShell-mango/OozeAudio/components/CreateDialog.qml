import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../data"

Dialog {
    id: root

    title: "Create Virtual Output"

    anchors.centerIn: Overlay.overlay

    standardButtons: Dialog.Ok | Dialog.Cancel

    contentItem: ColumnLayout {
        spacing: 12

        Text {
            text: "Output name"
            color: "white"
        }

        TextField {
            id: outputName

            Layout.preferredWidth: 300

            placeholderText: "Discord"

            onAccepted: root.accept()
        }
    }

    onOpened: {
        outputName.text = "";
        outputName.forceActiveFocus();
    }

    onAccepted: {
        if (outputName.text.length > 0) {
            AudioService.createOutput(outputName.text);
        }
    }
}
