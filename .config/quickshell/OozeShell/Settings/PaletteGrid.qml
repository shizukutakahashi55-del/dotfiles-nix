import QtQuick
import QtQuick.Layouts
import "../COMMON"
import "../Services/Lang"

ColumnLayout {
  id: pg

  property var model: []
  property var current: null

  signal picked(var value)

  readonly property int cols: pg.width >= 460 ? 3 : 2

  readonly property var groups: {
    const out = []
    for (const m of pg.model) {
      let g = null
      for (const x of out) if (x.id === m.group) { g = x; break }
      if (!g) { g = { id: m.group, items: [] }; out.push(g) }
      g.items.push(m)
    }
    return out
  }

  Layout.fillWidth: true
  spacing: 12

  Repeater {
    model: pg.groups

    delegate: ColumnLayout {
      id: grp
      required property var modelData

      Layout.fillWidth: true
      spacing: 6

      Text {
        Layout.fillWidth: true
        Layout.leftMargin: 2
        elide: Text.ElideRight
        text: Translations.t("advPalGroup_" + grp.modelData.id)
        color: Theme.subtext
        font.bold: true
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 1.1
        font.pixelSize: Theme.sfs(9)
        font.family: Theme.fontFamily
      }

      Flow {
        id: tiles
        Layout.fillWidth: true
        spacing: 6
        readonly property real tileW: Math.floor((width - spacing * (pg.cols - 1)) / pg.cols)

        Repeater {
          model: grp.modelData.items

          delegate: SkinRect {
            id: tile
            required property var modelData

            readonly property bool active: tile.modelData.value === pg.current

            width: tiles.tileW
            height: 36
            radius: Theme.cozy ? 4 : ((tile.active || tileArea.containsMouse) ? height / 2 : MdTokens.rXs + 2)
            color: tile.active ? Theme.primary
                 : (tileArea.containsMouse ? (Theme.cozy ? Theme.surfaceHigh : MdTokens.controlHover)
                                           : (Theme.cozy ? Theme.bg : MdTokens.control))
            border.width: tile.active ? 0 : (Theme.cozy ? Theme.bw1 : 1)
            border.color: Theme.cozy ? Theme.edge : MdTokens.controlEdge
            Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
            Behavior on radius { NumberAnimation { duration: Theme.animDuration(180); easing.type: Easing.OutBack } }

            RowLayout {
              anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
              spacing: 8

              Item {
                Layout.preferredWidth: 22
                Layout.preferredHeight: 14
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                  x: 0
                  width: 14
                  height: 14
                  radius: Theme.cozy ? 0 : 7
                  color: tile.modelData.bg
                  border.width: 1
                  border.color: tile.active ? Theme.textOnPrimary : Theme.edge
                }
                Rectangle {
                  x: 8
                  width: 14
                  height: 14
                  radius: Theme.cozy ? 0 : 7
                  color: tile.modelData.color
                  border.width: 1
                  border.color: tile.active ? Theme.textOnPrimary : Theme.edge
                }
              }

              Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                elide: Text.ElideRight
                text: tile.modelData.label
                color: tile.active ? Theme.textOnPrimary : Theme.text
                font.bold: tile.active
                font.pixelSize: Theme.sfs(11)
                font.family: Theme.fontFamily
              }
            }

            MouseArea {
              id: tileArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: pg.picked(tile.modelData.value)
            }
          }
        }
      }
    }
  }
}
