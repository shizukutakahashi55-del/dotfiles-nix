// MdTokens — COMMON

pragma Singleton

import QtQuick

QtObject {
  id: root

  readonly property int rXs: Theme.cozy ? 2 : 8
  readonly property int rS: Theme.cozy ? 3 : 12
  readonly property int rM: Theme.cozy ? 4 : 16
  readonly property int rL: Theme.cozy ? 4 : 20
  readonly property int rXl: Theme.cozy ? 6 : 28
  readonly property int listGap: 2
  readonly property int innerRadius: Theme.cozy ? 2 : 6

  readonly property color base: Theme.mix(Theme.surface, Theme.bg, 0.40)
  readonly property color container: Theme.mix(root.base, Theme.primary, 0.05)
  readonly property color containerHigh: Theme.mix(root.base, Theme.primary, 0.13)
  readonly property color containerHighest: Theme.mix(root.base, Theme.primary, 0.24)
  readonly property color well: Theme.mix(root.container, Theme.bg, 0.70)
  readonly property color control: Theme.mix(root.base, Theme.primary, 0.20)
  readonly property color controlHover: Theme.mix(root.base, Theme.primary, 0.36)
  readonly property color controlEdge: Theme.withAlpha(Theme.primary, 0.40)
  readonly property color controlStrong: Theme.mix(root.base, Theme.primary, 0.32)
  readonly property color edgeSoft: Theme.withAlpha(Theme.primary, 0.28)
  readonly property color onContainer: Theme.primary
  readonly property color outlineSoft: Theme.withAlpha(Theme.primary, 0.28)

  function tone(base, w) { return Theme.mix(Theme.surface, base, w) }
  function stateLayer(c, hover, pressed) {
    return Theme.withAlpha(c, pressed ? 0.16 : (hover ? 0.08 : 0))
  }
}
