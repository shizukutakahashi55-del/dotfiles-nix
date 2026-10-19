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
  property bool isCurrent: offset === 0
  property real cw: dock.cardW
  property real ch: dock.cardH

  // ─── OVERLAP ───
  property real spacing: cw * 0.52
  property real targetX:
    (dock.width / 2) -
    (cw / 2) +
    (offset * spacing)

  readonly property bool hovered: cardMouse.containsMouse
  property real targetY:
    (dock.height - ch) -
    ((walls.previewOn && hovered && !isCurrent) ? hoverLift : 0)

  // ─── ESCALA ───
  property real targetScale:
    isCurrent
      ? 1.0
      : Math.max(
          0.92,
          0.98 - Math.abs(offset) * 0.025
        )

  // ─── OPACIDAD ───
  property real targetOpacity:
    !slotActive
      ? 0.0
      : (
          isCurrent
            ? 1.0
            : Math.min(
                0.97,
                Math.max(
                  0.50,
                  0.82 - Math.abs(offset) * 0.08
                ) + ((walls.previewOn && hovered) ? 0.15 : 0)
              )
        )

  // ─── ROTACIÓN ───
  property real targetAngle:
    offset * 0

  x: targetX
  y: targetY
  width: cw
  height: ch
  opacity: targetOpacity
  visible: slotActive

  z: isCurrent
    ? 99
    : 50 - Math.abs(offset)

  // ─── Animaciones de movimiento ───
  Behavior on x {
    enabled: cCard.progress >= 0.999
    NumberAnimation {
      duration: Theme.animDuration(350)
      easing.type: Easing.OutCubic
    }
  }
  Behavior on y {
    enabled: cCard.progress >= 0.999
    NumberAnimation {
      duration: Theme.animDuration(350)
      easing.type: Easing.OutCubic
    }
  }
  Behavior on opacity {
    NumberAnimation {
      duration: Theme.animDuration(250)
    }
  }
  transform: [

    // ─── ESCALA ───
    Scale {
      origin.x: cCard.cw / 2
      origin.y: cCard.ch
      xScale: cCard.targetScale
      yScale: cCard.targetScale

      Behavior on xScale {
        NumberAnimation {
          duration: Theme.animDuration(350)
          easing.type: Easing.OutCubic
        }
      }
      Behavior on yScale {
        NumberAnimation {
          duration: Theme.animDuration(350)
          easing.type: Easing.OutCubic
        }
      }
    },

    // ─── ROTACIÓN ───
    Rotation {
      origin.x: cCard.cw / 2
      origin.y: cCard.ch / 2
      angle: cCard.targetAngle
      Behavior on angle {
        NumberAnimation {
          duration: Theme.animDuration(350)
          easing.type: Easing.OutCubic
        }
      }
    }
  ]

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
    border.color:
      cCard.isCurrent
        ? Theme.primary
        : Theme.tint(0.25)
    border.width: 2
    Behavior on border.color {
      ColorAnimation {
        duration: Theme.animDuration(200)
      }
    }

    // ─── Imagen ───
    Image {
      id: cThumb
      anchors.fill: parent
      anchors.margins: cardFrame.border.width
      source:
        (cCard.wp && cCard.wp.ready)
          ? ("file://" + cCard.wp.thumb)
          : ""
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      cache: true
      sourceSize.width: parent.width
      sourceSize.height: parent.height

      visible: !cAnim.visible || cAnim.status !== AnimatedImage.Ready
      opacity:
        status === Image.Ready
          ? 1.0
          : 0.0
      Behavior on opacity {
        NumberAnimation {
          duration: Theme.animDuration(280)
        }
      }
    }

    Rectangle {
      id: shimmer
      anchors.fill: parent
      anchors.margins: cardFrame.border.width
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

    // ─── Vista previa animada (solo tarjeta central) ───
    AnimatedImage {
      id: cAnim
      anchors.fill: parent
      anchors.margins: cardFrame.border.width
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      cache: true

      visible:
        cCard.walls.previewOn &&
        !Theme.shellPerf &&
        cCard.walls.open &&
        cCard.walls.liveMode &&
        cCard.isCurrent &&
        !!cCard.wp &&
        !!cCard.wp.clipReady
      source: visible ? ("file://" + cCard.wp.clip) : ""
      playing: visible && Theme.uiAnimationsEnabled
    }

    // ─── INSIGNIAS ───
    SkinRect {
      visible: cCard.walls.onlineMode && cCard.wp
      anchors { top: parent.top; right: parent.right; margins: cardFrame.border.width + 6 }
      width: onlineBadge.implicitWidth + 14; height: 20
      notch: 3
      raised: Theme.cozy
      depth: 2
      inkColor: Theme.primary
      color: Qt.rgba(0, 0, 0, 0.65)
      Text {
        id: onlineBadge
        anchors.centerIn: parent
        text: "☁ ONLINE"
        color: Theme.primary
        font.pixelSize: 9
        font.bold: true
        font.family: Theme.fontFamily
      }
    }

    SkinRect {
      visible: cCard.walls.liveMode && cCard.wp
      anchors { top: parent.top; right: parent.right; margins: cardFrame.border.width + 6 }
      width: liveBadge.implicitWidth + 14; height: 20
      notch: 3
      raised: Theme.cozy
      depth: 2
      inkColor: Theme.primary
      color: Qt.rgba(0, 0, 0, 0.65)
      Text {
        id: liveBadge
        anchors.centerIn: parent
        text: "▶ LIVE"
        color: Theme.primary
        font.pixelSize: 9
        font.bold: true
        font.family: Theme.fontFamily
      }
    }

    SkinRect {
      visible: !!cCard.wp && cCard.wp.path === cCard.walls.appliedPath
      anchors { top: parent.top; left: parent.left; margins: cardFrame.border.width + 6 }
      width: curBadge.implicitWidth + 14; height: 20
      notch: 3
      raised: Theme.cozy
      depth: 2
      inkColor: Theme.primary
      color: Theme.primary
      Text {
        id: curBadge
        anchors.centerIn: parent
        text: "● " + Translations.t("wallsCurrent")
        color: Theme.bg
        font.pixelSize: 9
        font.bold: true
        font.family: Theme.fontFamily
      }
    }

    // ─── BARRA DE NOMBRE ───
    Rectangle {
      anchors.bottom: parent.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.margins: cardFrame.border.width
      height: 36
      color: Qt.rgba(0, 0, 0, 0.65)
      visible:
        cCard.isCurrent &&
        cCard.wp

      RowLayout {
        anchors {
          fill: parent
          leftMargin: 12
          rightMargin: 12
        }

        Text {
          text:
            cCard.wp
              ? cCard.wp.name.replace(
                  /\.[^.]+$/,
                  ""
                )
              : ""

          color: "#ffffffdd"
          font.pixelSize: 11
          font.family: Theme.fontFamily
          elide: Text.ElideRight
          Layout.fillWidth: true
        }

        Text {
          text:
            Translations.t(
              cCard.walls.changing ? "wallsApplying"
              : (cCard.walls.onlineMode && cCard.walls.onlineError === "net" ? "wallsOnlineFailed"
              : "wallsApplyHint")
            )
          color:
            Theme.primary

          font.pixelSize: 9
          font.family: Theme.fontFamily
        }
      }
    }
  }

  // ─── INTERACCIÓN ───
  MouseArea {
    id: cardMouse
    anchors.fill: parent
    enabled: cCard.slotActive
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: {
      if (cCard.isCurrent) {
        cCard.walls.applyItem(cCard.wp)
      } else {
        cCard.walls.currentIndex = cCard.actualIndex
      }
    }
  }
}
