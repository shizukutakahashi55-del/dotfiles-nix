// CORE — AudioIpc
// IPC: target="audio" toggle(), raise(), lower(), mute()

import Quickshell
import Quickshell.Io
import QtQuick
import "../../Services/Audio"

Item {
  id: self
  property var shell
  IpcHandler {
    target: "audio"
    function toggle(): void {
      self.shell.togglePopup("audio")
    }
    function raise(): void { AudioBackend.stepVolume(0.05) }
    function lower(): void { AudioBackend.stepVolume(-0.05) }
    function mute(): void { AudioBackend.toggleMuteOsd() }
    function micToggle(): void { AudioBackend.toggleMicMuteOsd() }
    function micRaise(): void { AudioBackend.stepMicVolume(0.05) }
    function micLower(): void { AudioBackend.stepMicVolume(-0.05) }
  }
}
