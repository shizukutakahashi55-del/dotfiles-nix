// Keybinds — panel de atajos (pestañas Atajos / Vim).
//
// Atajo (IPC), ver shell.qml:
//   quickshell ipc -p .../shell.qml call -- keybinds toggle
//
// Teclado (toma el teclado apenas se abre, sin clic previo):
//   Esc              cerrar
//   Tab / Shift+Tab  cambiar de pestaña (Atajos ↔ Vim)
//   ← → / h l        sección anterior / siguiente
//   ↑ ↓ / k j        scroll de la lista, línea a línea
//   PgUp PgDn        scroll de a página (también Ctrl+u / Ctrl+d)
//   Home End / g G   inicio / final de la lista
//   1–9              saltar directo a una sección
import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../LANG"
import "../COMMON"

Item {
  id: keybindsRoot

  property bool open: false
  property string targetScreen: ""
  signal closeRequested()

  property var sections: Translations.sections()
  property var vimSections: Translations.vimSections()

  Connections {
    target: Translations
    function onCurrentChanged() {
      keybindsRoot.sections = Translations.sections()
      keybindsRoot.vimSections = Translations.vimSections()
    }
  }

  // ─── Medidas (lógicas: FusedPanel las escala según Ajustes → Ventanas) ──
  readonly property int cardW: 860
  // 620 como siempre, salvo que la pantalla sea más baja: entonces se acota
  // para que el panel entre bajo la barra
  readonly property real cardH: Math.max(380, Math.min(620,
    (fw.screenHeight - Theme.barOffset - 24) / Theme.windowScale))
  readonly property int headerH: 64
  readonly property int footerH: 40
  readonly property int sidebarW: 170

  // "keybinds" | "vim" — qué pestaña está activa arriba del panel.
  property string activeTab: "keybinds"

  // Cada pestaña recuerda su propia sección seleccionada, así
  // cambiar de Keybinds a Vim y volver no resetea la posición.
  property int activeSection: 0
  property int activeVimSection: 0

  readonly property var currentSections: keybindsRoot.activeTab === "vim"
    ? keybindsRoot.vimSections
    : keybindsRoot.sections

  readonly property int currentIndex: keybindsRoot.activeTab === "vim"
    ? keybindsRoot.activeVimSection
    : keybindsRoot.activeSection

  function setCurrentIndex(i) {
    if (keybindsRoot.activeTab === "vim") keybindsRoot.activeVimSection = i
    else keybindsRoot.activeSection = i
  }

  // Cambia entre las pestañas Atajos y Vim
  function toggleTab() {
    keybindsRoot.activeTab = keybindsRoot.activeTab === "vim" ? "keybinds" : "vim"
  }

  // Sección siguiente (+1) o anterior (-1), dando la vuelta en los extremos
  function moveSection(delta) {
    const total = keybindsRoot.currentSections.length
    if (total === 0) return
    keybindsRoot.setCurrentIndex((keybindsRoot.currentIndex + delta + total) % total)
  }

  // Alto de una fila de la lista (44 + spacing 4) y de "una página"
  readonly property real rowStep: 48
  readonly property real pageStep: Math.max(rowStep, bindsList.height - 48)

  // Scroll de la lista de binds por teclado. Anima contentY con un
  // NumberAnimation propio (un Behavior sobre contentY estorbaría al
  // scroll con la rueda y al arrastre). Si ya hay una animación en curso
  // suma sobre su destino, así mantener presionada la tecla acumula bien.
  NumberAnimation {
    id: scrollAnim
    target: bindsList
    property: "contentY"
    duration: 140
    easing.type: Easing.OutCubic
  }

  function scrollList(delta) {
    const min = bindsList.originY - bindsList.topMargin
    const max = Math.max(min, bindsList.originY + bindsList.contentHeight
                              + bindsList.bottomMargin - bindsList.height)
    const base = scrollAnim.running ? scrollAnim.to : bindsList.contentY
    const dest = Math.max(min, Math.min(max, base + delta))

    scrollAnim.stop()
    scrollAnim.from = bindsList.contentY
    scrollAnim.to = dest
    scrollAnim.start()
  }

  // Al abrir, siempre arranca desde arriba de la lista
  onOpenChanged: {
    if (keybindsRoot.open) {
      scrollAnim.stop()
      Qt.callLater(() => bindsList.positionViewAtBeginning())
    }
  }

  // Teclas (Esc lo maneja FusedWindow y cierra)
  function handleKey(key, modifiers) {
    const ctrl  = (modifiers & Qt.ControlModifier) !== 0
    const shift = (modifiers & Qt.ShiftModifier) !== 0

    switch (key) {
      // ─── Cambiar de pestaña (Atajos ↔ Vim) ───────────
      case Qt.Key_Tab:
      case Qt.Key_Backtab:
        keybindsRoot.toggleTab()
        return

      // ─── Sección siguiente / anterior ────────────────
      case Qt.Key_Right:
      case Qt.Key_L:
        keybindsRoot.moveSection(1)
        return

      case Qt.Key_Left:
      case Qt.Key_H:
        keybindsRoot.moveSection(-1)
        return

      // ─── Scroll de la lista de binds ─────────────────
      case Qt.Key_Down:
      case Qt.Key_J:
        keybindsRoot.scrollList(keybindsRoot.rowStep)
        return

      case Qt.Key_Up:
      case Qt.Key_K:
        keybindsRoot.scrollList(-keybindsRoot.rowStep)
        return

      case Qt.Key_PageDown:
        keybindsRoot.scrollList(keybindsRoot.pageStep)
        return

      case Qt.Key_PageUp:
        keybindsRoot.scrollList(-keybindsRoot.pageStep)
        return

      case Qt.Key_D:
        if (ctrl) keybindsRoot.scrollList(keybindsRoot.pageStep / 2)
        return

      case Qt.Key_U:
        if (ctrl) keybindsRoot.scrollList(-keybindsRoot.pageStep / 2)
        return

      case Qt.Key_Home:
        keybindsRoot.scrollList(-1e6)
        return

      case Qt.Key_End:
        keybindsRoot.scrollList(1e6)
        return

      case Qt.Key_G:
        keybindsRoot.scrollList(shift ? 1e6 : -1e6)
        return
    }

    // ─── Saltar directo a una sección con 1–9 ──────
    if (key >= Qt.Key_1 && key <= Qt.Key_9) {
      const idx = key - Qt.Key_1
      if (idx < keybindsRoot.currentSections.length)
        keybindsRoot.setCurrentIndex(idx)
    }
  }

  // ═══════════════════════════════════════════════════════════════
  FusedWindow {
    id: fw
    active: keybindsRoot.open || panel.shown
    targetScreen: keybindsRoot.targetScreen
    namespace: "oozeshell-keybinds"
    // Modal: toma el teclado apenas se abre (sin clic previo)
    exclusiveKeys: true
    onCloseRequested: keybindsRoot.closeRequested()
    onKeyPressed: (key, modifiers, text) => keybindsRoot.handleKey(key, modifiers)

    FusedPanel {
      id: panel

      open: keybindsRoot.open
      panelWidth: keybindsRoot.cardW
      contentHeight: keybindsRoot.cardH

      // Centrado bajo la barra (o al costado, si la barra es vertical)
      align: "center"

      ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ─── Header ─────────────────────────────────────────
        Item {
          Layout.fillWidth: true
          Layout.preferredHeight: keybindsRoot.headerH

          RowLayout {
            anchors {
              fill: parent
              leftMargin: 24
              rightMargin: 24
            }
            spacing: 10

            Text {
              text: "󰌌"
              color: Theme.primary
              font.pixelSize: Theme.fs(24)
              font.family: Theme.monoFamily
            }

            // ─── Tabs: Keybinds / Vim ───────────────────────
            Row {
              spacing: 6

              Repeater {
                model: [
                  { id: "keybinds", label: "tabKeybinds" },
                  { id: "vim",      label: "tabVim" }
                ]

                delegate: Rectangle {
                  id: tab
                  required property var modelData
                  readonly property bool current: keybindsRoot.activeTab === tab.modelData.id

                  width: tabLabel.implicitWidth + 24
                  height: 32
                  radius: Theme.cardRadius - 4

                  color: tab.current ? Theme.surface
                       : tabArea.containsMouse ? Theme.surface
                       : "transparent"
                  border.width: tab.current ? 1 : 0
                  border.color: Theme.primary

                  Behavior on color { ColorAnimation { duration: 150 } }

                  Text {
                    id: tabLabel
                    anchors.centerIn: parent
                    text: Translations.t(tab.modelData.label)
                    font.pixelSize: Theme.fs(15)
                    font.bold: tab.current
                    color: tab.current ? Theme.text : Theme.subtext
                    Behavior on color { ColorAnimation { duration: 150 } }
                  }

                  MouseArea {
                    id: tabArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: keybindsRoot.activeTab = tab.modelData.id
                  }
                }
              }
            }

            Item { Layout.fillWidth: true }

            Text {
              text: Translations.t("tagline")
              color: Theme.subtext
              font.pixelSize: Theme.fs(12)
              font.family: Theme.fontFamily
            }
          }

          Rectangle {
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
            height: 1
            color: Theme.surface
          }
        }

        // ─── Sidebar + lista ────────────────────────────────
        RowLayout {
          Layout.fillWidth: true
          Layout.fillHeight: true
          spacing: 0

          // ─── Sidebar categorías ───────────────────────────
          // Mismo fondo que el panel (sólido); solo la sección activa y
          // el hover llevan una tarjeta, como en el resto del shell.
          Item {
            Layout.preferredWidth: keybindsRoot.sidebarW
            Layout.fillHeight: true

            ListView {
              id: sectionList

              anchors {
                fill: parent
                topMargin: 10
                bottomMargin: 10
              }

              clip: true
              spacing: 2
              boundsBehavior: Flickable.StopAtBounds

              model: keybindsRoot.currentSections.length

              ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle {
                  implicitWidth: 4
                  radius: 2
                  color: Theme.surfaceHigh
                }
                background: null
              }

              // ─── Mantiene visible la sección activa al navegar
              // con teclado, aunque haya más categorías que las
              // que entran en el recuadro (ej. Vim con 15).
              Connections {
                target: keybindsRoot
                function onCurrentIndexChanged() {
                  sectionList.positionViewAtIndex(keybindsRoot.currentIndex, ListView.Contain)
                }
              }

              delegate: Item {
                id: secItem
                width: sectionList.width
                height: 44

                readonly property bool current: index === keybindsRoot.currentIndex

                Rectangle {
                  anchors {
                    fill: parent
                    leftMargin: 8
                    rightMargin: 8
                  }
                  radius: Theme.cardRadius - 2
                  color: secItem.current ? Theme.surfaceHigh
                       : secArea.containsMouse ? Theme.surface
                       : "transparent"
                  Behavior on color { ColorAnimation { duration: 150 } }
                }

                Rectangle {
                  visible: secItem.current
                  width: 3
                  height: 24
                  radius: 2
                  color: Theme.primary
                  anchors {
                    left: parent.left
                    leftMargin: 8
                    verticalCenter: parent.verticalCenter
                  }
                }

                RowLayout {
                  anchors {
                    fill: parent
                    leftMargin: 22
                    rightMargin: 16
                  }
                  spacing: 10

                  Text {
                    text: keybindsRoot.currentSections[index].icon
                    color: secItem.current ? Theme.primary : Theme.subtext
                    font.pixelSize: Theme.fs(17)
                    font.family: Theme.monoFamily
                    Behavior on color { ColorAnimation { duration: 150 } }
                  }

                  Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: keybindsRoot.currentSections[index].title
                    color: secItem.current ? Theme.text : Theme.subtext
                    font.pixelSize: Theme.fs(15)
                    font.bold: secItem.current
                    Behavior on color { ColorAnimation { duration: 150 } }
                  }
                }

                MouseArea {
                  id: secArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: keybindsRoot.setCurrentIndex(index)
                }
              }
            }

            Rectangle {
              anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
              width: 1
              color: Theme.surface
            }
          }

          // ─── Lista de binds ───────────────────────────────
          ListView {
            id: bindsList

            Layout.fillWidth: true
            Layout.fillHeight: true

            topMargin: 12
            bottomMargin: 12
            leftMargin: 16
            rightMargin: 16

            model: keybindsRoot.currentSections[keybindsRoot.currentIndex].binds

            spacing: 4
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar {
              policy: ScrollBar.AsNeeded
              contentItem: Rectangle {
                implicitWidth: 4
                radius: 2
                color: Theme.surfaceHigh
              }
              background: null
            }

            // Otra sección u otra pestaña: arranca desde arriba
            onModelChanged: {
              scrollAnim.stop()
              Qt.callLater(() => bindsList.positionViewAtBeginning())
            }

            delegate: Rectangle {
              width: bindsList.width - 32
              height: 44
              radius: Theme.cardRadius - 2

              color: hoverArea.containsMouse ? Theme.surface : "transparent"
              Behavior on color { ColorAnimation { duration: 120 } }

              MouseArea {
                id: hoverArea
                anchors.fill: parent
                hoverEnabled: true
              }

              RowLayout {
                anchors {
                  fill: parent
                  leftMargin: 12
                  rightMargin: 12
                }
                spacing: 10

                // ─── Key caps ──────────────────────────────
                Row {
                  spacing: 5

                  Repeater {
                    model: modelData.keys

                    delegate: Rectangle {
                      height: 28
                      width: capLabel.implicitWidth + 18
                      radius: 8
                      color: Theme.surfaceHigh

                      Text {
                        id: capLabel
                        anchors.centerIn: parent
                        text: modelData
                        color: Theme.primary
                        font.pixelSize: Theme.fs(14)
                        font.family: Theme.fontFamily
                        font.bold: true
                      }
                    }
                  }
                }

                Text {
                  Layout.fillWidth: true
                  text: modelData.desc
                  color: Theme.subtext
                  font.pixelSize: Theme.fs(16)
                  horizontalAlignment: Text.AlignRight
                  elide: Text.ElideLeft
                }
              }
            }
          }
        }

        // ─── Footer ─────────────────────────────────────────
        Item {
          Layout.fillWidth: true
          Layout.preferredHeight: keybindsRoot.footerH

          Rectangle {
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: 1
            color: Theme.surface
          }

          RowLayout {
            anchors {
              fill: parent
              leftMargin: 24
              rightMargin: 24
            }

            Text {
              Layout.fillWidth: true
              elide: Text.ElideRight
              text: "󰌑  " + Translations.t("keybindsFooterHint")
              color: Theme.subtext
              font.pixelSize: Theme.fs(12)
              font.family: Theme.monoFamily
            }

            Text {
              text: keybindsRoot.currentSections[keybindsRoot.currentIndex].title
                    + "  " + (keybindsRoot.currentIndex + 1)
                    + "/" + keybindsRoot.currentSections.length
              color: Theme.subtext
              font.pixelSize: Theme.fs(12)
              font.family: Theme.fontFamily
            }
          }
        }
      }
    }
  }
}
