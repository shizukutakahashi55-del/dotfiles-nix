// SettingsValue — valor de solo lectura a la derecha de una SettingsRow.

import QtQuick
import QtQuick.Layouts
import "../COMMON"

Text {
  Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
  Layout.maximumWidth: 300
  horizontalAlignment: Text.AlignRight
  elide: Text.ElideRight
  color: Theme.text
  font.bold: true
  font.pixelSize: Theme.sfs(11)
  font.family: Theme.fontFamily
}
