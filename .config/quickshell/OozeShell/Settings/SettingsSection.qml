// SettingsSection — tarjeta base de una sección de Ajustes avanzados: encabezado (título + descripción) y debajo una columna de filas (SettingsRow / SettingsNote) sin espacio entre ellas.

import QtQuick
import QtQuick.Layouts
import "../COMMON"
import "../Services/Lang"

SkinRect {
  id: sec

  property string titleKey: ""
  property string hintKey: ""

  property color borderColor: Theme.edge

  property int padding: 16
  property alias spacing: rows.spacing

  default property alias content: rows.data

  Layout.fillWidth: true
  implicitHeight: body.implicitHeight + sec.padding * 2 - 2
  radius: Theme.cozy ? Theme.cardRadius : MdTokens.rXl
  color: Theme.cozy ? Theme.surface : MdTokens.container
  border.width: Theme.cozy ? Theme.bw1 : 0
  border.color: sec.borderColor

  inkColor: sec.borderColor === Theme.edge ? Theme.ink : sec.borderColor
  clip: true

  ColumnLayout {
    id: body
    anchors { left: parent.left; right: parent.right; top: parent.top; margins: sec.padding }
    spacing: 0

    ColumnLayout {
      visible: sec.titleKey !== "" || sec.hintKey !== ""
      Layout.fillWidth: true
      Layout.bottomMargin: 4
      spacing: 3

      SectionLabel { textScale: Theme.settingsTextScale;
        visible: sec.titleKey !== ""
        Layout.fillWidth: true
        text: Translations.t(sec.titleKey)
        color: Theme.primary
      }
      Text {
        visible: sec.hintKey !== ""
        Layout.fillWidth: true
        text: Translations.t(sec.hintKey)
        wrapMode: Text.WordWrap
        color: Theme.subtext
        font.pixelSize: Theme.sfs(10)
        font.family: Theme.fontFamily
      }
    }

    ColumnLayout {
      id: rows
      Layout.fillWidth: true
      spacing: 0
    }
  }
}
