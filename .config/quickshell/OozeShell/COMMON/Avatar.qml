// Avatar — foto de perfil circular. Si no hay imagen (o todavía carga), muestra
// un círculo del color primario con la inicial.
//
// Uso:
//   Avatar { size: 46; source: UserProfile.avatarUrl; letter: "O" }
//
// El recorte circular usa el mismo truco de máscara que Mpris (MultiEffect).
import QtQuick
import QtQuick.Effects
import "../COMMON"

Item {
  id: root

  property real size: 46
  // URL file:// (ver UserProfile.fileUrl) o "" para mostrar solo la inicial
  property string source: ""
  property string letter: "?"

  implicitWidth: size
  implicitHeight: size
  width: size
  height: size

  // Sin foto: círculo con la inicial
  Rectangle {
    anchors.fill: parent
    radius: Theme.cozy ? 6 : width / 2
    color: Theme.primary
    visible: img.status !== Image.Ready

    Text {
      anchors.centerIn: parent
      text: root.letter
      color: Theme.textOnPrimary
      font.pixelSize: Theme.fs(Math.round(root.size * 0.43))
      font.bold: true
      font.family: Theme.fontFamily
    }
  }

  // Con foto: recortada en círculo
  Item {
    id: photo
    anchors.fill: parent
    opacity: img.status === Image.Ready ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.animDuration(180) } }

    layer.enabled: true
    layer.effect: MultiEffect {
      maskEnabled: true
      maskSource: circleMask
      maskThresholdMin: 0.5
      maskSpreadAtMin: 1.0
    }

    Image {
      id: img
      anchors.fill: parent
      source: root.source
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      smooth: true
      // Sin mipmaps: el avatar se renderiza a una escala UI fija y el
      // mip-chain solo añade memoria de textura.
      mipmap: false
      // Se decodifica a ~3× (nítida con la escala de Ventanas) y no a tamaño completo
      sourceSize: Qt.size(Math.ceil(root.size * 3), Math.ceil(root.size * 3))
    }
  }

  Item {
    id: circleMask
    anchors.fill: parent
    layer.enabled: true
    visible: false

    Rectangle {
      anchors.fill: parent
      radius: Theme.cozy ? 6 : width / 2
      color: "black"
    }
  }
}
