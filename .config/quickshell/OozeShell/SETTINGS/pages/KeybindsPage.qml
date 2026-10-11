// KeybindsPage — categoría "Keybinds": edita los atajos de Hyprland.
// Lee keybinds.lua con Keybinds/keybinds_tool.py (parsea hl.bind, incluidos bloques multilinea y mainMod .. " + X"). Los bucles `for` (workspaces 1-10) salen como no editables.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import ".."
import "../../COMMON"
import "../../LANG"

SettingsPage {
  id: page
  catId: "keybinds"

  readonly property string tool: Quickshell.env("HOME")
    + "/.config/quickshell/OozeShell/Keybinds/keybinds_tool.py"

  property var binds: []
  property bool loading: false
  property bool busy: false
  property string filter: ""
  property string cat: "all"
  property string status: ""
  property string error: ""
  property string editingId: ""
  property string confirmId: ""

  function sayOk() {
    page.status = Translations.t("kbApplied")
    page.error = ""
    statusTimer.restart()
  }
  function sayErr(raw) {
    const r = String(raw ?? "").trim().split("\n").filter(l => l.trim() !== "").join(" · ")
    page.error = r.indexOf("en uso") >= 0
      ? Translations.t("kbDup") + " (" + r + ")"
      : (r !== "" ? r : "error")
    page.status = ""
    statusTimer.restart()
  }

  readonly property var catDefs: [
    { id: "apps",       icon: "󰀻", key: "kbCatApps" },
    { id: "windows",    icon: "󱂬", key: "kbCatWindows" },
    { id: "focus",      icon: "󰁌", key: "kbCatFocus" },
    { id: "move",       icon: "󰆾", key: "kbCatMove" },
    { id: "layout",     icon: "󰕰", key: "kbCatLayout" },
    { id: "workspaces", icon: "󰊓", key: "kbCatWorkspaces" },
    { id: "special",    icon: "󰘔", key: "kbCatSpecial" },
    { id: "shell",      icon: "󰆍", key: "kbCatShell" },
    { id: "shots",      icon: "󰄀", key: "kbCatShots" },
    { id: "other",      icon: "󰇘", key: "kbCatOther" }
  ]

  function catOf(b) { return b.category ?? "other" }

  readonly property var textFiltered: {
    const q = page.filter.trim().toLowerCase()
    if (q === "") return page.binds
    return page.binds.filter(b =>
      String(b.combo).toLowerCase().indexOf(q) >= 0
      || String(b.desc).toLowerCase().indexOf(q) >= 0
      || String(b.action).toLowerCase().indexOf(q) >= 0)
  }

  readonly property var catCounts: {
    const c = { all: page.textFiltered.length }
    for (const b of page.textFiltered) c[page.catOf(b)] = (c[page.catOf(b)] ?? 0) + 1
    return c
  }

  readonly property var presentCats: {
    const seen = {}
    for (const b of page.binds) seen[page.catOf(b)] = true
    return page.catDefs.filter(d => seen[d.id])
  }

  readonly property var navIds: ["all"].concat(page.presentCats.map(d => d.id))

  readonly property var filtered: page.cat === "all"
    ? page.textFiltered
    : page.textFiltered.filter(b => page.catOf(b) === page.cat)

  function stepCat(delta) {
    const ids = page.navIds
    const i = Math.max(0, ids.indexOf(page.cat))
    page.cat = ids[(i + delta + ids.length) % ids.length]
  }

  onBindsChanged: { if (page.navIds.indexOf(page.cat) < 0) page.cat = "all" }

  function tagOf(b) {
    if (b.status === "modified") return Translations.t("kbTagModified")
    if (b.status === "disabled") return Translations.t("kbTagDisabled")
    if (b.status === "custom") return Translations.t("kbTagCustom")
    return ""
  }


  readonly property string wmId: WM.wm
  readonly property bool isHypr: page.wmId === "hyprland"
  property string srcFile: ""

  // ─── Lista ───────────────────────────────────────────────────────
  function refresh() {
    if (page.loading) return
    page.loading = true
    listErr.buf = ""
    listProc.running = false
    listProc.running = true
  }

  Process {
    id: listProc
    command: page.isHypr ? ["python3", page.tool, "list"]
                         : ["python3", page.tool, "list", "--wm", page.wmId]
    stdout: SplitParser {
      id: listOut
      onRead: line => listProc.buf += line + "\n"
    }
    stderr: SplitParser {
      id: listErr
      property string buf: ""
      onRead: line => listErr.buf += line + "\n"
    }
    property string buf: ""
    onRunningChanged: {
      if (running) { listProc.buf = ""; return }
      page.loading = false
      if (listErr.buf.trim() !== "") { page.sayErr(listErr.buf); return }
      try {
        const j = JSON.parse(listProc.buf)
        page.binds = j.binds
        page.srcFile = j.file ?? ""
      } catch (e) {
        page.sayErr("parse: " + e)
      }
    }
  }

  // ─── Mutación genérica: mutArgs = ["disable", id] etc. ────────────
  property var mutArgs: []
  function run(args) {
    if (page.busy) return
    page.mutArgs = args
    mutErr.buf = ""
    mutProc.running = false
    mutProc.running = true
  }

  Process {
    id: mutProc
    command: ["python3", page.tool].concat(page.mutArgs)
    stdout: SplitParser { onRead: line => mutProc.buf += line + "\n" }
    stderr: SplitParser {
      id: mutErr
      property string buf: ""
      onRead: line => mutErr.buf += line + "\n"
    }
    property string buf: ""
    onRunningChanged: {
      if (running) { mutProc.buf = ""; page.busy = true; return }
      page.busy = false
      page.editingId = ""
      page.confirmId = ""
      if (mutErr.buf.trim() !== "") { page.sayErr(mutErr.buf); return }
      page.refresh()
      reloadProc.running = false
      reloadProc.running = true
    }
  }

  Process {
    id: reloadProc
    command: ["hyprctl", "reload"]
    stderr: SplitParser { onRead: line => console.log("[keybinds] hyprctl:", line) }
    onRunningChanged: if (!running) page.sayOk()
  }

  Timer { id: statusTimer; interval: 5000; repeat: false; onTriggered: { page.status = ""; page.error = "" } }

  onActiveChanged: if (page.active && page.binds.length === 0 && !page.loading) page.refresh()

  // ─── Piezas ──────────────────────────────────────────────────────
  component Label: Text {
    Layout.fillWidth: true
    wrapMode: Text.WordWrap
    color: Theme.text
    font.pixelSize: Theme.fs(12)
    font.family: Theme.fontFamily
  }

  component Field: SkinRect {
    id: fld
    property alias text: fldInput.text
    property string placeholder: ""
    Layout.fillWidth: true
    Layout.preferredHeight: 34
    radius: 10
    color: Theme.bg
    border.width: fldInput.activeFocus ? 1 : 0
    border.color: Theme.primary
    TextInput {
      id: fldInput
      anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
      verticalAlignment: TextInput.AlignVCenter
      color: Theme.text
      selectionColor: Theme.primary
      selectedTextColor: Theme.textOnPrimary
      font.pixelSize: Theme.fs(12)
      font.family: Theme.monoFamily
      clip: true
      inputMethodHints: Qt.ImhNoPredictiveText
      Text {
        visible: fldInput.text === "" && !fldInput.activeFocus && fld.placeholder !== ""
        text: fld.placeholder
        color: Theme.subtext
        font.pixelSize: Theme.fs(12)
        font.family: Theme.fontFamily
      }
    }
  }

  // ═══ Lista ═══════════════════════════════════════════════════════
  SettingsSection {
    titleKey: "kbListTitle"
    hintKey: page.isHypr ? "kbListHint" : "kbManualHint"


    Flow {
      visible: !page.isHypr
      Layout.fillWidth: true
      spacing: 8
      SettingsBtn {
        icon: "󰈔"
        text: Translations.t("kbOpenFile")
        enabled: page.srcFile !== "" && !page.loading
        onClicked: Quickshell.execDetached(["xdg-open", page.srcFile])
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: 8
      Field {
        id: filterInput
        Layout.fillWidth: true
        placeholder: "SUPER + T…"
        onTextChanged: page.filter = text
      }
      SettingsBtn {
        icon: "󰑓"
        text: Translations.t("kbRefresh")
        enabled: !page.loading && !page.busy
        onClicked: page.refresh()
      }
    }

    Flow {
      Layout.fillWidth: true
      spacing: 6

      SettingsBtn {
        icon: "󰕮"
        text: Translations.t("kbCatAll") + " · " + (page.catCounts.all ?? 0)
        primary: page.cat === "all"
        onClicked: page.cat = "all"
      }
      Repeater {
        model: page.presentCats
        delegate: SettingsBtn {
          required property var modelData
          icon: modelData.icon
          text: Translations.t(modelData.key) + " · " + (page.catCounts[modelData.id] ?? 0)
          primary: page.cat === modelData.id
          opacity: (page.catCounts[modelData.id] ?? 0) > 0 ? 1.0 : 0.45
          onClicked: page.cat = modelData.id
        }
      }
    }

    Text {
      Layout.fillWidth: true
      text: page.loading ? "…" : (page.filtered.length + " / " + page.binds.length)
      color: Theme.subtext
      font.pixelSize: Theme.fs(10)
      font.family: Theme.monoFamily
    }
    Text {
      visible: page.status !== ""
      Layout.fillWidth: true
      wrapMode: Text.WordWrap
      text: "󰄬 " + page.status
      color: Theme.primary
      font.pixelSize: Theme.fs(11)
      font.family: Theme.fontFamily
    }
    Text {
      visible: page.error !== ""
      Layout.fillWidth: true
      wrapMode: Text.WordWrap
      text: "󰅖 " + page.error
      color: Theme.error
      font.pixelSize: Theme.fs(11)
      font.family: Theme.fontFamily
    }
    Text {
      visible: !page.loading && page.filtered.length === 0
      Layout.fillWidth: true
      text: Translations.t("kbEmpty")
      color: Theme.subtext
      font.pixelSize: Theme.fs(11)
      font.family: Theme.fontFamily
    }

    Repeater {
      model: page.filtered
      delegate: SkinRect {
        id: row
        required property var modelData
        readonly property bool editing: page.editingId === row.modelData.id
        readonly property bool confirming: page.confirmId === row.modelData.id
        readonly property bool gone: row.modelData.status === "disabled"
        Layout.fillWidth: true
        implicitHeight: rowCol.implicitHeight + 20
        radius: 10
        color: row.editing ? Theme.surfaceHigh : Theme.bg
        border.width: row.modelData.status === "modified" ? 1 : 0
        border.color: Theme.primary
        opacity: row.gone ? 0.55 : 1
        clip: true

        ColumnLayout {
          id: rowCol
          anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
          spacing: 6

          RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text {
              Layout.fillWidth: true
              elide: Text.ElideRight
              text: row.modelData.combo
              color: row.gone ? Theme.subtext : Theme.primary
              font.bold: true
              font.pixelSize: Theme.fs(13)
              font.family: Theme.monoFamily
            }
            Text {
              visible: page.tagOf(row.modelData) !== ""
              text: page.tagOf(row.modelData)
              color: Theme.primary
              font.pixelSize: Theme.fs(10)
              font.family: Theme.fontFamily
            }
            SettingsBtn {
              visible: row.modelData.editable && !row.gone
              text: Translations.t("kbEdit")
              enabled: !page.busy
              onClicked: { page.confirmId = ""; page.editingId = row.modelData.id }
            }
            SettingsBtn {
              visible: row.gone || row.modelData.status === "modified"
              text: Translations.t("kbRestore")
              enabled: !page.busy
              onClicked: page.run(["restore", row.modelData.id])
            }
            SettingsBtn {
              visible: !row.gone
              icon: row.confirming ? "󰄬" : "󰆴"
              text: Translations.t("kbDelete")
              primary: row.confirming
              enabled: !page.busy && row.modelData.editable
              onClicked: {
                if (row.modelData.custom) {
                  if (!row.confirming) { page.confirmId = row.modelData.id; return }
                  page.run(["delete-custom", row.modelData.id])
                } else {
                  if (!row.confirming) { page.confirmId = row.modelData.id; return }
                  page.run(["disable", row.modelData.id])
                }
              }
            }
          }

          Text {
            visible: row.modelData.desc !== ""
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: row.modelData.desc
            color: Theme.text
            font.pixelSize: Theme.fs(12)
            font.family: Theme.fontFamily
          }
          Text {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: (row.modelData.status === "modified" ? row.modelData.origCombo + " → " : "") + row.modelData.action
            color: Theme.subtext
            font.pixelSize: Theme.fs(10)
            font.family: Theme.monoFamily
          }
          Text {
            visible: row.modelData.generated
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: Translations.t("kbGeneratedNote")
            color: Theme.subtext
            font.pixelSize: Theme.fs(10)
            font.family: Theme.fontFamily
          }

          RowLayout {
            visible: row.editing
            Layout.fillWidth: true
            spacing: 8
            Field {
              id: editInput
              Layout.fillWidth: true
              Component.onCompleted: editInput.text = row.modelData.combo
              Connections {
                target: page
                function onEditingIdChanged() {
                  if (page.editingId === row.modelData.id) editInput.text = row.modelData.combo
                }
              }
            }
            SettingsBtn {
              text: Translations.t("kbSave")
              primary: true
              enabled: !page.busy && editInput.text.trim() !== ""
              onClicked: {
                const c = editInput.text
                if (row.modelData.custom) page.run(["edit-custom", row.modelData.id, "--combo", c])
                else page.run(["override", row.modelData.id, "--combo", c])
              }
            }
            SettingsBtn {
              text: Translations.t("kbCancel")
              enabled: !page.busy
              onClicked: page.editingId = ""
            }
          }
        }
      }
    }
  }

  // ═══ Nuevo (solo Hyprland) ═══════════════════════════════════
  SettingsSection {
    visible: page.isHypr
    titleKey: "kbNewTitle"
    hintKey: "kbNewHint"

    Label { text: Translations.t("kbComboLabel") }
    Field { id: newCombo; placeholder: "SUPER + F1" }
    Label { text: Translations.t("kbCmdLabel") }
    Field { id: newCmd; placeholder: "kitty" }
    Label { text: Translations.t("kbDescLabel") }
    Field { id: newDesc; placeholder: "…" }

    SettingsBtn {
      icon: "󰐕"
      text: Translations.t("kbAdd")
      primary: true
      enabled: !page.busy && newCombo.text.trim() !== "" && newCmd.text.trim() !== ""
      onClicked: {
        page.run(["add", "--combo", newCombo.text, "--cmd", newCmd.text, "--desc", newDesc.text])
        newCombo.text = ""
        newCmd.text = ""
        newDesc.text = ""
      }
    }
  }
}
