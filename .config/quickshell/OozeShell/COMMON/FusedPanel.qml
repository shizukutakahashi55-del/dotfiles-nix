// FusedPanel — el "cuerpo" de cualquier popup que cuelga de la barra.
//
// Qué hace:
//   • Dibuja UNA sola forma (Shape) con el color exacto de la barra, sin
//     bordes, con dos curvas cóncavas donde se une a la barra y esquinas
//     redondeadas en el lado opuesto. Visualmente la barra "chorrea": es
//     la misma pieza, no una tarjeta flotante.
//   • Anima su tamaño desde 0 (spawn desde la barra). El contenido NO se
//     aplasta: tiene tamaño fijo y se va revelando desde la cara de la barra.
//   • `shown` sigue siendo true mientras dura la animación de cierre, así
//     la ventana que lo contiene puede esperar a que termine antes de
//     ocultarse (antes desaparecía de golpe).
//
// ─── Los 4 bordes (edge) ──────────────────────────────────────────────
//   `edge` dice de qué lado de la pantalla cuelga el panel. Por defecto es
//   Theme.barPosition, así que TODOS los popups siguen a la barra solos:
//
//     top     nace del borde de arriba y crece hacia ABAJO
//     bottom  nace del borde de abajo  y crece hacia ARRIBA
//     left    nace del borde izquierdo y crece hacia la DERECHA
//     right   nace del borde derecho   y crece hacia la IZQUIERDA
//
//   Horizontal (top/bottom): el cuerpo mide panelWidth de ancho fijo y lo
//   que se anima es el ALTO; las curvas cóncavas quedan a izquierda y derecha.
//   Vertical (left/right): el cuerpo mide contentHeight de alto fijo y lo
//   que se anima es el ANCHO; las curvas quedan arriba y abajo.
//   El contenido nunca se rota: se dibuja siempre derecho.
//
//   Para el que necesite razonar sobre la orientación:
//     vertical    → la barra está a un costado
//     faceAtEnd   → la cara de la barra está abajo o a la derecha (el
//                   degradado de un fondo debe ser sólido de ESE lado)
//
// ─── Modo Islas (Theme.islandsMode) ───────────────────────────────────
//   Sin fondo de barra, el panel ya no cuelga de una barra: nace de la ISLA
//   (píldora) que le corresponde. Cada módulo de la barra publica su
//   rectángulo en IslandState y acá se decide cómo nacer, según el ancho:
//
//     hull   el panel es más ancho que la isla (menús, ajustes, launcher…).
//            La isla MISMA se estira: su rectángulo crece en ancho y alto,
//            y el radio de las esquinas pasa del de la isla (13) al del panel
//            (20), mientras el contenido aparece con un fundido. La tarjeta
//            queda DETRÁS de la isla (FusedWindow baja a la capa Top), así
//            los botones de la isla siguen visibles y usables arriba del
//            panel, como su "cabecera". Al cerrar, hace el camino inverso.
//     hang   el panel es bastante más angosto que la isla (tooltips, gotas):
//            cuelga de la cara inferior de la isla con las curvas cóncavas
//            de siempre, corrido para no salirse de ella.
//
//   Qué isla: `island` ("left" | "center" | "right"); vacío = según `align`
//   (start → left, end → right, center → la más cercana a alignCenter).
//   Se apaga con `islandAware: false` (FusedTip, que lo coloca su host).
//   Un panel detached, vertical, o que no cuelga de la barra (Walls con la
//   barra arriba) ignora las islas y se comporta como siempre.
//
// ─── Modo flotante (detached) ─────────────────────────────────────────
//   Con una ventana en fullscreen la barra se oculta, y un popup llamado
//   por teclado (o un toast) colgaría de una barra que no está: curvas
//   contra la nada y "naciendo" de un borde vacío. En ese caso el panel
//   se dibuja como una tarjeta FLOTANTE: sin curvas cóncavas, con las 4
//   esquinas redondeadas, y aparece con un fundido + escala en vez de
//   crecer desde el borde. NO cambia de lugar: el cuerpo queda exactamente
//   donde estaría pegado a la barra, así que solo parece desconectado.
//   Lo decide el padre: FusedWindow expone `detached` (fullscreen de su
//   pantalla) y el panel lo lee solo; se puede forzar con `detached: …`.
//
// ─── Colocación automática ────────────────────────────────────────────
//   El panel se coloca solo dentro de su padre (normalmente la ventana
//   completa de un FusedWindow):
//     • en profundidad: pegado a la cara de la barra (Theme.barOffset)
//     • a lo largo de la barra, según `align`:
//         "start"   → al inicio (izquierda / arriba), a alignMargin del borde
//         "center"  → centrado en alignCenter (o en el padre si es -1),
//                     sin salirse (alignMargin de cada borde)
//         "end"     → al final (derecha / abajo), a alignMargin del borde
//   Si el padre pone su propio x / y (ej. FusedTip), eso manda sobre esto.
//   Nunca uses anclas verticales/horizontales con este panel: alternar la
//   posición de la barra en caliente deja dos anclas activas y el panel
//   se estira a toda la pantalla.
//
// ─── Escala (Ajustes → Ventanas) ──────────────────────────────────────
//   panelWidth / contentHeight son medidas LÓGICAS (las de siempre: 420,
//   col.implicitHeight...). El panel las multiplica por `scaleFactor`
//   (Theme.windowScale) y dibuja el contenido con una transformación de
//   escala, así ningún popup necesita saber nada de esto. Si el panel
//   escalado no cabe en la pantalla, la ampliación se limita para que
//   entre (nunca reduce por debajo de la escala Normal por eso).
//
// ─── Fondo decorativo (backdrop) ──────────────────────────────────────
//   Lo que se declare en `backdrop` va DEBAJO del contenido, del tamaño del
//   cuerpo, y recortado con la misma silueta del panel (esquinas redondas
//   del lado correcto, según el borde). Lo usa Mpris para la portada:
//
//     FusedPanel {
//       backdrop: [ Image { anchors.fill: parent ... },
//                   Rectangle { anchors.fill: parent; gradient: ... } ]
//     }
//
// Uso:
//   FusedPanel {
//     open: algo
//     panelWidth: 400
//     contentHeight: col.implicitHeight + 36
//     align: "end"
//     alignMargin: 10
//     ColumnLayout { id: col; ... }     // hijos = contenido
//   }
import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import "../COMMON"

