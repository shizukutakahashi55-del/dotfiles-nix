import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Item {
  id: mprisRoot

  property bool open: false
  signal closeRequested()

  property string targetScreen: "DP-3"

  // ─── Colores desde matugen ────────────────────────────────────
  property var colors: ({
    bg:      "#0d0e11",
    border:  "#4a90d9",
    accent:  "#4a90d9",
    text:    "#e1e2e8",
    subtext: "#8e9ab0",
    btn:     "#1e2030"
  })

  Timer {
    id: startupDelay
    interval: 3000
    running: true
    repeat: false
    onTriggered: loadColors.running = true
  }

  Process {
    id: loadColors
    command: ["cat", "/tmp/matugen-colors.json"]
    running: false
    property string buffer: ""
    stdout: SplitParser {
      onRead: line => loadColors.buffer += line
    }
    onRunningChanged: {
      if (!running && buffer !== "") {
        try {
          const palette = JSON.parse(buffer)
          const c = palette.colors
          mprisRoot.colors = {
            bg:      c.background.dark.color,
            border:  c.primary.dark.color,
            accent:  c.primary.dark.color,
            text:    c.on_background.dark.color,
            subtext: c.secondary.dark.color,
            btn:     c.surface_container.dark.color
          }
        } catch(e) {
          console.log("mpris color parse error:", e)
        }
        buffer = ""
      }
    }
  }

  Timer {
    interval: 3000
    running: true
    repeat: true
    onTriggered: {
      loadColors.running = false
      loadColors.running = true
    }
  }

  // ─── Metadata ────────────────────────────────────────────────
  property string currentTitle: "Sin reproducción"
  property string currentArtist: ""
  property string currentArt: ""
  property string currentStatus: "Stopped"
  property int currentPosition: 0
  property int currentLength: 0
  property var activePlayers: []
  property int activePlayerIndex: 0

  // Listar players cada 3s
  Process {
    id: listPlayersProc
    command: ["playerctl", "--list-all"]
    running: true
    property string buffer: ""
    property var found: []
    stdout: SplitParser {
      onRead: line => {
        const p = line.trim()
        if (p !== "") listPlayersProc.found = [...listPlayersProc.found, p]
      }
    }
    onRunningChanged: {
      if (!running) {
        if (listPlayersProc.found.length > 0) {
          mprisRoot.activePlayers = listPlayersProc.found
          if (mprisRoot.activePlayerIndex >= mprisRoot.activePlayers.length)
            mprisRoot.activePlayerIndex = 0
          metadataProc.running = true
        }
        listPlayersProc.found = []
        listPlayersProc.buffer = ""
      }
    }
  }

  Timer {
    interval: 3000
    running: true
    repeat: true
    onTriggered: listPlayersProc.running = true
  }

  Process {
    id: metadataProc
    property string player: mprisRoot.activePlayers.length > 0
      ? mprisRoot.activePlayers[mprisRoot.activePlayerIndex] ?? "spotify"
      : "spotify"
    command: ["playerctl", "--player=" + player, "metadata", "--format",
      "{{artist}}|{{title}}|{{mpris:artUrl}}|{{status}}|{{position}}|{{mpris:length}}"]
    running: false
    stdout: SplitParser {
      onRead: data => {
        var parts = data.split("|")
        if (parts.length >= 6) {
          mprisRoot.currentArtist   = parts[0]
          mprisRoot.currentTitle    = parts[1]
          mprisRoot.currentArt      = parts[2]
          mprisRoot.currentStatus   = parts[3].trim()
          mprisRoot.currentPosition = parseInt(parts[4]) || 0
          mprisRoot.currentLength   = parseInt(parts[5]) || 0
        }
      }
    }
  }

  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: metadataProc.running = true
  }

  // ─── Helpers ─────────────────────────────────────────────────
  function formatTime(us) {
    const s = Math.floor(us / 1000000)
    const m = Math.floor(s / 60)
    const r = s % 60
    return m + ":" + (r < 10 ? "0" : "") + r
  }

  function playerIcon(name) {
    if (name.includes("spotify"))  return "󰓇"
    if (name.includes("firefox"))  return "󰈹"
    if (name.includes("chrome"))   return "󰊯"
    if (name.includes("mpv"))      return "󰚺"
    if (name.includes("vlc"))      return "󰕼"
    return "󰝚"
  }

  // ─── Un solo PanelWindow fullscreen ──────────────────────────
  PanelWindow {
    id: mainPanel
    screen: Quickshell.screens.find(s => s.name === mprisRoot.targetScreen) ?? Quickshell.screens[0]
    visible: mprisRoot.open
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.namespace: "mpris-panel"
    anchors { top: true; left: true; right: true; bottom: true }
    color: "transparent"
    exclusiveZone: -1

    // Fondo semitransparente — click fuera cierra
    Rectangle {
      anchors.fill: parent
      color: "transparent"

      MouseArea {
        anchors.fill: parent
        onClicked: mprisRoot.closeRequested()
        z: 0
      }

      // Tecla Escape cierra
      focus: mprisRoot.open
      Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
          mprisRoot.closeRequested()
          event.accepted = true
        }
      }

      // ─── Card del panel ──────────────────────────────────────
      Rectangle {
        x: 78
        y: 32
        width: 380
        height: 200
        radius: 18
        color: mprisRoot.colors.bg
        border.color: mprisRoot.colors.border
        border.width: 1
        z: 1

        Behavior on color        { ColorAnimation { duration: 400 } }
        Behavior on border.color { ColorAnimation { duration: 400 } }

        // Bloquear clicks dentro del card
        MouseArea {
          anchors.fill: parent
          onClicked: {}
        }

        ColumnLayout {
          anchors { fill: parent; margins: 14 }
          spacing: 10

          // ─── Fila superior ────────────────────────────────────
          RowLayout {
            Layout.fillWidth: true
            spacing: 14

            // Prev player
            Button {
              text: "‹"
              flat: true
              visible: mprisRoot.activePlayers.length > 1
              onClicked: {
                mprisRoot.activePlayerIndex = (mprisRoot.activePlayerIndex - 1 + mprisRoot.activePlayers.length) % mprisRoot.activePlayers.length
                metadataProc.running = true
              }
              contentItem: Text {
                text: parent.text
                color: mprisRoot.colors.accent
                font.pixelSize: 20
                horizontalAlignment: Text.AlignHCenter
                Behavior on color { ColorAnimation { duration: 400 } }
              }
              background: Rectangle {
                color: parent.hovered ? Qt.rgba(1,1,1,0.10) : "transparent"
                radius: 8
              }
              implicitWidth: 24
            }

            // Album art
            Rectangle {
              width: 88; height: 88
              radius: 12
              color: mprisRoot.colors.btn
              clip: true
              Behavior on color { ColorAnimation { duration: 400 } }

              Image {
                id: albumArt
                anchors.fill: parent
                source: mprisRoot.currentArt
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
              }

              Text {
                anchors.centerIn: parent
                text: "󰝚"
                font.pixelSize: 36
                color: mprisRoot.colors.accent
                visible: albumArt.status !== Image.Ready
                Behavior on color { ColorAnimation { duration: 400 } }
              }
            }

            // Info
            ColumnLayout {
              Layout.fillWidth: true
              spacing: 3

              // Nombre del reproductor activo
              RowLayout {
                spacing: 4
                Text {
                  text: mprisRoot.activePlayers.length > 0
                    ? mprisRoot.playerIcon(mprisRoot.activePlayers[mprisRoot.activePlayerIndex] ?? "")
                    : "󰝚"
                  color: mprisRoot.colors.accent
                  font.pixelSize: 11
                  font.family: "JetBrainsMono Nerd Font"
                  Behavior on color { ColorAnimation { duration: 400 } }
                }
                Text {
                  text: mprisRoot.activePlayers.length > 0
                    ? (mprisRoot.activePlayers[mprisRoot.activePlayerIndex] ?? "").split(".")[0]
                    : "—"
                  color: mprisRoot.colors.subtext
                  font.pixelSize: 10
                  font.family: "JetBrainsMono Nerd Font"
                  Behavior on color { ColorAnimation { duration: 400 } }
                }
              }

              Text {
                Layout.fillWidth: true
                text: mprisRoot.currentTitle
                color: mprisRoot.colors.text
                font.pixelSize: 15
                font.bold: true
                elide: Text.ElideRight
                Behavior on color { ColorAnimation { duration: 400 } }
              }

              Text {
                Layout.fillWidth: true
                text: mprisRoot.currentArtist
                color: mprisRoot.colors.subtext
                font.pixelSize: 12
                elide: Text.ElideRight
                Behavior on color { ColorAnimation { duration: 400 } }
              }
            }

            // Next player
            Button {
              text: "›"
              flat: true
              visible: mprisRoot.activePlayers.length > 1
              onClicked: {
                mprisRoot.activePlayerIndex = (mprisRoot.activePlayerIndex + 1) % mprisRoot.activePlayers.length
                metadataProc.running = true
              }
              contentItem: Text {
                text: parent.text
                color: mprisRoot.colors.accent
                font.pixelSize: 20
                horizontalAlignment: Text.AlignHCenter
                Behavior on color { ColorAnimation { duration: 400 } }
              }
              background: Rectangle {
                color: parent.hovered ? Qt.rgba(1,1,1,0.10) : "transparent"
                radius: 8
              }
              implicitWidth: 24
            }
          }

          // ─── Barra de progreso ────────────────────────────────
          ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            Rectangle {
              Layout.fillWidth: true
              height: 4
              radius: 2
              color: Qt.rgba(1,1,1,0.10)

              Rectangle {
                width: mprisRoot.currentLength > 0
                  ? parent.width * (mprisRoot.currentPosition / mprisRoot.currentLength)
                  : 0
                height: parent.height
                radius: 2
                color: mprisRoot.colors.accent
                Behavior on width { NumberAnimation { duration: 800; easing.type: Easing.Linear } }
                Behavior on color { ColorAnimation  { duration: 400 } }
              }

              MouseArea {
                anchors.fill: parent
                onClicked: mouse => {
                  if (mprisRoot.currentLength > 0) {
                    const pos = Math.floor((mouse.x / width) * mprisRoot.currentLength)
                    seekCmd.seekPos = pos
                    seekCmd.running = true
                  }
                }
              }
            }

            RowLayout {
              Layout.fillWidth: true
              Text {
                text: mprisRoot.formatTime(mprisRoot.currentPosition)
                color: mprisRoot.colors.subtext
                font.pixelSize: 10
                font.family: "JetBrainsMono Nerd Font"
                Behavior on color { ColorAnimation { duration: 400 } }
              }
              Item { Layout.fillWidth: true }
              Text {
                text: mprisRoot.formatTime(mprisRoot.currentLength)
                color: mprisRoot.colors.subtext
                font.pixelSize: 10
                font.family: "JetBrainsMono Nerd Font"
                Behavior on color { ColorAnimation { duration: 400 } }
              }
            }
          }

          // ─── Controles ────────────────────────────────────────
          RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: 8

            Process {
              id: seekCmd
              property int seekPos: 0
              property string player: metadataProc.player
              command: ["playerctl", "--player=" + player, "position",
                String(Math.floor(seekPos / 1000000))]
              onRunningChanged: if (!running) metadataProc.running = true
            }
            Process {
              id: prevCmd
              property string player: metadataProc.player
              command: ["playerctl", "--player=" + player, "previous"]
              onRunningChanged: if (!running) metadataProc.running = true
            }
            Process {
              id: playCmd
              property string player: metadataProc.player
              command: ["playerctl", "--player=" + player, "play-pause"]
              onRunningChanged: if (!running) metadataProc.running = true
            }
            Process {
              id: nextCmd
              property string player: metadataProc.player
              command: ["playerctl", "--player=" + player, "next"]
              onRunningChanged: if (!running) metadataProc.running = true
            }

            Button {
              text: "⏮"; flat: true
              onClicked: prevCmd.running = true
              contentItem: Text {
                text: parent.text
                color: mprisRoot.colors.subtext
                font.pixelSize: 18
                horizontalAlignment: Text.AlignHCenter
                Behavior on color { ColorAnimation { duration: 400 } }
              }
              background: Rectangle {
                color: parent.hovered ? Qt.rgba(1,1,1,0.08) : "transparent"
                radius: 8
              }
              implicitWidth: 44; implicitHeight: 36
            }

            Button {
              flat: true
              onClicked: { playCmd.running = false; playCmd.running = true }
              contentItem: Text {
                text: mprisRoot.currentStatus === "Playing" ? "⏸" : "▶"
                color: mprisRoot.colors.bg
                font.pixelSize: 20
                horizontalAlignment: Text.AlignHCenter
                Behavior on color { ColorAnimation { duration: 400 } }
              }
              background: Rectangle {
                color: parent.hovered ? Qt.rgba(1,1,1,0.85) : mprisRoot.colors.accent
                radius: 10
                Behavior on color { ColorAnimation { duration: 200 } }
              }
              implicitWidth: 56; implicitHeight: 40
            }

            Button {
              text: "⏭"; flat: true
              onClicked: nextCmd.running = true
              contentItem: Text {
                text: parent.text
                color: mprisRoot.colors.subtext
                font.pixelSize: 18
                horizontalAlignment: Text.AlignHCenter
                Behavior on color { ColorAnimation { duration: 400 } }
              }
              background: Rectangle {
                color: parent.hovered ? Qt.rgba(1,1,1,0.08) : "transparent"
                radius: 8
              }
              implicitWidth: 44; implicitHeight: 36
            }
          }

          // ─── Dots de players ──────────────────────────────────
          Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: 6
            visible: mprisRoot.activePlayers.length > 1

            Repeater {
              model: mprisRoot.activePlayers.length
              delegate: Rectangle {
                width: index === mprisRoot.activePlayerIndex ? 20 : 6
                height: 6
                radius: 3
                color: index === mprisRoot.activePlayerIndex
                  ? mprisRoot.colors.accent
                  : mprisRoot.colors.btn
                Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation  { duration: 400 } }

                MouseArea {
                  anchors.fill: parent
                  onClicked: {
                    mprisRoot.activePlayerIndex = index
                    metadataProc.running = true
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
