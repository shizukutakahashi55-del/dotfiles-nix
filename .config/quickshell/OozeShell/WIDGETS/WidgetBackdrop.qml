// WidgetBackdrop — el wallpaper actual, para que cada widget lo difumine por su cuenta.

pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: root

  readonly property string lastFile: Quickshell.env("HOME") + "/.cache/awww/last"
  property string url: ""

  function toUrl(path) {
    return path === "" ? "" : "file://" + path.split("/").map(encodeURIComponent).join("/")
  }

  FileView {
    id: view
    path: root.lastFile
    watchChanges: true
    onFileChanged: view.reload()
    onLoaded: {
      const p = String(view.text()).split("\n")[0].trim()
      root.url = root.toUrl(p)
    }
    onLoadFailed: root.url = ""
  }
}
