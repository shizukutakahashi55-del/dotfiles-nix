// WallpapersPage — categoría "Wallpapers":

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import ".."
import "../../COMMON"
import "../../LANG"

SettingsPage {
  id: page
  catId: "wallpapers"


  property string browsing: ""


  component FolderEntry: ColumnLayout {
    id: fe

    property string kind: ""
    property string titleKey: ""
    property string hintKey: ""
    property string defaultPath: ""
    property string current: ""
    property string openKind: ""
    signal chosen(string path)
    signal browseRequested(string kind)

    readonly property bool isOpen: fe.openKind === fe.kind

    Layout.fillWidth: true
    spacing: 8

    SectionLabel { text: Translations.t(fe.titleKey) }

    Text {
      Layout.fillWidth: true
      text: Translations.t(fe.hintKey)
      wrapMode: Text.WordWrap
      color: Theme.subtext
      font.pixelSize: Theme.fs(10)
      font.family: Theme.fontFamily
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: 8

      SkinRect {
        Layout.fillWidth: true
        Layout.preferredHeight: 34
        radius: 10
        color: Theme.surfaceHigh
        border.width: pathInput.activeFocus ? 1 : 0
        border.color: Theme.primary

        TextInput {
          id: pathInput
          anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
          verticalAlignment: TextInput.AlignVCenter
          text: fe.current
          color: Theme.text
          selectionColor: Theme.primary
          selectedTextColor: Theme.textOnPrimary
          font.pixelSize: Theme.fs(12)
          font.family: Theme.fontFamily
          clip: true
          inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhUrlCharactersOnly
          onAccepted: fe.chosen(text)
          onEditingFinished: fe.chosen(text)


          Text {
            visible: pathInput.text === "" && !pathInput.activeFocus
            text: fe.defaultPath
            color: Theme.subtext
            font.pixelSize: Theme.fs(12)
            font.family: Theme.fontFamily
          }
        }
      }

      SettingsBtn {
        icon: "󰉋"
        text: Translations.t("wallsFolderBrowse")
        primary: fe.isOpen
        onClicked: {
          if (fe.isOpen) { fe.browseRequested(""); return }
          fe.browseRequested(fe.kind)
          const cur = fe.current !== "" ? fe.current : fe.defaultPath
          browser.go(cur.replace(/^\$\{?HOME\}?/, browser.home))
        }
      }
      SettingsBtn {
        icon: "󰄬"
        text: Translations.t("lockPathApply")
        onClicked: fe.chosen(pathInput.text)
      }
      SettingsBtn {
        visible: fe.current !== ""
        icon: "󰑐"
        text: Translations.t("wallsFolderReset")
        onClicked: { pathInput.text = ""; fe.chosen("") }
      }
    }


    ImageBrowser {
      id: browser
      visible: fe.isOpen
      allowFolder: true
      Layout.fillWidth: true
      Layout.preferredHeight: fe.isOpen ? 300 : 0
      onFolderPicked: path => { fe.chosen(path); fe.browseRequested("") }
      onPicked: path => { fe.chosen(browser.parentOf(path)); fe.browseRequested("") }
      onCancelled: fe.browseRequested("")
    }
    Text {
      visible: fe.isOpen
      Layout.fillWidth: true
      wrapMode: Text.WordWrap
      text: Translations.t("wallsFolderBrowseHint")
      color: Theme.subtext
      font.pixelSize: Theme.fs(10)
      font.family: Theme.fontFamily
    }
  }


  // ─── Piezas chicas de esta página ──────────────────────────────────

  component SwitchRow: RowLayout {
    id: sw
    property string titleKey: ""
    property string hintKey: ""
    property bool on: false
    signal toggled(bool value)

    Layout.fillWidth: true
    spacing: 12

    ColumnLayout {
      Layout.fillWidth: true
      spacing: 2
      Text {
        Layout.fillWidth: true
        text: Translations.t(sw.titleKey)
        color: Theme.text
        font.pixelSize: Theme.fs(12)
        font.family: Theme.fontFamily
      }
      Text {
        visible: sw.hintKey !== ""
        Layout.fillWidth: true
        text: Translations.t(sw.hintKey)
        wrapMode: Text.WordWrap
        color: Theme.subtext
        font.pixelSize: Theme.fs(10)
        font.family: Theme.fontFamily
      }
    }

    Item {
      Layout.preferredWidth: 34
      Layout.preferredHeight: 20
      Layout.alignment: Qt.AlignTop

      SkinRect {
        anchors.fill: parent
        radius: 10
        color: sw.on ? Theme.primary : Theme.surfaceHigh
        Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }

        SkinRect {
          width: 14; height: 14; radius: 7
          anchors.verticalCenter: parent.verticalCenter
          x: sw.on ? 17 : 3
          color: sw.on ? Theme.textOnPrimary : Theme.subtext
          Behavior on x { NumberAnimation { duration: Theme.animDuration(150); easing.type: Easing.OutCubic } }
          Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
        }
      }
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: sw.toggled(!sw.on)
      }
    }
  }


  component ChipRow: ColumnLayout {
    id: cr
    property string titleKey: ""
    property string hintKey: ""
    property var options: []
    property string current: ""
    property var activeFn: null
    signal picked(string value)

    Layout.fillWidth: true
    spacing: 6

    Text {
      visible: cr.titleKey !== ""
      Layout.fillWidth: true
      text: Translations.t(cr.titleKey)
      color: Theme.text
      font.pixelSize: Theme.fs(12)
      font.family: Theme.fontFamily
    }
    Text {
      visible: cr.hintKey !== ""
      Layout.fillWidth: true
      text: Translations.t(cr.hintKey)
      wrapMode: Text.WordWrap
      color: Theme.subtext
      font.pixelSize: Theme.fs(10)
      font.family: Theme.fontFamily
    }
    Flow {
      Layout.fillWidth: true
      spacing: 8
      Repeater {
        model: cr.options
        delegate: SkinRect {
          id: opt
          required property var modelData
          readonly property bool active: cr.activeFn ? !!cr.activeFn(opt.modelData.value)
                                                      : opt.modelData.value === cr.current
          implicitWidth: optLabel.implicitWidth + 24
          implicitHeight: 30
          radius: 15
          color: opt.active ? Theme.primary
               : (optArea.containsMouse ? Theme.surfaceHigh : Theme.bg)
          border.width: opt.active ? 0 : Theme.bw1
          border.color: Theme.edge
          Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
          Text {
            id: optLabel
            anchors.centerIn: parent
            text: opt.modelData.label
            color: opt.active ? Theme.textOnPrimary : Theme.text
            font.pixelSize: Theme.fs(11)
            font.bold: opt.active
            font.family: Theme.fontFamily
          }
          MouseArea {
            id: optArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: cr.picked(opt.modelData.value)
          }
        }
      }
    }
  }


  component StepRow: RowLayout {
    id: st
    property string titleKey: ""
    property string hintKey: ""
    property int value: 0
    property int min: 0
    property int max: 100
    property int step: 1
    property string suffix: ""
    signal edited(int v)

    Layout.fillWidth: true
    spacing: 12

    ColumnLayout {
      Layout.fillWidth: true
      Layout.minimumWidth: 0

      Layout.alignment: st.hintKey !== "" ? Qt.AlignTop : Qt.AlignVCenter
      spacing: 2
      Text {
        Layout.fillWidth: true
        text: Translations.t(st.titleKey)
        color: Theme.text
        font.pixelSize: Theme.fs(12)
        font.family: Theme.fontFamily
      }
      Text {
        visible: st.hintKey !== ""
        Layout.fillWidth: true
        text: Translations.t(st.hintKey)
        wrapMode: Text.WordWrap
        color: Theme.subtext
        font.pixelSize: Theme.fs(10)
        font.family: Theme.fontFamily
      }
    }
    NumberStepper {


      Layout.fillWidth: false
      Layout.preferredWidth: 150
      Layout.minimumWidth: 130
      Layout.alignment: st.hintKey !== "" ? Qt.AlignTop : Qt.AlignVCenter
      value: st.value; min: st.min; max: st.max; step: st.step; suffix: st.suffix
      onEdited: v => st.edited(v)
    }
  }


  component TextRow: ColumnLayout {
    id: tr
    property string titleKey: ""
    property string hintKey: ""
    property string text: ""
    property string placeholderKey: ""
    property bool secret: false
    signal submitted(string value)

    Layout.fillWidth: true
    spacing: 6

    Text {
      Layout.fillWidth: true
      text: Translations.t(tr.titleKey)
      color: Theme.text
      font.pixelSize: Theme.fs(12)
      font.family: Theme.fontFamily
    }
    Text {
      visible: tr.hintKey !== ""
      Layout.fillWidth: true
      text: Translations.t(tr.hintKey)
      wrapMode: Text.WordWrap
      color: Theme.subtext
      font.pixelSize: Theme.fs(10)
      font.family: Theme.fontFamily
    }
    SkinRect {
      Layout.fillWidth: true
      Layout.preferredHeight: 34
      radius: 10
      color: Theme.surfaceHigh
      border.width: trInput.activeFocus ? 1 : 0
      border.color: Theme.primary

      TextInput {
        id: trInput
        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
        verticalAlignment: TextInput.AlignVCenter
        text: tr.text
        echoMode: tr.secret && !trInput.activeFocus ? TextInput.Password : TextInput.Normal
        color: Theme.text
        selectionColor: Theme.primary
        selectedTextColor: Theme.textOnPrimary
        font.pixelSize: Theme.fs(12)
        font.family: Theme.fontFamily
        clip: true
        inputMethodHints: Qt.ImhNoPredictiveText
        onAccepted: tr.submitted(text)
        onEditingFinished: tr.submitted(text)

        Text {
          visible: trInput.text === "" && !trInput.activeFocus && tr.placeholderKey !== ""
          text: Translations.t(tr.placeholderKey)
          color: Theme.subtext
          font.pixelSize: Theme.fs(12)
          font.family: Theme.fontFamily
        }
      }
    }
  }

  // ─── Herramientas instaladas ───────────────────────────────────────
  ListModel { id: toolsModel }
  Process {
    id: toolsCheck
    command: ["bash", "-c",
      "for t in awww mpvpaper ffmpeg socat curl jq matugen; do " +
      "if command -v \"$t\" >/dev/null 2>&1; then echo \"$t 1\"; else echo \"$t 0\"; fi; done"]
    running: true
    onRunningChanged: if (running) toolsModel.clear()
    stdout: SplitParser {
      onRead: line => {
        const f = line.trim().split(" ")
        if (f.length === 2) toolsModel.append({ "name": f[0], "ok": f[1] === "1" })
      }
    }
  }

  SettingsSection {
    titleKey: "wallsFoldersTitle"
    hintKey: "wallsFoldersHint"
    spacing: 14

    FolderEntry {
      kind: "static"
      titleKey: "wallsFolderStatic"
      hintKey: "wallsFolderStaticHint"
      defaultPath: "~/Pictures/Wallpapers"
      current: Theme.wallpaperDir
      openKind: page.browsing
      onBrowseRequested: kind => page.browsing = kind
      onChosen: path => Theme.setWallpaperDir(path)
    }

    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }

    FolderEntry {
      kind: "live"
      titleKey: "wallsFolderLive"
      hintKey: "wallsFolderLiveHint"
      defaultPath: (Theme.wallpaperDir !== "" ? Theme.wallpaperDir : "~/Pictures/Wallpapers") + "/Live"
      current: Theme.liveWallpaperDir
      openKind: page.browsing
      onBrowseRequested: kind => page.browsing = kind
      onChosen: path => Theme.setLiveWallpaperDir(path)
    }
  }


  // ─── Estáticos (awww) ─────────────────────────────────────────────
  SettingsSection {
    titleKey: "wallsStaticTitle"
    hintKey: "wallsStaticHint"
    spacing: 14

    ChipRow {
      titleKey: "wallsStaticFit"
      hintKey: "wallsStaticFitHint"
      options: [
        { value: "crop",    label: Translations.t("wallsStaticFitCrop") },
        { value: "fit",     label: Translations.t("wallsStaticFitFit") },
        { value: "stretch", label: Translations.t("wallsStaticFitStretch") },
        { value: "no",      label: Translations.t("wallsStaticFitNo") }
      ]
      current: Theme.wallFit
      onPicked: v => Theme.setWallsOpt("wallFit", v)
    }

    TextRow {
      visible: Theme.wallFit === "fit" || Theme.wallFit === "no"
      titleKey: "wallsStaticFill"
      hintKey: "wallsStaticFillHint"
      text: Theme.wallFillColor
      onSubmitted: v => Theme.setWallsOpt("wallFillColor", v)
    }
  }

  // ─── Online ───────────────────────────────────────────────────────
  SettingsSection {
    titleKey: "wallsOnlineTitle"
    hintKey: "wallsOnlineHint"
    spacing: 14

    ChipRow {
      titleKey: "wallsOnlineSource"
      hintKey: "wallsOnlineSourceHint"
      options: [ { value: "wallhaven", label: "Wallhaven" }, { value: "bing", label: "Bing" } ]
      current: Theme.onlineSource
      onPicked: v => Theme.setWallsOpt("onlineSource", v)
    }


    ColumnLayout {
      Layout.fillWidth: true
      spacing: 14
      enabled: Theme.onlineSource === "wallhaven"
      opacity: enabled ? 1 : 0.4
      Behavior on opacity { NumberAnimation { duration: Theme.animDuration(150) } }

      TextRow {
        titleKey: "wallsOnlineQuery"
        hintKey: "wallsOnlineQueryHint"
        placeholderKey: "wallsOnlineQueryPlaceholder"
        text: Theme.onlineQuery
        onSubmitted: v => Theme.setWallsOpt("onlineQuery", v)
      }

      ChipRow {
        titleKey: "wallsOnlineSorting"
        options: [
          { value: "toplist",    label: Translations.t("wallsSortToplist") },
          { value: "hot",        label: Translations.t("wallsSortHot") },
          { value: "random",     label: Translations.t("wallsSortRandom") },
          { value: "date_added", label: Translations.t("wallsSortLatest") },
          { value: "views",      label: Translations.t("wallsSortViews") },
          { value: "relevance",  label: Translations.t("wallsSortRelevance") }
        ]
        current: Theme.onlineSorting
        onPicked: v => Theme.setWallsOpt("onlineSorting", v)
      }


      ChipRow {
        titleKey: "wallsOnlineCats"
        options: [
          { value: "0", label: Translations.t("wallsCatGeneral") },
          { value: "1", label: Translations.t("wallsCatAnime") },
          { value: "2", label: Translations.t("wallsCatPeople") }
        ]
        activeFn: v => Theme.onlineCategories.charAt(parseInt(v)) === "1"
        onPicked: v => {
          const i = parseInt(v)
          const c = Theme.onlineCategories.split("")
          c[i] = c[i] === "1" ? "0" : "1"
          Theme.setWallsOpt("onlineCategories", c.join(""))
        }
      }


      ChipRow {
        titleKey: "wallsOnlinePurity"
        hintKey: "wallsOnlinePurityHint"
        options: [
          { value: "0", label: Translations.t("wallsPuritySfw") },
          { value: "1", label: Translations.t("wallsPuritySketchy") },
          { value: "2", label: Translations.t("wallsPurityNsfw") }
        ]
        activeFn: v => Theme.onlinePurity.charAt(parseInt(v)) === "1"
        onPicked: v => {
          const i = parseInt(v)
          const c = Theme.onlinePurity.split("")
          c[i] = c[i] === "1" ? "0" : "1"
          Theme.setWallsOpt("onlinePurity", c.join(""))
        }
      }

      ChipRow {
        titleKey: "wallsOnlineRes"
        options: [
          { value: "1920x1080", label: "1080p" },
          { value: "2560x1440", label: "1440p" },
          { value: "3840x2160", label: "4K" }
        ]
        current: Theme.onlineMinRes
        onPicked: v => Theme.setWallsOpt("onlineMinRes", v)
      }

      TextRow {
        titleKey: "wallsOnlineApiKey"
        hintKey: "wallsOnlineApiKeyHint"
        secret: true
        text: Theme.onlineApiKey
        onSubmitted: v => Theme.setWallsOpt("onlineApiKey", v)
      }
    }

    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }

    FolderEntry {
      kind: "online"
      titleKey: "wallsOnlineSaveDir"
      hintKey: "wallsOnlineSaveDirHint"
      defaultPath: (Theme.wallpaperDir !== "" ? Theme.wallpaperDir : "~/Pictures/Wallpapers") + "/Online"
      current: Theme.onlineSaveDir
      openKind: page.browsing
      onBrowseRequested: kind => page.browsing = kind
      onChosen: path => Theme.setWallsOpt("onlineSaveDir", path)
    }
  }

  // ─── En vivo ──────────────────────────────────────────────────────
  SettingsSection {
    titleKey: "wallsLiveTitle"
    hintKey: "wallsLiveHint"
    spacing: 14

    SwitchRow {
      titleKey: "wallsLiveOptimize"
      hintKey: "wallsLiveOptimizeHint"
      on: Theme.liveOptimize
      onToggled: v => Theme.setWallsOpt("liveOptimize", v)
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: 14
      enabled: Theme.liveOptimize
      opacity: enabled ? 1 : 0.4
      Behavior on opacity { NumberAnimation { duration: Theme.animDuration(150) } }

      StepRow {
        titleKey: "wallsLiveMaxHeight"
        value: Theme.liveOptMaxHeight
        min: 360; max: 2160; step: 120
        suffix: "p"
        onEdited: v => Theme.setWallsOpt("liveOptMaxHeight", v)
      }
      StepRow {
        titleKey: "wallsLiveMaxFps"
        value: Theme.liveOptMaxFps
        min: 10; max: 60; step: 5
        onEdited: v => Theme.setWallsOpt("liveOptMaxFps", v)
      }
      SwitchRow {
        titleKey: "wallsLiveSwap"
        hintKey: "wallsLiveSwapHint"
        on: Theme.liveOptSwap
        onToggled: v => Theme.setWallsOpt("liveOptSwap", v)
      }
    }

    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }

    SwitchRow {
      titleKey: "wallsLiveStopHidden"
      hintKey: "wallsLiveStopHiddenHint"
      on: Theme.liveStopWhenHidden
      onToggled: v => Theme.setWallsOpt("liveStopWhenHidden", v)
    }

    StepRow {
      titleKey: "wallsLiveRam"
      hintKey: "wallsLiveRamHint"
      value: Theme.liveRamLimitMB
      min: 0; max: 8192; step: 100
      suffix: " MB"
      onEdited: v => Theme.setWallsOpt("liveRamLimitMB", v)
    }

    ChipRow {
      titleKey: "wallsLiveFit"
      hintKey: "wallsLiveFitHint"
      options: [
        { value: "fill", label: Translations.t("wallsFitFill") },
        { value: "fit",  label: Translations.t("wallsFitFit") }
      ]
      current: Theme.liveFit
      onPicked: v => Theme.setWallsOpt("liveFit", v)
    }

    ChipRow {
      titleKey: "wallsLiveLayer"
      hintKey: "wallsLiveLayerHint"
      options: [ { value: "bottom", label: "bottom" }, { value: "background", label: "background" } ]
      current: Theme.liveLayer
      onPicked: v => Theme.setWallsOpt("liveLayer", v)
    }

    ChipRow {
      titleKey: "wallsLiveHwdec"
      hintKey: "wallsLiveHwdecHint"
      options: [
        { value: "auto-safe", label: "auto-safe" },
        { value: "vaapi",     label: "vaapi" },
        { value: "nvdec",     label: "nvdec" },
        { value: "no",        label: "no" }
      ]
      current: Theme.liveHwdec
      onPicked: v => Theme.setWallsOpt("liveHwdec", v)
    }
  }

  // ─── Herramientas ─────────────────────────────────────────────────
  SettingsSection {
    titleKey: "wallsToolsTitle"
    hintKey: "wallsToolsHint"

    Flow {
      Layout.fillWidth: true
      spacing: 8
      Repeater {
        model: toolsModel
        delegate: SkinRect {
          id: tool
          required property string name
          required property bool ok
          implicitWidth: toolLabel.implicitWidth + 24
          implicitHeight: 28
          radius: 14
          color: Theme.bg
          border.width: Theme.bw1
          border.color: tool.ok ? Theme.primary : Theme.error
          Text {
            id: toolLabel
            anchors.centerIn: parent
            text: (tool.ok ? "✓ " : "✗ ") + tool.name
            color: tool.ok ? Theme.text : Theme.error
            font.pixelSize: Theme.fs(11)
            font.family: Theme.fontFamily
          }
        }
      }
    }
  }

  SettingsSection {
    titleKey: "advMatugenTitle"
    hintKey: "advPaletteHint"


    Text {
      Layout.fillWidth: true
      visible: Theme.paletteMode
      text: Translations.t("advPaletteManualHint")
      wrapMode: Text.WordWrap
      color: Theme.primary
      font.pixelSize: Theme.fs(10)
      font.family: Theme.fontFamily
    }

    Flow {
      Layout.fillWidth: true
      spacing: 8
      opacity: Theme.paletteMode ? 0.45 : 1
      Behavior on opacity { NumberAnimation { duration: Theme.animDuration(150) } }

      Repeater {
        model: Theme.schemes
        delegate: SkinRect {
          id: chip
          required property var modelData
          required property int index
          readonly property bool active: index === Theme.defaultSchemeIndex

          implicitWidth: chipLabel.implicitWidth + 24
          implicitHeight: 32
          radius: 16
          color: chip.active ? Theme.primary
               : (chipArea.containsMouse ? Theme.surfaceHigh : Theme.bg)
          border.width: chip.active ? 0 : Theme.bw1
          border.color: Theme.edge
          Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }

          Text {
            id: chipLabel
            anchors.centerIn: parent
            text: chip.modelData.label
            color: chip.active ? Theme.textOnPrimary : Theme.text
            font.pixelSize: Theme.fs(11)
            font.bold: chip.active
            font.family: Theme.fontFamily
          }

          MouseArea {
            id: chipArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Theme.setDefaultSchemeIndex(chip.index)
          }
        }
      }
    }
  }
}
