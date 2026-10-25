// WallsCard — WALLS

import QtQuick
import QtQuick.Layouts
import "../Lang"
import "../../COMMON"

Item {
  id: cCard

  required property var walls
  required property Item dock
  required property int index
  property real progress: 1
  property real hoverLift: 10
  // Inclinación horizontal (tan del ángulo). 0 = rectángulo, >0 = paralelogramo.
  property real skew: 0

  property int offset: index - walls.halfWindow
  property int total: walls.activeModel.count
  property bool slotActive:
    total > 0 &&
    Math.abs(offset) < Math.max(1, Math.ceil(total / 2))
  property int actualIndex:
    total > 0
      ? ((walls.currentIndex + offset) % total + total) % total
      : -1
  property var wp: {
    walls.thumbRev
    walls.liveMode
    walls.downloadedMode
    return (slotActive && actualIndex >= 0 && actualIndex < total)
      ? walls.activeModel.get(actualIndex)
      : null
  }
  readonly property string wpKey: cCard.wp ? cCard.wp.path : ""
  property bool isCurrent: offset === 0

  // ─── GEOMETRÍA ───
  // Horizontal: las tarjetas se reparten en X. Vertical: se reparten en Y (columna).
  readonly property bool vert: dock.vertical
  readonly property real curLen: cCard.vert ? dock.cardH : dock.cardW
  readonly property real sideLen: cCard.vert ? dock.sideH : dock.sideW
  readonly property real slotStep: cCard.sideLen + dock.gap
  readonly property real centerPos: dock.edgeMargin + dock.half * cCard.slotStep
  property real targetPos:
    offset < 0 ? dock.edgeMargin + (offset + dock.half) * cCard.slotStep
    : (offset === 0 ? cCard.centerPos
    : cCard.centerPos + cCard.curLen + dock.gap + (offset - 1) * cCard.slotStep)
  property real targetLen: isCurrent ? cCard.curLen : cCard.sideLen

  readonly property bool hovered: cardMouse.containsMouse
  property real targetCross:
    cCard.vert ? 0
    : dock.hoverLift - ((walls.previewOn && hovered && !isCurrent) ? hoverLift : 0)

  property real targetOpacity:
    !slotActive
      ? 0.0
      : (
          isCurrent
            ? 1.0
            : Math.min(
                0.97,
                Math.max(0.45, 0.80 - (Math.abs(offset) - 1) * 0.14)
                  + ((walls.previewOn && hovered) ? 0.17 : 0)
              )
        )

  x: cCard.vert ? cCard.targetCross : cCard.targetPos
  y: cCard.vert ? cCard.targetPos : cCard.targetCross
  width: cCard.vert ? dock.cardW : cCard.targetLen
  height: cCard.vert ? cCard.targetLen : dock.cardH
  opacity: targetOpacity
  visible: slotActive

  z: isCurrent ? 99 : 50 - Math.abs(offset)

  Behavior on x {
    enabled: cCard.progress >= 0.999
    NumberAnimation { duration: Theme.animDuration(320); easing.type: Easing.OutCubic }
  }
  Behavior on width {
    enabled: cCard.progress >= 0.999
    NumberAnimation { duration: Theme.animDuration(320); easing.type: Easing.OutCubic }
  }
  Behavior on height {
    enabled: cCard.progress >= 0.999
    NumberAnimation { duration: Theme.animDuration(320); easing.type: Easing.OutCubic }
  }
  Behavior on y {
    enabled: cCard.progress >= 0.999
    NumberAnimation { duration: Theme.animDuration(cCard.vert ? 320 : 220); easing.type: Easing.OutCubic }
  }
  Behavior on opacity {
    NumberAnimation { duration: Theme.animDuration(250) }
  }

  // ─── IMAGEN EN ALTA ───
  property string hiUrl: ""
  onWpKeyChanged: { cCard.hiUrl = ""; hiTimer.restart() }
  onIsCurrentChanged: { cCard.hiUrl = ""; hiTimer.restart() }
  Timer {
    id: hiTimer
    interval: 450
    repeat: false
    onTriggered: {
      cCard.hiUrl = (cCard.isCurrent && cCard.walls.open && cCard.walls.onlineMode
                     && cCard.wp && !cCard.wp.isVideo && cCard.wp.url) ? cCard.wp.url : ""
    }
  }

  // ─── CONTENEDOR INCLINADO ───
  // Capa con antialiasing (MSAA): suaviza los bordes diagonales del paralelogramo.
  // Es más grande que la tarjeta porque la inclinación desplaza las esquinas hacia los lados.
  Item {
    id: aaBox
    readonly property real over: Math.ceil(cCard.skew * cCard.height / 2) + 6
    x: -over
    y: -3
    width: cCard.width + over * 2
    height: cCard.height + 6
    layer.enabled: cCard.skew > 0
    layer.samples: 4
    layer.smooth: true

  Item {
    id: shearBox
    x: aaBox.over
    y: 3
    width: cCard.width
    height: cCard.height
    transform: Matrix4x4 {
      matrix: Qt.matrix4x4(1, -cCard.skew, 0, cCard.skew * cCard.height / 2,
                           0, 1, 0, 0,
                           0, 0, 1, 0,
                           0, 0, 0, 1)
    }

  // ─── MARCO ───
  SkinRect {
    id: cardFrame
    anchors.fill: parent
    clip: true
    radius: 0
    notch: 0
    raised: Theme.cozy
    depth: 4
    inkColor: cCard.isCurrent ? Theme.primary : Theme.ink
    color: Theme.bg
    border.color: cCard.isCurrent ? Theme.primary : Theme.tint(0.25)
    border.width: cCard.isCurrent ? 3 : 2
    Behavior on border.color {
      ColorAnimation { duration: Theme.animDuration(200) }
    }

    // Área interior: separada del borde por su grosor y recortada en paralelogramo (clip),
    // así el borde del marco queda visible por los cuatro lados.
    Item {
      id: inner
      anchors.fill: parent
      anchors.margins: cardFrame.border.width
      clip: true

      // Capa de imágenes contra-inclinada (la imagen NO se deforma). Más ancha para cubrir
      // las esquinas desplazadas por la inclinación.
      Item {
        id: imgLayer
        readonly property real over: cCard.skew * cCard.height / 2
        x: -over
        y: 0
        width: parent.width + over * 2
        height: parent.height
        transform: Matrix4x4 {
          matrix: Qt.matrix4x4(1, cCard.skew, 0,
                               cCard.skew * (cardFrame.border.width - cCard.height / 2),
                               0, 1, 0, 0,
                               0, 0, 1, 0,
                               0, 0, 0, 1)
        }

        Image {
          id: cThumb
          anchors.fill: parent
          source: (cCard.wp && cCard.wp.ready) ? ("file://" + cCard.wp.thumb) : ""
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          cache: true
          sourceSize.width: Math.round(cCard.dock.cardW * 1.3)
          visible: !cAnim.visible || cAnim.status !== AnimatedImage.Ready
          opacity: status === Image.Ready ? 1.0 : 0.0
          Behavior on opacity {
            NumberAnimation { duration: Theme.animDuration(280) }
          }
        }

        Image {
          id: cHi
          anchors.fill: parent
          source: cCard.hiUrl
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          cache: true
          sourceSize.width: 1600
          opacity: status === Image.Ready ? 1.0 : 0.0
          visible: cCard.hiUrl !== ""
          Behavior on opacity {
            NumberAnimation { duration: Theme.animDuration(300) }
          }
        }

        Rectangle {
          id: shimmer
          anchors.fill: parent
          visible: cCard.walls.previewOn && cCard.slotActive && cThumb.status !== Image.Ready
          color: Theme.primary
          opacity: 0.12
          SequentialAnimation on opacity {
            running: (shimmer.visible && cCard.walls.open) && Theme.uiAnimationsEnabled
            loops: Animation.Infinite
            NumberAnimation { from: 0.08; to: 0.26; duration: Theme.animDuration(900); easing.type: Easing.InOutSine }
            NumberAnimation { from: 0.26; to: 0.08; duration: Theme.animDuration(900); easing.type: Easing.InOutSine }
          }
        }

        AnimatedImage {
          id: cAnim
          anchors.fill: parent
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          cache: true

          visible:
            cCard.walls.previewOn &&
            !Theme.shellPerf &&
            cCard.walls.open &&
            (cCard.walls.liveMode || (cCard.walls.onlineMode && cCard.walls.onlineLive)) &&
            cCard.isCurrent &&
            !!cCard.wp &&
            !!cCard.wp.clipReady
          source: visible ? ("file://" + cCard.wp.clip) : ""
          playing: visible && Theme.uiAnimationsEnabled
        }
      }
    }

    // ─── INSIGNIAS ───
    SkinRect {
      visible: !!cCard.wp && (cCard.walls.onlineMode || !!cCard.wp.isVideo) && cCard.width > 120 && cCard.height > 90
      anchors { top: parent.top; right: parent.right; margins: cardFrame.border.width + 6 }
      width: typeBadge.implicitWidth + 14; height: 22
      notch: 3
      transform: Matrix4x4 {
        matrix: Qt.matrix4x4(1, cCard.skew, 0, -cCard.skew * 11,
                             0, 1, 0, 0,
                             0, 0, 1, 0,
                             0, 0, 0, 1)
      }
      raised: Theme.cozy
      depth: 2
      inkColor: Theme.primary
      color: Qt.rgba(0, 0, 0, 0.65)
      Text {
        id: typeBadge
        anchors.centerIn: parent
        text: (cCard.walls.onlineMode ? "☁ ONLINE" : "") +
              ((cCard.walls.onlineMode && cCard.wp && cCard.wp.isVideo) ? "  " : "") +
              ((cCard.wp && cCard.wp.isVideo) ? "▶ LIVE" : "")
        color: Theme.primary
        font.pixelSize: 10
        font.bold: true
        font.family: Theme.fontFamily
      }
    }

    SkinRect {
      visible: !!cCard.wp && cCard.wp.path === cCard.walls.appliedPath && cCard.width > 120 && cCard.height > 90
      anchors { top: parent.top; left: parent.left; margins: cardFrame.border.width + 6 }
      width: curBadge.implicitWidth + 14; height: 22
      notch: 3
      transform: Matrix4x4 {
        matrix: Qt.matrix4x4(1, cCard.skew, 0, -cCard.skew * 11,
                             0, 1, 0, 0,
                             0, 0, 1, 0,
                             0, 0, 0, 1)
      }
      raised: Theme.cozy
      depth: 2
      inkColor: Theme.primary
      color: Theme.primary
      Text {
        id: curBadge
        anchors.centerIn: parent
        text: "● " + Translations.t("wallsCurrent")
        color: Theme.bg
        font.pixelSize: 10
        font.bold: true
        font.family: Theme.fontFamily
      }
    }

    Rectangle {
      anchors.bottom: parent.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.margins: cardFrame.border.width
      height: 44
      color: Qt.rgba(0, 0, 0, 0.68)
      visible: cCard.isCurrent && !!cCard.wp

      RowLayout {
        anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
        transform: Matrix4x4 {
          matrix: Qt.matrix4x4(1, cCard.skew, 0, -cCard.skew * 22,
                               0, 1, 0, 0,
                               0, 0, 1, 0,
                               0, 0, 0, 1)
        }

        Text {
          text: cCard.wp ? cCard.wp.name.replace(/\.[^.]+$/, "") : ""
          color: "#ffffffee"
          font.pixelSize: 13
          font.family: Theme.fontFamily
          elide: Text.ElideRight
          Layout.fillWidth: true
        }

        Text {
          text: cCard.walls.changing ? Translations.t("wallsApplying")
              : (cCard.walls.onlineMode && cCard.walls.onlineError === "net" ? Translations.t("wallsOnlineFailed")
              : "✓ " + Translations.t("wallsApply"))
          color: Theme.primary
          font.pixelSize: 12
          font.bold: true
          font.family: Theme.fontFamily
        }
      }
    }
  }

  MouseArea {
    id: cardMouse
    anchors.fill: parent
    enabled: cCard.slotActive
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: {
      if (cCard.isCurrent) cCard.walls.applyItem(cCard.wp)
      else cCard.walls.currentIndex = cCard.actualIndex
    }
  }
  }
  }
}
