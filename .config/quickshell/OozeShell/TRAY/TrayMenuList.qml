// TrayMenuList — contenido del menú de un ícono de la bandeja (encabezado, submenús y lista de entradas). No dibuja fondo: lo aloja quien lo use.

import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import "../COMMON"

Item {
  id: root

  property var trayItem: null

  property int maxListHeight: 420
  readonly property int pad: 12
  readonly property int rowHeight: 32

  property bool showClose: false
  signal closeRequested()

  implicitHeight: col.implicitHeight + root.pad * 2


  property var stack: []
  readonly property var currentEntry: stack.length > 0 ? stack[stack.length - 1] : null
  readonly property var currentHandle: currentEntry ? currentEntry : (trayItem ? trayItem.menu : null)


  onTrayItemChanged: root.stack = []

  readonly property string title: {
    if (root.currentEntry) return root.currentEntry.text
    const it = root.trayItem
    return it ? (it.tooltipTitle || it.title || it.id || "") : ""
  }

  QsMenuOpener {
    id: opener
    menu: root.currentHandle
  }

  ColumnLayout {
    id: col
    x: root.pad
    y: root.pad
    width: root.width - root.pad * 2
    spacing: 8

    // ── Encabezado: [‹] ícono + título ─────────────────────
    RowLayout {
      Layout.fillWidth: true
      spacing: 10

      Rectangle {
        visible: root.stack.length > 0 || root.showClose
        Layout.preferredWidth: 26
        Layout.preferredHeight: 26
        radius: 13
        color: backArea.containsMouse ? Theme.surfaceHigh : Theme.surface
        Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }

        Text {
          anchors.centerIn: parent
          text: "󰅁"
          color: Theme.text
          font.pixelSize: Theme.fs(14)
          font.family: Theme.monoFamily
        }
        MouseArea {
          id: backArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
        if (root.stack.length > 0) root.stack = root.stack.slice(0, -1)
        else root.closeRequested()
      }
        }
      }

      Image {
        visible: root.stack.length === 0 && root.trayItem !== null
        Layout.preferredWidth: 20
        Layout.preferredHeight: 20

        sourceSize.width: Math.ceil(20 * Math.max(1, Screen.devicePixelRatio))
        sourceSize.height: Math.ceil(20 * Math.max(1, Screen.devicePixelRatio))
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        smooth: true
        mipmap: true
        source: root.trayItem ? root.trayItem.icon : ""
      }

      Text {
        Layout.fillWidth: true
        text: root.title
        color: Theme.text
        font.bold: true
        font.pixelSize: Theme.fs(13)
        elide: Text.ElideRight
        font.family: Theme.fontFamily
      }
    }

    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }

    // ── Lista de entradas ──────────────────────────────────
    Flickable {
      id: flick
      Layout.fillWidth: true
      Layout.preferredHeight: Math.min(list.implicitHeight, root.maxListHeight)
      contentWidth: width
      contentHeight: list.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds

      ColumnLayout {
        id: list
        width: flick.width
        spacing: 2

        Repeater {
          model: opener.children

          delegate: Item {
            id: er
            required property var modelData

            readonly property bool sep: modelData.isSeparator
            readonly property bool checkable:
              modelData.buttonType !== undefined
              && modelData.buttonType !== QsMenuButtonType.None

            Layout.fillWidth: true
            Layout.preferredHeight: er.sep ? 9 : root.rowHeight


            Rectangle {
              visible: er.sep
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: 6
              anchors.rightMargin: 6
              height: 1
              color: Theme.divider
            }


            Rectangle {
              visible: !er.sep
              anchors.fill: parent
              radius: 10
              color: (rowArea.containsMouse && er.modelData.enabled) ? Theme.surface : "transparent"
              Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 8


                Item {
                  Layout.preferredWidth: 18
                  Layout.preferredHeight: 18

                  Text {
                    anchors.centerIn: parent
                    visible: er.checkable
                    text: er.modelData.checkState === Qt.Checked ? "󰄬" : ""
                    color: Theme.primary
                    font.pixelSize: Theme.fs(14)
                    font.family: Theme.monoFamily
                  }

                  Image {
                    anchors.fill: parent
                    visible: !er.checkable && er.modelData.icon !== ""
                    sourceSize.width: Math.ceil(width * Math.max(1, Screen.devicePixelRatio))
                    sourceSize.height: Math.ceil(height * Math.max(1, Screen.devicePixelRatio))
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    smooth: true
                    mipmap: true
                    source: er.modelData.icon
                  }
                }

                Text {
                  Layout.fillWidth: true
                  text: er.modelData.text
                  color: er.modelData.enabled ? Theme.text : Theme.subtext
                  font.pixelSize: Theme.fs(12)
                  elide: Text.ElideRight
                  font.family: Theme.fontFamily
                }

                Text {
                  visible: er.modelData.hasChildren
                  text: "󰅂"
                  color: Theme.subtext
                  font.pixelSize: Theme.fs(13)
                  font.family: Theme.monoFamily
                }
              }

              MouseArea {
                id: rowArea
                anchors.fill: parent
                hoverEnabled: true
                enabled: er.modelData.enabled
                cursorShape: Qt.PointingHandCursor

                onClicked: {
                  if (er.modelData.hasChildren) {
                    root.stack = root.stack.concat([er.modelData])
                  } else {
                    er.modelData.triggered()
                    root.closeRequested()
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
