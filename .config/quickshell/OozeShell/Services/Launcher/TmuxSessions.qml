// TmuxSessions — sesiones de tmux para el modo `!` del Launcher.

import Quickshell
import Quickshell.Io
import QtQuick
import "../../COMMON"

Item {
  id: root

  width: 0
  height: 0

  property var sessions: []
  property var pending: []

  readonly property bool running: reader.running

  function refresh() {
    if (reader.running) return
    root.pending = []
    reader.running = true
  }


  function launch(name, create) {
    if (!name || name === "") return
    const args = create
      ? ["tmux", "new-session", "-A", "-s", name]
      : ["tmux", "attach-session", "-t", "=" + name]
    Quickshell.execDetached(Theme.terminalCmd.concat(args))
  }

  Process {
    id: reader
    command: ["tmux", "list-sessions", "-F", "#{session_name}"]

    stdout: SplitParser {
      onRead: data => {
        const n = data.trim()
        if (n !== "") root.pending = root.pending.concat(n)
      }
    }

    onExited: root.sessions = root.pending.slice().sort()
  }
}
