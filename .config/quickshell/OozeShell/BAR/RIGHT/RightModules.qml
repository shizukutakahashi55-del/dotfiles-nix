// RightModules — módulos del lado derecho de la barra.

import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

import "../../COMMON"
import "../../LANG"
import "../../AUDIO"
import "../../BATTERY"
import "../../PRIVACY"
import "../../TASKBAR"
import "../../TRAY"

Item {
  id: rightModules


  signal audioButtonClicked()

  signal trayMenuOpened()


  signal menuButtonClicked()


  property bool audioOpen: false
  property bool menuOpen: false
  property bool wallpaperChanging: false

  property bool popupOpen: false


  property real frameArmRight: 0
  property real frameArmBottom: 0

  property var targetScreen
  readonly property string screenName: targetScreen ? targetScreen.name : ""

  // ── Configuración ────────────────────────────────────────────
  property bool hideOnFullscreen: true
  property bool hideOnWallpaperChange: true


  property int rightMargin: 6
  property real scrollStep: 0.05


  property bool showPrivacy: true
  property bool showTaskbar: true
  property bool showTray: true


  property int privacyIconSize: 16
  property int privacyIconSpacing: 6
  property int privacyTransitionMs: 250

  property int taskbarIconSize: 16
  property bool taskbarAllOutputs: false
  property int taskbarMaxItems: 8

  property int trayIconSize: 16


  property bool showBattery: Theme.batteryEnabled


  readonly property string batteryTip: {
    if (!BatteryBackend.available) return ""
    const pct = Math.round(BatteryBackend.percentage * 100) + "%"
    const state = BatteryBackend.fullyCharged ? Translations.t("batteryFull")
                : BatteryBackend.charging     ? Translations.t("batteryCharging")
                                               : Translations.t("batteryDischarging")
    const secs = BatteryBackend.charging ? BatteryBackend.timeToFull : BatteryBackend.timeToEmpty
    const time = BatteryBackend.formatSecs(secs)
    const timeLabel = BatteryBackend.charging ? Translations.t("batteryTimeToFull")
                                               : Translations.t("batteryTimeToEmpty")
    return pct + " — " + state + (time !== "" ? ("\n" + timeLabel + " " + time) : "")
  }

  // ── Barra vertical ───────────────────────────────────────────

  property real centerHeight: 0


  readonly property real extent: Theme.barVertical
    ? rightModules.rightMargin + Math.max(Theme.barEdge, rightModules.frameArmBottom) + pill.height
    : 0


  readonly property int taskbarLimit: {
    if (!Theme.barVertical) return rightModules.taskbarMaxItems
    const screenH = rightModules.targetScreen ? rightModules.targetScreen.height : 1080

    const avail = screenH / 2 - rightModules.centerHeight / 2 - 8
                  - rightModules.rightMargin - Theme.barEdge - 14 * Theme.barScale


    const fixed = 34
                  + (privacy.visible ? privacy.implicitHeight : 0)
                  + (tray.visible ? tray.implicitHeight : 0)
                  + 15
                  + 18
    const cells = Math.floor((avail / Theme.barScale - fixed) / 32)
    return Math.max(1, Math.min(rightModules.taskbarMaxItems, cells))
  }

  readonly property bool suppressed:
    (hideOnFullscreen && FullscreenState.isOn(targetScreen))
    || (hideOnWallpaperChange && wallpaperChanging)

  // ── Modo Islas: publicar dónde está esta isla (coords de pantalla) ──


  readonly property var islandRect: {
    if (!Theme.islandsMode || !targetScreen) return null
    return {
      x: targetScreen.width - rightModules.rightMargin - Math.max(Theme.barEdge, rightModules.frameArmRight) - pill.width,
      y: Theme.barAtBottom ? targetScreen.height - Theme.barEdge - pill.height : Theme.barEdge,
      w: pill.width,
      h: pill.height
    }
  }
  function publishIsland() {
    if (rightModules.screenName === "") return
    if (rightModules.islandRect) IslandState.report(rightModules.screenName, "right", rightModules.islandRect)
    else IslandState.clear(rightModules.screenName, "right")
  }
  onIslandRectChanged: publishIsland()
  Connections {
    target: IslandState
    function onRefreshRequested() { rightModules.publishIsland() }
  }
  Component.onCompleted: publishIsland()

  // ============================================================

  // ============================================================

  property var tipTarget: null
  property real tipCenterX: 0
  property real tipCenterY: 0
  property bool tipShown: false
  property string tipText: ""


  readonly property string liveTip: tipTarget ? String(tipTarget.tip ?? "") : ""
  onLiveTipChanged: { if (liveTip !== "") tipText = liveTip }

  readonly property bool tipAllowed: !popupOpen && !trayMenuOpen && !suppressed
  readonly property bool tipOpen:
    tipShown && tipAllowed && tipTarget !== null && tipTarget.visible && tipText !== ""

  function tipEnter(item) {
    tipHideTimer.stop()
    tipTarget = item
    tipText = liveTip
    const c = item.mapToItem(null, item.width / 2, item.height / 2)
    tipCenterX = c.x
    tipCenterY = c.y
    if (!tipShown) tipShowTimer.restart()
  }


  function tipRefresh() {
    if (!tipTarget) return
    const c = tipTarget.mapToItem(null, tipTarget.width / 2, tipTarget.height / 2)
    tipCenterX = c.x
    tipCenterY = c.y
  }

  Connections {
    target: pill
    function onWidthChanged() { Qt.callLater(rightModules.tipRefresh) }
  }

  function tipLeave(item) {
    if (tipTarget !== item) return
    tipShowTimer.stop()
    tipHideTimer.restart()
  }


  Timer { id: tipShowTimer; interval: 500; repeat: false; onTriggered: rightModules.tipShown = true }

  Timer { id: tipHideTimer; interval: 150; repeat: false; onTriggered: rightModules.tipShown = false }

  // ============================================================

  // ============================================================

  property bool trayMenuOpen: false

  function closeTrayMenu() { trayMenuOpen = false }


  function screenXOf(item) {
    const local = item.mapToItem(null, item.width / 2, 0).x
    return rightPanel.screen.width - rightModules.rightMargin - Theme.barEdge - rightPanel.width + local
  }

  function screenYOf(item) {
    const local = item.mapToItem(null, 0, item.height / 2).y
    return rightPanel.screen.height - rightModules.rightMargin - Theme.barEdge - rightPanel.height + local
  }

  function openTrayMenu(iconItem, entry) {

    if (trayMenuOpen && trayMenu.trayItem === entry) {
      closeTrayMenu()
      return
    }
    tipShown = false
    tipShowTimer.stop()
    rightModules.trayMenuOpened()
    closeTaskbarMenu()
    trayMenu.trayItem = entry
    trayMenu.anchorX = rightModules.screenXOf(iconItem)
    trayMenu.anchorY = rightModules.screenYOf(iconItem)
    trayMenuOpen = true
  }


  onPopupOpenChanged: { if (popupOpen) { closeTrayMenu(); closeTaskbarMenu() } }
  onSuppressedChanged: {
    if (suppressed) {
      closeTrayMenu()
      closeTaskbarMenu()
      tipShown = false
    }
  }

  TrayMenu {
    id: trayMenu
    open: rightModules.trayMenuOpen
    targetScreen: rightModules.screenName
    onCloseRequested: rightModules.closeTrayMenu()
  }

  // ============================================================

  // ============================================================

  property bool taskbarMenuOpen: false

  function closeTaskbarMenu() { taskbarMenuOpen = false }

  function openTaskbarMenu(iconItem) {

    if (taskbarMenuOpen) {
      closeTaskbarMenu()
      return
    }
    tipShown = false
    tipShowTimer.stop()
    rightModules.trayMenuOpened()
    closeTrayMenu()
    taskbarMenu.anchorX = rightModules.screenXOf(iconItem)
    taskbarMenu.anchorY = rightModules.screenYOf(iconItem)
    taskbarMenuOpen = true
  }

  TaskbarMenu {
    id: taskbarMenu
    open: rightModules.taskbarMenuOpen
    windows: taskbar.windows
    targetScreen: rightModules.screenName
    onCloseRequested: rightModules.closeTaskbarMenu()
  }

  // ============================================================

  // ============================================================


  component PillButton: SkinRect {
    id: btn

    property string tip: ""
    property bool active: false

    default property alias content: row.data

    signal clicked(var mouse)
    signal scrolled(var wheel)
    signal hoverEntered()
    signal hoverExited()


    Layout.preferredHeight: Theme.barVertical ? Math.max(30, row.implicitHeight + 12) : 30
    Layout.preferredWidth: Theme.barVertical ? 40 : Math.max(34, row.implicitWidth + 16)

    radius: Theme.cardRadius
    raised: Theme.cozy && (area.containsMouse || btn.active)
    depth: 2

    color: (area.containsMouse || btn.active) ? Theme.surface : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }

    scale: Theme.cozy ? 1.0 : (area.pressed ? 0.90 : (area.containsMouse ? 1.06 : 1.0))
    Behavior on scale { NumberAnimation { duration: Theme.animDuration(160); easing.type: Easing.OutBack } }


    BarFlow {
      id: row
      anchors.centerIn: parent
      gap: Theme.barVertical ? 1 : 6
    }

    MouseArea {
      id: area
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      acceptedButtons: Qt.LeftButton | Qt.RightButton

      onEntered: btn.hoverEntered()
      onExited: btn.hoverExited()
      onClicked: mouse => btn.clicked(mouse)
      onWheel: wheel => btn.scrolled(wheel)
    }
  }


  component Sep: Rectangle {
    Layout.preferredWidth: Theme.barVertical ? 18 : 1
    Layout.preferredHeight: Theme.barVertical ? 1 : 15
    Layout.alignment: Qt.AlignCenter
    radius: 1
    color: Theme.primary
    opacity: 0.25
  }

  // ============================================================

  // ============================================================

  PanelWindow {
    id: rightPanel

    screen: rightModules.targetScreen

    anchors {
      top: !Theme.barAtBottom && !Theme.barVertical
      bottom: Theme.barAtBottom || Theme.barVertical
      right: !Theme.barVertical || Theme.barAtRight
      left: Theme.barVertical && !Theme.barAtRight
    }
    margins.top: Theme.barEdge

    margins.bottom: Theme.barVertical
      ? rightModules.rightMargin + Math.max(Theme.barEdge, rightModules.frameArmBottom)
      : Theme.barEdge

    margins.right: Theme.barVertical ? 0 : rightModules.rightMargin + Math.max(Theme.barEdge, rightModules.frameArmRight)
    margins.left: 0
    Behavior on margins.right { NumberAnimation { duration: Theme.animDuration(200); easing.type: Easing.OutCubic } }
    Behavior on margins.bottom { NumberAnimation { duration: Theme.animDuration(200); easing.type: Easing.OutCubic } }


    implicitWidth: Theme.barVertical
      ? Theme.barThickness + Math.round(340 * Theme.barScale)
      : Math.max(pill.width + 20, Math.round(380 * Theme.barScale))


    implicitHeight: Theme.barVertical
      ? pill.height + Math.round(260 * Theme.barScale)
      : Theme.barHeight + Math.round(260 * Theme.barScale)

    color: "transparent"
    visible: !rightModules.suppressed && !Theme.barRebuilding

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-right-modules"
    exclusiveZone: -1

    mask: Region { item: pill }


    property var glassPanels: []
    BackgroundEffect.blurRegion: GlassRegion {
      panels: rightPanel.glassPanels
      rect: pill
      rectOn: Theme.glassBlurOn && Theme.islandsMode
      rectRadius: Theme.islandRadius
    }

    Item {
      id: pill


      x: (Theme.barVertical && !Theme.barAtRight) ? 0 : parent.width - width


      y: (Theme.barVertical || Theme.barAtBottom) ? parent.height - height : 0

      width: Theme.barVertical ? Theme.barThickness : modulesRow.implicitWidth * Theme.barScale + 14
      height: Theme.barVertical ? modulesRow.implicitHeight * Theme.barScale + 14 : Theme.barHeight

      Rectangle {
        visible: !(Theme.cozy && Theme.islandsMode)
        anchors.fill: parent
        radius: Theme.islandRadius
        color: Theme.islandBg
        border.width: Theme.islandsMode ? Theme.inkWidth : 0
        border.color: Theme.ink
      }

      SkinRect {
        visible: Theme.cozy && Theme.islandsMode
        anchors.fill: parent
        notch: 0
        color: Theme.islandBg
        inkColor: Theme.ink
      }

      BarFlow {
        id: modulesRow


        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        gap: 2
        scale: Theme.barScale

        // ── 1. AUDIO ──────────────────────────────────────────
        PillButton {
          id: audioBtn

          active: rightModules.audioOpen
          tip: Translations.t("audioTip")

          onHoverEntered: rightModules.tipEnter(audioBtn)
          onHoverExited: rightModules.tipLeave(audioBtn)

          onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
              AudioBackend.toggleMuteOsd()
            else
              rightModules.audioButtonClicked()
          }

          onScrolled: wheel => {
            AudioBackend.stepVolume(
              (wheel.angleDelta.y > 0 ? 1 : -1) * rightModules.scrollStep)
          }

          Text {
            Layout.alignment: Qt.AlignHCenter
            text: AudioBackend.icon
            color: AudioBackend.muted ? Theme.subtext : Theme.text
            font.family: Theme.monoFamily
            font.pixelSize: Theme.fs(16)
            Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
          }

          Text {

            visible: !(Theme.barVertical && AudioBackend.muted)
            Layout.alignment: Qt.AlignHCenter
            text: AudioBackend.muted ? Translations.t("audioMuted")
                                      : Math.round(AudioBackend.volume * 100) + "%"
            color: AudioBackend.muted ? Theme.subtext : Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fs(12)
          }
        }

        // ── 2. BATTERY (solo si la máquina tiene batería) ──────
        Sep { visible: rightModules.showBattery && BatteryBackend.available }

        PillButton {
          id: batteryBtn

          visible: rightModules.showBattery && BatteryBackend.available
          tip: rightModules.batteryTip

          onHoverEntered: rightModules.tipEnter(batteryBtn)
          onHoverExited: rightModules.tipLeave(batteryBtn)

          BatteryIcon {
            Layout.alignment: Qt.AlignHCenter
            percentage: BatteryBackend.percentage
            charging: BatteryBackend.charging
            full: BatteryBackend.fullyCharged
            low: BatteryBackend.isLow
            iconHeight: Math.max(10, Theme.fs(12))
          }

          Text {
            Layout.alignment: Qt.AlignHCenter
            text: Math.round(BatteryBackend.percentage * 100) + "%"
            color: BatteryBackend.isLow ? Theme.error : Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fs(12)
          }
        }

        // ── 3. PRIVACY (solo se ve mientras algo usa mic/pantalla) ──
        Sep { visible: rightModules.showPrivacy && privacy.present }

        Privacy {
          id: privacy
          visible: rightModules.showPrivacy && privacy.present
          iconSize: rightModules.privacyIconSize
          iconSpacing: rightModules.privacyIconSpacing
          transitionMs: rightModules.privacyTransitionMs
          onTipEnter: item => rightModules.tipEnter(item)
          onTipLeave: item => rightModules.tipLeave(item)
        }

        // ── 4. TASKBAR ────────────────────────────────────────
        Sep { visible: rightModules.showTaskbar && taskbar.count > 0 }

        Taskbar {
          id: taskbar
          visible: rightModules.showTaskbar && taskbar.count > 0
          targetScreen: rightModules.targetScreen
          iconSize: rightModules.taskbarIconSize
          allOutputs: rightModules.taskbarAllOutputs
          maxItems: rightModules.taskbarLimit

          compact: Theme.taskbarCompact
          onToggleCompact: Theme.setTaskbarCompact(!Theme.taskbarCompact)
          onTipEnter: item => rightModules.tipEnter(item)
          onTipLeave: item => rightModules.tipLeave(item)
          onMenuRequested: item => rightModules.openTaskbarMenu(item)
        }

        // ── 4. TRAY (pegada al botón ❄) ───────────────────────
        Sep { visible: rightModules.showTray && tray.count > 0 }

        Tray {
          id: tray
          visible: rightModules.showTray && tray.count > 0
          iconSize: rightModules.trayIconSize
          renderScale: Theme.barScale
          activeItem: rightModules.trayMenuOpen ? trayMenu.trayItem : null
          onTipEnter: item => rightModules.tipEnter(item)
          onTipLeave: item => rightModules.tipLeave(item)
          onMenuRequested: (iconItem, entry) => rightModules.openTrayMenu(iconItem, entry)
        }

        // ── 5. MENÚ ❄ (integrado al final de la fila) ──────────
        Sep { }

        PillButton {
          id: menuBtn

          active: rightModules.menuOpen
          tip: Translations.t("menuButtonTip")

          onHoverEntered: rightModules.tipEnter(menuBtn)
          onHoverExited: rightModules.tipLeave(menuBtn)
          onClicked: rightModules.menuButtonClicked()


          readonly property string logoFile: {
            if (WM.distro === "arch") return "Arch_Logo/Arch_Linux.svg"
            if (WM.distro === "nixos") return "NixOS_Logo/NixOS.svg"
            return ""
          }

          Image {
            visible: menuBtn.logoFile !== ""
            Layout.alignment: Qt.AlignHCenter
            source: menuBtn.logoFile !== ""
              ? Qt.resolvedUrl("../../assets/logos/" + menuBtn.logoFile) : ""
            sourceSize.width: Theme.fs(19)
            sourceSize.height: Theme.fs(19)
            fillMode: Image.PreserveAspectFit
            asynchronous: true
          }
          Text {
            visible: menuBtn.logoFile === ""
            Layout.alignment: Qt.AlignHCenter
            text: "❄"
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fs(19)
          }
        }
      }
    }

    // ── Tooltip compartido ──────────────────────────────────────


    FusedTip {
      id: tip

      open: rightModules.tipOpen
      text: rightModules.tipText


      maxDepth: Theme.barVertical
        ? parent.height - 8 - 2 * Theme.tipFlare
        : parent.height - Theme.barFace - 6


      // ── Modo Islas ──────────────────────────────────────────────


      z: Theme.islandsMode ? -1 : 0
      island: "right"
      islandRectLocal: Theme.islandsMode
        ? ({ x: pill.x, y: pill.y, w: pill.width, h: pill.height }) : null
      align: "center"
      alignCenter: rightModules.tipCenterX

      x: Theme.barVertical
        ? (Theme.barAtRight ? pill.x - tip.width : Theme.barThickness)
        : (tip.islandActive
            ? tip.placedAlong
            : Math.max(Theme.frameSideArm, Math.min(parent.width - width - Theme.frameSideArm, rightModules.tipCenterX - width / 2)))
      y: Theme.barVertical
        ? Math.max(0, Math.min(parent.height - height, rightModules.tipCenterY - height / 2))
        : (tip.hull ? tip.placedDepth
                    : (Theme.barAtBottom ? pill.y - tip.height : Theme.barHeight))

      Behavior on x {
        enabled: tip.shown && !Theme.barVertical && !tip.hull
        NumberAnimation { duration: Theme.animDuration(160); easing.type: Easing.OutCubic }
      }
      Behavior on y {
        enabled: tip.shown && Theme.barVertical
        NumberAnimation { duration: Theme.animDuration(160); easing.type: Easing.OutCubic }
      }
    }
  }
}
