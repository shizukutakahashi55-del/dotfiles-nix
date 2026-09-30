import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../COMMON"
import "../LANG"

// ─────────────────────────────────────────────────────────────────
// PowerMenu — reemplazo nativo del powermenu.sh de rofi (tema WLStyle),
//
//   quickshell ipc -p .../shell.qml call -- powermenu toggle
// ─────────────────────────────────────────────────────────────────
Item {
  id: root

  property bool open: false
  property string targetScreen: ""
  property string namespace: "oozeshell-powermenu"

  // Nieve de fondo. Ponlo en false si prefieres el menú quieto.
  property bool snowEnabled: true
  property int snowCount: 16

  signal closeRequested()

  // ─── Comandos ─────────────────────────────────────────────────
  // La lista de acciones y cómo se ejecutan viven en POWER/PowerActions.qml
  // (singleton), compartido con DASHBOARD/DashboardPower.qml — acá solo
  // queda la UI (lista → confirmación → animación de cierre → ejecutar).
  readonly property var actions: PowerActions.actions

  // Botones de la confirmación: No (izquierda) | Sí (derecha)
  readonly property var confirmItems: [
    { id: "no",  icon: "󰅖", labelKey: "powerNo" },
    { id: "yes", icon: "󰄬", labelKey: "powerYes" }
  ]

  // ─── Estado ─────────────────────────────────────────────────────
  // Acción esperando confirmación (null = mostrando la lista)
  property var pending: null
  // Botón resaltado (índice dentro del modelo que se esté mostrando)
  property int sel: 0
  // Índice que tenía la lista antes de confirmar, para volver a él con Esc
  property int listIndex: 0

  readonly property var model: root.pending ? root.confirmItems : root.actions
  readonly property int count: root.model.length

  property string uptimeText: ""
  readonly property string userName: UserProfile.shownName !== "" ? UserProfile.shownName : "?"

  // Hora al abrir → frase del momento del día
  property int hour: 12
  readonly property string momentKey:
      (root.hour >= 22 || root.hour < 5) ? "powerMsgNight"
    : root.hour < 12 ? "powerMsgMorning"
    : root.hour < 19 ? "powerMsgAfternoon"
    : "powerMsgEvening"

  onOpenChanged: {
    if (!root.open) return
    root.pending = null
    root.sel = 0
    root.listIndex = 0
    root.hour = new Date().getHours()
    uptimeProc.running = false
    uptimeProc.running = true
  }

  function move(delta) {
    root.sel = (root.sel + delta + root.count) % root.count
  }

  // Un botón de la lista fue elegido → pasa a la confirmación (foco en "Sí")
  function choose(i) {
    if (i < 0 || i >= root.actions.length) return
    root.listIndex = i
    root.pending = root.actions[i]
    root.sel = 1
  }

  function back() {
    root.pending = null
    root.sel = root.listIndex
  }

  function activate() {
    if (!root.pending) {
      root.choose(root.sel)
    } else if (root.sel === 1) {
      root.run(root.pending)
    } else {
      root.back()
    }
  }

  // Cierra el menú y, un instante después (que termine el fade), ejecuta.
  // execDetached: hyprshutdown cierra Hyprland y con él Quickshell; el
  // comando tiene que sobrevivir a eso.
  property var toRun: null
  function run(a) {
    root.toRun = a
    root.closeRequested()
    runTimer.restart()
  }
  Timer {
    id: runTimer
    interval: 180
    repeat: false
    onTriggered: {
      PowerActions.run(root.toRun)
      root.toRun = null
    }
  }

  // ─── Uptime ─────────────────────────────────────────────────────
  // /proc/uptime → "2d 3h 14m". Sin depender de `uptime` ni del idioma.
  Process {
    id: uptimeProc
    command: ["cat", "/proc/uptime"]
    running: false
    stdout: SplitParser {
      onRead: line => {
        const s = Math.floor(parseFloat(line.split(" ")[0]))
        if (isNaN(s)) return
        const d = Math.floor(s / 86400)
        const h = Math.floor((s % 86400) / 3600)
        const m = Math.floor((s % 3600) / 60)
        root.uptimeText = d > 0 ? d + "d " + h + "h " + m + "m"
                        : h > 0 ? h + "h " + m + "m"
                        : m + "m"
      }
    }
  }

  // ─── Paleta (todo derivado de Theme / matugen) ──────────────────
  // rofi @base → surface_container · @outline → outline
  // @p-container → primary_container · @on-p-cont → on_primary_container
  readonly property color cCard: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.90)
  readonly property color cBody: Theme.surface
  readonly property color cOutline: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.45)
  readonly property color cSelected: Theme.primaryContainer
  readonly property color cOnSelected: Theme.textOnPrimaryContainer

  // ═══════════════════════════════════════════════════════════════
  PanelWindow {
    id: win

    screen: Quickshell.screens.find(s => s.name === root.targetScreen) ?? Quickshell.screens[0]
    visible: true
    color: "transparent"
    exclusiveZone: -1
    anchors { top: true; left: true; right: true; bottom: true }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: root.namespace
    // Modal: mientras está abierto se queda con el teclado
    WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Cerrado: región vacía = todo click-through
    mask: Region { item: hitArea }

    Connections {
      target: root
      function onOpenChanged() {
        if (root.open) keyCatcher.forceActiveFocus()
      }
    }

    // ── Fondo oscurecido, teñido con el color de fondo del tema ──
    Rectangle {
      id: dim
      anchors.fill: parent
      // Oscuro: velo oscuro. Claro: velo del propio fondo, para no ensuciar la paleta
      color: Theme.lightMode ? Qt.darker(Theme.bg, 1.12) : Qt.darker(Theme.bg, 1.7)
      opacity: root.open ? (Theme.lightMode ? 0.72 : 0.74) : 0
      visible: opacity > 0
      Behavior on opacity { NumberAnimation { duration: Theme.animDuration(200) } }
    }

    // ── Nieve ❄ (detrás de la tarjeta; solo se anima mientras se ve) ──
    Item {
      id: snow
      anchors.fill: parent
      readonly property bool active: root.snowEnabled && dim.opacity > 0
      visible: active

      Repeater {
        model: root.snowCount
        delegate: Text {
          id: flake

          // "Azar" repetible a partir del índice: cada copo es distinto
          // pero siempre igual entre aperturas.
          readonly property real baseX: ((index * 137) % 100) / 100 * snow.width
          readonly property real startY: ((index * 211) % 100) / 100 * snow.height
          readonly property int fallMs: 11000 + (index * 1237) % 9000
          readonly property int swayMs: 3200 + (index * 311) % 2000

          text: "❄"
          color: index % 3 === 0 ? Theme.primary : Theme.text
          opacity: 0.10 + ((index * 53) % 25) / 100
          font.pixelSize: 10 + (index * 7) % 16
          font.family: Theme.fontFamily
          y: -40

          // Vaivén de lado a lado
          SequentialAnimation on x {
            running: snow.active && Theme.uiAnimationsEnabled
            loops: Animation.Infinite
            NumberAnimation { from: flake.baseX - 18; to: flake.baseX + 18
                              duration: Theme.animDuration(flake.swayMs); easing.type: Easing.InOutSine }
            NumberAnimation { from: flake.baseX + 18; to: flake.baseX - 18
                              duration: Theme.animDuration(flake.swayMs); easing.type: Easing.InOutSine }
          }

          // Caída: la primera pasada arranca a media altura (para que no
          // caigan todos juntos desde arriba) y luego se repite completa.
          SequentialAnimation on y {
            running: snow.active
            NumberAnimation {
              from: flake.startY
              to: snow.height + 40
              duration: Theme.animDuration(Math.max(1, Math.round(flake.fallMs * (snow.height + 40 - flake.startY) / (snow.height + 80))))
            }
            SequentialAnimation {
              running: Theme.uiAnimationsEnabled; loops: Animation.Infinite
              NumberAnimation { from: -40; to: snow.height + 40; duration: Theme.animDuration(flake.fallMs) }
            }
          }
        }
      }
    }

    // ── Zona que captura input (clic afuera = cerrar) ──
    Item {
      id: hitArea
      width: root.open ? parent.width : 0
      height: root.open ? parent.height : 0

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onClicked: root.closeRequested()
      }
    }

    Item {
      id: keyCatcher
      anchors.fill: parent
      focus: true
      Keys.onPressed: event => {
        const k = event.key
        if (k === Qt.Key_Escape) {
          if (root.pending) root.back()
          else root.closeRequested()
        } else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) {
          root.activate()
        } else if (k === Qt.Key_Right || k === Qt.Key_Tab || k === Qt.Key_L) {
          root.move(1)
        } else if (k === Qt.Key_Left || k === Qt.Key_Backtab || k === Qt.Key_H) {
          root.move(-1)
        } else if (!root.pending && k >= Qt.Key_1 && k <= Qt.Key_5) {
          root.choose(k - Qt.Key_1)
        } else {
          return
        }
        event.accepted = true
      }
    }

    // ── Tarjeta ──
    Item {
      id: stage
      anchors.centerIn: parent
      width: card.width
      height: card.height

      opacity: root.open ? 1 : 0
      visible: opacity > 0
      // Respeta la escala de "Ventanas" (Ajustes → Interfaz)
      scale: (root.open ? 1.0 : 0.94) * Theme.windowScale
      Behavior on opacity { NumberAnimation { duration: Theme.animDuration(200) } }
      Behavior on scale { NumberAnimation { duration: Theme.animDuration(240); easing.type: Easing.OutCubic } }

      SkinRect {
        id: card
        raised: true
        notch: 8
        depth: 4
        width: content.implicitWidth + 112
        height: content.implicitHeight + 88
        radius: 34
        color: root.cCard
        border.width: 2
        border.color: root.cOutline

        // Los clics sobre la tarjeta no deben llegar al fondo (que cierra)
        MouseArea { anchors.fill: parent }

        // ❄ de marca de agua en la esquina
        Text {
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          anchors.rightMargin: 26
          anchors.bottomMargin: 10
          text: "❄"
          color: Theme.primary
          opacity: 0.07
          font.pixelSize: 150
          font.family: Theme.fontFamily
        }

        ColumnLayout {
          id: content
          anchors.centerIn: parent
          spacing: 16

          // ── Foto de perfil con su ❄ ──
          Item {
            id: avatarBox
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 190
            Layout.preferredHeight: 190

            // Aro (surface = cuerpo, outline = borde)
            Rectangle {
              anchors.fill: parent
              radius: width / 2
              color: root.cBody
              border.width: 3
              border.color: Theme.primary
            }

            Avatar {
              anchors.centerIn: parent
              size: 190 - 12
              source: UserProfile.avatarUrl
              letter: root.userName.charAt(0).toUpperCase()
            }

            // Insignia ❄ abajo a la derecha
            SkinRect {
              anchors.right: parent.right
              anchors.bottom: parent.bottom
              anchors.rightMargin: 2
              anchors.bottomMargin: 2
              width: 46
              height: 46
              radius: 23
              color: root.cSelected
              // Borde del color de la tarjeta: "recorta" la insignia de la foto
              border.width: 4
              border.color: Theme.bg

              Text {
                anchors.centerIn: parent
                text: "❄"
                color: Theme.primary
                font.pixelSize: Theme.fs(20)
                font.family: Theme.fontFamily
              }
            }
          }

          Item { Layout.preferredHeight: 6 }

          // ── Saludo: "See you soon, user ✧"  /  "¿Apagar el equipo?" ──
          Text {
            id: promptText
            Layout.alignment: Qt.AlignHCenter
            text: root.pending
              ? Translations.t(root.pending.confirmKey)
              : Translations.t("powerGoodbye").replace("%1", root.userName)
            color: Theme.primary
            font.pixelSize: Theme.fs(26)
            font.bold: true
            font.family: Theme.fontFamily
          }

          // ── Frase del momento  /  aviso de la confirmación ──
          SkinRect {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: msgText.implicitWidth + 44
            Layout.preferredHeight: msgText.implicitHeight + 16
            radius: height / 2
            notch: 4
            color: root.cSelected

            Text {
              id: msgText
              anchors.centerIn: parent
              text: root.pending
                ? Translations.t(root.pending.closesApps ? "powerConfirmHint" : "powerAreYouSure")
                : Translations.t(root.momentKey)
              color: root.cOnSelected
              font.pixelSize: Theme.fs(12)
              font.family: Theme.fontFamily
            }
          }

          // ── Uptime (solo en la lista) ──
          Text {
            Layout.alignment: Qt.AlignHCenter
            visible: !root.pending
            text: "󱑂 " + Translations.t("powerUptime") + ": " + root.uptimeText
            color: Theme.subtext
            opacity: 0.85
            font.pixelSize: Theme.fs(11)
            font.family: Theme.monoFamily
          }

          Item { Layout.preferredHeight: 8 }

          // ── Botones ──
          RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 18

            Repeater {
              model: root.model
              delegate: SkinRect {
                id: btn
                readonly property bool selected: root.sel === index

                Layout.preferredWidth: 150
                Layout.preferredHeight: 128
                radius: 22
                raised: true
                notch: 6
                inkColor: btn.selected ? Theme.primary : Theme.ink
                color: btn.selected ? root.cSelected : root.cBody
                border.width: btn.selected ? 2 : Theme.bw1
                border.color: btn.selected ? Theme.primary : root.cOutline
                Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
                Behavior on border.color { ColorAnimation { duration: Theme.animDuration(150) } }

                // El elegido "se infla" un poquito, como una almohada
                scale: Theme.cozy ? 1.0 : (btnArea.pressed ? 0.96 : (btn.selected ? 1.05 : 1.0))
                Behavior on scale { NumberAnimation { duration: Theme.animDuration(180); easing.type: Easing.OutBack } }

                ColumnLayout {
                  anchors.centerIn: parent
                  spacing: 10

                  Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: modelData.icon
                    color: btn.selected ? Theme.primary : Theme.subtext
                    font.pixelSize: Theme.fs(34)
                    font.family: Theme.monoFamily
                    Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
                  }
                  Text {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.maximumWidth: btn.width - 16
                    text: Translations.t(modelData.labelKey)
                    color: btn.selected ? root.cOnSelected : Theme.subtext
                    font.pixelSize: Theme.fs(11)
                    font.bold: true
                    font.family: Theme.fontFamily
                    elide: Text.ElideRight
                    Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
                  }
                }

                MouseArea {
                  id: btnArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onEntered: root.sel = index
                  onClicked: { root.sel = index; root.activate() }
                }
              }
            }
          }
        }
      }
    }
  }
}
