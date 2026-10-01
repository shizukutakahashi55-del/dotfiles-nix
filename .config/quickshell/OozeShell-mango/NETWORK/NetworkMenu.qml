// NetworkMenu — panel de conexión a internet (Wi-Fi / Ethernet).
//
import Quickshell
import QtQuick
import QtQuick.Layouts
import "../COMMON"
import "../LANG"
import "../NETWORK"

Item {
  id: root

  property bool open: false
  property string targetScreen: ""
  signal closeRequested()
  signal backRequested()

  property int cardWidth: 420
  property int edgeMargin: 10
  readonly property int pad: 18
  readonly property real maxListHeight: Math.max(150, Math.min(300, (fw.screenHeight - Theme.barOffset) / Theme.windowScale - 320))

  // SSID cuya fila tiene el campo de contraseña abierto, y lo escrito
  property string expandedSsid: ""
  property string pw: ""

  onOpenChanged: {
    NetworkBackend.panelWatch = root.open
    if (!root.open) { root.expandedSsid = ""; root.pw = "" }
  }

  // Mientras hay un campo abierto, la lista no se reconstruye
  onExpandedSsidChanged: NetworkBackend.holdList = (root.expandedSsid !== "")

  function activate(net) {
    if (net.active || NetworkBackend.connectingSsid !== "") return
    if (NetworkBackend.isSecured(net.security) && !NetworkBackend.isSaved(net.ssid)) {
      root.expandedSsid = (root.expandedSsid === net.ssid) ? "" : net.ssid
      root.pw = ""
      return
    }
    NetworkBackend.connectTo(net.ssid, "")
  }

  function submitPassword(net) {
    if (root.pw.length === 0) return
    NetworkBackend.connectTo(net.ssid, root.pw)
  }

  Connections {
    target: NetworkBackend

    function onConnectSucceeded() { root.expandedSsid = ""; root.pw = "" }
    function onNeedPasswordForChanged() {
      if (NetworkBackend.needPasswordFor !== "") {
        root.expandedSsid = NetworkBackend.needPasswordFor
        root.pw = ""
      }
    }
  }

  FusedWindow {
    id: fw
    active: root.open || panel.shown
    targetScreen: root.targetScreen
    namespace: "oozeshell-network"
    onCloseRequested: root.closeRequested()

    FusedPanel {
      id: panel

      open: root.open
      panelWidth: root.cardWidth
      contentHeight: col.implicitHeight + root.pad * 2

      // Cuelga de la barra, del lado de su botón (derecha si es horizontal,
      // abajo si es vertical). FusedPanel se coloca solo según Theme.barPosition.
      align: "end"
      alignMargin: root.edgeMargin + Theme.barEdge + Theme.frameSideArm

      ColumnLayout {
        id: col
        x: root.pad
        y: root.pad
        width: parent.width - root.pad * 2
        spacing: 12

        // ── Encabezado: volver, título, refrescar, interruptor ──
        RowLayout {
          Layout.fillWidth: true
          spacing: 10

          SkinRect {
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            radius: 15
            color: backArea.containsMouse ? Theme.surfaceHigh : Theme.surface
            Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }

            Text {
              anchors.centerIn: parent
              text: "󰅁"
              color: Theme.text
              font.pixelSize: Theme.fs(16)
              font.family: Theme.monoFamily
            }
            MouseArea {
              id: backArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.backRequested()
            }
          }

          Text {
            text: NetworkBackend.statusIcon
            color: Theme.primary
            font.pixelSize: Theme.fs(20)
            font.family: Theme.fontFamily
          }

          Text {
            text: NetworkBackend.title
            color: Theme.text
            font.bold: true
            font.pixelSize: Theme.fs(16)
            font.family: Theme.fontFamily
          }

          Item { Layout.fillWidth: true }

          SkinRect {
            visible: NetworkBackend.wifiEnabled
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            radius: 15
            color: refreshArea.containsMouse ? Theme.surfaceHigh : Theme.surface
            Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }

            Text {
              id: refreshIcon
              anchors.centerIn: parent
              text: "󰑐"
              color: NetworkBackend.scanning ? Theme.primary : Theme.text
              font.pixelSize: Theme.fs(15)
              font.family: Theme.monoFamily

              RotationAnimation on rotation {
                running: NetworkBackend.scanning && Theme.uiAnimationsEnabled
                from: 0
                to: 360
                duration: Theme.animDuration(900)
                loops: Animation.Infinite
              }
            }
            MouseArea {
              id: refreshArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: NetworkBackend.rescan()
            }
          }

          // Interruptor Wi-Fi
          SkinRect {
            Layout.preferredWidth: 40
            Layout.preferredHeight: 22
            radius: 11
            color: NetworkBackend.wifiEnabled ? Theme.primary : Theme.surfaceHigh
            Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }

            SkinRect {
              width: 16
              height: 16
              radius: 8
              anchors.verticalCenter: parent.verticalCenter
              x: NetworkBackend.wifiEnabled ? 21 : 3
              color: NetworkBackend.wifiEnabled ? Theme.textOnPrimary : Theme.subtext
              Behavior on x { NumberAnimation { duration: Theme.animDuration(150); easing.type: Easing.OutCubic } }
              Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: NetworkBackend.setWifi(!NetworkBackend.wifiEnabled)
            }
          }
        }

        // ── Conexión actual ──────────────────────────────────
        SkinRect {
          Layout.fillWidth: true
          Layout.preferredHeight: 60
          radius: Theme.cardRadius
          color: Theme.surface

          RowLayout {
            anchors { fill: parent; leftMargin: 14; rightMargin: 12 }
            spacing: 12

            Text {
              text: NetworkBackend.statusIcon
              color: (NetworkBackend.wifiConnected || NetworkBackend.activeEthernet !== "")
                ? Theme.primary : Theme.subtext
              font.pixelSize: Theme.fs(24)
              font.family: Theme.fontFamily
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 2

              Text {
                Layout.fillWidth: true
                text: NetworkBackend.wifiConnected
                  ? NetworkBackend.summary
                  : (NetworkBackend.activeEthernet !== ""
                      ? "Ethernet"
                      : Translations.t("netNotConnected"))
                color: Theme.text
                font.bold: true
                font.pixelSize: Theme.fs(13)
                font.family: Theme.fontFamily
                elide: Text.ElideRight
              }

              Text {
                Layout.fillWidth: true
                text: {
                  if (NetworkBackend.wifiConnected) {
                    const sig = NetworkBackend.activeSignal > 0 ? "  ·  " + NetworkBackend.activeSignal + "%" : ""
                    const eth = NetworkBackend.activeEthernet !== "" ? "  ·  Ethernet" : ""
                    return Translations.t("netConnected") + sig + eth
                  }
                  if (NetworkBackend.activeEthernet !== "") return Translations.t("netConnected") + "  ·  " + NetworkBackend.activeEthernet
                  return NetworkBackend.wifiEnabled ? "" : Translations.t("netWifiOff")
                }
                visible: text.length > 0
                color: Theme.subtext
                font.pixelSize: Theme.fs(10)
                font.family: Theme.fontFamily
                elide: Text.ElideRight
              }
            }

            SkinRect {
              visible: NetworkBackend.wifiConnected
              Layout.preferredHeight: 28
              Layout.preferredWidth: disconnectLabel.implicitWidth + 22
              radius: 9
              color: disconnectArea.containsMouse ? Theme.surfaceHigh : Theme.bg
              Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }

              Text {
                id: disconnectLabel
                anchors.centerIn: parent
                text: Translations.t("netDisconnect")
                color: Theme.text
                font.pixelSize: Theme.fs(10)
                font.family: Theme.fontFamily
              }
              MouseArea {
                id: disconnectArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: NetworkBackend.disconnectWifi()
              }
            }
          }
        }

        // ── Error de conexión ────────────────────────────────
        Text {
          visible: NetworkBackend.errorText !== ""
          Layout.fillWidth: true
          text: NetworkBackend.errorText
          color: Theme.error
          font.pixelSize: Theme.fs(11)
          font.family: Theme.fontFamily
          wrapMode: Text.Wrap
        }

        // ── Wi-Fi apagado / sin redes ────────────────────────
        ColumnLayout {
          visible: !NetworkBackend.wifiEnabled
                   || (NetworkBackend.networks.length === 0)
          Layout.fillWidth: true
          Layout.topMargin: 10
          Layout.bottomMargin: 10
          spacing: 6

          Text {
            Layout.alignment: Qt.AlignHCenter
            text: NetworkBackend.wifiEnabled ? "󰤯" : "󰖪"
            color: Theme.subtext
            font.pixelSize: Theme.fs(30)
            font.family: Theme.monoFamily
          }
          Text {
            Layout.alignment: Qt.AlignHCenter
            text: !NetworkBackend.wifiEnabled
              ? Translations.t("netWifiOff")
              : (NetworkBackend.scanning
                  ? Translations.t("netScanning")
                  : Translations.t("netNoNetworks"))
            color: Theme.subtext
            font.pixelSize: Theme.fs(11)
            font.family: Theme.fontFamily
          }
        }

        // ── Lista de redes ───────────────────────────────────
        ListView {
          id: list
          visible: NetworkBackend.wifiEnabled && NetworkBackend.networks.length > 0
          Layout.fillWidth: true
          Layout.preferredHeight: Math.min(contentHeight, root.maxListHeight)
          clip: true
          spacing: 2
          cacheBuffer: 100000
          boundsBehavior: Flickable.StopAtBounds
          interactive: contentHeight > height

          model: ScriptModel {
            values: NetworkBackend.networks
            objectProp: "ssid"
          }

          delegate: Item {
            id: row
            required property var modelData

            readonly property bool expanded: root.expandedSsid === row.modelData.ssid
            readonly property bool connecting: NetworkBackend.connectingSsid === row.modelData.ssid
            readonly property bool secured: NetworkBackend.isSecured(row.modelData.security)

            width: ListView.view.width
            implicitHeight: rowCol.implicitHeight
            height: implicitHeight

            Column {
              id: rowCol
              width: parent.width
              spacing: 0

              SkinRect {
                width: parent.width
                height: 44
                radius: 10
                color: row.modelData.active
                  ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16)
                  : (rowArea.containsMouse ? Theme.surface : "transparent")
                Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }

                RowLayout {
                  anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                  spacing: 10

                  Text {
                    text: NetworkBackend.signalIcon(row.modelData.signal)
                    color: row.modelData.active ? Theme.primary : Theme.text
                    font.pixelSize: Theme.fs(17)
                    font.family: Theme.fontFamily
                  }

                  Text {
                    Layout.fillWidth: true
                    text: row.modelData.ssid
                    color: Theme.text
                    font.bold: row.modelData.active
                    font.pixelSize: Theme.fs(12)
                    font.family: Theme.fontFamily
                    elide: Text.ElideRight
                  }

                  Text {
                    visible: row.connecting
                    text: Translations.t("netConnecting")
                    color: Theme.primary
                    font.pixelSize: Theme.fs(10)
                    font.family: Theme.fontFamily
                  }

                  Text {
                    visible: row.secured && !row.connecting
                    text: "󰌾"
                    color: Theme.subtext
                    font.pixelSize: Theme.fs(13)
                    font.family: Theme.monoFamily
                  }

                  Text {
                    visible: row.modelData.active
                    text: "󰄬"
                    color: Theme.primary
                    font.pixelSize: Theme.fs(15)
                    font.family: Theme.monoFamily
                  }
                }

                MouseArea {
                  id: rowArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: row.modelData.active ? Qt.ArrowCursor : Qt.PointingHandCursor
                  onClicked: root.activate(row.modelData)
                }
              }

              // Campo de contraseña (se despliega bajo la fila)
              Item {
                id: pwWrap
                width: parent.width
                height: row.expanded ? 50 : 0
                clip: true
                Behavior on height { NumberAnimation { duration: Theme.animDuration(160); easing.type: Easing.OutCubic } }

                RowLayout {
                  anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 6 }
                  spacing: 8

                  SkinRect {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    radius: 10
                    color: Theme.surface
                    border.width: Theme.bw1
                    border.color: pwInput.activeFocus ? Theme.primary : "transparent"
                    Behavior on border.color { ColorAnimation { duration: Theme.animDuration(120) } }

                    TextInput {
                      id: pwInput
                      anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                      verticalAlignment: TextInput.AlignVCenter
                      echoMode: TextInput.Password
                      selectByMouse: true
                      clip: true
                      color: Theme.text
                      font.pixelSize: Theme.fs(12)
                      text: root.pw
                      onTextChanged: root.pw = text
                      onAccepted: root.submitPassword(row.modelData)
                      Keys.onEscapePressed: root.expandedSsid = ""

                      Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: pwInput.text.length === 0
                        text: Translations.t("netPassword")
                        color: Theme.subtext
                        font.pixelSize: Theme.fs(12)
                      }
                    }
                  }

                  SkinRect {
                    Layout.preferredHeight: 38
                    Layout.preferredWidth: connectLabel.implicitWidth + 24
                    radius: 10
                    color: connectArea.containsMouse ? Qt.lighter(Theme.primary, 1.1) : Theme.primary
                    opacity: root.pw.length > 0 && !row.connecting ? 1.0 : 0.5
                    Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }

                    Text {
                      id: connectLabel
                      anchors.centerIn: parent
                      text: Translations.t("netConnect")
                      color: Theme.textOnPrimary
                      font.bold: true
                      font.pixelSize: Theme.fs(11)
                      font.family: Theme.fontFamily
                    }
                    MouseArea {
                      id: connectArea
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.submitPassword(row.modelData)
                    }
                  }
                }

                // Al desplegarse, el foco va directo al campo
                Connections {
                  target: root
                  function onExpandedSsidChanged() {
                    if (row.expanded) pwInput.forceActiveFocus()
                  }
                }
              }
            }
          }

          displaced: Transition {
            NumberAnimation { property: "y"; duration: Theme.animDuration(200); easing.type: Easing.OutCubic }
          }
        }
      }
    }
  }
}
