// MetricCard — cuadro de CPU / RAM / GPU: ícono, etiqueta, valor y gráfico.
import QtQuick
import QtQuick.Layouts
import "../COMMON"

Rectangle {
  id: card

  property string icon: ""
  property string label: ""
  property real value: -1          // 0..100; negativo = N/A
  property string detail: ""
  property var history: []
  property int maxSamples: 30

  implicitHeight: 100
  radius: Theme.cozy ? 0 : Theme.cardRadius
  color: Theme.cozy ? "transparent" : Theme.surface

  // CoOzey: tarjeta de papel pixel
  CozyBox {
    visible: Theme.cozy
    anchors.fill: parent
    anchors.bottomMargin: Theme.shadowY
    notch: 4
    fillTop: Theme.mix(Theme.surface, Theme.primary, 0.14)
    fillBottom: Theme.surface
  }

  ColumnLayout {
    anchors { fill: parent; margins: 10 }
    spacing: 2

    RowLayout {
      Layout.fillWidth: true
      spacing: 5

      Text {
        text: card.icon
        color: Theme.primary
        font.pixelSize: Theme.fs(14)
        font.family: Theme.monoFamily
      }
      Text {
        text: card.label
        color: Theme.subtext
        font.pixelSize: Theme.fs(10)
        font.bold: true
        font.family: Theme.fontFamily
      }
      Item { Layout.fillWidth: true }
      Text {
        visible: card.detail !== ""
        text: card.detail
        color: Theme.subtext
        font.pixelSize: Theme.fs(9)
        font.family: Theme.fontFamily
      }
    }

    Text {
      text: card.value < 0 ? "N/A" : Math.round(card.value) + "%"
      color: Theme.text
      font.pixelSize: Theme.fs(18)
      font.bold: true
      font.family: Theme.fontFamily
    }

    PixelSteps {
      visible: Theme.cozy
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.topMargin: 2
      values: card.history
      maxSamples: card.maxSamples
      color: Theme.primary
      cellH: 3
    }
    Sparkline {
      visible: !Theme.cozy
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.topMargin: 2
      values: card.history
      maxSamples: card.maxSamples
      lineColor: Theme.primary
    }
  }
}
