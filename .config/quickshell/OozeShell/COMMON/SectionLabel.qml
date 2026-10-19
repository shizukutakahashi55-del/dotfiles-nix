// SectionLabel — encabezado de sección DENTRO de un panel (ej. "Tema", "Barra", "Detalles del sistema"). Antes estos encabezados eran un Text

import QtQuick

Text {
  id: root

  property real textScale: 1

  color: Theme.subtext
  font.family: Theme.titleFamily
  font.pixelSize: Math.max(6, Math.round(11 * Theme.fontScale * root.textScale))
  font.bold: true
  font.capitalization: Font.AllUppercase
  font.letterSpacing: 1.1
}
