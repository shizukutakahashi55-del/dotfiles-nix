// LockScreen — pantalla de bloqueo nativa (sustituye a hyprlock).
//
// ─── Cómo funciona ────────────────────────────────────────────────────
//   • Usa el protocolo ext-session-lock-v1 (WlSessionLock de Quickshell): el
//     compositor oculta TODO lo demás y solo deja estas superficies, una por
//     monitor. Si el shell muere estando bloqueado, Mango deja su pantalla
//     roja de seguridad (igual que con hyprlock): nunca queda desbloqueado.
//   • La contraseña se valida con PAM (Quickshell.Services.Pam). Por defecto
//     usa el servicio "login" de /etc/pam.d (existe en cualquier distro y en
//     NixOS). Si prefieres uno propio, cambia `pamConfig`.
//   • Fondo = el wallpaper DEL MOMENTO en que se bloquea: se lee
//     ~/.cache/awww/last (lo escribe Walls; con un wallpaper en vivo apunta a un
//     fotograma del video) y, si no está, `awww query`. Se COPIA a
//     ~/.cache/oozeshell/lock-bg-<ns>.<ext> para que no cambie mientras está
//     bloqueado, y se borra al desbloquear. El bloqueo se activa al instante
//     (fondo sólido) y el wallpaper aparece con un fundido en cuanto se copia,
//     así nunca hay una carrera con el suspend.
//   • Mismo diseño que tu hyprlock.conf: saludo, reloj grande, línea, campo
//     con ❄, texto inferior; fondo con blur/brillo/contraste parecidos.
//   • OSD de Caps Lock propio (el del shell queda tapado por el bloqueo): la
//     píldora aparece al activar/desactivar Caps y, además, el borde y los ❄
//     del campo cambian de color mientras esté activo (capslock_color).
//
// ─── Cómo se llama ────────────────────────────────────────────────────
//   quickshell ipc -p .../shell.qml call -- lock lock      (hypridle y bind)
//   quickshell ipc -p .../shell.qml call -- lock locked    (true/false)
// No hay IPC de "desbloquear": solo se sale con la contraseña.
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import "../COMMON"
import "../LANG"

