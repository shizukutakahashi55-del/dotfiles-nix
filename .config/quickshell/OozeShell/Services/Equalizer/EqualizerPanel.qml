import QtQuick
import QtQuick.Layouts
import "../../COMMON"
import "../../Settings"
import "../Lang"

ColumnLayout {
  id: root

  property real k: 1
  property bool dense: false
  property bool closable: false
  signal closeRequested()

  readonly property bool on: EqualizerService.enabled
  readonly property int sliderH: root.g(root.dense ? 118 : 176)
  readonly property int handle: root.g(root.dense ? 12 : 16)
  readonly property int handleW: root.g(root.dense ? 24 : 36)
  readonly property int trackW: root.g(root.dense ? 6 : 10)
  readonly property int scaleW: root.g(root.dense ? 30 : 40)

  spacing: root.g(root.dense ? 8 : 12)

  function g(px) { return Math.round(px * root.k) }
  function f(px) { return root.dense ? Theme.dfs(px) : Theme.sfs(px) }
  function yOf(v) { return root.handle / 2 + (12 - v) / 24 * (root.sliderH - root.handle) }
  function fmt(v) { return (v > 0 ? "+" : "") + (Math.abs(v) % 1 === 0 ? v.toFixed(0) : v.toFixed(1)) }

  component Card: Rectangle {
    radius: Theme.cardRadius + 2
    color: Theme.bg
    border.width: Theme.bw1
    border.color: Theme.edge
  }

  component HSlider: Item {
    id: hs
    property real from: 0
    property real to: 1
    property real value: 0
    signal moved(real v)
    implicitHeight: root.g(24)
    readonly property real frac: (hs.value - hs.from) / (hs.to - hs.from)
    readonly property real mid: (0 - hs.from) / (hs.to - hs.from)

    Rectangle {
      id: ht
      anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
      height: root.g(6)
      radius: height / 2
      color: Theme.surfaceHigh
      Rectangle {
        x: Math.min(hs.frac, hs.mid) * parent.width
        width: Math.abs(hs.frac - hs.mid) * parent.width
        height: parent.height
        radius: height / 2
        color: Theme.primary
      }
    }
    Rectangle {
      width: root.g(18)
      height: width
      radius: width / 2
      x: (hs.width - width) * hs.frac
      anchors.verticalCenter: parent.verticalCenter
      color: Theme.primary
      border.width: 3
      border.color: Theme.bg
    }
    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      function setFrom(mx) {
        const hw = root.g(9)
        const fr = Math.max(0, Math.min(1, (mx - hw) / Math.max(1, hs.width - hw * 2)))
        hs.moved(hs.from + fr * (hs.to - hs.from))
      }
      onPressed: mouse => setFrom(mouse.x)
      onPositionChanged: mouse => { if (pressed) setFrom(mouse.x) }
      onDoubleClicked: hs.moved(0)
    }
  }

  Card {
    Layout.fillWidth: true
    implicitHeight: hdr.implicitHeight + root.g(root.dense ? 14 : 24)
    radius: Theme.cardRadius + 4

    RowLayout {
      id: hdr
      anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: root.g(root.dense ? 10 : 14) }
      spacing: root.g(12)

      Rectangle {
        visible: !root.dense
        Layout.preferredWidth: root.g(46)
        Layout.preferredHeight: root.g(46)
        radius: width / 2
        color: root.on ? Theme.primary : Theme.surfaceHigh
        Behavior on color { ColorAnimation { duration: Theme.animDuration(160) } }
        Text {
          anchors.centerIn: parent
          text: "󰺢"
          color: root.on ? Theme.textOnPrimary : Theme.subtext
          font.pixelSize: root.f(22)
          font.family: Theme.monoFamily
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 0
        Text {
          Layout.fillWidth: true
          elide: Text.ElideRight
          text: Translations.t("eqTitle")
          color: Theme.text
          font.bold: true
          font.pixelSize: root.f(root.dense ? 14 : 18)
          font.family: Theme.fontFamily
        }
        Text {
          Layout.fillWidth: true
          elide: Text.ElideRight
          visible: !root.dense || EqualizerService.error !== ""
          text: EqualizerService.error !== "" ? Translations.t("eqMissing") + " " + EqualizerService.error
              : (root.on ? Translations.t("eqStateOn") : Translations.t("eqStateOff")) + " • PipeWire"
          color: EqualizerService.error !== "" ? Theme.error : Theme.subtext
          font.pixelSize: root.f(12)
          font.family: Theme.fontFamily
        }
      }

      SettingsSwitch {
        checked: root.on
        opacity: EqualizerService.busy ? 0.5 : 1
        onToggled: EqualizerService.toggleEnabled()
      }

      Rectangle {
        visible: root.closable
        Layout.preferredWidth: root.g(30)
        Layout.preferredHeight: root.g(30)
        radius: Theme.cozy ? 4 : width / 2
        color: cArea.containsMouse ? Theme.surfaceHigh : "transparent"
        Text {
          anchors.centerIn: parent
          text: "󰅖"
          color: Theme.subtext
          font.pixelSize: root.f(16)
          font.family: Theme.monoFamily
        }
        MouseArea {
          id: cArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.closeRequested()
        }
      }
    }
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: root.g(8)
    opacity: root.on ? 1 : 0.55
    Behavior on opacity { NumberAnimation { duration: Theme.animDuration(160) } }

    Repeater {
      model: EqualizerService.presets
      delegate: Rectangle {
        required property var modelData
        readonly property bool sel: EqualizerService.preset === modelData.id
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.preferredHeight: root.g(root.dense ? 26 : 36)
        radius: Theme.cozy ? 4 : height / 2
        color: sel ? Theme.primary : (pArea.containsMouse ? Theme.surfaceHigh : Theme.bg)
        border.width: sel ? 0 : Theme.bw1
        border.color: Theme.edge
        Behavior on color { ColorAnimation { duration: Theme.animDuration(130) } }
        Text {
          anchors.centerIn: parent
          width: parent.width - 8
          horizontalAlignment: Text.AlignHCenter
          elide: Text.ElideRight
          text: Translations.t(parent.modelData.key)
          color: parent.sel ? Theme.textOnPrimary : Theme.text
          font.bold: true
          font.pixelSize: root.f(12)
          font.family: Theme.fontFamily
        }
        MouseArea {
          id: pArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: EqualizerService.setPreset(parent.modelData.id)
        }
      }
    }
  }

  Card {
    Layout.fillWidth: true
    implicitHeight: plot.implicitHeight + root.g(root.dense ? 16 : 28)
    opacity: root.on ? 1 : 0.55
    Behavior on opacity { NumberAnimation { duration: Theme.animDuration(160) } }

    RowLayout {
      id: plot
      anchors { left: parent.left; right: parent.right; top: parent.top; margins: root.g(root.dense ? 8 : 14) }
      spacing: 0

      ColumnLayout {
        Layout.fillWidth: false
        Layout.preferredWidth: root.scaleW
        Layout.minimumWidth: root.scaleW
        Layout.maximumWidth: root.scaleW
        Layout.alignment: Qt.AlignTop
        spacing: 0
        Item {
          Layout.fillWidth: true
          Layout.preferredHeight: root.sliderH
          Repeater {
            model: [12, 6, 0, -6, -12]
            delegate: Text {
              required property int modelData
              y: root.yOf(modelData) - height / 2
              text: root.fmt(modelData)
              color: modelData === 0 ? Theme.text : Theme.subtext
              font.pixelSize: root.f(11)
              font.family: Theme.fontFamily
            }
          }
        }
        Text {
          Layout.topMargin: root.g(4)
          text: "dB"
          color: Theme.subtext
          font.pixelSize: root.f(11)
          font.family: Theme.fontFamily
        }
      }

      Item {
        Layout.fillWidth: true
        Layout.minimumWidth: root.g(160)
        Layout.preferredHeight: bandRow.height

        Repeater {
          model: [12, 6, 0, -6, -12]
          delegate: Rectangle {
            required property int modelData
            width: parent.width
            height: 1
            y: root.yOf(modelData)
            color: modelData === 0 ? Theme.subtext : Theme.divider
            opacity: modelData === 0 ? 0.5 : 0.6
          }
        }

        Canvas {
          id: curve
          anchors.fill: parent
          visible: !root.dense
          readonly property var gs: EqualizerService.gains
          readonly property color pc: Theme.primary
          onGsChanged: requestPaint()
          onPcChanged: requestPaint()
          onWidthChanged: requestPaint()
          onHeightChanged: requestPaint()
          onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            const n = gs.length
            if (n < 2 || width <= 0) return
            const cw = width / n
            const pts = []
            for (let i = 0; i < n; i++) pts.push({ x: (i + 0.5) * cw, y: root.yOf(gs[i]) })
            ctx.beginPath()
            ctx.moveTo(pts[0].x, pts[0].y)
            for (let i = 0; i < n - 1; i++) {
              const mx = (pts[i].x + pts[i + 1].x) / 2
              ctx.bezierCurveTo(mx, pts[i].y, mx, pts[i + 1].y, pts[i + 1].x, pts[i + 1].y)
            }
            ctx.strokeStyle = Qt.rgba(pc.r, pc.g, pc.b, 0.85)
            ctx.lineWidth = 2
            ctx.stroke()
            ctx.lineTo(pts[n - 1].x, root.yOf(0))
            ctx.lineTo(pts[0].x, root.yOf(0))
            ctx.closePath()
            ctx.fillStyle = Qt.rgba(pc.r, pc.g, pc.b, 0.12)
            ctx.fill()
          }
        }

        Item {
          id: bandRow
          anchors { left: parent.left; right: parent.right; top: parent.top }
          height: root.sliderH + root.g(8) + Math.ceil((root.f(11) + root.f(12)) * 1.5)

          Repeater {
            id: bands
            model: EqualizerService.freqLabels
            delegate: ColumnLayout {
              id: band
              required property int index
              required property string modelData
              x: band.index * (bandRow.width / EqualizerService.freqLabels.length)
              width: bandRow.width / EqualizerService.freqLabels.length
              spacing: root.g(4)
              readonly property real gain: EqualizerService.gains[band.index]

              Item {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: root.handleW + root.g(6)
                Layout.preferredHeight: root.sliderH

                Rectangle {
                  anchors.horizontalCenter: parent.horizontalCenter
                  width: root.trackW
                  height: parent.height
                  radius: width / 2
                  color: Theme.surfaceHigh
                  border.width: 1
                  border.color: Theme.divider
                }
                Rectangle {
                  anchors.horizontalCenter: parent.horizontalCenter
                  width: root.trackW
                  radius: width / 2
                  y: Math.min(root.yOf(band.gain), root.yOf(0))
                  height: Math.abs(root.yOf(band.gain) - root.yOf(0))
                  gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0; color: band.gain >= 0 ? Qt.lighter(Theme.primary, 1.25) : Theme.primary }
                    GradientStop { position: 1; color: band.gain >= 0 ? Theme.primary : Qt.lighter(Theme.primary, 1.25) }
                  }
                }
                Rectangle {
                  id: thumb
                  width: root.handleW
                  height: root.handle
                  radius: height / 2
                  anchors.horizontalCenter: parent.horizontalCenter
                  y: root.yOf(band.gain) - height / 2
                  color: bArea.pressed || bArea.containsMouse ? Qt.lighter(Theme.primary, 1.12) : Theme.primary
                  border.width: 3
                  border.color: Theme.bg
                  scale: bArea.pressed ? 1.08 : 1
                  Behavior on scale { NumberAnimation { duration: Theme.animDuration(100) } }
                  Behavior on color { ColorAnimation { duration: Theme.animDuration(100) } }
                  Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 0.4
                    height: 2
                    radius: 1
                    color: Theme.textOnPrimary
                    opacity: 0.55
                  }
                }
                Rectangle {
                  visible: bArea.pressed
                  anchors.horizontalCenter: parent.horizontalCenter
                  y: Math.max(0, thumb.y - height - root.g(6))
                  width: bubbleText.implicitWidth + root.g(14)
                  height: bubbleText.implicitHeight + root.g(8)
                  radius: Theme.cozy ? 4 : root.g(8)
                  color: Theme.text
                  Text {
                    id: bubbleText
                    anchors.centerIn: parent
                    text: root.fmt(band.gain) + " dB"
                    color: Theme.bg
                    font.bold: true
                    font.pixelSize: root.f(11)
                    font.family: Theme.fontFamily
                  }
                }
                MouseArea {
                  id: bArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  function setFrom(my) {
                    const hh = root.handle / 2
                    const fr = Math.max(0, Math.min(1, (my - hh) / Math.max(1, parent.height - root.handle)))
                    EqualizerService.setGain(band.index, 12 - fr * 24)
                  }
                  onPressed: mouse => setFrom(mouse.y)
                  onPositionChanged: mouse => { if (pressed) setFrom(mouse.y) }
                  onDoubleClicked: EqualizerService.setGain(band.index, 0)
                  onWheel: wheel => EqualizerService.setGain(band.index, band.gain + (wheel.angleDelta.y > 0 ? 0.5 : -0.5))
                }
              }

              Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.fmt(band.gain)
                color: band.gain === 0 ? Theme.subtext : Theme.primary
                font.bold: band.gain !== 0
                font.pixelSize: root.f(11)
                font.family: Theme.fontFamily
              }
              Text {
                Layout.alignment: Qt.AlignHCenter
                text: band.modelData
                color: Theme.text
                font.pixelSize: root.f(12)
                font.family: Theme.fontFamily
              }
            }
          }
        }
      }

      Text {
        Layout.alignment: Qt.AlignBottom
        Layout.leftMargin: root.g(6)
        text: "Hz"
        color: Theme.subtext
        font.pixelSize: root.f(11)
        font.family: Theme.fontFamily
      }
    }
  }

  Card {
    Layout.fillWidth: true
    implicitHeight: root.g(root.dense ? 56 : 84)
    opacity: root.on ? 1 : 0.55
    Behavior on opacity { NumberAnimation { duration: Theme.animDuration(160) } }

    RowLayout {
      anchors { fill: parent; margins: root.g(root.dense ? 8 : 14) }
      spacing: root.g(14)

      ColumnLayout {
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        spacing: 0
        RowLayout {
          Layout.fillWidth: true
          Text {
            Layout.fillWidth: true
            text: Translations.t("eqPreamp")
            color: Theme.text
            font.pixelSize: root.f(12)
            font.family: Theme.fontFamily
          }
          Text {
            text: root.fmt(EqualizerService.preamp) + " dB"
            color: Theme.subtext
            font.pixelSize: root.f(12)
            font.family: Theme.fontFamily
          }
        }
        HSlider {
          Layout.fillWidth: true
          from: -12
          to: 12
          value: EqualizerService.preamp
          onMoved: v => EqualizerService.setPreamp(v)
        }
      }

      Rectangle {
        Layout.preferredWidth: 1
        Layout.fillHeight: true
        Layout.topMargin: root.g(4)
        Layout.bottomMargin: root.g(4)
        color: Theme.divider
      }

      ColumnLayout {
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        spacing: 0
        RowLayout {
          Layout.fillWidth: true
          Text {
            text: "L"
            color: Theme.subtext
            font.pixelSize: root.f(12)
            font.family: Theme.fontFamily
          }
          Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: Translations.t("eqBalance")
            color: Theme.text
            font.pixelSize: root.f(12)
            font.family: Theme.fontFamily
          }
          Text {
            text: "R"
            color: Theme.subtext
            font.pixelSize: root.f(12)
            font.family: Theme.fontFamily
          }
        }
        HSlider {
          Layout.fillWidth: true
          from: -1
          to: 1
          value: EqualizerService.balance
          onMoved: v => EqualizerService.setBalance(v)
        }
      }

      Rectangle {
        Layout.preferredWidth: resetRow.implicitWidth + root.g(24)
        Layout.preferredHeight: root.g(root.dense ? 28 : 36)
        radius: Theme.cozy ? 4 : height / 2
        color: rArea.containsMouse ? Theme.surfaceHigh : "transparent"
        border.width: Theme.bw1
        border.color: Theme.edge
        RowLayout {
          id: resetRow
          anchors.centerIn: parent
          spacing: root.g(6)
          Text {
            text: "󰜉"
            color: Theme.primary
            font.pixelSize: root.f(15)
            font.family: Theme.monoFamily
          }
          Text {
            text: Translations.t("eqReset")
            color: Theme.primary
            font.bold: true
            font.pixelSize: root.f(12)
            font.family: Theme.fontFamily
          }
        }
        MouseArea {
          id: rArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: EqualizerService.reset()
        }
      }
    }
  }

  Card {
    visible: !root.dense
    Layout.fillWidth: true
    implicitHeight: extra.implicitHeight + root.g(28)
    opacity: root.on ? 1 : 0.55
    Behavior on opacity { NumberAnimation { duration: Theme.animDuration(160) } }

    ColumnLayout {
      id: extra
      anchors { left: parent.left; right: parent.right; top: parent.top; margins: root.g(14) }
      spacing: root.g(12)

      RowLayout {
        Layout.fillWidth: true
        spacing: root.g(18)

        Repeater {
          model: [
            { key: "eqBass",   icon: "󰝚", get: () => EqualizerService.bass,   set: v => EqualizerService.setBass(v) },
            { key: "eqTreble", icon: "󰎈", get: () => EqualizerService.treble, set: v => EqualizerService.setTreble(v) }
          ]
          delegate: ColumnLayout {
            id: tone
            required property var modelData
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            spacing: 0
            RowLayout {
              Layout.fillWidth: true
              Text {
                Layout.fillWidth: true
                text: Translations.t(tone.modelData.key)
                color: Theme.text
                font.pixelSize: root.f(12)
                font.family: Theme.fontFamily
              }
              Text {
                text: root.fmt(tone.modelData.get()) + " dB"
                color: Theme.subtext
                font.pixelSize: root.f(12)
                font.family: Theme.fontFamily
              }
            }
            HSlider {
              Layout.fillWidth: true
              from: -12
              to: 12
              value: tone.modelData.get()
              onMoved: v => tone.modelData.set(v)
            }
          }
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: root.g(10)

        Text {
          Layout.fillWidth: true
          text: Translations.t("eqBandwidth")
          color: Theme.text
          font.pixelSize: root.f(12)
          font.family: Theme.fontFamily
        }
        Repeater {
          model: EqualizerService.bandwidths
          delegate: Rectangle {
            required property var modelData
            readonly property bool sel: EqualizerService.bandwidth === modelData.id
            Layout.preferredWidth: bwLabel.implicitWidth + root.g(26)
            Layout.preferredHeight: root.g(30)
            radius: Theme.cozy ? 4 : height / 2
            color: sel ? Theme.primary : (bwArea.containsMouse ? Theme.surfaceHigh : Theme.surface)
            border.width: sel ? 0 : Theme.bw1
            border.color: Theme.edge
            Text {
              id: bwLabel
              anchors.centerIn: parent
              text: Translations.t(parent.modelData.key)
              color: parent.sel ? Theme.textOnPrimary : Theme.text
              font.bold: true
              font.pixelSize: root.f(12)
              font.family: Theme.fontFamily
            }
            MouseArea {
              id: bwArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: EqualizerService.setBandwidth(parent.modelData.id)
            }
          }
        }
      }

      Rectangle {
        Layout.fillWidth: true
        height: 1
        color: Theme.divider
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: root.g(12)
        ColumnLayout {
          Layout.fillWidth: true
          spacing: 0
          Text {
            text: Translations.t("eqAutoPreamp")
            color: Theme.text
            font.pixelSize: root.f(12)
            font.family: Theme.fontFamily
          }
          Text {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: Translations.t("eqAutoPreampHint") + (EqualizerService.autoCut > 0 ? "  (−" + EqualizerService.autoCut.toFixed(1) + " dB)" : "")
            color: Theme.subtext
            font.pixelSize: root.f(11)
            font.family: Theme.fontFamily
          }
        }
        SettingsSwitch {
          checked: EqualizerService.autoPreamp
          onToggled: EqualizerService.setAutoPreamp(!EqualizerService.autoPreamp)
        }
      }
    }
  }
}
