// ImageBrowser — mini explorador de imágenes para elegir la foto de perfil.
// Está hecho a mano (en vez de abrir zenity / kdialog / el portal de archivos) para no depender de ningún programa extra: lista las carpetas y las imágenes de la carpeta actual, con miniaturas. Clic en una carpeta = ent…

import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../COMMON"
import "../LANG"

Item {
  id: root

  property string dir: ""
  readonly property string home: Quickshell.env("HOME")

  signal picked(string path)
  signal cancelled()


  property bool allowFolder: false
  signal folderPicked(string path)

  ListModel { id: entries }

  function join(name) { return (root.dir === "/" ? "" : root.dir) + "/" + name }

  function parentOf(path) {
    const t = String(path).replace(/\/+$/, "")
    const i = t.lastIndexOf("/")
    return i <= 0 ? "/" : t.slice(0, i)
  }


  function clean(path) {
    let t = String(path || "").trim()
    if (t.indexOf("file://") === 0) { try { t = decodeURIComponent(t.slice(7)) } catch (e) { t = t.slice(7) } }
    if (t === "~") t = root.home
    else if (t.indexOf("~/") === 0) t = root.home + t.slice(1)
    return t === "" ? root.home : t
  }
  function go(path) {
    entries.clear()
    lister.running = false
    lister.command = ["bash", "-c", root.listScript, "ooze-browser", root.clean(path)]
    lister.running = true
  }


  readonly property string listScript:
    'p="$1"; [ -f "$p" ] && p="$(dirname -- "$p")"; ' +
    'cd -- "$p" 2>/dev/null || { echo E; exit 0; }; ' +
    'printf "P\\t%s\\n" "$PWD"; ' +
    'for d in */; do [ -d "$d" ] && printf "d\\t%s\\n" "${d%/}"; done; ' +
    'for f in *; do [ -f "$f" ] || continue; ' +
    'case "${f,,}" in *.png|*.jpg|*.jpeg|*.webp|*.bmp|*.gif|*.svg) printf "f\\t%s\\n" "$f";; esac; done'

  Process {
    id: lister
    running: false
    stdout: SplitParser {
      onRead: line => {
        if (line === "E") {
          if (root.dir !== root.home) Qt.callLater(() => root.go(root.home))
          return
        }
        const i = line.indexOf("\t")
        if (i < 0) return
        const kind = line.slice(0, i), name = line.slice(i + 1)
        if (kind === "P") root.dir = name
        else entries.append({ kind: kind, name: name })
      }
    }
    stderr: SplitParser { onRead: line => console.log("[imagebrowser]", line) }
  }


  component Chip: SkinRect {
    id: chip
    property string icon: ""
    signal clicked()

    Layout.preferredWidth: 34
    Layout.preferredHeight: 28
    radius: 9
    color: chipArea.containsMouse ? Theme.surfaceHigh : Theme.surface
    Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }

    Text {
      anchors.centerIn: parent
      text: chip.icon
      color: Theme.primary
      font.pixelSize: Theme.fs(14)
      font.family: Theme.monoFamily
    }
    MouseArea {
      id: chipArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: chip.clicked()
    }
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: 8

    // ── Barra: subir · inicio · imágenes · descargas · ruta · cancelar ──
    RowLayout {
      Layout.fillWidth: true
      spacing: 6

      Chip { icon: "↑";  onClicked: root.go(root.parentOf(root.dir)) }
      Chip { icon: "󰋜"; onClicked: root.go(root.home) }
      Chip { icon: "󰋩"; onClicked: root.go(root.home + "/Pictures") }
      Chip { icon: "󰇚"; onClicked: root.go(root.home + "/Downloads") }

      Text {
        Layout.fillWidth: true
        Layout.leftMargin: 6
        Layout.minimumWidth: 0
        text: root.dir.indexOf(root.home) === 0 ? "~" + root.dir.slice(root.home.length) : root.dir
        color: Theme.subtext
        font.pixelSize: Theme.fs(10)
        font.family: Theme.fontFamily
        elide: Text.ElideLeft
      }

      Chip { visible: root.allowFolder; icon: "󰄬"; onClicked: root.folderPicked(root.dir) }
      Chip { icon: "✕"; onClicked: root.cancelled() }
    }

    // ── Cuadrícula ──
    Item {
      Layout.fillWidth: true
      Layout.fillHeight: true

      GridView {
        id: grid
        anchors.fill: parent
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        readonly property int cols: 4
        cellWidth: Math.floor(width / cols)
        cellHeight: cellWidth

        model: entries

        delegate: Item {
          id: cell
          required property string kind
          required property string name

          width: grid.cellWidth
          height: grid.cellHeight

          SkinRect {
            anchors.fill: parent
            anchors.margins: 3
            radius: 9
            clip: true
            color: cellArea.containsMouse ? Theme.surfaceHigh : Theme.surface
            Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }


            ColumnLayout {
              visible: cell.kind === "d"
              anchors.centerIn: parent
              width: parent.width - 10
              spacing: 2

              Text {
                Layout.alignment: Qt.AlignHCenter
                text: "󰉋"
                color: Theme.primary
                font.pixelSize: Theme.fs(24)
                font.family: Theme.monoFamily
              }
              Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: cell.name
                color: Theme.text
                font.pixelSize: Theme.fs(10)
                font.family: Theme.fontFamily
                elide: Text.ElideMiddle
              }
            }


            Image {
              visible: cell.kind === "f"
              anchors.fill: parent
              source: cell.kind === "f" ? UserProfile.fileUrl(root.join(cell.name)) : ""
              sourceSize: Qt.size(220, 220)
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
              smooth: true
              opacity: status === Image.Ready ? 1 : 0
              Behavior on opacity { NumberAnimation { duration: Theme.animDuration(150) } }
            }


            Rectangle {
              visible: cell.kind === "f"
              anchors.fill: parent
              radius: 9
              color: "transparent"
              border.width: cellArea.containsMouse ? 2 : 0
              border.color: Theme.primary
            }
          }

          MouseArea {
            id: cellArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (cell.kind === "d") root.go(root.join(cell.name))
              else root.picked(root.join(cell.name))
            }
          }
        }
      }

      Text {
        visible: entries.count === 0 && !lister.running
        anchors.centerIn: parent
        text: Translations.t("profileEmptyDir")
        color: Theme.subtext
        font.pixelSize: Theme.fs(11)
        font.family: Theme.fontFamily
      }
    }
  }
}
