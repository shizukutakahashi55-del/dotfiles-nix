// SettingsPage — raíz de toda página de pages/. Es lo que el Loader de AdvancedSettings carga cuando su categoría está elegida.

import QtQuick
import QtQuick.Layouts
import "../COMMON"
import "../Services/Lang"

ColumnLayout {
  id: page

  property string catId: ""
  property bool showTitle: true


  property bool active: false
  property var host: null

  spacing: 14

  SettingsPanelTitle {
    visible: page.showTitle && page.catId !== ""
    catId: page.catId
  }
}
