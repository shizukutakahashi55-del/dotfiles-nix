// Privacy — indicadores de privacidad de la barra (módulo "privacy" de
// Waybar): un ícono por cosa que se está usando, y NADA cuando no se usa
// ninguna. Apunta a la config de Waybar así:
//
// Es puramente visual: la detección vive en PrivacyBackend.qml. No tiene
// clics; solo pasar el mouse por encima muestra quién lo está usando.
//
// El host conecta tipEnter/tipLeave a su tooltip compartido, y usa
// `present` para esconder el separador cuando no hay nada que mostrar.
import QtQuick
import QtQuick.Layouts
import "../COMMON"
import "../LANG"
import "../PRIVACY"

BarFlow {
  id: privacy

  property int iconSize: 16
  property int iconSpacing: 6
  property int transitionMs: 250
  // Cuántas apps se listan en el tooltip antes de "… +N"
  property int tipMaxApps: 6

  signal tipEnter(var item)
  signal tipLeave(var item)

  // true mientras algún ícono sea visible (incluye el fade-out), así el
  // grupo no desaparece de golpe a mitad de la animación
  readonly property bool present: screenIcon.reveal > 0.001 || micIcon.reveal > 0.001

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

    // 0 → oculto, 1 → visible. Anima ancho, opacidad y escala juntos.
    property real reveal: active ? 1 : 0
    Behavior on reveal { NumberAnimation { duration: Theme.animDuration(pi.transitionMs); easing.type: Easing.OutCubic } }

    // Un ícono oculto no ocupa lugar (ni deja su parte del `spacing`)
    visible: reveal > 0.001
    opacity: reveal
    scale: 0.7 + 0.3 * reveal

    // El ícono "se abre" a lo largo de la barra: a lo ancho (horizontal) o a lo alto (vertical)
    Layout.preferredWidth: Theme.barVertical ? 30 : (iconSize + 10) * reveal
    Layout.preferredHeight: Theme.barVertical ? (iconSize + 10) * reveal : 30

    Text {
      anchors.centerIn: parent
      text: pi.glyph
      color: Theme.error          // rojo = algo te está mirando/escuchando
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
