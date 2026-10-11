// Mpris.qml — MPRIS

import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import "../COMMON"
import "../LANG"

// ─────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────
Item {
  id: mprisRoot

  property bool open: false
  property string targetScreen: ""
  signal closeRequested()


  property int anchorLeftMargin: 45
  property int anchorTopMargin: 6
  property int cardWidth: 460

  // ─── Medidas (px lógicos) ────────────────────────────────────

  readonly property int headerH: 42
  readonly property int footerH: 30
  readonly property int sidePad: 18
  readonly property int coverSize: 100
  readonly property int playSize: 48
  readonly property int skipSize: 38


  readonly property int ctlBorderW: Theme.cozy ? 2 : (Theme.glassCtl ? 1 : 0)
  readonly property color ctlBorderC: Theme.cozy ? Theme.ink : Theme.glassEdge

  // ─── Metadata ────────────────────────────────────────────────

  readonly property string currentTitle: MprisBackend.currentTitle
  readonly property string currentArtist: MprisBackend.currentArtist
  readonly property string currentArt: MprisBackend.currentArt
  readonly property string currentStatus: MprisBackend.currentStatus
  readonly property int currentPosition: MprisBackend.currentPosition
  readonly property int currentLength: MprisBackend.currentLength

  readonly property var activePlayers: MprisBackend.activePlayers
  readonly property int activePlayerIndex: MprisBackend.activePlayerIndex

  readonly property real progressRatio: MprisBackend.progressRatio

  readonly property bool wanted: mprisRoot.open || panel.shown
  onWantedChanged: MprisBackend.setWanted("popup", mprisRoot.wanted)
  Component.onCompleted: MprisBackend.setWanted("popup", mprisRoot.wanted)
  Component.onDestruction: {
    MprisBackend.setWanted("popup", false)
    AudioLevels.setWanted("mpris", false)
  }

  function currentPlayer() { return MprisBackend.currentPlayer() }
  function selectPlayer(i) { MprisBackend.selectPlayer(i) }
  function runCtl(args) { MprisBackend.runCtl(args) }
  function playerIcon(name) { return MprisBackend.playerIcon(name) }
  function cleanPlayerName(name) { return MprisBackend.cleanPlayerName(name) }

  function formatTime(us) { return MprisBackend.formatTime(us) }

  // ─── Ir a la app que está reproduciendo ────────────────────────


  readonly property var playerAppMap: ({
    chromium: "chromium",
    brave: "brave-browser",
    spotify: "spotify",
    firefox: "firefox",
  })

  function playerAppNeedle(name) {
    if (!name) return ""
    const clean = name.split(".")[0].split("-")[0].toLowerCase()
    return mprisRoot.playerAppMap[clean] || clean
  }


  function playerNeedles(name) {
    if (!name) return []
    const out = []
    const mapped = mprisRoot.playerAppNeedle(name)
    const base = name.split(".")[0].toLowerCase()
    if (mapped !== "") out.push(mapped)
    if (base !== "" && out.indexOf(base) < 0) out.push(base)
    return out
  }


  function findPlayerWindow(clients, needles) {
    const usable = clients
      .filter(c => c.mapped !== false && !c.hidden)
      .sort((a, b) => (a.focusHistoryID ?? 999) - (b.focusHistoryID ?? 999))

    const byClass = usable.find(c => {
      const cls = ((c["class"] || "") + " " + (c.initialClass || "")).toLowerCase()
      return needles.some(n => cls.includes(n))
    })
    if (byClass) return byClass

    return usable.find(c => {
      const title = (c.title || "").toLowerCase()
      return needles.some(n => title.includes(n))
    }) ?? null
  }


  function locateAndFocusPlayer() {
    const player = mprisRoot.currentPlayer()
    const needles = mprisRoot.playerNeedles(player)
    if (needles.length === 0) return

    WM.withClients(clients => {
      const match = mprisRoot.findPlayerWindow(clients, needles)
      if (match) {

        WM.focusWindow(match.address)
        mprisRoot.closeRequested()
        return
      }


      for (const n of needles) {
        const entry = DesktopEntries.heuristicLookup(n)
        if (entry) {
          entry.execute()
          mprisRoot.closeRequested()
          return
        }
      }
      console.log("Mpris: sin ventana ni .desktop para el player:", player)
    })
  }


  function focusPlayerApp() {
    if (mprisRoot.activePlayers.length === 0) return
    mprisRoot.locateAndFocusPlayer()
  }


  // ─── Audio para las ondas ────────────────────────────────────


  readonly property bool audioWanted:
    (mprisRoot.open || panel.shown) && mprisRoot.currentStatus === "Playing"
  onAudioWantedChanged: AudioLevels.setWanted("mpris", mprisRoot.audioWanted)

  // ═══════════════════════════════════════════════════════════════
  FusedWindow {
    active: mprisRoot.open || panel.shown
    targetScreen: mprisRoot.targetScreen
    namespace: "oozeshell-mpris"
    onCloseRequested: mprisRoot.closeRequested()

    FusedPanel {
      id: panel

      open: mprisRoot.open
      panelWidth: mprisRoot.cardWidth


      stretchToIsland: true
      contentHeight: col.implicitHeight


      align: "start"
      alignMargin: (Theme.barVertical ? mprisRoot.anchorTopMargin : mprisRoot.anchorLeftMargin)
                   + Theme.barEdge + Theme.frameSideArm


      ColumnLayout {
        id: col
        width: parent.width
        spacing: 0

        // ── Header ───────────────────────────────────────────
        Item {
          Layout.fillWidth: true
          Layout.preferredHeight: mprisRoot.headerH

          RowLayout {
            anchors { fill: parent; leftMargin: mprisRoot.sidePad; rightMargin: mprisRoot.sidePad }
            spacing: 8

            Text {
              text: "󰝚"
              color: Theme.primary
              font.pixelSize: Theme.fs(18)
              font.family: Theme.monoFamily
            }

            Text {
              text: Translations.t("mprisTitle")
              color: Theme.text
              font.pixelSize: Theme.fs(14)
              font.bold: true
              font.family: Theme.fontFamily
            }

            Item { Layout.fillWidth: true }


            Rectangle {
              visible: mprisRoot.activePlayers.length > 1
              Layout.preferredWidth: 24
              Layout.preferredHeight: 24
              radius: Theme.cozy ? 4 : 12
              border.width: mprisRoot.ctlBorderW
              border.color: mprisRoot.ctlBorderC
              color: prevPlayerArea.containsMouse ? Theme.surfaceHigh : Theme.surface
              Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }

              Text {
                anchors.centerIn: parent
                text: "󰅁"
                color: Theme.text
                font.pixelSize: Theme.fs(13)
                font.family: Theme.monoFamily
              }
              MouseArea {
                id: prevPlayerArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: mprisRoot.selectPlayer(mprisRoot.activePlayerIndex - 1)
              }
            }


            Rectangle {
              Layout.preferredHeight: 24
              Layout.preferredWidth: Math.min(150, playerRow.implicitWidth + 16)
              radius: Theme.cozy ? 4 : 12
              color: Theme.surface
              border.width: mprisRoot.ctlBorderW
              border.color: mprisRoot.ctlBorderC
              clip: true

              RowLayout {
                id: playerRow
                anchors.centerIn: parent
                spacing: 6

                Text {
                  text: mprisRoot.activePlayers.length > 0
                    ? mprisRoot.playerIcon(mprisRoot.currentPlayer()) : "󰝚"
                  color: Theme.primary
                  font.pixelSize: Theme.fs(12)
                  font.family: Theme.monoFamily
                }
                Text {
                  Layout.maximumWidth: 100
                  text: mprisRoot.activePlayers.length > 0
                    ? mprisRoot.cleanPlayerName(mprisRoot.currentPlayer()) : "—"
                  color: Theme.subtext
                  font.pixelSize: Theme.fs(11)
                  font.bold: true
                  font.family: Theme.fontFamily
                  elide: Text.ElideRight
                }
              }
            }

            Rectangle {
              visible: mprisRoot.activePlayers.length > 1
              Layout.preferredWidth: 24
              Layout.preferredHeight: 24
              radius: Theme.cozy ? 4 : 12
              border.width: mprisRoot.ctlBorderW
              border.color: mprisRoot.ctlBorderC
              color: nextPlayerArea.containsMouse ? Theme.surfaceHigh : Theme.surface
              Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }

              Text {
                anchors.centerIn: parent
                text: "󰅂"
                color: Theme.text
                font.pixelSize: Theme.fs(13)
                font.family: Theme.monoFamily
              }
              MouseArea {
                id: nextPlayerArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: mprisRoot.selectPlayer(mprisRoot.activePlayerIndex + 1)
              }
            }


            Rectangle {
              visible: mprisRoot.activePlayers.length > 0
              Layout.preferredWidth: 24
              Layout.preferredHeight: 24
              radius: Theme.cozy ? 4 : 12
              border.width: mprisRoot.ctlBorderW
              border.color: mprisRoot.ctlBorderC
              color: goToAppArea.containsMouse ? Theme.surfaceHigh : Theme.surface
              Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }

              Text {
                anchors.centerIn: parent
                text: "󰏌"
                color: Theme.text
                font.pixelSize: Theme.fs(12)
                font.family: Theme.monoFamily
              }
              MouseArea {
                id: goToAppArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: mprisRoot.focusPlayerApp()
              }
            }
          }

          Rectangle {
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
            height: 1
            color: Theme.divider
          }
        }

        // ── Cuerpo ───────────────────────────────────────────
        ColumnLayout {
          Layout.fillWidth: true
          Layout.leftMargin: mprisRoot.sidePad
          Layout.rightMargin: mprisRoot.sidePad
          Layout.topMargin: 14
          Layout.bottomMargin: 12
          spacing: 10

          // ── Bloque 1: portada + título/artista + visualizador ──
          SkinRect {
            Layout.fillWidth: true
            Layout.preferredHeight: mprisRoot.coverSize + 24
            radius: Theme.cardRadius
            color: Theme.surface

            RowLayout {
              anchors { fill: parent; margins: 12 }
              spacing: 14

              ClippingRectangle {
                Layout.preferredWidth: mprisRoot.coverSize
                Layout.preferredHeight: mprisRoot.coverSize
                Layout.alignment: Qt.AlignVCenter
                radius: Theme.cozy ? 4 : 10
                color: Theme.surfaceHigh
                border.width: Theme.cozy ? 3 : 0
                border.color: Theme.ink

                Image {
                  id: albumArt
                  anchors.fill: parent
                  source: mprisRoot.currentArt
                  fillMode: Image.PreserveAspectCrop
                  asynchronous: true
                  smooth: true

                  sourceSize: Qt.size(256, 256)
                }

                Text {
                  anchors.centerIn: parent
                  visible: albumArt.status !== Image.Ready
                  text: "󰝚"
                  color: Theme.primary
                  font.pixelSize: Theme.fs(36)
                  font.family: Theme.monoFamily
                }
              }

              ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 3

                Text {
                  Layout.fillWidth: true
                  text: mprisRoot.currentTitle !== ""
                    ? mprisRoot.currentTitle : Translations.t("mprisNoPlaying")
                  color: Theme.text
                  font.pixelSize: Theme.fs(15)
                  font.bold: true
                  font.family: Theme.fontFamily
                  elide: Text.ElideRight
                }
                Text {
                  Layout.fillWidth: true
                  text: mprisRoot.currentArtist !== "" ? mprisRoot.currentArtist : "—"
                  color: Theme.subtext
                  font.pixelSize: Theme.fs(12)
                  font.family: Theme.fontFamily
                  elide: Text.ElideRight
                }


                SpectrumBars {
                  Layout.fillWidth: true
                  Layout.fillHeight: true
                  Layout.minimumHeight: 24
                  Layout.topMargin: 6
                  active: panel.shown && mprisRoot.currentStatus === "Playing"
                  minBarHeight: 4
                  barSpacing: 3
                  activeOpacity: 0.85
                  idleOpacity: 0.25
                  ledActiveOpacity: 0.90
                  ledIdleOpacity: 0.30
                  color: Theme.primary
                }
              }
            }
          }

          // ── Bloque 2: progreso + controles ──
          SkinRect {
            Layout.fillWidth: true
            Layout.preferredHeight: ctlCol.implicitHeight + 24
            radius: Theme.cardRadius
            color: Theme.surface

            ColumnLayout {
              id: ctlCol
              anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
              spacing: 12


              RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 14
                spacing: 10

                Text {
                  Layout.preferredWidth: 38
                  text: mprisRoot.formatTime(mprisRoot.currentPosition)
                  color: Theme.subtext
                  font.pixelSize: Theme.fs(11)
                  font.family: Theme.fontFamily
                  horizontalAlignment: Text.AlignLeft
                }

                Item {
                  Layout.fillWidth: true
                  Layout.fillHeight: true

                  PixelBar {
                    visible: Theme.cozy
                    anchors.fill: parent
                    ratio: mprisRoot.progressRatio
                    cell: 6
                    gap: 2
                  }

                  Rectangle {
                    id: track
                    visible: !Theme.cozy
                    anchors.centerIn: parent
                    width: parent.width
                    height: progressArea.containsMouse ? 5 : 3
                    radius: 2.5
                    color: Theme.tint(0.12)
                    Behavior on height { NumberAnimation { duration: Theme.animDuration(100) } }

                    Rectangle {
                      width: track.width * mprisRoot.progressRatio
                      height: parent.height
                      radius: parent.radius
                      color: Theme.primary
                    }

                    Rectangle {
                      x: track.width * mprisRoot.progressRatio - width / 2
                      anchors.verticalCenter: parent.verticalCenter
                      width: progressArea.containsMouse ? 11 : 0
                      height: width
                      radius: width / 2
                      color: Theme.text
                      Behavior on width { NumberAnimation { duration: Theme.animDuration(100) } }
                    }
                  }

                  MouseArea {
                    id: progressArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                      if (mprisRoot.currentLength > 0) {
                        const pos = (mouse.x / width) * mprisRoot.currentLength
                        mprisRoot.runCtl(["position", (pos / 1000000).toFixed(2)])
                      }
                    }
                  }
                }

                Text {
                  Layout.preferredWidth: 38
                  text: mprisRoot.formatTime(mprisRoot.currentLength)
                  color: Theme.subtext
                  font.pixelSize: Theme.fs(11)
                  font.family: Theme.fontFamily
                  horizontalAlignment: Text.AlignRight
                }
              }


              RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 18

                CozyButton {
                  visible: Theme.cozy
                  Layout.preferredWidth: mprisRoot.skipSize
                  Layout.preferredHeight: mprisRoot.skipSize + depth
                  onClicked: mprisRoot.runCtl(["previous"])
                  Text {
                    anchors.centerIn: parent
                    text: "󰒮"
                    color: Theme.text
                    font.pixelSize: Theme.fs(18)
                    font.family: Theme.monoFamily
                  }
                }
                CozyButton {
                  visible: Theme.cozy
                  Layout.preferredWidth: mprisRoot.playSize + 6
                  Layout.preferredHeight: mprisRoot.playSize + depth
                  face: Theme.primary
                  faceHover: Theme.mix(Theme.primary, "#ffffff", 0.18)
                  active: true
                  onClicked: mprisRoot.runCtl(["play-pause"])
                  Text {
                    anchors.centerIn: parent
                    text: mprisRoot.currentStatus === "Playing" ? "󰏤" : "󰐊"
                    color: Theme.textOnPrimary
                    font.pixelSize: Theme.fs(22)
                    font.family: Theme.monoFamily
                  }
                }
                CozyButton {
                  visible: Theme.cozy
                  Layout.preferredWidth: mprisRoot.skipSize
                  Layout.preferredHeight: mprisRoot.skipSize + depth
                  onClicked: mprisRoot.runCtl(["next"])
                  Text {
                    anchors.centerIn: parent
                    text: "󰒭"
                    color: Theme.text
                    font.pixelSize: Theme.fs(18)
                    font.family: Theme.monoFamily
                  }
                }

                Rectangle {
                  visible: !Theme.cozy
                  Layout.preferredWidth: mprisRoot.skipSize
                  Layout.preferredHeight: mprisRoot.skipSize
                  radius: mprisRoot.skipSize / 2
                  border.width: mprisRoot.ctlBorderW
                  border.color: mprisRoot.ctlBorderC
                  color: prevArea.containsMouse ? Theme.surfaceHigh : Theme.surface
                  Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }
                  Text {
                    anchors.centerIn: parent
                    text: "󰒮"
                    color: Theme.text
                    font.pixelSize: Theme.fs(18)
                    font.family: Theme.monoFamily
                  }
                  MouseArea {
                    id: prevArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mprisRoot.runCtl(["previous"])
                  }
                }

                Rectangle {
                  visible: !Theme.cozy
                  Layout.preferredWidth: mprisRoot.playSize
                  Layout.preferredHeight: mprisRoot.playSize
                  radius: mprisRoot.playSize / 2
                  color: Theme.primary
                  scale: playArea.pressed ? 0.92 : (playArea.containsMouse ? 1.05 : 1.0)
                  Behavior on scale { NumberAnimation { duration: Theme.animDuration(120); easing.type: Easing.OutBack } }
                  Text {
                    anchors.centerIn: parent
                    text: mprisRoot.currentStatus === "Playing" ? "󰏤" : "󰐊"
                    color: Theme.textOnPrimary
                    font.pixelSize: Theme.fs(20)
                    font.family: Theme.monoFamily
                  }
                  MouseArea {
                    id: playArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mprisRoot.runCtl(["play-pause"])
                  }
                }

                Rectangle {
                  visible: !Theme.cozy
                  Layout.preferredWidth: mprisRoot.skipSize
                  Layout.preferredHeight: mprisRoot.skipSize
                  radius: mprisRoot.skipSize / 2
                  border.width: mprisRoot.ctlBorderW
                  border.color: mprisRoot.ctlBorderC
                  color: nextArea.containsMouse ? Theme.surfaceHigh : Theme.surface
                  Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }
                  Text {
                    anchors.centerIn: parent
                    text: "󰒭"
                    color: Theme.text
                    font.pixelSize: Theme.fs(18)
                    font.family: Theme.monoFamily
                  }
                  MouseArea {
                    id: nextArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mprisRoot.runCtl(["next"])
                  }
                }
              }
            }
          }
        }

        // ── Footer ───────────────────────────────────────────


        Item {
          Layout.fillWidth: true
          Layout.preferredHeight: mprisRoot.footerH

          Rectangle {
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: 1
            color: Theme.divider
          }

          RowLayout {
            anchors { fill: parent; leftMargin: mprisRoot.sidePad; rightMargin: mprisRoot.sidePad }
            spacing: 10

            Text {
              Layout.fillWidth: true
              text: "󰌑  " + Translations.t("footerHint")
              color: Theme.subtext
              font.pixelSize: Theme.fs(10)
              font.family: Theme.monoFamily
              elide: Text.ElideRight
            }

            Row {
              visible: mprisRoot.activePlayers.length > 1
              spacing: 5

              Repeater {
                model: mprisRoot.activePlayers.length
                delegate: Rectangle {
                  width: index === mprisRoot.activePlayerIndex ? 16 : 6
                  height: 6
                  radius: Theme.cozy ? 0 : 3
                  color: index === mprisRoot.activePlayerIndex ? Theme.primary : Theme.tint(0.2)
                  Behavior on width { NumberAnimation { duration: Theme.animDuration(150) } }

                  MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mprisRoot.selectPlayer(index)
                  }
                }
              }
            }

            Text {
              visible: mprisRoot.activePlayers.length > 1
              text: (mprisRoot.activePlayerIndex + 1) + "/" + mprisRoot.activePlayers.length
              color: Theme.subtext
              font.pixelSize: Theme.fs(10)
              font.family: Theme.fontFamily
            }
          }
        }
      }
    }
  }
}
