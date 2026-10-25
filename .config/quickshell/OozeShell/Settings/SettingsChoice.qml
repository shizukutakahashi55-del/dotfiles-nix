import QtQuick
import QtQuick.Layouts
import "../COMMON"

SkinRect {
  id: root

  property var model: []
  property var current: null
  property real natural: 6
  // Si no cabe en una línea, pasa al estilo de pastillas sueltas (como los chips de General).
  readonly property bool pills: root.width > 0 && root.width < root.natural - 1

  signal picked(var value)

  function measure() {
    let w = 6
    let n = 0
    for (let i = 0; i < seg.children.length; i++) {
      const c = seg.children[i]
      if (c.optWidth !== undefined) { w += c.optWidth; n++ }
    }
    root.natural = Math.ceil(w + Math.max(0, n - 1) * seg.spacing) + 2
  }

  Layout.alignment: Qt.AlignVCenter
  Layout.fillWidth: true
  Layout.preferredWidth: root.natural
  Layout.maximumWidth: root.natural
  Layout.minimumWidth: 0
  Layout.preferredHeight: seg.height + (root.pills ? 0 : 6)
  implicitWidth: root.natural
  implicitHeight: seg.height + (root.pills ? 0 : 6)
  radius: Theme.cozy ? 4 : Math.min(height / 2, 17)
  color: root.pills ? "transparent" : (Theme.cozy ? Theme.bg : MdTokens.well)
  border.width: root.pills ? 0 : (Theme.cozy ? Theme.bw1 : 1)
  border.color: Theme.cozy ? Theme.edge : MdTokens.controlEdge

  Flow {
    id: seg
    x: root.pills ? 0 : 3
    y: root.pills ? 0 : 3
    width: root.pills ? root.width : Math.max(0, root.width - 6 + 1)
    spacing: root.pills ? (Theme.cozy ? 8 : 6) : 2

    Repeater {
      model: root.model

      delegate: SkinRect {
        id: opt
        required property var modelData

        readonly property bool active: root.current === opt.modelData.value
        readonly property real optWidth: optRow.implicitWidth + 24

        width: opt.optWidth
        height: root.pills ? 34 : 28
        radius: root.pills ? (Theme.cozy ? 4 : ((opt.active || optArea.containsMouse) ? height / 2 : MdTokens.rXs + 2))
                           : (Theme.cozy ? 3 : ((opt.active || optArea.containsMouse) ? height / 2 : MdTokens.rXs))
        color: opt.active ? Theme.primary
             : (optArea.containsMouse ? (Theme.cozy ? Theme.surfaceHigh : (root.pills ? MdTokens.controlHover : Theme.withAlpha(Theme.primary, 0.20)))
                                      : (root.pills ? (Theme.cozy ? Theme.bg : MdTokens.control) : "transparent"))
        border.width: root.pills && !opt.active ? (Theme.cozy ? Theme.bw1 : 1) : 0
        border.color: Theme.cozy ? Theme.edge : MdTokens.controlEdge
        Behavior on radius { NumberAnimation { duration: Theme.animDuration(180); easing.type: Easing.OutBack } }
        opacity: opt.modelData.enabled === false ? 0.45 : 1
        Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }

        onOptWidthChanged: root.measure()
        Component.onCompleted: root.measure()

        Row {
          id: optRow
          anchors.centerIn: parent
          spacing: 6

          Text {
            visible: (opt.modelData.icon ?? "") !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: opt.modelData.icon ?? ""
            color: opt.active ? Theme.textOnPrimary : Theme.primary
            font.pixelSize: Theme.sfs(12)
            font.family: Theme.monoFamily
          }
          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: opt.modelData.label
            color: opt.active ? Theme.textOnPrimary : Theme.text
            font.bold: opt.active
            font.pixelSize: Theme.sfs(11)
            font.family: Theme.fontFamily
          }
        }

        MouseArea {
          id: optArea
          anchors.fill: parent
          enabled: opt.modelData.enabled !== false
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.picked(opt.modelData.value)
        }
      }
    }
  }
}
