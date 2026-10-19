// IslandState — dónde está cada isla de la barra, en coordenadas de PANTALLA.

pragma Singleton
import QtQuick
import Quickshell

Singleton {
  id: root

  property var rects: ({})


  property var spans: ({})

  signal refreshRequested()

  function setSpan(screen, x, w) {
    if (!screen) return
    const o = root.spans[screen]
    if (o && Math.abs(o.x - x) < 0.25 && Math.abs(o.w - w) < 0.25) return
    const n = Object.assign({}, root.spans)
    n[screen] = { x: x, w: w }
    root.spans = n
  }

  function clearSpan(screen) {
    if (!(screen in root.spans)) return
    const n = Object.assign({}, root.spans)
    delete n[screen]
    root.spans = n
  }

  function spanFor(screen) {
    return root.spans[screen] ?? null
  }

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


  function clearPill(screen, side) {
    const o = root.rects[root.key(screen, side)]
    if (!o || o.r === undefined) return
    root.clear(screen, side)
  }

  function rectFor(screen, side) {
    return root.rects[root.key(screen, side)] ?? null
  }


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
