// Keybinds — panel de atajos (pestañas Atajos / Vim).

import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../Services/Lang"
import "../../COMMON"

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
  readonly property int cardW: 980


  readonly property real cardH: Math.max(380, Math.min(620,
    (fw.screenHeight - Theme.barFace - 24) / Theme.windowScale))
  readonly property int headerH: 64
  readonly property int footerH: 40
  readonly property int keyColW: 330
  readonly property int sidebarW: 196


  property string activeTab: "keybinds"


  property int activeSection: 0
  property int activeVimSection: 0

  readonly property var currentSections: {
    const all = keybindsRoot.activeTab === "vim" ? keybindsRoot.vimSections : keybindsRoot.sections
    return all.filter(s => !s.wm || s.wm.indexOf(WM.wm) >= 0)
  }

  readonly property int currentIndex: keybindsRoot.activeTab === "vim"
    ? keybindsRoot.activeVimSection
    : keybindsRoot.activeSection

  function setCurrentIndex(i) {
    if (keybindsRoot.activeTab === "vim") keybindsRoot.activeVimSection = i
    else keybindsRoot.activeSection = i
  }


  function toggleTab() {
    keybindsRoot.activeTab = keybindsRoot.activeTab === "vim" ? "keybinds" : "vim"
  }


  function moveSection(delta) {
    const total = keybindsRoot.currentSections.length
    if (total === 0) return
    keybindsRoot.setCurrentIndex((keybindsRoot.currentIndex + delta + total) % total)
  }


  // ─── Disponibilidad por compositor ──────────────────────────────
  function wmLabel(list) {
    return WM.wmList.filter(w => list.indexOf(w.id) >= 0).map(w => w.name).join(" · ")
  }
  readonly property string wmName: {
    const w = WM.wmList.find(x => x.id === WM.wm)
    return w ? w.name : WM.wm
  }
  readonly property var currentBinds: keybindsRoot.currentSections[keybindsRoot.currentIndex].binds
  readonly property int unavailableCount: keybindsRoot.currentBinds.filter(b => !keybindsRoot.availableHere(b)).length

  function availableHere(b) {
    return !b.wm || b.wm.length === 0 || b.wm.indexOf(WM.wm) >= 0
  }

  readonly property real rowStep: 58
  readonly property real pageStep: Math.max(rowStep, bindsList.height - 48)


  NumberAnimation {
    id: scrollAnim
    target: bindsList
    property: "contentY"
    duration: Theme.animDuration(140)
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


  onOpenChanged: {
    if (keybindsRoot.open) {
      scrollAnim.stop()
      Qt.callLater(() => bindsList.positionViewAtBeginning())
    }
  }


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

  FusedWindow {
    id: fw
    active: keybindsRoot.open || panel.shown
    targetScreen: keybindsRoot.targetScreen
    namespace: "oozeshell-keybinds"

    exclusiveKeys: true
    onCloseRequested: keybindsRoot.closeRequested()
    onKeyPressed: (key, modifiers, text) => keybindsRoot.handleKey(key, modifiers)

    FusedPanel {
      id: panel

      open: keybindsRoot.open
      panelWidth: keybindsRoot.cardW
      contentHeight: keybindsRoot.cardH


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

                  Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }

                  Text {
                    id: tabLabel
                    anchors.centerIn: parent
                    text: Translations.t(tab.modelData.label)
                    font.pixelSize: Theme.fs(15)
                    font.family: Theme.fontFamily
                    font.bold: tab.current
                    color: tab.current ? Theme.text : Theme.subtext
                    Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
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
              text: Translations.t("tagline").replace("%1", keybindsRoot.wmName)
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
                  Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
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
                    Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
                  }

                  Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: keybindsRoot.currentSections[index].title
                    color: secItem.current ? Theme.text : Theme.subtext
                    font.pixelSize: Theme.fs(15)
                    font.family: Theme.fontFamily
                    font.bold: secItem.current
                    Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
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

            topMargin: 10
            bottomMargin: 16
            leftMargin: 20
            rightMargin: 20

            model: keybindsRoot.currentBinds

            spacing: 0
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

            onModelChanged: {
              scrollAnim.stop()
              Qt.callLater(() => bindsList.positionViewAtBeginning())
            }

            // ─── Cabecera: título de la sección + conteo ──────
            header: Item {
              width: bindsList.width - bindsList.leftMargin - bindsList.rightMargin
              height: headCol.implicitHeight + 16

              Column {
                id: headCol
                anchors {
                  left: parent.left
                  right: parent.right
                  top: parent.top
                  leftMargin: 12
                  rightMargin: 12
                }
                spacing: 3

                Text {
                  width: parent.width
                  elide: Text.ElideRight
                  text: keybindsRoot.currentSections[keybindsRoot.currentIndex].title
                  color: Theme.text
                  font.pixelSize: Theme.fs(21)
                  font.family: Theme.fontFamily
                  font.bold: true
                }

                Text {
                  width: parent.width
                  elide: Text.ElideRight
                  color: Theme.subtext
                  font.pixelSize: Theme.fs(12)
                  font.family: Theme.fontFamily
                  text: {
                    let t = Translations.t("keybindsCount").replace("%1", keybindsRoot.currentBinds.length)
                    if (keybindsRoot.unavailableCount > 0)
                      t += "  ·  " + Translations.t("keybindsDimNote")
                             .replace("%1", keybindsRoot.unavailableCount)
                             .replace("%2", keybindsRoot.wmName)
                    return t
                  }
                }
              }
            }

            delegate: Item {
              id: bindRow
              width: bindsList.width - bindsList.leftMargin - bindsList.rightMargin
              height: Math.max(56, rowContent.implicitHeight + 24)

              opacity: keybindsRoot.availableHere(modelData) ? 1 : 0.45

              Rectangle {
                anchors.fill: parent
                radius: Theme.cardRadius - 2
                color: hoverArea.containsMouse ? Theme.surface : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }
              }

              MouseArea {
                id: hoverArea
                anchors.fill: parent
                hoverEnabled: true
              }

              Rectangle {
                anchors {
                  left: parent.left
                  right: parent.right
                  bottom: parent.bottom
                  leftMargin: 12
                  rightMargin: 12
                }
                height: 1
                color: Theme.surface
                opacity: 0.8
              }

              RowLayout {
                id: rowContent
                anchors {
                  left: parent.left
                  right: parent.right
                  verticalCenter: parent.verticalCenter
                  leftMargin: 12
                  rightMargin: 12
                }
                spacing: 20

                // ─── Key caps (columna fija) ───────────────
                Flow {
                  id: capsFlow
                  width: keybindsRoot.keyColW
                  Layout.preferredWidth: keybindsRoot.keyColW
                  Layout.maximumWidth: keybindsRoot.keyColW
                  Layout.preferredHeight: implicitHeight
                  Layout.alignment: Qt.AlignVCenter
                  spacing: 6

                  Repeater {
                    model: modelData.keys

                    delegate: Rectangle {
                      height: 30
                      width: capLabel.implicitWidth + 20
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

                // ─── Descripción (con salto de línea) + marca de WM ──
                ColumnLayout {
                  Layout.fillWidth: true
                  Layout.alignment: Qt.AlignVCenter
                  spacing: 5

                  Text {
                    Layout.fillWidth: true
                    text: modelData.desc
                    color: Theme.text
                    font.pixelSize: Theme.fs(15)
                    font.family: Theme.fontFamily
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                  }

                  Rectangle {
                    visible: !!modelData.wm && modelData.wm.length > 0
                    Layout.alignment: Qt.AlignLeft
                    height: 20
                    width: wmChip.implicitWidth + 14
                    radius: 6
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.surfaceHigh

                    Text {
                      id: wmChip
                      anchors.centerIn: parent
                      text: modelData.wm
                        ? Translations.t("keybindsOnlyIn").replace("%1", keybindsRoot.wmLabel(modelData.wm))
                        : ""
                      color: Theme.subtext
                      font.pixelSize: Theme.fs(11)
                      font.family: Theme.fontFamily
                    }
                  }
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
