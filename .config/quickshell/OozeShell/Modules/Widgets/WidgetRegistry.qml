// WidgetRegistry — EL ANEXADOR. Único lugar donde se da de alta un tipo de widget.

pragma Singleton
import Quickshell
import QtQuick

Singleton {
  id: root

  readonly property var appearanceKeys: ["background", "card", "bgOpacity", "blur", "border", "radius"]

  readonly property var types: [
    {
      id: "clock", title: "Reloj",
      source: "clock/ClockWidget.qml",
      styles: ["digital", "minimal", "analog", "hybrid", "vertical", "weather", "weathermini"],
      size: [260, 120],
      styleSizes: { minimal: [240, 100], analog: [200, 200], hybrid: [380, 170], vertical: [130, 240],
                    weather: [380, 150], weathermini: [250, 84] },
      defaults: { seconds: false, hour24: true, date: true, city: "", fahrenheit: false, refreshMin: 20,
                  background: true, bgOpacity: 60, blur: 40, border: false },
      ranges: { refreshMin: [10, 180, 5], bgOpacity: [0, 100, 5], blur: [0, 100, 5] },
      styleOptions: { city: ["weather", "weathermini"], fahrenheit: ["weather", "weathermini"],
                      refreshMin: ["weather", "weathermini"],
                      seconds: ["digital", "minimal", "hybrid", "vertical", "weather", "weathermini"],
                      date: ["digital", "analog", "hybrid", "vertical", "weather"] },
      needsNative: false
    },
    {
      id: "sysinfo", title: "Sistema (CPU · RAM · GPU)",
      source: "sysinfo/SysInfoWidget.qml",
      styles: ["bars", "rings", "graph", "compact", "minimal"],
      size: [260, 150],
      styleSizes: { rings: [360, 170], graph: [320, 180], compact: [340, 76], minimal: [240, 54] },
      defaults: { intervalMs: 1000, card: true, bgOpacity: 72, blur: 40, border: false },
      ranges: { intervalMs: [250, 10000, 250], bgOpacity: [0, 100, 5], blur: [0, 100, 5] },
      needsNative: false
    },
    {
      id: "audiovisualizer", title: "Visualizador de audio",
      source: "audiovisualizer/AudioVisualizerWidget.qml",
      styles: ["bars", "mirror", "wave", "circular", "dots", "ribbon", "pulse", "player"],
      size: [320, 120],
      styleSizes: { circular: [220, 220], wave: [320, 110], dots: [300, 120], ribbon: [340, 120],
                    pulse: [220, 220], player: [380, 132] },
      defaults: { cover: false, title: false, onlyWhenPlaying: true, background: false, bgOpacity: 50, blur: 40,
                  border: false },
      ranges: { bgOpacity: [0, 100, 5], blur: [0, 100, 5] },
      styleOptions: { cover: ["bars", "mirror", "wave", "circular", "dots", "ribbon", "pulse"],
                      title: ["bars", "mirror", "wave", "circular", "dots", "ribbon", "pulse"],
                      background: ["bars", "mirror", "wave", "circular", "dots", "ribbon", "pulse"] },
      needsNative: false
    },
    {
      id: "imageframe", title: "Marco de imagen",
      source: "imageframe/ImageFrameWidget.qml",
      styles: ["fit", "fill", "blur", "circle", "polaroid", "gallery", "strip"],
      size: [300, 220],
      styleSizes: { circle: [220, 220], polaroid: [260, 300], gallery: [320, 220], strip: [340, 220] },
      defaults: { source: "", intervalSec: 60, shuffle: true, radius: 14, caption: false, counter: true,
                  border: false },
      ranges: { intervalSec: [0, 3600, 5], radius: [0, 80, 2] },
      styleOptions: { caption: ["polaroid", "gallery"], counter: ["gallery"],
                      radius: ["fit", "fill", "blur", "gallery", "strip"] },
      pickers: { source: "image" },
      needsNative: false
    },
    {
      id: "weather", title: "Clima",
      source: "weather/WeatherWidget.qml",
      styles: ["compact", "card", "forecast", "minimal"],
      size: [260, 150],
      styleSizes: { compact: [200, 90], forecast: [460, 230], minimal: [150, 60] },
      defaults: { city: "", fahrenheit: false, refreshMin: 20, background: true, bgOpacity: 60, blur: 40,
                  border: false },
      ranges: { refreshMin: [10, 180, 5], bgOpacity: [0, 100, 5], blur: [0, 100, 5] },
      needsNative: false
    },
    {
      id: "pomodoro", title: "Pomodoro",
      source: "pomodoro/PomodoroWidget.qml",
      styles: ["ring", "minimal", "bar", "dots", "tomato", "capsule"],
      size: [240, 240],
      styleSizes: { minimal: [250, 110], bar: [320, 130], dots: [270, 170], tomato: [220, 270], capsule: [360, 100] },
      defaults: { focusMin: 25, shortMin: 5, longMin: 15, rounds: 4, autoNext: false,
                  notify: true, sound: true, background: true, bgOpacity: 60, blur: 40, border: false },
      ranges: { focusMin: [1, 180, 1], shortMin: [1, 60, 1], longMin: [1, 120, 1], rounds: [1, 12, 1],
                bgOpacity: [0, 100, 5], blur: [0, 100, 5] },
      needsNative: false
    }
  ]

  function get(type) { return root.types.find(t => t.id === type) ?? null }
  function has(type) { return root.get(type) !== null }

  function sizeFor(type, style) {
    const t = root.get(type)
    if (!t) return [200, 120]
    return (t.styleSizes && t.styleSizes[style]) ? t.styleSizes[style] : t.size
  }

  function optionVisible(type, style, key) {
    const t = root.get(type)
    if (!t || !t.styleOptions || !t.styleOptions[key]) return true
    return t.styleOptions[key].indexOf(style) >= 0
  }
}
