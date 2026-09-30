// BarFlow — fila si la barra es horizontal, columna si es vertical.
//
// Reemplaza a RowLayout en todo lo que vive dentro de la barra, así cada
// módulo declara sus hijos UNA sola vez y se acomoda solo según
// Theme.barVertical. Los hijos usan los mismos Layout.preferredWidth /
// Layout.preferredHeight de siempre.
//
// Ojo: GridLayout no tiene `spacing` (solo columnSpacing / rowSpacing);
// por eso este componente expone `gap`, que llena los dos.
//
//   BarFlow { gap: 2; ... hijos ... }
//
// Los hijos con visible: false no ocupan celda (ni dejan su parte del gap).
import QtQuick
import QtQuick.Layouts
import "../COMMON"

GridLayout {
  id: bf

  property bool vertical: Theme.barVertical
  property real gap: 2

  // Cuando un BarFlow va DENTRO de otro (workspaces, taskbar, tray, privacy),
  // en una columna los hijos más angostos que ella quedan pegados a la
  // izquierda por defecto. Centrado, quedan alineados con los botones.
  Layout.alignment: Qt.AlignCenter

  // Horizontal: una sola fila (TopToBottom con rows: 1 pone cada hijo en
  // su propia columna). Vertical: una sola columna.
  flow: bf.vertical ? GridLayout.LeftToRight : GridLayout.TopToBottom
  columns: bf.vertical ? 1 : -1
  rows: bf.vertical ? -1 : 1

  columnSpacing: bf.gap
  rowSpacing: bf.gap
}
