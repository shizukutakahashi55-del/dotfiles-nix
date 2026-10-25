// LockNotifs

import QtQuick
import QtQuick.Layouts
import "../../COMMON"
import "../../Services/Lang"
import "../../Services/Notify"

SkinRect {
  id: root

  property real unit: 1
  property bool active: true
  property string mode: "apps"
  property int maxItems: 4
  property int cardWidth: Math.round(340 * root.unit)

  // ── Datos ──
  readonly property var live: NotificationsBackend.list.filter(n => !n.closed)
  readonly property var recent: root.live.slice(0, root.maxItems)
  readonly property var apps: {
    const order = []
    const map = {}
    for (const n of root.live) {
      const key = n.appName !== "" ? n.appName : "?"
      if (!map[key]) {
        map[key] = { name: key === "?" ? Translations.t("notifSystem") : key, icon: n.appIcon, id: n.appName, count: 0 }
        order.push(key)
      }
      map[key].count++
      if (map[key].icon === "" && n.appIcon !== "") map[key].icon = n.appIcon
    }
    return order.map(k => map[k])
  }
  readonly property var shownApps: root.apps.slice(0, root.maxItems)
  readonly property bool ready: root.mode === "apps" ? root.apps.length > 0
                              : root.mode === "notifs" ? root.live.length > 0
                              : false

  // ── Formato ──
  function plain(s) {
    return String(s ?? "")
      .replace(/<[^>]*>/g, "")
      .replace(/&lt;/g, "<")
      .replace(/&gt;/g, ">")
      .replace(/&quot;/g, "\"")
      .replace(/&amp;/g, "&")
      .trim()
  }

  // ── Geometría ──
  readonly property int pad: Math.round(14 * root.unit)
  readonly property int rowRadius: Theme.cozy ? 4 : Math.round(10 * root.unit)

  implicitWidth: root.cardWidth
  implicitHeight: body.implicitHeight + root.pad * 2

  radius: Theme.cardRadius
  color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.55)
  border.width: 1
  border.color: Qt.rgba(1, 1, 1, 0.14)

  visible: opacity > 0
  opacity: root.active && root.ready ? 1 : 0
  Behavior on opacity { NumberAnimation { duration: Theme.animDuration(280); easing.type: Easing.OutCubic } }

  // ── Contenido ──
  ColumnLayout {
    id: body
    anchors { left: parent.left; right: parent.right; top: parent.top; margins: root.pad }
    spacing: Math.round(10 * root.unit)

    // ── Cabecera ──
    Row {
      spacing: Math.round(8 * root.unit)

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "󰂚"
        color: Theme.primary
        font.pixelSize: Math.round(15 * root.unit)
        font.family: Theme.monoFamily
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: Translations.t("notifTitle").toUpperCase()
        color: Theme.subtext
        font.pixelSize: Math.round(11 * root.unit)
        font.bold: true
        font.letterSpacing: Math.round(2 * root.unit)
        font.family: Theme.fontFamily
      }
    }

    // ── Solo aplicaciones ──
    Repeater {
      model: root.mode === "apps" ? root.shownApps : []

      delegate: RowLayout {
        required property var modelData
        Layout.fillWidth: true
        spacing: Math.round(10 * root.unit)

        AppIcon {
          Layout.alignment: Qt.AlignVCenter
          size: Math.round(28 * root.unit)
          icon: modelData.icon
          appId: modelData.id
        }
        Text {
          Layout.fillWidth: true
          Layout.alignment: Qt.AlignVCenter
          text: modelData.name
          color: Theme.text
          font.pixelSize: Math.round(14 * root.unit)
          font.bold: true
          font.family: Theme.fontFamily
          elide: Text.ElideRight
        }
        Rectangle {
          Layout.alignment: Qt.AlignVCenter
          Layout.preferredWidth: Math.max(height, badge.implicitWidth + Math.round(14 * root.unit))
          Layout.preferredHeight: Math.round(22 * root.unit)
          radius: Theme.cozy ? 4 : height / 2
          color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2)

          Text {
            id: badge
            anchors.centerIn: parent
            text: modelData.count
            color: Theme.primary
            font.pixelSize: Math.round(12 * root.unit)
            font.bold: true
            font.family: Theme.fontFamily
          }
        }
      }
    }

    // ── Solo notificaciones ──
    Repeater {
      model: root.mode === "notifs" ? root.recent : []

      delegate: Rectangle {
        id: entry
        required property var modelData
        readonly property string bodyText: root.plain(modelData.body)

        Layout.fillWidth: true
        Layout.preferredHeight: entryRow.implicitHeight + Math.round(20 * root.unit)
        radius: root.rowRadius
        color: Qt.rgba(1, 1, 1, 0.06)

        RowLayout {
          id: entryRow
          anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter
                    leftMargin: Math.round(10 * root.unit); rightMargin: Math.round(10 * root.unit) }
          spacing: Math.round(10 * root.unit)

          AppIcon {
            Layout.alignment: Qt.AlignTop
            size: Math.round(28 * root.unit)
            icon: entry.modelData.appIcon
            appId: entry.modelData.appName
          }

          ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: Math.round(1 * root.unit)

            RowLayout {
              Layout.fillWidth: true
              spacing: Math.round(8 * root.unit)

              Text {
                Layout.fillWidth: true
                text: root.plain(entry.modelData.summary)
                color: Theme.text
                font.pixelSize: Math.round(13 * root.unit)
                font.bold: true
                font.family: Theme.fontFamily
                elide: Text.ElideRight
              }
              Text {
                text: entry.modelData.timeStr
                color: Theme.subtext
                font.pixelSize: Math.round(11 * root.unit)
                font.family: Theme.fontFamily
              }
            }
            Text {
              visible: entry.bodyText !== ""
              Layout.fillWidth: true
              text: entry.bodyText
              color: Theme.subtext
              font.pixelSize: Math.round(12 * root.unit)
              font.family: Theme.fontFamily
              textFormat: Text.PlainText
              wrapMode: Text.Wrap
              maximumLineCount: 2
              elide: Text.ElideRight
            }
          }
        }
      }
    }
  }
}
