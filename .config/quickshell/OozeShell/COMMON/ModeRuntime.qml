// ModeRuntime.qml — COMMON

pragma Singleton
import QtQuick


QtObject {
  id: root


  readonly property bool pillActive: Theme.pillMode

  readonly property bool barActive: !Theme.pillMode
}
