// LockScreen — pantalla de bloqueo nativa (sustituye a hyprlock).
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


  property string pamConfig: "login"

  readonly property bool locked: sessionLock.locked


  property string wallUrl: ""
  property string password: ""
  property bool checking: false
  property bool failed: false
  property string failText: ""
  property int failCount: 0

  // ─── Caps Lock ───────────────────────────────────────────────


  property bool capsOn: false
  property bool capsHw: false
  property int capsPulse: 0

  function setCaps(on) {
    if (root.capsOn === on) return
    root.capsOn = on
    root.capsPulse++
  }


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
    root.capsOn = false
    root.capsHw = false
    if (pam.active) pam.abort()

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


  Process {
    id: capsWatch
    running: sessionLock.locked
    command: ["bash", "-c", [
      'prev=""; warned=0',
      'while :; do',
      '  on=0; found=0; delay=0.15',
      '  for f in /sys/class/leds/*capslock/brightness; do',
      '    [ -r "$f" ] || continue',
      '    found=1',
      '    read -r v < "$f" && [ "${v:-0}" != "0" ] && on=1',
      '  done',
      '  if [ "$found" = 0 ] && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then',
      '    found=1; delay=0.4',
      '    hyprctl devices -j 2>/dev/null | grep -q \'"capsLock": *true\' && on=1',
      '  fi',
      '  if [ "$found" = 0 ]; then',
      '    if [ "$warned" = 0 ]; then warned=1; echo N; fi',
      '    sleep 2; continue',
      '  fi',
      '  if [ "$on" != "$prev" ]; then echo "$on"; prev="$on"; fi',
      '  sleep $delay',
      'done'
    ].join("\n")]
    stdout: SplitParser {
      onRead: line => {
        const v = line.trim()
        if (v === "N") { root.capsHw = false; return }
        if (v !== "0" && v !== "1") return
        root.capsHw = true
        root.setCaps(v === "1")
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


      readonly property real u: Math.max(0.7, Math.min(1.3, surface.height / 1080))

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

      Rectangle {
        anchors.fill: parent
        gradient: Gradient {
          GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.10) }
          GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.38) }
        }
      }

      // ── Entrada de teclado ──
      Item {
        id: keys
        anchors.fill: parent
        focus: true
        Component.onCompleted: keys.forceActiveFocus()

        Keys.onPressed: event => {
          event.accepted = true


          if (event.key === Qt.Key_CapsLock) {
            if (!root.capsHw) root.setCaps(!root.capsOn)
            return
          }
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


          if (!root.capsHw && event.text.length === 1) {
            const ch = event.text
            if (ch.toLowerCase() !== ch.toUpperCase()) {
              const shift = (event.modifiers & Qt.ShiftModifier) !== 0
              root.setCaps((ch === ch.toUpperCase()) !== shift)
            }
          }

          if (event.text.length > 0) {
            const c = event.text.charCodeAt(0)
            if (c >= 32 && c !== 127) {
              root.failed = false
              root.password += event.text
            }
          }
        }
      }

      // ── Contenido ──
      Item {
        id: content
        anchors.fill: parent
        opacity: 0
        transform: Translate { id: rise; y: Math.round(14 * surface.u) }
        Component.onCompleted: enterAnim.start()

        ParallelAnimation {
          id: enterAnim
          NumberAnimation { target: content; property: "opacity"; to: 1
            duration: Theme.animDuration(320); easing.type: Easing.OutCubic }
          NumberAnimation { target: rise; property: "y"; to: 0
            duration: Theme.animDuration(420); easing.type: Easing.OutCubic }
        }

        ColumnLayout {
          anchors.centerIn: parent
          anchors.verticalCenterOffset: -Math.round(24 * surface.u)
          spacing: 0


          Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: 0
            Text {
              text: Qt.formatTime(clock.date, "HH")
              color: Theme.primary
              font.pixelSize: Math.round(128 * surface.u)
              font.bold: true
              font.family: Theme.titleFamily
            }
            Text {
              text: ":"
              color: Theme.subtext
              font.pixelSize: Math.round(128 * surface.u)
              font.bold: true
              font.family: Theme.titleFamily
              bottomPadding: Math.round(8 * surface.u)
            }
            Text {
              text: Qt.formatTime(clock.date, "mm")
              color: Theme.text
              font.pixelSize: Math.round(128 * surface.u)
              font.bold: true
              font.family: Theme.titleFamily
            }
          }


          Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: -Math.round(6 * surface.u)
            text: Qt.formatDate(clock.date, "dddd  •  d MMM").toUpperCase()
            color: Theme.subtext
            font.pixelSize: Math.round(18 * surface.u)
            font.letterSpacing: Math.round(3 * surface.u)
            font.family: Theme.fontFamily
          }


          Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Math.round(44 * surface.u)
            width: Math.round(104 * surface.u)
            height: width

            Rectangle {
              anchors.fill: parent
              radius: Theme.cozy ? 6 : width / 2
              color: "transparent"
              border.width: Math.max(2, Math.round(3 * surface.u))
              border.color: root.failed ? Theme.error : Theme.primary
              Behavior on border.color { ColorAnimation { duration: Theme.animDuration(150) } }
            }
            Avatar {
              anchors.centerIn: parent
              size: Math.round(92 * surface.u)
              source: UserProfile.avatarUrl
              letter: (UserProfile.shownName || "?").charAt(0).toUpperCase()
            }
          }


          Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Math.round(16 * surface.u)
            text: Translations.t("lockWelcome")
            color: Theme.subtext
            font.pixelSize: Math.round(14 * surface.u)
            font.family: Theme.fontFamily
          }
          Text {
            Layout.alignment: Qt.AlignHCenter
            text: UserProfile.shownName
            color: Theme.text
            font.pixelSize: Math.round(26 * surface.u)
            font.bold: true
            font.family: Theme.fontFamily
          }


          LockField {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Math.round(22 * surface.u)
            unit: surface.u
            password: root.password
            checking: root.checking
            failed: root.failed
            capsOn: root.capsOn
            capsColor: root.capsColor
            failCount: root.failCount
            placeholder: Translations.t("lockPlaceholder")
            checkingText: Translations.t("lockChecking")
            onSubmit: root.submit()
          }


          LockChip {
            Layout.alignment: Qt.AlignHCenter
            unit: surface.u
            shown: root.failed
            text: root.failText
            icon: "󰀦"
            tone: Theme.error
          }
          LockChip {
            Layout.alignment: Qt.AlignHCenter
            unit: surface.u
            shown: root.capsOn
            text: Translations.t("lockCapsOn")
            icon: "⇪"
            tone: root.capsColor
            pulse: root.capsPulse
          }
        }


        Row {
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.bottom: parent.bottom
          anchors.bottomMargin: Math.round(40 * surface.u)
          spacing: Math.round(8 * surface.u)
          visible: KeyboardLayout.layoutName !== ""

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "󰌌"
            color: Theme.subtext
            font.pixelSize: Math.round(18 * surface.u)
            font.family: Theme.fontFamily
          }
          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: KeyboardLayout.label
            color: Theme.subtext
            font.pixelSize: Math.round(14 * surface.u)
            font.bold: true
            font.family: Theme.fontFamily
          }
        }
      }
    }
  }
}
