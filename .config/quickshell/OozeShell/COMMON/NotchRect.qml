import QtQuick

// NotchRect — rectángulo de "esquinas pixel": a cada esquina le falta un
// cuadrito de `notch` px (escalón), en vez de un radio curvo. Se arma con tres
// franjas, y el degradado vertical se reparte entre ellas para que no se vea
// ninguna costura. `solid: true` = un solo color (respeta el alfa).
Item {
  id: root
  property color topColor: "#888888"
  property color bottomColor: root.topColor
  property bool solid: true
  property int notch: 4

  readonly property int n: Math.max(0, Math.min(root.notch, Math.floor(Math.min(root.width, root.height) / 2)))

  function at(y) {
    if (root.solid || root.height <= 0) return root.topColor
    return Theme.mix(root.topColor, root.bottomColor, Math.max(0, Math.min(1, y / root.height)))
  }

  // franja central (ancho completo)
  Rectangle {
    x: 0; y: root.n
    width: root.width; height: Math.max(0, root.height - 2 * root.n)
    gradient: Gradient {
      GradientStop { position: 0.0; color: root.at(root.n) }
      GradientStop { position: 1.0; color: root.at(root.height - root.n) }
    }
  }
  // franja superior
  Rectangle {
    x: root.n; y: 0
    width: Math.max(0, root.width - 2 * root.n); height: root.n
    gradient: Gradient {
      GradientStop { position: 0.0; color: root.at(0) }
      GradientStop { position: 1.0; color: root.at(root.n) }
    }
  }
  // franja inferior
  Rectangle {
    x: root.n; y: root.height - root.n
    width: Math.max(0, root.width - 2 * root.n); height: root.n
    gradient: Gradient {
      GradientStop { position: 0.0; color: root.at(root.height - root.n) }
      GradientStop { position: 1.0; color: root.at(root.height) }
    }
  }
}
