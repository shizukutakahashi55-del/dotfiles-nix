// IslandState — dónde está cada isla de la barra, en coordenadas de PANTALLA.
//
// Con el modo Islas (Theme.islandsMode) la barra no tiene fondo: hay tres
// píldoras (left / center / right) y los popups tienen que "nacer" de la que
// les toca. Las píldoras viven en ventanas distintas a las de los popups, así
// que cada módulo (LeftModules / CenterModules / RightModules) publica acá su
// rectángulo y FusedPanel lo lee para saber de dónde crecer.
//
//   IslandState.report("DP-3", "right", { x, y, w, h })
//   IslandState.rectFor("DP-3", "right")   → { x, y, w, h } | null
//   IslandState.nearestSide("DP-3", 640)     → "left" | "center" | "right"
//
// `rects` se reemplaza entero en cada cambio, así los bindings que lo leen se
// reevalúan solos.
pragma Singleton
import QtQuick
import Quickshell

Singleton {
  id: root

  property var rects: ({})

  function key(screen, side) { return screen + "|" + side }

  function report(screen, side, r) {
    if (!screen || !r) return
    const k = root.key(screen, side)
    const o = root.rects[k]
    if (o && Math.abs(o.x - r.x) < 0.25 && Math.abs(o.y - r.y) < 0.25
        && Math.abs(o.w - r.w) < 0.25 && Math.abs(o.h - r.h) < 0.25
        && o.r === r.r) return
    const n = Object.assign({}, root.rects)
    n[k] = { x: r.x, y: r.y, w: r.w, h: r.h, r: r.r }
    root.rects = n
  }

  function clear(screen, side) {
    const k = root.key(screen, side)
    if (!(k in root.rects)) return
    const n = Object.assign({}, root.rects)
    delete n[k]
    root.rects = n
  }

  function rectFor(screen, side) {
    return root.rects[root.key(screen, side)] ?? null
  }

  // Isla (de esa pantalla) cuyo centro queda más cerca de la coordenada x
  function nearestSide(screen, cx) {
    let best = "center"
    let bestD = 1e9
    const sides = ["left", "center", "right"]
    for (let i = 0; i < sides.length; i++) {
      const r = root.rectFor(screen, sides[i])
      if (!r) continue
      const d = Math.abs(r.x + r.w / 2 - cx)
      if (d < bestD) { bestD = d; best = sides[i] }
    }
    return best
  }
}
