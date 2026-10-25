// SettingsNote — aviso corto dentro de una sección. kind: "info" (gris), "accent" (color primario), "warn" (ámbar) o "error".

import QtQuick
import QtQuick.Layouts
import "../COMMON"

Text {
  id: note

  property string kind: "info"

  Layout.fillWidth: true
  Layout.topMargin: 6
  Layout.bottomMargin: 6
  wrapMode: Text.WordWrap
  color: note.kind === "error" ? Theme.error
       : (note.kind === "warn" ? "#e0b04f" : (note.kind === "accent" ? Theme.primary : Theme.subtext))
  font.pixelSize: Theme.sfs(11)
  font.family: Theme.fontFamily
}
