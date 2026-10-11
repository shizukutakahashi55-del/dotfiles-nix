// SettingsSection — tarjeta base de una sección dentro de una página de Ajustes avanzados. Trae el borde, el fondo, el título (SectionLabel) y la descripción;

import QtQuick
import QtQuick.Layouts
import "../COMMON"
import "../LANG"

SkinRect {
  id: sec

  property string titleKey: ""
  property string hintKey: ""

  property color borderColor: Theme.edge

  property int padding: 16
  property alias spacing: body.spacing


  default property alias content: body.data

  Layout.fillWidth: true
  implicitHeight: body.implicitHeight + sec.padding * 2 - 2
  radius: Theme.cardRadius
  color: Theme.surface
  border.width: Theme.bw1
  border.color: sec.borderColor

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
