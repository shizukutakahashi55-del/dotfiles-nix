// LockContent

import QtQuick
import QtQuick.Layouts
import "../../COMMON"
import "../../Services/Lang"
import "../../Services/Battery"

Item {
  id: root

  property real unit: 1
  property date now: new Date()
  property string password: ""
  property bool checking: false
  property bool failed: false
  property string failText: ""
  property int failCount: 0
  property bool capsOn: false
  property color capsColor: Theme.primary
  property int capsPulse: 0
  signal submit()

  // ── Distribución ──
  readonly property var plan: LockLayouts.spec(LockConfig.layout)
  readonly property bool joined: root.plan.joined
  readonly property int edge: Math.round(44 * root.unit)
  readonly property int strip: Math.round(48 * root.unit)
  readonly property int clockAlign: LockLayouts.align(root.plan.clock.h)
  readonly property int authAlign: LockLayouts.align(root.plan.auth.h)
  readonly property int groupTop: Math.round((root.height - clockBlock.height - authBlock.height) / 2 - 30 * root.unit)

  function px(h, w) {
    return h === "left" ? root.edge : h === "right" ? root.width - w - root.edge : Math.round((root.width - w) / 2)
  }

  // ── Widgets ──
  readonly property string placement: LockConfig.widgetsPlacement === "auto" ? root.plan.widgets : LockConfig.widgetsPlacement
  readonly property bool wantsSide: root.placement === "left" || root.placement === "right"
  readonly property real maxScale: Math.max(LockConfig.weatherScale, LockConfig.mediaScale, LockConfig.notifScale) / 100
  readonly property bool dashStyle: LockConfig.widgetsStyle === "dashboard"
  readonly property real sideScale: root.dashStyle ? LockConfig.dashScale / 100 : root.maxScale
  readonly property bool sideMode: root.wantsSide
    && root.width >= (960 + LockConfig.sideWidth * Math.max(1, root.sideScale)) * root.unit
  readonly property bool dashMode: root.sideMode && root.dashStyle
  readonly property bool atTop: root.placement === "top"

  // ── Zona libre del panel lateral ──
  readonly property int gap: Math.round(24 * root.unit)
  readonly property int sideTop: {
    let t = root.edge
    if (!root.joined && root.plan.clock.h === root.placement)
      t = Math.max(t, clockBlock.y + clockBlock.height + root.gap)
    if (powerRow.visible && root.plan.power.v === "top" && root.plan.power.h === root.placement)
      t = Math.max(t, powerRow.y + powerRow.height + root.gap)
    return t
  }
  readonly property int sideBottom: {
    let b = root.height - root.edge
    const stripBusy = (statusRow.visible && root.plan.status.h === root.placement)
                   || (powerRow.visible && root.plan.power.v === "bottom" && root.plan.power.h === root.placement)
    if (stripBusy) b -= root.strip
    if (!root.joined && root.plan.auth.v === "bottom" && root.plan.auth.h === root.placement)
      b = Math.min(b, authBlock.y - root.gap)
    return b
  }

  // ── Entrada ──
  opacity: 0
  transform: Translate { id: rise; y: Math.round(14 * root.unit) }
  Component.onCompleted: enterAnim.start()

  ParallelAnimation {
    id: enterAnim
    NumberAnimation { target: root; property: "opacity"; to: 1
      duration: Theme.animDuration(280); easing.type: Easing.OutCubic }
    NumberAnimation { target: rise; property: "y"; to: 0
      duration: Theme.animDuration(460); easing.type: Easing.OutCubic }
  }

  // ── Bloque del reloj ──
  Item {
    id: clockBlock
    width: clockCol.implicitWidth
    height: clockCol.implicitHeight
    x: root.px(root.plan.clock.h, width)
    y: root.joined ? root.groupTop : root.edge

    ColumnLayout {
      id: clockCol
      spacing: 0

      LockClock {
        Layout.alignment: root.clockAlign
        unit: root.unit
        now: root.now
        use24h: LockConfig.clock24h
        clockStyle: LockConfig.clockStyle
        scalePct: LockConfig.clockScale
      }

      Text {
        readonly property var parts: [
          LockConfig.clock24h ? "" : Qt.formatTime(root.now, "AP"),
          LockConfig.showDate ? Qt.formatDate(root.now, "dddd  •  d MMM") : ""
        ].filter(x => x !== "")
        visible: parts.length > 0
        Layout.alignment: root.clockAlign
        Layout.topMargin: LockConfig.clockStyle === "analog" || LockConfig.clockStyle === "boxed"
                          ? Math.round(20 * root.unit) : -Math.round(4 * root.unit)
        text: parts.join("  •  ")
        color: Theme.subtext
        font.pixelSize: Math.round(16 * root.unit)
        font.letterSpacing: Math.round(4 * root.unit)
        font.capitalization: Font.AllUppercase
        font.family: Theme.fontFamily
      }
    }
  }

  // ── Bloque de acceso ──
  Item {
    id: authBlock
    width: authCol.implicitWidth
    height: authCol.implicitHeight
    x: root.px(root.plan.auth.h, width)
    y: root.joined ? root.groupTop + clockBlock.height
     : root.plan.auth.v === "bottom" ? root.height - root.edge - root.strip - height
     : Math.round((root.height - height) / 2)

    ColumnLayout {
      id: authCol
      spacing: 0

      // ── Identidad ──
      ColumnLayout {
        Layout.alignment: root.authAlign
        visible: LockConfig.showAvatar
        spacing: 0

        Item {
          Layout.alignment: root.authAlign
          Layout.topMargin: root.joined ? Math.round(38 * root.unit) : 0
          width: Math.round(104 * root.unit)
          height: width

          Rectangle {
            anchors.centerIn: parent
            width: parent.width + Math.round(16 * root.unit)
            height: width
            radius: Theme.cozy ? 6 : width / 2
            visible: !Theme.cozy && !Theme.shellPerf
            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.14)
            opacity: root.failed ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: Theme.animDuration(200) } }
          }
          Rectangle {
            anchors.fill: parent
            radius: Theme.cozy ? 6 : width / 2
            color: "transparent"
            border.width: Math.max(2, Math.round(3 * root.unit))
            border.color: root.failed ? Theme.error : Theme.primary
            Behavior on border.color { ColorAnimation { duration: Theme.animDuration(150) } }
          }
          Avatar {
            anchors.centerIn: parent
            size: Math.round(92 * root.unit)
            source: UserProfile.avatarUrl
            letter: (UserProfile.shownName || "?").charAt(0).toUpperCase()
          }
        }

        Text {
          Layout.alignment: root.authAlign
          Layout.topMargin: Math.round(18 * root.unit)
          text: Translations.t("lockWelcome")
          color: Theme.subtext
          font.pixelSize: Math.round(13 * root.unit)
          font.letterSpacing: Math.round(1.6 * root.unit)
          font.family: Theme.fontFamily
        }
        Text {
          Layout.alignment: root.authAlign
          Layout.topMargin: Math.round(3 * root.unit)
          text: UserProfile.shownName
          color: Theme.text
          font.pixelSize: Math.round(28 * root.unit)
          font.bold: true
          font.family: Theme.fontFamily
        }
      }

      // ── Campo ──
      LockField {
        Layout.alignment: root.authAlign
        Layout.topMargin: Math.round(26 * root.unit)
        unit: root.unit
        password: root.password
        checking: root.checking
        failed: root.failed
        capsOn: root.capsOn
        capsColor: root.capsColor
        failCount: root.failCount
        placeholder: Translations.t("lockPlaceholder")
        checkingText: Translations.t("lockChecking")
        onSubmit: root.submit()
      }

      // ── Avisos ──
      LockChip {
        Layout.alignment: root.authAlign
        unit: root.unit
        shown: root.failed
        text: root.failText
        icon: "󰀦"
        tone: Theme.error
      }
      LockChip {
        Layout.alignment: root.authAlign
        unit: root.unit
        shown: root.capsOn
        text: Translations.t("lockCapsOn")
        icon: "⇪"
        tone: root.capsColor
        pulse: root.capsPulse
      }
    }
  }

  // ── Widgets ──
  GridLayout {
    id: widgets
    readonly property bool side: root.sideMode
    readonly property int sideWidth: Math.round(LockConfig.sideWidth * root.unit)

    opacity: 0
    transform: Translate { id: widgetsRise; y: Math.round(18 * root.unit) }
    Component.onCompleted: widgetsIn.start()
    ParallelAnimation {
      id: widgetsIn
      PauseAnimation { duration: Theme.animDuration(140) }
      NumberAnimation { target: widgets; property: "opacity"; to: 1
        duration: Theme.animDuration(300); easing.type: Easing.OutCubic }
      NumberAnimation { target: widgetsRise; property: "y"; to: 0
        duration: Theme.animDuration(440); easing.type: Easing.OutCubic }
    }

    columns: widgets.side ? 1 : (root.width < 1100 * root.unit ? 1 : (root.width < 1700 * root.unit ? 2 : 3))
    columnSpacing: Math.round(18 * root.unit)
    rowSpacing: Math.round(14 * root.unit)
    visible: !root.dashMode && (weatherCard.opacity > 0 || mediaCard.opacity > 0 || notifCard.opacity > 0)
    x: widgets.side
       ? (root.placement === "left" ? root.edge : parent.width - width - root.edge)
       : Math.round((parent.width - width) / 2)
    y: widgets.side
       ? Math.round((root.sideTop + root.sideBottom - height) / 2)
       : (root.atTop
          ? root.edge
          : parent.height - height - root.edge
            - (statusRow.visible ? statusRow.height + Math.round(24 * root.unit) : 0))

    LockWeather {
      id: weatherCard
      Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
      unit: root.unit * LockConfig.weatherScale / 100
      active: LockConfig.weatherEnabled && !root.dashMode
      city: LockConfig.city
      fahrenheit: LockConfig.weatherFahrenheit
      forecast: LockConfig.weatherForecast
      look: LockConfig.weatherStyle
      days: LockConfig.weatherDays
      tintOn: LockConfig.weatherTint
      vertical: widgets.side
      cardWidth: widgets.side ? Math.round(widgets.sideWidth * LockConfig.weatherScale / 100) : 0
    }

    LockMedia {
      id: mediaCard
      Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
      unit: root.unit * LockConfig.mediaScale / 100
      active: LockConfig.mediaEnabled && !root.dashMode
      showCover: LockConfig.mediaCover
      onlyPlaying: LockConfig.mediaOnlyPlaying
      look: LockConfig.mediaStyle
      visualizer: LockConfig.mediaVisualizer && !root.dashMode
      cardWidth: Math.round((widgets.side ? widgets.sideWidth : 420 * root.unit) * LockConfig.mediaScale / 100)
    }

    LockNotifs {
      id: notifCard
      Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
      unit: root.unit * LockConfig.notifScale / 100
      active: LockConfig.notifMode !== "off" && !root.dashMode
      mode: LockConfig.notifMode
      maxItems: LockConfig.notifMax
      cardWidth: Math.round((widgets.side ? widgets.sideWidth : 340 * root.unit) * LockConfig.notifScale / 100)
    }
  }

  // ── Dashboard ──
  LockDashboard {
    id: dashboard
    active: root.dashMode

    unit: root.unit * LockConfig.dashScale / 100
    panelWidth: Math.round(LockConfig.sideWidth * root.unit * LockConfig.dashScale / 100)
    maxHeight: root.sideBottom - root.sideTop
    transformOrigin: root.placement === "left" ? Item.Left : Item.Right
    x: root.placement === "left" ? root.edge : root.width - width - root.edge
    y: Math.round((root.sideTop + root.sideBottom) / 2 - height / 2)

    weatherOn: LockConfig.weatherEnabled && root.dashMode
    city: LockConfig.city
    fahrenheit: LockConfig.weatherFahrenheit
    forecast: LockConfig.weatherForecast
    days: LockConfig.weatherDays
    tintOn: LockConfig.weatherTint

    mediaOn: LockConfig.mediaEnabled && root.dashMode
    showCover: LockConfig.mediaCover
    onlyPlaying: LockConfig.mediaOnlyPlaying
    visualizer: LockConfig.mediaVisualizer

    notifMode: root.dashMode ? LockConfig.notifMode : "off"
    notifMax: LockConfig.notifMax
  }

  // ── Energía ──
  LockPower {
    id: powerRow
    visible: LockConfig.showPower
    unit: root.unit
    x: root.px(root.plan.power.h, width)
    y: root.plan.power.v === "top" ? root.edge : root.height - root.edge - height
  }

  // ── Estado ──
  Row {
    id: statusRow
    readonly property bool hasLayout: LockConfig.showLayout && KeyboardLayout.layoutName !== ""
    readonly property bool hasBattery: LockConfig.showBattery && BatteryBackend.available

    opacity: 0
    transform: Translate { id: statusRise; y: Math.round(12 * root.unit) }
    Component.onCompleted: statusIn.start()
    ParallelAnimation {
      id: statusIn
      PauseAnimation { duration: Theme.animDuration(240) }
      NumberAnimation { target: statusRow; property: "opacity"; to: 1
        duration: Theme.animDuration(320); easing.type: Easing.OutCubic }
      NumberAnimation { target: statusRise; property: "y"; to: 0
        duration: Theme.animDuration(460); easing.type: Easing.OutCubic }
    }

    x: root.px(root.plan.status.h, width)
    y: root.height - root.edge - height
    spacing: Math.round(22 * root.unit)
    visible: statusRow.hasLayout || statusRow.hasBattery

    Row {
      visible: statusRow.hasLayout
      spacing: Math.round(8 * root.unit)

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "󰌌"
        color: Theme.subtext
        font.pixelSize: Math.round(18 * root.unit)
        font.family: Theme.fontFamily
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: KeyboardLayout.label
        color: Theme.subtext
        font.pixelSize: Math.round(14 * root.unit)
        font.bold: true
        font.family: Theme.fontFamily
      }
    }

    Row {
      visible: statusRow.hasBattery
      spacing: Math.round(8 * root.unit)

      BatteryIcon {
        anchors.verticalCenter: parent.verticalCenter
        percentage: BatteryBackend.percentage
        charging: BatteryBackend.charging
        full: BatteryBackend.fullyCharged
        low: BatteryBackend.isLow
        iconHeight: Math.max(12, Math.round(16 * root.unit))
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: Math.round(BatteryBackend.percentage * 100) + "%"
        color: BatteryBackend.isLow ? Theme.error : Theme.subtext
        font.pixelSize: Math.round(14 * root.unit)
        font.bold: true
        font.family: Theme.fontFamily
      }
    }
  }
}
