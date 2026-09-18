import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../LANG"

Item {
  id: mprisRoot

  property bool open: false
  signal closeRequested()

  property string targetScreen: ""

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

  // Position Memorize--------

  property string posFilePath: "/tmp/mpris-panel-pos.json"
property real savedX: -1
property real savedY: -1

Process {
  id: loadPosProc
  command: ["cat", mprisRoot.posFilePath]
  running: true
  property string buffer: ""
  stdout: SplitParser { onRead: line => loadPosProc.buffer += line }
  onRunningChanged: {
    if (!running) {
      if (buffer !== "") {
        try {
          const pos = JSON.parse(buffer)
          if (typeof pos.x === "number") mprisRoot.savedX = pos.x
          if (typeof pos.y === "number") mprisRoot.savedY = pos.y
        } catch (e) {
          console.log("mpris pos parse error:", e)
        }
      }
      buffer = ""
    }
  }
}

Process {
  id: savePosProc
  property int posX: 0
  property int posY: 0
  command: ["sh", "-c", "echo '{\"x\":" + posX + ",\"y\":" + posY + "}' > " + mprisRoot.posFilePath]
}

Timer {
  id: posSaveTimer
  interval: 500
  repeat: false
  onTriggered: {
    savePosProc.posX = Math.round(cardContainer.x)
    savePosProc.posY = Math.round(cardContainer.y)
    savePosProc.running = false
    savePosProc.running = true
  }
}

  // ─── Metadata ────────────────────────────────────────────────
  property string currentTitle: ""
  property string currentArtist: ""
  property string currentArt: ""
  property string currentStatus: "Stopped"
  property int currentPosition: 0
  property int currentLength: 0
  property var activePlayers: []
  property int activePlayerIndex: 0

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
    const lower = name.toLowerCase()
    if (lower.includes("spotify")) return "󰓇"
    if (lower.includes("firefox")) return "󰈹"
    if (lower.includes("chrome"))  return "󰊯"
    if (lower.includes("brave"))   return "󰈹"
    if (lower.includes("mpv"))     return "󰚺"
    if (lower.includes("vlc"))     return "󰕼"
    return "󰝚"
  }

  function cleanPlayerName(name) {
    if (!name) return "—"
    let clean = name.split(".")[0]
    clean = clean.split("-")[0]
    return clean.charAt(0).toUpperCase() + clean.slice(1)
  }

      // ─── Panel overlay ──────────────────────────────────────────
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

        Item {
          anchors.fill: parent

          MouseArea {
            anchors.fill: parent
            onClicked: mprisRoot.closeRequested()
            z: 0
          }

          focus: mprisRoot.open
          Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
              mprisRoot.closeRequested()
              event.accepted = true
            }
          }

      // ─── Card Principal ─────────────────────────────────────
      Rectangle {
        id: cardContainer
          
        height: 380 // Mantiene su alto fijo
          anchors {
            top: parent.top
            topMargin: 40
            left: parent.left
            leftMargin: 45
            // Para la posición horizontal usas left o horizontalCenter
          }

          x: (parent.width - width) / 2
          y: (parent.height - height) / 2

          onXChanged: if (mprisRoot.open) posSaveTimer.restart()
          onYChanged: if (mprisRoot.open) posSaveTimer.restart()

        width: 460
       

        radius: 4
        color: mprisRoot.colors.bg
        border.color: Qt.rgba(1, 1, 1, 0.14)
        border.width: 1
        clip: true
        antialiasing: true
        layer.enabled: true
        layer.smooth: true
        z: 1

        scale: mprisRoot.open ? 1.0 : 0.92
        opacity: mprisRoot.open ? 1.0 : 0.0

        Behavior on scale   { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
        Behavior on opacity { NumberAnimation { duration: 200 } }
        Behavior on color   { ColorAnimation  { duration: 400 } }

        // Arrastrar
        MouseArea {
          id: dragArea
          anchors.fill: parent
          drag.target: cardContainer
          drag.axis: Drag.XAndYAxis
          drag.minimumX: 0
          drag.maximumX: mainPanel.width - cardContainer.width
          drag.minimumY: 0
          drag.maximumY: mainPanel.height - cardContainer.height
          cursorShape: dragArea.pressed ? Qt.ClosedHandCursor : Qt.ArrowCursor
        }

        // ─── ARTWORK BACKGROUND BLUR ──────────────────────────
        Item {
          anchors.fill: parent
          clip: true

          Image {
            anchors.fill: parent
            source: mprisRoot.currentArt
            fillMode: Image.PreserveAspectCrop
            opacity: 0.18
            visible: status === Image.Ready

            Behavior on opacity { NumberAnimation { duration: 500 } }
          }

          Rectangle {
            anchors.fill: parent
            gradient: Gradient {
              GradientStop { position: 0.0; color: Qt.rgba(0,0,0,0.3) }
              GradientStop { position: 1.0; color: Qt.rgba(0,0,0,0.75) }
            }
          }
        }

        ColumnLayout {
          anchors.fill: parent
          spacing: 0

          // ─── Header ─────────────────────────────────────────
          Item {
            Layout.fillWidth: true
            height: 56

            RowLayout {
              anchors { fill: parent; leftMargin: 20; rightMargin: 20 }
              spacing: 10

              Text {
                text: "󰝚"
                color: mprisRoot.colors.accent
                font.pixelSize: 20
                font.family: "JetBrainsMono Nerd Font"
                Behavior on color { ColorAnimation { duration: 400 } }
              }

              Text {
                text: Translations.t("Mpris")
                color: mprisRoot.colors.text
                font.pixelSize: 16
                font.bold: true
                Behavior on color { ColorAnimation { duration: 400 } }
              }

              Item { Layout.fillWidth: true }

              // Badge del Player Activo (Ajustado para no salir del borde)
              Rectangle {
                Layout.maximumWidth: 160
                height: 26
                implicitWidth: playerRow.implicitWidth + 16
                radius: 13
                color: Qt.rgba(1, 1, 1, 0.08)
                border.color: Qt.rgba(1, 1, 1, 0.12)
                border.width: 1
                clip: true

                RowLayout {
                  id: playerRow
                  anchors.centerIn: parent
                  anchors.leftMargin: 8
                  anchors.rightMargin: 8
                  spacing: 6

                  Text {
                    text: mprisRoot.activePlayers.length > 0
                      ? mprisRoot.playerIcon(mprisRoot.activePlayers[mprisRoot.activePlayerIndex] ?? "")
                      : "󰝚"
                    color: mprisRoot.colors.accent
                    font.pixelSize: 13
                    font.family: "JetBrainsMono Nerd Font"
                  }

                  Text {
                    Layout.maximumWidth: 110
                    text: mprisRoot.activePlayers.length > 0
                      ? mprisRoot.cleanPlayerName(mprisRoot.activePlayers[mprisRoot.activePlayerIndex])
                      : "—"
                    color: mprisRoot.colors.subtext
                    font.pixelSize: 11
                    font.bold: true
                    font.family: "JetBrainsMono Nerd Font"
                    elide: Text.ElideRight
                  }
                }
              }
            }

            Rectangle {
              anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
              height: 1
              color: Qt.rgba(1, 1, 1, 0.06)
            }
          }

          // ─── Cuerpo ─────────────────────────────────────────
          ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 20
            spacing: 16

            // Central Row: Switcher + Art + Info
            RowLayout {
              Layout.fillWidth: true
              spacing: 14

              // Prev player
              Rectangle {
                width: 32; height: 32
                radius: 16
                visible: mprisRoot.activePlayers.length > 1
                color: prevPlayerArea.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.06)
                border.color: Qt.rgba(1, 1, 1, 0.1)
                border.width: 1

                Text {
                  anchors.centerIn: parent
                  text: "󰅁"
                  color: mprisRoot.colors.text
                  font.pixelSize: 16
                  font.family: "JetBrainsMono Nerd Font"
                }

                MouseArea {
                  id: prevPlayerArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    mprisRoot.activePlayerIndex = (mprisRoot.activePlayerIndex - 1 + mprisRoot.activePlayers.length) % mprisRoot.activePlayers.length
                    metadataProc.running = true
                  }
                }
              }

              // Album art
              Rectangle {
                width: 110; height: 110
                radius: 16
                color: mprisRoot.colors.btn
                border.color: Qt.rgba(1, 1, 1, 0.15)
                border.width: 1
                clip: true

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
                  font.pixelSize: 38
                  font.family: "JetBrainsMono Nerd Font"
                  color: mprisRoot.colors.accent
                  visible: albumArt.status !== Image.Ready
                }

                // Mini Ecualizador
                Rectangle {
                  anchors { right: parent.right; bottom: parent.bottom; margins: 6 }
                  width: 32; height: 24
                  radius: 4
                  color: Qt.rgba(0, 0, 0, 0.65)
                  visible: mprisRoot.currentStatus === "Playing"

                  Row {
                    anchors.centerIn: parent
                    spacing: 2
                    Repeater {
                      model: 3
                      Rectangle {
                        width: 3
                        height: index === 0 ? 8 : (index === 1 ? 12 : 6)
                        radius: 1.5
                        color: mprisRoot.colors.accent

                        SequentialAnimation on height {
                          running: mprisRoot.currentStatus === "Playing"
                          loops: Animation.Infinite
                          NumberAnimation { to: 12; duration: 300 + index * 100 }
                          NumberAnimation { to: 4; duration: 300 + index * 100 }
                        }
                      }
                    }
                  }
                }
              }

              // Info Canción
              ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                  Layout.fillWidth: true
                  text: mprisRoot.currentTitle !== ""
                    ? mprisRoot.currentTitle
                    : Translations.t("mprisNoPlaying")
                  color: mprisRoot.colors.text
                  font.pixelSize: 16
                  font.bold: true
                  elide: Text.ElideRight
                  Behavior on color { ColorAnimation { duration: 400 } }
                }

                Text {
                  Layout.fillWidth: true
                  text: mprisRoot.currentArtist !== "" ? mprisRoot.currentArtist : "—"
                  color: mprisRoot.colors.subtext
                  font.pixelSize: 13
                  elide: Text.ElideRight
                  Behavior on color { ColorAnimation { duration: 400 } }
                }
              }

              // Next player
              Rectangle {
                width: 32; height: 32
                radius: 16
                visible: mprisRoot.activePlayers.length > 1
                color: nextPlayerArea.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.06)
                border.color: Qt.rgba(1, 1, 1, 0.1)
                border.width: 1

                Text {
                  anchors.centerIn: parent
                  text: "󰅂"
                  color: mprisRoot.colors.text
                  font.pixelSize: 16
                  font.family: "JetBrainsMono Nerd Font"
                }

                MouseArea {
                  id: nextPlayerArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    mprisRoot.activePlayerIndex = (mprisRoot.activePlayerIndex + 1) % mprisRoot.activePlayers.length
                    metadataProc.running = true
                  }
                }
              }
            }

            // ─── Barra de progreso ──────────────────────────────
            ColumnLayout {
              Layout.fillWidth: true
              spacing: 6

              Item {
                Layout.fillWidth: true
                height: 14

                Rectangle {
                  anchors.centerIn: parent
                  width: parent.width
                  height: progressArea.containsMouse ? 6 : 4
                  radius: 3
                  color: Qt.rgba(1, 1, 1, 0.12)
                  Behavior on height { NumberAnimation { duration: 150 } }

                  Rectangle {
                    width: mprisRoot.currentLength > 0
                      ? parent.width * (mprisRoot.currentPosition / mprisRoot.currentLength)
                      : 0
                    height: parent.height
                    radius: 3
                    color: mprisRoot.colors.accent

                    Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                  }

                  Rectangle {
                    x: (mprisRoot.currentLength > 0
                      ? parent.width * (mprisRoot.currentPosition / mprisRoot.currentLength)
                      : 0) - width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: progressArea.containsMouse ? 12 : 0
                    height: width
                    radius: width / 2
                    color: "#ffffff"

                    Behavior on width { NumberAnimation { duration: 150 } }
                  }
                }

                MouseArea {
                  id: progressArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
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
                  font.pixelSize: 11
                  font.family: "JetBrainsMono Nerd Font"
                }
                Item { Layout.fillWidth: true }
                Text {
                  text: mprisRoot.formatTime(mprisRoot.currentLength)
                  color: mprisRoot.colors.subtext
                  font.pixelSize: 11
                  font.family: "JetBrainsMono Nerd Font"
                }
              }
            }

            // ─── Controles ──────────────────────────────────────
            RowLayout {
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignHCenter
              spacing: 20

              Process {
                id: seekCmd
                property int seekPos: 0
                property string player: metadataProc.player
                command: ["playerctl", "--player=" + player, "position", String(Math.floor(seekPos / 1000000))]
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

              // Botón Anterior
              Rectangle {
                width: 44; height: 44
                radius: 22
                color: prevArea.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05)
                border.color: Qt.rgba(1, 1, 1, 0.1)
                border.width: 1

                Text {
                  anchors.centerIn: parent
                  text: "󰒮"
                  color: mprisRoot.colors.text
                  font.pixelSize: 20
                  font.family: "JetBrainsMono Nerd Font"
                }

                MouseArea {
                  id: prevArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: prevCmd.running = true
                }
              }

              // Botón Play / Pause Primario
              Rectangle {
                width: 52; height: 52
                radius: 26
                color: mprisRoot.colors.accent
                border.color: playArea.containsMouse ? "#ffffff" : "transparent"
                border.width: 1

                Behavior on scale { NumberAnimation { duration: 100 } }
                scale: playArea.pressed ? 0.92 : (playArea.containsMouse ? 1.05 : 1.0)

                Text {
                  anchors.centerIn: parent
                  text: mprisRoot.currentStatus === "Playing" ? "󰏤" : "󰐊"
                  color: mprisRoot.colors.bg
                  font.pixelSize: 22
                  font.family: "JetBrainsMono Nerd Font"
                }

                MouseArea {
                  id: playArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: { playCmd.running = false; playCmd.running = true }
                }
              }

              // Botón Siguiente
              Rectangle {
                width: 44; height: 44
                radius: 22
                color: nextArea.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05)
                border.color: Qt.rgba(1, 1, 1, 0.1)
                border.width: 1

               Text {
                  anchors.centerIn: parent
                  text: "󰒭"
                  color: mprisRoot.colors.text
                  font.pixelSize: 20
                  font.family: "JetBrainsMono Nerd Font"
                }

                MouseArea {
                  id: nextArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: nextCmd.running = true
                }
              }
            }

            // Indicadores de Players
            Row {
              Layout.alignment: Qt.AlignHCenter
              spacing: 6
              visible: mprisRoot.activePlayers.length > 1

              Repeater {
                model: mprisRoot.activePlayers.length
                delegate: Rectangle {
                  width: index === mprisRoot.activePlayerIndex ? 18 : 6
                  height: 6
                  radius: 3
                  color: index === mprisRoot.activePlayerIndex
                    ? mprisRoot.colors.accent
                    : Qt.rgba(1, 1, 1, 0.2)

                  Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      mprisRoot.activePlayerIndex = index
                      metadataProc.running = true
                    }
                  }
                }
              }
            }
          }

          // ─── Footer ─────────────────────────────────────────
          Item {
            Layout.fillWidth: true
            height: 36

            Rectangle {
              anchors { top: parent.top; left: parent.left; right: parent.right }
              height: 1
              color: Qt.rgba(1, 1, 1, 0.06)
            }

            RowLayout {
              anchors { fill: parent; leftMargin: 20; rightMargin: 20 }

              Text {
                text: "󰌑  " + Translations.t("footerHint")
                color: mprisRoot.colors.subtext
                font.pixelSize: 11
                font.family: "JetBrainsMono Nerd Font"
              }

              Item { Layout.fillWidth: true }

              Text {
                visible: mprisRoot.activePlayers.length > 1
                text: (mprisRoot.activePlayerIndex + 1) + "/" + mprisRoot.activePlayers.length
                color: mprisRoot.colors.subtext
                font.pixelSize: 11
                font.family: "JetBrainsMono Nerd Font"
              }
            }
          }
        }
      }
    }
  }
}