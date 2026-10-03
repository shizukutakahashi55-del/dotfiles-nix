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

  // Clic en el botón de audio: shell.qml abre/cierra el panel AudioMenu
  signal audioButtonClicked()
  // Se abrió el menú de un ícono de la bandeja: shell.qml cierra los demás popups
  signal trayMenuOpened()
  // Modo Islas: el botón ❄ vive al final de esta isla (shell.qml abre/cierra Menu)
  signal menuButtonClicked()

  // Los setea Bar.qml
  property bool audioOpen: false
  property bool menuOpen: false
  property bool wallpaperChanging: false
  // Hay algún popup de shell.qml abierto (menu/notify/network/audio/mpris)
  property bool popupOpen: false

  // Marco curvo 
  property real frameArmRight: 0
  property real frameArmBottom: 0

  property var targetScreen
  readonly property string screenName: targetScreen ? targetScreen.name : ""

  // ── Configuración ────────────────────────────────────────────
  property bool hideOnFullscreen: true
  property bool hideOnWallpaperChange: true
  // Distancia al borde derecho: deja libre el botón ❄ + un respiro.
  // Modo Islas: el ❄ está adentro de la isla, así que solo queda un respiro.
  property int rightMargin: Theme.islandsMode ? 6 : Theme.menuButtonWidth + Theme.rightGap
  property real scrollStep: 0.05

  // Encender/apagar módulos (un módulo apagado no ocupa lugar)
  property bool showPrivacy: true
  property bool showTaskbar: true
  property bool showTray: true

  // Waybar: "privacy" → icon-size / icon-spacing / transition-duration
  property int privacyIconSize: 16
  property int privacyIconSpacing: 6
  property int privacyTransitionMs: 250
  // Waybar: "wlr/taskbar" → icon-size / all-outputs
  property int taskbarIconSize: 16
  property bool taskbarAllOutputs: false
  property int taskbarMaxItems: 8
  // Waybar: "tray" → icon-size
  property int trayIconSize: 18

  // Waybar: no tiene equivalente directo (venía de swayosd) — módulo nuevo
  property bool showBattery: Theme.batteryEnabled

  // Texto del tooltip de batería: "62% — Cargando · Falta 1h 20m"
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

  // Hasta dónde llega este bloque desde el borde de ABAJO (incluye el botón
  // ❄ y su respiro). Bar.qml se lo pasa al módulo central para no pisarlo.
  readonly property real extent: Theme.barVertical
    ? rightModules.rightMargin + Math.max(Theme.barEdge, rightModules.frameArmBottom) + pill.height
    : 0

  // Cuántas ventanas muestra el taskbar. En horizontal, el máximo de siempre.
  // En vertical, las que entren entre el borde de abajo y el bloque central.
 
  readonly property int taskbarLimit: {
    if (!Theme.barVertical) return rightModules.taskbarMaxItems
    const screenH = rightModules.targetScreen ? rightModules.targetScreen.height : 1080
    // Alto disponible (px reales) para todo este bloque, sin ❄ ni respiro
    const avail = screenH / 2 - rightModules.centerHeight / 2 - 8
                  - rightModules.rightMargin - Theme.barEdge - 14 * Theme.barScale
    // Lo que ocupan los otros grupos (px lógicos): audio + privacy + tray +
    // separadores (~5 c/u con su gap) + el mini botón de plegar del taskbar
    // (16 + gap 2)
    const fixed = 34
                  + (privacy.visible ? privacy.implicitHeight : 0)
                  + (tray.visible ? tray.implicitHeight : 0)
                  + 15
                  + 18
    const cells = Math.floor((avail / Theme.barScale - fixed) / 32)   // 30 + gap 2
    return Math.max(1, Math.min(rightModules.taskbarMaxItems, cells))
  }

  readonly property bool suppressed:
    (hideOnFullscreen && FullscreenState.isOn(targetScreen))
    || (hideOnWallpaperChange && wallpaperChanging)

  // ── Modo Islas: publicar dónde está esta isla (coords de pantalla) ──
  // FusedPanel lo lee (IslandState) para saber de dónde nace cada popup.
  // La ventana está anclada a la derecha y la píldora pegada a su borde.
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
  // TOOLTIP COMPARTIDO (FusedTip)
  // ============================================================

  property var tipTarget: null      // Item que está bajo el mouse
  property real tipCenterX: 0       // su centro, en coords de esta ventana
  property real tipCenterY: 0       // (X si la barra es horizontal, Y si es vertical)
  property bool tipShown: false     // pasó el retardo y sigue encima
  property string tipText: ""       // último texto no vacío (para la animación de cierre)

  // Texto en vivo: si el título de una ventana cambia con el mouse encima,
  // el tooltip lo sigue
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

  // Si la isla cambia de tamaño con el tooltip armado (plegar el taskbar,
  // abrirse/cerrarse una ventana, entrar un ícono a la bandeja…) los botones se
  // corren —esta isla crece hacia la izquierda—: se vuelve a medir el centro
  // del botón, si no el tooltip queda donde estaba.
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

  // Retardo de aparición (como el `delay: 600` de los ToolTip de antes)
  Timer { id: tipShowTimer; interval: 500; repeat: false; onTriggered: rightModules.tipShown = true }
  // Colchón al cruzar de un botón a otro: si entra otro antes, no se cierra
  Timer { id: tipHideTimer; interval: 150; repeat: false; onTriggered: rightModules.tipShown = false }

  // ============================================================
  // MENÚ DE LA BANDEJA
  // ============================================================

  property bool trayMenuOpen: false

  function closeTrayMenu() { trayMenuOpen = false }

  // Centro de un ítem en coordenadas de PANTALLA. Horizontal: esta ventana
  // está anclada a la derecha, así que su x en pantalla es: ancho - margen -
  // su ancho. Vertical: está anclada abajo (dejando libre el botón ❄), así que
  // su y en pantalla es: alto - margen - su alto.
  function screenXOf(item) {
    const local = item.mapToItem(null, item.width / 2, 0).x
    return rightPanel.screen.width - rightModules.rightMargin - Theme.barEdge - rightPanel.width + local
  }

  function screenYOf(item) {
    const local = item.mapToItem(null, 0, item.height / 2).y
    return rightPanel.screen.height - rightModules.rightMargin - Theme.barEdge - rightPanel.height + local
  }

  function openTrayMenu(iconItem, entry) {
    // Segundo clic sobre el mismo ícono = cerrar
    if (trayMenuOpen && trayMenu.trayItem === entry) {
      closeTrayMenu()
      return
    }
    tipShown = false
    tipShowTimer.stop()
    rightModules.trayMenuOpened()          // shell.qml cierra los demás popups
    closeTaskbarMenu()                     // exclusivo con el drop del taskbar
    trayMenu.trayItem = entry
    trayMenu.anchorX = rightModules.screenXOf(iconItem)
    trayMenu.anchorY = rightModules.screenYOf(iconItem)
    trayMenuOpen = true
  }

  // Se abrió otro popup, o se ocultó la barra → cerrar el menú
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
  // DROP DEL TASKBAR (ícono resumen, modo compacto)
  // ============================================================

  property bool taskbarMenuOpen: false

  function closeTaskbarMenu() { taskbarMenuOpen = false }

  function openTaskbarMenu(iconItem) {
    // Segundo clic sobre el mismo ícono = cerrar
    if (taskbarMenuOpen) {
      closeTaskbarMenu()
      return
    }
    tipShown = false
    tipShowTimer.stop()
    rightModules.trayMenuOpened()          // mismo aviso: shell.qml cierra los demás popups
    closeTrayMenu()                        // exclusivo con el menú de la bandeja
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
  // BOTÓN REUTILIZABLE (mismo look que LeftModules/CenterModules)
  // ============================================================
  // Sin ToolTip propio: emite hoverEntered/hoverExited y el host muestra
  // el tooltip compartido usando la propiedad `tip`.

  component PillButton: SkinRect {
    id: btn

    property string tip: ""
    property bool active: false

    default property alias content: row.data

    signal clicked(var mouse)
    signal scrolled(var wheel)
    signal hoverEntered()
    signal hoverExited()

    // Horizontal: 30 de alto y el ancho del contenido. Vertical: 40 de ancho
    // (la barra mide 44) y el alto del contenido apilado.
    Layout.preferredHeight: Theme.barVertical ? Math.max(30, row.implicitHeight + 12) : 30
    Layout.preferredWidth: Theme.barVertical ? 40 : Math.max(34, row.implicitWidth + 16)

    radius: Theme.cardRadius
    raised: Theme.cozy && (area.containsMouse || btn.active)
    depth: 2

    color: (area.containsMouse || btn.active) ? Theme.surface : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }

    scale: Theme.cozy ? 1.0 : (area.pressed ? 0.90 : (area.containsMouse ? 1.06 : 1.0))
    Behavior on scale { NumberAnimation { duration: Theme.animDuration(160); easing.type: Easing.OutBack } }

    // Fila (horizontal) o columna (vertical: ícono arriba, texto abajo)
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

  // Separador entre grupos
  component Sep: Rectangle {
    Layout.preferredWidth: Theme.barVertical ? 18 : 1
    Layout.preferredHeight: Theme.barVertical ? 1 : 15
    Layout.alignment: Qt.AlignCenter
    radius: 1
    color: Theme.primary
    opacity: 0.25
  }

  // ============================================================
  // VENTANA
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
    // Vertical: mismo respiro (rightMargin) de siempre contra el botón ❄,
    // medido desde donde el botón realmente arranca ahora (ver margins.right
    // más abajo y menuButtonPanel en Bar.qml).
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
    // Alto de tooltip: el taskbar plegado lista hasta 12 líneas (~200 px) y con
    // 150 el tooltip se cortaba contra el borde de la ventana (parte de abajo
    // cuadrada). La ventana es click-through fuera de la píldora, así que
    // agrandarla no estorba.
    implicitHeight: Theme.barVertical
      ? pill.height + Math.round(260 * Theme.barScale)
      : Theme.barHeight + Math.round(260 * Theme.barScale)

    color: "transparent"
    visible: !rightModules.suppressed && !Theme.barRebuilding

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-right-modules"
    exclusiveZone: -1

    mask: Region { item: pill }

    Item {
      id: pill
      // Anclada a la derecha del PanelWindow: la píldora crece hacia la
      // izquierda, nunca hacia el botón ❄. Vertical: pegada al lado de la
      // barra (la ventana es más ancha por el tooltip); crece hacia ARRIBA.
      x: (Theme.barVertical && !Theme.barAtRight) ? 0 : parent.width - width
      // Barra abajo (o vertical, que crece hacia arriba): la píldora va pegada
      // al borde inferior de la ventana y el tooltip tiene lugar ARRIBA de ella
      y: (Theme.barVertical || Theme.barAtBottom) ? parent.height - height : 0
      // La fila se dibuja escalada (Ajustes → Barra)
      width: Theme.barVertical ? Theme.barThickness : modulesRow.implicitWidth * Theme.barScale + 14
      height: Theme.barVertical ? modulesRow.implicitHeight * Theme.barScale + 14 : Theme.barHeight

      Rectangle {
        visible: !(Theme.cozy && Theme.islandsMode)
        anchors.fill: parent
        radius: Theme.islandRadius
        color: Theme.bg
        border.width: Theme.islandsMode ? Theme.inkWidth : 0
        border.color: Theme.ink
      }
      // CoOzey + Islas: caja pixel en vez de redondeada
      SkinRect {
        visible: Theme.cozy && Theme.islandsMode
        anchors.fill: parent
        notch: 0
        color: Theme.bg
        inkColor: Theme.ink
      }

      BarFlow {
        id: modulesRow
        anchors.centerIn: parent
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
            // Vertical: "Silenciado" no cabe; el ícono ya indica el mute
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

          Text {
            Layout.alignment: Qt.AlignHCenter
            text: BatteryBackend.icon
            color: BatteryBackend.isLow ? Theme.error : Theme.text
            font.family: Theme.monoFamily
            font.pixelSize: Theme.fs(16)
            Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
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
          // Plegado (un solo ícono): la preferencia vive en Theme (ui.json)
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
          activeItem: rightModules.trayMenuOpen ? trayMenu.trayItem : null
          onTipEnter: item => rightModules.tipEnter(item)
          onTipLeave: item => rightModules.tipLeave(item)
          onMenuRequested: (iconItem, entry) => rightModules.openTrayMenu(iconItem, entry)
        }

        // ── 5. MENÚ ❄ (solo en modo Islas: integrado en la isla) ─────
        // El panel Menu nace de esta isla y crece hasta ser el menú; este
        // botón queda arriba, como su cabecera.
        Sep { visible: Theme.islandsMode }

        PillButton {
          id: menuBtn

          visible: Theme.islandsMode
          active: rightModules.menuOpen
          tip: Translations.t("menuButtonTip")

          onHoverEntered: rightModules.tipEnter(menuBtn)
          onHoverExited: rightModules.tipLeave(menuBtn)
          onClicked: rightModules.menuButtonClicked()

          Text {
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
    // Pegado a la barra 

    FusedTip {
      id: tip

      open: rightModules.tipOpen
      text: rightModules.tipText


      maxDepth: Theme.barVertical
        ? parent.height - 8 - 2 * Theme.tipFlare
        : parent.height - Theme.barOffset - 6

      // Horizontal: y fijo pegado a la barra; x se centra en el botón.
      // Vertical: x fijo pegado a la píldora (a su derecha si la barra está a
      // la izquierda, a su izquierda si está a la derecha); y se centra en el botón.
      // ── Modo Islas ──────────────────────────────────────────────
      // Nace de la isla derecha

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
            : Math.max(0, Math.min(parent.width - width, rightModules.tipCenterX - width / 2)))
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
