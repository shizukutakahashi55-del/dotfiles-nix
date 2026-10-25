// FusedPanel — el "cuerpo" de cualquier popup que cuelga de la barra.

import Quickshell
import QtQuick
import QtQuick.Shapes
import QtQuick.Effects

Item {
  id: root

  property bool open: false

  property bool detachedFlat: false

  property string moduleId: ""
  readonly property bool floatMid: root.moduleId !== "" && root.islandRectLocal === null && Theme.popupFloatsMid(root.moduleId)

  property real panelWidth: 360
  property real contentHeight: 200

  // ─── Borde del que cuelga ──────────────────────────────────────
  property string edge: Theme.barPosition
  readonly property bool vertical: root.edge === "left" || root.edge === "right"
  readonly property bool faceAtEnd: root.edge === "bottom" || root.edge === "right"


  property real faceOffset: Theme.barFace

  // ─── Curvas y colores ──────────────────────────────────────────


  property bool flareStart: true
  property bool flareEnd: true
  property real flare: Theme.flare
  property real bodyRadius: Theme.panelRadius


  property color color: Theme.panelBg


  property real glassBlur: Theme.glassBlurOn ? 100 : 0


  property bool outline: false
  property int duration: Theme.animMs

  // ─── Islas ─────────────────────────────────────────────────────
  property bool islandAware: true
  property string island: ""
  property string islandStyle: "auto"


  property var islandRectLocal: null


  property real islandRadius: (root.islandRect !== null && root.islandRect.r !== undefined)
                              ? root.islandRect.r : Theme.islandRadius


  property bool latchHull: true


  property bool liveContent: false


  property bool stretchToIsland: false


  property string screenName: root.parent && root.parent.screenName !== undefined
                              ? root.parent.screenName : ""

  readonly property bool islandCapable:
    root.islandAware && !root.detached && !root.vertical
    && (root.islandRectLocal !== null
        || ((Theme.islandsMode || Theme.pillMode) && root.screenName !== "" && root.edge === Theme.barPosition
            && Math.abs(root.faceOffset - Theme.barFace) < 0.5))

  readonly property string islandSide: {
    if (root.island !== "") return root.island
    if (root.moduleId !== "") {
      const s = Theme.popupIsland(root.moduleId, "")
      if (s !== "") return s
    }

    if (Theme.pillMode) return "center"
    if (root.align === "end") return "right"
    if (root.align === "start") return "left"
    return IslandState.nearestSide(root.screenName,
             root.alignCenter >= 0 ? root.alignCenter : root.hostWidth / 2)
  }
  readonly property var islandRect: {
    if (!root.islandCapable) return null
    if (root.islandRectLocal !== null) return root.islandRectLocal
    return root.screenName !== "" ? IslandState.rectFor(root.screenName, root.islandSide) : null
  }
  readonly property bool islandActive: root.islandRect !== null


  readonly property bool hullNow: root.islandActive
    && (root.islandStyle === "hull"
        || (root.islandStyle === "auto"
            && root.scaledWidth + 2 * (root.islandRadius + root.flare) > (root.islandRect ? root.islandRect.w : 0)))
  property bool hullLatch: false


  property bool reopening: false
  onHullNowChanged: {
    if (!root.shown) {
      root.hullLatch = root.hullNow
    } else if (root.liveContent && root.islandActive) {


      root.reopening = (root.hullNow !== root.hullLatch)
    }
  }
  onShownChanged: {
    if (!root.shown) {
      root.hullLatch = root.hullNow
      root.reopening = false
    }
  }


  readonly property bool hostReady: root.parent && root.parent.fusedReady !== undefined
                                    ? root.parent.fusedReady : true
  readonly property bool effOpen: root.open && !root.reopening && root.hostReady
  Component.onCompleted: {
    root.hullLatch = root.hullNow
    root.registerGlass()
    root.animSpring = root.effOpen ? 1 : 0
  }
  readonly property bool hull: (root.latchHull ? root.hullLatch : root.hullNow) && root.islandActive
  readonly property bool hang: root.islandActive


  property real hullOpen: root.effOpen ? 1 : 0
  Behavior on hullOpen {
    enabled: !root.instantResize && !root.snapResize
    NumberAnimation {
      duration: Theme.animDuration(root.effOpen ? root.duration : Math.round(root.duration * 0.7))
      easing.type: root.effOpen ? Easing.OutCubic : Easing.InOutCubic
    }
  }

  readonly property real hullProgress:
    (root.instantResize || root.snapResize) ? root.progress : root.hullOpen


  readonly property real hullFullWTarget:
    (root.islandActive && root.islandRect) ? Math.max(root.islandRect.w, root.scaledWidth) : 0
  readonly property real hullLeftFullTarget: {
    if (!root.islandActive) return 0
    const A = root.islandRect
    const W = root.hullFullWTarget
    let v
    if (root.islandSide === "right") v = A.x + A.w - W
    else if (root.islandSide === "left") v = A.x
    else v = A.x + A.w / 2 - W / 2

    const m = root.islandRectLocal !== null ? 0 : 8
    if (root.hostWidth > 0) v = Math.min(root.hostWidth - m - W, v)
    return Math.max(m, v)
  }


  readonly property bool hullSmooth: root.liveContent && root.shown
  property real hullFullW: root.hullFullWTarget
  property real hullLeftFull: root.hullLeftFullTarget
  Behavior on hullFullW {
    enabled: root.hullSmooth
    NumberAnimation { duration: Theme.animDuration(160); easing.type: Easing.OutCubic }
  }
  Behavior on hullLeftFull {
    enabled: root.hullSmooth
    NumberAnimation { duration: Theme.animDuration(160); easing.type: Easing.OutCubic }
  }


  readonly property real hullLeft: (root.hull && root.islandRect)
    ? Math.round(root.islandRect.x + (root.hullLeftFull - root.islandRect.x) * root.hullProgress) : 0
  readonly property real hullRight: (root.hull && root.islandRect)
    ? Math.round((root.islandRect.x + root.islandRect.w)
      + (root.hullLeftFull + root.hullFullW - (root.islandRect.x + root.islandRect.w)) * root.hullProgress)
    : 0
  readonly property real hullCardW: root.hullRight - root.hullLeft

  readonly property real hullExtra: (root.hull && root.islandRect) ? root.islandRect.h : 0


  readonly property real hullContentW: root.hull
    ? (root.stretchToIsland ? root.hullFullW : root.scaledWidth) : root.scaledWidth
  readonly property real hullContentX: root.hull
    ? Math.round(root.hullLeftFull + (root.hullFullW - root.hullContentW) / 2) - root.hullLeft : 0

  readonly property real contentLogicalWidth:
    (root.hull && root.stretchToIsland && root.scaleFactor > 0)
      ? Math.max(root.panelWidth, root.hullFullW / root.scaleFactor)
      : root.panelWidth + (root.scaleFactor > 0 ? (root.startBridge + root.endBridge) / root.scaleFactor : 0)


  readonly property real hullBackdropX: root.hull ? root.hullLeftFull - root.hullLeft : 0

  readonly property real hullRadius:
    root.islandRadius + (root.bodyRadius - root.islandRadius) * root.hullProgress


  property bool floatWin: Theme.floatWindows && root.islandRectLocal === null


  property real hostOriginX: 0

  readonly property var barSpan: (root.screenName !== "" && !root.vertical && Theme.barFloating
                                  && !Theme.islandsMode && !Theme.pillMode && root.islandRectLocal === null)
                                 ? IslandState.spanFor(root.screenName) : null
  readonly property bool floatBar: root.barSpan !== null
    && (root.rawPos + root.hostOriginX < root.barSpan.x + 1
        || root.rawPos + root.hostOriginX + root.fullAlong > root.barSpan.x + root.barSpan.w - 1)

  property bool detached: (root.parent ? root.parent.detached === true : false) || root.floatWin || root.floatMid || root.floatBar


  readonly property real floatShift: ((root.floatWin || root.floatBar) && root.detached && !root.hull) ? Theme.windowGap : 0


  readonly property bool inputLive: root.open || root.progress > 0.001
  readonly property real shiftX: root.vertical ? (root.edge === "left" ? root.floatShift : -root.floatShift) : 0
  readonly property real shiftY: root.vertical ? 0 : (root.edge === "top" ? root.floatShift : -root.floatShift)


  readonly property real startInset: root.hull ? 0 : (root.fusedStart ? root.startBridge : (root.effFlareStart ? root.flare : 0))
  readonly property real endInset: root.hull ? 0 : (root.fusedEnd ? root.endBridge : (root.effFlareEnd ? root.flare : 0))

  // ─── Fusión con el marco ───────────────────────────────────────


  property bool fuseFrame: Theme.frameFuse
  readonly property bool frameGapMode: Theme.frameBorderActive || (Theme.frameOn && !Theme.frameCurved)
  property real frameGap: 15
  readonly property bool fuseOk: root.fuseFrame && Theme.frameBorderActive
    && !root.detached && !root.hull && !root.hang && !root.frameGapMode

  readonly property real flushMargin: Theme.barEdge + Theme.frameSideArm
  readonly property real edgeMargin: root.frameGapMode
    ? Math.max(root.alignMargin, root.flushMargin + Theme.frameCornerRadius + root.frameGap)
    : root.alignMargin


  readonly property real fullAlong: root.alongLength
    + (root.flareStart ? root.flare : 0) + (root.flareEnd ? root.flare : 0)
  readonly property real rawPos: {
    if (root.align === "start") return root.edgeMargin
    if (root.align === "center") {
      const c = root.alignCenter >= 0 ? root.alignCenter : root.alongHost / 2
      return Math.max(root.edgeMargin,
                      Math.min(root.alongHost - root.edgeMargin - root.fullAlong, c - root.fullAlong / 2))
    }
    return root.alongHost - root.edgeMargin - root.fullAlong
  }
  property real fuseReach: (root.alignMargin - root.flushMargin) + root.flare + 28
  property real fuseHold: 8

  readonly property real bodyStartIdeal: root.rawPos + (root.flareStart ? root.flare : 0)
  readonly property real bodyEndIdeal: root.rawPos + root.fullAlong - (root.flareEnd ? root.flare : 0)
  readonly property real gapStart: root.bodyStartIdeal - root.flushMargin
  readonly property real gapEnd: (root.alongHost - root.flushMargin) - root.bodyEndIdeal

  property bool fusedStartHeld: false
  property bool fusedEndHeld: false
  readonly property bool fusedStart: root.fuseOk
    && root.gapStart <= root.fuseReach + (root.fusedStartHeld ? root.fuseHold : 0)
  readonly property bool fusedEnd: root.fuseOk
    && root.gapEnd <= root.fuseReach + (root.fusedEndHeld ? root.fuseHold : 0)
  onFusedStartChanged: root.fusedStartHeld = root.fusedStart
  onFusedEndChanged: root.fusedEndHeld = root.fusedEnd

  property real fuseBridgeMax: 0
  readonly property bool fusedBoth: root.fusedStart && root.fusedEnd
  readonly property real startBridge: (!root.fusedStart || root.vertical) ? 0
    : Math.max(0, root.fusedBoth ? Math.round(root.gapStart) : Math.min(Math.round(root.gapStart), root.fuseBridgeMax))
  readonly property real endBridge: (!root.fusedEnd || root.vertical) ? 0
    : Math.max(0, root.fusedBoth ? Math.round(root.gapEnd) : Math.min(Math.round(root.gapEnd), root.fuseBridgeMax))
  readonly property bool effFlareStart: root.flareStart && !root.fusedStart
  readonly property bool effFlareEnd: root.flareEnd && !root.fusedEnd


  readonly property real frameFillet: (root.fusedStart || root.fusedEnd)
    ? Math.max(0, Math.min(Theme.frameCornerRadius, root.depth, root.alongLength / 2)) : 0


  readonly property real farStartRadius: root.fusedStart ? 0 : root.cornerRadius
  readonly property real farEndRadius:   root.fusedEnd   ? 0 : root.cornerRadius

  readonly property real radTL: root.farStartRadius
  readonly property real radBR: root.farEndRadius
  readonly property real radTR: root.vertical ? root.farStartRadius : root.farEndRadius
  readonly property real radBL: root.vertical ? root.farEndRadius : root.farStartRadius

  // ─── Escala ────────────────────────────────────────────────────


  property real uiScale: Theme.windowScale

  property bool fitScreen: true
  readonly property real fitScale: {
    const p = root.parent
    if (!root.fitScreen || !p || p.height <= 0 || p.width <= 0
        || root.contentHeight <= 0 || root.panelWidth <= 0)
      return root.uiScale
    if (root.vertical) {


      const byHeight = (p.height - 16 - root.startInset - root.endInset) / root.contentHeight
      const byWidth  = (p.width - root.faceOffset - 16) / root.panelWidth
      return Math.min(byHeight, byWidth)
    }
    return (p.height - root.faceOffset - 16) / root.contentHeight
  }
  readonly property real scaleFactor:
    root.uiScale > 1 ? Math.max(1, Math.min(root.uiScale, root.fitScale)) : root.uiScale

  readonly property real scaledWidth: Math.round(root.panelWidth * root.scaleFactor)
  readonly property real scaledHeight: Math.round(root.contentHeight * root.scaleFactor)

  // ─── Animación ─────────────────────────────────────────────────


  readonly property real alongLength: root.vertical ? root.scaledHeight : root.scaledWidth
  readonly property real depthFull: root.vertical ? root.scaledWidth : root.scaledHeight


  property real grown: root.snapResize ? root.openAmount * root.depthFull
                                       : (root.effOpen ? root.depthFull : 0)


  property bool instantResize: false


  property bool snapResize: false
  property real openAmount: root.effOpen ? 1 : 0
  Behavior on openAmount {
    enabled: root.snapResize
    NumberAnimation {
      duration: Theme.animDuration(root.effOpen ? root.duration : Math.round(root.duration * 0.7))
      easing.type: root.effOpen ? Easing.OutCubic : Easing.InOutCubic
    }
  }

  Behavior on grown {
    enabled: !root.instantResize && !root.snapResize
    NumberAnimation {
      duration: Theme.animDuration(root.effOpen ? root.duration : Math.round(root.duration * 0.7))
      easing.type: root.effOpen ? Easing.OutCubic : Easing.InOutCubic
    }
  }


  readonly property real depthRaw: root.hull ? root.grown + root.hullExtra
    : (root.detached ? root.depthFull : root.grown)
  readonly property real depth: root.faceAtEnd ? Math.round(root.depthRaw) : root.depthRaw

  readonly property bool shown: root.grown > 0.5
  readonly property bool hovered: hover.hovered

  readonly property real progress:
    root.depthFull > 0 ? Math.max(0, Math.min(1, root.grown / root.depthFull)) : 0


  readonly property real cornerRadius: root.hull
    ? Math.max(0, Math.min(root.hullRadius, root.depth / 2, root.hullCardW / 2))
    : root.frameGapMode
      ? Math.max(0, Math.min(Math.max(root.bodyRadius, Theme.frameCornerRadius + root.frameGap),
                             root.depth / 2, root.alongLength / 2))
      : Math.max(0, Math.min(root.bodyRadius, root.depth / 2, root.alongLength / 2))


  default property alias content: contentArea.data

  property alias backdrop: backdropHolder.data
  readonly property bool hasBackdrop: backdropHolder.children.length > 0


  implicitWidth: root.vertical ? root.depthFull
    : (root.hull ? root.hullCardW : root.scaledWidth + root.startInset + root.endInset)
  implicitHeight: root.vertical ? root.scaledHeight + root.startInset + root.endInset : root.depthFull
  width: root.vertical ? root.depth : root.implicitWidth
  height: root.vertical ? root.implicitHeight : root.depth


  visible: root.hull ? root.shown : (!root.detached || root.progress > 0.001)


  readonly property real glassFade: {


    const p = root.styleAnim ? root.animSpring : root.progress
    const t = Math.max(0, Math.min(1, p / (root.styleAnim ? root.styleFadeSpan : 0.4)))
    return t * t * (3 - 2 * t)
  }
  opacity: (Theme.glassMode || root.styleAnim) ? root.glassFade : (root.detached ? root.progress : 1)

  // ─── Animación de las ventanas flotantes ────────────────────────


  readonly property bool styleAnim: (Theme.glassMode || Theme.floatWindows) && root.detached && !root.hull

  readonly property string animStyle: Theme.windowAnimStyle
  readonly property bool animSpringy: root.animStyle === "spring"

  readonly property real styleMinScale: ({ spring: 0.72, smooth: 0.94, zoom: 0.78, pop: 0.55, slide: 1, fade: 0.98 })[root.animStyle] ?? 0.72
  readonly property real styleSlide: ({ spring: 22, smooth: 14, zoom: 0, pop: 0, slide: 56, fade: 0 })[root.animStyle] ?? 22
  readonly property real styleFadeSpan: ({ spring: 0.55, smooth: 0.5, zoom: 0.5, pop: 0.35, slide: 0.6, fade: 1 })[root.animStyle] ?? 0.55
  readonly property real styleOpenMs: ({ spring: 950, smooth: 300, zoom: 340, pop: 420, slide: 320, fade: 220 })[root.animStyle] ?? 950
  readonly property bool styleFromEdge: root.animStyle !== "zoom" && root.animStyle !== "fade"

  // ── Interpolación ─────


  property real animSpring: 0
  property real animSpringX: 0
  property real gsFrom: 0
  property real gsClock: 0
  property bool gsOpening: false
  readonly property real gsResponse: 0.46
  readonly property real gsDamping: 0.46
  readonly property real gsSpanSec: 0.95
  readonly property real gsLag: 0.045
  readonly property real gsSquash: root.animSpringy ? 0.55 : 0
  readonly property real gsSwell: 0.06
  readonly property real gsMinScale: root.styleMinScale

  function gsEaseOut(u) {
    const q = 1 - u
    if (root.animStyle === "pop") {
      const c1 = 2.2
      const w = u - 1
      return 1 + (c1 + 1) * w * w * w + c1 * w * w
    }
    if (root.animStyle === "zoom") return 1 - q * q * q * q
    return 1 - q * q * q
  }

  function gsStep(u, opening) {
    u = Math.max(0, Math.min(1, u))
    if (opening) {
      if (!root.animSpringy) return 1 - (1 - root.gsFrom) * (1 - root.gsEaseOut(u))
      const w  = 2 * Math.PI / root.gsResponse
      const z  = root.gsDamping
      const wd = w * Math.sqrt(1 - z * z)
      const t  = u * root.gsSpanSec
      const g  = Math.exp(-z * w * t) * (Math.cos(wd * t) + (z * w / wd) * Math.sin(wd * t))
      return 1 - (1 - root.gsFrom) * g
    }

    const k = root.animSpringy ? 0.22 : 0
    const swell = u < k ? Math.sin(Math.PI * u / k) * root.gsSwell : 0
    const v = Math.max(0, (u - k * 0.6) / (1 - k * 0.6))
    const e = v * v * (3 - 2 * v)
    return root.gsFrom * (1 - e + swell)
  }
  onGsClockChanged: if (root.styleAnim) {
    root.animSpring  = root.gsStep(root.gsClock, root.gsOpening)
    root.animSpringX = root.gsStep(root.gsClock - root.gsLag, root.gsOpening)
  }

  NumberAnimation {
    id: gsAnim
    target: root
    property: "gsClock"
    from: 0
    to: 1
    easing.type: Easing.Linear
    onFinished: { root.animSpring = root.gsOpening ? 1 : 0; root.animSpringX = root.animSpring }
  }
  function gsRetarget() {

    const dur = root.gsOpening ? Theme.animDuration(root.styleOpenMs)
                               : Theme.animDuration(Math.max(root.animSpringy ? 300 : 160, Math.round(root.duration * 0.8)))
    gsAnim.stop()
    if (!root.styleAnim || dur <= 0) { root.animSpring = root.effOpen ? 1 : 0; root.animSpringX = root.animSpring; return }
    root.gsFrom = root.animSpring
    root.gsOpening = root.effOpen
    gsAnim.duration = dur
    gsAnim.restart()
  }
  onEffOpenChanged: root.gsRetarget()
  onStyleAnimChanged: { gsAnim.stop(); root.animSpring = root.effOpen ? 1 : 0; root.animSpringX = root.animSpring }

  readonly property real slideDist: root.styleAnim ? (1 - root.animSpring) * root.styleSlide : 0

  readonly property real slideX: root.vertical ? (root.edge === "left" ? -root.slideDist : root.slideDist) : 0
  readonly property real slideY: root.vertical ? 0 : (root.edge === "top" ? -root.slideDist : root.slideDist)
  transformOrigin: (!root.styleAnim || !root.styleFromEdge) ? Item.Center
    : (root.vertical ? (root.edge === "left" ? Item.Left : Item.Right)
                     : (root.edge === "top" ? Item.Top : Item.Bottom))

  scale: root.detached ? (root.styleAnim ? root.gsMinScale + (1 - root.gsMinScale) * root.animSpring
                                          : 0.94 + 0.06 * root.progress) : 1
  transform: [


    Scale {
      origin.x: root.blurOx
      origin.y: root.blurOy
      xScale: root.styleAnim && !root.vertical ? 1 + root.gsSquash * (root.animSpringX - root.animSpring) / root.gsMinScale : 1
      yScale: root.styleAnim && root.vertical ? 1 + root.gsSquash * (root.animSpringX - root.animSpring) / root.gsMinScale : 1
    },
    Translate { x: root.shiftX + root.slideX; y: root.shiftY + root.slideY }
  ]

  // ─── Colocación automática ─────────────────────────────────────
  property string align: "end"

  property real alignMargin: 10


  property real alignCenter: -1

  readonly property real hostWidth: root.parent ? root.parent.width : 0
  readonly property real hostHeight: root.parent ? root.parent.height : 0
  readonly property real alongHost: root.vertical ? root.hostHeight : root.hostWidth


  readonly property real alongSize: root.vertical ? root.height : root.width

  readonly property real placedAlong: {

    if (root.hull && root.islandRect) return root.hullLeft
    let v
    if (root.hang && root.islandRect) {


      const A = root.islandRect
      const lo = A.x + root.islandRadius
      const hi = Math.max(lo, A.x + A.w - root.islandRadius - root.alongSize)
      if (root.align === "end") v = hi
      else if (root.align === "start") v = lo
      else v = (root.alignCenter >= 0 ? root.alignCenter : A.x + A.w / 2) - root.alongSize / 2
      return Math.round(Math.max(lo, Math.min(hi, v)))
    }

    if (root.fusedStart) return Math.round(root.flushMargin)
    if (root.fusedEnd) return Math.round(root.alongHost - root.flushMargin - root.alongSize)
    const m = root.edgeMargin
    if (root.align === "start") {
      v = m
    } else if (root.align === "center") {
      const c = root.alignCenter >= 0 ? root.alignCenter : root.alongHost / 2
      v = Math.max(m, Math.min(root.alongHost - m - root.alongSize, c - root.alongSize / 2))
    } else {
      v = root.alongHost - m - root.alongSize
    }
    return Math.round(v)
  }


  readonly property real placedDepth: {
    if (root.floatMid)
      return Math.round(root.vertical ? (root.hostWidth - root.width) / 2 : (root.hostHeight - root.height) / 2)

    if (root.hull && root.islandRect)
      return root.edge === "bottom" ? root.islandRect.y + root.islandRect.h - root.height
                                    : root.islandRect.y
    if (root.edge === "bottom") return root.hostHeight - root.faceOffset - root.height
    if (root.edge === "right")  return root.hostWidth - root.faceOffset - root.width
    return root.faceOffset
  }

  x: root.vertical ? root.placedDepth : root.placedAlong
  y: root.vertical ? root.placedAlong : root.placedDepth

  // ─── Forma ─────────────────────────────────────────────────────


  function n(v) { return v.toFixed(2) }

  function pt(u, v) {
    const d = root.depth
    if (root.edge === "bottom") return n(u) + " " + n(d - v)
    if (root.edge === "left")   return n(v) + " " + n(u)
    if (root.edge === "right")  return n(d - v) + " " + n(u)
    return n(u) + " " + n(v)
  }


  function corner(cu, cv, e1u, e1v, e2u, e2v, r, sweep) {
    const E = root.pt(cu + e2u * r, cv + e2v * r)
    if (!Theme.cozy || r < 2)
      return " A " + n(r) + " " + n(r) + " 0 0 " + sweep + " " + E
    const rr = Math.round(r)
    const k = rr >= 12 ? 3 : (rr >= 6 ? 2 : 1)
    const P = (al, be) => root.pt(cu + e1u * al + e2u * be, cv + e1v * al + e2v * be)
    let out = ""
    for (let i = 0; i < k; i++) {
      const m = (i + 0.5) / k * rr
      const a = Math.max(0, Math.round(rr - Math.sqrt(Math.max(0, rr * rr - (rr - m) * (rr - m)))))
      out += " L " + P(a, Math.round(i * rr / k)) + " L " + P(a, Math.round((i + 1) * rr / k))
    }
    return out + " L " + E
  }

  readonly property string svgPath: {
    const d = root.depth
    if (d < 1) return ""
    const fs = (root.effFlareStart && !root.detached) ? Math.min(root.flare, d / 2) : 0
    const fe = (root.effFlareEnd   && !root.detached) ? Math.min(root.flare, d / 2) : 0
    const rb = root.cornerRadius
    const u0 = root.startInset
    const u1 = u0 + root.alongLength
    const mirrored = root.edge === "bottom" || root.edge === "left"
    const concave = mirrored ? 0 : 1
    const convex  = mirrored ? 1 : 0


    if (root.hull) {
      const w = root.hullCardW
      const rf = Math.max(0, Math.min(root.islandRadius, d / 2, w / 2))
      let h = "M " + root.pt(0, rf)
      h += " L " + root.pt(0, d - rb)
      h += root.corner(0, d, 0, -1, 1, 0, rb, convex)
      h += " L " + root.pt(w - rb, d)
      h += root.corner(w, d, -1, 0, 0, -1, rb, convex)
      h += " L " + root.pt(w, rf)
      h += root.corner(w, 0, 0, 1, -1, 0, rf, convex)
      h += " L " + root.pt(rf, 0)
      h += root.corner(0, 0, 1, 0, 0, 1, rf, convex)
      h += " Z"
      return h
    }


    if (root.detached) {
      let q = "M " + root.pt(u0, rb)
      q += " L " + root.pt(u0, d - rb)
      q += root.corner(u0, d, 0, -1, 1, 0, rb, convex)
      q += " L " + root.pt(u1 - rb, d)
      q += root.corner(u1, d, -1, 0, 0, -1, rb, convex)
      q += " L " + root.pt(u1, rb)
      q += root.corner(u1, 0, 0, 1, -1, 0, rb, convex)
      q += " L " + root.pt(u0 + rb, 0)
      q += root.corner(u0, 0, 1, 0, 0, 1, rb, convex)
      q += " Z"
      return q
    }

    const ff = root.frameFillet
    const us = root.fusedStart ? 0 : u0
    const ue = root.fusedEnd ? u1 + root.endBridge : u1
    let p = "M " + root.pt(us - fs, 0)
    if (fs > 0) p += root.corner(us, 0, -1, 0, 0, 1, fs, concave)
    if (root.fusedStart && ff > 0) {
      p += " L " + root.pt(us, d + ff)
      p += root.corner(us, d, 0, 1, 1, 0, ff, concave)
    } else {
      p += " L " + root.pt(us, d - rb)
      p += root.corner(us, d, 0, -1, 1, 0, rb, convex)
    }
    if (root.fusedEnd && ff > 0) {
      p += " L " + root.pt(ue - ff, d)
      p += root.corner(ue, d, -1, 0, 0, 1, ff, concave)
      p += " L " + root.pt(ue, fe)
    } else {
      p += " L " + root.pt(ue - rb, d)
      p += root.corner(ue, d, -1, 0, 0, -1, rb, convex)
      p += " L " + root.pt(ue, fe)
    }
    if (fe > 0) p += root.corner(ue, 0, 0, 1, 1, 0, fe, concave)
    p += " Z"
    return p
  }


  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.AllButtons
  }

  HoverHandler { id: hover }


  Shape {
    anchors.fill: parent
    anchors.topMargin: Theme.shadowY
    anchors.bottomMargin: -Theme.shadowY
    visible: Theme.cozy && !root.detachedFlat
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      fillColor: Theme.shadowInk
      strokeWidth: -1
      strokeColor: "transparent"
      PathSvg { path: root.svgPath }
    }
  }

  // ─── Blur real (compositor) ─────────────────────────────────────


  readonly property var hostWindow: QsWindow.window
  property var registeredIn: null
  function registerGlass() {
    const w = root.hostWindow
    if (w === root.registeredIn) return
    const old = root.registeredIn
    if (old && old.glassPanels !== undefined)
      old.glassPanels = old.glassPanels.filter(p => p !== root)
    root.registeredIn = null
    if (w && w.glassPanels !== undefined) {
      w.glassPanels = w.glassPanels.filter(p => p !== root).concat([root])
      root.registeredIn = w
    }
  }
  onHostWindowChanged: root.registerGlass()
  Component.onDestruction: {
    const w = root.registeredIn
    if (w && w.glassPanels !== undefined)
      w.glassPanels = w.glassPanels.filter(p => p !== root)
  }


  function windowPos() {
    let px = 0, py = 0
    let it = root
    while (it) { px += it.x; py += it.y; it = it.parent }
    return Qt.point(px, py)
  }
  readonly property point winPos: root.windowPos()


  readonly property real blurMin: root.styleAnim ? 0.08 : (root.effOpen ? 0.02 : 0.4)
  readonly property bool blurOn: root.glassBlur > 0.5 && root.shown
                                 && root.progress > root.blurMin
                                 && root.visible && !Theme.shellPerf


  property real blurSeam: root.detached ? 0 : Theme.glassSeamInset
  readonly property real seamPx: Math.max(0, Math.min(root.blurSeam,
    (root.vertical ? clipArea.width : clipArea.height) / 2))


  readonly property real blurK: root.detached
    ? Math.min(1, root.scale) * (Theme.glassMode ? 0.88 + 0.12 * root.glassFade : 1) : 1

  readonly property real blurOx: (!root.styleAnim || !root.styleFromEdge) ? root.width / 2
    : (root.vertical ? (root.edge === "left" ? 0 : root.width) : root.width / 2)
  readonly property real blurOy: (!root.styleAnim || !root.styleFromEdge) ? root.height / 2
    : (root.vertical ? root.height / 2 : (root.edge === "top" ? 0 : root.height))
  readonly property real blurLx: clipArea.x + (root.edge === "left" ? root.seamPx : 0)
  readonly property real blurLy: clipArea.y + (root.edge === "top"  ? root.seamPx : 0)
  readonly property real blurX: root.winPos.x + root.shiftX + root.slideX + root.blurOx + (root.blurLx - root.blurOx) * root.blurK
  readonly property real blurY: root.winPos.y + root.shiftY + root.slideY + root.blurOy + (root.blurLy - root.blurOy) * root.blurK
  readonly property real blurW: (clipArea.width  - (root.vertical ? root.seamPx : 0)) * root.blurK
  readonly property real blurH: (clipArea.height - (root.vertical ? 0 : root.seamPx)) * root.blurK
  readonly property real blurTL: ((root.detached || root.edge === "bottom" || root.edge === "right") ? root.radTL : 0) * root.blurK
  readonly property real blurTR: ((root.detached || root.edge === "bottom" || root.edge === "left")  ? root.radTR : 0) * root.blurK
  readonly property real blurBL: ((root.detached || root.edge === "top"    || root.edge === "right") ? root.radBL : 0) * root.blurK
  readonly property real blurBR: ((root.detached || root.edge === "top"    || root.edge === "left")  ? root.radBR : 0) * root.blurK

  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      fillColor: root.color


      strokeWidth: Theme.cozy ? Theme.inkWidth : (root.outline ? Theme.bw1 : -1)
      strokeColor: Theme.cozy ? Theme.ink : (root.outline ? Theme.edge : "transparent")
      joinStyle: Theme.cozy ? ShapePath.MiterJoin : ShapePath.RoundJoin
      PathSvg { path: root.svgPath }
    }
  }


  Item {
    id: clipArea
    x: root.vertical ? 0 : root.startInset - root.startBridge
    y: root.vertical ? root.startInset : 0
    width: root.vertical ? root.width : (root.hull ? root.width : root.scaledWidth + root.startBridge + root.endBridge)
    height: root.vertical ? root.scaledHeight : root.height
    clip: true

    // ── Fondo decorativo ────────────────────────────────────────


    Item {
      id: backdropLayer
      anchors.fill: parent
      visible: root.hasBackdrop && !Theme.shellPerf
      opacity: contentArea.opacity
      layer.enabled: root.hasBackdrop && !Theme.shellPerf
      layer.effect: MultiEffect {
        maskEnabled: true
        maskSource: backdropMask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
      }


      Item {
        id: backdropHolder
        width: root.hull ? root.hullFullW : root.scaledWidth + root.startBridge + root.endBridge
        height: root.scaledHeight
        x: root.hull ? root.hullBackdropX
                     : (root.edge === "right" ? clipArea.width - root.scaledWidth : 0)
        y: root.edge === "bottom" ? clipArea.height - root.scaledHeight - root.hullExtra
                                  : root.hullExtra
      }
    }

    Item {
      id: backdropMask
      width: clipArea.width
      height: clipArea.height
      layer.enabled: !Theme.shellPerf
      visible: false

      Rectangle {
        anchors.fill: parent
        color: "black"

        topLeftRadius:     (root.detached || root.edge === "bottom" || root.edge === "right") ? root.radTL : 0
        topRightRadius:    (root.detached || root.edge === "bottom" || root.edge === "left")  ? root.radTR : 0
        bottomLeftRadius:  (root.detached || root.edge === "top"    || root.edge === "right") ? root.radBL : 0
        bottomRightRadius: (root.detached || root.edge === "top"    || root.edge === "left")  ? root.radBR : 0
      }
    }


    Item {
      id: contentMask
      width: clipArea.width
      height: clipArea.height
      layer.enabled: !Theme.shellPerf
      visible: false

      Rectangle {
        x: contentArea.x
        y: contentArea.y
        width: Math.round(root.contentLogicalWidth * root.scaleFactor)
        height: Math.round(root.contentHeight * root.scaleFactor)
        color: "black"
        topLeftRadius:     (root.detached || root.edge === "bottom" || root.edge === "right") ? root.radTL : 0
        topRightRadius:    (root.detached || root.edge === "bottom" || root.edge === "left")  ? root.radTR : 0
        bottomLeftRadius:  (root.detached || root.edge === "top"    || root.edge === "right") ? root.radBL : 0
        bottomRightRadius: (root.detached || root.edge === "top"    || root.edge === "left")  ? root.radBR : 0
      }
    }


    Item {
      id: contentClip
      anchors.fill: parent


      layer.enabled: !Theme.shellPerf
      layer.smooth: true
      layer.effect: MultiEffect {
        maskEnabled: true
        maskSource: contentMask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
      }

      Item {
        id: contentArea
        width: root.contentLogicalWidth
        height: root.contentHeight


        x: Math.round(root.hull ? root.hullContentX
                     : (root.edge === "right" ? clipArea.width - root.scaledWidth : 0))
        y: Math.round(root.edge === "bottom" ? clipArea.height - root.scaledHeight - root.hullExtra
                                  : root.hullExtra)
        scale: root.scaleFactor
        transformOrigin: Item.TopLeft


        opacity: (Theme.glassMode || root.styleAnim) ? Math.max(0, Math.min(1, (root.progress - 0.05) / 0.35))
                 : (root.detached ? 1 : Math.max(0, Math.min(1, (root.progress - 0.15) / 0.5)))
      }
    }
  }
}
