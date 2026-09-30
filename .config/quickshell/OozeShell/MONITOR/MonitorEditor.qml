// MonitorEditor ("HyprMonitors") — editor visual de monitores para
// Hyprland (configProvider: lua), como submenú de Ajustes
// (General → HyprMonitors).
//
//   ~/.config/hypr/modules/hardware/settings/monitors.lua
//
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

  property int cardWidth: 640
  property int edgeMargin: 10
  readonly property int pad: 18

  signal closeRequested()
  signal backRequested()

  // ─── Detección (hyprctl monitors -j) ────────────────────────────
  property var monitors: []     // modelo editable, ver refresh()
  property string selected: ""  // "output" elegido abajo del mapa
  property string status: ""    // texto de estado tras Aplicar

  readonly property var current: {
    for (const m of root.monitors) if (m.output === root.selected) return m
    return null
  }

  Process {
    id: detect
    command: ["hyprctl", "monitors", "-j"]
    running: false
    property string buffer: ""
    stdout: SplitParser { onRead: line => detect.buffer += line }
    onRunningChanged: {
      if (!running) {
        try {
          const list = JSON.parse(detect.buffer)
          root.monitors = list.map(m => ({
            output:    m.name,
            width:     m.width,
            height:    m.height,
            x:         m.x,
            y:         m.y,
            scale:     m.scale,
            transform: m.transform || 0,
            modes:     Array.isArray(m.availableModes) ? m.availableModes : [],
            mode:      "preferred",
            mirrorOf:  ""
          }))
          if (!root.monitors.some(m => m.output === root.selected))
            root.selected = root.monitors.length > 0 ? root.monitors[0].output : ""
        } catch (e) {
          console.log("MonitorEditor: error leyendo hyprctl monitors:", e)
        }
        detect.buffer = ""
      }
    }
  }

  // Redetecta cada vez que se abre: si enchufaste/desenchufaste algo
  // desde la última vez, aparece solo.
  onOpenChanged: if (root.open) { root.status = ""; detect.running = false; detect.running = true }

  // Reemplaza un monitor del modelo (inmutable, para que los bindings
  // de QML noten el cambio).
  function updateMonitor(output, patch) {
    root.monitors = root.monitors.map(m => m.output === output ? Object.assign({}, m, patch) : m)
  }

  // ─── Mapa / arrastre ─────────────────────────────────────────────
  // Caja envolvente de TODOS los monitores (en px lógicos = px
  // físicos / escala), con margen para poder arrastrar más allá del
  // borde de los demás.
  readonly property real mapPad: 500
  readonly property var bounds: {
    if (root.monitors.length === 0) return { minX: 0, minY: 0, w: 1920, h: 1080 }
    let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity
    for (const m of root.monitors) {
      const w = m.width / (m.scale || 1), h = m.height / (m.scale || 1)
      minX = Math.min(minX, m.x); minY = Math.min(minY, m.y)
      maxX = Math.max(maxX, m.x + w); maxY = Math.max(maxY, m.y + h)
    }
    return { minX: minX - root.mapPad, minY: minY - root.mapPad,
             w: (maxX - minX) + root.mapPad * 2, h: (maxY - minY) + root.mapPad * 2 }
  }
  property int mapHeight: 210
  readonly property real mapScale: Math.min(
    (root.cardWidth - root.pad * 2) / Math.max(1, root.bounds.w),
    root.mapHeight / Math.max(1, root.bounds.h)
  )

  function toMapX(x) { return (x - root.bounds.minX) * root.mapScale }
  function toMapY(y) { return (y - root.bounds.minY) * root.mapScale }
  function fromMapX(px) { return root.bounds.minX + px / root.mapScale }
  function fromMapY(py) { return root.bounds.minY + py / root.mapScale }
  // Redondea a pasos de 10px lógicos: fácil dejar dos monitores justo
  // pegados (ej. 1920x0) sin quedar a un pixel de más.
  function snap(v) { return Math.round(v / 10) * 10 }

  // Botón de texto (con icono opcional) — mismo componente que en
  // SettingsPanel/TerminalSettings.
  component Btn: Rectangle {
    id: btn
    property string text: ""
    property string icon: ""
    property bool primary: false
    signal clicked()

    implicitHeight: 32
    implicitWidth: btnRow.implicitWidth + 22
    Layout.preferredHeight: 32
    Layout.preferredWidth: btnRow.implicitWidth + 22
    radius: 9
    color: btn.primary
      ? (btnArea.containsMouse ? Qt.lighter(Theme.primary, 1.12) : Theme.primary)
      : (btnArea.containsMouse ? Theme.surfaceHigh : Theme.surface)
    Behavior on color { ColorAnimation { duration: 150 } }

    scale: btnArea.pressed ? 0.94 : 1.0
    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }

    RowLayout {
      id: btnRow
      anchors.centerIn: parent
      spacing: 6
      Text {
        visible: btn.icon !== ""
        text: btn.icon
        color: btn.primary ? Theme.textOnPrimary : Theme.primary
        font.pixelSize: Theme.fs(13)
        font.family: Theme.monoFamily
      }
      Text {
        text: btn.text
        color: btn.primary ? Theme.textOnPrimary : Theme.text
        font.pixelSize: Theme.fs(11)
        font.bold: true
        font.family: Theme.fontFamily
      }
    }

    MouseArea {
      id: btnArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: btn.clicked()
    }
  }

  FusedWindow {
    id: fw
    active: root.open || panel.shown
    targetScreen: root.targetScreen
    namespace: "oozeshell-monitor-editor"
    onCloseRequested: root.closeRequested()

    FusedPanel {
      id: panel

      open: root.open
      panelWidth: root.cardWidth
      contentHeight: col.implicitHeight + root.pad * 2

      align: "end"
      alignMargin: root.edgeMargin + Theme.barEdge + Theme.frameSideArm

      ColumnLayout {
        id: col
        x: root.pad
        y: root.pad
        width: parent.width - root.pad * 2
        spacing: 12

        PanelHeader {
          Layout.fillWidth: true
          icon: "󰍹"
          title: Translations.t("hyprMonitorsTitle")
          onBackRequested: root.backRequested()
        }

        Text {
          Layout.fillWidth: true
          text: Translations.t("hyprMonitorsHint")
          wrapMode: Text.WordWrap
          color: Theme.subtext
          font.pixelSize: Theme.fs(10)
          font.family: Theme.fontFamily
        }

        // ── Mapa: arrastrar para reposicionar ───────────────────
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: root.mapHeight
          radius: Theme.cardRadius
          color: Theme.surface
          clip: true

          Repeater {
            model: root.monitors

            delegate: Rectangle {
              id: box
              required property var modelData
              readonly property bool isSelected: modelData.output === root.selected
              readonly property real logW: modelData.width / (modelData.scale || 1)
              readonly property real logH: modelData.height / (modelData.scale || 1)

              x: root.toMapX(modelData.x)
              y: root.toMapY(modelData.y)
              width: Math.max(30, logW * root.mapScale)
              height: Math.max(30, logH * root.mapScale)
              radius: 6
              color: isSelected
                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.22)
                : Theme.surfaceHigh
              border.width: isSelected ? 2 : Theme.bw1
              border.color: isSelected ? Theme.primary : Theme.edge
              Behavior on x { enabled: !dragArea.drag.active; NumberAnimation { duration: 120 } }
              Behavior on y { enabled: !dragArea.drag.active; NumberAnimation { duration: 120 } }

              ColumnLayout {
                anchors.centerIn: parent
                spacing: 0
                Text {
                  Layout.alignment: Qt.AlignHCenter
                  text: modelData.output
                  color: box.isSelected ? Theme.primary : Theme.text
                  font.bold: true
                  font.pixelSize: Theme.fs(11)
                  font.family: Theme.fontFamily
                  elide: Text.ElideRight
                }
                Text {
                  Layout.alignment: Qt.AlignHCenter
                  visible: box.width > 60
                  text: modelData.width + "×" + modelData.height
                  color: Theme.subtext
                  font.pixelSize: Theme.fs(9)
                  font.family: Theme.fontFamily
                }
              }

              MouseArea {
                id: dragArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.SizeAllCursor
                onPressed: root.selected = box.modelData.output
                drag.target: box
                drag.axis: Drag.XAndYAxis
                onReleased: {
                  const newX = root.snap(root.fromMapX(box.x))
                  const newY = root.snap(root.fromMapY(box.y))
                  root.updateMonitor(box.modelData.output, { x: newX, y: newY })
                }
              }
            }
          }
        }

        // ── Selector de salida (si hay más de una) ──────────────
        Flow {
          Layout.fillWidth: true
          visible: root.monitors.length > 1
          spacing: 8
          Repeater {
            model: root.monitors
            delegate: Btn {
              required property var modelData
              icon: "󰍹"
              text: modelData.output
              primary: modelData.output === root.selected
              onClicked: root.selected = modelData.output
            }
          }
        }

        // ── Ajustes del monitor seleccionado ─────────────────────
        ColumnLayout {
          Layout.fillWidth: true
          visible: root.current !== null
          spacing: 10

          SectionLabel { text: Translations.t("hyprMonitorsMode") }
          Flow {
            Layout.fillWidth: true
            spacing: 8
            Btn {
              text: Translations.t("hyprMonitorsPreferred")
              primary: root.current && root.current.mode === "preferred"
              onClicked: root.updateMonitor(root.selected, { mode: "preferred" })
            }
            Repeater {
              model: root.current ? root.current.modes : []
              delegate: Btn {
                required property string modelData
                text: modelData
                primary: root.current && root.current.mode === modelData
                onClicked: root.updateMonitor(root.selected, { mode: modelData })
              }
            }
          }

          SectionLabel { text: Translations.t("hyprMonitorsScale") }
          Flow {
            Layout.fillWidth: true
            spacing: 8
            Repeater {
              model: ["auto", 1, 1.25, 1.5, 2]
              delegate: Btn {
                required property var modelData
                text: modelData === "auto" ? Translations.t("hyprMonitorsAuto")
                                            : Math.round(modelData * 100) + "%"
                primary: root.current && root.current.scale === modelData
                onClicked: root.updateMonitor(root.selected, { scale: modelData })
              }
            }
          }

          SectionLabel { text: Translations.t("hyprMonitorsRotation") }
          Flow {
            Layout.fillWidth: true
            spacing: 8
            Repeater {
              model: [ { v: 0, l: "0°" }, { v: 1, l: "90°" }, { v: 2, l: "180°" }, { v: 3, l: "270°" } ]
              delegate: Btn {
                required property var modelData
                text: modelData.l
                primary: root.current && root.current.transform === modelData.v
                onClicked: root.updateMonitor(root.selected, { transform: modelData.v })
              }
            }
          }

          SectionLabel { text: Translations.t("hyprMonitorsMirror") }
          Flow {
            Layout.fillWidth: true
            spacing: 8
            Btn {
              text: Translations.t("hyprMonitorsMirrorNone")
              primary: root.current && root.current.mirrorOf === ""
              onClicked: root.updateMonitor(root.selected, { mirrorOf: "" })
            }
            Repeater {
              model: root.monitors.filter(m => m.output !== root.selected)
              delegate: Btn {
                required property var modelData
                icon: "󰍹"
                text: modelData.output
                primary: root.current && root.current.mirrorOf === modelData.output
                onClicked: root.updateMonitor(root.selected, { mirrorOf: modelData.output })
              }
            }
          }
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }

        RowLayout {
          Layout.fillWidth: true
          spacing: 10
          Btn {
            icon: "󰑐"
            text: Translations.t("hyprMonitorsRefresh")
            onClicked: { detect.running = false; detect.running = true }
          }
          Item { Layout.fillWidth: true }
          Text {
            visible: root.status !== ""
            Layout.maximumWidth: 200
            text: root.status
            wrapMode: Text.WordWrap
            color: Theme.subtext
            font.pixelSize: Theme.fs(10)
            font.family: Theme.fontFamily
          }
          Btn {
            primary: true
            icon: "󰄬"
            text: Translations.t("hyprMonitorsApply")
            onClicked: root.applyAndSave()
          }
        }
      }
    }
  }

  // ─── Escritura de monitors.lua + aplicar ────────────────────────
  readonly property string monitorsLuaPath:
    Quickshell.env("HOME") + "/.config/hypr/modules/hardware/settings/monitors.lua"

  // Un hl.monitor({...}) por salida, mismo formato que tu archivo a
  // mano. Con espejo activado, la posición no importa (Hyprland la
  // ignora) pero se manda igual como "auto" para que quede prolijo.
  function luaMonitorBlock(m) {
    const pos = m.mirrorOf !== "" ? "auto" : (m.x + "x" + m.y)
    const lines = []
    lines.push("hl.monitor({")
    lines.push("    output   = \"" + m.output + "\",")
    lines.push("    mode     = \"" + m.mode + "\",")
    lines.push("    position = \"" + pos + "\",")
    lines.push("    scale    = " + (m.scale === "auto" ? "\"auto\"" : m.scale) + ",")
    if (m.transform && m.transform !== 0)
      lines.push("    transform = " + m.transform + ", -- 1 = 90°, 2 = 180°, 3 = 270°")
    if (m.mirrorOf !== "")
      lines.push("    mirror   = \"" + m.mirrorOf + "\",")
    lines.push("})")
    return lines.join("\n")
  }

  function buildLua() {
    const header =
      "-- ============================================================================\n" +
      "--  MODULE: monitors.lua\n" +
      "--  Contains: monitor outputs (mode, position, scale, mirroring).\n" +
      "--  Auto-generado por OozeShell (HyprMonitors, Ajustes → General). No editar\n" +
      "--  a mano: se pisa entero cada vez que tocás \"Aplicar\" en el panel.\n" +
      "--  Wiki: https://wiki.hypr.land/Configuring/Basics/Monitors/\n" +
      "-- ============================================================================\n\n" +
      "------------------\n---- MONITORS ----\n------------------\n\n" +
      "-- See https://wiki.hypr.land/Configuring/Basics/Monitors/\n\n"
    return header + root.monitors.map(m => root.luaMonitorBlock(m)).join("\n\n") + "\n"
  }

  Process {
    id: saveMonitorsLua
    property string content: ""
    command: ["bash", "-c",
      "mkdir -p \"$(dirname '" + root.monitorsLuaPath + "')\" && cat > '" +
      root.monitorsLuaPath + "' << 'OOZE_LUA_EOF'\n" + content + "\nOOZE_LUA_EOF\n"]
    running: false
    onRunningChanged: if (!running) { applyReload.running = false; applyReload.running = true }
  }

  // El archivo cambió, pero hyprland.lua ya lo *requirió* al arrancar:
  // hace falta un reload real para que lo vuelva a leer.
  Process {
    id: applyReload
    running: false
    command: ["bash", "-c", "hyprctl reload"]
    property bool failed: false
    stdout: SplitParser { onRead: line => console.log("[monitors] hyprctl:", line) }
    stderr: SplitParser { onRead: line => { applyReload.failed = true; console.log("[monitors] hyprctl error:", line) } }
    onRunningChanged: {
      if (!running) {
        root.status = applyReload.failed ? Translations.t("hyprMonitorsError")
                                          : Translations.t("hyprMonitorsApplied")
        applyReload.failed = false
      }
    }
  }

  function applyAndSave() {
    root.status = ""
    saveMonitorsLua.content = root.buildLua()
    saveMonitorsLua.running = false
    saveMonitorsLua.running = true
  }
}
