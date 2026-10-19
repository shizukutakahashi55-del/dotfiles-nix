// AboutPage — categoría "Acerca de": hero, información del sistema, carpetas del shell y repos de Git.

import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import ".."
import "../../COMMON"
import "../../Services/Lang"

SettingsPage {
  id: page
  catId: "about"
  spacing: 14

  Component.onCompleted: page.aboutRefreshSysInfo()

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


  function aboutStripAnsi(s) {
    return s.replace(/\x1b\[[0-9;]*[a-zA-Z]/g, "")
  }


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


  readonly property var aboutRows: page.aboutSysInfoRows

  property bool aboutCopied: false
  function aboutCopy() {
    if (page.aboutRows.length === 0 || aboutCopyProc.running) return
    aboutCopyProc.payload = "OozeShell\n" + page.aboutRows.map(r => r.key + ": " + r.value).join("\n")
    aboutCopyProc.running = true
  }
  Process {
    id: aboutCopyProc
    property string payload: ""
    command: ["bash", "-c", "printf %s \"$1\" | wl-copy", "sh", aboutCopyProc.payload]
    running: false
    onRunningChanged: {
      if (running) return
      page.aboutCopied = true
      aboutCopiedTimer.restart()
    }
  }
  Timer { id: aboutCopiedTimer; interval: 1600; onTriggered: page.aboutCopied = false }

  readonly property string aboutHome: Quickshell.env("HOME")
  readonly property var aboutPaths: [
    { icon: "󰆍", label: "Shell",  path: Quickshell.shellDir },
    { icon: "󰒓", label: "Config", path: Theme.prefsDir },
    { icon: "󰃨", label: "Cache",  path: page.aboutHome + "/.cache/oozeshell" }
  ]


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
    if (k.includes("quickshell") || k === "qt") return "󰆧"
    return "󰋽"
  }

  function aboutRefreshSysInfo() {
    if (!aboutSysInfoProc.running) aboutSysInfoProc.running = true
  }

  Process {
    id: aboutSysInfoProc


    command: ["bash", "-c", "echo \"Host: $(hostname)\"\n. /etc/os-release 2>/dev/null\necho \"OS: ${PRETTY_NAME:-${NAME:-Linux}}\"\necho \"Kernel: $(uname -r)\"\nread -r up _ < /proc/uptime\ns=${up%.*}\nd=$((s/86400)); h=$((s%86400/3600)); m=$((s%3600/60))\nif [ \"$d\" -gt 0 ]; then echo \"Uptime: ${d}d ${h}h ${m}m\"\nelif [ \"$h\" -gt 0 ]; then echo \"Uptime: ${h}h ${m}m\"\nelse echo \"Uptime: ${m}m\"\nfi\necho \"Shell: $(basename \"${SHELL:-sh}\")\"\ndesktop=\"${XDG_CURRENT_DESKTOP:-${DESKTOP_SESSION:-}}\"\n[ -n \"${HYPRLAND_INSTANCE_SIGNATURE:-}\" ] && desktop=\"Hyprland\"\n[ -n \"$desktop\" ] && echo \"Desktop: $desktop\"\ncpu_model=$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | sed 's/^ *//')\ncores=$(nproc 2>/dev/null)\nif [ -n \"$cpu_model\" ]; then\n  if [ -n \"$cores\" ]; then echo \"CPU: $cpu_model ($cores)\"\n  else echo \"CPU: $cpu_model\"\n  fi\nfi\nif command -v lspci >/dev/null 2>&1; then\n  gpu=$(lspci -mm 2>/dev/null | grep -Ei 'vga|3d|display' | head -n1 | sed -E 's/^[^\"]*\"[^\"]*\"[[:space:]]*\"[^\"]*\"[[:space:]]*\"([^\"]*)\"[[:space:]]*\"([^\"]*)\".*/\\1 \\2/')\n  [ -n \"$gpu\" ] && echo \"GPU: $gpu\"\nfi\nif command -v free >/dev/null 2>&1; then\n  mem=$(free -h 2>/dev/null | awk '/^Mem:/ {print $3 \" / \" $2}')\n  [ -n \"$mem\" ] && echo \"Memory: $mem\"\nfi\ndisk=$(df -h / 2>/dev/null | awk 'NR==2 {print $3 \" / \" $2 \" (\" $5 \")\"}')\n[ -n \"$disk\" ] && echo \"Disk: $disk\"\nif command -v hyprctl >/dev/null 2>&1; then\n  res=$(hyprctl monitors 2>/dev/null | awk '/^Monitor/ {getline; print $1}' | head -n1)\n  [ -n \"$res\" ] && echo \"Resolution: $res\"\nfi\nip=$(hostname -I 2>/dev/null | awk '{print $1}')\n[ -n \"$ip\" ] && echo \"Local IP: $ip\"\n[ -n \"${LANG:-}\" ] && echo \"Locale: $LANG\"\nif command -v quickshell >/dev/null 2>&1; then echo \"Quickshell: $(quickshell --version 2>/dev/null | head -n1 | cut -c1-60)\"; fi\nqtv=$(qmake6 -query QT_VERSION 2>/dev/null || qmake -query QT_VERSION 2>/dev/null)\n[ -n \"$qtv\" ] && echo \"Qt: $qtv\"\nif command -v upower >/dev/null 2>&1; then\n  bat=$(upower -e 2>/dev/null | grep -m1 BAT)\n  if [ -n \"$bat\" ]; then\n    pct=$(upower -i \"$bat\" 2>/dev/null | awk -F: '/percentage/ {gsub(/ /,\"\",$2); print $2}')\n    state=$(upower -i \"$bat\" 2>/dev/null | awk -F: '/state/ {gsub(/ /,\"\",$2); print $2}')\n    [ -n \"$pct\" ] && echo \"Battery: $pct ($state)\"\n  fi\nfi\n"]
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
        font.pixelSize: Theme.sfs(19)
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
        font.pixelSize: Theme.sfs(14)
        font.family: Theme.fontFamily
      }

      Text {
        Layout.fillWidth: true
        elide: Text.ElideRight
        text: Translations.t("advAboutBuiltWith")
        color: Theme.subtext
        font.pixelSize: Theme.sfs(10)
        font.family: Theme.fontFamily
      }
    }
  }

  SettingsSection {
    titleKey: "advAboutSysInfoTitle"
    hintKey: "advAboutSysInfoSource"

    SettingsRow {
      titleKey: "advAboutCopy"

      SettingsBtn {
        icon: page.aboutCopied ? "󰄬" : "󰆏"
        text: page.aboutCopied ? Translations.t("advAboutCopied") : ""
        primary: page.aboutCopied
        enabled: page.aboutRows.length > 0
        onClicked: page.aboutCopy()
      }
      SettingsIconBtn {
        spinning: aboutSysInfoProc.running
        onClicked: page.aboutRefreshSysInfo()
      }
    }

    Repeater {
      model: page.aboutRows
      delegate: SettingsRow {
        required property var modelData
        title: modelData.key

        Text {
          Layout.alignment: Qt.AlignVCenter
          text: page.aboutIconFor(modelData.key)
          color: Theme.primary
          font.pixelSize: Theme.sfs(13)
          font.family: Theme.monoFamily
        }
        SettingsValue { text: modelData.value ?? "" }
      }
    }

    SettingsNote {
      visible: page.aboutSysInfoRows.length === 0
      text: aboutSysInfoProc.running
        ? Translations.t("advAboutSysInfoLoading")
        : Translations.t("advAboutSysInfoEmpty")
    }
  }

  SettingsSection {
    titleKey: "advAboutPathsTitle"

    Repeater {
      model: page.aboutPaths
      delegate: SettingsRow {
        required property var modelData
        title: modelData.label
        hint: modelData.path.replace(page.aboutHome, "~")

        SettingsBtn {
          icon: "󰏌"
          text: ""
          onClicked: Quickshell.execDetached(["xdg-open", modelData.path])
        }
      }
    }
  }

  SettingsSection {
    titleKey: "advAboutRepoTitle"

    Repeater {
      model: page.aboutRepos
      delegate: SettingsRow {
        required property var modelData
        title: Translations.t(modelData.titleKey)
        hint: modelData.url.replace(/^https?:\/\//, "")

        SettingsBtn {
          icon: "󰏌"
          text: ""
          onClicked: Qt.openUrlExternally(modelData.url)
        }
      }
    }
  }
}
