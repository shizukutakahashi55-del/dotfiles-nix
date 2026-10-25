// LockDashNotifs

import QtQuick
import QtQuick.Layouts
import "../../COMMON"
import "../../Services/Lang"
import "../../Services/Notify"

LockDashSection {
  id: root

  property bool active: true
  property string mode: "apps"
  property int maxItems: 4

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

  // ── Sección ──
  shown: root.active && root.ready
  icon: String.fromCodePoint(0xF009A)
  title: Translations.t("notifTitle")
  trailing: String(root.live.length)
  trailingColor: Theme.primary
  bodySpacing: Math.round(8 * root.unit)

  // ── Solo aplicaciones ──
  Repeater {
    model: root.mode === "apps" ? root.shownApps : []

    delegate: RowLayout {
      required property var modelData
      Layout.fillWidth: true
      spacing: Math.round(10 * root.unit)

      AppIcon {
        Layout.alignment: Qt.AlignVCenter
        size: Math.round(26 * root.unit)
        icon: modelData.icon
        appId: modelData.id
      }
      Text {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        text: modelData.name
        color: Theme.text
        font.pixelSize: Math.round(13 * root.unit)
        font.bold: true
        font.family: Theme.fontFamily
        elide: Text.ElideRight
      }
      Rectangle {
        Layout.alignment: Qt.AlignVCenter
        Layout.preferredWidth: Math.max(height, badge.implicitWidth + Math.round(14 * root.unit))
        Layout.preferredHeight: Math.round(20 * root.unit)
        radius: Theme.cozy ? 4 : height / 2
        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2)

        Text {
          id: badge
          anchors.centerIn: parent
          text: modelData.count
          color: Theme.primary
          font.pixelSize: Math.round(11 * root.unit)
          font.bold: true
          font.family: Theme.fontFamily
        }
      }
    }
  }

  // ── Solo notificaciones ──
  Repeater {
    model: root.mode === "notifs" ? root.recent : []

    delegate: ColumnLayout {
      id: entry
      required property var modelData
      required property int index
      readonly property string bodyText: root.plain(modelData.body)

      Layout.fillWidth: true
      spacing: Math.round(8 * root.unit)

      Rectangle {
        visible: entry.index > 0
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: Theme.divider
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Math.round(10 * root.unit)

        AppIcon {
          Layout.alignment: Qt.AlignTop
          size: Math.round(26 * root.unit)
          icon: entry.modelData.appIcon
          appId: entry.modelData.appName
        }

        ColumnLayout {
          Layout.fillWidth: true
          Layout.minimumWidth: 0
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
