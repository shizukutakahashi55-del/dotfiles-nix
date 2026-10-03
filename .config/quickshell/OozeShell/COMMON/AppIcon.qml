// AppIcon — ícono de una app que NUNCA muestra el cuadriculado morado/negro.
//
// Quickshell dibuja esa textura "missing" cuando le pasás un nombre de ícono
// que no existe en el tema. Acá cada nombre se comprueba antes con
// Quickshell.iconPath(nombre, true) (devuelve "" si no existe) y se va
// probando el siguiente candidato; si ninguno existe se dibuja un glifo.
//
// Candidatos, en orden: `icon` (el Icon= del .desktop, nombre de tema o ruta
// absoluta), el ícono del .desktop que encuentra DesktopEntries para `appId`,
// el appId tal cual y en minúsculas, su último tramo (org.mozilla.firefox →
// firefox) y, al final, el genérico del tema.
//
//   AppIcon { size: 28; icon: entry.icon }                 // launcher de apps
//   AppIcon { size: 28; appId: window.class }              // lista de ventanas
//
// La base de .desktop llega de forma asíncrona y heuristicLookup() no avisa
// cuando termina; por eso se lee la lista dentro de resolve(): así el ícono
// se vuelve a resolver solo cuando llegan (o cambian) las apps.
import Quickshell
import Quickshell.Widgets
import QtQuick
import "../COMMON"

Item {
  id: root

  property string icon: ""
  property string appId: ""
  property real size: 24
  // Lo que se dibuja si no hay ningún ícono resoluble
  property string glyph: "󰀻"
  property color glyphColor: Theme.subtext

  implicitWidth: root.size
  implicitHeight: root.size

  readonly property int desktopRevision: DesktopEntries.applications.values.length

  // URL de un ícono que EXISTE, o "" si no hay ninguno
  function resolve() {
    void root.desktopRevision

    const names = []
    if (root.icon !== "") names.push(root.icon)
    const id = root.appId
    if (id !== "") {
      const entry = DesktopEntries.heuristicLookup(id)
      if (entry && entry.icon) names.push(entry.icon)
      names.push(id, id.toLowerCase())
      const last = id.split(".").pop().toLowerCase()
      if (last !== id.toLowerCase()) names.push(last)
    }

    for (let i = 0; i < names.length; i++) {
      const n = names[i]
      if (!n) continue
      // Icon=/ruta/absoluta.png (AppImages, apps propietarias…)
      if (n.charAt(0) === "/") return "file://" + n
      const p = Quickshell.iconPath(n, true)
      if (p !== "") return p
    }
    return Quickshell.iconPath("application-x-executable", true)
  }

  readonly property string src: root.resolve()

  IconImage {
    anchors.fill: parent
    visible: root.src !== ""
    source: root.src
  }

  Text {
    anchors.centerIn: parent
    visible: root.src === ""
    text: root.glyph
    color: root.glyphColor
    font.pixelSize: Math.round(root.size * 0.9)
    font.family: Theme.monoFamily
  }
}