Scope {
  id: root

  // Servicio PAM (archivo en /etc/pam.d)
  property string pamConfig: "login"

  readonly property bool locked: sessionLock.locked

  // Estado compartido entre todas las superficies (multi-monitor: se teclea
  // en cualquiera y el campo de todas se actualiza)
  property string wallUrl: ""
  property string password: ""
  property bool checking: false
  property bool failed: false
  property string failText: ""
  property int failCount: 0

  property bool capsOn: false
  property bool capsGot: false
  property bool capsOsdVisible: false

  // Acento para Caps (hyprlock: $tertiary): primario con el tono girado
  readonly property color capsColor: Qt.hsla(
    (Theme.primary.hslHue + 0.15) % 1.0,
    Math.max(0.55, Theme.primary.hslSaturation), 0.68, 1)

  // ═══ API ═════════════════════════════════════════════════════════
  function lock() {
    if (sessionLock.locked) return
    root.password = ""
    root.checking = false
    root.failed = false
    root.wallUrl = ""
    root.capsGot = false
    root.capsOsdVisible = false
    // Primero el bloqueo (instantáneo); el wallpaper llega enseguida
    sessionLock.locked = true
    snapProc.running = true
  }

  function unlockNow() {
    root.password = ""
    root.checking = false
    root.failed = false
    sessionLock.locked = false
    cleanupProc.running = true
  }

  function submit() {
    if (root.checking || root.password.length === 0) return
    root.failed = false
    root.checking = true
    if (!pam.start()) root.fail(-1)
  }

  function fail(result) {
    root.checking = false
    root.password = ""
    root.failText = result === PamResult.MaxTries ? Translations.t("lockTooMany")
                  : result === PamResult.Failed   ? Translations.t("lockWrong")
                  : Translations.t("lockError")
    root.failed = true
    root.failCount++
    failTimer.restart()
  }

  function toUrl(path) {
    return path === "" ? "" : "file://" + path.split("/").map(encodeURIComponent).join("/")
  }

  Timer {
    id: failTimer
    interval: 2600
    onTriggered: root.failed = false
  }

  SystemClock { id: clock; precision: SystemClock.Minutes }

  // ═══ Wallpaper del momento del bloqueo ═══════════════════════════
  Process {
    id: snapProc
    // $1 = modo ("auto" | "custom"), $2 = ruta elegida en Ajustes avanzados →
    // General. Con "custom" y una ruta válida se usa esa imagen; si no
    // existe, cae al wallpaper actual (auto).
    command: ["bash", "-c", [
      'dir="$HOME/.cache/oozeshell"; mkdir -p "$dir"',
      'wp=""',
      'if [ "$1" = custom ] && [ -n "$2" ]; then',
      '  p="$2"',
      '  case "$p" in "~"|"~/"*) p="$HOME${p#\\~}";; esac',
      '  p="${p/#\\$HOME/$HOME}"',
      '  [ -f "$p" ] && wp="$p"',
      'fi',
      '[ -n "$wp" ] || wp=$(cat "$HOME/.cache/awww/last" 2>/dev/null)',
      '[ -f "$wp" ] || wp=$(awww query 2>/dev/null | grep -oP "(?<=image: ).*" | head -n1)',
      '[ -f "$wp" ] || exit 0',
      'ext=$(printf %s "${wp##*.}" | tr -cd "A-Za-z0-9"); [ -n "$ext" ] || ext=img',
      'rm -f "$dir"/lock-bg-* 2>/dev/null',
      'out="$dir/lock-bg-$(date +%s%N).$ext"',
      'cp -f -- "$wp" "$out" && printf "%s\\n" "$out"'
    ].join("\n"), "sh", Theme.lockWallpaperMode, Theme.lockWallpaperPath]
    stdout: SplitParser {
      onRead: line => {
        const p = line.trim()
        if (p !== "" && sessionLock.locked) root.wallUrl = root.toUrl(p)
      }
    }
  }

  Process {
    id: cleanupProc
    command: ["bash", "-c", 'rm -f "$HOME"/.cache/oozeshell/lock-bg-* 2>/dev/null']
  }

  // ═══ PAM ═════════════════════════════════════════════════════════
  PamContext {
    id: pam
    config: root.pamConfig

    onPamMessage: {
      // Solo se responde cuando PAM pide algo (los mensajes informativos,
      // p. ej. de huella, se ignoran)
      if (pam.responseRequired) {
        pam.respond(root.password)
        root.password = ""
      }
    }
    onCompleted: result => {
      if (result === PamResult.Success) root.unlockNow()
      else root.fail(result)
    }
    onError: root.fail(-1)
  }

  // ═══ Caps Lock ═══════════════════════════════════════════════════
  Timer {
    id: capsHide
    interval: 1400
    onTriggered: root.capsOsdVisible = false
  }

  // Polling cada 150ms con Process de vida corta (robusto a recargas del shell)
  Timer {
    id: capsPoll
    interval: 150
    repeat: true
    running: sessionLock.locked
    triggeredOnStart: true
    onTriggered: capsCheck.running = true
  }

  Process {
    id: capsCheck
    command: ["bash", "-c", "on=0; found=0; for f in /sys/class/leds/*capslock/brightness; do [ -r \"$f\" ] || continue; found=1; read -r v < \"$f\" && [ \"${v:-0}\" != \"0\" ] && on=1; done; echo \"$on\""]
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: line => {
        const s = line.trim()
        if (s !== "0" && s !== "1") return
        const on = s === "1"
        const first = !root.capsGot
        const changed = root.capsOn !== on
        root.capsGot = true
        root.capsOn = on
        if (changed || (first && on)) {
          root.capsOsdVisible = true
          capsHide.restart()
        }
      }
    }
  }

  // ═══ Superficies (una por monitor) ═══════════════════════════════
  WlSessionLock {
    id: sessionLock
    locked: false

    WlSessionLockSurface {
      id: surface
      color: Theme.bg
    
      // ── Fondo: wallpaper con blur/brillo/contraste (como hyprlock.conf) ──
      Image {
        id: bgImg
        anchors.fill: parent
        source: root.wallUrl
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        sourceSize: Qt.size(surface.width, surface.height)
        visible: Theme.performanceMode
      }
      Rectangle {
        anchors.fill: parent
        visible: Theme.performanceMode
        color: "black"
        opacity: 0.4
      }
      MultiEffect {
        anchors.fill: parent
        visible: !Theme.performanceMode
        source: bgImg
        autoPaddingEnabled: false
        blurEnabled: true
        blur: 0.45
        blurMax: 48
        brightness: -0.18
        contrast: -0.11
        saturation: 0.17
        opacity: bgImg.status === Image.Ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.animDuration(350) } }
      }

      // ── Entrada de teclado ──
      Item {
        id: keys
        anchors.fill: parent
        focus: true
        Component.onCompleted: keys.forceActiveFocus()

        Keys.onPressed: event => {
          event.accepted = true
          if (root.checking) return

          if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.submit()
            return
          }
          if (event.key === Qt.Key_Escape
              || (event.key === Qt.Key_U && (event.modifiers & Qt.ControlModifier))) {
            root.password = ""
            return
          }
          if (event.key === Qt.Key_Backspace) {
            root.password = (event.modifiers & Qt.ControlModifier)
              ? "" : root.password.slice(0, -1)
            return
          }
          if (event.modifiers & (Qt.ControlModifier | Qt.MetaModifier)) return
          if (event.text.length > 0) {
            const c = event.text.charCodeAt(0)
            if (c >= 32 && c !== 127) {
              root.failed = false
              root.password += event.text
            }
          }
        }
      }

      // ── Contenido (posiciones idénticas a hyprlock.conf, medidas desde
      //    el centro: positivo = arriba) ──
      Item {
        id: content
        anchors.fill: parent

        // Reloj
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.verticalCenter: parent.verticalCenter
          anchors.verticalCenterOffset: -145
          text: Qt.formatTime(clock.date, "HH:mm")
          color: Theme.primary
          font.pixelSize: 88
          font.bold: true
          font.family: Theme.fontFamily
        }

        // Línea decorativa
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.verticalCenter: parent.verticalCenter
          anchors.verticalCenterOffset: -85
          text: "─────────────"
          color: Theme.primary
          font.pixelSize: 12
          font.family: Theme.fontFamily
        }

        // Saludo
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.verticalCenter: parent.verticalCenter
          anchors.verticalCenterOffset: -55
          text: "󰌾  " + Translations.t("lockWelcome") + ", " + UserProfile.shownName
          color: Theme.subtext
          font.pixelSize: 18
          font.family: Theme.monoFamily
        }

        // Campo de contraseña
        Rectangle {
          id: field
          width: 280
          height: 54
          radius: 22
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.verticalCenter: parent.verticalCenter
          anchors.verticalCenterOffset: 55
          color: Theme.surfaceHigh
          border.width: 2
          border.color: root.failed ? Theme.error
                      : root.checking ? Theme.text
                      : root.capsOn ? root.capsColor
                      : Theme.primary
          Behavior on border.color { ColorAnimation { duration: Theme.animDuration(150) } }

          transform: Translate { id: shake; x: 0 }
          SequentialAnimation {
            id: shakeAnim
            NumberAnimation { target: shake; property: "x"; to: -14; duration: Theme.animDuration(50) }
            NumberAnimation { target: shake; property: "x"; to: 14;  duration: Theme.animDuration(90) }
            NumberAnimation { target: shake; property: "x"; to: -9;  duration: Theme.animDuration(80) }
            NumberAnimation { target: shake; property: "x"; to: 6;   duration: Theme.animDuration(70) }
            NumberAnimation { target: shake; property: "x"; to: 0;   duration: Theme.animDuration(60) }
          }
          Connections {
            target: root
            function onFailCountChanged() { shakeAnim.restart() }
          }

          // ❄ por cada carácter
          Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 36
            visible: root.password.length > 0
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideLeft
            text: "❄".repeat(root.password.length)
            font.letterSpacing: 4
            color: root.capsOn ? root.capsColor : Theme.text
            font.pixelSize: 22
            font.family: Theme.fontFamily
          }

          // Placeholder / estado
          Text {
            anchors.centerIn: parent
            visible: root.password.length === 0
            text: root.checking ? "󰔟  " + Translations.t("lockChecking")
                                : "󰌾  " + Translations.t("lockPlaceholder")
            color: Theme.subtext
            font.italic: true
            font.pixelSize: 14
            font.family: Theme.monoFamily
          }
        }

        // Avisos bajo el campo: Caps Lock (mientras esté activo) y error
        Column {
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.top: field.bottom
          anchors.topMargin: 14
          spacing: 8

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "⇪  " + Translations.t("lockCapsOn")
            color: root.capsColor
            font.bold: true
            font.pixelSize: 13
            font.family: Theme.fontFamily
            opacity: root.capsOn ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.animDuration(180) } }
          }

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.failText
            color: Theme.error
            font.pixelSize: 13
            font.family: Theme.fontFamily
            opacity: root.failed ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.animDuration(180) } }
          }
        }

        // OSD de Caps Lock (mismo look que CAPS/CapsOSD.qml)
        Rectangle {
          id: capsCard
          z: 100
          readonly property int fullHeight: 58
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.bottom: parent.bottom
          anchors.bottomMargin: 96
          width: 210
          height: root.capsOsdVisible ? fullHeight : 0
          clip: true
          radius: Theme.panelRadius
          color: Theme.bg
          opacity: Math.max(0, Math.min(1, height / fullHeight))
          scale: 0.94 + 0.06 * opacity
          Behavior on height { NumberAnimation { duration: Theme.animDuration(160); easing.type: Easing.OutCubic } }

          RowLayout {
            width: capsCard.width - 32
            height: capsCard.fullHeight - 16
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            spacing: 12

            Rectangle {
              Layout.preferredWidth: 34
              Layout.preferredHeight: 34
              radius: 10
              color: root.capsOn ? Theme.primary : Theme.surface
              Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }

              Text {
                anchors.centerIn: parent
                text: "⇪"
                color: root.capsOn ? Theme.textOnPrimary : Theme.subtext
                font.pixelSize: 20
                font.bold: true
                font.family: Theme.fontFamily
              }
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 0

              Text {
                text: "Caps Lock"
                color: Theme.text
                font.pixelSize: 13
                font.bold: true
                font.family: Theme.fontFamily
              }
              Text {
                text: root.capsOn ? Translations.t("capsOn") : Translations.t("capsOff")
                color: root.capsOn ? Theme.primary : Theme.subtext
                font.pixelSize: 11
                font.family: Theme.fontFamily
                Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
              }
            }
          }
        }

        // Texto inferior
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.bottom: parent.bottom
          anchors.bottomMargin: 45
          text: "Mango  •  " + UserProfile.userName
          color: Theme.subtext
          font.pixelSize: 13
          font.family: Theme.fontFamily
        }
      }
    }
  }
}