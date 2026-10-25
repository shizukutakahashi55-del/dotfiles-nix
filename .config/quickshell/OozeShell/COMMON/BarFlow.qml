// BarFlow — fila si la barra es horizontal, columna si es vertical.

import QtQuick
import QtQuick.Layouts

GridLayout {
  id: bf

  property bool vertical: Theme.barVertical
  property real gap: 2


  Layout.alignment: Qt.AlignCenter


  flow: bf.vertical ? GridLayout.LeftToRight : GridLayout.TopToBottom
  columns: bf.vertical ? 1 : -1
  rows: bf.vertical ? -1 : 1

  columnSpacing: bf.gap
  rowSpacing: bf.gap
}
