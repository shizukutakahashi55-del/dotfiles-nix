import QtQuick
import QtQuick.Layouts
import "../COMMON"
import "../Services/Lang"

ColumnLayout {
  id: nav

  property var categories: []
  property string current: ""
  property bool open: false
  property real maxGridHeight: 360

  signal picked(string id)
  signal stepped(int sign)
  signal toggled()

  readonly property var currentCat: {
    for (const c of nav.categories) if (c.id === nav.current) return c
    return nav.categories.length > 0 ? nav.categories[0] : null
  }

  readonly property var groups: {
    const out = []
    for (const c of nav.categories) {
      const last = out.length > 0 ? out[out.length - 1] : null
      if (last && last.id === c.group) last.items.push(c)
      else out.push({ id: c.group, label: SettingsRegistry.groupLabel(c.group), items: [c] })
    }
    return out
  }

  Layout.fillWidth: true
  spacing: 8

  RowLayout {
    Layout.fillWidth: true
    spacing: 6

    SkinRect {
      id: prevBtn
      Layout.preferredWidth: 36
      Layout.preferredHeight: 40
      radius: Theme.cozy ? 4 : 11
      color: prevArea.containsMouse ? Theme.surfaceHigh : Theme.surface
      Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }
      Text {
        anchors.centerIn: parent
        text: "󰅁"
        color: Theme.text
        font.pixelSize: Theme.sfs(15)
        font.family: Theme.monoFamily
      }
      MouseArea {
        id: prevArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: nav.stepped(-1)
      }
    }

    SkinRect {
      id: mainBtn
      readonly property bool current: true
      Layout.fillWidth: true
      Layout.preferredHeight: 40
      radius: Theme.cozy ? 4 : 11
      color: nav.open ? Theme.primary : (mainArea.containsMouse ? Theme.surfaceHigh : Theme.surface)
      border.width: Theme.bw1
      border.color: nav.open ? Theme.primary : Theme.divider
      Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }

      RowLayout {
        anchors { fill: parent; leftMargin: 12; rightMargin: 10 }
        spacing: 10

        CatIcon {
          Layout.preferredWidth: Theme.sfs(16)
          Layout.alignment: Qt.AlignVCenter
          icon: nav.currentCat ? nav.currentCat.icon : ""
          color: nav.open ? Theme.textOnPrimary : Theme.primary
          size: Theme.sfs(15)
        }
        Text {
          Layout.fillWidth: true
          elide: Text.ElideRight
          text: nav.currentCat ? Translations.t(nav.currentCat.titleKey) : ""
          color: nav.open ? Theme.textOnPrimary : Theme.text
          font.bold: true
          font.pixelSize: Theme.sfs(13)
          font.family: Theme.fontFamily
        }
        Text {
          text: nav.open ? "󰅃" : "󰅀"
          color: nav.open ? Theme.textOnPrimary : Theme.subtext
          font.pixelSize: Theme.sfs(15)
          font.family: Theme.monoFamily
        }
      }

      MouseArea {
        id: mainArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: nav.toggled()
      }
    }

    SkinRect {
      id: nextBtn
      Layout.preferredWidth: 36
      Layout.preferredHeight: 40
      radius: Theme.cozy ? 4 : 11
      color: nextArea.containsMouse ? Theme.surfaceHigh : Theme.surface
      Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }
      Text {
        anchors.centerIn: parent
        text: "󰅂"
        color: Theme.text
        font.pixelSize: Theme.sfs(15)
        font.family: Theme.monoFamily
      }
      MouseArea {
        id: nextArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: nav.stepped(1)
      }
    }
  }

  Flickable {
    id: gridFlick
    Layout.fillWidth: true
    Layout.preferredHeight: nav.open ? Math.min(gridCol.implicitHeight + 4, nav.maxGridHeight) : 0
    visible: Layout.preferredHeight > 0
    contentWidth: width
    contentHeight: gridCol.implicitHeight + 4
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick
    opacity: nav.open ? 1 : 0
    Behavior on Layout.preferredHeight { NumberAnimation { duration: Theme.animDuration(180); easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: Theme.animDuration(140) } }

    ColumnLayout {
      id: gridCol
      width: gridFlick.width
      spacing: 4

      Repeater {
        model: nav.groups

        delegate: ColumnLayout {
          id: groupCol
          required property var modelData
          required property int index

          Layout.fillWidth: true
          spacing: 5

          Text {
            visible: groupCol.modelData.label !== ""
            Layout.fillWidth: true
            Layout.leftMargin: 4
            Layout.topMargin: groupCol.index > 0 ? 6 : 0
            elide: Text.ElideRight
            text: groupCol.modelData.label
            color: Theme.subtext
            font.bold: true
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 1.1
            font.pixelSize: Theme.sfs(9)
            font.family: Theme.fontFamily
          }

          Flow {
            id: tileFlow
            Layout.fillWidth: true
            spacing: 5
            readonly property real tileW: Math.floor((width - spacing) / 2)

            Repeater {
              model: groupCol.modelData.items

              delegate: SkinRect {
                id: tile
                required property var modelData
                readonly property string catIndex: tile.modelData.id
                readonly property bool current: tile.modelData.id === nav.current

                width: tileFlow.tileW
                height: 38
                radius: Theme.cozy ? 4 : 11
                color: tile.current ? Theme.primary : (tileArea.containsMouse ? Theme.surfaceHigh : Theme.surface)
                Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }

                RowLayout {
                  anchors { fill: parent; leftMargin: 10; rightMargin: 8 }
                  spacing: 8

                  CatIcon {
                    Layout.preferredWidth: Theme.sfs(15)
                    Layout.alignment: Qt.AlignVCenter
                    icon: tile.modelData.icon
                    color: tile.current ? Theme.textOnPrimary : Theme.primary
                    size: Theme.sfs(14)
                  }
                  Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: Translations.t(tile.modelData.titleKey)
                    color: tile.current ? Theme.textOnPrimary : Theme.text
                    font.bold: true
                    font.pixelSize: Theme.sfs(11)
                    font.family: Theme.fontFamily
                  }
                }

                MouseArea {
                  id: tileArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: nav.picked(tile.modelData.id)
                }
              }
            }
          }
        }
      }
    }
  }
}