Item {
  id: root

  property bool open: false
  // (reservado) apaga la sombra dura si algún host la necesita plana
  property bool detachedFlat: false
  // Ancho / alto LÓGICOS del CUERPO (sin curvas y sin escala)
  property real panelWidth: 360
  property real contentHeight: 200

  // ─── Borde del que cuelga ──────────────────────────────────────
  property string edge: Theme.barPosition          // top | bottom | left | right
  readonly property bool vertical: root.edge === "left" || root.edge === "right"
  readonly property bool faceAtEnd: root.edge === "bottom" || root.edge === "right"
  // Distancia del borde de pantalla a la cara de la barra. Solo Walls lo
  // cambia (su borde es siempre el de abajo, sea cual sea la barra).
  property real faceOffset: Theme.barOffset

  // ─── Curvas y colores ──────────────────────────────────────────
  // "start"/"end" = los dos extremos a lo largo de la barra
  // (izquierda/derecha si es horizontal, arriba/abajo si es vertical)
  property bool flareStart: true
  property bool flareEnd: true
  property real flare: Theme.flare
  property real bodyRadius: Theme.panelRadius
  property color color: Theme.bg
  property int duration: Theme.animMs

  // ─── Islas ─────────────────────────────────────────────────────
  property bool islandAware: true
  property string island: ""                 // "" = automática (ver arriba)
  property string islandStyle: "auto"        // auto | hang | hull
  // Rectángulo de la isla en coordenadas del PADRE (no de pantalla). Lo usan
  // los hosts que no son una ventana a pantalla completa (tooltips de las
  // ventanas Left/Right, Dock): manda sobre IslandState y no exige modo Islas.
  property var islandRectLocal: null
  // Radio de las esquinas de la isla (el Dock, por ejemplo, usa otro)
  // (Si la isla publica su propio radio —píldoras— se usa ese, para que la
  //  tarjeta que crece detrás no asome por las esquinas de la píldora.)
  property real islandRadius: (root.islandRect !== null && root.islandRect.r !== undefined)
                              ? root.islandRect.r : Theme.islandRadius
  // true = hull/hang se decide con el panel cerrado y se congela mientras está
  // abierto. Los tooltips (liveContent) también lo congelan, pero si el texto
  // nuevo pide el otro modo, se cierran y se reabren en él.
  property bool latchHull: true
  // Contenido que cambia con el panel ABIERTO (tooltips: pasar de un ícono a
  // otro cambia el texto y con él el ancho). Con esto activo el modo (hull /
  // hang) sigue congelado mientras el panel está abierto —nunca cambia de
  // forma a mitad de camino—, y si el contenido nuevo pide el OTRO modo, el
  // panel se cierra, cambia de forma cerrado y se vuelve a abrir (ver
  // `reopening`). Además los cambios de ancho del hull se deslizan en vez
  // de saltar.
  property bool liveContent: false
  // Panel (hull) más angosto que la isla: en vez de dejar franjas lisas a los
  // lados del contenido, el contenido se estira al ancho de la tarjeta. Solo
  // para paneles cuyo contenido sigue el ancho del padre (ej. Mpris); si el
  // contenido tiene medidas fijas, dejalo apagado (queda centrado).
  property bool stretchToIsland: false
  // Pantalla de este panel (FusedWindow la expone en su contenedor; los
  // paneles que viven en otra ventana la pasan a mano)
  property string screenName: root.parent && root.parent.screenName !== undefined
                              ? root.parent.screenName : ""

  readonly property bool islandCapable:
    root.islandAware && !root.detached && !root.vertical
    && (root.islandRectLocal !== null
        || ((Theme.islandsMode || Theme.pillMode) && root.screenName !== "" && root.edge === Theme.barPosition
            && Math.abs(root.faceOffset - Theme.barOffset) < 0.5))

  readonly property string islandSide: {
    if (root.island !== "") return root.island
    // Modo Píldora: todo nace de la píldora central; solo el menú del Tray
    // pide "right" (su propia pastilla, ver TrayMenu).
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

  // hull o hang: se decide con el panel CERRADO y se congela mientras está
  // abierto (si la isla cambia de ancho a mitad de camino no cambia de forma)
  readonly property bool hullNow: root.islandActive
    && (root.islandStyle === "hull"
        || (root.islandStyle === "auto"
            && root.scaledWidth + 2 * (root.islandRadius + root.flare) > root.islandRect.w))
  property bool hullLatch: false
  // Cerrándose para cambiar de modo (solo liveContent). Es un estado que se
  // maneja a mano (no un binding sobre `shown`): `shown` sale de `grown` y
  // `grown` de `effOpen`, que depende de esto → un binding sería un lazo.
  property bool reopening: false
  onHullNowChanged: {
    if (!root.shown) {
      root.hullLatch = root.hullNow
    } else if (root.liveContent && root.islandActive) {
      // Abierto y el contenido pide otro modo → cerrar; si vuelve al modo
      // actual antes de terminar de cerrarse, se reabre desde donde va.
      root.reopening = (root.hullNow !== root.hullLatch)
    }
  }
  onShownChanged: {
    if (!root.shown) {
      root.hullLatch = root.hullNow
      root.reopening = false
    }
  }
  // `open` efectivo: el que pide el host, salvo mientras cambia de modo
  readonly property bool effOpen: root.open && !root.reopening
  Component.onCompleted: root.hullLatch = root.hullNow
  readonly property bool hull: (root.latchHull ? root.hullLatch : root.hullNow) && root.islandActive
  readonly property bool hang: root.islandActive && !root.hull

  // Geometría del "hull" (coordenadas del padre). La tarjeta va de la isla
  // (progreso 0) al panel completo (progreso 1) por sus DOS bordes.
  //
  // Avance HORIZONTAL del hull: solo abrir/cerrar. NO sale de `progress`
  // (= grown / depthFull): en un tooltip el texto cambia con el panel abierto
  // (otra ventana del taskbar, un título que se actualiza…) y, si el alto
  // crece, `grown` tarda `duration` en alcanzar a `depthFull`: `progress` cae
  // (ej. 33→48 px = 0.69) y con él el borde izquierdo de la tarjeta se
  // corría hacia la derecha y volvía, como un temblor. El alto de la tarjeta
  // sí sigue al contenido (grown); el ancho no.
  property real hullOpen: root.effOpen ? 1 : 0
  Behavior on hullOpen {
    enabled: !root.instantResize && !root.snapResize
    NumberAnimation {
      duration: root.effOpen ? root.duration : Math.round(root.duration * 0.7)
      easing.type: root.effOpen ? Easing.OutCubic : Easing.InOutCubic
    }
  }
  // instantResize / snapResize ya traen su propio criterio en `progress`
  readonly property real hullProgress:
    (root.instantResize || root.snapResize) ? root.progress : root.hullOpen

  // Objetivos (dónde tiene que terminar la tarjeta con este ancho de panel)
  readonly property real hullFullWTarget:
    root.islandActive ? Math.max(root.islandRect.w, root.scaledWidth) : 0
  readonly property real hullLeftFullTarget: {
    if (!root.islandActive) return 0
    const A = root.islandRect
    const W = root.hullFullWTarget
    let v
    if (root.islandSide === "right") v = A.x + A.w - W
    else if (root.islandSide === "left") v = A.x
    else v = A.x + A.w / 2 - W / 2
    // Rect local (ventana propia del host): sin margen, el borde de la ventana es el límite
    const m = root.islandRectLocal !== null ? 0 : 8
    if (root.hostWidth > 0) v = Math.min(root.hostWidth - m - W, v)
    return Math.max(m, v)
  }

  // Valores con los que se dibuja. Un panel normal salta directo al objetivo,
  // como siempre. Un TOOLTIP (liveContent) abierto que cambia de texto (pasar de un
  // ícono a otro) hace el cambio con un deslizamiento corto, igual que el
  // tooltip colgado (Behavior on x del host) en vez de teletransportar el
  // borde de la tarjeta.
  readonly property bool hullSmooth: root.liveContent && root.shown
  property real hullFullW: root.hullFullWTarget
  property real hullLeftFull: root.hullLeftFullTarget
  Behavior on hullFullW {
    enabled: root.hullSmooth
    NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
  }
  Behavior on hullLeftFull {
    enabled: root.hullSmooth
    NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
  }

  // Bordes en píxeles ENTEROS. La tarjeta se mueve cada cuadro (isla derecha:
  // el borde izquierdo avanza hacia la izquierda) y el contenido se coloca
  // restándole ese mismo valor para quedar fijo en pantalla; con decimales,
  // padre e hijo quedaban en posiciones fraccionarias que se compensaban en
  // la suma pero no al rasterizar: el texto vibraba ±1 px durante la animación.
  // Con enteros la suma es exacta. (Solo el eje largo de la barra: el borde
  // pegado a la barra en profundidad NO se redondea, ver placedDepth.)
  readonly property real hullLeft: root.hull
    ? Math.round(root.islandRect.x + (root.hullLeftFull - root.islandRect.x) * root.hullProgress) : 0
  readonly property real hullRight: root.hull
    ? Math.round((root.islandRect.x + root.islandRect.w)
      + (root.hullLeftFull + root.hullFullW - (root.islandRect.x + root.islandRect.w)) * root.hullProgress)
    : 0
  readonly property real hullCardW: root.hullRight - root.hullLeft
  // Alto de la isla: la tarjeta la incluye como cabecera
  readonly property real hullExtra: root.hull ? root.islandRect.h : 0
  // Dónde queda el contenido dentro de la tarjeta: fijo en pantalla, así la
  // tarjeta crece a su alrededor y lo va revelando
  // Ancho (px reales) del contenido dentro de la tarjeta
  readonly property real hullContentW: root.hull
    ? (root.stretchToIsland ? root.hullFullW : root.scaledWidth) : root.scaledWidth
  readonly property real hullContentX: root.hull
    ? Math.round(root.hullLeftFull + (root.hullFullW - root.hullContentW) / 2) - root.hullLeft : 0
  // Ancho LÓGICO del contenido (el que ve quien usa el panel como parent.width)
  readonly property real contentLogicalWidth:
    (root.hull && root.stretchToIsland && root.scaleFactor > 0)
      ? Math.max(root.panelWidth, root.hullFullW / root.scaleFactor) : root.panelWidth
  // El fondo decorativo cubre TODA la tarjeta (no solo el contenido): si la isla
  // es más ancha que el panel no quedan franjas lisas ni cortes verticales
  readonly property real hullBackdropX: root.hull ? root.hullLeftFull - root.hullLeft : 0
  // Radio de las esquinas: el de la isla al empezar, el del panel al final
  readonly property real hullRadius:
    root.islandRadius + (root.bodyRadius - root.islandRadius) * root.hullProgress

  // Flotante: ver arriba. Por defecto lo hereda del padre (FusedWindow).
  property bool detached: root.parent ? root.parent.detached === true : false

  // Los insets NO dependen de `detached`: así el cuerpo queda en el mismo
  // sitio, solo se dejan de dibujar las curvas.
  readonly property real startInset: (root.flareStart && !root.hull) ? root.flare : 0
  readonly property real endInset: (root.flareEnd && !root.hull) ? root.flare : 0

  // ─── Escala ────────────────────────────────────────────────────
  // Por defecto la de "Ventanas". Los tooltips (FusedTip) pasan la de la
  // barra y apagan fitScreen.
  property real uiScale: Theme.windowScale
  // Limitar la ampliación para que el panel quepa en la pantalla
  property bool fitScreen: true
  readonly property real fitScale: {
    const p = root.parent
    if (!root.fitScreen || !p || p.height <= 0 || p.width <= 0
        || root.contentHeight <= 0 || root.panelWidth <= 0)
      return root.uiScale
    if (root.vertical) {
      // A lo largo de la barra ocupa todo el alto libre; en profundidad,
      // el ancho que queda al lado de la barra
      const byHeight = (p.height - 16 - root.startInset - root.endInset) / root.contentHeight
      const byWidth  = (p.width - root.faceOffset - 16) / root.panelWidth
      return Math.min(byHeight, byWidth)
    }
    return (p.height - root.faceOffset - 16) / root.contentHeight
  }
  readonly property real scaleFactor:
    root.uiScale > 1 ? Math.max(1, Math.min(root.uiScale, root.fitScale)) : root.uiScale
  // Medidas reales (ya escaladas) del cuerpo
  readonly property real scaledWidth: Math.round(root.panelWidth * root.scaleFactor)
  readonly property real scaledHeight: Math.round(root.contentHeight * root.scaleFactor)

  // ─── Animación ─────────────────────────────────────────────────
  // Largo del cuerpo a lo largo de la barra (fijo) y su profundidad
  // (la que crece: alto si es horizontal, ancho si es vertical)
  readonly property real alongLength: root.vertical ? root.scaledHeight : root.scaledWidth
  readonly property real depthFull: root.vertical ? root.scaledWidth : root.scaledHeight

  // Profundidad actual (0 → cerrado, depthFull → abierto)
  //   normal      → sigue a `open ? depthFull : 0` con un Behavior: cada cambio
  //                 (abrir, cerrar o cambiar el alto del contenido) se anima.
  //   snapResize  → ver abajo: abrir/cerrar se anima, el alto del contenido no.
  property real grown: root.snapResize ? root.openAmount * root.depthFull
                                       : (root.effOpen ? root.depthFull : 0)
  // Si es true, el resize NO se anima: `grown` salta directo al valor
  // final. Lo usan los paneles cuyo contentHeight cambia todo el tiempo
  // mientras están abiertos (toasts): con la animación de Behavior puesta,
  // cada notificación nueva/cerrada hacía que el marco tardara `duration` en
  // alcanzar al contenido real, y mientras tanto el contenido quedaba
  // recortado o pisado. OJO: esto también apaga la animación de abrir/cerrar.
  // El resto de los paneles (contenido fijo) no lo usan y conservan el
  // crecimiento animado normal desde la barra.
  property bool instantResize: false

  // Para paneles con contenido vivo (centro de notificaciones): abrir y cerrar
  // SÍ se animan con la curva de siempre, pero el alto del contenido manda sin
  // retraso. Lo que se anima es un avance 0‥1 (`openAmount`) y la profundidad
  // sale de multiplicarlo por `depthFull`: si el contenido crece o se achica, el
  // marco lo sigue en el mismo cuadro (nada queda recortado ni pisado), y si
  // cambia a mitad de la apertura, la animación continúa sin saltos. Quien lo
  // use puede animar el alto de sus filas y el marco crecerá a la par.
  property bool snapResize: false
  property real openAmount: root.effOpen ? 1 : 0
  Behavior on openAmount {
    enabled: root.snapResize
    NumberAnimation {
      duration: root.effOpen ? root.duration : Math.round(root.duration * 0.7)
      easing.type: root.effOpen ? Easing.OutCubic : Easing.InOutCubic
    }
  }

  Behavior on grown {
    enabled: !root.instantResize && !root.snapResize
    NumberAnimation {
      duration: root.effOpen ? root.duration : Math.round(root.duration * 0.7)
      easing.type: root.effOpen ? Easing.OutCubic : Easing.InOutCubic
    }
  }

  // Profundidad con la que se DIBUJA: flotante = siempre completa (lo que
  // se anima es el fundido); pegado a la barra = la que crece
  readonly property real depth: root.hull ? root.grown + root.hullExtra
    : (root.detached ? root.depthFull : root.grown)

  readonly property bool shown: root.grown > 0.5
  readonly property bool hovered: hover.hovered
  // 0 → cerrado, 1 → totalmente abierto
  readonly property real progress:
    root.depthFull > 0 ? Math.max(0, Math.min(1, root.grown / root.depthFull)) : 0
  // Radio real de las esquinas del lado opuesto a la barra (mientras la
  // profundidad es chica se recorta para que la forma nunca se rompa)
  readonly property real cornerRadius: root.hull
    ? Math.max(0, Math.min(root.hullRadius, root.depth / 2, root.hullCardW / 2))
    : Math.max(0, Math.min(root.bodyRadius, root.depth / 2, root.alongLength / 2))

  // Los hijos declarados por quien use el panel van al área de contenido
  default property alias content: contentArea.data
  // Fondo decorativo, recortado con la silueta del panel (ver arriba)
  property alias backdrop: backdropHolder.data
  readonly property bool hasBackdrop: backdropHolder.children.length > 0

  // El alto (horizontal) o el ancho (vertical) es el que se anima
  implicitWidth: root.vertical ? root.depthFull
    : (root.hull ? root.hullCardW : root.scaledWidth + root.startInset + root.endInset)
  implicitHeight: root.vertical ? root.scaledHeight + root.startInset + root.endInset : root.depthFull
  width: root.vertical ? root.depth : root.implicitWidth
  height: root.vertical ? root.implicitHeight : root.depth

  // Flotante: aparece/desaparece con fundido + una escala leve, en su sitio
  visible: root.hull ? root.shown : (!root.detached || root.progress > 0.001)
  opacity: root.detached ? root.progress : 1
  scale: root.detached ? 0.94 + 0.06 * root.progress : 1

  // ─── Colocación automática ─────────────────────────────────────
  property string align: "end"       // start | center | end
  // Separación al borde de pantalla, a lo largo de la barra
  property real alignMargin: 10
  // Para align: "center": posición del centro a lo largo de la barra, en
  // coordenadas del padre (-1 = centro del padre)
  property real alignCenter: -1

  readonly property real hostWidth: root.parent ? root.parent.width : 0
  readonly property real hostHeight: root.parent ? root.parent.height : 0
  readonly property real alongHost: root.vertical ? root.hostHeight : root.hostWidth
  // Ojo: el tamaño a lo largo de la barra NO es el que se anima, así que
  // la posición no "baila" mientras el panel crece
  readonly property real alongSize: root.vertical ? root.height : root.width

  readonly property real placedAlong: {
    // Isla, panel ancho: la tarjeta va de la isla al panel completo
    if (root.hull) return root.hullLeft
    let v
    if (root.hang) {
      // Isla, gota: cuelga de la cara de la isla sin salirse de su tramo
      // plano (las esquinas de la isla quedan libres)
      const A = root.islandRect
      const lo = A.x + root.islandRadius
      const hi = Math.max(lo, A.x + A.w - root.islandRadius - root.alongSize)
      if (root.align === "end") v = hi
      else if (root.align === "start") v = lo
      else v = (root.alignCenter >= 0 ? root.alignCenter : A.x + A.w / 2) - root.alongSize / 2
      return Math.round(Math.max(lo, Math.min(hi, v)))
    }
    if (root.align === "start") {
      v = root.alignMargin
    } else if (root.align === "center") {
      const c = root.alignCenter >= 0 ? root.alignCenter : root.alongHost / 2
      v = Math.max(root.alignMargin,
                   Math.min(root.alongHost - root.alignMargin - root.alongSize,
                            c - root.alongSize / 2))
    } else {
      v = root.alongHost - root.alignMargin - root.alongSize
    }
    return Math.round(v)
  }

  // Pegado a la cara de la barra. Abajo / derecha depende del tamaño que
  // se anima: así el borde pegado a la barra no se mueve mientras crece.
  // (sin redondear: durante la animación el borde pegado a la barra tiene
  // que quedar exacto, medio píxel de baile se nota como un temblor)
  readonly property real placedDepth: {
    // Isla, panel ancho: la tarjeta arranca en el borde exterior de la isla
    if (root.hull)
      return root.edge === "bottom" ? root.islandRect.y + root.islandRect.h - root.height
                                    : root.islandRect.y
    if (root.edge === "bottom") return root.hostHeight - root.faceOffset - root.height
    if (root.edge === "right")  return root.hostWidth - root.faceOffset - root.width
    return root.faceOffset
  }

  x: root.vertical ? root.placedDepth : root.placedAlong
  y: root.vertical ? root.placedAlong : root.placedDepth

  // ─── Forma ─────────────────────────────────────────────────────
  // Se arma como path SVG para poder omitir las curvas cuando flareStart /
  // flareEnd están apagados. Se dibuja UNA vez en un sistema canónico:
  //     u = distancia a lo largo de la barra
  //     v = distancia a la cara de la barra (0 = pegado a ella)
  // y pt(u, v) lo pasa a x/y según el borde. Los bordes "bottom" y "left"
  // son un espejo del canónico, así que ahí se invierte el sentido de los
  // arcos (sweep). Mientras la profundidad es chica, los radios se recortan.
  //   sweep cóncavo → curva contra la barra · sweep convexo → esquina lejana
  function n(v) { return v.toFixed(2) }

  function pt(u, v) {
    const d = root.depth
    if (root.edge === "bottom") return n(u) + " " + n(d - v)
    if (root.edge === "left")   return n(v) + " " + n(u)
    if (root.edge === "right")  return n(d - v) + " " + n(u)
    return n(u) + " " + n(v)
  }

  // Esquina/curva del path. OozeSoft: arco SVG de siempre. CoOzey: ESCALONES
  // (pixel art) que aproximan ese mismo arco, con coordenadas enteras.
  //   (cu, cv)   = vértice del rectángulo que la esquina recorta
  //   (e1u, e1v) = dirección unitaria del vértice hacia el punto de INICIO
  //   (e2u, e2v) = dirección unitaria del vértice hacia el punto FINAL
  //   r = radio · sweep = el mismo de "A" (solo se usa fuera de CoOzey)
  // Devuelve el tramo desde el punto de inicio (ya dibujado) hasta el final.
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
    const fs = (root.flareStart && !root.detached) ? Math.min(root.flare, d / 2) : 0
    const fe = (root.flareEnd   && !root.detached) ? Math.min(root.flare, d / 2) : 0
    const rb = root.cornerRadius
    const u0 = root.startInset
    const u1 = u0 + root.alongLength
    const mirrored = root.edge === "bottom" || root.edge === "left"
    const concave = mirrored ? 0 : 1
    const convex  = mirrored ? 1 : 0

    // Isla (panel ancho): rectángulo sin curvas; esquinas de la cara =
    // radio de la isla, esquinas lejanas = radio animado (isla → panel)
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

    // Flotante: rectángulo con las 4 esquinas redondeadas, sin curvas
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

    let p = "M " + root.pt(u0 - fs, 0)
    if (fs > 0) p += root.corner(u0, 0, -1, 0, 0, 1, fs, concave)
    p += " L " + root.pt(u0, d - rb)
    p += root.corner(u0, d, 0, -1, 1, 0, rb, convex)
    p += " L " + root.pt(u1 - rb, d)
    p += root.corner(u1, d, -1, 0, 0, -1, rb, convex)
    p += " L " + root.pt(u1, fe)
    if (fe > 0) p += root.corner(u1, 0, 0, 1, 1, 0, fe, concave)
    p += " Z"
    return p
  }

  // Traga los clicks dentro del panel (si no, caerían al fondo y lo cerrarían)
  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.AllButtons
  }

  HoverHandler { id: hover }

  // CoOzey: sombra dura desplazada (la misma silueta, más oscura, corrida
  // shadowY px hacia abajo) — va DETRÁS de la forma principal.
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

  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      fillColor: root.color
      // CoOzey: contorno de "tinta" que sigue toda la silueta (incluidas las
      // curvas cóncavas que la unen a la barra). OozeSoft: sin borde.
      strokeWidth: Theme.cozy ? Theme.inkWidth : -1
      strokeColor: Theme.cozy ? Theme.ink : "transparent"
      joinStyle: Theme.cozy ? ShapePath.MiterJoin : ShapePath.RoundJoin
      PathSvg { path: root.svgPath }
    }
  }

  // Recorta al tamaño animado; el contenido interno mantiene el suyo.
  // Cubre solo el CUERPO (sin las curvas de los extremos).
  Item {
    id: clipArea
    x: root.vertical ? 0 : root.startInset
    y: root.vertical ? root.startInset : 0
    width: root.vertical ? root.width : (root.hull ? root.width : root.scaledWidth)
    height: root.vertical ? root.scaledHeight : root.height
    clip: true

    // ── Fondo decorativo ────────────────────────────────────────
    // Se recorta con la MISMA silueta del cuerpo: esquinas redondas solo
    // del lado opuesto a la barra, con el radio real (sin escalar), que es
    // el que dibuja la forma de arriba.
    Item {
      id: backdropLayer
      anchors.fill: parent
      visible: root.hasBackdrop
      opacity: contentArea.opacity
      layer.enabled: root.hasBackdrop
      layer.effect: MultiEffect {
        maskEnabled: true
        maskSource: backdropMask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
      }

      // Del tamaño del cuerpo abierto y pegado a la cara de la barra, igual
      // que el contenido: no se aplasta mientras el panel crece.
      Item {
        id: backdropHolder
        width: root.hull ? root.hullFullW : root.scaledWidth
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
      layer.enabled: true
      visible: false

      Rectangle {
        anchors.fill: parent
        color: "black"
        // Esquinas redondas = las del lado opuesto a la barra
        topLeftRadius:     (root.detached || root.edge === "bottom" || root.edge === "right") ? root.cornerRadius : 0
        topRightRadius:    (root.detached || root.edge === "bottom" || root.edge === "left")  ? root.cornerRadius : 0
        bottomLeftRadius:  (root.detached || root.edge === "top"    || root.edge === "right") ? root.cornerRadius : 0
        bottomRightRadius: (root.detached || root.edge === "top"    || root.edge === "left")  ? root.cornerRadius : 0
      }
    }

    // Máscara del CONTENIDO, en coordenadas FÍSICAS (las de clipArea, ya
    // escaladas): mismo rectángulo y mismas esquinas redondas que el cuerpo
    // real del panel (x/y/ancho/alto de contentArea × scaleFactor, radio
    // sin escalar). Antes estaba en coordenadas lógicas porque el layer se
    // capturaba sobre contentArea ANTES de aplicarle `scale`, y ese era
    // justo el problema: la textura se rasterizaba al tamaño lógico (ej.
    // 420 px) y luego se AMPLIABA con filtrado bilineal → todo el texto y
    // los íconos se veían borrosos con "Ventanas" en Grande/Exorbitante.
    // Ahora el layer vive en `contentClip` (sin escalar, tamaño físico) y
    // contentArea se dibuja escalado DENTRO de él, así el texto se
    // rasteriza directamente a su tamaño final y queda nítido.
    Item {
      id: contentMask
      width: clipArea.width
      height: clipArea.height
      layer.enabled: true
      visible: false

      Rectangle {
        x: contentArea.x
        y: contentArea.y
        width: Math.round(root.contentLogicalWidth * root.scaleFactor)
        height: Math.round(root.contentHeight * root.scaleFactor)
        color: "black"
        topLeftRadius:     (root.detached || root.edge === "bottom" || root.edge === "right") ? root.cornerRadius : 0
        topRightRadius:    (root.detached || root.edge === "bottom" || root.edge === "left")  ? root.cornerRadius : 0
        bottomLeftRadius:  (root.detached || root.edge === "top"    || root.edge === "right") ? root.cornerRadius : 0
        bottomRightRadius: (root.detached || root.edge === "top"    || root.edge === "left")  ? root.cornerRadius : 0
      }
    }

    // El contenido vive en coordenadas LÓGICAS (panelWidth × contentHeight)
    // y se dibuja escalado desde la esquina superior izquierda.
    Item {
      id: contentClip
      anchors.fill: parent
      // Recorta el contenido real con la MISMA silueta redondeada del panel
      // (antes solo lo recortaba clipArea, un rectángulo, así que el fondo
      // de listas/filas se veía cuadrado sobresaliendo de la esquina curva).
      // OJO: el layer va AQUÍ (sin `scale`) y no en contentArea; ver
      // contentMask.
      layer.enabled: true
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
        // Pegado a la cara de la barra (la que NO se mueve), así se va
        // revelando desde ella hacia afuera
        // (Islas: la cabecera de la tarjeta es la propia isla, así que el
        // contenido empieza debajo de ella y a la altura fija en pantalla)
        // Enteros: una posición con decimales hace que el texto escalado caiga
        // entre píxeles físicos y se vea borroso.
        x: Math.round(root.hull ? root.hullContentX
                     : (root.edge === "right" ? clipArea.width - root.scaledWidth : 0))
        y: Math.round(root.edge === "bottom" ? clipArea.height - root.scaledHeight - root.hullExtra
                                  : root.hullExtra)
        scale: root.scaleFactor
        transformOrigin: Item.TopLeft
        // Aparece mientras se abre, así nada se ve "cortado" contra las
        // esquinas redondeadas a mitad de animación
        opacity: root.detached ? 1 : Math.max(0, Math.min(1, (root.progress - 0.15) / 0.5))
      }
    }
  }
}
