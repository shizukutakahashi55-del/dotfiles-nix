// FontPicker — selector de la fuente del shell (Ajustes → Apariencia).

import QtQuick
import QtQuick.Layouts
import "../COMMON"
import "../Services/Lang"

ColumnLayout {
  id: root
  spacing: 8

  property string query: ""


  property string hovered: ""

  // ── Modelo ─────────────────────────────────────────────────────

  readonly property var entries: {
    const out = []
    const q = Theme.normFont(root.query)
    const match = (name) => q === "" || Theme.normFont(name).indexOf(q) >= 0

    if (q === "") {
      out.push({ id: "", label: Translations.t("fontAuto"), family: "", suggested: false, special: true })
      if (!Theme.cozy)
        out.push({ id: "mono", label: Translations.t("fontMono"), family: Theme.monoFamily, suggested: false, special: true })
    }

    const used = ({})

    const sugg = Theme.cozy ? Theme.pixelCandidates : Theme.fontSuggestions
    for (let i = 0; i < sugg.length; i++) {
      const r = Theme.resolveFont(sugg[i])
      if (r === "" || used[r] || !match(r)) continue
      used[r] = true
      out.push({ id: r, label: r, family: r, suggested: true, special: false })
    }

    const all = Theme.fontChoices
    for (let i = 0; i < all.length; i++) {
      const f = all[i]
      if (used[f] || !match(f)) continue
      out.push({ id: f, label: f, family: f, suggested: false, special: false })
    }
    return out
  }


  readonly property string currentLabel: Theme.fontPref === "" ? Translations.t("fontAuto")
    : (Theme.fontPref === "mono" ? Translations.t("fontMono") : Theme.fontFamily)
  readonly property string previewFamily: root.hovered !== "" ? root.hovered : Theme.fontFamily

  // ── Cabecera: en uso + releer ──────────────────────────────────
  RowLayout {
    Layout.fillWidth: true
    spacing: 8
    Text {
      Layout.fillWidth: true
      text: Translations.t("fontCurrent") + ":  " + root.currentLabel
      elide: Text.ElideRight
      color: Theme.text
      font.bold: true
      font.pixelSize: Theme.sfs(12)
      font.family: Theme.fontFamily
    }
    SettingsBtn {
      icon: "󰑓"
      text: Translations.t("fontRescan")
      onClicked: Theme.refreshFonts()
    }
  }

  // ── Vista previa ───────────────────────────────────────────────
  SkinRect {
    Layout.fillWidth: true


    Layout.preferredHeight: Math.ceil(Theme.sfs(20) * 1.6 + Theme.sfs(12) * 1.6 * 2 + 2 + 26)
    radius: Theme.cardRadius
    color: Theme.bg
    border.width: Theme.bw1
    border.color: Theme.edge
    clip: true

    ColumnLayout {
      id: prevCol
      anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter
                leftMargin: 12; rightMargin: 12 }
      spacing: 2
      Text {
        Layout.fillWidth: true
        text: "Aa Bb Cc  ñ á é í ó ú"
        elide: Text.ElideRight
        color: Theme.primary
        font.bold: true
        font.pixelSize: Theme.sfs(20)
        font.family: root.previewFamily
      }
      Text {
        Layout.fillWidth: true
        text: Translations.t("fontPreviewText")
        wrapMode: Text.WordWrap
        maximumLineCount: 2
        elide: Text.ElideRight
        color: Theme.text
        font.pixelSize: Theme.sfs(12)
        font.family: root.previewFamily
      }
    }
  }

  // ── Buscador ───────────────────────────────────────────────────
  SkinRect {
    Layout.fillWidth: true
    Layout.preferredHeight: 34
    radius: 12
    color: Theme.surface
    border.width: Theme.bw1
    border.color: fontSearch.activeFocus
      ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.6)
      : Theme.divider
    Behavior on border.color { ColorAnimation { duration: Theme.animDuration(150) } }

    RowLayout {
      anchors { fill: parent; leftMargin: 12; rightMargin: 10 }
      spacing: 8

      Text {
        text: "󰍉"
        color: fontSearch.activeFocus ? Theme.primary : Theme.subtext
        font.pixelSize: Theme.sfs(13)
        font.family: Theme.monoFamily
      }
      TextInput {
        id: fontSearch
        Layout.fillWidth: true
        color: Theme.text
        selectionColor: Theme.primary
        selectedTextColor: Theme.textOnPrimary
        font.pixelSize: Theme.sfs(12)
        font.family: Theme.fontFamily
        clip: true
        selectByMouse: true
        inputMethodHints: Qt.ImhNoPredictiveText
        onTextChanged: root.query = text
        Keys.onEscapePressed: event => {
          if (fontSearch.text !== "") { fontSearch.text = ""; event.accepted = true }
          else event.accepted = false
        }

        Text {
          visible: fontSearch.text === "" && !fontSearch.activeFocus
          text: Translations.t("fontSearch")
          color: Theme.subtext
          font.pixelSize: Theme.sfs(12)
          font.family: Theme.fontFamily
        }
      }
      Text {
        text: root.entries.length + " " + Translations.t("fontCount")
        color: Theme.subtext
        font.pixelSize: Theme.sfs(10)
        font.family: Theme.fontFamily
      }
    }
  }

  // ── Lista ──────────────────────────────────────────────────────
  SkinRect {
    Layout.fillWidth: true
    Layout.preferredHeight: 232
    radius: Theme.cardRadius
    color: Theme.surface
    border.width: Theme.bw1
    border.color: Theme.edge
    clip: true


    HoverHandler {
      onHoveredChanged: if (!hovered) { list.hoverIdx = -1; hoverTimer.stop(); root.hovered = "" }
    }

    ListView {
      id: list
      anchors.fill: parent
      anchors.margins: 6
      model: root.entries
      clip: true
      spacing: 2
      boundsBehavior: Flickable.StopAtBounds
      reuseItems: true
      cacheBuffer: 400


      property int hoverIdx: -1
      onMovingChanged: if (moving) { list.hoverIdx = -1; hoverTimer.stop(); root.hovered = "" }


      Timer {
        id: hoverTimer
        interval: 90
        property string pending: ""
        onTriggered: root.hovered = pending
      }

      delegate: Rectangle {
        id: row
        required property var modelData
        required property int index
        readonly property bool active: row.modelData.id === Theme.fontPref
        readonly property bool hot: list.hoverIdx === row.index
        width: list.width - (scroll.visible ? 8 : 0)
        height: 34
        radius: Theme.cozy ? 3 : 9
        color: row.active ? Theme.primary
             : (row.hot ? Theme.surfaceHigh : "transparent")


        RowLayout {
          anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
          spacing: 8
          Text {
            Layout.fillWidth: true
            text: row.modelData.label
            elide: Text.ElideRight
            color: row.active ? Theme.textOnPrimary : Theme.text
            font.bold: row.active || row.modelData.special
            font.pixelSize: Theme.sfs(13)

            font.family: row.modelData.special ? Theme.fontFamily : row.modelData.family
          }
          Text {
            visible: row.modelData.suggested
            text: Translations.t("fontSuggested")
            color: row.active ? Theme.textOnPrimary : Theme.subtext
            opacity: 0.8
            font.pixelSize: Theme.sfs(9)
            font.family: Theme.fontFamily
          }
          Text {
            visible: row.active
            text: "󰄬"
            color: Theme.textOnPrimary
            font.pixelSize: Theme.sfs(13)
            font.family: Theme.monoFamily
          }
        }

        MouseArea {
          id: rowArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor


          onPositionChanged: {
            if (list.moving || list.hoverIdx === row.index) return
            list.hoverIdx = row.index
            hoverTimer.pending = row.modelData.special && row.modelData.id === "" ? "" : row.modelData.family
            hoverTimer.restart()
          }
          onClicked: Theme.setFontPref(row.modelData.id)
        }
      }


      Rectangle {
        id: scroll
        visible: list.contentHeight > list.height
        x: list.width - width
        width: 4
        radius: 2
        color: Theme.primary
        opacity: 0.55
        height: Math.max(24, list.height * list.height / Math.max(1, list.contentHeight))
        y: list.contentHeight > list.height
           ? (list.height - height) * list.contentY / (list.contentHeight - list.height)
           : 0
      }
    }

    Text {
      anchors.centerIn: parent
      visible: root.entries.length === 0
      text: Translations.t("fontNoResults")
      color: Theme.subtext
      font.pixelSize: Theme.sfs(12)
      font.family: Theme.fontFamily
    }
  }
}
