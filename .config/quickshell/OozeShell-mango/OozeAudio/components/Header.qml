import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../data"

RowLayout {
    id: root

    Layout.fillWidth: true
    Layout.preferredHeight: 50

    ColumnLayout {
        spacing: 2

        Text {
            text: "OozeAudio"
            color: "white"
            font.pixelSize: 28
            font.bold: true
        }

        Text {
            text: "PipeWire Audio Manager"
            color: "#92929f"
            font.pixelSize: 13
        }
    }

    Item {
        Layout.fillWidth: true
    }

    Button {
        text: AudioService.busy ? "Working…" : "Refresh"
        enabled: !AudioService.busy

        onClicked: {
            AudioService.refreshAll()
        }
    }
}
