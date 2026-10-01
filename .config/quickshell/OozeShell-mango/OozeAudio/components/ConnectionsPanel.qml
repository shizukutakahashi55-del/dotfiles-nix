import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../data"

ColumnLayout {
    id: root

    spacing: 10

    Text {
        text: "CONNECTIONS"
        color: "#b7b7c5"
        font.pixelSize: 12
        font.bold: true
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true

        color: "#1d1d25"
        radius: 16

        ScrollView {
            anchors.fill: parent
            anchors.margins: 16
            clip: true

            ColumnLayout {
                width: parent.width
                spacing: 12

                Repeater {
                    model: AudioService.outputs

                    ConnectionCard {
                        Layout.fillWidth: true

                        outputName: modelData.name
                        outputDesc: modelData.desc

                        destNames: {
                            var out = [];
                            for (var i = 0; i < AudioService.links.length; i++) {
                                var l = AudioService.links[i];
                                if (l.src === modelData.name)
                                    out.push(l.dst);
                            }
                            return out;
                        }
                    }
                }

                Text {
                    visible: AudioService.outputs.length === 0
                    text: "No virtual outputs yet. Create one below."
                    color: "#6b6b78"
                    font.italic: true
                    Layout.topMargin: 12
                }
            }
        }
    }
}
