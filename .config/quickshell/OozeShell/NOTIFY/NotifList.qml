// NotifList — contenido del centro de notificaciones (título, No molestar y lista agrupada por app). No dibuja fondo: lo aloja quien lo use.

import Quickshell
import QtQuick
import QtQuick.Layouts
import "../COMMON"
import "../LANG"
import "../NOTIFY"

Item {
  id: root


  property real maxListHeight: 400

  property bool listActive: false

  property bool entriesAnimated: false

  property bool showClose: false
  signal closeRequested()

  readonly property int pad: 16
  implicitHeight: col.implicitHeight + root.pad * 2

  property real listH: 0
  Behavior on listH { NumberAnimation { duration: Theme.animDuration(180); easing.type: Easing.OutCubic } }
  readonly property real listTarget: Math.min(listCol.height, root.maxListHeight)
  onListTargetChanged: root.listH = root.listTarget


  property var collapsed: ({})
  function toggleGroup(key) {
    const c = Object.assign({}, root.collapsed)
    c[key] = !c[key]
    root.collapsed = c
  }

      ColumnLayout {
        id: col
        x: root.pad
        y: root.pad
        width: parent.width - root.pad * 2
        spacing: 10

        // ── Título + limpiar todo ────────────────────────────
        RowLayout {
          Layout.fillWidth: true
          spacing: 8


          Rectangle {
            visible: root.showClose
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
              onClicked: root.closeRequested()
            }
          }

          Text {
            text: "󰂚"
            color: Theme.primary
            font.pixelSize: Theme.fs(18)
            font.family: Theme.monoFamily
          }

          Text {
            text: Translations.t("notifTitle")
            color: Theme.text
            font.bold: true
            font.pixelSize: Theme.fs(14)
            font.family: Theme.fontFamily
          }

          Rectangle {
            visible: NotificationsBackend.count > 0
            Layout.preferredHeight: 18
            Layout.preferredWidth: Math.max(20, countText.implicitWidth + 12)
            radius: 9
            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.22)

            Text {
              id: countText
              anchors.centerIn: parent
              text: NotificationsBackend.count
              color: Theme.primary
              font.bold: true
              font.pixelSize: Theme.fs(10)
              font.family: Theme.fontFamily
            }
          }

          Item { Layout.fillWidth: true }

          Rectangle {
            visible: NotificationsBackend.count > 0
            Layout.preferredHeight: 26
            Layout.preferredWidth: clearRow.implicitWidth + 20
            radius: 8
            color: clearArea.containsMouse ? Theme.surfaceHigh : Theme.surface
            Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }

            RowLayout {
              id: clearRow
              anchors.centerIn: parent
              spacing: 6

              Text {
                text: "󰎟"
                color: Theme.primary
                font.pixelSize: Theme.fs(13)
                font.family: Theme.monoFamily
              }
              Text {
                text: Translations.t("notifClear")
                color: Theme.text
                font.pixelSize: Theme.fs(11)
                font.family: Theme.fontFamily
              }
            }

            MouseArea {
              id: clearArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: NotificationsBackend.clearAll()
            }
          }
        }

        // ── No molestar ──────────────────────────────────────
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: 44
          radius: Theme.cardRadius
          color: dndArea.containsMouse ? Theme.surfaceHigh : Theme.surface
          Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }

          RowLayout {
            anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
            spacing: 10

            Text {
              text: "󰂛"
              color: NotificationsBackend.dnd ? Theme.primary : Theme.subtext
              font.pixelSize: Theme.fs(16)
              font.family: Theme.monoFamily
              Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
            }

            Text {
              text: Translations.t("notifDnd")
              color: Theme.text
              font.pixelSize: Theme.fs(12)
              font.family: Theme.fontFamily
            }

            Item { Layout.fillWidth: true }


            Rectangle {
              Layout.preferredWidth: 40
              Layout.preferredHeight: 22
              radius: 11
              color: NotificationsBackend.dnd ? Theme.primary : Theme.surfaceHigh
              Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }

              Rectangle {
                width: 16
                height: 16
                radius: 8
                anchors.verticalCenter: parent.verticalCenter
                x: NotificationsBackend.dnd ? 21 : 3
                color: NotificationsBackend.dnd ? Theme.textOnPrimary : Theme.subtext
                Behavior on x { NumberAnimation { duration: Theme.animDuration(150); easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
              }
            }
          }

          MouseArea {
            id: dndArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: NotificationsBackend.toggleDnd()
          }
        }

        // ── Estado vacío ─────────────────────────────────────
        ColumnLayout {
          visible: NotificationsBackend.count === 0
          Layout.fillWidth: true
          Layout.topMargin: 14
          Layout.bottomMargin: 14
          spacing: 6

          Text {
            Layout.alignment: Qt.AlignHCenter
            text: NotificationsBackend.dnd ? "󰂛" : "󰂚"
            color: Theme.subtext
            font.pixelSize: Theme.fs(30)
            font.family: Theme.monoFamily
          }
          Text {
            Layout.alignment: Qt.AlignHCenter
            text: Translations.t("notifEmpty")
            color: Theme.subtext
            font.pixelSize: Theme.fs(11)
            font.family: Theme.fontFamily
          }
        }

        // ── Lista agrupada por app ───────────────────────────


        Flickable {
          id: list
          visible: NotificationsBackend.count > 0
          Layout.fillWidth: true
          Layout.preferredHeight: root.listH
          contentWidth: width
          contentHeight: listCol.height
          clip: true
          boundsBehavior: Flickable.StopAtBounds


          readonly property bool animateEntries: root.entriesAnimated

          readonly property int maxRows: 100
          readonly property var rows: root.listActive ? NotificationsBackend.displayOrdered : []

          Column {
            id: listCol
            width: list.width
            spacing: 0

            Repeater {
              model: ScriptModel { values: list.rows.slice(0, list.maxRows); objectProp: "notifId" }

              delegate: Item {
                id: entry
                required property var modelData
                readonly property bool isCollapsed: root.collapsed[entry.modelData.groupKey] === true
                readonly property bool leaving: entry.modelData.leaving === true


                property real reveal: list.animateEntries ? 0 : 1
                Behavior on reveal {
                  NumberAnimation { duration: Theme.animDuration(200); easing.type: entry.leaving ? Easing.InCubic : Easing.OutCubic }
                }
                Component.onCompleted: entry.reveal = 1
                onLeavingChanged: { if (entry.leaving) entry.reveal = 0 }

                width: listCol.width
                height: entryCol.implicitHeight * entry.reveal
                opacity: entry.reveal
                clip: entry.reveal < 0.999

                enabled: !entry.leaving

                  Column {
                    id: entryCol
                    width: parent.width
                    spacing: 0

                    x: (1 - entry.reveal) * (entry.leaving ? 80 : 40)


                    Item {
                      id: hdr
                      readonly property bool shown: entry.modelData.groupFirst
                      width: parent.width
                      height: shown ? 34 : 0
                      clip: true
                      opacity: shown ? 1 : 0
                      Behavior on height { NumberAnimation { duration: Theme.animDuration(140); easing.type: Easing.OutCubic } }
                      Behavior on opacity { NumberAnimation { duration: Theme.animDuration(120) } }

                      MouseArea {
                        anchors.fill: parent
                        enabled: hdr.shown
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleGroup(entry.modelData.groupKey)
                      }

                      RowLayout {
                        anchors { fill: parent; leftMargin: 4; rightMargin: 2 }
                        spacing: 8

                        Item {
                          Layout.preferredWidth: 18
                          Layout.preferredHeight: 18

                          Image {
                            id: hdrIcon
                            anchors.fill: parent
                            source: entry.modelData.iconSource
                            sourceSize: Qt.size(36, 36)
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            visible: status === Image.Ready
                          }
                          Text {
                            anchors.centerIn: parent
                            visible: !hdrIcon.visible
                            text: "󰂚"
                            color: Theme.subtext
                            font.pixelSize: Theme.fs(14)
                            font.family: Theme.monoFamily
                          }
                        }

                        Text {
                          text: entry.modelData.appName !== "" ? entry.modelData.appName : Translations.t("notifSystem")
                          color: Theme.text
                          font.bold: true
                          font.pixelSize: Theme.fs(12)
                          font.family: Theme.fontFamily
                        }

                        Rectangle {
                          visible: entry.modelData.groupCount > 1
                          Layout.preferredHeight: 16
                          Layout.preferredWidth: Math.max(18, grpCount.implicitWidth + 10)
                          radius: 8
                          color: Theme.surfaceHigh

                          Text {
                            id: grpCount
                            anchors.centerIn: parent
                            text: entry.modelData.groupCount
                            color: Theme.subtext
                            font.pixelSize: Theme.fs(9)
                            font.bold: true
                            font.family: Theme.fontFamily
                          }
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                          text: entry.isCollapsed ? "󰅂" : "󰅀"
                          color: Theme.subtext
                          font.pixelSize: Theme.fs(13)
                          font.family: Theme.monoFamily
                        }

                        Item {
                          Layout.preferredWidth: 20
                          Layout.preferredHeight: 20

                          Text {
                            anchors.centerIn: parent
                            text: "󰅖"
                            color: grpCloseArea.containsMouse ? Theme.error : Theme.subtext
                            font.pixelSize: Theme.fs(13)
                            font.family: Theme.monoFamily
                            Behavior on color { ColorAnimation { duration: Theme.animDuration(100) } }
                          }

                          MouseArea {
                            id: grpCloseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: NotificationsBackend.clearGroup(entry.modelData.groupKey)
                          }
                        }
                      }
                    }


                    Item {
                      id: cardWrap
                      width: parent.width
                      height: entry.isCollapsed ? 0 : cardItem.implicitHeight + 8
                      clip: true


                      Behavior on height { NumberAnimation { duration: Theme.animDuration(140); easing.type: Easing.OutCubic } }

                      NotifCard {
                        id: cardItem
                        width: parent.width
                        notif: entry.modelData
                        showApp: false
                      }
                    }
                  }
              }
            }


            Text {
              readonly property int extra: NotificationsBackend.displayOrdered.length - list.maxRows
              visible: extra > 0
              width: listCol.width
              height: visible ? implicitHeight + 10 : 0
              verticalAlignment: Text.AlignVCenter
              horizontalAlignment: Text.AlignHCenter
              text: "󰇘  +" + extra
              color: Theme.subtext
              font.pixelSize: Theme.fs(11)
              font.family: Theme.monoFamily
            }
          }
        }
      }
}
