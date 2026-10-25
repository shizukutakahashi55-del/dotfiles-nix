// ClockFace — cara del reloj según el estilo (la comparten ClockModule de la barra y PillClock de la píldora).

import QtQuick
import QtQuick.Layouts

Loader {
  id: face

  property string clockStyle: "classic"
  property bool vertical: false
  property var now: new Date()

  readonly property bool h24: Theme.barClock24h

  function h12(d) { return d.getHours() % 12 || 12 }
  function pad(n) { return (n < 10 ? "0" : "") + n }
  function hourText(d, padded) { return face.h24 ? face.pad(d.getHours()) : (padded ? face.pad(face.h12(d)) : String(face.h12(d))) }

  function hm(d) { return face.h24 ? Qt.formatTime(d, "HH:mm") : Qt.formatTime(d, "h:mm AP") }

  function timeText(d) {
    if (face.vertical) return face.hourText(d, face.h24) + "\n" + Qt.formatTime(d, "mm")
    return face.hm(d)
  }

  sourceComponent: face.clockStyle === "seconds" ? cSeconds
                 : face.clockStyle === "date"    ? cDate
                 : face.clockStyle === "cards"   ? cCards
                 : face.clockStyle === "analog"  ? cAnalog
                 : cText

  // ─── Estilos ─────────────────────────────────────────────────

  Component {
    id: cText

    Text {
      text: face.timeText(face.now)
      horizontalAlignment: Text.AlignHCenter
      lineHeight: 0.9
      color: Theme.text
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fs(15)
    }
  }

  Component {
    id: cSeconds

    RowLayout {
      spacing: 1

      Text {
        Layout.alignment: Qt.AlignBaseline
        text: face.hourText(face.now, false) + ":" + Qt.formatTime(face.now, "mm")
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fs(15)
      }
      Text {
        Layout.alignment: Qt.AlignBaseline
        text: ":" + Qt.formatTime(face.now, "ss") + (face.h24 ? "" : " " + Qt.formatTime(face.now, "AP"))
        color: Theme.subtext
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fs(10)
      }
    }
  }

  Component {
    id: cDate

    RowLayout {
      spacing: 6

      Text {
        Layout.alignment: Qt.AlignBaseline
        text: Qt.formatDate(face.now, "ddd d MMM")
        color: Theme.primary
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fs(12)
        font.bold: true
      }
      Text {
        Layout.alignment: Qt.AlignBaseline
        text: face.hm(face.now)
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fs(15)
      }
    }
  }

  Component {
    id: cCards

    GridLayout {
      columns: face.vertical ? 1 : (face.h24 ? 2 : 3)
      columnSpacing: 3
      rowSpacing: 2

      Repeater {
        model: ["h", "m"]

        delegate: Rectangle {
          required property string modelData

          implicitWidth: Math.max(26, cardText.implicitWidth + 10)
          implicitHeight: face.vertical ? 18 : 22
          radius: 6
          color: Theme.surfaceHigh

          Text {
            id: cardText
            anchors.centerIn: parent
            text: parent.modelData === "h" ? face.hourText(face.now, true) : face.pad(face.now.getMinutes())
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fs(13)
            font.bold: true
          }
        }
      }

      Text {
        visible: !face.h24 && !face.vertical
        text: Qt.formatTime(face.now, "AP")
        color: Theme.subtext
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fs(10)
        font.bold: true
      }
    }
  }

  Component {
    id: cAnalog

    Item {
      implicitWidth: 24
      implicitHeight: 24

      Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: "transparent"
        border.width: 2
        border.color: Theme.text
      }

      Rectangle {
        x: parent.width / 2 - width / 2
        y: parent.height / 2 - height
        width: 2
        height: parent.height * 0.26
        radius: 1
        color: Theme.text
        transformOrigin: Item.Bottom
        rotation: (face.now.getHours() % 12 + face.now.getMinutes() / 60) * 30
      }

      Rectangle {
        x: parent.width / 2 - width / 2
        y: parent.height / 2 - height
        width: 1.5
        height: parent.height * 0.38
        radius: 1
        color: Theme.primary
        transformOrigin: Item.Bottom
        rotation: (face.now.getMinutes() + face.now.getSeconds() / 60) * 6
      }

      Rectangle {
        anchors.centerIn: parent
        width: 3
        height: 3
        radius: 1.5
        color: Theme.text
      }
    }
  }
}
