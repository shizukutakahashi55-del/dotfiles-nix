// PanelHeader — encabezado común de los submenús que cuelgan del Menu
// (Apariencia / Monitor / Idioma): flecha ‹ para volver, ícono y título.
// Mismo aspecto que el encabezado de NetworkMenu.
//
// Uso:
//   PanelHeader {
//     Layout.fillWidth: true
//     icon: "󰗊"
//     title: Translations.t("chooseLanguage")
//     onBackRequested: root.backRequested()
//   }
import QtQuick
import QtQuick.Layouts
import "../COMMON"

RowLayout {
  id: root

  property string icon: ""
  property string title: ""
  signal backRequested()

  spacing: 10

  Rectangle {
    Layout.preferredWidth: 30
    Layout.preferredHeight: 30
    radius: 15
    color: backArea.containsMouse ? Theme.surfaceHigh : Theme.surface
    border.width: Theme.cozy ? Theme.inkWidth : 0
    border.color: Theme.ink
    Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }

    Text {
      anchors.centerIn: parent
      text: "󰅁"
      color: Theme.text
      font.pixelSize: Theme.fs(16)
      font.family: Theme.monoFamily
    }
    MouseArea {
      id: backArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.backRequested()
    }
  }

  Text {
    visible: root.icon !== ""
    text: root.icon
    color: Theme.primary
    font.pixelSize: Theme.fs(20)
    font.family: Theme.monoFamily
  }

  // fillWidth + elide: un título largo (ej. "Seleccionar pantalla principal")
  // antes se dibujaba a su ancho natural, pasaba del borde derecho del panel y
  // la máscara redondeada lo cortaba ("se pierde la derecha").
  Text {
    Layout.fillWidth: true
    Layout.minimumWidth: 0
    elide: Text.ElideRight
    text: root.title
    color: Theme.text
    font.bold: true
    font.pixelSize: Theme.fs(16)
    font.family: Theme.fontFamily
  }
}
