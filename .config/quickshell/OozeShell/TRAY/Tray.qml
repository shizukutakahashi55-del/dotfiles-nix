// Tray — bandeja del sistema (reemplaza el módulo "tray" de Waybar).
// Este archivo NO dibuja ni el tooltip ni el menú: solo avisa por señales (tipEnter / tipLeave / menuRequested) y el host (RightModules) los muestra con la misma lógica que el resto de los popups.

import Quickshell
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Layouts

import "../COMMON"

BarFlow {
  id: tray


  property int iconSize: 18


  property real renderScale: 1


  property real uiScale: 1


  property bool snapSizes: false
  readonly property var nativeSizes: [16, 22, 24, 32, 48]
  function snap(n) {
    let best = tray.nativeSizes[0]
    for (let i = 0; i < tray.nativeSizes.length; i++) {
      const c = tray.nativeSizes[i]
      if (Math.abs(c - n) <= Math.abs(best - n)) best = c
    }
    return best
  }
  readonly property int drawSize: tray.snapSizes ? tray.snap(tray.iconSize) : tray.iconSize


  readonly property real dpr: Math.max(1, Screen.devicePixelRatio)


  readonly property int texSize:
    Math.max(
      16,
      Math.ceil(tray.drawSize * tray.renderScale * tray.dpr)
    )


  property var activeItem: null

  readonly property int count: rep.count


  function resolveIcon(raw) {
    const s = String(raw || "")
    if (s === "") return ""

    const pre = "image://icon/"
    if (s.indexOf(pre) !== 0) return s

    let name = s.substring(pre.length)
    const q = name.indexOf("?")
    if (q >= 0) name = name.substring(0, q)
    if (name === "") return s

    if (name.charAt(0) === "/")
      return "file://" + name

    const p = Quickshell.iconPath(name, true)
    if (p === "") return s
    return p.charAt(0) === "/" ? "file://" + p : p
  }

  signal tipEnter(var item)
  signal tipLeave(var item)


  signal menuRequested(var iconItem, var entry)

  gap: 0

  Repeater {
    id: rep

    model: SystemTray.items

    delegate: Rectangle {
      id: trayItem

      required property SystemTrayItem modelData

      readonly property bool active:
        tray.activeItem === trayItem.modelData

      readonly property string tip: {
        const t =
          modelData.tooltipTitle
          || modelData.title
          || modelData.id
          || ""

        const d =
          modelData.tooltipDescription
          || ""

        return d !== "" ? t + "\n" + d : t
      }


      Layout.preferredWidth: Math.max(tray.iconSize, tray.drawSize) + Math.round(8 * tray.uiScale)
      Layout.preferredHeight: Math.round(26 * tray.uiScale)

      radius: Math.round(8 * tray.uiScale)

      color:
        (itemArea.containsMouse || trayItem.active)
        ? Theme.surface
        : "transparent"

      Behavior on color {
        ColorAnimation {
          duration: Theme.animDuration(120)
        }
      }

      // ---------------------------------------------------------

      // ---------------------------------------------------------

      Item {
        id: iconBox


        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)


        width: tray.drawSize
        height: tray.drawSize

        opacity: itemArea.pressed ? 0.7 : 1.0

        Behavior on opacity {
          NumberAnimation {
            duration: Theme.animDuration(100)
          }
        }

        Image {
          id: trayImg

          x: 0
          y: 0


          width: iconBox.width
          height: iconBox.height


          sourceSize.width: tray.texSize
          sourceSize.height: tray.texSize

          fillMode: Image.PreserveAspectFit


          asynchronous: false


          smooth: true


          mipmap: false

          cache: true

          source: tray.resolveIcon(trayItem.modelData.icon)
        }
      }

      MouseArea {
        id: itemArea

        anchors.fill: parent

        hoverEnabled: true

        cursorShape: Qt.PointingHandCursor

        acceptedButtons:
          Qt.LeftButton
          | Qt.RightButton
          | Qt.MiddleButton

        onEntered: tray.tipEnter(trayItem)
        onExited: tray.tipLeave(trayItem)

        onClicked: mouse => {
          const it = trayItem.modelData

          if (mouse.button === Qt.RightButton) {

            if (it.hasMenu)
              tray.menuRequested(trayItem, it)
            else
              it.secondaryActivate()

          } else if (mouse.button === Qt.MiddleButton) {

            it.secondaryActivate()

          } else {

            if (it.onlyMenu && it.hasMenu)
              tray.menuRequested(trayItem, it)
            else
              it.activate()
          }
        }
      }
    }
  }
}
