// SectionLabel — encabezado de sección DENTRO de un panel (ej. "Tema", "Barra", "Detalles del sistema"). Antes estos encabezados eran un Text

import QtQuick

Text {
  id: root

  color: Theme.subtext
  font.family: Theme.titleFamily
  font.pixelSize: Theme.fs(11)
  font.bold: true
  font.capitalization: Font.AllUppercase
  font.letterSpacing: 1.1
}
