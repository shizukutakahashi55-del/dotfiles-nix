// SettingsRow — fila estándar de toda página: título + descripción a la izquierda y el control a la derecha. Con `stacked` el control baja debajo del texto y ocupa todo el ancho.

import QtQuick
import QtQuick.Layouts
import "../COMMON"
import "../Services/Lang"

ColumnLayout {
  id: row

  property string titleKey: ""
  property string hintKey: ""
  property string title: ""
  property string hint: ""
  property bool stacked: false
  property bool divider: true

  readonly property string shownTitle: row.titleKey !== "" ? Translations.t(row.titleKey) : row.title
  readonly property string shownHint: row.hintKey !== "" ? Translations.t(row.hintKey) : row.hint

  default property alias control: slot.data

  Layout.fillWidth: true
  spacing: 0
  opacity: row.enabled ? 1 : 0.45
  Behavior on opacity { NumberAnimation { duration: Theme.animDuration(150) } }

  Rectangle {
    visible: row.divider && row.y > 0
    Layout.fillWidth: true
    Layout.preferredHeight: 1
    color: Theme.divider
  }

  GridLayout {
    Layout.fillWidth: true
    Layout.topMargin: 11
    Layout.bottomMargin: 11
    columns: row.stacked ? 1 : 2
    columnSpacing: 18
    rowSpacing: 9

    ColumnLayout {
      visible: row.shownTitle !== "" || row.shownHint !== ""
      Layout.fillWidth: true
      Layout.minimumWidth: 0
      Layout.preferredWidth: 1
      Layout.alignment: Qt.AlignVCenter
      spacing: 2

      Text {
        visible: row.shownTitle !== ""
        Layout.fillWidth: true
        text: row.shownTitle
        wrapMode: Text.WordWrap
        color: Theme.text
        font.bold: true
        font.pixelSize: Theme.sfs(12)
        font.family: Theme.fontFamily
      }
      Text {
        visible: row.shownHint !== ""
        Layout.fillWidth: true
        text: row.shownHint
        wrapMode: Text.WordWrap
        color: Theme.subtext
        font.pixelSize: Theme.sfs(10)
        font.family: Theme.fontFamily
      }
    }

    RowLayout {
      id: slot
      Layout.fillWidth: row.stacked
      Layout.alignment: row.stacked ? (Qt.AlignLeft | Qt.AlignTop) : (Qt.AlignRight | Qt.AlignVCenter)
      spacing: 8
    }
  }
}
