// WallsBubble — WALLS
// Burbuja con contorno del color primario que agrupa controles (la misma que usa WallsHeader).

import QtQuick
import "../../COMMON"

SkinRect {
  notch: 4
  raised: Theme.cozy
  depth: 3
  inkColor: Theme.primary
  color: Theme.bg
  border.color: Theme.primary
  border.width: 1.5
}
