// OozeShell Wallpapers and More

import Quickshell
import Quickshell.Io
import "./WALLS"

ShellRoot {
  id: root

  property bool wallsOpen:     false
  property int  currentWallIndex: 0

  Process {
    id: initColors
    command: ["bash", "-c",
      "WP=$(cat ~/.cache/awww/last 2>/dev/null); " +
      "if [ -n \"$WP\" ] && [ -f \"$WP\" ]; then " +
      "  matugen image \"$WP\" --source-color-index 0 --json hex | sed -n '/^{/,/^}/p' > /tmp/matugen-colors.json; " +
      "fi"
    ]
    running: true
  }


  IpcHandler {
    target: "toggleWalls"
    function handle() { root.wallsOpen = !root.wallsOpen }
  }


  Walls {
    id: walls
    open: root.wallsOpen
    currentIndex: root.currentWallIndex
    onCurrentIndexChanged: root.currentWallIndex = walls.currentIndex
    onCloseRequested: root.wallsOpen = false
  }

}
