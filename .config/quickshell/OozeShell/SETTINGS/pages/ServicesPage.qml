// ServicesPage — categoría "Servicios": Tachidesk (server de manga/anime, manejado
// con el comando `tachidesk {start,stop,restart,status}` que ya existe en el
// sistema).
//
// Migrada desde AdvancedSettings.qml (paso 3 de SIGUIENTE_FASE.md): el estado, los
// Process y el Timer de Tachidesk viven ACÁ, ya no en el marco. La página solo
// existe mientras la categoría está elegida, así que el poll se corta solo al
// cambiar de categoría; `page.active` además lo corta al cerrar la ventana.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import ".."
import "../../COMMON"
import "../../LANG"

SettingsPage {
  id: page
  catId: "services"

  // ── Tachidesk (server de manga/anime, manejado con el comando
  // `tachidesk {start,stop,status}` que ya existe en el sistema) ──
  // Mismo patrón que las acciones de NETWORK/NetworkBackend.qml: un
  // Process para consultar estado, otro para la acción, y un Timer que
  // refresca la salida mientras esta categoría está abierta.
  property string tachideskStatusText: ""
  property string tachideskLastUpdate: ""
  property string tachideskLastAction: ""
  property bool tachideskRunning: false
  property bool tachideskBusy: false
  property bool tachideskKnown: false

  // La salida de "tachidesk status" es la de systemctl: busca la línea
  // "Active: active (running)" / "Active: inactive (dead)".
  function tachideskParseActive(text) {
    const m = text.match(/Active:\s*(\S+)/)
    return m ? m[1] === "active" : false
  }

  function tachideskHtmlEscape(s) {
    return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
  }

  // Coloreado línea por línea al estilo de una terminal real: no es
  // sintaxis de systemd completa, solo lo que hace que de un vistazo se
  // note si está corriendo, si hay un warning o un error.
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

  // Después de start/stop/restart, systemd tarda un pelo en reflejar el
  // nuevo estado — mismo margen que afterActionTimer en NetworkBackend.
  Timer { id: tachideskAfterActionTimer; interval: 500; repeat: false; onTriggered: page.tachideskRefreshStatus() }

  // Poll periódico, solo mientras el panel está abierto y parado en
  // "Servicios" (igual criterio que `watching` en NetworkBackend: no
  // interesa gastar procesos de fondo si nadie está mirando).
  Timer {
    interval: 3000
    repeat: true
    triggeredOnStart: true
    running: page.active
    onTriggered: page.tachideskRefreshStatus()
  }

  // ── Tarjeta de Tachidesk ──
  // Encabezado propio (ícono + nombre + badge), por eso sin titleKey.
  SettingsSection {
    spacing: 14

    // ── Encabezado: ícono grande + nombre + estado ──
    RowLayout {
      Layout.fillWidth: true
      spacing: 12

      SkinRect {
        Layout.preferredWidth: 40
        Layout.preferredHeight: 40
        radius: 12
        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.14)
        Text {
          anchors.centerIn: parent
          text: "󰇜"
          color: Theme.primary
          font.pixelSize: Theme.fs(19)
          font.family: Theme.monoFamily
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 1
        Text {
          text: Translations.t("advTachideskTitle")
          color: Theme.text
          font.bold: true
          font.pixelSize: Theme.fs(14)
          font.family: Theme.fontFamily
        }
        Text {
          Layout.fillWidth: true
          text: Translations.t("advTachideskHint")
          wrapMode: Text.WordWrap
          color: Theme.subtext
          font.pixelSize: Theme.fs(10)
          font.family: Theme.fontFamily
        }
      }

      // ── Badge de estado (pastilla con fondo tintado) ──
      SkinRect {
        id: statusBadge
        readonly property color tint: !page.tachideskKnown ? Theme.subtext
                                     : (page.tachideskRunning ? Theme.primary : Theme.error)
        Layout.preferredWidth: badgeRow.implicitWidth + 20
        Layout.preferredHeight: 26
        radius: 13
        color: Qt.rgba(tint.r, tint.g, tint.b, 0.14)
        Behavior on color { ColorAnimation { duration: Theme.animDuration(200) } }

        RowLayout {
          id: badgeRow
          anchors.centerIn: parent
          spacing: 6

          Rectangle {
            id: statusDot
            Layout.preferredWidth: 7
            Layout.preferredHeight: 7
            radius: Theme.cozy ? 0 : 3.5
            color: statusBadge.tint
            Behavior on color { ColorAnimation { duration: Theme.animDuration(200) } }

            SequentialAnimation on opacity {
              running: (page.tachideskBusy || !page.tachideskKnown) && Theme.uiAnimationsEnabled
              loops: Animation.Infinite
              NumberAnimation { from: 1.0; to: 0.25; duration: Theme.animDuration(550); easing.type: Easing.InOutQuad }
              NumberAnimation { from: 0.25; to: 1.0; duration: Theme.animDuration(550); easing.type: Easing.InOutQuad }
            }
          }
          Text {
            text: page.tachideskBusy ? Translations.t("advTachideskWorking")
                : (!page.tachideskKnown ? Translations.t("advTachideskUnknown")
                : (page.tachideskRunning ? Translations.t("advTachideskActive")
                                          : Translations.t("advTachideskInactive")))
            color: statusBadge.tint
            font.pixelSize: Theme.fs(10)
            font.bold: true
            font.family: Theme.fontFamily
          }
        }
      }
    }

    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }

    // ── Acciones ──
    RowLayout {
      Layout.fillWidth: true
      spacing: 8

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

      Item { Layout.fillWidth: true }

      // ── Refrescar: ghost button, solo ícono, gira mientras consulta ──
      SkinRect {
        id: refreshBtn
        Layout.preferredWidth: 32
        Layout.preferredHeight: 32
        radius: 9
        color: refreshArea.containsMouse ? Theme.surfaceHigh : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }

        Text {
          id: refreshIcon
          anchors.centerIn: parent
          text: "󰑐"
          color: Theme.subtext
          font.pixelSize: Theme.fs(14)
          font.family: Theme.monoFamily
          RotationAnimation on rotation {
            running: tachideskStatusProc.running && Theme.uiAnimationsEnabled
            loops: Animation.Infinite
            from: 0; to: 360
            duration: Theme.animDuration(700)
          }
        }
        MouseArea {
          id: refreshArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: page.tachideskRefreshStatus()
        }
      }
    }

    // ── "Terminal": barra con semáforo + salida coloreada ──
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

          Item { Layout.preferredWidth: 4 }

          Text {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: Translations.t("advTachideskOutputTitle")
            color: Theme.subtext
            font.pixelSize: Theme.fs(10)
            font.family: Theme.fontFamily
          }

          Text {
            visible: page.tachideskLastUpdate !== ""
            text: page.tachideskLastUpdate
            color: Theme.subtext
            opacity: 0.7
            font.pixelSize: Theme.fs(9)
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

          // Autoscroll al fondo cada vez que llega salida nueva
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
            font.pixelSize: Theme.fs(10)
            font.family: Theme.monoFamily
          }
        }
      }
    }
  }
}
