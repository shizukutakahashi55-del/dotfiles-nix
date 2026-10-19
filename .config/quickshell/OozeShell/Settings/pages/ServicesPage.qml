// ServicesPage — categoría "Servicios": Tachidesk (server de manga/anime), manejado con el comando `tachidesk {start,stop,restart,status}`.

import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import ".."
import "../../COMMON"
import "../../Services/Lang"

SettingsPage {
  id: page
  catId: "services"

  // ── Tachidesk ──


  property string tachideskStatusText: ""
  property string tachideskLastUpdate: ""
  property string tachideskLastAction: ""
  property bool tachideskRunning: false
  property bool tachideskBusy: false
  property bool tachideskKnown: false


  function tachideskParseActive(text) {
    const m = text.match(/Active:\s*(\S+)/)
    return m ? m[1] === "active" : false
  }

  function tachideskHtmlEscape(s) {
    return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
  }


  function tachideskFormatOutput(text) {
    if (text === "") return ""
    return text.split("\n").map(line => {
      const esc = page.tachideskHtmlEscape(line)
      if (/Active:\s*active/i.test(line))
        return "<font color=\"" + Theme.primary + "\"><b>" + esc + "</b></font>"
      if (/Active:\s*(inactive|failed)/i.test(line))
        return "<font color=\"" + Theme.error + "\"><b>" + esc + "</b></font>"
      if (/\berror\b/i.test(line))
        return "<font color=\"" + Theme.error + "\">" + esc + "</font>"
      if (/\bwarn(ing)?\b/i.test(line))
        return "<font color=\"#e0a95a\">" + esc + "</font>"
      if (/^\s*(Loaded|Docs|Main PID|Process|Tasks|Memory|CPU):/i.test(line))
        return "<font color=\"" + Theme.text + "\">" + esc + "</font>"
      return "<font color=\"" + Theme.subtext + "\">" + esc + "</font>"
    }).join("<br>")
  }

  function tachideskRefreshStatus() {
    if (!tachideskStatusProc.running) tachideskStatusProc.running = true
  }

  function tachideskRunAction(action) {
    page.tachideskLastAction = action
    page.tachideskBusy = true
    tachideskActionProc.running = false
    tachideskActionProc.action = action
    tachideskActionProc.running = true
  }

  Process {
    id: tachideskStatusProc
    command: ["tachidesk", "status"]
    running: false
    property var lines: []
    stdout: SplitParser { onRead: line => tachideskStatusProc.lines.push(line) }
    stderr: SplitParser { onRead: line => tachideskStatusProc.lines.push(line) }
    onRunningChanged: {
      if (running) { lines = []; return }
      const text = lines.join("\n")
      page.tachideskStatusText = text
      page.tachideskRunning = page.tachideskParseActive(text)
      page.tachideskKnown = true
      page.tachideskLastUpdate = Qt.formatTime(new Date(), "hh:mm:ss")
    }
  }

  Process {
    id: tachideskActionProc
    property string action: ""
    command: ["tachidesk", action]
    running: false
    onRunningChanged: {
      if (running) return
      page.tachideskBusy = false
      tachideskAfterActionTimer.restart()
    }
  }


  Timer { id: tachideskAfterActionTimer; interval: 500; repeat: false; onTriggered: page.tachideskRefreshStatus() }


  Timer {
    interval: 3000
    repeat: true
    triggeredOnStart: true
    running: page.active
    onTriggered: page.tachideskRefreshStatus()
  }

  SettingsSection {
    titleKey: "advTachideskTitle"
    hintKey: "advTachideskHint"

    SettingsRow {
      title: page.tachideskBusy ? Translations.t("advTachideskWorking")
           : (!page.tachideskKnown ? Translations.t("advTachideskUnknown")
           : (page.tachideskRunning ? Translations.t("advTachideskActive")
                                     : Translations.t("advTachideskInactive")))
      hint: page.tachideskLastUpdate

      Rectangle {
        id: statusDot
        readonly property color tint: !page.tachideskKnown ? Theme.subtext
                                    : (page.tachideskRunning ? Theme.primary : Theme.error)
        Layout.preferredWidth: 9
        Layout.preferredHeight: 9
        Layout.alignment: Qt.AlignVCenter
        radius: Theme.cozy ? 0 : 4.5
        color: statusDot.tint
        Behavior on color { ColorAnimation { duration: Theme.animDuration(200) } }

        SequentialAnimation on opacity {
          running: (page.tachideskBusy || !page.tachideskKnown) && Theme.uiAnimationsEnabled
          loops: Animation.Infinite
          NumberAnimation { from: 1.0; to: 0.25; duration: Theme.animDuration(550); easing.type: Easing.InOutQuad }
          NumberAnimation { from: 0.25; to: 1.0; duration: Theme.animDuration(550); easing.type: Easing.InOutQuad }
        }
      }

      SettingsIconBtn {
        spinning: tachideskStatusProc.running
        onClicked: page.tachideskRefreshStatus()
      }
    }

    SettingsRow {
      stacked: true

      SettingsBtn {
        text: Translations.t("advTachideskStart")
        icon: "󰐊"
        primary: true
        enabled: !page.tachideskBusy && !page.tachideskRunning
        onClicked: page.tachideskRunAction("start")
      }
      SettingsBtn {
        text: Translations.t("advTachideskStop")
        icon: "󰓛"
        enabled: !page.tachideskBusy && page.tachideskRunning
        onClicked: page.tachideskRunAction("stop")
      }
      SettingsBtn {
        text: Translations.t("advTachideskRestart")
        icon: "󰜉"
        enabled: !page.tachideskBusy
        onClicked: page.tachideskRunAction("restart")
      }
    }
  }

  SettingsSection {
    titleKey: "advTachideskOutputTitle"

    SettingsRow {
      stacked: true
      divider: false

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: 28
          topLeftRadius: 10
          topRightRadius: 10
          color: Qt.darker(Theme.bg, 1.08)

          RowLayout {
            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
            spacing: 6

            Repeater {
              model: ["#ff5f56", "#ffbd2e", "#27c93f"]
              delegate: Rectangle {
                required property string modelData
                Layout.preferredWidth: 9
                Layout.preferredHeight: 9
                radius: Theme.cozy ? 0 : 4.5
                color: modelData
                opacity: 0.85
              }
            }

            Item { Layout.fillWidth: true }

            Text {
              visible: page.tachideskLastUpdate !== ""
              text: page.tachideskLastUpdate
              color: Theme.subtext
              opacity: 0.7
              font.pixelSize: Theme.sfs(9)
              font.family: Theme.fontFamily
            }
          }
        }

        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: 168
          color: Theme.bg
          bottomLeftRadius: 10
          bottomRightRadius: 10
          border.width: Theme.bw1
          border.color: Theme.edge
          clip: true

          Flickable {
            id: consoleFlick
            anchors { fill: parent; margins: 12 }
            contentWidth: width
            contentHeight: consoleText.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Behavior on contentY { NumberAnimation { duration: Theme.animDuration(160); easing.type: Easing.OutCubic } }

            onContentHeightChanged: Qt.callLater(() => {
              consoleFlick.contentY = Math.max(0, consoleFlick.contentHeight - consoleFlick.height)
            })

            Text {
              id: consoleText
              width: consoleFlick.width
              textFormat: Text.RichText
              text: page.tachideskStatusText !== ""
                ? page.tachideskFormatOutput(page.tachideskStatusText)
                : "<font color=\"" + Theme.subtext + "\">" + Translations.t("advTachideskNoOutput") + "</font>"
              wrapMode: Text.Wrap
              lineHeight: 1.35
              font.pixelSize: Theme.sfs(10)
              font.family: Theme.monoFamily
            }
          }
        }
      }
    }
  }
}
