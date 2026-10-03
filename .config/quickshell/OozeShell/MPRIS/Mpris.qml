import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import "../COMMON"
import "../LANG"

// ─────────────────────────────────────────────────────────────────
//
// ─────────────────────────────────────────────────────────────────
Item {
  id: mprisRoot

  property bool open: false
  property string targetScreen: ""
  signal closeRequested()

  // Distancia al borde de pantalla, a lo largo de la barra: a la izquierda
  // (barra horizontal) o desde arriba (barra vertical, donde el módulo
  // izquierdo arranca casi pegado al borde)
  property int anchorLeftMargin: 45
  property int anchorTopMargin: 6
  property int cardWidth: 460

  // ─── Medidas (px lógicos) ────────────────────────────────────
  // El alto total del panel sale de estas cifras (más los márgenes del cuerpo).
  readonly property int headerH: 42
  readonly property int footerH: 30
  readonly property int sidePad: 18
  readonly property int coverSize: 92
  readonly property int playSize: 48
  readonly property int skipSize: 38

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
  // El nombre MPRIS no siempre coincide con la clase de la ventana en
  // Hyprland (ej. Firefox reporta "firefox.instanceXXXX" pero su clase
  // suele ser "firefox"; algunos players usan guiones para lo mismo que
  // cleanPlayerName ya recorta). Este mapeo cubre los casos más comunes;
  // si no matchea ninguno, cae al nombre limpio tal cual.
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

  // Palabras con las que buscar la ventana del player: la del mapeo de
  // arriba ("brave" → "brave-browser") y el nombre MPRIS tal cual, sin el
  // sufijo ".instanceXXXX" ("youtube-music" sigue entero).
  function playerNeedles(name) {
    if (!name) return []
    const out = []
    const mapped = mprisRoot.playerAppNeedle(name)
    const base = name.split(".")[0].toLowerCase()
    if (mapped !== "") out.push(mapped)
    if (base !== "" && out.indexOf(base) < 0) out.push(base)
    return out
  }

  // Ventana del player entre las ventanas del WM: primero por CLASE
  // (más fiable), después por título. Si hay varias (ej. dos ventanas del
  // navegador) gana la usada más recientemente (focusHistoryID menor).
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

  // Busca la ventana del player (lista al día: ver WM.withClients) y la
  // enfoca; si no hay ventana, abre la app desde su .desktop.
  function locateAndFocusPlayer() {
    const player = mprisRoot.currentPlayer()
    const needles = mprisRoot.playerNeedles(player)
    if (needles.length === 0) return

    WM.withClients(clients => {
      const match = mprisRoot.findPlayerWindow(clients, needles)
      if (match) {
        // Enfoca la ventana (y cambia de workspace si hace falta)
        WM.focusWindow(match.address)
        mprisRoot.closeRequested()
        return
      }

      // Sin ventana (el player corre en segundo plano o la ventana se
      // cerró): se abre la app desde su .desktop, así el botón siempre
      // hace algo.
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

  // Botón "ir a la app": busca su ventana entre las ventanas del WM
  // (por clase o título) y la enfoca, cambiando de escritorio si hace
  // falta; si no tiene ventana, abre la app. Cierra el panel al saltar,
  // como al hacer clic afuera.
  function focusPlayerApp() {
    if (mprisRoot.activePlayers.length === 0) return
    mprisRoot.locateAndFocusPlayer()
  }

  // Lista + metadata + controles: MPRIS/MprisBackend.qml (ver los
  // delegados currentPlayer()/selectPlayer()/runCtl() más arriba y
  // `wanted`, que le avisa cuándo sondear).

  // ─── Audio para las ondas ────────────────────────────────────
  // cava (COMMON/AudioLevels.qml) solo corre mientras el panel se ve (o se
  // está cerrando) Y el player está sonando; pausado o cerrado = 0% CPU.
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
      // Modo Islas: la isla izquierda crece con la canción; si pasa el
      // ancho del panel, el contenido y la portada se estiran (sin franjas)
      stretchToIsland: true
      contentHeight: col.implicitHeight

      // Cuelga de la barra, del lado del módulo izquierdo: a la izquierda si la
      // barra es horizontal, arriba si es vertical. FusedPanel se coloca solo.
      align: "start"
      alignMargin: (Theme.barVertical ? mprisRoot.anchorTopMargin : mprisRoot.anchorLeftMargin)
                   + Theme.barEdge + Theme.frameSideArm

      // ── Fondo: portada + degradado + ondas ───────────────────────────
      // Va en el `backdrop` de FusedPanel, que lo recorta con la MISMA silueta
      // del panel: esquinas redondas del lado opuesto a la barra (con el radio
      // real, sin escalar). El degradado es EXACTAMENTE el color de la barra
      // del lado en que ella está (arriba, abajo, izquierda o derecha) para
      // que la unión sea invisible, y se va abriendo hacia el lado contrario
      // dejando ver la portada. Encima van las ondas, en el lado LEJANO a la
      // barra (abajo si la barra está arriba; arriba si está abajo).
      backdrop: [
        Image {
          anchors.fill: parent
          source: mprisRoot.currentArt
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          smooth: true
          // Sin esto Qt decodifica la carátula a su tamaño original (una de
          // 1200×1200 = ~5,5 MB de RAM y de textura) para un fondo a 45 % de opacidad
          sourceSize: Qt.size(720, 720)
          opacity: status === Image.Ready ? 0.45 : 0.0
          Behavior on opacity { NumberAnimation { duration: Theme.animDuration(500) } }
        },

        Rectangle {
          anchors.fill: parent
          gradient: Gradient {
            // Barra vertical → degradado de lado a lado; horizontal → de arriba a abajo
            orientation: panel.vertical ? Gradient.Horizontal : Gradient.Vertical
            // Posición 0 = arriba/izquierda. Si la barra está abajo/derecha, la
            // cara sólida es la del final: se espeja.
            GradientStop { position: panel.faceAtEnd ? 1.0 : 0.0;  color: Theme.bg }
            GradientStop { position: panel.faceAtEnd ? 0.65 : 0.35; color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.80) }
            GradientStop { position: panel.faceAtEnd ? 0.0 : 1.0;  color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.55) }
          }
        },

        // ── Ondas ──────────────────────────────────────────────────────
        // Ver MprisWaves.qml: capas sinusoidales + espectro que reaccionan al
        // audio (COMMON/AudioLevels.qml). Solo animan mientras el panel se ve.
        MprisWaves {
          anchors.fill: parent
          visible: !Theme.performanceMode
          running: panel.shown && !Theme.performanceMode
          playing: mprisRoot.currentStatus === "Playing"
          sf: panel.scaleFactor
          flip: !panel.vertical && panel.faceAtEnd
        }
      ]

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

            // Player activo
            Rectangle {
              Layout.preferredHeight: 24
              Layout.preferredWidth: Math.min(150, playerRow.implicitWidth + 16)
              radius: Theme.cozy ? 4 : 12
              color: Theme.surface
              border.width: Theme.cozy ? 2 : 0
              border.color: Theme.ink
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

            // Ir a la app que está reproduciendo
            Rectangle {
              visible: mprisRoot.activePlayers.length > 0
              Layout.preferredWidth: 24
              Layout.preferredHeight: 24
              radius: Theme.cozy ? 4 : 12
              border.width: Theme.cozy ? 2 : 0
              border.color: Theme.ink
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
          spacing: 12

          // Portada + info (+ selector de player)
          RowLayout {
            Layout.fillWidth: true
            spacing: 14

            Rectangle {
              visible: mprisRoot.activePlayers.length > 1
              Layout.preferredWidth: 28
              Layout.preferredHeight: 28
              radius: Theme.cozy ? 5 : 14
              border.width: Theme.cozy ? 2 : 0
              border.color: Theme.ink
              color: prevPlayerArea.containsMouse ? Theme.surfaceHigh : Theme.surface
              Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }

              Text {
                anchors.centerIn: parent
                text: "󰅁"
                color: Theme.text
                font.pixelSize: Theme.fs(15)
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

            ClippingRectangle {
              Layout.preferredWidth: mprisRoot.coverSize
              Layout.preferredHeight: mprisRoot.coverSize
              radius: Theme.cozy ? 4 : 14
              color: Theme.surface
              border.width: Theme.cozy ? 3 : 0
              border.color: Theme.ink

              Image {
                id: albumArt
                anchors.fill: parent
                source: mprisRoot.currentArt
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
                // Portada de 92 px lógicos: 256 px alcanza incluso con escala 2x
                sourceSize: Qt.size(256, 256)
              }

              Text {
                anchors.centerIn: parent
                visible: albumArt.status !== Image.Ready
                text: "󰝚"
                color: Theme.primary
                font.pixelSize: Theme.fs(34)
                font.family: Theme.monoFamily
              }

              // Mini ecualizador
              Rectangle {
                anchors { right: parent.right; bottom: parent.bottom; margins: 5 }
                width: 28
                height: 20
                radius: Theme.cozy ? 2 : 6
                color: Qt.rgba(0, 0, 0, 0.68)
                visible: mprisRoot.currentStatus === "Playing"

                Row {
                  anchors.centerIn: parent
                  spacing: 2

                  Repeater {
                    model: 3

                    // Contenedor de alto fijo: el Row no admite anchors
                    // verticales en sus hijos, así las barras se centran.
                    Item {
                      width: 3
                      height: 12

                      Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 3
                        height: index === 0 ? 7 : (index === 1 ? 10 : 5)
                        radius: Theme.cozy ? 0 : 1.5
                        color: Theme.primary

                        SequentialAnimation on height {
                          running: (mprisRoot.currentStatus === "Playing" && mprisRoot.open) && Theme.uiAnimationsEnabled
                          loops: Animation.Infinite
                          NumberAnimation { to: 10; duration: Theme.animDuration(300 + index * 100) }
                          NumberAnimation { to: 3;  duration: Theme.animDuration(300 + index * 100) }
                        }
                      }
                    }
                  }
                }
              }
            }

            ColumnLayout {
              Layout.fillWidth: true
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
            }

            Rectangle {
              visible: mprisRoot.activePlayers.length > 1
              Layout.preferredWidth: 28
              Layout.preferredHeight: 28
              radius: Theme.cozy ? 5 : 14
              border.width: Theme.cozy ? 2 : 0
              border.color: Theme.ink
              color: nextPlayerArea.containsMouse ? Theme.surfaceHigh : Theme.surface
              Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }

              Text {
                anchors.centerIn: parent
                text: "󰅂"
                color: Theme.text
                font.pixelSize: Theme.fs(15)
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
          }

          // Progreso: tiempo · barra · duración, todo en una sola línea
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

          // Controles
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

        // ── Footer ───────────────────────────────────────────
        // Los indicadores de player viven aquí (antes eran una fila extra en
        // el cuerpo): así el alto del panel no cambia cuando aparece un 2º player.
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
