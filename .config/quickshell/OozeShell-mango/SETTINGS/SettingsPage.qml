// SettingsPage — raíz de toda página de pages/. Es lo que el Loader de
// AdvancedSettings carga cuando su categoría está elegida.
//
//   import ".."                       // SettingsPage, SettingsSection, SettingsBtn…
//   import "../../COMMON"
//   import "../../LANG"
//
//   SettingsPage {
//     id: page
//     catId: "miCategoria"            // id en SettingsRegistry.categories
//     SettingsSection { … }
//     SettingsSection { … }
//   }
//
// Contrato con el marco (lo inyecta el Loader, la página solo lo lee):
//   active   true mientras la ventana de Ajustes está abierta. Atá a esto los
//            Timer que hacen polling:  Timer { running: page.active … }
//            (la página solo existe mientras su categoría está elegida, así que
//            "categoría visible" ya está implícito).
//   host     el AdvancedSettings (señales y propiedades del marco:
//            host.targetMonitor, host.languageChosen(…), etc.). Puede ser null
//            un instante al construirse: leelo dentro de handlers/bindings, no
//            en Component.onCompleted de un objeto anidado.
//
// Trae el título de la categoría arriba (SettingsPanelTitle). Para una página
// sin título: `showTitle: false`.
import QtQuick
import QtQuick.Layouts
import "../COMMON"
import "../LANG"

ColumnLayout {
  id: page

  property string catId: ""
  property bool showTitle: true

  // Inyectadas por el Loader del marco
  property bool active: false
  property var host: null

  spacing: 12

  SettingsPanelTitle {
    visible: page.showTitle && page.catId !== ""
    catId: page.catId
  }
}
