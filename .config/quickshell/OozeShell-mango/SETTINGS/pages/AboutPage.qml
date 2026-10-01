// AboutPage — categoría "Acerca de": hero, info del sistema (siempre a la vista)
// y enlaces a los repos de Git.
//
// Migrada desde AdvancedSettings.qml (paso 3 de SIGUIENTE_FASE.md). El estado y el
// Process de la info del sistema viven ACÁ. La info se pide una vez al abrir
// la categoría (la página se construye al elegirla) y con el botón de refrescar.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import ".."
import "../../COMMON"
import "../../LANG"

SettingsPage {
  id: page
  catId: "about"
  spacing: 14

  Component.onCompleted: page.aboutRefreshSysInfo()

  // ── Acerca de: repos + info avanzada del sistema ─────────────────────
  readonly property var aboutRepos: [
    {
      icon: "󰆍",
      titleKey: "advAboutRepoDotfilesTitle",
      url: "https://github.com/shizukutakahashi55-del/dotfiles-nix"
    },
    {
      icon: "󱄅",
      titleKey: "advAboutRepoNixTitle",
      url: "https://github.com/shizukutakahashi55-del/nix-home"
    }
  ]
  property string aboutSysInfoText: ""
  property bool aboutSysInfoKnown: false

  // Nuestra caja de texto (Text + RichText) no interpreta ANSI: un código
  // como "\x1b[90m" no pinta nada, queda como un cuadradito sin glifo.
  // Ya no dependemos de fastfetch, pero se deja como limpieza defensiva
  // por si algún comando de abajo llega a colar color en el futuro.
  function aboutStripAnsi(s) {
    return s.replace(/\x1b\[[0-9;]*[a-zA-Z]/g, "")
  }

  // El backend imprime líneas planas "Clave: Valor" (sin terminal, sin
  // logo, sin colores) — se parsean acá para renderizarlas como filas
  // (mismo look que la tarjeta "SYSTEM" de la pestaña Usuario), en vez de
  // tirar todo como un bloque de texto tipo terminal.
  function aboutParseSysInfo(text) {
    if (text === "") return []
    return text.split("\n")
      .map(line => line.trim())
      .filter(line => line !== "")
      .map(line => {
        const idx = line.indexOf(": ")
        if (idx === -1) return { key: line, value: "" }
        return { key: line.slice(0, idx).trim(), value: line.slice(idx + 2).trim() }
      })
      .filter(row => row.value !== "")
  }

  readonly property var aboutSysInfoRows: page.aboutParseSysInfo(page.aboutSysInfoText)

  // Ícono por tipo de dato (heurística por palabra clave — el backend
  // reporta más o menos campos según la máquina, así que esto no depende
  // de una lista fija).
  function aboutIconFor(key) {
    const k = key.toLowerCase()
    if (k.includes("host")) return "󰍹"
    if (k === "os" || k.includes("operating")) return "󰌽"
    if (k.includes("kernel")) return "󰣇"
    if (k.includes("uptime")) return "󱑂"
    if (k.includes("package") || k.includes("pkgs")) return "󰏖"
    if (k.includes("shell")) return "󱆃"
    if (k === "de" || k.includes("desktop")) return "󰧨"
    if (k === "wm" || k.includes("window manager")) return "󱂬"
    if (k.includes("cpu") || k.includes("processor")) return "󰘚"
    if (k.includes("gpu")) return "󰢮"
    if (k.includes("memory") || k.includes("ram")) return "󰍛"
    if (k.includes("disk")) return "󰋊"
    if (k.includes("resolution") || k.includes("display") || k.includes("monitor")) return "󰍹"
    if (k.includes("terminal")) return "󰆍"
    if (k.includes("battery")) return "󰁹"
    if (k.includes("ip")) return "󰩟"
    if (k.includes("locale")) return "󰗊"
    return "󰋽"
  }

  function aboutRefreshSysInfo() {
    if (!aboutSysInfoProc.running) aboutSysInfoProc.running = true
  }

  Process {
    id: aboutSysInfoProc
    // Sin fastfetch (no siempre está instalado -- por eso la caja decía
    // "Couldn't read system information"): comandos estándar de
    // Linux/systemd/Mango ya presentes en cualquier NixOS, cada uno
    // imprimiendo su propia línea "Clave: Valor" en texto plano. Cada
    // sección tiene su propio guard (command -v / [ -n ]), así que si
    // algo no aplica en esta máquina (por ej. no hay batería) esa línea
    // simplemente no sale, en vez de romper el resto.
    command: ["bash", "-c", "echo \"Host: $(hostname)\"\n. /etc/os-release 2>/dev/null\necho \"OS: ${PRETTY_NAME:-${NAME:-Linux}}\"\necho \"Kernel: $(uname -r)\"\nread -r up _ < /proc/uptime\ns=${up%.*}\nd=$((s/86400)); h=$((s%86400/3600)); m=$((s%3600/60))\nif [ \"$d\" -gt 0 ]; then echo \"Uptime: ${d}d ${h}h ${m}m\"\nelif [ \"$h\" -gt 0 ]; then echo \"Uptime: ${h}h ${m}m\"\nelse echo \"Uptime: ${m}m\"\nfi\necho \"Shell: $(basename \"${SHELL:-sh}\")\"\ndesktop=\"${XDG_CURRENT_DESKTOP:-${DESKTOP_SESSION:-}}\"\n[ -n \"${MANGO_INSTANCE_SIGNATURE:-}\" ] && desktop=\"Mango\"\n[ -n \"$desktop\" ] && echo \"Desktop: $desktop\"\ncpu_model=$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | sed 's/^ *//')\ncores=$(nproc 2>/dev/null)\nif [ -n \"$cpu_model\" ]; then\n  if [ -n \"$cores\" ]; then echo \"CPU: $cpu_model ($cores)\"\n  else echo \"CPU: $cpu_model\"\n  fi\nfi\nif command -v lspci >/dev/null 2>&1; then\n  gpu=$(lspci -mm 2>/dev/null | grep -Ei 'vga|3d|display' | head -n1 | sed -E 's/^[^\"]*\"[^\"]*\"[[:space:]]*\"[^\"]*\"[[:space:]]*\"([^\"]*)\"[[:space:]]*\"([^\"]*)\".*/\\1 \\2/')\n  [ -n \"$gpu\" ] && echo \"GPU: $gpu\"\nfi\nif command -v free >/dev/null 2>&1; then\n  mem=$(free -h 2>/dev/null | awk '/^Mem:/ {print $3 \" / \" $2}')\n  [ -n \"$mem\" ] && echo \"Memory: $mem\"\nfi\ndisk=$(df -h / 2>/dev/null | awk 'NR==2 {print $3 \" / \" $2 \" (\" $5 \")\"}')\n[ -n \"$disk\" ] && echo \"Disk: $disk\"\nip=$(hostname -I 2>/dev/null | awk '{print $1}')\n[ -n \"$ip\" ] && echo \"Local IP: $ip\"\n[ -n \"${LANG:-}\" ] && echo \"Locale: $LANG\"\nif command -v upower >/dev/null 2>&1; then\n  bat=$(upower -e 2>/dev/null | grep -m1 BAT)\n  if [ -n \"$bat\" ]; then\n    pct=$(upower -i \"$bat\" 2>/dev/null | awk -F: '/percentage/ {gsub(/ /,\"\",$2); print $2}')\n    state=$(upower -i \"$bat\" 2>/dev/null | awk -F: '/state/ {gsub(/ /,\"\",$2); print $2}')\n    [ -n \"$pct\" ] && echo \"Battery: $pct ($state)\"\n  fi\nfi\n"]
    running: false
    property var lines: []
    stdout: SplitParser { onRead: line => aboutSysInfoProc.lines.push(line) }
    stderr: SplitParser { onRead: line => aboutSysInfoProc.lines.push(line) }
    onRunningChanged: {
      if (running) { lines = []; return }
      page.aboutSysInfoText = page.aboutStripAnsi(lines.join("\n"))
      page.aboutSysInfoKnown = true
    }
  }

  // ── Hero: ícono + nombre + tagline en una fila compacta ──
  RowLayout {
    Layout.fillWidth: true
    spacing: 12

    SkinRect {
      Layout.preferredWidth: 42
      Layout.preferredHeight: 42
      radius: 13
      color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)

      Text {
        anchors.centerIn: parent
        text: "󰧨"
        color: Theme.primary
        font.pixelSize: Theme.fs(19)
        font.family: Theme.monoFamily
      }
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: 1

      Text {
        text: "OozeShell"
        color: Theme.text
        font.bold: true
        font.pixelSize: Theme.fs(14)
        font.family: Theme.fontFamily
      }

      Text {
        Layout.fillWidth: true
        elide: Text.ElideRight
        text: Translations.t("advAboutBuiltWith")
        color: Theme.subtext
        font.pixelSize: Theme.fs(10)
        font.family: Theme.fontFamily
      }
    }
  }

  // ── Información del sistema (siempre visible) ──
  SettingsSection {
    padding: 12
    spacing: 10

    RowLayout {
      Layout.fillWidth: true
      spacing: 8
      Text {
        text: "󰆍"
        color: Theme.subtext
        font.pixelSize: Theme.fs(13)
        font.family: Theme.monoFamily
      }
      Text {
        Layout.fillWidth: true
        text: Translations.t("advAboutSysInfoTitle")
        color: Theme.text
        font.bold: true
        font.pixelSize: Theme.fs(12)
        font.family: Theme.fontFamily
      }
      // ── Refrescar (gira mientras corren los comandos) ──
      SkinRect {
        Layout.preferredWidth: 22
        Layout.preferredHeight: 22
        radius: 7
        color: aboutRefreshArea.containsMouse ? Theme.surfaceHigh : Theme.bg
        border.width: Theme.bw1
        border.color: Theme.edge
        Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }
        Text {
          anchors.centerIn: parent
          text: "󰑐"
          color: Theme.subtext
          font.pixelSize: Theme.fs(11)
          font.family: Theme.monoFamily
          RotationAnimation on rotation {
            running: aboutSysInfoProc.running && Theme.uiAnimationsEnabled
            loops: Animation.Infinite
            from: 0; to: 360
            duration: Theme.animDuration(700)
          }
        }
        MouseArea {
          id: aboutRefreshArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: page.aboutRefreshSysInfo()
        }
      }
    }

    Text {
      Layout.fillWidth: true
      text: Translations.t("advAboutSysInfoSource")
      color: Theme.subtext
      font.pixelSize: Theme.fs(10)
      font.family: Theme.fontFamily
    }

    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }

    // ── Filas ícono + etiqueta + valor (mismo estilo que
    // la tarjeta "SYSTEM" de la pestaña Usuario) ──
    Repeater {
      model: page.aboutSysInfoRows
      delegate: RowLayout {
        required property var modelData
        Layout.fillWidth: true
        spacing: 10
        Text {
          text: page.aboutIconFor(modelData.key)
          color: Theme.primary
          font.pixelSize: Theme.fs(13)
          font.family: Theme.fontFamily
        }
        Text {
          text: modelData.key
          color: Theme.subtext
          font.pixelSize: Theme.fs(11)
          font.family: Theme.fontFamily
        }
        Item { Layout.fillWidth: true }
        Text {
          Layout.maximumWidth: 260
          horizontalAlignment: Text.AlignRight
          text: modelData.value
          color: Theme.text
          font.bold: true
          font.pixelSize: Theme.fs(11)
          elide: Text.ElideRight
          font.family: Theme.fontFamily
        }
      }
    }

    Text {
      visible: page.aboutSysInfoRows.length === 0
      Layout.fillWidth: true
      wrapMode: Text.WordWrap
      text: aboutSysInfoProc.running
        ? Translations.t("advAboutSysInfoLoading")
        : Translations.t("advAboutSysInfoEmpty")
      color: Theme.subtext
      font.italic: true
      font.pixelSize: Theme.fs(11)
      font.family: Theme.fontFamily
    }
  }

  // ── Repos (GitHub) — al final, abajo de todo ──
  SettingsSection {
    padding: 10
    spacing: 4

    Repeater {
      model: page.aboutRepos
      delegate: SkinRect {
        id: repoRow
        required property var modelData
        Layout.fillWidth: true
        Layout.preferredHeight: 48
        radius: 10
        clip: true
        color: repoArea.containsMouse ? Theme.surfaceHigh : Theme.surface
        Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }

        RowLayout {
          anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
          spacing: 12

          Text {
            text: repoRow.modelData.icon
            color: Theme.primary
            font.pixelSize: Theme.fs(16)
            font.family: Theme.monoFamily
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Text {
              text: Translations.t(repoRow.modelData.titleKey)
              color: Theme.text
              font.bold: true
              font.pixelSize: Theme.fs(12)
              font.family: Theme.fontFamily
            }
            Text {
              Layout.fillWidth: true
              elide: Text.ElideMiddle
              text: repoRow.modelData.url.replace(/^https?:\/\//, "")
              color: Theme.subtext
              font.pixelSize: Theme.fs(10)
              font.family: Theme.fontFamily
            }
          }

          Text {
            text: "󰏌"
            color: Theme.subtext
            font.pixelSize: Theme.fs(13)
            font.family: Theme.monoFamily
          }
        }

        MouseArea {
          id: repoArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: Qt.openUrlExternally(repoRow.modelData.url)
        }
      }
    }
  }
}
