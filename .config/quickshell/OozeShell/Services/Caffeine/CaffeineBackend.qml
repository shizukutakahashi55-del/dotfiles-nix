// CaffeineBackend — modo Caffeine: evita que la pantalla se apague o el equipo se suspenda por inactividad.

pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  property bool active: false

  function toggle() { root.active = !root.active }
  function set(on) { root.active = !!on }

  Process {
    id: logindLock
    command: ["systemd-inhibit", "--what=idle", "--who=OozeShell",
              "--why=Caffeine", "--mode=block", "sleep", "infinity"]
    running: root.active
  }
}
