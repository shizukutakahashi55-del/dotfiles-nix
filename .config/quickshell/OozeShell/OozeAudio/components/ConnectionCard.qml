import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../data"

Rectangle {
    id: root

    property string outputName: ""
    property string outputDesc: ""
    property var destNames: []   // array of strings

    width: parent ? parent.width : 0
    height: contentLayout.implicitHeight + 32

    radius: 12
    color: "#25252f"

    RowLayout {
        id: contentLayout

        anchors.fill: parent
        anchors.margins: 16
        spacing: 14

        ColumnLayout {
            Layout.preferredWidth: 220
            Layout.fillWidth: false

            Text {
                text: "🔊 " + root.outputDesc
                color: "white"
                font.pixelSize: 16
                font.bold: true
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: "Virtual Output"
                color: "#8f8f9d"
            }
        }

        Text {
            visible: root.destNames.length > 0
            text: "→"
            color: "#d8a7ff"
            font.pixelSize: 24
        }

        Flow {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: root.destNames

                Rectangle {
                    radius: 8
                    color: "#1d1d25"
                    height: 28
                    width: destLabel.implicitWidth + 16

                    Text {
                        id: destLabel
                        anchors.centerIn: parent
                        text: "🎧 " + modelData
                        color: "white"
                        font.pixelSize: 13
                    }
                }
            }

            Text {
                visible: root.destNames.length === 0
                text: "Not connected to anything"
                color: "#6b6b78"
                font.italic: true
            }
        }

        Button {
            text: "✕"
            flat: true
            ToolTip.text: "Delete virtual output"
            ToolTip.visible: hovered

            onClicked: {
                AudioService.deleteOutput(root.outputDesc)
            }
        }
    }
}
