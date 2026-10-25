// AppearanceSlider.qml — APPEARANCE

import QtQuick
import "../../COMMON"

Item {
    id: sliderRoot


    // ─────────────────────────────────────────────────────────────

    // ─────────────────────────────────────────────────────────────

    property string label: ""
    property string keyName: ""

    property real minValue: 0
    property real maxValue: 100
    property real stepValue: 1

    property int decimals: 0


    property real value: 0


    property real sliderValue: value


    property bool dragging: false


    property var colors: ({
        accent: "#4a90d9",
        text: "#e1e2e8",
        subtext: "#8e9ab0",
        track: "#232530"
    })


    // ─────────────────────────────────────────────────────────────

    // ─────────────────────────────────────────────────────────────

    signal previewChanged(string key, real value)
    signal committed(string key, real value)


    // ─────────────────────────────────────────────────────────────

    // ─────────────────────────────────────────────────────────────

    implicitHeight: 44


    // ─────────────────────────────────────────────────────────────

    // ─────────────────────────────────────────────────────────────


    onValueChanged: {
        if (!dragging) {
            sliderValue = value
        }
    }


    // ─────────────────────────────────────────────────────────────

    // ─────────────────────────────────────────────────────────────

    function clamp(v) {
        return Math.min(
            maxValue,
            Math.max(minValue, v)
        )
    }


    function snap(v) {
        const stepped =
            Math.round(
                (v - minValue) / stepValue
            ) * stepValue + minValue

        return parseFloat(
            clamp(stepped).toFixed(decimals)
        )
    }


    function keyNudge(dir, t) {
        if (t && t !== dragArea) return false
        setSliderValue(sliderValue + dir * stepValue)
        keyCommit.restart()
        return true
    }
    Timer {
        id: keyCommit
        interval: 350
        onTriggered: sliderRoot.committed(sliderRoot.keyName, sliderRoot.sliderValue)
    }

    function fromX(x) {
        const ratio = Math.min(
            1,
            Math.max(
                0,
                x / track.width
            )
        )

        return snap(
            minValue +
            ratio * (maxValue - minValue)
        )
    }


    // ─────────────────────────────────────────────────────────────

    // ─────────────────────────────────────────────────────────────

    function setSliderValue(v) {
        const newValue = snap(v)

        sliderValue = newValue

        previewChanged(
            keyName,
            newValue
        )
    }


    // ─────────────────────────────────────────────────────────────

    // ─────────────────────────────────────────────────────────────

    Column {
        anchors.fill: parent
        spacing: 5


        // ─────────────────────────────────────────────────────────

        // ─────────────────────────────────────────────────────────

        Row {
            width: parent.width

            Text {
                text: sliderRoot.label

                color: sliderRoot.colors.text

                font.pixelSize: Theme.fs(11)
                font.family: Theme.fontFamily

                width:
                    parent.width
                    - valueBox.implicitWidth
                    - 8

                elide: Text.ElideRight
            }


            Item {
                id: valueBox

                implicitWidth: Math.max(valueText.implicitWidth, valueInput.implicitWidth)
                implicitHeight: Math.max(valueText.implicitHeight, valueInput.implicitHeight)

                property bool editing: false

                Text {
                    id: valueText

                    visible: !valueBox.editing
                    text: sliderRoot.sliderValue.toFixed(sliderRoot.decimals)

                    color: sliderRoot.colors.subtext

                    font.pixelSize: Theme.fs(11)
                    font.family: Theme.fontFamily

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.IBeamCursor
                        onClicked: {
                            valueInput.text = sliderRoot.sliderValue.toFixed(sliderRoot.decimals)
                            valueBox.editing = true
                            valueInput.forceActiveFocus()
                            valueInput.selectAll()
                        }
                    }
                }

                TextInput {
                    id: valueInput

                    visible: valueBox.editing
                    color: sliderRoot.colors.text

                    font.pixelSize: Theme.fs(11)
                    font.family: Theme.fontFamily
                    horizontalAlignment: Text.AlignRight
                    selectByMouse: true
                    inputMethodHints: Qt.ImhFormattedNumbersOnly
                    validator: DoubleValidator {
                        bottom: sliderRoot.minValue
                        top: sliderRoot.maxValue
                        decimals: sliderRoot.decimals
                        notation: DoubleValidator.StandardNotation
                    }

                    function commitTyped() {
                        const parsed = parseFloat(valueInput.text.replace(",", "."))
                        const v = isNaN(parsed) ? sliderRoot.sliderValue : sliderRoot.snap(parsed)
                        sliderRoot.sliderValue = v
                        sliderRoot.previewChanged(sliderRoot.keyName, v)
                        sliderRoot.committed(sliderRoot.keyName, v)
                        valueBox.editing = false
                    }

                    Keys.onReturnPressed: valueInput.commitTyped()
                    Keys.onEnterPressed: valueInput.commitTyped()
                    Keys.onEscapePressed: valueBox.editing = false
                    onActiveFocusChanged: if (!activeFocus && valueBox.editing) valueInput.commitTyped()
                }
            }
        }


        // ─────────────────────────────────────────────────────────

        // ─────────────────────────────────────────────────────────

        Rectangle {
            id: track

            width: parent.width
            height: 6
            radius: 3

            color: sliderRoot.colors.track


            // ─────────────────────────────────────────────────────

            // ─────────────────────────────────────────────────────

            Rectangle {
                id: fill

                anchors.left: parent.left

                height: parent.height
                radius: 3

                color: sliderRoot.colors.accent

                width:
                    track.width *
                    (
                        (sliderRoot.sliderValue - sliderRoot.minValue) /
                        Math.max(
                            0.0001,
                            sliderRoot.maxValue -
                            sliderRoot.minValue
                        )
                    )

                Behavior on width {
                    enabled: !dragArea.pressed

                    NumberAnimation {
                        duration: Theme.animDuration(120)
                    }
                }
            }


            // ─────────────────────────────────────────────────────

            // ─────────────────────────────────────────────────────

            Rectangle {
                id: handle

                width: 14
                height: 14
                radius: 7

                color: "#ffffff"

                border.color:
                    sliderRoot.colors.accent

                border.width: 2

                y:
                    (track.height - height) / 2

                x:
                    Math.max(
                        0,
                        Math.min(
                            track.width - width,
                            fill.width - width / 2
                        )
                    )
            }


            // ─────────────────────────────────────────────────────

            // ─────────────────────────────────────────────────────

            MouseArea {
                id: dragArea

                anchors.fill: parent
                anchors.margins: -8

                cursorShape:
                    Qt.PointingHandCursor


                // ───────────────────────────────────────────────

                // ───────────────────────────────────────────────

                onPressed: mouse => {
                    sliderRoot.dragging = true

                    const v =
                        sliderRoot.fromX(mouse.x)

                    sliderRoot.setSliderValue(v)
                }


                // ───────────────────────────────────────────────

                // ───────────────────────────────────────────────

                onPositionChanged: mouse => {
                    if (!pressed)
                        return

                    const v =
                        sliderRoot.fromX(mouse.x)

                    sliderRoot.setSliderValue(v)
                }


                // ───────────────────────────────────────────────

                // ───────────────────────────────────────────────

                onReleased: mouse => {
                    const v =
                        sliderRoot.fromX(mouse.x)

                    sliderRoot.sliderValue =
                        sliderRoot.snap(v)

                    sliderRoot.dragging = false


                    sliderRoot.committed(
                        sliderRoot.keyName,
                        sliderRoot.sliderValue
                    )
                }


                onCanceled: {
                    sliderRoot.dragging = false


                    sliderRoot.sliderValue =
                        sliderRoot.value
                }
            }
        }
    }
}
