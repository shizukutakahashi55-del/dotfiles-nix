// SettingsSection — tarjeta base de una sección dentro de una página de Ajustes
// avanzados. Trae el borde, el fondo, el título (SectionLabel) y la descripción;
// el contenido que le pongas adentro se apila en una columna.
//
//   SettingsSection {
//     titleKey: "miSeccionTitulo"      // opcional: SectionLabel arriba
//     hintKey:  "miSeccionHint"        // opcional: texto chico debajo
//     SettingsBtn { text: "Hacer algo"; onClicked: ... }
//     ...                              // cualquier contenido
//   }
//
// Sin titleKey/hintKey es solo la tarjeta vacía (útil cuando la sección dibuja
// su propio encabezado, como Tachidesk).
//
// OJO — buscador: esta tarjeta NO se registra sola en el índice de búsqueda.
// Las páginas se cargan bajo demanda (Loader), así que el buscador no puede
// preguntarles nada mientras no están abiertas. Lo buscable se declara en
// `sections` de la entrada de la categoría en SettingsRegistry.qml. El
// `titleKey` de acá y el de allá tienen que ser el mismo texto: el buscador
// scrollea hasta el texto visible que coincide.
import QtQuick
import QtQuick.Layouts
import "../COMMON"
import "../LANG"

SkinRect {
  id: sec

  property string titleKey: ""
  property string hintKey: ""
  // Borde (ej. resaltarlo mientras algo está activo)
  property color borderColor: Theme.edge
  // Margen interno y separación entre hijos
  property int padding: 16
  property alias spacing: body.spacing

  // Todo lo que se declare adentro de SettingsSection { … } va a la columna.
  default property alias content: body.data

  Layout.fillWidth: true
  implicitHeight: body.implicitHeight + sec.padding * 2 - 2
  radius: Theme.cardRadius
  color: Theme.surface
  border.width: Theme.bw1
  border.color: sec.borderColor
  // CoOzey: contorno de tinta (o `borderColor` si se resalta) + filo de luz
  inkColor: sec.borderColor === Theme.edge ? Theme.ink : sec.borderColor
  clip: true

  ColumnLayout {
    id: body
    anchors { left: parent.left; right: parent.right; top: parent.top; margins: sec.padding }
    spacing: 10

    SectionLabel {
      visible: sec.titleKey !== ""
      Layout.fillWidth: true
      text: Translations.t(sec.titleKey)
    }
    Text {
      visible: sec.hintKey !== ""
      Layout.fillWidth: true
      text: Translations.t(sec.hintKey)
      wrapMode: Text.WordWrap
      color: Theme.subtext
      font.pixelSize: Theme.fs(10)
      font.family: Theme.fontFamily
    }
  }
}
