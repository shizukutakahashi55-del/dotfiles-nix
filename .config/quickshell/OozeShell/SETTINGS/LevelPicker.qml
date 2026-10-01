// LevelPicker — selector de 5 niveles FIJOS (Pequeño · Mediano · Normal ·
// Grande · Exorbitante). No hay valores intermedios a propósito: cada nivel
// es un preset. Un "resaltador" (color primario) se desliza bajo el activo,
// igual que las pestañas de Audio.
//
// Uso:
//   LevelPicker {
//     level: Theme.barLevel          // -1 = ninguno resaltado ("personalizado")
//     names: ["Pequeño", ...]        // 5 nombres
//     showNames: true                // false = solo "Aa" (versión compacta)
//     onPicked: index => Theme.setLevel("bar", index)
//   }
import QtQuick
import QtQuick.Layouts
import "../COMMON"

SkinRect {
  id: root

  property int level: -1
  property var names: []
  property bool showNames: true
  signal picked(int index)

  Layout.fillWidth: true
  Layout.preferredHeight: root.showNames ? 54 : 36
  radius: 13
  color: Theme.surface

  readonly property real segW: (width - 6) / 5

  // Resaltador
  SkinRect {
    visible: root.level >= 0
    x: 3 + Math.max(0, root.level) * root.segW
    y: 3
    width: root.segW
    height: root.height - 6
    radius: 10
    color: Theme.primary
    Behavior on x { NumberAnimation { duration: Theme.animDuration(180); easing.type: Easing.OutCubic } }
  }

  Row {
    x: 3
    y: 3

    Repeater {
      model: 5

      delegate: Item {
        id: seg
        required property int index

        readonly property bool current: root.level === seg.index

        width: root.segW
        height: root.height - 6

        SkinRect {
          anchors.fill: parent
          radius: 10
          color: Theme.surfaceHigh
          opacity: (segArea.containsMouse && !seg.current) ? 1 : 0
          Behavior on opacity { NumberAnimation { duration: Theme.animDuration(120) } }
        }

        ColumnLayout {
          anchors.centerIn: parent
          spacing: 1

          // "Aa" que crece con el nivel: es la vista previa del tamaño
          Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Aa"
            color: seg.current ? Theme.textOnPrimary : Theme.text
            font.pixelSize: 9 + seg.index * 2
            font.bold: true
            font.family: Theme.fontFamily
            Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
          }

          Text {
            visible: root.showNames
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: seg.width - 6
            horizontalAlignment: Text.AlignHCenter
            text: root.names[seg.index] ?? ""
            color: seg.current ? Theme.textOnPrimary : Theme.subtext
            font.pixelSize: Theme.fs(9)
            font.family: Theme.fontFamily
            // "Exorbitante" es largo: se achica en vez de cortarse
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: 6
            Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
          }
        }

        MouseArea {
          id: segArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.picked(seg.index)
        }
      }
    }
  }
}
