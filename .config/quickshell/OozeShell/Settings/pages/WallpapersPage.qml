// WallpapersPage — categoría "Wallpapers". Orden de las secciones:

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import ".."
import "../../COMMON"
import "../../Services/Lang"

SettingsPage {
  id: page
  catId: "wallpapers"

  property string browsing: ""

  function toolOk(name) {
    for (let i = 0; i < toolsModel.count; i++)
      if (toolsModel.get(i).name === name) return toolsModel.get(i).ok
    return true
  }

  function toggleBit(str, i) {
    const c = str.split("")
    c[i] = c[i] === "1" ? "0" : "1"
    return c.join("")
  }

  readonly property string defaultRoot: Theme.wallpaperDir !== "" ? Theme.wallpaperDir : "~/Pictures/Wallpapers"

  component FolderEntry: ColumnLayout {
    id: fe

    property string kind: ""
    property string defaultPath: ""
    property string current: ""
    property string openKind: ""
    signal chosen(string path)
    signal browseRequested(string kind)

    readonly property bool isOpen: fe.openKind === fe.kind

    Layout.fillWidth: true
    spacing: 8

    RowLayout {
      Layout.fillWidth: true
      spacing: 8

      SettingsField {
        id: pathField
        placeholder: fe.defaultPath
        value: fe.current
        onSubmitted: text => fe.chosen(text)
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
        visible: fe.current !== ""
        icon: "󰑐"
        text: Translations.t("wallsFolderReset")
        onClicked: fe.chosen("")
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
      font.pixelSize: Theme.sfs(10)
      font.family: Theme.fontFamily
    }
  }

  ListModel { id: toolsModel }
  Process {
    id: toolsCheck
    command: ["bash", "-c",
      "export PATH=\"$HOME/.local/bin:$HOME/.cargo/bin:/run/current-system/sw/bin:$PATH\"; " +
      "for t in awww oozewalls mpvpaper ffmpeg socat curl jq matugen; do " +
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

    SettingsRow {
      titleKey: "wallsFolderStatic"
      stacked: true
      FolderEntry {
        kind: "static"
        defaultPath: "~/Pictures/Wallpapers"
        current: Theme.wallpaperDir
        openKind: page.browsing
        onBrowseRequested: kind => page.browsing = kind
        onChosen: path => Theme.setWallpaperDir(path)
      }
    }

    SettingsRow {
      titleKey: "wallsFolderLive"
      stacked: true
      FolderEntry {
        kind: "live"
        defaultPath: page.defaultRoot + "/Live"
        current: Theme.liveWallpaperDir
        openKind: page.browsing
        onBrowseRequested: kind => page.browsing = kind
        onChosen: path => Theme.setLiveWallpaperDir(path)
      }
    }

    SettingsRow {
      titleKey: "wallsOnlineSaveDir"
      stacked: true
      FolderEntry {
        kind: "online"
        defaultPath: page.defaultRoot + "/Online"
        current: Theme.onlineSaveDir
        openKind: page.browsing
        onBrowseRequested: kind => page.browsing = kind
        onChosen: path => Theme.setWallsOpt("onlineSaveDir", path)
      }
    }
  }

  SettingsSection {
    titleKey: "wallsLayoutTitle"

    SettingsRow {
      titleKey: "wallsLayoutChoice"
      hintKey: "wallsLayoutChoiceHint"
      SettingsChoice {
        model: [
          { value: "normal",      label: Translations.t("wallsLayoutNormal") },
          { value: "compact-top", label: Translations.t("wallsLayoutCompactTop") },
          { value: "fullview",    label: Translations.t("wallsLayoutFullview") },
          { value: "rail",        label: Translations.t("wallsLayoutRail") },
          { value: "list",        label: Translations.t("wallsLayoutList") }
        ]
        current: Theme.wallsLayout
        onPicked: v => Theme.setWallsOpt("wallsLayout", v)
      }
    }

    SettingsRow {
      titleKey: "wallsLayoutSize"
      ScaleSlider {
        Layout.fillWidth: false
        Layout.preferredWidth: 240
        value: Theme.wallsScale
        min: 50
        max: 150
        step: 5
        defaultValue: 100
        onEdited: v => Theme.setWallsOpt(Theme.wallsScaleKey(Theme.wallsLayout), v)
      }
    }

    SettingsRow {
      visible: Theme.wallsLayout === "rail"
      titleKey: "wallsRailSide"
      SettingsChoice {
        model: [
          { value: "left",  label: Translations.t("wallsRailLeft") },
          { value: "right", label: Translations.t("wallsRailRight") }
        ]
        current: Theme.wallsRailSide
        onPicked: v => Theme.setWallsOpt("wallsRailSide", v)
      }
    }
  }

  SettingsSection {
    titleKey: "advMatugenTitle"
    hintKey: "advPaletteHint"

    SettingsNote {
      visible: Theme.paletteMode
      kind: "accent"
      text: Translations.t("advPaletteManualHint")
    }

    SettingsRow {
      stacked: true
      enabled: !Theme.paletteMode
      SettingsChips {
        model: Theme.schemeOrder.map(i => ({ value: i, label: Theme.schemes[i].label }))
        columns: Theme.schemeColumns
        current: Theme.defaultSchemeIndex
        onPicked: v => Theme.setDefaultSchemeIndex(v)
      }
    }
  }

  SettingsSection {
    titleKey: "wallsStaticTitle"

    SettingsRow {
      titleKey: "wallsStaticEngine"
      hintKey: "wallsStaticEngineHint"
      SettingsChoice {
        model: [
          { value: "awww",      label: "awww" },
          { value: "oozewalls", label: "OozeWalls" }
        ]
        current: Theme.wallStaticBackend
        onPicked: v => Theme.setWallsOpt("wallStaticBackend", v)
      }
    }
    SettingsNote {
      visible: !page.toolOk(Theme.wallStaticBackend)
      kind: "error"
      text: "✗ " + Theme.wallStaticBackend + " — " + Translations.t("wallsToolMissing")
    }

    SettingsRow {
      titleKey: "wallsStaticFit"
      SettingsChoice {
        model: [
          { value: "crop",    label: Translations.t("wallsStaticFitCrop") },
          { value: "fit",     label: Translations.t("wallsStaticFitFit") },
          { value: "stretch", label: Translations.t("wallsStaticFitStretch") },
          { value: "no",      label: Translations.t("wallsStaticFitNo") }
        ]
        current: Theme.wallFit
        onPicked: v => Theme.setWallsOpt("wallFit", v)
      }
    }

    SettingsRow {
      visible: Theme.wallStaticBackend === "awww" && (Theme.wallFit === "fit" || Theme.wallFit === "no")
      titleKey: "wallsStaticFill"
      hintKey: "wallsStaticFillHint"
      SettingsField {
        value: Theme.wallFillColor
        mono: true
        onSubmitted: text => Theme.setWallsOpt("wallFillColor", text)
      }
    }
  }

  SettingsSection {
    titleKey: "wallsAnimTitle"

    SettingsRow {
      titleKey: "wallsAnimKind"
      hintKey: "wallsAnimHint"
      stacked: true
      SettingsChips {
        model: [
          { value: "none",        label: Translations.t("wallsAnimNone") },
          { value: "fade",        label: Translations.t("wallsAnimFade") },
          { value: "slide-left",  label: Translations.t("wallsAnimSlideLeft") },
          { value: "slide-right", label: Translations.t("wallsAnimSlideRight") },
          { value: "slide-up",    label: Translations.t("wallsAnimSlideUp") },
          { value: "slide-down",  label: Translations.t("wallsAnimSlideDown") },
          { value: "wipe-left",   label: Translations.t("wallsAnimWipeLeft") },
          { value: "wipe-right",  label: Translations.t("wallsAnimWipeRight") },
          { value: "wipe-up",     label: Translations.t("wallsAnimWipeUp") },
          { value: "wipe-down",   label: Translations.t("wallsAnimWipeDown") },
          { value: "circle",      label: Translations.t("wallsAnimCircle") },
          { value: "zoom",        label: Translations.t("wallsAnimZoom") },
          { value: "blinds",      label: Translations.t("wallsAnimBlinds") },
          { value: "random",      label: Translations.t("wallsAnimRandom") }
        ]
        current: Theme.wallTransition
        onPicked: v => Theme.setWallsOpt("wallTransition", v)
      }
    }

    SettingsRow {
      visible: Theme.wallTransition !== "none"
      titleKey: "wallsAnimDuration"
      NumberStepper {
        Layout.fillWidth: false
        Layout.preferredWidth: 150
        Layout.preferredHeight: 34
        value: Theme.wallTransitionMs
        min: 100; max: 3000; step: 100
        suffix: " ms"
        onEdited: v => Theme.setWallsOpt("wallTransitionMs", v)
      }
    }
  }

  SettingsSection {
    titleKey: "wallsLiveTitle"

    SettingsRow {
      titleKey: "wallsLiveEngine"
      hintKey: "wallsLiveEngineHint"
      SettingsChoice {
        model: [
          { value: "mpvpaper",  label: "mpvpaper" },
          { value: "oozewalls", label: "OozeWalls" }
        ]
        current: Theme.liveBackend
        onPicked: v => Theme.setWallsOpt("liveBackend", v)
      }
    }
    SettingsNote {
      visible: !page.toolOk("mpvpaper")
      kind: "error"
      text: "✗ mpvpaper — " + Translations.t("wallsToolMissing")
    }
    SettingsNote {
      visible: Theme.liveBackend === "oozewalls" && !page.toolOk("oozewalls")
      kind: "error"
      text: "✗ oozewalls — " + Translations.t("wallsToolMissing")
    }

    SettingsRow {
      titleKey: "wallsLiveFit"
      SettingsChoice {
        model: [
          { value: "fill", label: Translations.t("wallsFitFill") },
          { value: "fit",  label: Translations.t("wallsFitFit") }
        ]
        current: Theme.liveFit
        onPicked: v => Theme.setWallsOpt("liveFit", v)
      }
    }

    SettingsRow {
      titleKey: "wallsLiveLayer"
      hintKey: "wallsLiveLayerHint"
      SettingsChoice {
        model: [
          { value: "bottom",     label: "bottom" },
          { value: "background", label: "background" }
        ]
        current: Theme.liveLayer
        onPicked: v => Theme.setWallsOpt("liveLayer", v)
      }
    }

    SettingsRow {
      titleKey: "wallsLiveHwdec"
      hintKey: "wallsLiveHwdecHint"
      SettingsChoice {
        model: [
          { value: "auto-safe", label: "auto-safe" },
          { value: "vaapi",     label: "vaapi" },
          { value: "nvdec",     label: "nvdec" },
          { value: "no",        label: "no" }
        ]
        current: Theme.liveHwdec
        onPicked: v => Theme.setWallsOpt("liveHwdec", v)
      }
    }
  }

  SettingsSection {
    titleKey: "wallsLiveSaveTitle"

    SettingsRow {
      titleKey: "wallsLiveOptimize"
      hintKey: "wallsLiveOptimizeHint"
      SettingsSwitch {
        checked: Theme.liveOptimize
        onToggled: Theme.setWallsOpt("liveOptimize", !Theme.liveOptimize)
      }
    }

    SettingsRow {
      titleKey: "wallsLiveMaxHeight"
      enabled: Theme.liveOptimize
      NumberStepper {
        Layout.fillWidth: false
        Layout.preferredWidth: 150
        Layout.preferredHeight: 34
        value: Theme.liveOptMaxHeight
        min: 360; max: 2160; step: 120
        suffix: "p"
        onEdited: v => Theme.setWallsOpt("liveOptMaxHeight", v)
      }
    }

    SettingsRow {
      titleKey: "wallsLiveMaxFps"
      enabled: Theme.liveOptimize
      NumberStepper {
        Layout.fillWidth: false
        Layout.preferredWidth: 150
        Layout.preferredHeight: 34
        value: Theme.liveOptMaxFps
        min: 10; max: 60; step: 5
        onEdited: v => Theme.setWallsOpt("liveOptMaxFps", v)
      }
    }

    SettingsRow {
      titleKey: "wallsLiveSwap"
      hintKey: "wallsLiveSwapHint"
      enabled: Theme.liveOptimize
      SettingsSwitch {
        checked: Theme.liveOptSwap
        onToggled: Theme.setWallsOpt("liveOptSwap", !Theme.liveOptSwap)
      }
    }

    SettingsRow {
      titleKey: "wallsLiveStopHidden"
      hintKey: "wallsLiveStopHiddenHint"
      SettingsSwitch {
        checked: Theme.liveStopWhenHidden
        onToggled: Theme.setWallsOpt("liveStopWhenHidden", !Theme.liveStopWhenHidden)
      }
    }

    SettingsRow {
      titleKey: "wallsLiveRam"
      hintKey: "wallsLiveRamHint"
      NumberStepper {
        Layout.fillWidth: false
        Layout.preferredWidth: 150
        Layout.preferredHeight: 34
        value: Theme.liveRamLimitMB
        min: 0; max: 8192; step: 100
        suffix: " MB"
        onEdited: v => Theme.setWallsOpt("liveRamLimitMB", v)
      }
    }
  }

  SettingsSection {
    titleKey: "wallsOnlineTitle"
    hintKey: "wallsOnlineHint"

    SettingsRow {
      titleKey: "wallsOnlineSource"
      SettingsChoice {
        model: [
          { value: "wallhaven", label: "Wallhaven" },
          { value: "bing",      label: "Bing" }
        ]
        current: Theme.onlineSource
        onPicked: v => Theme.setWallsOpt("onlineSource", v)
      }
    }

    SettingsRow {
      titleKey: "wallsOnlineQuery"
      hintKey: "wallsOnlineQueryHint"
      enabled: Theme.onlineSource === "wallhaven"
      SettingsField {
        placeholder: Translations.t("wallsOnlineQueryPlaceholder")
        value: Theme.onlineQuery
        onSubmitted: text => Theme.setWallsOpt("onlineQuery", text)
      }
    }

    SettingsRow {
      titleKey: "wallsOnlineSorting"
      stacked: true
      enabled: Theme.onlineSource === "wallhaven"
      SettingsChips {
        model: [
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
    }

    SettingsRow {
      titleKey: "wallsOnlineCats"
      stacked: true
      enabled: Theme.onlineSource === "wallhaven"
      SettingsChips {
        model: [
          { value: 0, label: Translations.t("wallsCatGeneral") },
          { value: 1, label: Translations.t("wallsCatAnime") },
          { value: 2, label: Translations.t("wallsCatPeople") }
        ]
        activeFn: v => Theme.onlineCategories.charAt(v) === "1"
        onPicked: v => Theme.setWallsOpt("onlineCategories", page.toggleBit(Theme.onlineCategories, v))
      }
    }

    SettingsRow {
      titleKey: "wallsOnlineRes"
      enabled: Theme.onlineSource === "wallhaven"
      SettingsChoice {
        model: [
          { value: "any",       label: Translations.t("wallsFilterAll") },
          { value: "1920x1080", label: "1080p" },
          { value: "2560x1440", label: "1440p" },
          { value: "3840x2160", label: "4K" }
        ]
        current: Theme.onlineMinRes
        onPicked: v => Theme.setWallsOpt("onlineMinRes", v)
      }
    }

    SettingsRow {
      titleKey: "wallsOnlinePurity"
      hintKey: "wallsOnlinePurityHint"
      stacked: true
      enabled: Theme.onlineSource === "wallhaven"
      SettingsChips {
        model: [
          { value: 0, label: Translations.t("wallsPuritySfw") },
          { value: 1, label: Translations.t("wallsPuritySketchy") },
          { value: 2, label: Translations.t("wallsPurityNsfw") }
        ]
        activeFn: v => Theme.onlinePurity.charAt(v) === "1"
        onPicked: v => Theme.setWallsOpt("onlinePurity", page.toggleBit(Theme.onlinePurity, v))
      }
    }

    SettingsRow {
      titleKey: "wallsOnlineApiKey"
      hintKey: "wallsOnlineApiKeyHint"
      enabled: Theme.onlineSource === "wallhaven"
      SettingsField {
        secret: true
        value: Theme.onlineApiKey
        onSubmitted: text => Theme.setWallsOpt("onlineApiKey", text)
      }
    }
  }

  SettingsSection {
    titleKey: "wallsOnlineLiveTitle"
    hintKey: "wallsOnlineLiveHint"

    SettingsRow {
      titleKey: "wallsOnlineSource"
      SettingsChoice {
        model: [
          { value: "moewalls",            label: "Moewalls" },
          { value: "wallpaperwaifu",      label: "WallpaperWaifu" }
        ]
        current: Theme.onlineLiveSource
        onPicked: v => Theme.setWallsOpt("onlineLiveSource", v)
      }
    }
  }

  SettingsSection {
    titleKey: "wallsToolsTitle"
    hintKey: "wallsToolsHint"

    SettingsRow {
      stacked: true
      divider: false

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
            radius: Theme.cozy ? 4 : 14
            color: Theme.bg
            border.width: Theme.bw1
            border.color: tool.ok ? Theme.primary : Theme.error
            Text {
              id: toolLabel
              anchors.centerIn: parent
              text: (tool.ok ? "✓ " : "✗ ") + tool.name
              color: tool.ok ? Theme.text : Theme.error
              font.pixelSize: Theme.sfs(11)
              font.family: Theme.fontFamily
            }
          }
        }
      }
    }
  }
}
