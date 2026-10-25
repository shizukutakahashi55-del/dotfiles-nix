// CORE — RecordIpc
// IPC: target="record" toggleArea(), toggleScreen(), startArea(), startScreen(), stop(), pause(), resume(), togglePause(), cancel(), status()

import Quickshell
import Quickshell.Io
import QtQuick
import "../../Services/Screenshot"

Item {
  id: self
  property var shell
  IpcHandler {
    target: "record"
    function toggleArea(): void { RecorderBackend.toggle("area") }
    function toggleScreen(): void { RecorderBackend.toggle("screen") }
    function startArea(): void { RecorderBackend.startArea() }
    function startScreen(): void { RecorderBackend.startScreen() }
    function stop(): void { RecorderBackend.stop() }
    function pause(): void { RecorderBackend.pause() }
    function resume(): void { RecorderBackend.resume() }
    function togglePause(): void { RecorderBackend.togglePause() }
    function cancel(): void { RecorderBackend.cancel() }
    function status(): string { return RecorderBackend.phase + " " + RecorderBackend.elapsedText }
  }
}
