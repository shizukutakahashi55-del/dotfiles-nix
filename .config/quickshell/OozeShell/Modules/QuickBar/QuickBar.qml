// QuickBar (QuickSearch) — barra de búsqueda rápida, flotante y centrada en horizontal.

import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../COMMON"
import "../../COMMON/SafeModel.js" as SafeModel
import "../../Services/Lang"

Item {
  id: root

  property bool open: false
  property string targetScreen: ""

  property string startQuery: ""
  signal closeRequested()

  // ─── Medidas (lógicas: FusedPanel las escala según Ajustes → Ventanas) ──
  readonly property var widths: ({ compact: 540, normal: 660, wide: 820 })
  readonly property int cardW: root.widths[QuickBarConfig.widthMode] ?? 660
  readonly property int pad: 10
  readonly property int inputH: 52
  readonly property int rowH: 46
  readonly property int rowGap: 2
  readonly property int footH: 22
  readonly property int gap: 6
  readonly property int maxRows: 10

  readonly property int edgeGap: 14

  readonly property bool atBottom: QuickBarConfig.position === "bottom"

  readonly property string query: input.text
  readonly property var cls: QuickBarConfig.classify(root.query)
  property int selected: 0
  onQueryChanged: {
    root.selected = 0
    searchTimer.restart()
  }


  readonly property var webItems: {
    const c = root.cls
    if (c.kind === "empty") return []
    const browser = QuickBarConfig.browserName
    const out = []
    if (c.url !== "")
      out.push({ id: "u:" + c.url, type: "url", icon: "󰌷", title: c.url,
                 sub: Translations.t("qbOpenUrl") + "  ·  " + browser, url: c.url, opener: "" })
    if (c.kind === "bang") {
      out.push({ id: "b:" + c.bang.id + ":" + c.term, type: "search", icon: "󰖟",
                 title: Translations.t("qbSearchOn").replace("%1", c.term).replace("%2", c.bang.name),
                 sub: browser, url: QuickBarConfig.fillTemplate(c.bang.url, c.term), opener: "" })
    } else {
      out.push({ id: "s:" + c.term, type: "search", icon: "󰖟",
                 title: Translations.t("qbSearchFor").replace("%1", c.term),
                 sub: QuickBarConfig.engineName + "  ·  " + browser,
                 url: QuickBarConfig.searchUrl(c.term), opener: "" })
    }
    return out
  }


  property var fileLines: []

  readonly property var fileItems: {
    const c = root.cls
    if (!QuickBarConfig.filesEnabled || (c.kind !== "search" && c.kind !== "files")) return []
    if (c.term.length < 3) return []
    const terms = Fuzzy.terms(c.term)
    const lines = root.fileLines
    const scored = []
    for (let i = 0; i < lines.length; i++) {
      const l = lines[i]
      const isDir = l.charAt(l.length - 1) === "/"
      const path = isDir ? l.slice(0, -1) : l
      const slash = path.lastIndexOf("/")
      const name = path.slice(slash + 1)
      if (name === "") continue
      const s = Fuzzy.match(terms, [
        { text: name.toLowerCase(), w: 1.0 },
        { text: path.toLowerCase(),  w: 0.3 }
      ])
      if (s < 0) continue

      const depth = path.split("/").length
      const parent = slash > 0 ? path.slice(0, slash) : "/"
      scored.push({
        s: s - depth * 6 + (isDir ? 10 : 0),
        item: {
          id: "f:" + path, type: "file", icon: isDir ? "󰉋" : "󰈔",
          title: name, sub: QuickBarConfig.prettyPath(parent),
          path: path, isDir: isDir,
          opener: QuickBarConfig.usesEditor(path, isDir, false)
                    ? QuickBarConfig.editorBin : Translations.t("qbOpenerApp")
        }
      })
    }
    scored.sort((a, b) => b.s - a.s)
    return scored.slice(0, QuickBarConfig.fileMax).map(x => x.item)
  }


  readonly property var results: {
    const w = root.webItems
    const f = root.fileItems
    const all = root.cls.kind === "files" ? f.concat(w) : w.concat(f)
    return all.slice(0, root.maxRows)
  }


  property var displayResults: root.results
  onResultsChanged: Qt.callLater(root.syncDisplay)
  function syncDisplay() {
    const next = root.results
    // Un move en ScriptModel puede crashear Qt 6.11.2: si el orden cambia, reiniciar el modelo.
    if (SafeModel.wouldMove(root.displayResults, next, r => r.id)) root.displayResults = []
    root.displayResults = next
    if (root.selected >= root.displayResults.length)
      root.selected = Math.max(0, root.displayResults.length - 1)
  }

  readonly property var current: root.displayResults[root.selected] ?? null


  readonly property int rowsShown: root.displayResults.length
  readonly property int listH: root.rowsShown > 0
    ? root.rowsShown * root.rowH + (root.rowsShown - 1) * root.rowGap : 0
  readonly property int targetH: root.pad * 2 + root.inputH
    + (root.rowsShown > 0 ? root.gap + root.listH + 4 + root.footH : 0)

  property real animH: root.targetH
  Behavior on animH {
    enabled: Theme.uiAnimationsEnabled
    NumberAnimation { duration: Theme.animDuration(140); easing.type: Easing.OutCubic }
  }


  readonly property string hintText: {
    const it = root.current
    if (!it) return ""
    if (it.type === "file") {
      const a = QuickBarConfig.usesEditor(it.path, it.isDir, false)
                  ? QuickBarConfig.editorBin : Translations.t("qbOpenDefaultApp")
      const b = QuickBarConfig.usesEditor(it.path, it.isDir, true)
                  ? QuickBarConfig.editorBin : Translations.t("qbOpenDefaultApp")
      return Translations.t("qbHintFile").replace("%1", a).replace("%2", b)
    }

    if (QuickBarConfig.browser === null)
      return Translations.t("qbHintWebPlain").replace("%1", QuickBarConfig.browserName)
    return Translations.t("qbHintWeb").replace("%1", QuickBarConfig.browserName)
             .replace("%2", Translations.t(QuickBarConfig.privateWindow ? "qbWinNormal" : "qbWinPrivate"))
  }

  function move(delta) {
    const n = root.displayResults.length
    if (n === 0) return
    root.selected = Math.max(0, Math.min(n - 1, root.selected + delta))
  }


  function activate(alt) {
    const it = root.current
    if (!it) return

    if (root.cls.kind === "files" && root.busy && it.type !== "file") return
    if (it.type === "file") QuickBarConfig.openPath(it.path, it.isDir, alt)
    else QuickBarConfig.openWeb(it.url, alt)
    root.closeRequested()
  }

  property int fileGen: 0

  property string lastKey: ""
  readonly property bool busy: searchTimer.running || fileProc.running


  Timer {
    id: searchTimer
    interval: 250
    repeat: false
    onTriggered: root.runFileSearch()
  }


  readonly property string searchScript: [
    'gen="$1"; depth="$2"; max="$3"; hid="$4"; pat="$5"; shift 5',
    'echo "$gen"',
    'fdb=""',
    'command -v fd >/dev/null 2>&1 && fdb=fd',
    '[ -z "$fdb" ] && command -v fdfind >/dev/null 2>&1 && fdb=fdfind',
    '{',
    'if [ -n "$fdb" ]; then',
    '  h=""; [ "$hid" = 1 ] && h="--hidden"',
    '  to=""; command -v timeout >/dev/null 2>&1 && to="timeout 4"',
    '  $to "$fdb" --color never $h --ignore-case --fixed-strings --absolute-path --threads 2' +
      ' --max-depth "$depth" --max-results "$max"' +
      ' --exclude .git --exclude node_modules --exclude .cache --exclude result --exclude .nix-profile' +
      ' -- "$pat" "$@" 2>/dev/null',
    'else',
    '  to=""; command -v timeout >/dev/null 2>&1 && to="timeout 4"',
    '  for r in "$@"; do',
    '    if [ "$hid" = 1 ]; then',
    '      $to find "$r" -maxdepth "$depth" -mindepth 1 \\( -name .git -o -name node_modules -o -name .cache -o -name result -o -name .nix-profile \\) -prune -o -iname "*$pat*" -print 2>/dev/null',
    '    else',
    '      $to find "$r" -maxdepth "$depth" -mindepth 1 \\( -name ".*" -o -name node_modules -o -name result \\) -prune -o -iname "*$pat*" -print 2>/dev/null',
    '    fi',
    '  done | head -n "$max"',
    'fi',
    '} | while IFS= read -r p; do',
    '  if [ -d "$p" ]; then printf "%s/\\n" "$p"; else printf "%s\\n" "$p"; fi',
    'done',
    'exit 0'
  ].join("\n")

  function runFileSearch() {
    const c = root.cls
    const want = root.open && QuickBarConfig.filesEnabled
      && (c.kind === "search" || c.kind === "files") && c.term.length >= 3
    if (!want) {
      root.pendingSearch = false
      root.lastKey = ""
      if (root.fileLines.length > 0) root.fileLines = []
      return
    }

    const pat = Fuzzy.terms(c.term)[0]
    const roots = QuickBarConfig.rootList()
    const key = pat + "|" + QuickBarConfig.fileDepth + "|" + (QuickBarConfig.fileHidden ? 1 : 0) + "|" + roots.join(":")
    if (key === root.lastKey) return


    if (fileProc.running) { root.pendingSearch = true; return }
    root.lastKey = key

    fileProc.buf = []
    fileProc.gotGen = false
    fileProc.valid = false
    root.fileGen++
    fileProc.command = ["sh", "-c", root.searchScript, "sh", String(root.fileGen),
      String(QuickBarConfig.fileDepth), "300", QuickBarConfig.fileHidden ? "1" : "0", pat].concat(roots)
    fileProc.running = true
  }
  property bool pendingSearch: false

  Process {
    id: fileProc
    property var buf: []
    property bool gotGen: false
    property bool valid: false
    stdout: SplitParser {
      onRead: line => {
        if (!fileProc.gotGen) {
          fileProc.gotGen = true
          fileProc.valid = (line === String(root.fileGen))
          return
        }
        if (fileProc.valid && line !== "") fileProc.buf.push(line)
      }
    }
    onRunningChanged: {
      if (running) return
      if (fileProc.valid) root.fileLines = fileProc.buf.slice()
      if (root.pendingSearch && root.open) {
        root.pendingSearch = false
        root.runFileSearch()
      }
    }
  }

  onOpenChanged: {
    if (root.open) {
      root.selected = 0
      root.fileLines = []
      root.lastKey = ""
      input.text = root.startQuery
      input.cursorPosition = input.text.length
      root.syncDisplay()


      Qt.callLater(() => input.forceActiveFocus())
      focusTimer.restart()
    } else {
      searchTimer.stop()
      root.pendingSearch = false
    }
  }

  Timer {
    id: focusTimer
    interval: 120
    repeat: false
    onTriggered: if (root.open && !input.activeFocus) input.forceActiveFocus()
  }


  readonly property real topInset: Theme.barPosition === "top" ? Theme.barFace : 0
  readonly property real bottomInset: Theme.barPosition === "bottom" ? Theme.barFace : 0

  FusedWindow {
    id: fw
    active: root.open || panel.shown
    targetScreen: root.targetScreen
    namespace: "oozeshell-quickbar"

    exclusiveKeys: true
    onCloseRequested: root.closeRequested()


    onKeyPressed: (key, modifiers, text) => {
      input.forceActiveFocus()
      if (text.length === 1 && text.charCodeAt(0) >= 32 && (modifiers & Qt.ControlModifier) === 0)
        input.text += text
    }

    FusedPanel {
      id: panel


      edge: "top"
      faceOffset: 0
      detached: true
      floatWin: false
      flareStart: false
      flareEnd: false

      open: root.open
      panelWidth: root.cardW
      contentHeight: Math.round(root.animH)
      bodyRadius: 22

      x: Math.round((panel.hostWidth - panel.width) / 2)
      y: {
        const H = panel.hostHeight
        let v
        if (QuickBarConfig.position === "bottom")
          v = H - root.bottomInset - root.edgeGap - panel.height
        else if (QuickBarConfig.position === "center")


          v = H / 2 - (root.pad + root.inputH / 2) * panel.scaleFactor
        else
          v = root.topInset + root.edgeGap
        return Math.round(Math.max(8, Math.min(v, H - 8 - panel.height)))
      }

      Item {
        anchors.fill: parent

        // ─── Campo de búsqueda ──────────────────────────────────
        SkinRect {
          id: inputBox
          anchors {
            left: parent.left
            right: parent.right
            leftMargin: root.pad
            rightMargin: root.pad
            top: root.atBottom ? undefined : parent.top
            bottom: root.atBottom ? parent.bottom : undefined
            topMargin: root.pad
            bottomMargin: root.pad
          }
          height: root.inputH
          radius: 16
          color: Theme.surface
          border.width: Theme.bw1
          border.color: input.activeFocus ? Theme.primary : Theme.edge
          Behavior on border.color { ColorAnimation { duration: Theme.animDuration(150) } }

          RowLayout {
            anchors { fill: parent; leftMargin: 16; rightMargin: 12 }
            spacing: 12

            Text {
              text: "󰍉"
              color: Theme.primary
              font.pixelSize: Theme.fs(20)
              font.family: Theme.monoFamily
            }

            Item {
              Layout.fillWidth: true
              Layout.fillHeight: true

              TextInput {
                id: input
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                color: Theme.text
                selectionColor: Theme.primary
                selectedTextColor: Theme.textOnPrimary
                font.pixelSize: Theme.fs(16)
                font.family: Theme.fontFamily
                clip: true
                inputMethodHints: Qt.ImhNoPredictiveText

                Keys.onPressed: event => {
                  const ctrl  = (event.modifiers & Qt.ControlModifier) !== 0
                  const shift = (event.modifiers & Qt.ShiftModifier) !== 0

                  switch (event.key) {
                    case Qt.Key_Escape:
                      root.closeRequested()
                      event.accepted = true
                      return

                    case Qt.Key_Down:
                      root.move(1); event.accepted = true; return
                    case Qt.Key_Up:
                      root.move(-1); event.accepted = true; return
                    case Qt.Key_PageDown:
                      root.move(5); event.accepted = true; return
                    case Qt.Key_PageUp:
                      root.move(-5); event.accepted = true; return
                    case Qt.Key_Tab:
                      root.move(1); event.accepted = true; return
                    case Qt.Key_Backtab:
                      root.move(-1); event.accepted = true; return

                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                      root.activate(ctrl || shift)
                      event.accepted = true
                      return
                  }


                  if (ctrl) {
                    switch (event.key) {
                      case Qt.Key_N:
                      case Qt.Key_J:
                        root.move(1); event.accepted = true; return
                      case Qt.Key_P:
                      case Qt.Key_K:
                        root.move(-1); event.accepted = true; return
                      case Qt.Key_U:
                        input.text = ""; event.accepted = true; return
                    }
                  }
                }
              }


              Text {
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                visible: input.text === ""
                elide: Text.ElideRight
                text: Translations.t(QuickBarConfig.filesEnabled ? "qbPlaceholder" : "qbPlaceholderNoFiles")
                color: Theme.subtext
                font.pixelSize: Theme.fs(16)
                font.family: Theme.fontFamily
              }
            }


            Rectangle {
              Layout.preferredHeight: 26
              Layout.preferredWidth: browserChip.implicitWidth + 18
              radius: 8
              color: Theme.surfaceHigh

              Text {
                id: browserChip
                anchors.centerIn: parent
                text: "󰖟  " + QuickBarConfig.browserName
                      + ((QuickBarConfig.privateWindow && QuickBarConfig.browser !== null)
                         ? "  ·  " + Translations.t("qbPrivateShort") : "")
                color: Theme.subtext
                font.pixelSize: Theme.fs(11)
                font.family: Theme.fontFamily
              }
            }
          }
        }

        // ─── Resultados ─────────────────────────────────────────


        ListView {
          id: list
          anchors {
            left: parent.left
            right: parent.right
            leftMargin: root.pad - 4
            rightMargin: root.pad - 4
            top: root.atBottom ? undefined : inputBox.bottom
            bottom: root.atBottom ? inputBox.top : undefined
            topMargin: root.gap
            bottomMargin: root.gap
          }
          height: root.listH
          visible: root.rowsShown > 0
          clip: true
          interactive: false
          spacing: root.rowGap
          verticalLayoutDirection: root.atBottom ? ListView.BottomToTop : ListView.TopToBottom

          model: ScriptModel {
            values: root.displayResults
            objectProp: "id"
          }

          delegate: Item {
            id: row
            required property var modelData
            required property int index

            readonly property bool isCurrent: row.index === root.selected

            width: ListView.view.width
            height: root.rowH

            Rectangle {
              anchors { fill: parent; leftMargin: 4; rightMargin: 4 }
              radius: Theme.cardRadius - 2
              color: row.isCurrent ? Theme.surfaceHigh
                   : rowArea.containsMouse ? Theme.surface
                   : "transparent"
              Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }
            }

            Rectangle {
              visible: row.isCurrent
              width: 3
              height: 22
              radius: 2
              color: Theme.primary
              anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
            }

            RowLayout {
              anchors { fill: parent; leftMargin: 22; rightMargin: 16 }
              spacing: 12

              Text {
                Layout.preferredWidth: 26
                horizontalAlignment: Text.AlignHCenter
                text: row.modelData.icon
                color: (row.modelData.type !== "file" || row.modelData.isDir) ? Theme.primary : Theme.subtext
                font.pixelSize: Theme.fs(21)
                font.family: Theme.monoFamily
              }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                  Layout.fillWidth: true
                  text: row.modelData.title
                  elide: Text.ElideRight
                  color: Theme.text
                  font.pixelSize: Theme.fs(14)
                  font.family: Theme.fontFamily
                  font.bold: row.isCurrent
                }
                Text {
                  Layout.fillWidth: true
                  visible: text !== ""
                  text: row.modelData.sub ?? ""
                  elide: Text.ElideMiddle
                  color: Theme.subtext
                  font.pixelSize: Theme.fs(11)
                  font.family: Theme.fontFamily
                }
              }


              Text {
                visible: (row.modelData.opener ?? "") !== ""
                text: row.modelData.opener ?? ""
                color: Theme.subtext
                font.pixelSize: Theme.fs(11)
                font.family: Theme.monoFamily
              }

              Text {
                visible: row.isCurrent
                text: "󰌑"
                color: Theme.subtext
                font.pixelSize: Theme.fs(14)
                font.family: Theme.monoFamily
              }
            }

            MouseArea {
              id: rowArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              acceptedButtons: Qt.LeftButton | Qt.RightButton
              onClicked: mouse => {
                root.selected = row.index
                root.activate(mouse.button === Qt.RightButton)
              }
            }
          }
        }

        // ─── Atajos de la fila elegida (en el extremo lejano al campo) ───
        Text {
          anchors {
            left: parent.left
            right: parent.right
            leftMargin: root.pad + 10
            rightMargin: root.pad + 10
            top: root.atBottom ? undefined : list.bottom
            bottom: root.atBottom ? list.top : undefined
            topMargin: 4
            bottomMargin: 4
          }
          height: root.footH
          visible: root.rowsShown > 0
          verticalAlignment: Text.AlignVCenter
          elide: Text.ElideRight
          text: root.hintText
          color: Theme.subtext
          font.pixelSize: Theme.fs(11)
          font.family: Theme.fontFamily
        }
      }
    }
  }
}
