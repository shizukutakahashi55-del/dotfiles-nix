// UserProfile — datos del usuario que se muestran en el shell (por ahora, la foto de perfil). Un singleton compartido: el Menu la dibuja y el panel

pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  readonly property string dir: Quickshell.env("HOME") + "/.config/oozeshell"
  readonly property string file: dir + "/profile.json"

  readonly property string userName: Quickshell.env("USER") || ""


  property string displayName: ""

  readonly property string shownName: root.displayName.trim() !== "" ? root.displayName.trim() : root.userName


  property string avatarPath: ""

  property string faceFallback: ""

  readonly property string avatarSource: avatarPath !== "" ? avatarPath : faceFallback
  readonly property string avatarUrl: root.fileUrl(avatarSource)

  readonly property bool busy: copyProc.running


  function shq(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }


  function fileUrl(path) {
    if (!path) return ""
    return "file://" + encodeURI(path).replace(/#/g, "%23").replace(/\?/g, "%3F")
  }

  function save() {
    saveProc.json = JSON.stringify({ avatarPath: root.avatarPath, displayName: root.displayName })
    saveProc.running = false
    saveProc.running = true
  }

  function setDisplayName(name) {
    root.displayName = String(name)
    root.save()
  }


  function chooseAvatar(src) {
    if (!src) return
    const ext = (String(src).split(".").pop() || "png").toLowerCase().replace(/[^a-z0-9]/g, "") || "png"
    copyProc.dest = root.dir + "/avatar-" + Date.now() + "." + ext
    copyProc.src = src
    copyProc.running = false
    copyProc.running = true
  }

  function clearAvatar() {
    root.avatarPath = ""
    root.save()
    cleanProc.running = false
    cleanProc.running = true
  }

  // ─── Copiar la foto elegida ─────────────────────────────────────

  Process {
    id: copyProc
    property string src: ""
    property string dest: ""
    command: ["bash", "-c",
      "mkdir -p " + root.shq(root.dir) + " && cp -f -- " + root.shq(src) + " " + root.shq(dest) +
      " && find " + root.shq(root.dir) + " -maxdepth 1 -type f -name 'avatar-*' ! -path " + root.shq(dest) + " -delete"]
    running: false
    stderr: SplitParser { onRead: line => console.log("[profile]", line) }
    onExited: (code, status) => {
      if (code === 0) {
        root.avatarPath = copyProc.dest
        root.save()
      } else {
        console.log("[profile] no se pudo copiar la imagen (código " + code + ")")
      }
    }
  }

  Process {
    id: cleanProc
    command: ["bash", "-c", "find " + root.shq(root.dir) + " -maxdepth 1 -type f -name 'avatar-*' -delete 2>/dev/null; true"]
    running: false
  }

  // ─── Persistencia ───────────────────────────────────────────────
  Process {
    id: loadProc
    command: ["bash", "-c", "cat " + root.shq(root.file) + " 2>/dev/null"]
    running: true
    property string buffer: ""
    stdout: SplitParser { onRead: line => loadProc.buffer += line }
    onRunningChanged: {
      if (running) return
      const raw = loadProc.buffer.trim()
      loadProc.buffer = ""
      if (raw === "") return
      try {
        const j = JSON.parse(raw)
        if (typeof j.avatarPath === "string") root.avatarPath = j.avatarPath
        if (typeof j.displayName === "string") root.displayName = j.displayName
      } catch (e) {
        console.log("UserProfile: error leyendo profile.json:", e)
      }
    }
  }

  Process {
    id: saveProc
    property string json: ""
    command: ["bash", "-c",
      "mkdir -p " + root.shq(root.dir) + " && cat > " + root.shq(root.file) + " << 'OOZE_EOF'\n" + json + "\nOOZE_EOF\n"]
    running: false
  }


  Process {
    id: faceProc
    command: ["bash", "-c",
      "for f in \"$HOME/.face\" \"$HOME/.config/rofi/images/user.png\"; do [ -f \"$f\" ] && { echo \"$f\"; break; }; done; true"]
    running: true
    stdout: SplitParser { onRead: line => { if (line.trim() !== "") root.faceFallback = line.trim() } }
  }
}
