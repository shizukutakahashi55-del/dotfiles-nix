// LauncherParticles — "polvo" ambiente detrás de la tarjeta del Launcher.
//
//   LauncherParticles { anchors.fill: parent; active: root.open && root.fancyFxActive }
import QtQuick
import "../COMMON"

Item {
  id: root

  property bool active: false
  property int count: 20
  // Glifos y su peso relativo de aparición (index % glyphs.length)
  readonly property var glyphs: ["✦", "·", "✧"]

  visible: root.active

  Repeater {
    model: root.count
    delegate: Text {
      id: mote

      // "Azar" repetible a partir del índice: cada mota es distinta pero
      // siempre igual entre aperturas (nada salta ni se reacomoda solo).
      readonly property real baseX: ((index * 149) % 100) / 100 * root.width
      readonly property real startY: ((index * 197) % 100) / 100 * root.height
      readonly property int riseMs: 9000 + (index * 977) % 7000
      readonly property int swayMs: 2600 + (index * 271) % 1800
      readonly property int twinkleMs: 900 + (index * 131) % 1100
      readonly property string glyph: root.glyphs[index % root.glyphs.length]

      text: mote.glyph
      color: index % 4 === 0 ? Theme.primary : Theme.text
      font.pixelSize: mote.glyph === "·" ? (10 + (index * 5) % 10) : (8 + (index * 6) % 13)
      font.family: Theme.fontFamily
      x: mote.baseX
      y: root.height + 30

      readonly property real maxOpacity: 0.08 + ((index * 41) % 22) / 100

      // Sube desde abajo, sale por arriba, y vuelve a arrancar desde
      // abajo del todo (no desde la mitad: a diferencia de la nieve, acá
      // no hace falta ocultar el arranque porque nace fuera de la tarjeta)
      SequentialAnimation on y {
        running: root.active && Theme.uiAnimationsEnabled
        loops: Animation.Infinite
        NumberAnimation { from: root.height + 30; to: -30; duration: Theme.animDuration(mote.riseMs) }
      }

      // Vaivén de lado a lado, igual que la nieve del PowerMenu
      SequentialAnimation on x {
        running: root.active && Theme.uiAnimationsEnabled
        loops: Animation.Infinite
        NumberAnimation { from: mote.baseX - 14; to: mote.baseX + 14
                          duration: Theme.animDuration(mote.swayMs); easing.type: Easing.InOutSine }
        NumberAnimation { from: mote.baseX + 14; to: mote.baseX - 14
                          duration: Theme.animDuration(mote.swayMs); easing.type: Easing.InOutSine }
      }

      // Titileo propio, independiente de la subida
      SequentialAnimation on opacity {
        running: root.active && Theme.uiAnimationsEnabled
        loops: Animation.Infinite
        NumberAnimation { from: mote.maxOpacity * 0.25; to: mote.maxOpacity
                          duration: Theme.animDuration(mote.twinkleMs); easing.type: Easing.InOutSine }
        NumberAnimation { from: mote.maxOpacity; to: mote.maxOpacity * 0.25
                          duration: Theme.animDuration(mote.twinkleMs); easing.type: Easing.InOutSine }
      }
    }
  }
}
