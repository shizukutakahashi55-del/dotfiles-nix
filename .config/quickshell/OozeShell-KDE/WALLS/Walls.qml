import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../LANG"

Item {
  id: wallsRoot

  property bool open: false
  property int currentIndex: 0
  property string targetScreen: "DP-3"
  signal closeRequested()

  property string wallpaperFolder: "$HOME/Pictures/Wallpapers"

  property int windowSize: 7
  readonly property int halfWindow: Math.floor(windowSize / 2)

  function shQuote(s) {
    return "'" + String(s).replace(/'/g, "'\\''") + "'"
  }

  // ─── Función para buscar el índice guardado en el modelo ────
    function restoreLastIndex(savedPath) {
      const cleanPath = savedPath.trim()
      if (cleanPath === "") return

      for (let i = 0; i < wallpaperModel.count; i++) {
        if (wallpaperModel.get(i).path === cleanPath) {
          wallsRoot.currentIndex = i
          // Asignamos la ruta cargada para que matugen la use
          applyWallpaper.wpPath = cleanPath
          break
        }
      }
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
    { name: "monochrome",  label: "mono"     }
  ]

  function applyScheme(idx) {
    schemeIndex = idx
    if (applyWallpaper.wpPath !== "") {
      matugenProc.running = true
    }
  }

  property var paletteSlots: []
  ListModel { id: wallpaperModel }

  // ─── Carga de lista de Wallpapers ──────────────────────────────
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
    // Una vez que termina de escanear la carpeta, lee el caché del último fondo
    onRunningChanged: if (!running) loadLastWp.running = true
  }

  // ─── Proceso para leer la última imagen usada desde el caché ───
  // (antes leía ~/.cache/awww/last, que es del daemon de wallpaper
  // de Hyprland; en KDE usamos nuestra propia ruta de caché)
  property string cacheDir: Quickshell.env("HOME") + "/.cache/oozeshell-kde"
  property string lastWpFile: cacheDir + "/last-wallpaper"
  property string matugenKdeConfig: Quickshell.env("HOME") + "/.config/matugen/config-kde.toml"

    Process {
      id: loadLastWp
      command: ["bash", "-c", "cat " + wallsRoot.shQuote(wallsRoot.lastWpFile) + " 2>/dev/null"]
      running: false
      property string lastPath: ""
      stdout: SplitParser { onRead: line => loadLastWp.lastPath += line }
      onRunningChanged: {
        if (!running && lastPath !== "") {
          wallsRoot.restoreLastIndex(lastPath)
          lastPath = ""
          // Si hay una ruta válida cargada, regeneramos la paleta de colores al iniciar
          if (applyWallpaper.wpPath !== "") {
            matugenProc.running = true
          }
        }
      }
    }

    Process {
      id: applyWallpaper
      property string wpPath: ""
      command: ["bash", "-c",
        "mkdir -p " + wallsRoot.shQuote(wallsRoot.cacheDir) + " && " +
        // KDE: preferimos plasma-apply-wallpaperimage (viene con
        // plasma-workspace/kde-cli-tools). Si no está instalado,
        // caemos a qdbus llamando al scripting API de PlasmaShell,
        // que sí siempre está disponible.
        "if command -v plasma-apply-wallpaperimage >/dev/null 2>&1; then " +
        "  plasma-apply-wallpaperimage " + wallsRoot.shQuote(wpPath) + "; " +
        "else " +
        "  QDBUS=$(command -v qdbus6 || command -v qdbus-qt6 || command -v qdbus); " +
        "  \"$QDBUS\" org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript \"" +
        "    var allDesktops = desktops();" +
        "    for (i = 0; i < allDesktops.length; i++) {" +
        "      d = allDesktops[i];" +
        "      d.wallpaperPlugin = 'org.kde.image';" +
        "      d.currentConfigGroup = Array('Wallpaper', 'org.kde.image', 'General');" +
        "      d.writeConfig('Image', 'file://" + wpPath + "');" +
        "    }" +
        "  \"; " +
        "fi; " +
        "echo " + wallsRoot.shQuote(wpPath) + " > " + wallsRoot.shQuote(wallsRoot.lastWpFile)
      ]
      running: false
      onRunningChanged: if (!running && wpPath !== "") matugenProc.running = true
    }

  // ─── Matugen ────────────────────────────────────────────────
  // -c apunta siempre a config-kde.toml de forma explícita: así
  // esta llamada NUNCA cae en el config.toml por defecto (el de
  // Hyprland, con templates de waybar/swaync/hyprctl reload que
  // no existen en KDE y solo generaban ruido/errores).
  Process {
    id: matugenProc
    command: ["bash", "-c",
      "matugen -c " + wallsRoot.shQuote(wallsRoot.matugenKdeConfig) +
      " image " + wallsRoot.shQuote(applyWallpaper.wpPath) +
      " --source-color-index 0 -t scheme-" + wallsRoot.schemes[wallsRoot.schemeIndex].name + "; " +
      "matugen -c " + wallsRoot.shQuote(wallsRoot.matugenKdeConfig) +
      " image " + wallsRoot.shQuote(applyWallpaper.wpPath) +
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
            border:  c.primary?.dark?.color         ?? "#cc1a2a",
            accent:  c.primary?.dark?.color         ?? "#cc1a2a",
            text:    c.on_background?.dark?.color   ?? "#e8c4c4",
            subtext: c.secondary?.dark?.color       ?? "#a87878",
            btn:     c.surface_container?.dark?.color ?? "#1e0a0d"
          }
          const slotDefs = [
            { key: "primary",            color: c.primary?.dark?.color             },
            { key: "secondary",          color: c.secondary?.dark?.color           },
            { key: "tertiary",           color: c.tertiary?.dark?.color            },
            { key: "error",              color: c.error?.dark?.color               },
            { key: "primary_container",   color: c.primary_container?.dark?.color   },
            { key: "secondary_container", color: c.secondary_container?.dark?.color },
            { key: "tertiary_container",  color: c.tertiary_container?.dark?.color  },
            { key: "surface_variant",     color: c.surface_variant?.dark?.color     }
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
    screen: Quickshell.screens.find(s => s.name === wallsRoot.targetScreen) ?? Quickshell.screens[0]
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
      Rectangle {
        id: topBar
        anchors { top: parent.top; topMargin: 565; horizontalCenter: parent.horizontalCenter }
        width: Math.min(parent.width * 0.9, 560)
        height: schemeFlow.implicitHeight + 20
        radius: 12
        color: wallsRoot.matugenColors.bg; border.color: wallsRoot.matugenColors.accent; border.width: 1.5; opacity: 1.0
        z: 300

        Flow {
          id: schemeFlow
          anchors { fill: parent; margins: 10 }
          spacing: 11

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
      // DOCK LAYOUT — Anclado abajo con marco visible
      // ══════════════════════════════════════════════════════════
      Item {
        id: dockArea
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 60
        width: parent.width
        height: cardH * 2.0
        
        // Tamaño aumentado de las tarjetas
        property real cardW: parent.width * 0.28
        property real cardH: cardW * (9.0 / 16.0)

        Repeater {
          model: wallsRoot.windowSize

          delegate: Item {
            id: cCard
            property int offset: index - wallsRoot.halfWindow
            property int total: wallpaperModel.count
            property bool slotActive: total > 0 && Math.abs(offset) < Math.max(1, Math.ceil(total / 2))
            property int actualIndex: total > 0 ? ((wallsRoot.currentIndex + offset) % total + total) % total : -1
            property var wp: (slotActive && actualIndex >= 0 && actualIndex < total) ? wallpaperModel.get(actualIndex) : null
            property bool isCurrent: offset === 0

            property real cw: dockArea.cardW
            property real ch: dockArea.cardH

            property real spacing: cw * 0.52
            property real targetX: (dockArea.width / 2) - (cw / 2) + (offset * spacing)
            property real targetY: (dockArea.height - ch) - (isCurrent ? 24 : 0)
            
            // Escala ligeramente aumentada para tarjeta enfocada y laterales
            property real targetScale: isCurrent ? 1.18 : Math.max(0.75, 0.95 - Math.abs(offset) * 0.08)
            property real targetOpacity: !slotActive ? 0.0 : (isCurrent ? 1.0 : Math.max(0.35, 0.75 - Math.abs(offset) * 0.15))

            // Inclinación según la posición (grados de rotación)
            property real targetAngle: offset * 0

            x: targetX
            y: targetY
            width: cw
            height: ch
            opacity: targetOpacity
            visible: slotActive
            z: isCurrent ? 99 : 50 - Math.abs(offset)

            Behavior on x { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 250 } }

            transform: [
              Scale {
                origin.x: cw / 2; origin.y: ch
                xScale: cCard.targetScale; yScale: cCard.targetScale
                Behavior on xScale { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
                Behavior on yScale { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
              },
              Rotation {
                origin.x: cw / 2; origin.y: ch / 2
                angle: cCard.targetAngle
                Behavior on angle { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
              }
            ]

            // ─── TARJETA CON MARCO VISIBLE ───
            Rectangle {
              id: cardFrame
              anchors.fill: parent
              radius: 0 // Sin curvas (borde recto)
              clip: true
              color: "#181825"
              
              // Grosor y color del marco (resalta la tarjeta actual con el color de Matugen)
              border.color: cCard.isCurrent ? wallsRoot.matugenColors.accent : Qt.rgba(1, 1, 1, 0.25)
              border.width: cCard.isCurrent ? 2 : 2

              // Transición suave al cambiar de color de marco
              Behavior on border.color { ColorAnimation { duration: 200 } }

              // Imagen con margen interno para no tapar el marco
              Image {
                id: cThumb
                anchors.fill: parent
                anchors.margins: cardFrame.border.width
                source: cCard.wp ? ("file://" + cCard.wp.path) : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                sourceSize.width: parent.width
                sourceSize.height: parent.height
                opacity: status === Image.Ready ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 280 } }
              }

              // Barra de título e indicación sobre la imagen enfocada
              Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: cardFrame.border.width
                height: 36
                color: Qt.rgba(0, 0, 0, 0.65)
                visible: cCard.isCurrent && cCard.wp

                RowLayout {
                  anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                  Text {
                    text: cCard.wp ? cCard.wp.name.replace(/\.[^.]+$/, "") : ""
                    color: "#ffffffdd"
                    font.pixelSize: 11
                    font.family: "JetBrainsMono Nerd Font"
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                  }
                  Text {
                    text: Translations.t("wallsApplyHint")
                    color: wallsRoot.matugenColors.accent
                    font.pixelSize: 9
                    font.family: "JetBrainsMono Nerd Font"
                  }
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