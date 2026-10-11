// ModeRuntime.qml — COMMON

pragma Singleton
import QtQuick
import "../COMMON"


QtObject {
  id: root


  readonly property bool pillActive: Theme.pillMode

  readonly property bool barActive: !Theme.pillMode
}
