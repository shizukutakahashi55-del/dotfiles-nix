// Privacy — indicadores de privacidad de la barra (módulo "privacy" de Waybar): un ícono por cosa que se está usando, y NADA cuando no se usa

import QtQuick
import QtQuick.Layouts
import "../../COMMON"
import "../../Services/Lang"
import "../../Services/Screenshot"

BarFlow {
  id: privacy

  property int iconSize: 16
  property int iconSpacing: 6
  property int transitionMs: 250

  property int tipMaxApps: 6

  signal tipEnter(var item)
  signal tipLeave(var item)
  signal menuRequested(var item, var entry)


  readonly property bool present: screenIcon.reveal > 0.001 || micIcon.reveal > 0.001 || recIcon.reveal > 0.001

  gap: privacy.iconSpacing

  function tipFor(title, apps) {
    let s = title
    const n = Math.min(apps.length, privacy.tipMaxApps)
    for (let i = 0; i < n; i++) s += "\n• " + apps[i]
    if (apps.length > n) s += "\n… +" + (apps.length - n)
    return s
  }

  component PrivacyIcon: Item {
    id: pi

    property bool active: false
    property string glyph: ""
    property string tip: ""
    property int iconSize: 16
    property int transitionMs: 250

    signal entered()
    signal exited()


    property real reveal: active ? 1 : 0
    Behavior on reveal { NumberAnimation { duration: Theme.animDuration(pi.transitionMs); easing.type: Easing.OutCubic } }


    visible: reveal > 0.001
    opacity: reveal
    scale: 0.7 + 0.3 * reveal


    Layout.preferredWidth: Theme.barVertical ? 30 : (iconSize + 10) * reveal
    Layout.preferredHeight: Theme.barVertical ? (iconSize + 10) * reveal : 30

    Text {
      anchors.centerIn: parent
      text: pi.glyph
      color: Theme.error
      font.pixelSize: Theme.fs(pi.iconSize)
      font.family: Theme.monoFamily
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      enabled: pi.active
      onEntered: pi.entered()
      onExited: pi.exited()
    }
  }

  component RecordIcon: Item {
    id: ri

    property int iconSize: 16
    property int transitionMs: 250
    readonly property bool active: RecorderBackend.active
    readonly property string tip: RecorderBackend.tip

    signal entered()
    signal exited()
    signal menu()

    property real reveal: active ? 1 : 0
    Behavior on reveal { NumberAnimation { duration: Theme.animDuration(ri.transitionMs); easing.type: Easing.OutCubic } }

    property real blink: 1
    SequentialAnimation on blink {
      running: RecorderBackend.recording
      loops: Animation.Infinite
      NumberAnimation { to: 0.35; duration: 700; easing.type: Easing.InOutSine }
      NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
    }

    visible: reveal > 0.001
    opacity: reveal
    scale: 0.7 + 0.3 * reveal

    Layout.preferredWidth: Theme.barVertical ? 30 : (row.implicitWidth + 10) * reveal
    Layout.preferredHeight: Theme.barVertical ? (iconSize + 10) * reveal : 30

    Row {
      id: row
      anchors.centerIn: parent
      spacing: 4

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: RecorderBackend.paused ? RecorderBackend.gPause : RecorderBackend.gRecord
        color: RecorderBackend.paused ? Theme.primary : (RecorderBackend.counting ? Theme.subtext : Theme.error)
        opacity: RecorderBackend.recording ? ri.blink : 1
        font.pixelSize: Theme.fs(ri.iconSize)
        font.family: Theme.monoFamily
      }

      Text {
        visible: !Theme.barVertical
        anchors.verticalCenter: parent.verticalCenter
        text: RecorderBackend.counting ? String(RecorderBackend.countdown) : RecorderBackend.elapsedText
        color: Theme.text
        font.pixelSize: Theme.fs(Math.max(10, ri.iconSize - 4))
        font.family: Theme.monoFamily
      }
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      enabled: ri.active
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      cursorShape: Qt.PointingHandCursor
      onEntered: ri.entered()
      onExited: ri.exited()
      onClicked: mouse => {
        if (mouse.button === Qt.RightButton) ri.menu()
        else if (RecorderBackend.counting) RecorderBackend.cancel()
        else RecorderBackend.togglePause()
      }
    }
  }

  // ── Grabación de pantalla ─────────────────────────────────────
  RecordIcon {
    id: recIcon
    iconSize: privacy.iconSize
    transitionMs: privacy.transitionMs
    onEntered: privacy.tipEnter(recIcon)
    onExited: privacy.tipLeave(recIcon)
    onMenu: privacy.menuRequested(recIcon, RecorderBackend.menuEntry)
  }

  // ── Compartir pantalla ────────────────────────────────────────
  PrivacyIcon {
    id: screenIcon
    active: PrivacyBackend.screenshare
    glyph: "󰍹"
    iconSize: privacy.iconSize
    transitionMs: privacy.transitionMs
    tip: privacy.tipFor(Translations.t("privacyScreenshare"), PrivacyBackend.screenApps)
    onEntered: privacy.tipEnter(screenIcon)
    onExited: privacy.tipLeave(screenIcon)
  }

  // ── Micrófono ─────────────────────────────────────────────────
  PrivacyIcon {
    id: micIcon
    active: PrivacyBackend.micActive
    glyph: "󰍬"
    iconSize: privacy.iconSize
    transitionMs: privacy.transitionMs
    tip: privacy.tipFor(Translations.t("privacyMic"), PrivacyBackend.micApps)
    onEntered: privacy.tipEnter(micIcon)
    onExited: privacy.tipLeave(micIcon)
  }
}
