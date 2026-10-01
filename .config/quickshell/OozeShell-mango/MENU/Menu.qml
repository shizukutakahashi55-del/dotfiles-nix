import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../COMMON"
import "../NETWORK"
import "../BLUETOOTH"
import "../LANG"
import "../POWER"

// ─────────────────────────────────────────────────────────────────
// Menu — ventana principal que reemplaza los "perfiles-daemon" y
// accesos de Waybar.
//
// Botones "Network" / "Bluetooth" / "Appearance" / "Wallpaper" no
// reimplementan nada: solo emiten señales para que shell.qml abra el panel
// que corresponde (NetworkMenu, BluetoothMenu, Appearance, Walls) y cierran
// este menú. Todos menos Wallpaper son submenús que nacen del mismo sitio
//
// Estructura (cada grupo lleva un título discreto arriba, componente
// SectionTitle): Sistema (CPU/RAM/GPU) · Volumen · Energía (perfil) ·
// Accesos (Network/Bluetooth/Apariencia/Wallpaper) · Sesión
// (Reiniciar/Cerrar sesión/Apagar).
//
// ─────────────────────────────────────────────────────────────────
Item {
  id: menuRoot

  property bool open: false
  property string targetScreen: ""
  property int edgeMargin: 10
  property int cardWidth: 420
  readonly property int pad: 18

  signal closeRequested()
  signal requestAppearance()
  signal requestWalls()
  signal requestNetwork()
  signal requestBluetooth()
  // Botón de la tuerca (junto al usuario): shell.qml abre el panel de Ajustes
  signal requestSettings()
  // Botón del marco (junto al usuario): shell.qml alterna las esquinas
  signal requestCornersToggle()

  // Lo setea shell.qml: ¿están activadas las esquinas de pantalla?
  property bool screenCorners: true
  // El marco solo puede estar activo si la barra NO es flotante
  readonly property bool framed: screenCorners && !Theme.barSeparated

  // Texto gris a la derecha de cada acceso (vacío = sin subtítulo)
  function subtitleFor(action) {
    if (action === "network") return NetworkBackend.summary
    if (action === "bluetooth") return BluetoothBackend.summary
    return ""
  }

  // Solo sondea la red mientras el menú está abierto (para el subtítulo)
  onOpenChanged: {
    NetworkBackend.menuWatch = menuRoot.open
    // Por si el idioma cambió con el menú cerrado y el evento se perdió
    if (menuRoot.open) KeyboardLayout.refresh()
    PowerProfile.setWanted("menu", menuRoot.open)
  }

  // ─── Usuario / sesión ───────────────────────────────────────────
  property string userName: ""
  // Nombre a mostrar: el elegido en Ajustes → Perfil si hay uno, si no el
  // del sistema (whoami, de abajo).
  readonly property string displayUserName: UserProfile.displayName.trim() !== ""
    ? UserProfile.displayName.trim() : menuRoot.userName
  // Sistema operativo (PRETTY_NAME de /etc/os-release). No cambia mientras
  // corre el shell: se lee una sola vez.
  property string osName: ""
  Process {
    id: whoamiProc
    command: ["whoami"]
    running: menuRoot.open && menuRoot.userName === ""
    stdout: SplitParser { onRead: line => menuRoot.userName = line.trim() }
  }
  Process {
    id: osProc
    command: ["bash", "-c",
      ". /etc/os-release 2>/dev/null || . /usr/lib/os-release 2>/dev/null; echo \"${PRETTY_NAME:-${NAME:-Linux}}\""]
    running: menuRoot.open && menuRoot.osName === ""
    stdout: SplitParser { onRead: line => menuRoot.osName = line.trim() }
  }

  // ─── CPU / RAM / GPU (solo muestrea con el menú abierto) ────────
  SystemStats {
    id: stats
    active: menuRoot.open
  }

  // ─── Volumen (wpctl) ────────────────────────────────────────────
  AudioControl {
    id: audio
    active: menuRoot.open
  }

  // ─── Perfil de energía (POWER/PowerProfile.qml, compartido con el Dashboard) ───
  function setPowerProfile(p) { PowerProfile.set(p) }

  // ─── Bluetooth ──────────────────────────────────────────────────
  // El estado sale de BluetoothBackend (BLUETOOTH/): lo usa el subtítulo del
  // acceso rápido a Bluetooth (Accesos, abajo) — el toggle en sí vive en
  // BLUETOOTH/BluetoothMenu.qml, no acá.

  // ─── Layout de teclado ──────────────────────────────────────────
  // Ya no hay chip de idioma acá (era redundante con el ícono xkb de la
  // barra); el refresh de abajo (menuRoot.open) solo mantiene al día el
  // singleton COMMON/KeyboardLayout.qml que ese ícono también lee.

  // ─── Reboot / LogOut / Shutdown ─────────────────────────────────
  // Siempre piden confirmación antes, con un popup (ConfirmDialog).
  // Mango no trae un "shutdown" propio como hyprshutdown: reboot/apagar van
  // por systemd (que cierra las apps al bajar la sesión) y logout sale del
  // compositor con `mmsg dispatch quit`.
  readonly property var powerActions: [
    { id: "reboot",   icon: "󰑐", danger: false,
      titleKey: "powerConfirmReboot",   confirmKey: "powerReboot",
      cmd: ["systemctl", "reboot"] },
    { id: "logout",   icon: "󰍃", danger: false,
      titleKey: "powerConfirmLogout",   confirmKey: "powerLogout",
      cmd: ["mmsg", "dispatch", "quit"] },
    { id: "shutdown", icon: "󰐥", danger: true,
      titleKey: "powerConfirmShutdown", confirmKey: "powerShutdown",
      cmd: ["systemctl", "poweroff"] }
  ]

  // Acción pendiente de confirmar. Se conserva al cerrar el diálogo para que
  // el texto no desaparezca a mitad del fade-out.
  property var powerAction: null
  property bool powerDialogOpen: false

  // Un botón de energía fue pulsado: cierra el menú y pregunta.
  function requestPower(action) {
    menuRoot.powerAction = action
    menuRoot.powerDialogOpen = true
    menuRoot.closeRequested()
  }

  function confirmPower() {
    const a = menuRoot.powerAction
    menuRoot.powerDialogOpen = false
    // execDetached: apagar/salir cierra Mango y con él Quickshell; el
    // comando tiene que sobrevivir a eso.
    if (a) Quickshell.execDetached(a.cmd)
  }

  // Popup de confirmación (vive fuera del panel: el menú ya se cerró)
  ConfirmDialog {
    open: menuRoot.powerDialogOpen
    targetScreen: menuRoot.targetScreen
    icon: menuRoot.powerAction ? menuRoot.powerAction.icon : ""
    title: menuRoot.powerAction ? Translations.t(menuRoot.powerAction.titleKey) : ""
    message: Translations.t("powerConfirmHint")
    confirmText: menuRoot.powerAction ? Translations.t(menuRoot.powerAction.confirmKey) : ""
    cancelText: Translations.t("powerCancel")
    danger: menuRoot.powerAction ? menuRoot.powerAction.danger : false
    onConfirmed: menuRoot.confirmPower()
    onCancelled: menuRoot.powerDialogOpen = false
  }

  // ── Título de sección (mismo estilo que Ajustes) ──────────────
  component SectionTitle: Text {
    Layout.fillWidth: true
    Layout.topMargin: 2
    color: Theme.subtext
    font.bold: true
    font.pixelSize: Theme.fs(10)
    font.family: Theme.fontFamily
    font.letterSpacing: 0.5
  }

  // ═══════════════════════════════════════════════════════════════
  FusedWindow {
    active: menuRoot.open || panel.shown
    targetScreen: menuRoot.targetScreen
    namespace: "oozeshell-menu"
    onCloseRequested: menuRoot.closeRequested()

    FusedPanel {
      id: panel

      open: menuRoot.open
      panelWidth: menuRoot.cardWidth
      contentHeight: col.implicitHeight + menuRoot.pad * 2

      // Cuelga de la barra, del lado de su botón (derecha si es horizontal,
      // abajo si es vertical). FusedPanel se coloca solo según Theme.barPosition.
      align: "end"
      alignMargin: menuRoot.edgeMargin + Theme.barEdge + Theme.frameSideArm

      ColumnLayout {
        id: col
        x: menuRoot.pad
        y: menuRoot.pad
        width: parent.width - menuRoot.pad * 2
        spacing: 14

        // ── Header: usuario ──────────────────────────────────
        RowLayout {
          Layout.fillWidth: true
          spacing: 12

          // Foto de perfil (Ajustes → Perfil). Sin foto: círculo con la inicial.
          Avatar {
            Layout.preferredWidth: 46
            Layout.preferredHeight: 46
            size: 46
            source: UserProfile.avatarUrl
            letter: menuRoot.displayUserName.length > 0 ? menuRoot.displayUserName.charAt(0).toUpperCase() : "?"
          }

          // Ocupa el espacio que sobra y recorta con "…": con fuentes grandes el
          // header ya no se desborda hacia los botones de la derecha.
          ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: 2
            Text {
              Layout.fillWidth: true
              text: menuRoot.displayUserName.length > 0 ? menuRoot.displayUserName : "..."
              color: Theme.text
              font.pixelSize: Theme.fs(15)
              font.bold: true
              font.family: Theme.fontFamily
              elide: Text.ElideRight
            }
            Text {
              Layout.fillWidth: true
              text: "󰌽 " + (menuRoot.osName.length > 0 ? menuRoot.osName : "Linux")
              color: Theme.subtext
              font.pixelSize: Theme.fs(11)
              font.family: Theme.monoFamily
              elide: Text.ElideRight
            }
          }

          // ── Marco (esquinas de pantalla) on/off ──
          // Mismo look que el botón de Bluetooth: activo = color primario.
          SkinRect {
            Layout.preferredHeight: 34
            Layout.preferredWidth: cornersRow.implicitWidth + 24
            radius: 10
            // Con la barra flotante el marco no se puede activar (se pisarían)
            opacity: Theme.barSeparated ? 0.4 : 1.0
            color: menuRoot.framed ? Theme.primary : Theme.surface
            Behavior on color { ColorAnimation { duration: Theme.animDuration(200) } }

            scale: Theme.cozy ? 1.0 : ((cornersArea.pressed && !Theme.barSeparated) ? 0.92 : 1.0)
            Behavior on scale { NumberAnimation { duration: Theme.animDuration(140); easing.type: Easing.OutBack } }

            RowLayout {
              id: cornersRow
              anchors.centerIn: parent
              spacing: 6
              Text {
                text: menuRoot.framed ? "▣" : "▢"
                color: menuRoot.framed ? Theme.textOnPrimary : Theme.text
                font.pixelSize: Theme.fs(15)
                font.family: Theme.fontFamily
              }
              Text {
                text: Translations.t("screenFrame")
                color: menuRoot.framed ? Theme.textOnPrimary : Theme.text
                font.pixelSize: Theme.fs(11)
                font.family: Theme.fontFamily
              }
              // Perillita ON/OFF: mismo lenguaje visual que los interruptores
              // de Ajustes → Avanzado, para que se lea de un vistazo que esto
              // es un toggle (el ESTILO — esquinas/curvas — se elige ahí).
              Rectangle {
                Layout.preferredWidth: 22
                Layout.preferredHeight: 13
                radius: Theme.cozy ? 2 : 6.5
                antialiasing: !Theme.cozy
                color: menuRoot.framed
                  ? Qt.rgba(Theme.textOnPrimary.r, Theme.textOnPrimary.g, Theme.textOnPrimary.b, 0.35)
                  : Theme.surfaceHigh
                Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }

                Rectangle {
                  width: 9
                  height: 9
                  radius: Theme.cozy ? 1 : 4.5
                  antialiasing: !Theme.cozy
                  anchors.verticalCenter: parent.verticalCenter
                  x: menuRoot.framed ? 11 : 2
                  color: menuRoot.framed ? Theme.textOnPrimary : Theme.subtext
                  Behavior on x { NumberAnimation { duration: Theme.animDuration(150); easing.type: Easing.OutCubic } }
                  Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
                }
              }
            }
            MouseArea {
              id: cornersArea
              anchors.fill: parent
              cursorShape: Theme.barSeparated ? Qt.ArrowCursor : Qt.PointingHandCursor
              onClicked: { if (!Theme.barSeparated) menuRoot.requestCornersToggle() }
            }
          }

          // ── Ajustes (tuerca) ──
          // Abre el panel de Ajustes: tamaño de la interfaz, foto de perfil...
          SkinRect {
            Layout.preferredWidth: 34
            Layout.preferredHeight: 34
            radius: 10
            color: gearArea.containsMouse ? Theme.surfaceHigh : Theme.surface
            Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }

            scale: Theme.cozy ? 1.0 : (gearArea.pressed ? 0.92 : 1.0)
            Behavior on scale { NumberAnimation { duration: Theme.animDuration(140); easing.type: Easing.OutBack } }

            Text {
              anchors.centerIn: parent
              text: "󰒓"
              color: gearArea.containsMouse ? Theme.primary : Theme.text
              font.pixelSize: Theme.fs(17)
              font.family: Theme.monoFamily
              // La tuerca gira un poquito al pasar el mouse
              rotation: gearArea.containsMouse ? 60 : 0
              Behavior on rotation { NumberAnimation { duration: Theme.animDuration(320); easing.type: Easing.OutCubic } }
              Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
            }
            MouseArea {
              id: gearArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                menuRoot.requestSettings()
                menuRoot.closeRequested()
              }
            }
          }
        }

        // ── Sistema: CPU / RAM / GPU con gráficos ─────────────
        SectionTitle { text: Translations.t("menuSectionSystem") }
        RowLayout {
          Layout.fillWidth: true
          spacing: 10

          MetricCard {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            icon: "󰻠"
            label: "CPU"
            value: stats.cpu
            history: stats.cpuHistory
            maxSamples: stats.maxSamples
          }

          MetricCard {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            icon: "󰍛"
            label: "RAM"
            value: stats.ram
            detail: stats.ramTotalGb > 0 ? stats.ramUsedGb.toFixed(1) + "G" : ""
            history: stats.ramHistory
            maxSamples: stats.maxSamples
          }

          MetricCard {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            icon: "󰢮"
            label: "GPU"
            value: stats.gpu
            history: stats.gpuHistory
            maxSamples: stats.maxSamples
          }
        }

        // ── Volumen ──────────────────────────────────────────
        SkinRect {
          Layout.fillWidth: true
          Layout.preferredHeight: 50
          radius: Theme.cardRadius
          color: Theme.surface

          RowLayout {
            anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
            spacing: 12

            // Icono = botón de silenciar
            Item {
              Layout.preferredWidth: 26
              Layout.preferredHeight: 26

              Text {
                anchors.centerIn: parent
                text: audio.icon
                color: audio.muted ? Theme.subtext : Theme.primary
                font.pixelSize: Theme.fs(20)
                font.family: Theme.monoFamily
                Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
              }

              MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                onClicked: audio.toggleMute()
              }
            }

            // Slider
            Item {
              id: volSlider
              Layout.fillWidth: true
              Layout.preferredHeight: 30

              readonly property bool grabbed: volArea.containsMouse || volArea.pressed

              PixelBar {

                visible: Theme.cozy

                anchors.verticalCenter: parent.verticalCenter

                width: parent.width

                height: 16

                ratio: audio.volume

                colorA: Theme.mix((audio.muted ? Theme.subtext : Theme.primary), Theme.bg, 0.40)

                colorB: (audio.muted ? Theme.subtext : Theme.primary)

              }


              Rectangle {
                id: volTrack

                visible: !Theme.cozy
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: volSlider.grabbed ? 8 : 6
                radius: height / 2
                color: Theme.surfaceHigh
                Behavior on height { NumberAnimation { duration: Theme.animDuration(100) } }

                Rectangle {
                  width: volTrack.width * audio.volume
                  height: parent.height
                  radius: parent.radius
                  color: audio.muted ? Theme.subtext : Theme.primary
                  Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
                }

                Rectangle {
                  x: volTrack.width * audio.volume - width / 2
                  anchors.verticalCenter: parent.verticalCenter
                  width: volSlider.grabbed ? 16 : 0
                  height: width
                  radius: width / 2
                  color: Theme.text
                  Behavior on width { NumberAnimation { duration: Theme.animDuration(100) } }
                }
              }

              MouseArea {
                id: volArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                function setFrom(mx) {
                  audio.setVolume(mx / width)
                }

                onPressed: mouse => { audio.dragging = true; setFrom(mouse.x) }
                onPositionChanged: mouse => { if (pressed) setFrom(mouse.x) }
                onReleased: { audio.dragging = false; audio.commit() }
                onCanceled: { audio.dragging = false; audio.commit() }
                onWheel: wheel => {
                  audio.setVolume(audio.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
                  audio.commit()
                }
              }
            }

            Text {
              Layout.preferredWidth: 38
              horizontalAlignment: Text.AlignRight
              text: Math.round(audio.volume * 100) + "%"
              color: audio.muted ? Theme.subtext : Theme.text
              font.pixelSize: Theme.fs(12)
              font.bold: true
              font.family: Theme.fontFamily
            }
          }
        }

        // ── Perfil de energía ────────────────────────────────
        SectionTitle { text: Translations.t("menuSectionPower") }
        RowLayout {
          Layout.fillWidth: true
          spacing: 6

          Repeater {
            model: PowerProfile.profiles
            delegate: SkinRect {
              Layout.fillWidth: true
              Layout.preferredWidth: 1
              Layout.preferredHeight: 44
              radius: 10
              raised: true
              color: PowerProfile.current === modelData.key ? Theme.primary : Theme.surface
              Behavior on color { ColorAnimation { duration: Theme.animDuration(200) } }

              ColumnLayout {
                anchors.fill: parent
                anchors.margins: 4
                spacing: 0
                Text {
                  Layout.fillWidth: true
                  Layout.alignment: Qt.AlignHCenter
                  horizontalAlignment: Text.AlignHCenter
                  text: modelData.icon
                  color: PowerProfile.current === modelData.key ? Theme.textOnPrimary : Theme.text
                  font.pixelSize: Theme.fs(14)
                  font.family: Theme.monoFamily
                }
                Text {
                  Layout.fillWidth: true
                  Layout.alignment: Qt.AlignHCenter
                  horizontalAlignment: Text.AlignHCenter
                  text: Translations.t(modelData.labelKey)
                  color: PowerProfile.current === modelData.key ? Theme.textOnPrimary : Theme.subtext
                  font.pixelSize: Theme.fs(8)
                  font.family: Theme.fontFamily
                  elide: Text.ElideRight
                }
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: menuRoot.setPowerProfile(modelData.key)
              }
            }
          }
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }

        // Antes había acá una sección "Bluetooth + Teclado" con dos chips de
        // acceso rápido: encendido de Bluetooth e idioma de teclado. Se
        // sacó por redundante — el toggle de Bluetooth ya está más abajo,
        // dentro de BLUETOOTH/BluetoothMenu.qml (que se abre desde
        // "Accesos → Bluetooth", justo debajo), y el de teclado ya está en
        // la barra (ícono xkb, target "keyboardlayout" del IPC).

        // ── Accesos: Network / Bluetooth / Apariencia / Wallpaper ──
        SectionTitle { text: Translations.t("menuSectionQuick") }
        ColumnLayout {
          Layout.fillWidth: true
          spacing: 6

          Repeater {
            model: [
              { icon: "󰖩", labelKey: "netTitle",        action: "network" },
              { icon: "󰂯", labelKey: "btTitle",          action: "bluetooth" },
              { icon: "󰏘", labelKey: "appearanceTitle",  action: "appearance" },
              { icon: "󰸉", labelKey: "menuWallpaper",    action: "walls" }
            ]
            delegate: SkinRect {
              Layout.fillWidth: true
              Layout.preferredHeight: 42
              radius: 10
              color: itemArea.containsMouse ? Theme.surface : "transparent"
              Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }

              RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                spacing: 10
                Text {
                  text: modelData.action === "network" ? NetworkBackend.statusIcon
                      : (modelData.action === "bluetooth" ? BluetoothBackend.statusIcon : modelData.icon)
                  color: Theme.primary
                  font.pixelSize: Theme.fs(15)
                  font.family: Theme.fontFamily
                }
                Text {
                  text: modelData.action === "network" ? NetworkBackend.title : Translations.t(modelData.labelKey)
                  color: Theme.text
                  font.pixelSize: Theme.fs(12)
                  font.family: Theme.fontFamily
                }
                Item { Layout.fillWidth: true }
                // Subtítulo: red conectada / estado del bluetooth
                Text {
                  visible: text !== ""
                  Layout.maximumWidth: 180
                  text: menuRoot.subtitleFor(modelData.action)
                  color: Theme.subtext
                  font.pixelSize: Theme.fs(11)
                  font.family: Theme.fontFamily
                  elide: Text.ElideRight
                }
                Text { text: "󰅂"; color: Theme.subtext; font.pixelSize: Theme.fs(11); font.family: Theme.fontFamily }
              }

              MouseArea {
                id: itemArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (modelData.action === "network") menuRoot.requestNetwork()
                  else if (modelData.action === "bluetooth") menuRoot.requestBluetooth()
                  else if (modelData.action === "appearance") menuRoot.requestAppearance()
                  else if (modelData.action === "walls") menuRoot.requestWalls()
                  menuRoot.closeRequested()
                }
              }
            }
          }
        }

        // ── Sesión: Reiniciar / Cerrar sesión / Apagar (con confirmación) ──
        SectionTitle { text: Translations.t("menuSectionSession") }
        RowLayout {
          Layout.fillWidth: true
          spacing: 8

          Repeater {
            model: menuRoot.powerActions
            delegate: SkinRect {
              id: pwrBtn
              Layout.fillWidth: true
              Layout.preferredWidth: 1
              Layout.preferredHeight: 44
              radius: 10
              raised: true
              color: pwrArea.containsMouse
                ? (modelData.danger ? Theme.error : Theme.surfaceHigh)
                : Theme.surface
              Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 6
                Text {
                  text: modelData.icon
                  color: pwrArea.containsMouse
                    ? (modelData.danger ? Theme.textOnError : Theme.text)
                    : (modelData.danger ? Theme.error : Theme.primary)
                  font.pixelSize: Theme.fs(15)
                  font.family: Theme.monoFamily
                }
                Text {
                  Layout.fillWidth: true
                  text: Translations.t(modelData.confirmKey)
                  color: pwrArea.containsMouse && modelData.danger ? Theme.textOnError : Theme.text
                  font.pixelSize: Theme.fs(12)
                  font.bold: true
                  font.family: Theme.fontFamily
                  horizontalAlignment: Text.AlignHCenter
                  elide: Text.ElideRight
                }
              }

              MouseArea {
                id: pwrArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: menuRoot.requestPower(modelData)
              }
            }
          }
        }
      }
    }
  }
}
