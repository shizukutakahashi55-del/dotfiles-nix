import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Item {
  id: wallsRoot

  property bool open: false
  property int currentIndex: 0
  signal closeRequested()

  // ─── Config ─────────────────────────────────────────────────
  // Carpeta de wallpapers. Usa $HOME (bash lo expande en runtime),
  // así funciona sin importar el usuario del sistema.
  property string wallpaperFolder: "$HOME/Pictures/Wallpapers"

  // Cuántas imágenes viven en memoria a la vez (ventana centrada
  // en currentIndex). 5 = actual +/-2. Bajalo a 3 (+/-1) si querés
  // aún menos RAM en máquinas con poca memoria.
  property int windowSize: 5
  readonly property int halfWindow: Math.floor(windowSize / 2)

  // ─── Utilidad: escapar para bash -c '...' de forma segura ────
  function shQuote(s) {
    return "'" + String(s).replace(/'/g, "'\\''") + "'"
  }

  // ─── Esquemas matugen ─────────────────────────────────────────
  property int schemeIndex: 0
  readonly property var schemes: [
    { name: "vibrant",     label: "vibrant"  },
    { name: "tonal-spot",  label: "tonal"    },
    { name: "neutral",     label: "neutral"  },
    { name: "fruit-salad", label: "fruit"    },
    { name: "rainbow",     label: "rainbow"  },
    { name: "fidelity",    label: "fidelity" },
    { name: "content",     label: "content"  },
    { name: "monochrome",  label: "mono"     },
  ]

  function applyScheme(idx) {
    schemeIndex = idx
    if (applyWallpaper.wpPath !== "") {
      matugenProc.running = true
    }
  }

  property var paletteSlots: []
  ListModel { id: wallpaperModel }

  // Solo guarda rutas (strings), es liviano incluso con miles de
  // wallpapers. Lo pesado (decodificar imágenes) sólo pasa para
  // las `windowSize` que están visibles — ver Repeater más abajo.
  Process {
    id: loadWalls
    command: ["bash", "-c",
      "find \"" + wallsRoot.wallpaperFolder + "\" -maxdepth 1 -type f 2>/dev/null | sort | grep -iE '\\.(jpg|jpeg|png|webp|gif)$'"
    ]
    running: true
    stdout: SplitParser {
      onRead: (line) => {
        const p = line.trim()
        if (p !== "") wallpaperModel.append({ "name": p.split("/").pop(), "path": p })
      }
    }
  }

  Process {
    id: applyWallpaper
    property string wpPath: ""
    command: ["bash", "-c",
      "mkdir -p \"$HOME/.cache/awww\" && " +
      "awww img " + wallsRoot.shQuote(wpPath) + " " +
      "--transition-type center " +
      "--transition-angle 30 " +
      "--transition-duration 1; " +
      "echo " + wallsRoot.shQuote(wpPath) + " > \"$HOME/.cache/awww/last\""
    ]
    running: false
    onRunningChanged: if (!running && wpPath !== "") matugenProc.running = true
  }

  // ─── Matugen ────────────────────────────────────────────────
  // Dos invocaciones (aplicar templates + volcar json), como en
  // el script original que ya sabíamos que funcionaba. Se sacó
  // python3 de en medio con `sed` para extraer el bloque JSON,
  // que alcanza porque matugen imprime el JSON como un objeto
  // "{ ... }" con llaves en su propia línea.
  // El stderr NO se silencia: si matugen falla vas a verlo en la
  // terminal donde corre quickshell, prefijado con [matugen].
  Process {
    id: matugenProc
    command: ["bash", "-c",
      "matugen image " + wallsRoot.shQuote(applyWallpaper.wpPath) +
      " --source-color-index 0 -t scheme-" + wallsRoot.schemes[wallsRoot.schemeIndex].name + "; " +
      "matugen image " + wallsRoot.shQuote(applyWallpaper.wpPath) +
      " --source-color-index 0 -t scheme-" + wallsRoot.schemes[wallsRoot.schemeIndex].name +
      " --json hex | sed -n '/^{/,/^}/p' > /tmp/matugen-colors.json"
    ]
    running: false
    stderr: SplitParser { onRead: (line) => console.log("[matugen]", line) }
    onRunningChanged: if (!running) colorReadTimer.running = true
  }

  Timer {
    id: colorReadTimer
    interval: 200; repeat: false; running: false
    onTriggered: readColors.running = true
  }

  Process {
    id: readColors
    command: ["cat", "/tmp/matugen-colors.json"]
    running: false
    property string buffer: ""
    stdout: SplitParser { onRead: line => readColors.buffer += line }
    onRunningChanged: {
      if (!running && buffer !== "") {
        try {
          const palette = JSON.parse(buffer)
          const c = palette.colors
          wallsRoot.matugenColors = {
            bg:      c.background?.dark?.color      ?? "#0d0305",
            border:  c.primary?.dark?.color          ?? "#cc1a2a",
            accent:  c.primary?.dark?.color          ?? "#cc1a2a",
            text:    c.on_background?.dark?.color   ?? "#e8c4c4",
            subtext: c.secondary?.dark?.color       ?? "#a87878",
            btn:     c.surface_container?.dark?.color ?? "#1e0a0d"
          }
          const slotDefs = [
            { key: "primary",           color: c.primary?.dark?.color             },
            { key: "secondary",          color: c.secondary?.dark?.color           },
            { key: "tertiary",           color: c.tertiary?.dark?.color            },
            { key: "error",              color: c.error?.dark?.color               },
            { key: "primary_container",   color: c.primary_container?.dark?.color   },
            { key: "secondary_container", color: c.secondary_container?.dark?.color },
            { key: "tertiary_container",  color: c.tertiary_container?.dark?.color  },
            { key: "surface_variant",     color: c.surface_variant?.dark?.color     },
          ]
          wallsRoot.paletteSlots = slotDefs.filter(s => s.color && s.color !== "")
        } catch(e) { console.log("matugen parse error:", e) }
        buffer = ""
      }
    }
  }

  property var matugenColors: ({
    bg: "#0d0305", border: "#cc1a2a", accent: "#cc1a2a",
    text: "#e8c4c4", subtext: "#a87878", btn: "#1e0a0d"
  })

  // ─── Panel ───────────────────────────────────────────────────
  PanelWindow {
    id: wallsPanel
    screen: Quickshell.screens[0]
    anchors { left: true; right: true; top: true; bottom: true }
    color: "transparent"
    exclusiveZone: -1
    focusable: true
    visible: wallsRoot.open

    Rectangle {
      anchors.fill: parent
      color: Qt.rgba(0, 0, 0, 0)
      opacity: wallsRoot.open ? 1.0 : 0.0
      Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

      MouseArea {
        anchors.fill: parent
        onClicked: {
            wallsRoot.closeRequested()
            gc()
        }
        z: -1
      }

      focus: wallsRoot.open
      Keys.onPressed: (event) => {
        const total = wallpaperModel.count
        if (total === 0) return

        if (event.key === Qt.Key_Left || event.key === Qt.Key_A)
          wallsRoot.currentIndex = (wallsRoot.currentIndex - 1 + total) % total
        else if (event.key === Qt.Key_Right || event.key === Qt.Key_D)
          wallsRoot.currentIndex = (wallsRoot.currentIndex + 1) % total
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Space) {
          applyWallpaper.wpPath = wallpaperModel.get(wallsRoot.currentIndex).path
          applyWallpaper.running = true
        }
        else if (event.key === Qt.Key_Escape) wallsRoot.closeRequested()
        event.accepted = true
      }

      // ─── HUD (Contador) ──────────────────────────────────────
      Rectangle {
        id: counterPill
        anchors { top: parent.top; right: parent.right; margins: 20 }
        width: counterText.width + 24; height: 32; radius: 10
        color: Qt.rgba(0, 0, 0, 0.55)
        border.color: Qt.rgba(1, 1, 1, 0.18)
        border.width: 1
        z: 300

        Text {
          id: counterText
          anchors.centerIn: parent
          text: (wallsRoot.currentIndex + 1) + " / " + wallpaperModel.count
          color: Qt.rgba(1,1,1,0.75)
          font.pixelSize: 11
          font.family: "JetBrainsMono Nerd Font"
        }
      }

      // ─── SELECTOR DE ESQUEMAS ───────────────────────────────────
      // Antes esto mostraba puntitos con los colores de la paleta
      // ACTUAL (no los 8 esquemas disponibles) — coincidía en
      // cantidad por casualidad, pero no era un selector real ni
      // se entendía qué tocabas. Ahora son chips con el nombre de
      // cada esquema (vibrant, tonal, neutral...), el activo se
      // resalta, y cada uno es clickeable para cambiar de esquema.
      Rectangle {
        id: topBar
        anchors { top: parent.top; topMargin: 70; horizontalCenter: parent.horizontalCenter }
        width: Math.min(parent.width * 0.9, 560)
        height: schemeFlow.implicitHeight + 20
        radius: 14
        color: wallsRoot.matugenColors.bg; border.color: wallsRoot.matugenColors.accent; border.width: 1; opacity: 0.92
        z: 300

        Flow {
          id: schemeFlow
          anchors { fill: parent; margins: 10 }
          spacing: 8

          Repeater {
            model: wallsRoot.schemes
            delegate: Rectangle {
              id: schemeChip
              readonly property bool active: index === wallsRoot.schemeIndex
              width: chipText.implicitWidth + 20; height: 26; radius: 13
              color: active ? wallsRoot.matugenColors.accent : Qt.rgba(1, 1, 1, 0.08)
              border.color: active ? "#ffffff" : Qt.rgba(1, 1, 1, 0.18)
              border.width: 1
              Behavior on color { ColorAnimation { duration: 150 } }

              Text {
                id: chipText
                anchors.centerIn: parent
                text: modelData.label
                font.pixelSize: 10
                font.family: "JetBrainsMono Nerd Font"
                color: schemeChip.active ? wallsRoot.matugenColors.bg : "#ffffffcc"
              }
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: wallsRoot.applyScheme(index)
              }
            }
          }
        }
      }

      // ══════════════════════════════════════════════════════════
      // CARRUSEL — único layout. Repeater de tamaño FIJO
      // (windowSize), no de wallpaperModel.count. Cada slot se
      // remapea al índice real via módulo cuando currentIndex
      // cambia, así solo existen `windowSize` Image/Rectangle en
      // memoria sin importar cuántos wallpapers tengas.
      // ══════════════════════════════════════════════════════════
      Item {
        anchors.fill: parent

        Item {
          id: carouselArea
          anchors.centerIn: parent
          width: parent.width; height: parent.height * 0.62
          property real cardW: parent.width * 0.32
          property real cardH: cardW * (9.0 / 16.0)

          Repeater {
            model: wallsRoot.windowSize

            delegate: Item {
              id: cCard
              // offset centrado: p.ej. windowSize=5 -> -2,-1,0,1,2
              property int offset: index - wallsRoot.halfWindow
              property int total: wallpaperModel.count
              // Evita duplicar la misma imagen en varios slots
              // cuando hay menos wallpapers que huecos de ventana.
              property bool slotActive: total > 0 && Math.abs(offset) < Math.max(1, Math.ceil(total / 2))
              property int actualIndex: total > 0 ? ((wallsRoot.currentIndex + offset) % total + total) % total : -1
              property var wp: (slotActive && actualIndex >= 0 && actualIndex < total) ? wallpaperModel.get(actualIndex) : null
              property bool isCurrent: offset === 0

              property real cw: carouselArea.cardW
              property real ch: carouselArea.cardH

              property real targetX: carouselArea.width/2 - cw/2 + offset * (cw * 0.72)
              property real targetScale: isCurrent ? 1.0 : Math.max(0.72, 1.0 - Math.abs(offset) * 0.10)
              property real targetOpacity: !slotActive ? 0.0 : (isCurrent ? 1.0 : 0.65)

              x: targetX; y: carouselArea.height/2 - ch/2 * targetScale
              width: cw; height: ch; opacity: targetOpacity
              visible: slotActive
              z: isCurrent ? 99 : 50 - Math.abs(offset)

              Behavior on x { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
              Behavior on opacity { NumberAnimation { duration: 250 } }

              transform: Scale {
                origin.x: cw/2; origin.y: ch/2; xScale: cCard.targetScale; yScale: cCard.targetScale
                Behavior on xScale { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                Behavior on yScale { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
              }

              Rectangle {
                anchors.fill: parent; radius: cCard.isCurrent ? 16 : 10; clip: true; color: "#181825"
                border.color: cCard.isCurrent ? wallsRoot.matugenColors.accent : Qt.rgba(1,1,1,0.08); border.width: cCard.isCurrent ? 2 : 1

                Image {
                  id: cThumb; anchors.fill: parent
                  source: cCard.wp ? ("file://" + cCard.wp.path) : ""
                  fillMode: Image.PreserveAspectCrop
                  asynchronous: true
                  cache: true
                  sourceSize.width: parent.width; sourceSize.height: parent.height
                  opacity: status === Image.Ready ? 1.0 : 0.0
                  Behavior on opacity { NumberAnimation { duration: 280 } }
                }

                Rectangle {
                  anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
                  height: 36; color: Qt.rgba(0,0,0,0.60); visible: cCard.isCurrent && cCard.wp
                  RowLayout {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    Text { text: cCard.wp ? cCard.wp.name.replace(/\.[^.]+$/, "") : ""; color: "#ffffffdd"; font.pixelSize: 11; font.family: "JetBrainsMono Nerd Font"; elide: Text.ElideRight; Layout.fillWidth: true }
                    Text { text: "↵ aplicar"; color: wallsRoot.matugenColors.accent; font.pixelSize: 9; font.family: "JetBrainsMono Nerd Font" }
                  }
                }
              }
              MouseArea {
                anchors.fill: parent
                enabled: cCard.slotActive
                onClicked: {
                  if (cCard.isCurrent) {
                    applyWallpaper.wpPath = cCard.wp.path
                    applyWallpaper.running = true
                  } else {
                    wallsRoot.currentIndex = cCard.actualIndex
                  }
                }
              }
            }
          }
        }
      }

      // ─── PAGINADOR INFERIOR ─────────────────────────────────────
      Row {
        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 28 }
        spacing: 6
        z: 300
        Repeater {
          model: Math.min(wallpaperModel.count, 15)
          delegate: Rectangle {
            width: index === (wallsRoot.currentIndex % 15) ? 18 : 6; height: 6; radius: 3
            color: index === (wallsRoot.currentIndex % 15) ? wallsRoot.matugenColors.accent : Qt.rgba(1,1,1,0.25)
            Behavior on width { NumberAnimation { duration: 200 } }
          }
        }
      }
    }
  }
}
