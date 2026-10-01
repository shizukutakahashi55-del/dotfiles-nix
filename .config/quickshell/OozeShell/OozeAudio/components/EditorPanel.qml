import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../data"

Rectangle {
    id: root

    Layout.fillWidth: true
    height: 210

    color: "#1d1d25"
    radius: 16

    property CreateDialog createDialog

    readonly property var selectedOutput:
        outputCombo.currentIndex >= 0 && AudioService.outputs.length > outputCombo.currentIndex
            ? AudioService.outputs[outputCombo.currentIndex]
            : null

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 12

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "EDITOR"
                color: "#b7b7c5"
                font.pixelSize: 12
                font.bold: true
            }

            Item {
                Layout.fillWidth: true
            }

            Button {
                text: "+ Create Virtual Output"

                onClicked: {
                    if (root.createDialog)
                        root.createDialog.open();
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#30303a"
        }

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "Selected Output"
                color: "#888895"
            }

            ComboBox {
                id: outputCombo

                Layout.fillWidth: true

                model: AudioService.outputs
                textRole: "desc"

                displayText:
                    AudioService.outputs.length === 0
                        ? "No virtual outputs"
                        : currentText
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Text {
                text: "Destinations"
                color: "#888895"
                Layout.alignment: Qt.AlignTop
            }

            Flow {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: AudioService.destinationCandidates()

                    CheckBox {
                        text: "🎧 " + modelData.desc
                        enabled: root.selectedOutput !== null

                        checked:
                            root.selectedOutput !== null &&
                            AudioService.isConnected(root.selectedOutput.name, modelData.name)

                        onToggled: {
                            if (root.selectedOutput === null)
                                return;

                            AudioService.setConnection(
                                root.selectedOutput.name,
                                modelData.name,
                                checked
                            );
                        }
                    }
                }

                Text {
                    visible: AudioService.destinationCandidates().length === 0
                    text: "No destinations found"
                    color: "#6b6b78"
                    font.italic: true
                }
            }
        }
    }
}
