// WallsPopup — WALLS

import QtQuick
import QtQuick.Layouts
import "../Lang"
import "../../COMMON"

SkinRect {
  id: pop

  required property var walls
  property int fontSize: 12

  readonly property bool isSort: pop.walls.popup === "sort"
  readonly property bool isFilters: pop.walls.popup === "filters"
  readonly property var sortChoices: pop.isSort ? pop.walls.sortChoices() : []

  width: 340
  height: content.implicitHeight + 28
  visible: pop.walls.popup !== ""
  notch: 4
  raised: Theme.cozy
  depth: 3
  inkColor: Theme.primary
  color: Theme.bg
  border.color: Theme.primary
  border.width: 1.5

  component Chip: SkinRect {
    id: chip
    property string text: ""
    property bool on: false
    signal clicked()
    width: chipLabel.implicitWidth + 22
    height: 28
    notch: 3
    raised: Theme.cozy && chip.on
    depth: 2
    inkColor: chip.on ? Theme.primary : Theme.ink
    color: chip.on ? Theme.primary : (chipArea.containsMouse ? Theme.tint(0.16) : Theme.tint(0.08))
    border.color: chip.on ? "#ffffff" : Theme.tint(0.18)
    border.width: Theme.bw1
    Text {
      id: chipLabel
      anchors.centerIn: parent
      text: chip.text
      font.pixelSize: pop.fontSize - 1
      font.family: Theme.fontFamily
      color: chip.on ? Theme.bg : Theme.tint(0.85)
    }
    MouseArea {
      id: chipArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: chip.clicked()
    }
  }

  component Heading: Text {
    font.pixelSize: pop.fontSize - 2
    font.family: Theme.fontFamily
    font.bold: true
    color: Theme.tint(0.55)
    font.capitalization: Font.AllUppercase
  }

  MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

  ColumnLayout {
    id: content
    x: 14
    y: 14
    width: pop.width - 28
    spacing: 10

    // ─── ORDEN ───
    Repeater {
      model: pop.sortChoices
      delegate: Rectangle {
        required property var modelData
        Layout.fillWidth: true
        Layout.preferredHeight: 34
        radius: Theme.cozy ? 0 : 8
        color: rowArea.containsMouse ? Theme.tint(0.14) : (modelData.value === pop.walls.sortCurrent ? Theme.tint(0.08) : "transparent")
        Text {
          anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
          text: modelData.label
          font.pixelSize: pop.fontSize
          font.family: Theme.fontFamily
          color: modelData.value === pop.walls.sortCurrent ? Theme.primary : Theme.tint(0.88)
        }
        Text {
          anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
          visible: modelData.value === pop.walls.sortCurrent
          text: "✓"
          font.pixelSize: pop.fontSize
          color: Theme.primary
        }
        MouseArea {
          id: rowArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: pop.walls.pickSort(modelData.value)
        }
      }
    }

    Text {
      visible: pop.isSort && pop.sortChoices.length === 0
      text: Translations.t("wallsFilterNone")
      font.pixelSize: pop.fontSize
      font.family: Theme.fontFamily
      color: Theme.tint(0.6)
    }

    // ─── FILTROS LOCALES ───
    Heading {
      visible: pop.isFilters && !pop.walls.onlineMode
      text: Translations.t("wallsFilterType")
    }
    Flow {
      visible: pop.isFilters && !pop.walls.onlineMode
      Layout.fillWidth: true
      spacing: 6
      Chip {
        text: Translations.t("wallsFilterAll")
        on: pop.walls.filterExt === ""
        onClicked: pop.walls.filterExt = ""
      }
      Repeater {
        model: pop.walls.availableExts
        delegate: Chip {
          required property string modelData
          text: modelData.toUpperCase()
          on: pop.walls.filterExt === modelData
          onClicked: pop.walls.filterExt = modelData
        }
      }
    }

    // ─── FILTROS ONLINE ───
    Heading {
      visible: pop.isFilters && pop.walls.onlineMode
      text: Translations.t("wallsFilterSource")
    }
    Flow {
      visible: pop.isFilters && pop.walls.onlineMode && !pop.walls.onlineLive
      Layout.fillWidth: true
      spacing: 6
      Chip { text: "Wallhaven"; on: Theme.onlineSource === "wallhaven"; onClicked: Theme.setWallsOpt("onlineSource", "wallhaven") }
      Chip { text: "Bing"; on: Theme.onlineSource === "bing"; onClicked: Theme.setWallsOpt("onlineSource", "bing") }
    }
    Flow {
      visible: pop.isFilters && pop.walls.onlineMode && pop.walls.onlineLive
      Layout.fillWidth: true
      spacing: 6
      Chip { text: "Moewalls"; on: Theme.onlineLiveSource === "moewalls"; onClicked: Theme.setWallsOpt("onlineLiveSource", "moewalls") }
      Chip { text: "WallpaperWaifu"; on: Theme.onlineLiveSource === "wallpaperwaifu"; onClicked: Theme.setWallsOpt("onlineLiveSource", "wallpaperwaifu") }
    }

    Heading {
      visible: pop.isFilters && pop.walls.onlineMode && !pop.walls.onlineLive && Theme.onlineSource === "wallhaven"
      text: Translations.t("wallsOnlineCats")
    }
    Flow {
      visible: pop.isFilters && pop.walls.onlineMode && !pop.walls.onlineLive && Theme.onlineSource === "wallhaven"
      Layout.fillWidth: true
      spacing: 6
      Repeater {
        model: [Translations.t("wallsCatGeneral"), Translations.t("wallsCatAnime"), Translations.t("wallsCatPeople")]
        delegate: Chip {
          required property string modelData
          required property int index
          text: modelData
          on: Theme.onlineCategories.charAt(index) === "1"
          onClicked: Theme.setWallsOpt("onlineCategories", pop.toggleBit(Theme.onlineCategories, index))
        }
      }
    }

    Heading {
      visible: pop.isFilters && pop.walls.onlineMode && !pop.walls.onlineLive && Theme.onlineSource === "wallhaven"
      text: Translations.t("wallsOnlinePurity")
    }
    Flow {
      visible: pop.isFilters && pop.walls.onlineMode && !pop.walls.onlineLive && Theme.onlineSource === "wallhaven"
      Layout.fillWidth: true
      spacing: 6
      Repeater {
        model: [Translations.t("wallsPuritySfw"), Translations.t("wallsPuritySketchy"), Translations.t("wallsPurityNsfw")]
        delegate: Chip {
          required property string modelData
          required property int index
          text: modelData
          on: Theme.onlinePurity.charAt(index) === "1"
          onClicked: Theme.setWallsOpt("onlinePurity", pop.toggleBit(Theme.onlinePurity, index))
        }
      }
    }

    Heading {
      visible: pop.isFilters && pop.walls.onlineMode && !pop.walls.onlineLive && Theme.onlineSource === "wallhaven"
      text: Translations.t("wallsOnlineRes")
    }
    Flow {
      visible: pop.isFilters && pop.walls.onlineMode && !pop.walls.onlineLive && Theme.onlineSource === "wallhaven"
      Layout.fillWidth: true
      spacing: 6
      Repeater {
        model: [ { v: "any", l: Translations.t("wallsFilterAll") }, { v: "1920x1080", l: "1080p" }, { v: "2560x1440", l: "1440p" }, { v: "3840x2160", l: "4K" } ]
        delegate: Chip {
          required property var modelData
          text: modelData.l
          on: Theme.onlineMinRes === modelData.v
          onClicked: Theme.setWallsOpt("onlineMinRes", modelData.v)
        }
      }
    }
  }

  function toggleBit(bits, i) {
    const a = String(bits).split("")
    a[i] = a[i] === "1" ? "0" : "1"
    return a.join("")
  }
}
