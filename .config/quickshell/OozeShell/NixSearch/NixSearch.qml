// NixSearch — busca paquetes en nixpkgs (reemplaza al script de rofi + nix-search).
//
// Atajo (IPC), ver shell.qml:
//   quickshell ipc -p .../shell.qml call -- nixsearch toggle
//   quickshell ipc -p .../shell.qml call -- nixsearch open [consulta]
//   quickshell ipc -p .../shell.qml call -- nixsearch close
//
// Requiere: nix-search (nix-search-cli), y solo para las acciones que lo
// usan: una terminal (la de Ajustes → General; foot por defecto), wl-copy, notify-send y xdg-open. Si el
// programa no está en el PATH el panel lo dice en vez de quedarse mudo.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../COMMON"
import "../LANG"

Item {
  id: root

  property bool open: false
  property string targetScreen: ""
  signal closeRequested()

  // Consulta con la que arranca al abrirse (lo usa el IPC: `nixsearch open firefox`)
  property string startQuery: ""

  // ─── Configuración ──────────────────────────────────────────────
  // Terminal para `nix shell` / `nix profile install`: la que se elige en
  // Ajustes → General (por defecto foot). Las dos acciones abren SOLAS esa
  // terminal con el comando ya corriendo.
  readonly property var terminal: Theme.terminalCmd
  // "" = el canal por defecto de nix-search (unstable)
  property string channel: ""
  // Argumentos fijos de nix-search (antes de la consulta)
  property var searchArgs: ["--json", "--max-results", "40"]
  // Pausa desde la última tecla hasta buscar, y mínimo de letras
  property int debounceMs: 350
  property int minChars: 2

  // ─── Medidas (lógicas: FusedPanel las escala según Ajustes → Ventanas) ──
  readonly property int cardW: 800
  readonly property int cardH: 540
  readonly property int pad: 16
  readonly property int rowH: 44
  readonly property int colAttr: 230
  readonly property int colVersion: 96
  readonly property int colFlags: 58

  // ─── Estado ─────────────────────────────────────────────────────
  // list | actions | details
  property string level: "list"
  property var results: []
  property int selected: 0
  property int actionSel: 0
  property bool searching: false
  // "" | "missing" (no está nix-search) | "failed"
  property string status: ""
  property string errText: ""

  readonly property string query: input.text
  readonly property var current: root.results[root.selected] ?? null

  readonly property var actions: [
    { id: "details", icon: "󰋽",  label: "nixActDetails", key: "Ctrl+D" },
    { id: "shell",   icon: "󰆍", label: "nixActShell",   key: "Ctrl+S" },
    { id: "install", icon: "󰏗",   label: "nixActInstall", key: "Ctrl+I" },
    { id: "copy",    icon: "󰆏",  label: "nixActCopy",    key: "Ctrl+Y" },
    { id: "copyref", icon: "󰌹",  label: "nixActCopyRef", key: "Ctrl+⇧Y" },
    { id: "web",     icon: "󰖟",   label: "nixActWeb",     key: "Ctrl+O" }
  ]

  // ═══ BÚSQUEDA ════════════════════════════════════════════════════
  // Cada tecla reinicia la pausa; al vencer se lanza nix-search. Si todavía
  // hay una búsqueda en curso se la termina y, cuando sale, arranca la nueva
  // (así lo que llega del proceso viejo nunca se mezcla con lo nuevo).
  property string pendingQuery: ""
  property bool rerun: false
  property int searchGen: 0

  Timer {
    id: debounce
    interval: root.debounceMs
    repeat: false
    onTriggered: root.startSearch()
  }

  function queryEdited() {
    // Escribir siempre vuelve a la lista
    root.level = "list"
    root.selected = 0
    debounce.restart()
  }

  function startSearch() {
    const q = root.query.trim()
    if (q.length < root.minChars) {
      root.rerun = false
      if (searchProc.running) searchProc.running = false
      root.results = []
      root.searching = false
      root.status = ""
      return
    }
    root.pendingQuery = q
    if (searchProc.running) {
      root.rerun = true
      searchProc.running = false
      return
    }
    root.runSearch(q)
  }

  function runSearch(q) {
    searchProc.buf = []
    searchProc.gotGen = false
    searchProc.valid = false
    searchProc.err = ""
    searchProc.terms = q.split(/\s+/).filter(t => t !== "")
    root.searchGen++
    root.searching = true
    root.status = ""
    root.selected = 0
    searchProc.running = true
  }

  // Una línea de `nix-search --json` → un resultado. Los nombres de campo son
  // los del índice de search.nixos.org (package_*); se aceptan también los
  // nombres cortos por si la versión de nix-search los usa.
  function parseItem(o) {
    if (!o || typeof o !== "object") return null
    const attr = o.package_attr_name ?? o.attr ?? o.attribute ?? o.name ?? ""
    if (attr === "") return null

    const lic = o.package_license ?? o.license ?? []
    const licList = Array.isArray(lic) ? lic : (lic ? [lic] : [])
    const licenses = licList
      .map(l => (typeof l === "string") ? l : (l.fullName ?? l.spdxId ?? ""))
      .filter(n => n !== "")

    const home = o.package_homepage ?? o.homepage ?? ""
    const programs = o.package_programs ?? o.programs ?? []

    return {
      id: attr,
      attr: attr,
      version: String(o.package_pversion ?? o.version ?? ""),
      desc: String(o.package_description ?? o.description ?? ""),
      longDesc: String(o.package_longDescription ?? o.longDescription ?? ""),
      homepage: Array.isArray(home) ? (home[0] ?? "") : String(home),
      programs: Array.isArray(programs) ? programs : [],
      licenses: licenses,
      unfree: o.package_unfree === true || o.unfree === true
              || licenses.some(n => /unfree/i.test(n))
    }
  }

  Process {
    id: searchProc
    property var buf: []
    property var terms: []
    property bool gotGen: false
    property bool valid: false
    property string err: ""

    // La primera línea es la "generación" (ver runSearch); la marca
    // __NO_NIX_SEARCH__ avisa que el programa no está instalado.
    command: ["sh", "-c",
      'echo "$1"; shift; ' +
      'command -v nix-search >/dev/null 2>&1 || { echo __NO_NIX_SEARCH__; exit 127; }; ' +
      'exec nix-search "$@"',
      "sh", String(root.searchGen)
    ].concat(root.searchArgs,
             root.channel !== "" ? ["--channel", root.channel] : [],
             ["--"],
             searchProc.terms)

    stdout: SplitParser {
      onRead: line => {
        if (!searchProc.gotGen) {
          searchProc.gotGen = true
          searchProc.valid = (line === String(root.searchGen))
          return
        }
        if (!searchProc.valid || line === "") return

        if (line === "__NO_NIX_SEARCH__") { root.status = "missing"; return }

        let parsed
        try { parsed = JSON.parse(line) } catch (e) { return }
        // Una línea por paquete; por si alguna versión devuelve un array
        const list = Array.isArray(parsed) ? parsed : [parsed]
        for (let i = 0; i < list.length; i++) {
          const it = root.parseItem(list[i])
          if (it) searchProc.buf.push(it)
        }
        root.results = searchProc.buf.slice()
      }
    }

    stderr: SplitParser {
      onRead: line => { if (line.trim() !== "") searchProc.err = line.trim() }
    }

    onRunningChanged: {
      if (running) return
      root.searching = false
      // Salió el proceso viejo porque hay una consulta nueva esperando
      if (root.rerun) {
        root.rerun = false
        root.runSearch(root.pendingQuery)
        return
      }
      if (!searchProc.valid) return
      if (searchProc.buf.length === 0) {
        root.results = []
        if (root.status === "") {
          root.status = searchProc.err !== "" ? "failed" : ""
          root.errText = searchProc.err
        }
      }
    }
  }

  // ═══ ACCIONES ════════════════════════════════════════════════════
  function copyText(text) {
    Quickshell.execDetached(["sh", "-c",
      'printf %s "$1" | wl-copy && notify-send -a OozeShell "$2" "$1"',
      "sh", text, Translations.t("nixCopied")])
  }

  function runAction(id, item) {
    if (!item) return
    const ref = "nixpkgs#" + item.attr

    switch (id) {
      case "details":
        root.level = "details"
        return

      case "shell":
        Quickshell.execDetached(root.terminal.concat(["nix", "shell", ref]))
        break

      case "install":
        // Queda la terminal abierta para ver qué pasó, y avisa al terminar
        Quickshell.execDetached(root.terminal.concat(["sh", "-c",
          'nix profile install "$1"; s=$?; ' +
          'if [ "$s" -eq 0 ]; then notify-send -a OozeShell "nix profile" "$2: $1"; ' +
          'else notify-send -u critical -a OozeShell "nix profile" "$3: $1 ($s)"; fi; ' +
          'printf "\\n%s " "$4"; read -r _',
          "sh", ref, Translations.t("nixInstalled"), Translations.t("nixInstallFailed"),
          Translations.t("nixPressEnter")]))
        break

      case "copy":
        root.copyText(item.attr)
        break

      case "copyref":
        root.copyText(ref)
        break

      case "web":
        Quickshell.execDetached(["xdg-open",
          "https://search.nixos.org/packages?channel=" + (root.channel !== "" ? root.channel : "unstable")
          + "&show=" + encodeURIComponent(item.attr)
          + "&query=" + encodeURIComponent(item.attr)])
        break
    }
    root.closeRequested()
  }

  function move(delta) {
    if (root.level === "actions") {
      root.actionSel = Math.max(0, Math.min(root.actions.length - 1, root.actionSel + delta))
    } else if (root.level === "details") {
      detailsView.nudge(delta * 48)
    } else {
      const n = root.results.length
      if (n === 0) return
      root.selected = Math.max(0, Math.min(n - 1, root.selected + delta))
    }
  }

  // ═══ APERTURA ════════════════════════════════════════════════════
  onOpenChanged: {
    if (!root.open) {
      debounce.stop()
      return
    }
    root.level = "list"
    root.selected = 0
    root.actionSel = 0
    root.status = ""
    root.errText = ""
    root.rerun = false
    if (searchProc.running) searchProc.running = false
    root.results = []
    root.searching = false
    input.text = root.startQuery
    // Asignar el texto reinició la pausa (onTextChanged); acá se busca de
    // una vez, sin esperarla, así que se cancela para no buscar dos veces
    debounce.stop()
    if (root.startQuery.trim() !== "") root.startSearch()
    // FusedWindow le da el foco a su propio capturador de teclas al
    // activarse; acá se lo pedimos DESPUÉS
    Qt.callLater(() => input.forceActiveFocus())
    focusTimer.restart()
  }

  Timer {
    id: focusTimer
    interval: 120
    repeat: false
    onTriggered: if (root.open && !input.activeFocus) input.forceActiveFocus()
  }

  // ═══ UI ══════════════════════════════════════════════════════════
  FusedWindow {
    id: fw
    active: root.open || panel.shown
    targetScreen: root.targetScreen
    namespace: "oozeshell-nixsearch"
    // Modal: toma el teclado apenas se abre (sin clic previo)
    exclusiveKeys: true
    onCloseRequested: root.closeRequested()
    // Si el foco se fue del campo, la primera tecla lo recupera
    onKeyPressed: (key, modifiers, text) => {
      input.forceActiveFocus()
      if (text.length === 1 && text.charCodeAt(0) >= 32 && (modifiers & Qt.ControlModifier) === 0)
        input.text += text
    }

    FusedPanel {
      id: panel

      open: root.open
      panelWidth: root.cardW
      contentHeight: root.cardH
      align: "center"

      ColumnLayout {
        anchors { fill: parent; margins: root.pad }
        spacing: 8

        // ─── Buscador ───────────────────────────────────────
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: 50
          radius: Theme.cardRadius
          color: Theme.surface

          RowLayout {
            anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
            spacing: 10

            Text {
              text: "❄"
              color: Theme.primary
              font.pixelSize: Theme.fs(22)
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
                clip: true
                inputMethodHints: Qt.ImhNoPredictiveText

                onTextChanged: root.queryEdited()

                Keys.onPressed: event => {
                  const ctrl  = (event.modifiers & Qt.ControlModifier) !== 0
                  const shift = (event.modifiers & Qt.ShiftModifier) !== 0

                  switch (event.key) {
                    case Qt.Key_Escape:
                      // Un nivel atrás; desde la lista, cierra
                      if (root.level !== "list") root.level = "list"
                      else root.closeRequested()
                      event.accepted = true
                      return

                    case Qt.Key_Down:
                      root.move(1); event.accepted = true; return
                    case Qt.Key_Up:
                      root.move(-1); event.accepted = true; return
                    case Qt.Key_PageDown:
                      root.move(6); event.accepted = true; return
                    case Qt.Key_PageUp:
                      root.move(-6); event.accepted = true; return

                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                      if (root.level === "list") {
                        if (root.current) { root.actionSel = 0; root.level = "actions" }
                      } else if (root.level === "actions") {
                        root.runAction(root.actions[root.actionSel].id, root.current)
                      } else {
                        root.level = "list"
                      }
                      event.accepted = true
                      return

                    // Fuera de la lista, ← y Backspace vuelven atrás
                    // (en la lista siguen editando el texto)
                    case Qt.Key_Left:
                    case Qt.Key_Backspace:
                      if (root.level !== "list") {
                        root.level = "list"
                        event.accepted = true
                      }
                      return
                  }

                  if (!ctrl) return

                  // Estilo vim / readline + atajos directos a las acciones
                  switch (event.key) {
                    case Qt.Key_N:
                    case Qt.Key_J:
                      root.move(1); event.accepted = true; return
                    case Qt.Key_P:
                    case Qt.Key_K:
                      root.move(-1); event.accepted = true; return
                    case Qt.Key_U:
                      input.text = ""; event.accepted = true; return
                    case Qt.Key_D:
                      root.runAction("details", root.current); event.accepted = true; return
                    case Qt.Key_S:
                      root.runAction("shell", root.current); event.accepted = true; return
                    case Qt.Key_I:
                      root.runAction("install", root.current); event.accepted = true; return
                    case Qt.Key_Y:
                      root.runAction(shift ? "copyref" : "copy", root.current)
                      event.accepted = true
                      return
                    case Qt.Key_O:
                      root.runAction("web", root.current); event.accepted = true; return
                  }
                }
              }

              Text {
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                visible: input.text === ""
                elide: Text.ElideRight
                text: Translations.t("nixPlaceholder")
                color: Theme.subtext
                font.pixelSize: Theme.fs(16)
              }
            }

            Text {
              text: root.searching ? Translations.t("nixSearching")
                  : root.results.length > 0 ? String(root.results.length)
                  : ""
              color: Theme.subtext
              font.pixelSize: Theme.fs(12)
              font.family: Theme.fontFamily
            }
          }
        }

        // ─── Títulos de columna (solo con resultados) ───────
        RowLayout {
          Layout.fillWidth: true
          Layout.leftMargin: 22
          Layout.rightMargin: 16
          Layout.preferredHeight: 18
          visible: root.level === "list" && root.results.length > 0
          spacing: 12

          Text {
            Layout.preferredWidth: root.colAttr
            text: Translations.t("nixColPackage")
            color: Theme.subtext
            font.pixelSize: Theme.fs(11)
            font.bold: true
          }
          Text {
            Layout.preferredWidth: root.colVersion
            text: Translations.t("nixColVersion")
            color: Theme.subtext
            font.pixelSize: Theme.fs(11)
            font.bold: true
          }
          Item { Layout.preferredWidth: root.colFlags }
          Text {
            Layout.fillWidth: true
            text: Translations.t("nixColDescription")
            color: Theme.subtext
            font.pixelSize: Theme.fs(11)
            font.bold: true
          }
        }

        // ─── Contenido: lista / acciones / detalles ─────────
        Item {
          Layout.fillWidth: true
          Layout.fillHeight: true

          // ── Nivel: lista de resultados ────────────────────
          ListView {
            id: list
            anchors.fill: parent
            visible: root.level === "list"
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height

            model: ScriptModel {
              values: root.results
              objectProp: "id"
            }

            Connections {
              target: root
              function onSelectedChanged() {
                list.positionViewAtIndex(root.selected, ListView.Contain)
              }
            }

            delegate: Item {
              id: row
              required property var modelData
              required property int index
              readonly property bool isCurrent: row.index === root.selected

              width: ListView.view.width
              height: root.rowH

              Rectangle {
                anchors { fill: parent; leftMargin: 0; rightMargin: 0 }
                radius: Theme.cardRadius - 2
                color: row.isCurrent ? Theme.surfaceHigh
                     : rowArea.containsMouse ? Theme.surface
                     : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }
              }

              Rectangle {
                visible: row.isCurrent
                width: 3
                height: 22
                radius: 2
                color: Theme.primary
                anchors { left: parent.left; leftMargin: 6; verticalCenter: parent.verticalCenter }
              }

              RowLayout {
                anchors { fill: parent; leftMargin: 16; rightMargin: 10 }
                spacing: 12

                Text {
                  Layout.preferredWidth: root.colAttr
                  text: row.modelData.attr
                  elide: Text.ElideRight
                  color: row.isCurrent ? Theme.primary : Theme.text
                  font.pixelSize: Theme.fs(15)
                  font.bold: true
                }
                Text {
                  Layout.preferredWidth: root.colVersion
                  text: row.modelData.version
                  elide: Text.ElideRight
                  color: Theme.subtext
                  font.pixelSize: Theme.fs(13)
                  font.family: Theme.fontFamily
                }
                Item {
                  Layout.preferredWidth: root.colFlags
                  Layout.preferredHeight: 20

                  Rectangle {
                    visible: row.modelData.unfree
                    anchors.centerIn: parent
                    width: unfreeLabel.implicitWidth + 12
                    height: 18
                    radius: 9
                    color: Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.18)

                    Text {
                      id: unfreeLabel
                      anchors.centerIn: parent
                      text: Translations.t("nixUnfree")
                      color: Theme.error
                      font.pixelSize: Theme.fs(10)
                      font.bold: true
                    }
                  }
                }
                Text {
                  Layout.fillWidth: true
                  text: row.modelData.desc
                  elide: Text.ElideRight
                  color: Theme.subtext
                  font.pixelSize: Theme.fs(13)
                }
              }

              MouseArea {
                id: rowArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.selected = row.index
                  root.actionSel = 0
                  root.level = "actions"
                  input.forceActiveFocus()
                }
              }
            }
          }

          // ── Nivel: acciones sobre el resultado elegido ────
          ColumnLayout {
            anchors.fill: parent
            visible: root.level === "actions"
            spacing: 6

            RowLayout {
              Layout.fillWidth: true
              Layout.leftMargin: 8
              Layout.bottomMargin: 4
              spacing: 10

              Text {
                text: root.current ? root.current.attr : ""
                color: Theme.primary
                font.pixelSize: Theme.fs(18)
                font.bold: true
              }
              Text {
                text: root.current ? root.current.version : ""
                color: Theme.subtext
                font.pixelSize: Theme.fs(13)
                font.family: Theme.fontFamily
              }
            }

            Repeater {
              model: root.actions

              delegate: Item {
                id: act
                required property var modelData
                required property int index
                readonly property bool isCurrent: act.index === root.actionSel

                Layout.fillWidth: true
                Layout.preferredHeight: root.rowH

                Rectangle {
                  anchors.fill: parent
                  radius: Theme.cardRadius - 2
                  color: act.isCurrent ? Theme.surfaceHigh
                       : actArea.containsMouse ? Theme.surface
                       : "transparent"
                  Behavior on color { ColorAnimation { duration: 120 } }
                }

                Rectangle {
                  visible: act.isCurrent
                  width: 3
                  height: 22
                  radius: 2
                  color: Theme.primary
                  anchors { left: parent.left; leftMargin: 6; verticalCenter: parent.verticalCenter }
                }

                RowLayout {
                  anchors { fill: parent; leftMargin: 22; rightMargin: 16 }
                  spacing: 14

                  Text {
                    text: act.modelData.icon
                    color: act.isCurrent ? Theme.primary : Theme.subtext
                    font.pixelSize: Theme.fs(20)
                    font.family: Theme.monoFamily
                  }
                  Text {
                    Layout.fillWidth: true
                    text: Translations.t(act.modelData.label)
                    color: Theme.text
                    font.pixelSize: Theme.fs(15)
                    font.bold: act.isCurrent
                  }
                  Text {
                    text: act.modelData.key
                    color: Theme.subtext
                    font.pixelSize: Theme.fs(12)
                    font.family: Theme.fontFamily
                  }
                }

                MouseArea {
                  id: actArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.actionSel = act.index
                    root.runAction(act.modelData.id, root.current)
                    input.forceActiveFocus()
                  }
                }
              }
            }

            Item { Layout.fillHeight: true }
          }

          // ── Nivel: detalles ───────────────────────────────
          Flickable {
            id: detailsView
            anchors.fill: parent
            visible: root.level === "details"
            clip: true
            contentWidth: width
            contentHeight: detailsCol.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            function nudge(dy) {
              const max = Math.max(0, contentHeight - height)
              contentY = Math.max(0, Math.min(max, contentY + dy))
            }

            // Al abrir los detalles, arranca desde arriba
            onVisibleChanged: if (visible) contentY = 0

            ColumnLayout {
              id: detailsCol
              width: detailsView.width - 12
              x: 6
              spacing: 10

              RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                  text: root.current ? root.current.attr : ""
                  color: Theme.primary
                  font.pixelSize: Theme.fs(22)
                  font.bold: true
                }
                Text {
                  text: root.current ? root.current.version : ""
                  color: Theme.subtext
                  font.pixelSize: Theme.fs(14)
                  font.family: Theme.fontFamily
                }
              }

              Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.current ? root.current.desc : ""
                wrapMode: Text.WordWrap
                color: Theme.text
                font.pixelSize: Theme.fs(15)
              }

              Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.current ? root.current.longDesc : ""
                wrapMode: Text.WordWrap
                color: Theme.subtext
                font.pixelSize: Theme.fs(13)
              }

              // Datos sueltos: etiqueta + valor
              Repeater {
                model: root.current ? [
                  { k: "nixLicense",  v: root.current.licenses.join(", ") },
                  { k: "nixHomepage", v: root.current.homepage },
                  { k: "nixPrograms", v: root.current.programs.slice(0, 16).join(", ")
                                       + (root.current.programs.length > 16 ? " …" : "") }
                ].filter(r => r.v !== "") : []

                delegate: ColumnLayout {
                  id: metaRow
                  required property var modelData
                  Layout.fillWidth: true
                  spacing: 2

                  Text {
                    text: Translations.t(metaRow.modelData.k)
                    color: Theme.subtext
                    font.pixelSize: Theme.fs(11)
                    font.bold: true
                  }
                  Text {
                    Layout.fillWidth: true
                    text: metaRow.modelData.v
                    wrapMode: Text.WrapAnywhere
                    color: Theme.text
                    font.pixelSize: Theme.fs(13)
                  }
                }
              }
            }
          }

          // ── Mensajes (sin consulta, buscando, sin resultados, error) ──
          Text {
            anchors.centerIn: parent
            width: parent.width - 64
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            visible: root.level === "list" && root.results.length === 0
            color: root.status !== "" ? Theme.error : Theme.subtext
            font.pixelSize: Theme.fs(14)
            text: root.status === "missing" ? Translations.t("nixMissing")
                : root.status === "failed"
                    ? Translations.t("nixFailed") + (root.errText !== "" ? "\n" + root.errText : "")
                : root.searching ? Translations.t("nixSearching")
                : root.query.trim().length < root.minChars ? Translations.t("nixTypeToSearch")
                : Translations.t("nixNoResults")
          }
        }

        // ─── Atajos ─────────────────────────────────────────
        Text {
          Layout.fillWidth: true
          Layout.leftMargin: 6
          elide: Text.ElideRight
          text: root.level === "list" ? Translations.t("nixHintList")
              : root.level === "actions" ? Translations.t("nixHintActions")
              : Translations.t("nixHintDetails")
          color: Theme.subtext
          font.pixelSize: Theme.fs(11)
          font.family: Theme.fontFamily
        }
      }
    }
  }
}
