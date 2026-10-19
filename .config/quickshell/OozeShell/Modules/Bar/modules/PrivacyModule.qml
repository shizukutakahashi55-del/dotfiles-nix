// PrivacyModule — indicadores de micrófono / pantalla; solo se ven mientras algo los usa.

import QtQuick

import "../../../COMMON"
import "../../Privacy"

BarFlow {
  id: mod

  property var host: null
  readonly property bool shown: privacy.present

  property int privacyIconSize: 16
  property int privacyIconSpacing: 6
  property int privacyTransitionMs: 250

  Privacy {
    id: privacy

    iconSize: mod.privacyIconSize
    iconSpacing: mod.privacyIconSpacing
    transitionMs: mod.privacyTransitionMs
    onTipEnter: item => mod.host.tipEnter(item)
    onTipLeave: item => mod.host.tipLeave(item)
  }
}
