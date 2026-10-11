// StreamOutputPicker — "¿por qué salida suena esta app?" (como el desplegable de la pestaña Reproducción de pavucontrol).

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import "../COMMON"
import "../LANG"

ColumnLayout {
  id: root


  property var node: null

  property bool dash: false

  property bool expanded: false

  Layout.fillWidth: true
  spacing: 3

  function fsz(px) { return root.dash ? Theme.dfs(px) : Theme.fs(px) }
  function gsz(px) { return root.dash ? Theme.ds(px) : px }

  // ── Estado real: a qué sink está enlazado el stream ahora ──────────
  PwNodeLinkTracker { id: tracker; node: root.node }

  readonly property var linkedSink: {
    const groups = tracker.linkGroups ? tracker.linkGroups.values : []
    for (let i = 0; i < groups.length; i++) {
      const g = groups[i]
      if (!g) continue
      const other = g.source === root.node ? g.target : g.source
      if (other) return other
    }
    return null
  }

  // ── Regla guardada (node.name del sink, "" = predeterminada) ───────
  readonly property string ruleSink: AudioBackend.ruleFor(root.node)

  function labelOfSink(name) {
    const list = AudioBackend.outputTargets
    for (let i = 0; i < list.length; i++)
      if (list[i].name === name) return list[i].desc
    return name
  }

  readonly property string currentLabel: {
    if (root.linkedSink)
      return root.linkedSink.description || root.linkedSink.nickname || root.linkedSink.name
    if (root.ruleSink !== "")
      return root.labelOfSink(root.ruleSink)
    return Translations.t("audioStreamOutputDefault")
  }


  readonly property var options: [{
    name: "",
    desc: Translations.t("audioStreamOutputDefault"),
    virtual: false
  }].concat(AudioBackend.outputTargets)

  // ── Botón (muestra la salida actual) ───────────────────────────────
  SkinRect {
    Layout.fillWidth: true
    Layout.preferredHeight: root.gsz(26)
    radius: root.gsz(8)
    color: (headArea.containsMouse || root.expanded) ? Theme.surfaceHigh : Theme.surface
    Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }

    RowLayout {
      anchors { fill: parent; leftMargin: root.gsz(8); rightMargin: root.gsz(8) }
      spacing: root.gsz(6)

      Text {
        text: "󰓃"
        color: root.ruleSink !== "" ? Theme.primary : Theme.subtext
        font.pixelSize: root.fsz(12)
        font.family: Theme.monoFamily
      }
      Text {
        Layout.fillWidth: true
        text: root.currentLabel
        color: Theme.text
        font.pixelSize: root.fsz(10)
        font.family: Theme.fontFamily
        elide: Text.ElideRight
      }

      Text {
        visible: root.ruleSink !== ""
        text: "󰐃"
        color: Theme.primary
        font.pixelSize: root.fsz(11)
        font.family: Theme.monoFamily
      }
      Text {
        text: root.expanded ? "󰅃" : "󰅀"
        color: Theme.subtext
        font.pixelSize: root.fsz(12)
        font.family: Theme.monoFamily
      }
    }

    MouseArea {
      id: headArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.expanded = !root.expanded
    }
  }

  // ── Lista de salidas (se despliega debajo) ─────────────────────────
  ColumnLayout {
    Layout.fillWidth: true
    visible: root.expanded
    spacing: 2

    Repeater {
      model: root.expanded ? root.options : []

      delegate: SkinRect {
        id: opt
        required property var modelData

        readonly property bool selected: opt.modelData.name === root.ruleSink

        Layout.fillWidth: true
        Layout.preferredHeight: root.gsz(26)
        radius: root.gsz(8)
        color: opt.selected ? Theme.surfaceHigh
             : (optArea.containsMouse ? Theme.surface : "transparent")
        Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }

        RowLayout {
          anchors { fill: parent; leftMargin: root.gsz(8); rightMargin: root.gsz(8) }
          spacing: root.gsz(6)

          Text {
            text: opt.selected ? "󰄬" : "󰝛"
            color: opt.selected ? Theme.primary : Theme.subtext
            font.pixelSize: root.fsz(11)
            font.family: Theme.monoFamily
          }
          Text {
            Layout.fillWidth: true
            text: opt.modelData.desc
            color: Theme.text
            font.pixelSize: root.fsz(10)
            font.family: Theme.fontFamily
            elide: Text.ElideRight
          }
          Text {
            visible: opt.modelData.virtual
            text: Translations.t("audioMixerVirtualTag")
            color: Theme.subtext
            font.pixelSize: root.fsz(9)
            font.family: Theme.fontFamily
          }
        }

        MouseArea {
          id: optArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            AudioBackend.routeStream(root.node, opt.modelData.name)
            root.expanded = false
          }
        }
      }
    }
  }
}
