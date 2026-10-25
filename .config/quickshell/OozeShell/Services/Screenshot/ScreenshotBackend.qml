// ScreenshotBackend.qml — SCREENSHOT

pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../COMMON"
import "../Lang"

QtObject {
  id: root


  property int borderWidth: 2

  property real backgroundOpacity: 0.1

  property real settleDelay: 0.3

  // ─── Selección de área (con la pantalla congelada) ───────────────


  property bool pickerOpen: false

  property string pickerMode: "copy"


  property bool capturing: false


  property int freezeSettleMs: 90

  function openPicker(mode) {
    if (root.pickerOpen) return
    root.pickerMode = mode
    root.capturing = false
    root.pickerOpen = true
  }
  function closePicker() {
    root.pickerOpen = false
    root.capturing = false
  }

  function areaCopy() { root.openPicker("copy") }
  function areaSave() { root.openPicker("save") }


  function captureCommand(geo) {
    return CaptureConfig.shotCommand(root.pickerMode === "copy", geo)
  }

  function fullSave() {
    Quickshell.execDetached(CaptureConfig.shotCommand(false, ""))
  }
}
