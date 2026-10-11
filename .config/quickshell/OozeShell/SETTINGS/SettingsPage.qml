// SettingsPage — raíz de toda página de pages/. Es lo que el Loader de AdvancedSettings carga cuando su categoría está elegida.

import QtQuick
import QtQuick.Layouts
import "../COMMON"
import "../LANG"

ColumnLayout {
  id: page

  property string catId: ""
  property bool showTitle: true


  property bool active: false
  property var host: null

  spacing: 12

  SettingsPanelTitle {
    visible: page.showTitle && page.catId !== ""
    catId: page.catId
  }
}
