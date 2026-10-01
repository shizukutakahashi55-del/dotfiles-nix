// SectionLabel — encabezado de sección DENTRO de un panel (ej. "Tema",
// "Barra", "Detalles del sistema"). Antes estos encabezados eran un Text
// bold del mismo tamaño (±1px) que el título del panel (PanelHeader) y que
// las etiquetas de fila ("Fuente", "Posición", etc.), así que a simple
// vista no se distinguía nada.
//
// Jerarquía ahora:
//   PanelHeader   → título del panel: grande, negrita, Theme.text
//   SectionLabel  → encabezado de sección: chico, VERSALITAS, con tracking,
//                   Theme.subtext (este componente)
//   fila normal   → etiqueta de campo: negrita, tamaño normal, Theme.text
//
// Uso:
//   SectionLabel { Layout.fillWidth: true; text: Translations.t("themeSection") }
import QtQuick

Text {
  id: root

  color: Theme.subtext
  font.family: Theme.fontFamily
  font.pixelSize: Theme.fs(11)
  font.bold: true
  font.capitalization: Font.AllUppercase
  font.letterSpacing: 1.1
}
