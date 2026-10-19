// WeatherIcon — icono de clima dibujado con vectores (sin depender de ninguna fuente).

import QtQuick
import QtQuick.Shapes
import ".."
import "../../../COMMON"

Item {
  id: root

  property int code: 0
  property bool isDay: true
  property bool mono: false
  property color monoColor: Theme.text

  implicitWidth: 48
  implicitHeight: 48


  layer.enabled: root.width > 0
  layer.samples: 4

  readonly property string kind: WeatherService.group(root.code) + (root.isDay ? "_day" : "_night")
  readonly property var layers: root.table[root.kind] ?? root.table["overcast_day"]

  readonly property var palette: ({
    sun: "#ffc94a", moon: "#dfe6f5", bolt: "#ffd24a", rain: "#5aa9ff", snow: "#bfe3ff",
    cloud: Theme.bgIsDark ? "#e3e9f3" : "#a9b6cc",
    cloudDark: Theme.bgIsDark ? "#9aa5b8" : "#6f7b91",
    fog: Theme.bgIsDark ? "#9aa5b8" : "#6f7b91"
  })

  readonly property var table: ({
    "clear_day": [
      { p: "M33 50 A17 17 0 1 0 67 50 A17 17 0 1 0 33 50 Z", c: "sun", x: 0, y: 0, s: 1, w: 0 },
      { p: "M50 9 L50 19 M50 81 L50 91 M9 50 L19 50 M81 50 L91 50 M21 21 L28 28 M72 72 L79 79 M79 21 L72 28 M28 72 L21 79", c: "sun", x: 0, y: 0, s: 1, w: 5 }
    ],
    "clear_night": [
      { p: "M60 16 A34 34 0 1 0 86 64 A27 27 0 0 1 60 16 Z", c: "moon", x: 0, y: 0, s: 1, w: 0 }
    ],
    "mostlyClear_day": [
      { p: "M33 50 A17 17 0 1 0 67 50 A17 17 0 1 0 33 50 Z", c: "sun", x: -2, y: -2, s: 0.66, w: 0 },
      { p: "M50 9 L50 19 M50 81 L50 91 M9 50 L19 50 M81 50 L91 50 M21 21 L28 28 M72 72 L79 79 M79 21 L72 28 M28 72 L21 79", c: "sun", x: -2, y: -2, s: 0.66, w: 5 },
      { p: "M28 74 C14 74 8 63 12 53 C15 45 24 42 31 45 C34 33 46 27 57 31 C66 34 71 41 71 49 C83 48 92 56 90 65 C88 71 83 74 76 74 Z", c: "cloud", x: 14, y: 22, s: 0.8, w: 0 }
    ],
    "mostlyClear_night": [
      { p: "M60 16 A34 34 0 1 0 86 64 A27 27 0 0 1 60 16 Z", c: "moon", x: 0, y: -4, s: 0.62, w: 0 },
      { p: "M28 74 C14 74 8 63 12 53 C15 45 24 42 31 45 C34 33 46 27 57 31 C66 34 71 41 71 49 C83 48 92 56 90 65 C88 71 83 74 76 74 Z", c: "cloud", x: 14, y: 22, s: 0.8, w: 0 }
    ],
    "partly_day": [
      { p: "M33 50 A17 17 0 1 0 67 50 A17 17 0 1 0 33 50 Z", c: "sun", x: -2, y: -2, s: 0.66, w: 0 },
      { p: "M50 9 L50 19 M50 81 L50 91 M9 50 L19 50 M81 50 L91 50 M21 21 L28 28 M72 72 L79 79 M79 21 L72 28 M28 72 L21 79", c: "sun", x: -2, y: -2, s: 0.66, w: 5 },
      { p: "M28 74 C14 74 8 63 12 53 C15 45 24 42 31 45 C34 33 46 27 57 31 C66 34 71 41 71 49 C83 48 92 56 90 65 C88 71 83 74 76 74 Z", c: "cloud", x: 14, y: 22, s: 0.8, w: 0 }
    ],
    "partly_night": [
      { p: "M60 16 A34 34 0 1 0 86 64 A27 27 0 0 1 60 16 Z", c: "moon", x: 0, y: -4, s: 0.62, w: 0 },
      { p: "M28 74 C14 74 8 63 12 53 C15 45 24 42 31 45 C34 33 46 27 57 31 C66 34 71 41 71 49 C83 48 92 56 90 65 C88 71 83 74 76 74 Z", c: "cloud", x: 14, y: 22, s: 0.8, w: 0 }
    ],
    "overcast_day": [
      { p: "M28 74 C14 74 8 63 12 53 C15 45 24 42 31 45 C34 33 46 27 57 31 C66 34 71 41 71 49 C83 48 92 56 90 65 C88 71 83 74 76 74 Z", c: "cloudDark", x: 26, y: 2, s: 0.7, w: 0 },
      { p: "M28 74 C14 74 8 63 12 53 C15 45 24 42 31 45 C34 33 46 27 57 31 C66 34 71 41 71 49 C83 48 92 56 90 65 C88 71 83 74 76 74 Z", c: "cloud", x: 2, y: 16, s: 0.92, w: 0 }
    ],
    "overcast_night": [
      { p: "M28 74 C14 74 8 63 12 53 C15 45 24 42 31 45 C34 33 46 27 57 31 C66 34 71 41 71 49 C83 48 92 56 90 65 C88 71 83 74 76 74 Z", c: "cloudDark", x: 26, y: 2, s: 0.7, w: 0 },
      { p: "M28 74 C14 74 8 63 12 53 C15 45 24 42 31 45 C34 33 46 27 57 31 C66 34 71 41 71 49 C83 48 92 56 90 65 C88 71 83 74 76 74 Z", c: "cloud", x: 2, y: 16, s: 0.92, w: 0 }
    ],
    "fog_day": [
      { p: "M28 74 C14 74 8 63 12 53 C15 45 24 42 31 45 C34 33 46 27 57 31 C66 34 71 41 71 49 C83 48 92 56 90 65 C88 71 83 74 76 74 Z", c: "cloud", x: 0, y: -10, s: 1, w: 0 },
      { p: "M18 82 L82 82 M28 91 L92 91", c: "fog", x: 0, y: 0, s: 1, w: 5 }
    ],
    "fog_night": [
      { p: "M28 74 C14 74 8 63 12 53 C15 45 24 42 31 45 C34 33 46 27 57 31 C66 34 71 41 71 49 C83 48 92 56 90 65 C88 71 83 74 76 74 Z", c: "cloud", x: 0, y: -10, s: 1, w: 0 },
      { p: "M18 82 L82 82 M28 91 L92 91", c: "fog", x: 0, y: 0, s: 1, w: 5 }
    ],
    "drizzle_day": [
      { p: "M28 74 C14 74 8 63 12 53 C15 45 24 42 31 45 C34 33 46 27 57 31 C66 34 71 41 71 49 C83 48 92 56 90 65 C88 71 83 74 76 74 Z", c: "cloud", x: 0, y: -10, s: 1, w: 0 },
      { p: "M32 78 L30 85 M50 78 L48 85 M68 78 L66 85", c: "rain", x: 0, y: 0, s: 1, w: 5 }
    ],
    "drizzle_night": [
      { p: "M28 74 C14 74 8 63 12 53 C15 45 24 42 31 45 C34 33 46 27 57 31 C66 34 71 41 71 49 C83 48 92 56 90 65 C88 71 83 74 76 74 Z", c: "cloud", x: 0, y: -10, s: 1, w: 0 },
      { p: "M32 78 L30 85 M50 78 L48 85 M68 78 L66 85", c: "rain", x: 0, y: 0, s: 1, w: 5 }
    ],
    "rain_day": [
      { p: "M28 74 C14 74 8 63 12 53 C15 45 24 42 31 45 C34 33 46 27 57 31 C66 34 71 41 71 49 C83 48 92 56 90 65 C88 71 83 74 76 74 Z", c: "cloud", x: 0, y: -10, s: 1, w: 0 },
      { p: "M30 76 L26 90 M50 76 L46 90 M70 76 L66 90", c: "rain", x: 0, y: 0, s: 1, w: 5 }
    ],
    "rain_night": [
      { p: "M28 74 C14 74 8 63 12 53 C15 45 24 42 31 45 C34 33 46 27 57 31 C66 34 71 41 71 49 C83 48 92 56 90 65 C88 71 83 74 76 74 Z", c: "cloud", x: 0, y: -10, s: 1, w: 0 },
      { p: "M30 76 L26 90 M50 76 L46 90 M70 76 L66 90", c: "rain", x: 0, y: 0, s: 1, w: 5 }
    ],
    "freezing_day": [
      { p: "M28 74 C14 74 8 63 12 53 C15 45 24 42 31 45 C34 33 46 27 57 31 C66 34 71 41 71 49 C83 48 92 56 90 65 C88 71 83 74 76 74 Z", c: "cloud", x: 0, y: -10, s: 1, w: 0 },
      { p: "M30 78 L28 84 M70 78 L68 84", c: "rain", x: 0, y: 0, s: 1, w: 5 },
      { p: "M46 90 a4 4 0 1 0 8 0 a4 4 0 1 0 -8 0 Z", c: "snow", x: 0, y: 0, s: 1, w: 0 }
    ],
    "freezing_night": [
      { p: "M28 74 C14 74 8 63 12 53 C15 45 24 42 31 45 C34 33 46 27 57 31 C66 34 71 41 71 49 C83 48 92 56 90 65 C88 71 83 74 76 74 Z", c: "cloud", x: 0, y: -10, s: 1, w: 0 },
      { p: "M30 78 L28 84 M70 78 L68 84", c: "rain", x: 0, y: 0, s: 1, w: 5 },
      { p: "M46 90 a4 4 0 1 0 8 0 a4 4 0 1 0 -8 0 Z", c: "snow", x: 0, y: 0, s: 1, w: 0 }
    ],
    "snow_day": [
      { p: "M28 74 C14 74 8 63 12 53 C15 45 24 42 31 45 C34 33 46 27 57 31 C66 34 71 41 71 49 C83 48 92 56 90 65 C88 71 83 74 76 74 Z", c: "cloud", x: 0, y: -10, s: 1, w: 0 },
      { p: "M26 82 a4 4 0 1 0 8 0 a4 4 0 1 0 -8 0 Z M46 90 a4 4 0 1 0 8 0 a4 4 0 1 0 -8 0 Z M66 82 a4 4 0 1 0 8 0 a4 4 0 1 0 -8 0 Z", c: "snow", x: 0, y: 0, s: 1, w: 0 }
    ],
    "snow_night": [
      { p: "M28 74 C14 74 8 63 12 53 C15 45 24 42 31 45 C34 33 46 27 57 31 C66 34 71 41 71 49 C83 48 92 56 90 65 C88 71 83 74 76 74 Z", c: "cloud", x: 0, y: -10, s: 1, w: 0 },
      { p: "M26 82 a4 4 0 1 0 8 0 a4 4 0 1 0 -8 0 Z M46 90 a4 4 0 1 0 8 0 a4 4 0 1 0 -8 0 Z M66 82 a4 4 0 1 0 8 0 a4 4 0 1 0 -8 0 Z", c: "snow", x: 0, y: 0, s: 1, w: 0 }
    ],
    "thunder_day": [
      { p: "M28 74 C14 74 8 63 12 53 C15 45 24 42 31 45 C34 33 46 27 57 31 C66 34 71 41 71 49 C83 48 92 56 90 65 C88 71 83 74 76 74 Z", c: "cloudDark", x: 0, y: -14, s: 1, w: 0 },
      { p: "M56 60 L40 84 L51 84 L45 100 L66 74 L55 74 L61 60 Z", c: "bolt", x: 0, y: 0, s: 1, w: 0 }
    ],
    "thunder_night": [
      { p: "M28 74 C14 74 8 63 12 53 C15 45 24 42 31 45 C34 33 46 27 57 31 C66 34 71 41 71 49 C83 48 92 56 90 65 C88 71 83 74 76 74 Z", c: "cloudDark", x: 0, y: -14, s: 1, w: 0 },
      { p: "M56 60 L40 84 L51 84 L45 100 L66 74 L55 74 L61 60 Z", c: "bolt", x: 0, y: 0, s: 1, w: 0 }
    ]
  })

  Item {
    width: 100; height: 100
    scale: Math.min(root.width, root.height) / 100
    transformOrigin: Item.TopLeft
    x: (root.width - Math.min(root.width, root.height)) / 2
    y: (root.height - Math.min(root.width, root.height)) / 2

    Repeater {
      model: root.layers
      delegate: Shape {
        id: lay
        required property var modelData
        preferredRendererType: Shape.CurveRenderer
        readonly property color tone: root.mono ? root.monoColor : root.palette[modelData.c]
        x: modelData.x; y: modelData.y
        width: 100; height: 100
        scale: modelData.s
        transformOrigin: Item.TopLeft
        ShapePath {
          fillColor: modelData.w > 0 ? "transparent" : lay.tone
          strokeColor: modelData.w > 0 ? lay.tone : "transparent"
          strokeWidth: modelData.w > 0 ? modelData.w / Math.max(0.01, modelData.s) : 0
          capStyle: ShapePath.RoundCap
          joinStyle: ShapePath.RoundJoin
          PathSvg { path: modelData.p }
        }
      }
    }
  }
}
