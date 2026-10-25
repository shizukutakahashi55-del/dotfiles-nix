// WallsPreview — WALLS
// Vista previa grande del wallpaper actual (layout List).

import QtQuick
import QtQuick.Layouts
import "../Lang"
import "../../COMMON"

Item {
  id: pv

  required property var walls

  readonly property int idx: pv.walls.currentIndex
  readonly property int total: pv.walls.activeModel.count
  readonly property var wp: {
    pv.walls.thumbRev
    pv.walls.liveMode
    pv.walls.downloadedMode
    return (pv.total > 0 && pv.idx >= 0 && pv.idx < pv.total) ? pv.walls.activeModel.get(pv.idx) : null
  }
  readonly property string wpKey: pv.wp ? pv.wp.path : ""

  // ─── IMAGEN EN ALTA (online) ───
  property string hiUrl: ""
  onWpKeyChanged: { pv.hiUrl = ""; hiTimer.restart() }
  Timer {
    id: hiTimer
    interval: 450
    repeat: false
    onTriggered: {
      pv.hiUrl = (pv.walls.open && pv.walls.onlineMode && pv.wp && !pv.wp.isVideo && pv.wp.url) ? pv.wp.url : ""
    }
  }

  SkinRect {
    id: frame
    anchors.fill: parent
    clip: true
    radius: 0
    notch: 0
    raised: Theme.cozy
    depth: 4
    inkColor: Theme.primary
    color: Theme.bg
    border.color: Theme.primary
    border.width: 3

    Image {
      id: pThumb
      anchors.fill: parent
      anchors.margins: frame.border.width
      source: (pv.wp && pv.wp.ready) ? ("file://" + pv.wp.thumb) : ""
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      cache: true
      sourceSize.width: Math.round(Math.max(1, pv.width) * 1.2)
      visible: !pAnim.visible || pAnim.status !== AnimatedImage.Ready
      opacity: status === Image.Ready ? 1.0 : 0.0
      Behavior on opacity { NumberAnimation { duration: Theme.animDuration(280) } }
    }

    Image {
      id: pHi
      anchors.fill: parent
      anchors.margins: frame.border.width
      source: pv.hiUrl
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      cache: true
      sourceSize.width: 1600
      visible: pv.hiUrl !== ""
      opacity: status === Image.Ready ? 1.0 : 0.0
      Behavior on opacity { NumberAnimation { duration: Theme.animDuration(300) } }
    }

    AnimatedImage {
      id: pAnim
      anchors.fill: parent
      anchors.margins: frame.border.width
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      cache: true
      visible:
        pv.walls.previewOn &&
        !Theme.shellPerf &&
        pv.walls.open &&
        (pv.walls.liveMode || (pv.walls.onlineMode && pv.walls.onlineLive)) &&
        !!pv.wp &&
        !!pv.wp.clipReady
      source: visible ? ("file://" + pv.wp.clip) : ""
      playing: visible && Theme.uiAnimationsEnabled
    }

    // ─── INSIGNIAS ───
    SkinRect {
      visible: !!pv.wp && pv.wp.path === pv.walls.appliedPath
      anchors { top: parent.top; left: parent.left; margins: frame.border.width + 8 }
      width: curBadge.implicitWidth + 14; height: 22
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
        font.pixelSize: 10
        font.bold: true
        font.family: Theme.fontFamily
      }
    }

    SkinRect {
      visible: !!pv.wp && (pv.walls.onlineMode || !!pv.wp.isVideo)
      anchors { top: parent.top; right: parent.right; margins: frame.border.width + 8 }
      width: typeBadge.implicitWidth + 14; height: 22
      notch: 3
      raised: Theme.cozy
      depth: 2
      inkColor: Theme.primary
      color: Qt.rgba(0, 0, 0, 0.65)
      Text {
        id: typeBadge
        anchors.centerIn: parent
        text: (pv.walls.onlineMode ? "☁ ONLINE" : "") +
              ((pv.walls.onlineMode && pv.wp && pv.wp.isVideo) ? "  " : "") +
              ((pv.wp && pv.wp.isVideo) ? "▶ LIVE" : "")
        color: Theme.primary
        font.pixelSize: 10
        font.bold: true
        font.family: Theme.fontFamily
      }
    }

    // ─── PIE ───
    Rectangle {
      anchors.bottom: parent.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.margins: frame.border.width
      height: 44
      color: Qt.rgba(0, 0, 0, 0.68)
      visible: !!pv.wp

      RowLayout {
        anchors { fill: parent; leftMargin: 14; rightMargin: 14 }

        Text {
          text: pv.wp ? pv.wp.name.replace(/\.[^.]+$/, "") : ""
          color: "#ffffffee"
          font.pixelSize: 13
          font.family: Theme.fontFamily
          elide: Text.ElideRight
          Layout.fillWidth: true
        }

        Text {
          text: pv.walls.changing ? Translations.t("wallsApplying")
              : (pv.walls.onlineMode && pv.walls.onlineError === "net" ? Translations.t("wallsOnlineFailed")
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
    anchors.fill: parent
    enabled: !!pv.wp
    cursorShape: Qt.PointingHandCursor
    onClicked: pv.walls.applyItem(pv.wp)
  }
}
