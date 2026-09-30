// NotifCard — una notificación, con el mismo aspecto en el panel y en los
// toasts (ícono/imagen, título, hora, cuerpo, acciones).
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications
import Quickshell.Widgets
import "../COMMON"
import "../LANG"

Rectangle {
  id: card

  required property var notif
  property bool showApp: false

  readonly property bool critical: notif.urgency === NotificationUrgency.Critical
  readonly property bool low: notif.urgency === NotificationUrgency.Low

  implicitHeight: row.implicitHeight + 24
  radius: Theme.cardRadius
  color: critical
    ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.16)
    : (hh.hovered ? Theme.surfaceHigh : Theme.surface)
  Behavior on color { ColorAnimation { duration: 120 } }

  HoverHandler {
    id: hh
    onHoveredChanged: card.notif.hovered = hh.hovered
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton
    cursorShape: Qt.PointingHandCursor
    onClicked: {
      if (card.notif.defaultAction) card.notif.invokeAction(card.notif.defaultAction)
      else card.notif.expanded = !card.notif.expanded
    }
  }

  // Row/Column con anchos explícitos en vez de RowLayout: así bodyText
  // conoce su ancho real en el mismo frame y calcula bien su altura
  // desde el primer render (evita el hueco al llegar una notificación).
  Row {
    id: row
    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
    spacing: 10

    // Ícono / imagen
    Item {
      width: 40
      height: 40

      ClippingRectangle {
        anchors.fill: parent
        radius: 12
        color: card.critical
          ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.30)
          : (card.low ? Theme.surfaceHigh
                      : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.20))

        Image {
          id: img
          anchors.fill: parent
          source: card.notif.image
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          cache: false
          // La tarjeta solo muestra 40×40: limita la textura aunque la
          // notificación traiga una captura/foto de varios megapíxeles.
          sourceSize: Qt.size(80, 80)
          visible: card.notif.image !== "" && status === Image.Ready
        }

        Image {
          id: appImg
          anchors.centerIn: parent
          width: 26
          height: 26
          sourceSize: Qt.size(52, 52)
          fillMode: Image.PreserveAspectFit
          asynchronous: true
          source: img.visible ? "" : card.notif.iconSource
          visible: !img.visible && status === Image.Ready
        }

        Text {
          anchors.centerIn: parent
          visible: !img.visible && !appImg.visible
          text: "󰂚"
          color: card.critical ? Theme.error : Theme.primary
          font.pixelSize: Theme.fs(18)
          font.family: Theme.monoFamily
        }
      }
    }

    // Texto (width fijo por aritmética, no Layout.fillWidth: ver comentario en `row`)
    Column {
      id: textCol
      width: row.width - 40 - row.spacing
      spacing: 3

      Text {
        visible: card.showApp
        width: textCol.width
        text: card.notif.appName !== "" ? card.notif.appName : Translations.t("notifSystem")
        color: Theme.subtext
        font.pixelSize: Theme.fs(10)
        font.family: Theme.fontFamily
        elide: Text.ElideRight
      }

      RowLayout {
        width: textCol.width
        spacing: 6

        Text {
          Layout.fillWidth: true
          text: card.notif.summary
          color: card.critical ? Theme.error : Theme.text
          font.bold: true
          font.pixelSize: Theme.fs(12)
          font.family: Theme.fontFamily
          elide: Text.ElideRight
        }

        Text {
          text: card.notif.timeStr
          color: Theme.subtext
          font.pixelSize: Theme.fs(10)
          font.family: Theme.fontFamily
        }

        Item {
          Layout.preferredWidth: 18
          Layout.preferredHeight: 18

          Text {
            anchors.centerIn: parent
            text: "󰅖"
            color: closeArea.containsMouse ? Theme.error : Theme.subtext
            font.pixelSize: Theme.fs(13)
            font.family: Theme.monoFamily
            Behavior on color { ColorAnimation { duration: 100 } }
          }

          MouseArea {
            id: closeArea
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: card.notif.close()
          }
        }
      }

      Text {
        id: bodyText
        width: textCol.width
        visible: text.length > 0
        text: card.notif.body
        textFormat: Text.StyledText
        wrapMode: Text.Wrap
        maximumLineCount: card.notif.expanded ? 0 : 3 // 0 = sin límite, la tarjeta crece
        elide: Text.ElideRight
        color: Theme.subtext
        linkColor: Theme.primary
        font.pixelSize: Theme.fs(11)
        font.family: Theme.fontFamily
        onLinkActivated: link => Qt.openUrlExternally(link)
      }

      // "Ver detalles" — solo si el cuerpo no entra en 3 líneas, independiente
      // del clic en la tarjeta (que puede disparar una acción por defecto)
      Text {
        id: moreLink
        visible: bodyText.truncated || card.notif.expanded
        width: textCol.width
        text: card.notif.expanded ? Translations.t("notifShowLess") : Translations.t("notifShowMore")
        color: moreArea.containsMouse ? Theme.text : Theme.primary
        font.pixelSize: Theme.fs(10)
        font.bold: true
        font.family: Theme.fontFamily
        font.underline: moreArea.containsMouse
        Behavior on color { ColorAnimation { duration: 100 } }

        MouseArea {
          id: moreArea
          anchors.fill: parent
          anchors.margins: -4
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: card.notif.expanded = !card.notif.expanded
        }
      }

      // Botones de acción (ej. "Responder", "Ver")
      RowLayout {
        width: textCol.width
        spacing: 6
        visible: card.notif.visibleActions.length > 0

        Repeater {
          model: card.notif.visibleActions

          delegate: Rectangle {
            id: actionBtn
            required property var modelData

            Layout.preferredHeight: 24
            Layout.preferredWidth: actionLabel.implicitWidth + 18
            radius: 8
            color: actionArea.containsMouse ? Theme.primary : Theme.surfaceHigh
            Behavior on color { ColorAnimation { duration: 120 } }

            Text {
              id: actionLabel
              anchors.centerIn: parent
              text: actionBtn.modelData.text
              color: actionArea.containsMouse ? Theme.textOnPrimary : Theme.text
              font.pixelSize: Theme.fs(10)
              font.family: Theme.fontFamily
            }

            MouseArea {
              id: actionArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: card.notif.invokeAction(actionBtn.modelData)
            }
          }
        }
      }
    }
  }
}
