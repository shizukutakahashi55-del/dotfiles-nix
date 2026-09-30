// FusedTip — tooltip de la barra con la MISMA lógica que los popups.
//
// Antes cada botón traía un ToolTip de QtQuick.Controls: una cajita
// flotante 8px debajo, de otro color y sin animación, que no tenía nada
// que ver con Menu / Network / Audio / Calendario. Ahora es un FusedPanel
// en chico: cuelga de la barra (esté arriba, abajo o a un costado) con las
// curvas cóncavas, mismo color (Theme.bg), sin bordes, y "nace" de la barra
// con la misma animación.
//
// Es UN solo tooltip por ventana (lo maneja el host, ver RightModules y
// LeftModules):
// al pasar de un botón a otro no se cierra y se abre de nuevo, se
// desliza y cambia de texto. Eso lo hace sentir como una sola pieza.
//
// Uso (el host pone x/y):
//   Barra horizontal → y pegado a la barra (Theme.barHeight, o encima si está
//     abajo), x centrado en el botón.
//   Barra vertical   → x pegado al costado de la píldora, y centrado en el botón.
//   Ojo: el eje que se anima al abrir (alto si es horizontal, ancho si es
//   vertical) es el que queda "pegado" a la barra, así que ahí no va Behavior.
//   FusedTip {
//     open: hayQueMostrar
//     text: "Volumen\nlínea 2"          // \n = varias líneas
//     y: Theme.barHeight
//     x: centroDelBoton - width / 2
//   }
import QtQuick
import "../COMMON"

FusedPanel {
  id: tip

  property string text: ""
  // Ancho máximo del texto; si se pasa, hace word-wrap
  property int maxTextWidth: 300

  readonly property int padX: 12
  readonly property int padY: 9

  // Alto máximo (px reales, ya escalado) que puede ocupar el tooltip sin salirse
  // de la ventana que lo aloja; el host lo calcula con el alto de SU ventana.
  // Las ventanas de la barra son chicas a propósito (solo la píldora recibe
  // clics) y un tooltip más alto se CORTA contra su borde: la parte de abajo
  // sale recta, sin las esquinas redondas (le pasaba al taskbar plegado, que
  // lista hasta 12 líneas). Con tope, lo que no cabe se recorta con "…" y el
  // panel conserva su forma. -1 = sin tope.
  property real maxDepth: -1

  FontMetrics { id: fm; font: label.font }
  // Líneas que caben (0 = sin límite). El 1.06 deja margen por si el alto real
  // de línea del Text es un poco mayor que el de las métricas.
  readonly property int maxLines: (tip.maxDepth < 0 || tip.scaleFactor <= 0) ? 0
    : Math.max(1, Math.floor((tip.maxDepth / tip.scaleFactor - tip.padY * 2)
                             / (fm.lineSpacing * 1.06)))

  // El borde (edge) lo hereda de FusedPanel: sigue a la barra, así el tooltip
  // nace hacia abajo, arriba o al costado según dónde esté. El host lo coloca
  // con x / y (eso manda sobre la colocación automática de FusedPanel).

  // ─── Modo Islas (y Dock) ───────────────────────────────────────
  // Mismo criterio que los paneles (ver FusedPanel, "Modo Islas"): el
  // tooltip NACE de la isla que lo lleva.
  //   • cabe en su tramo plano → cuelga de la cara de la isla (curvas cóncavas)
  //   • es más ancho que la isla (isla plegada, canción larga, lista de
  //     ventanas…) → la isla se estira hasta ser el tooltip (hull)
  // El host le da la isla en coordenadas de SU ventana (`islandRectLocal`,
  // null = sin islas → cuelga de la barra como siempre), dice de qué lado
  // es con `island` ("left" | "center" | "right") y coloca x con
  // `tip.placedAlong` / y con `tip.placedDepth` cuando `tip.islandActive`.
  // El hull nace DETRÁS de la píldora: el host pone `z: -1` al tooltip.
  //
  // `islandStyle: "hang"` (Dock: una píldora con borde y otro radio, que no
  // se puede estirar): si no cabe colgado se vuelve una burbuja flotante,
  // sin curvas, que el host separa un poco de la píldora (`tip.floating`).
  islandAware: true
  // El texto cambia con el tooltip abierto (al pasar de un botón a otro).
  // El modo (hull / hang) NO cambia con el tooltip abierto: si el texto nuevo
  // pide el otro, el tooltip se cierra, cambia de forma y se vuelve a abrir
  // (FusedPanel.liveContent). Antes se re-evaluaba en vivo y, con la isla
  // angosta (taskbar plegado), el tooltip saltaba de "colgado" a "isla
  // estirada" a mitad de camino al pasar de un ícono a otro.
  liveContent: true

  readonly property bool tooWideForHang: tip.islandRectLocal !== null
    && tip.scaledWidth + 2 * (tip.islandRadius + Theme.tipFlare) > tip.islandRectLocal.w
  readonly property bool floating: tip.islandStyle === "hang" && tip.tooWideForHang
  detached: tip.floating

  flare: Theme.tipFlare
  bodyRadius: Theme.tipRadius
  duration: Theme.animDuration(Theme.tipMs)
  // Cuelga de la barra: sigue el tamaño de la BARRA, no el de las ventanas
  uiScale: Theme.barScale
  fitScreen: false

  // El ancho sale del texto SIN envolver (regla); el alto, del texto
  // ya envuelto al ancho final. No hay lazo porque la regla no depende
  // de la etiqueta visible.
  panelWidth: Math.min(tip.maxTextWidth, ruler.implicitWidth) + padX * 2
  contentHeight: label.implicitHeight + padY * 2

  Text {
    id: ruler
    visible: false
    text: tip.text
    font.pixelSize: Theme.fs(11)
    font.family: Theme.fontFamily
  }

  Text {
    id: label
    x: tip.padX
    y: tip.padY
    width: tip.panelWidth - tip.padX * 2
    text: tip.text
    wrapMode: Text.WordWrap
    maximumLineCount: tip.maxLines > 0 ? tip.maxLines : 2147483647
    elide: Text.ElideRight
    color: Theme.text
    font.pixelSize: Theme.fs(11)
    font.family: Theme.fontFamily
  }
}
