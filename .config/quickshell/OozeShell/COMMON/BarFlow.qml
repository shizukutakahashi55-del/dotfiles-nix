// BarFlow — fila si la barra es horizontal, columna si es vertical.
// Reemplaza a RowLayout en todo lo que vive dentro de la barra, así cada módulo declara sus hijos UNA sola vez y se acomoda solo según Theme.barVertical. Los hijos usan los mismos Layout.preferredWidth /

import QtQuick
import QtQuick.Layouts
import "../COMMON"

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
