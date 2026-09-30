// Taskbar — lista de ventanas abiertas (módulo "wlr/taskbar" de Waybar).
//
// El host conecta tipEnter/tipLeave a su tooltip compartido (FusedTip).
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import "../COMMON"
import "../LANG"

BarFlow {
  id: taskbar

  property var targetScreen
  property int iconSize: 16
  property bool allOutputs: false
  property int maxItems: 8
  property bool debugIcons: false
  // Plegado: un solo ícono en vez de uno por ventana (lo setea el host)
  property bool compact: false
  // Mostrar la flechita de plegar/desplegar (la Pill la oculta)
  property bool showToggle: true

  signal tipEnter(var item)
  signal tipLeave(var item)
  // Plegar / desplegar (el host cambia `compact`)
  signal toggleCompact()
  // Clic en el ícono resumen (modo compacto): pide abrir el drop con la
  // lista de ventanas. `item` es el ícono, para que el host lo use de ancla
  // (TaskbarMenu se centra bajo/al costado de él, según la barra).
  signal menuRequested(var item)

  gap: 2

  // ¿La ventana está en la pantalla de esta barra?
  // (si el compositor no informa pantalla, se muestra igual)
  function onThisScreen(t) {
    if (taskbar.allOutputs) return true
    const scr = t.screens
    if (!scr || scr.length === undefined || scr.length === 0) return true
    for (let i = 0; i < scr.length; i++) {
      if (scr[i] && taskbar.targetScreen && scr[i].name === taskbar.targetScreen.name)
        return true
    }
    return false
  }

  readonly property var windows: {
    const all = ToplevelManager.toplevels.values
    const out = []
    for (let i = 0; i < all.length; i++)
      if (taskbar.onThisScreen(all[i])) out.push(all[i])
    return out
  }

  readonly property int count: windows.length
  readonly property var hiddenWindows: windows.slice(maxItems)

  // DesktopEntries.heuristicLookup() no avisa cuando la base de .desktop
  // termina de cargar (o cambia). Sin esto, las ventanas que ya estaban
  // abiertas al arrancar el shell resolvían el ícono contra una base vacía
  // y se quedaban con el nombre crudo del appId para siempre. Leer la lista
  // dentro de iconFor() hace que el binding se reevalúe cuando llegue.
  readonly property int desktopRevision: DesktopEntries.applications.values.length

  // Devuelve la URL de un ícono que EXISTE, o "" si no hay ninguno.
  // Candidatos, en orden: Icon= del .desktop, appId tal cual, appId en
  // minúsculas, último tramo del appId (org.mozilla.firefox → firefox) y por
  // último el genérico del tema.
  function iconFor(appId) {
    void taskbar.desktopRevision

    const id = appId || ""
    const names = []
    if (id !== "") {
      const entry = DesktopEntries.heuristicLookup(id)
      if (entry && entry.icon) names.push(entry.icon)
      names.push(id, id.toLowerCase())
      const last = id.split(".").pop().toLowerCase()
      if (last !== id.toLowerCase()) names.push(last)
    }

    for (let i = 0; i < names.length; i++) {
      const n = names[i]
      if (!n) continue
      // Icon=/ruta/absoluta.png (AppImages, apps propietarias…)
      if (n.charAt(0) === "/") return taskbar.logIcon(id, n, "file://" + n)
      const p = Quickshell.iconPath(n, true)
      if (p !== "") return taskbar.logIcon(id, n, p)
    }
    return taskbar.logIcon(id, "(genérico)",
                           Quickshell.iconPath("application-x-executable", true))
  }

  function logIcon(id, name, url) {
    if (taskbar.debugIcons)
      console.log("[taskbar] appId='" + id + "' → " + name + " → " + (url || "SIN ÍCONO"))
    return url
  }

  // "minimize-raise": la activa se minimiza; cualquier otra sube al frente
  function minimizeRaise(t) {
    if (t.activated && !t.minimized) {
      t.minimized = true
    } else {
      t.minimized = false
      t.activate()
    }
  }

  // ── Plegar / desplegar ────────────────────────────────────────
  // Primero en el flujo, así que el contenido va DESPUÉS del botón.
  BarToggle {
    id: toggle

    visible: taskbar.showToggle
    collapsed: taskbar.compact
    contentAfter: true
    tip: Translations.t(taskbar.compact ? "barExpand" : "barCollapse")

    onToggled: taskbar.toggleCompact()
    onHoverEntered: taskbar.tipEnter(toggle)
    onHoverExited: taskbar.tipLeave(toggle)
  }

  // El modelo es la lista viva de Quickshell, NO un array derivado de
  // ella. Con un array nuevo en cada cambio, el Repeater destruía y recreaba TODOS
  // los delegates cada vez que se abría/cerraba cualquier ventana, y cada
  // ícono volvía a cargarse desde cero (parpadeo y demora). Así los delegates
  // persisten y solo se muestran u ocultan.
  Repeater {
    model: ToplevelManager.toplevels

    delegate: Rectangle {
      id: cell
      required property var modelData      // Toplevel

      readonly property string tip: modelData ? modelData.title : ""

      // ¿Está entre las primeras `maxItems` de ESTA pantalla?
      readonly property bool shown: taskbar.windows.indexOf(modelData) >= 0
                                    && taskbar.windows.indexOf(modelData) < taskbar.maxItems

      // Se reevalúa solo si cambia el appId o llega la base de .desktop
      readonly property string iconSrc: taskbar.iconFor(modelData ? modelData.appId : "")

      visible: shown && !taskbar.compact
      Layout.preferredWidth: shown ? taskbar.iconSize + 14 : 0
      Layout.preferredHeight: 30
      radius: 10

      color: (area.containsMouse || cell.modelData.activated) ? Theme.surface : "transparent"
      Behavior on color { ColorAnimation { duration: 150 } }

      scale: area.pressed ? 0.90 : (area.containsMouse ? 1.06 : 1.0)
      Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }

      // Síncrono a propósito: el nombre ya se comprobó en iconFor(), así que
      // cargarlo es barato y se evita el cuadro en blanco previo de la
      // carga asíncrona.
      IconImage {
        anchors.centerIn: parent
        width: taskbar.iconSize
        height: taskbar.iconSize
        visible: cell.iconSrc !== ""
        source: cell.iconSrc
        // Minimizada = apagada
        opacity: cell.modelData.minimized ? 0.45 : 1.0
        Behavior on opacity { NumberAnimation { duration: 150 } }
      }

      // Sin ningún ícono resoluble: un glifo neutro en vez del cuadriculado
      Text {
        anchors.centerIn: parent
        visible: cell.iconSrc === ""
        text: "󰀻"
        color: Theme.subtext
        font.pixelSize: taskbar.iconSize
        font.family: Theme.monoFamily
        opacity: cell.modelData.minimized ? 0.45 : 1.0
      }

      // Rayita de "esta es la ventana activa"
      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 2
        width: cell.modelData.activated ? 10 : 0
        height: 2
        radius: 1
        color: Theme.primary
        Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
      }

      MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

        onEntered: taskbar.tipEnter(cell)
        onExited: taskbar.tipLeave(cell)

        onClicked: mouse => {
          const t = cell.modelData
          if (mouse.button === Qt.MiddleButton) {
            t.close()
          } else if (mouse.button === Qt.RightButton) {
            taskbar.minimizeRaise(t)
          } else {
            if (t.minimized) t.minimized = false
            t.activate()
          }
        }
      }
    }
  }

  // ── Overflow: "+N" ────────────────────────────────────────────
  Rectangle {
    id: more

    visible: taskbar.hiddenWindows.length > 0 && !taskbar.compact

    readonly property string tip: {
      let s = Translations.t("taskbarMore")
      for (let i = 0; i < taskbar.hiddenWindows.length; i++)
        s += "\n• " + taskbar.hiddenWindows[i].title
      return s
    }

    // Vertical: mismo cuadrado de 30 que las ventanas
    Layout.preferredWidth: Theme.barVertical ? 30 : moreLabel.implicitWidth + 16
    Layout.preferredHeight: 30
    radius: 10
    color: moreArea.containsMouse ? Theme.surface : "transparent"
    Behavior on color { ColorAnimation { duration: 150 } }

    Text {
      id: moreLabel
      anchors.centerIn: parent
      text: "+" + taskbar.hiddenWindows.length
      color: Theme.subtext
      font.pixelSize: Theme.fs(11)
      font.family: Theme.fontFamily
    }

    MouseArea {
      id: moreArea
      anchors.fill: parent
      hoverEnabled: true
      onEntered: taskbar.tipEnter(more)
      onExited: taskbar.tipLeave(more)
    }
  }

  // ── Plegado: un solo ícono ────────────────────────────────────
  // Reemplaza a todas las ventanas. El tooltip dice cuántas hay y lista los
  // títulos (con tope, para que no crezca sin límite); clic = desplegar.
  Rectangle {
    id: summary

    visible: taskbar.compact

    readonly property int maxTipLines: 10

    readonly property string tip: {
      const w = taskbar.windows
      let s = Translations.t("taskbarWindows") + " (" + w.length + ")"
      for (let i = 0; i < Math.min(w.length, summary.maxTipLines); i++)
        s += "\n• " + (w[i].title || w[i].appId)
      if (w.length > summary.maxTipLines)
        s += "\n… +" + (w.length - summary.maxTipLines)
      return s
    }

    Layout.preferredWidth: taskbar.iconSize + 14
    Layout.preferredHeight: 30
    radius: 10
    color: summaryArea.containsMouse ? Theme.surface : "transparent"
    Behavior on color { ColorAnimation { duration: 150 } }

    scale: summaryArea.pressed ? 0.90 : (summaryArea.containsMouse ? 1.06 : 1.0)
    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }

    // 󰖲 (ventanas): ícono resumen del modo compacto. Abre un drop con
    // las ventanas abiertas, así que usa su propio glifo — distinto del
    // de Overview (󰕮, vista de espacios) y del genérico de "app" (󰀻).
    Text {
      anchors.centerIn: parent
      text: "󰖲"
      color: Theme.text
      font.pixelSize: Theme.fs(taskbar.iconSize)
      font.family: Theme.monoFamily
    }

    MouseArea {
      id: summaryArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: taskbar.tipEnter(summary)
      onExited: taskbar.tipLeave(summary)
      onClicked: taskbar.menuRequested(summary)
    }
  }
}
