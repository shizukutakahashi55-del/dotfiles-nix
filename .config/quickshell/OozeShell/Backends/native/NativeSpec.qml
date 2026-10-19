// BACKEND — NativeSpec
// IPC: target="native" get(): string

pragma Singleton
import QtQuick
import Quickshell

QtObject {
  id: root
  readonly property string activeModules: "AnimationController,FontProbe,SystemStats,SystemMonitor,ProcessList,WmStream"
  readonly property var planned: ["Fuzzy", "ImageProc"]
  readonly property string modulePath: Quickshell.dataDir + "/oozeshell/qml/OozeShell/Native"
  readonly property bool disabled: Quickshell.env("OOZE_NO_NATIVE") === "1"

  function probe(body, parent, name) {
    if (root.disabled) throw new Error("núcleo nativo desactivado (OOZE_NO_NATIVE=1)")
    try {
      return Qt.createQmlObject('import QtQml\nimport OozeShell.Native 1.0\n' + body, parent, name)
    } catch (e) {
      return Qt.createQmlObject('import QtQml\nimport "file:' + root.modulePath + '"\n' + body, parent, name)
    }
  }

  function get(): string {
    return JSON.stringify({ active: root.activeModules, planned: root.planned })
  }
}
