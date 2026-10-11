// Menu.qml — MENU

import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../COMMON"
import "../NETWORK"
import "../BLUETOOTH"
import "../LANG"
import "../POWER"
import "../BRIGHTNESS"
import "../CAFFEINE"
import "../NOTIFY"

Item {
  id: menuRoot

  property bool open: false
  property string targetScreen: ""
  property int edgeMargin: 10
  property int cardWidth: 420
  readonly property int pad: 18
  property string startTab: "general"
  property string currentTab: "general"

  signal tabChanged(string tab)
  signal closeRequested()
  signal requestAppearance()
  signal requestWalls()
  signal requestNetwork()
  signal requestBluetooth()
  signal requestSettings()
  signal requestCornersToggle()

  property bool screenCorners: true
  readonly property bool framed: screenCorners && !Theme.barSeparated && !Theme.glassMode

  readonly property var tabs: [
    { id: "general", icon: OozeIcons.performance },
    { id: "accesos", icon: OozeIcons.settings },
    { id: "notifs",  icon: OozeIcons.bell }
  ]

  function tabTitle(id) {
    if (id === "accesos") return Translations.t("menuSectionQuick")
    if (id === "notifs") return Translations.t("notifTitle")
    return Translations.t("menuSectionSystem")
  }

  function showTab(name) {
    menuRoot.currentTab = name
  }

  function openNotifs() {
    menuRoot.showTab("notifs")
  }

  function isActive(action) {
    if (action === "caffeine") return CaffeineBackend.active
    if (action === "performance") return Theme.performanceMode
    return false
  }

  function subtitleFor(action) {
    if (action === "network") return NetworkBackend.summary
    if (action === "bluetooth") return BluetoothBackend.summary
    if (action === "caffeine") return Translations.t(CaffeineBackend.active ? "caffeineOn" : "caffeineOff")
    if (action === "performance") return Translations.t(Theme.performanceMode ? "perfToastOn" : "perfToastOff")
    return ""
  }

  onStartTabChanged: {
    if (menuRoot.open) menuRoot.currentTab = menuRoot.startTab
  }

  onCurrentTabChanged: {
    menuRoot.tabChanged(menuRoot.currentTab)
    NotificationsBackend.centerOpen = menuRoot.open && menuRoot.currentTab === "notifs"
  }

  onOpenChanged: {
    NetworkBackend.menuWatch = menuRoot.open
    if (menuRoot.open) BrightnessBackend.acquireWatch(); else BrightnessBackend.releaseWatch()
    if (menuRoot.open) KeyboardLayout.refresh()
    PowerProfile.setWanted("menu", menuRoot.open)
    if (menuRoot.open) menuRoot.currentTab = menuRoot.startTab
    NotificationsBackend.centerOpen = menuRoot.open && menuRoot.currentTab === "notifs"
  }

  property string userName: ""
  readonly property string displayUserName: UserProfile.displayName.trim() !== ""
    ? UserProfile.displayName.trim() : menuRoot.userName
  property string osName: ""
  Process {
    id: whoamiProc
    command: ["whoami"]
    running: menuRoot.open && menuRoot.userName === ""
    stdout: SplitParser { onRead: line => menuRoot.userName = line.trim() }
  }
  Process {
    id: osProc
    command: ["bash", "-c",
      ". /etc/os-release 2>/dev/null || . /usr/lib/os-release 2>/dev/null; echo \"${PRETTY_NAME:-${NAME:-Linux}}\""]
    running: menuRoot.open && menuRoot.osName === ""
    stdout: SplitParser { onRead: line => menuRoot.osName = line.trim() }
  }

  SystemStats {
    id: stats
    active: menuRoot.open
  }

  AudioControl {
    id: audio
    active: menuRoot.open
  }

  function setPowerProfile(p) { PowerProfile.set(p) }

  readonly property real maxListHeight: Math.max(160, (fw.screenHeight - (Theme.barVertical ? 0 : Theme.barFace)) / Theme.windowScale - 420)
  readonly property var notifRows: menuRoot.open && menuRoot.currentTab === "notifs"
    ? NotificationsBackend.displayOrdered.slice(0, 60) : []
  property real listH: 0
  Behavior on listH { NumberAnimation { duration: Theme.animDuration(180); easing.type: Easing.OutCubic } }
  readonly property real listTarget: Math.min(notifCol.height, menuRoot.maxListHeight)
  onListTargetChanged: menuRoot.listH = menuRoot.listTarget

  component SectionTitle: Text {
    Layout.fillWidth: true
    Layout.topMargin: 2
    color: Theme.subtext
    font.bold: true
    font.pixelSize: Theme.fs(10)
    font.family: Theme.fontFamily
    font.letterSpacing: 0.5
  }

  FusedWindow {
    id: fw
    active: menuRoot.open || panel.shown
    targetScreen: menuRoot.targetScreen
    namespace: "oozeshell-menu"
    onCloseRequested: menuRoot.closeRequested()

    FusedPanel {
      id: panel

      open: menuRoot.open
      panelWidth: menuRoot.cardWidth
      contentHeight: col.implicitHeight + menuRoot.pad * 2

      align: "end"
      alignMargin: menuRoot.edgeMargin + Theme.barEdge + Theme.frameSideArm

      ColumnLayout {
        id: col
        x: menuRoot.pad
        y: menuRoot.pad
        width: parent.width - menuRoot.pad * 2
        spacing: 14

        SkinRect {
          Layout.fillWidth: true
          Layout.preferredHeight: 74
          radius: Theme.cardRadius
          color: Theme.surface
          border.width: Theme.bw1
          border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.14)

          RowLayout {
            anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
            spacing: 12

            Avatar {
              Layout.preferredWidth: 46
              Layout.preferredHeight: 46
              size: 46
              source: UserProfile.avatarUrl
              letter: menuRoot.displayUserName.length > 0 ? menuRoot.displayUserName.charAt(0).toUpperCase() : "?"
            }

            ColumnLayout {
              Layout.fillWidth: true
              Layout.minimumWidth: 0
              spacing: 2
              Text {
                Layout.fillWidth: true
                text: menuRoot.displayUserName.length > 0 ? menuRoot.displayUserName : "..."
                color: Theme.text
                font.pixelSize: Theme.fs(15)
                font.bold: true
                font.family: Theme.fontFamily
                elide: Text.ElideRight
              }
              Text {
                Layout.fillWidth: true
                text: OozeIcons.nixos + "  " + (menuRoot.osName.length > 0 ? menuRoot.osName : "Linux")
                color: Theme.subtext
                font.pixelSize: Theme.fs(11)
                font.family: Theme.monoFamily
                elide: Text.ElideRight
              }
            }

            SkinRect {
              Layout.preferredHeight: 34
              Layout.preferredWidth: cornersRow.implicitWidth + 24
              radius: 10
              opacity: Theme.barSeparated ? 0.4 : 1.0
              color: menuRoot.framed ? Theme.primary : Theme.surface
              Behavior on color { ColorAnimation { duration: Theme.animDuration(200) } }

              scale: Theme.cozy ? 1.0 : ((cornersArea.pressed && !Theme.barSeparated) ? 0.92 : 1.0)
              Behavior on scale { NumberAnimation { duration: Theme.animDuration(140); easing.type: Easing.OutBack } }

              RowLayout {
                id: cornersRow
                anchors.centerIn: parent
                spacing: 6
                Text {
                  text: menuRoot.framed ? "▣" : "▢"
                  color: menuRoot.framed ? Theme.textOnPrimary : Theme.text
                  font.pixelSize: Theme.fs(15)
                  font.family: Theme.fontFamily
                }
                Text {
                  text: Translations.t("screenFrame")
                  color: menuRoot.framed ? Theme.textOnPrimary : Theme.text
                  font.pixelSize: Theme.fs(11)
                  font.family: Theme.fontFamily
                }
                Rectangle {
                  Layout.preferredWidth: 22
                  Layout.preferredHeight: 13
                  radius: Theme.cozy ? 2 : 6.5
                  antialiasing: !Theme.cozy
                  color: menuRoot.framed
                    ? Qt.rgba(Theme.textOnPrimary.r, Theme.textOnPrimary.g, Theme.textOnPrimary.b, 0.35)
                    : Theme.surfaceHigh
                  Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }

                  Rectangle {
                    width: 9
                    height: 9
                    radius: Theme.cozy ? 1 : 4.5
                    antialiasing: !Theme.cozy
                    anchors.verticalCenter: parent.verticalCenter
                    x: menuRoot.framed ? 11 : 2
                    color: menuRoot.framed ? Theme.textOnPrimary : Theme.subtext
                    Behavior on x { NumberAnimation { duration: Theme.animDuration(150); easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
                  }
                }
              }
              MouseArea {
                id: cornersArea
                anchors.fill: parent
                cursorShape: Theme.barSeparated ? Qt.ArrowCursor : Qt.PointingHandCursor
                onClicked: { if (!Theme.barSeparated) menuRoot.requestCornersToggle() }
              }
            }

            SkinRect {
              Layout.preferredWidth: 34
              Layout.preferredHeight: 34
              radius: 10
              color: gearArea.containsMouse ? Theme.surfaceHigh : Theme.surface
              Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }

              scale: Theme.cozy ? 1.0 : (gearArea.pressed ? 0.92 : 1.0)
              Behavior on scale { NumberAnimation { duration: Theme.animDuration(140); easing.type: Easing.OutBack } }

              Text {
                anchors.centerIn: parent
                text: OozeIcons.settings
                color: gearArea.containsMouse ? Theme.primary : Theme.text
                font.pixelSize: Theme.fs(17)
                font.family: Theme.monoFamily
                rotation: gearArea.containsMouse ? 60 : 0
                Behavior on rotation { NumberAnimation { duration: Theme.animDuration(320); easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
              }
              MouseArea {
                id: gearArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  menuRoot.requestSettings()
                  menuRoot.closeRequested()
                }
              }
            }
          }
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: 8

          Text {
            Layout.fillWidth: true
            text: menuRoot.tabTitle(menuRoot.currentTab)
            color: Theme.text
            font.pixelSize: Theme.fs(13)
            font.bold: true
            font.family: Theme.fontFamily
            elide: Text.ElideRight
          }

          Repeater {
            model: menuRoot.tabs
            delegate: Rectangle {
              id: tabBtn
              required property var modelData
              readonly property bool active: menuRoot.currentTab === tabBtn.modelData.id
              property real pillW: active ? 56 : 44
              Behavior on pillW { NumberAnimation { duration: Theme.animDuration(160); easing.type: Easing.OutCubic } }
              Layout.preferredWidth: pillW
              Layout.preferredHeight: 34
              radius: active ? 17 : 10
              Behavior on radius { NumberAnimation { duration: Theme.animDuration(160) } }
              color: active ? Theme.primary : (tabHover.hovered ? Theme.surfaceHigh : Theme.surface)
              Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }

              Text {
                anchors.centerIn: parent
                text: tabBtn.modelData.icon
                color: active ? Theme.textOnPrimary : Theme.text
                font.pixelSize: Theme.fs(16)
                font.family: Theme.monoFamily
                Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
              }

              HoverHandler {
                id: tabHover
                cursorShape: Qt.PointingHandCursor
              }
              TapHandler {
                onTapped: menuRoot.showTab(tabBtn.modelData.id)
              }
            }
          }
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }

        ColumnLayout {
          visible: menuRoot.currentTab === "general"
          Layout.fillWidth: true
          spacing: 14

          SectionTitle { text: Translations.t("menuSectionSystem") }
          RowLayout {
            Layout.fillWidth: true
            spacing: 10

            MetricCard {
              Layout.fillWidth: true
              Layout.preferredWidth: 1
              icon: OozeIcons.cpu
              label: "CPU"
              value: stats.cpu
              history: stats.cpuHistory
              maxSamples: stats.maxSamples
            }

            MetricCard {
              Layout.fillWidth: true
              Layout.preferredWidth: 1
              icon: OozeIcons.memory
              label: "RAM"
              value: stats.ram
              detail: stats.ramTotalGb > 0 ? stats.ramUsedGb.toFixed(1) + "G" : ""
              history: stats.ramHistory
              maxSamples: stats.maxSamples
            }

            MetricCard {
              Layout.fillWidth: true
              Layout.preferredWidth: 1
              icon: OozeIcons.gpu
              label: "GPU"
              value: stats.gpu
              history: stats.gpuHistory
              maxSamples: stats.maxSamples
            }
          }

          SkinRect {
            Layout.fillWidth: true
            Layout.preferredHeight: 50
            radius: Theme.cardRadius
            color: Theme.surface

            RowLayout {
              anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
              spacing: 12

              Item {
                Layout.preferredWidth: 26
                Layout.preferredHeight: 26

                Text {
                  anchors.centerIn: parent
                  text: audio.icon
                  color: audio.muted ? Theme.subtext : Theme.primary
                  font.pixelSize: Theme.fs(20)
                  font.family: Theme.monoFamily
                  Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
                }

                MouseArea {
                  anchors.fill: parent
                  anchors.margins: -4
                  cursorShape: Qt.PointingHandCursor
                  onClicked: audio.toggleMute()
                }
              }

              Item {
                id: volSlider
                Layout.fillWidth: true
                Layout.preferredHeight: 30

                readonly property bool grabbed: volArea.containsMouse || volArea.pressed

                PixelBar {
                  visible: Theme.cozy
                  anchors.verticalCenter: parent.verticalCenter
                  width: parent.width
                  height: 16
                  ratio: audio.volume
                  colorA: Theme.mix((audio.muted ? Theme.subtext : Theme.primary), Theme.bg, 0.40)
                  colorB: (audio.muted ? Theme.subtext : Theme.primary)
                }

                Rectangle {
                  id: volTrack
                  visible: !Theme.cozy
                  anchors.verticalCenter: parent.verticalCenter
                  width: parent.width
                  height: volSlider.grabbed ? 8 : 6
                  radius: height / 2
                  color: Theme.surfaceHigh
                  Behavior on height { NumberAnimation { duration: Theme.animDuration(100) } }

                  Rectangle {
                    width: volTrack.width * audio.volume
                    height: parent.height
                    radius: parent.radius
                    color: audio.muted ? Theme.subtext : Theme.primary
                    Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
                  }

                  Rectangle {
                    x: volTrack.width * audio.volume - width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: volSlider.grabbed ? 14 : 0
                    height: width
                    radius: width / 2
                    color: Theme.text
                    Behavior on width { NumberAnimation { duration: Theme.animDuration(100) } }
                  }
                }

                MouseArea {
                  id: volArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor

                  function setFrom(mx) {
                    audio.setVolume(mx / width)
                  }

                  onPressed: mouse => { audio.dragging = true; setFrom(mouse.x) }
                  onPositionChanged: mouse => { if (pressed) setFrom(mouse.x) }
                  onReleased: { audio.dragging = false; audio.commit() }
                  onCanceled: { audio.dragging = false; audio.commit() }
                  onWheel: wheel => {
                    audio.setVolume(audio.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
                    audio.commit()
                  }
                }
              }

              Text {
                Layout.preferredWidth: 36
                horizontalAlignment: Text.AlignRight
                text: Math.round(audio.volume * 100) + "%"
                color: audio.muted ? Theme.subtext : Theme.text
                font.pixelSize: Theme.fs(12)
                font.bold: true
                font.family: Theme.fontFamily
              }
            }
          }

          SkinRect {
            Layout.fillWidth: true
            Layout.preferredHeight: 50
            radius: Theme.cardRadius
            color: Theme.surface
            visible: BrightnessBackend.available

            RowLayout {
              anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
              spacing: 12

              Item {
                Layout.preferredWidth: 26
                Layout.preferredHeight: 26
                Text {
                  anchors.centerIn: parent
                  text: BrightnessBackend.brightness < 0.5 ? OozeIcons.brightnessLow : OozeIcons.brightnessHigh
                  color: Theme.primary
                  font.pixelSize: Theme.fs(20)
                  font.family: Theme.monoFamily
                }
                MouseArea {
                  anchors.fill: parent
                  anchors.margins: -4
                  cursorShape: Qt.PointingHandCursor
                  onClicked: BrightnessBackend.stepBrightness(1 - BrightnessBackend.brightness)
                }
              }

              Item {
                id: briSlider
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                readonly property bool grabbed: briArea.containsMouse || briArea.pressed

                PixelBar {
                  visible: Theme.cozy
                  anchors.verticalCenter: parent.verticalCenter
                  width: parent.width
                  height: 16
                  ratio: BrightnessBackend.brightness
                  colorA: Theme.mix(Theme.primary, Theme.bg, 0.40)
                  colorB: Theme.primary
                }

                Rectangle {
                  id: briTrack
                  visible: !Theme.cozy
                  anchors.verticalCenter: parent.verticalCenter
                  width: parent.width
                  height: briSlider.grabbed ? 8 : 6
                  radius: height / 2
                  color: Theme.surfaceHigh
                  Behavior on height { NumberAnimation { duration: Theme.animDuration(100) } }

                  Rectangle {
                    width: briTrack.width * BrightnessBackend.brightness
                    height: parent.height
                    radius: parent.radius
                    color: Theme.primary
                  }
                  Rectangle {
                    x: briTrack.width * BrightnessBackend.brightness - width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: briSlider.grabbed ? 14 : 0
                    height: width
                    radius: width / 2
                    color: Theme.text
                    Behavior on width { NumberAnimation { duration: Theme.animDuration(100) } }
                  }
                }

                MouseArea {
                  id: briArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  function setFrom(mx) {
                    BrightnessBackend.dragging = true
                    BrightnessBackend.setBrightness(Math.max(0, Math.min(1, mx / width)))
                  }
                  function done() { BrightnessBackend.dragging = false; BrightnessBackend.commit() }
                  onPressed: mouse => setFrom(mouse.x)
                  onPositionChanged: mouse => { if (pressed) setFrom(mouse.x) }
                  onReleased: done()
                  onCanceled: done()
                  onWheel: wheel => BrightnessBackend.stepBrightness(wheel.angleDelta.y > 0 ? 0.05 : -0.05)
                }
              }

              Text {
                Layout.preferredWidth: 36
                horizontalAlignment: Text.AlignRight
                text: Math.round(BrightnessBackend.brightness * 100) + "%"
                color: Theme.text
                font.pixelSize: Theme.fs(12)
                font.bold: true
                font.family: Theme.fontFamily
              }
            }
          }

          SectionTitle { text: Translations.t("menuSectionPower") }
          RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
              model: PowerProfile.profiles
              delegate: SkinRect {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.preferredHeight: 44
                radius: 10
                raised: true
                color: PowerProfile.current === modelData.key ? Theme.primary : Theme.surface
                Behavior on color { ColorAnimation { duration: Theme.animDuration(200) } }

                ColumnLayout {
                  anchors.fill: parent
                  anchors.margins: 4
                  spacing: 0
                  Text {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData.icon
                    color: PowerProfile.current === modelData.key ? Theme.textOnPrimary : Theme.text
                    font.pixelSize: Theme.fs(14)
                    font.family: Theme.monoFamily
                  }
                  Text {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    horizontalAlignment: Text.AlignHCenter
                    text: Translations.t(modelData.labelKey)
                    color: PowerProfile.current === modelData.key ? Theme.textOnPrimary : Theme.subtext
                    font.pixelSize: Theme.fs(8)
                    font.family: Theme.fontFamily
                    elide: Text.ElideRight
                  }
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: menuRoot.setPowerProfile(modelData.key)
                }
              }
            }
          }
        }

        ColumnLayout {
          visible: menuRoot.currentTab === "accesos"
          Layout.fillWidth: true
          spacing: 14

          SectionTitle { text: Translations.t("menuSectionQuick") }
          ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
              model: [
                { icon: OozeIcons.wifi,       labelKey: "netTitle",        action: "network" },
                { icon: OozeIcons.bluetooth,  labelKey: "btTitle",         action: "bluetooth" },
                { icon: OozeIcons.appearance, labelKey: "appearanceTitle", action: "appearance" },
                { icon: OozeIcons.walls,      labelKey: "menuWallpaper",   action: "walls" },
                { icon: OozeIcons.caffeine,   labelKey: "caffeineTitle",   action: "caffeine" },
                { icon: OozeIcons.performance, labelKey: "perfToastTitle",  action: "performance" }
              ]
              delegate: SkinRect {
                Layout.fillWidth: true
                Layout.preferredHeight: 42
                radius: 10
                color: menuRoot.isActive(modelData.action)
                       ? Theme.mix(Theme.surface, Theme.primary, itemArea.containsMouse ? 0.34 : 0.24)
                       : (itemArea.containsMouse ? Theme.surfaceHigh : Theme.surface)
                Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }

                RowLayout {
                  anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                  spacing: 10
                  Text {
                    text: modelData.action === "network" ? NetworkBackend.statusIcon
                        : (modelData.action === "bluetooth" ? BluetoothBackend.statusIcon
                        : (modelData.action === "caffeine" ? (CaffeineBackend.active ? OozeIcons.caffeine : OozeIcons.caffeineOff)
                        : modelData.icon))
                    color: Theme.primary
                    font.pixelSize: Theme.fs(15)
                    font.family: Theme.fontFamily
                  }
                  Text {
                    text: modelData.action === "network" ? NetworkBackend.title : Translations.t(modelData.labelKey)
                    color: Theme.text
                    font.pixelSize: Theme.fs(12)
                    font.family: Theme.fontFamily
                  }
                  Item { Layout.fillWidth: true }
                  Text {
                    visible: text !== ""
                    Layout.maximumWidth: 180
                    text: menuRoot.subtitleFor(modelData.action)
                    color: Theme.subtext
                    font.pixelSize: Theme.fs(11)
                    font.family: Theme.fontFamily
                    elide: Text.ElideRight
                  }
                  Text { text: OozeIcons.chevron; color: Theme.subtext; font.pixelSize: Theme.fs(11); font.family: Theme.fontFamily }
                }

                MouseArea {
                  id: itemArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (modelData.action === "caffeine") { CaffeineBackend.toggle(); return }
                    if (modelData.action === "performance") { Theme.setPerformanceMode(!Theme.performanceMode); return }
                    if (modelData.action === "network") menuRoot.requestNetwork()
                    else if (modelData.action === "bluetooth") menuRoot.requestBluetooth()
                    else if (modelData.action === "appearance") menuRoot.requestAppearance()
                    else if (modelData.action === "walls") menuRoot.requestWalls()
                    menuRoot.closeRequested()
                  }
                }
              }
            }
          }
        }

        ColumnLayout {
          visible: menuRoot.currentTab === "notifs"
          Layout.fillWidth: true
          spacing: 10

          RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
              text: OozeIcons.bell
              color: Theme.primary
              font.pixelSize: Theme.fs(18)
              font.family: Theme.monoFamily
            }

            Text {
              text: Translations.t("notifTitle")
              color: Theme.text
              font.bold: true
              font.pixelSize: Theme.fs(14)
              font.family: Theme.fontFamily
            }

            Rectangle {
              visible: NotificationsBackend.count > 0
              Layout.preferredHeight: 18
              Layout.preferredWidth: Math.max(20, countText.implicitWidth + 12)
              radius: 9
              color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.22)

              Text {
                id: countText
                anchors.centerIn: parent
                text: NotificationsBackend.count
                color: Theme.primary
                font.bold: true
                font.pixelSize: Theme.fs(10)
                font.family: Theme.fontFamily
              }
            }

            Item { Layout.fillWidth: true }

            Rectangle {
              visible: NotificationsBackend.count > 0
              Layout.preferredHeight: 26
              Layout.preferredWidth: clearRow.implicitWidth + 20
              radius: 8
              color: clearArea.containsMouse ? Theme.surfaceHigh : Theme.surface
              Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }

              RowLayout {
                id: clearRow
                anchors.centerIn: parent
                spacing: 6

                Text {
                  text: OozeIcons.trash
                  color: Theme.primary
                  font.pixelSize: Theme.fs(13)
                  font.family: Theme.monoFamily
                }
                Text {
                  text: Translations.t("notifClear")
                  color: Theme.text
                  font.pixelSize: Theme.fs(11)
                  font.family: Theme.fontFamily
                }
              }

              MouseArea {
                id: clearArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: NotificationsBackend.clearAll()
              }
            }
          }

          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            radius: Theme.cardRadius
            color: dndArea.containsMouse ? Theme.surfaceHigh : Theme.surface
            Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }

            RowLayout {
              anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
              spacing: 10

              Text {
                text: OozeIcons.bellOff
                color: NotificationsBackend.dnd ? Theme.primary : Theme.subtext
                font.pixelSize: Theme.fs(16)
                font.family: Theme.monoFamily
                Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
              }

              Text {
                text: Translations.t("notifDnd")
                color: Theme.text
                font.pixelSize: Theme.fs(12)
                font.family: Theme.fontFamily
              }

              Item { Layout.fillWidth: true }

              Rectangle {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 22
                radius: 11
                color: NotificationsBackend.dnd ? Theme.primary : Theme.surfaceHigh
                Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }

                Rectangle {
                  width: 16
                  height: 16
                  radius: 8
                  anchors.verticalCenter: parent.verticalCenter
                  x: NotificationsBackend.dnd ? 21 : 3
                  color: NotificationsBackend.dnd ? Theme.textOnPrimary : Theme.subtext
                  Behavior on x { NumberAnimation { duration: Theme.animDuration(150); easing.type: Easing.OutCubic } }
                  Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
                }
              }
            }

            MouseArea {
              id: dndArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: NotificationsBackend.toggleDnd()
            }
          }

          ColumnLayout {
            visible: NotificationsBackend.count === 0
            Layout.fillWidth: true
            Layout.topMargin: 14
            Layout.bottomMargin: 14
            spacing: 6

            Text {
              Layout.alignment: Qt.AlignHCenter
              text: NotificationsBackend.dnd ? OozeIcons.bellOff : OozeIcons.bell
              color: Theme.subtext
              font.pixelSize: Theme.fs(30)
              font.family: Theme.monoFamily
            }
            Text {
              Layout.alignment: Qt.AlignHCenter
              text: Translations.t("notifEmpty")
              color: Theme.subtext
              font.pixelSize: Theme.fs(11)
              font.family: Theme.fontFamily
            }
          }

          Flickable {
            id: notifList
            visible: NotificationsBackend.count > 0
            Layout.fillWidth: true
            Layout.preferredHeight: menuRoot.listH
            contentWidth: width
            contentHeight: notifCol.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
              id: notifCol
              width: notifList.width
              spacing: 8

              Repeater {
                model: ScriptModel { values: menuRoot.notifRows; objectProp: "notifId" }

                delegate: Item {
                  id: entry
                  required property var modelData
                  readonly property bool leaving: entry.modelData.leaving === true
                  property real reveal: 1
                  Behavior on reveal {
                    NumberAnimation { duration: Theme.animDuration(200); easing.type: entry.leaving ? Easing.InCubic : Easing.OutCubic }
                  }
                  onLeavingChanged: { if (entry.leaving) entry.reveal = 0 }
                  width: notifCol.width
                  height: (cardItem.implicitHeight + 8) * entry.reveal
                  opacity: entry.reveal
                  clip: entry.reveal < 0.999
                  enabled: !entry.leaving

                  NotifCard {
                    id: cardItem
                    width: parent.width
                    x: (1 - entry.reveal) * 40
                    notif: entry.modelData
                    showApp: true
                  }
                }
              }
            }
          }
        }

      }
    }
  }
}
