// Theme — UNA sola fuente de verdad para colores y medidas de todo el shell.
//
// Antes cada componente (Bar, CenterModules, Menu, Notify, Mpris) tenía su
// propio Process + Timer leyendo /tmp/matugen-colors.json cada 3 s, y cada
// uno elegía colores distintos (la barra usaba "surface", Menu/Mpris usaban
// "background"...). Por eso los popups no combinaban con la barra.
//
// Ahora se lee UNA vez, y todos leen Theme.bg / Theme.surface / etc.
// Los colores tienen Behavior, así que al cambiar de wallpaper TODO
// transiciona junto, sin saltos.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  // ─── Escala de la interfaz (Ajustes → Interfaz) ───────────────
  // 5 niveles FIJOS (no hay slider libre):
  //   0 Pequeño · 1 Mediano · 2 Normal · 3 Grande · 4 Exorbitante
  // Son tres perillas independientes:
  //   fontLevel   → tamaño del TEXTO (Theme.fs(px) en cada font.pixelSize)
  //   barLevel    → barra + sus módulos + botón ❄ + tooltips
  //   windowLevel → todos los popups (FusedPanel escala su contenido)
  // Ojo: barra y ventanas escalan también su texto (es geometría); la
  // fuente es un extra "encima" de eso. Se persisten en
  // ~/.config/oozeshell/ui.json y se cambian desde el panel de Ajustes.
  property int fontLevel: 2
  property int barLevel: 2
  property int windowLevel: 2

  // Animaciones propias de OozeShell (independiente de las animaciones de Hyprland).
  // normal = tiempos completos; minimal = transiciones cortas; off = duración cero.
  property string uiAnimationMode: "normal"
  readonly property bool uiAnimationsEnabled: uiAnimationMode !== "off"
  function animDuration(ms) {
    const base = Math.max(0, Number(ms) || 0)
    if (root.uiAnimationMode === "off") return 0
    if (root.uiAnimationMode === "minimal") return Math.round(base * 0.4)
    return base
  }
  function setUiAnimationMode(mode) {
    const valid = ["normal", "minimal", "off"]
    const next = valid.indexOf(mode) >= 0 ? mode : "normal"
    if (root.uiAnimationMode === next) return
    root.uiAnimationMode = next
    root.savePrefs()
  }

  readonly property var geometryScales: [0.85, 0.92, 1.0, 1.15, 1.35]
  readonly property var fontScales:     [0.85, 0.92, 1.0, 1.15, 1.30]

  // Tamaño de fuente MANUAL (Ajustes → General → Tamaño → Ajuste fino). 0 = usar el
  // nivel de arriba; 50‥250 = porcentaje libre (100 = tamaño normal). Elegir un nivel
  // (setLevel "font") o restablecer vuelve a 0.
  readonly property int fontPercentMin: 50
  readonly property int fontPercentMax: 250
  property int fontPercent: 0
  readonly property bool fontCustom: fontPercent > 0
  readonly property real fontScale: fontPercent > 0 ? fontPercent / 100 : fontScales[fontLevel]
  // Porcentaje efectivo (el que muestra el campo numérico)
  readonly property int fontPercentEffective: Math.round(root.fontScale * 100)
  function clampFontPercent(v) {
    const n = parseInt(v)
    if (isNaN(n)) return root.fontPercent
    return Math.max(root.fontPercentMin, Math.min(root.fontPercentMax, n))
  }
  function setFontPercent(v) {
    const n = (v === 0 || v === "0") ? 0 : root.clampFontPercent(v)
    if (n === root.fontPercent) return
    root.fontPercent = n
    root.savePrefs()
  }
  readonly property real barScale:    geometryScales[barLevel]
  readonly property real windowScale: geometryScales[windowLevel]

  // Tamaño de texto escalado por el nivel de "Fuente". Usalo SIEMPRE en
  // vez de un número pelado: font.pixelSize: Theme.fs(13)
  function fs(px) { return Math.max(6, Math.round(px * root.fontScale)) }

  // Medidas REALES de la barra (Ajustes → Barra). Antes la fila se escalaba con
  // `scale:` (una transformación) y el texto/íconos se ampliaban ya
  // rasterizados → borrosos. Ahora cada medida se multiplica por barScale y se
  // redondea a píxel entero, así todo se dibuja nítido a su tamaño final.
  //   Theme.bs(30)  → tamaño/espaciado/radio de la barra
  //   Theme.bfs(13) → texto de la barra (nivel de Fuente × nivel de Barra)
  function bs(px)  { return Math.round(px * root.barScale) }
  function bfs(px) { return Math.max(6, Math.round(px * root.fontScale * root.barScale)) }

  // ─── Medidas compartidas ───────────────────────────────────────
  // Alto de la barra (32 px a escala Normal). TODOS los popups cuelgan de
  // este valor, así que al cambiar el nivel de "Barra" se acomodan solos.
  readonly property int barHeight: Math.round(32 * barScale)
  // ─── Posición y modo de la barra (Ajustes → Interfaz) ──────────
  // barPosition: "top" | "bottom" (barra horizontal) o "left" | "right"
  // (barra vertical, de arriba a abajo del monitor).
  // barFloating: la barra se despega de los bordes (píldora con margen).
  //   • Los popups y tooltips cuelgan de la barra donde esté: hacia abajo si
  //     está arriba, hacia arriba si está abajo; en vertical, hacia el costado
  //     contrario al de la barra. FusedPanel lo resuelve solo: su `edge` vale
  //     barPosition por defecto (top | bottom | left | right).
  //   • Flotante solo existe en horizontal. La preferencia del usuario se
  //     guarda en barFloatingPref y NO se pierde al pasar a vertical.
  //     barFloating (la que leen todos) = preferencia Y barra horizontal.
  //   • Flotante y el "marco" (esquinas de pantalla) son incompatibles: en
  //     modo flotante el marco se apaga solo (Bar.qml) y su botón del Menú
  //     queda deshabilitado, para que no se pisen visualmente.
  // Se persisten en ui.json junto con los niveles de escala.
  property string barPosition: "top"
  property bool barFloatingPref: false
  readonly property bool barVertical: barPosition === "left" || barPosition === "right"
  readonly property bool barAtBottom: barPosition === "bottom"
  readonly property bool barAtRight: barPosition === "right"
  readonly property bool barFloating: barFloatingPref && !barVertical
  // Ancho de la barra VERTICAL (44 px a escala Normal): más ancha que la
  // horizontal para que entren etiquetas como "ESP" o "100%".
  readonly property int verticalBarWidth: Math.round(44 * barScale)
  // Grosor de la barra sea cual sea su orientación (alto si es horizontal,
  // ancho si es vertical)
  readonly property int barThickness: barVertical ? verticalBarWidth : barHeight
  // Hueco entre la barra flotante y los bordes de la pantalla
  readonly property int floatGap: Math.round(3 * barScale)
  // ─── Modo Islas (Ajustes → General → Barra) ───────────────────
  // Apaga el FONDO de la barra: quedan solo las tres píldoras (izquierda,
  // centro, derecha) flotando con un respiro contra el borde, y el botón ❄
  // pasa a vivir dentro de la isla derecha. Los popups ya no cuelgan de una
  // barra: "nacen" de la isla que les corresponde (ver FusedPanel/IslandState).
  // Solo existe con la barra horizontal; la preferencia se guarda igual en
  // islandsPref y vuelve al regresar a arriba/abajo (igual que el flotante).
  property bool islandsPref: false
  readonly property bool islandsMode: islandsPref && !barVertical

  // ─── Modo Píldora (Ajustes → Interfaz → Barra) ──────────────────
  // A diferencia de Modo Islas, Modo Píldora NO es una variante de la
  // barra/islas: es una superficie aparte (PILL/Pill.qml + DASHBOARD/ +
  // la Tray propia, instanciadas desde shell.qml) que no depende de
  // Left/Center/RightModules ni de IslandState. Barra / Islas / Píldora
  // son mutuamente excluyentes (ver setIslandsEnabled / setPillModeEnabled)
  // y, como Islas, solo existen con la barra horizontal (con la vertical se
  // atenúan en Ajustes y la preferencia se conserva).
  property bool pillModePref: false
  readonly property bool pillMode: pillModePref && !barVertical
  // Auto-ocultar y "sincronizar Tray": preferencias persistidas. El valor
  // EN VIVO que leen PILL/Pill.qml y PILL/PillTray.qml es AppState.*; acá
  // solo se guardan/restauran (ver setPillAutoHide / setPillTraySync).
  property bool pillAutoHidePref: false
  property bool pillTraySyncPref: false
  // Radio de las píldoras (= el de las tres ventanas de módulos)
  // Barra "despegada" de los bordes: flotante O islas. Apaga el marco de
  // esquinas de pantalla (dos siluetas redondeadas a la vez se pisan).
  readonly property bool barSeparated: barFloating || islandsMode
  // Distancia del borde de pantalla a la barra (0 si no es flotante ni islas)
  readonly property int barEdge: barSeparated ? floatGap : 0
  // Distancia del borde de pantalla a la cara de la barra de la que cuelgan
  // los popups. Usalo en vez de barHeight para posicionar todo lo que cuelga.
  readonly property int barOffset: barThickness + barEdge
  // Radio de las esquinas de la barra (solo flotante)
  readonly property int barRadius: barFloating ? (root.cozy ? 4 : 14) : 0

  // Radio de la curva cóncava donde el popup se une a la barra
  readonly property int flare: root.cozy ? 12 : 16
  // Radio de las "esquinas de pantalla": la piecita curva del color de la
  // barra que muerde el ángulo recto de las 4 esquinas del área de trabajo
  // (2 bajo la barra, 2 abajo; ver screenCorners en Bar.qml). 0 = sin esquinas.
  readonly property int screenCorner: 16

  // ─── Estilo del "marco" de pantalla (Ajustes → Avanzado → Interfaz) ──
  // El ON/OFF general sigue viviendo en shell.qml (root.screenCorners,
  // botón del Menú, IPC `corners toggle`) — eso no cambia. Esto es el
  // ESTILO con el que se dibuja cuando está activado:
  //
  //   "corners" (por defecto, el de siempre) → solo 4 piecitas en las
  //             esquinas del área de trabajo, radio fijo (screenCorner).
  //   "curved"  → esquinas con un radio más grande y suave + 3 líneas de
  //             borde (todo el contorno menos el lado de la barra, que ya
  //             cumple esa función) que nacen de la barra y envuelven el
  //             resto de la pantalla, como un marco continuo.
  //
  // Fusiona en un solo sistema (BAR/Border.qml + BAR/components/, cableados
  // en Bar.qml) lo que antes eran dos piezas sueltas del proyecto sin usar.
  // Se persiste en ui.json junto con el resto de las preferencias de UI.
  property string frameStyle: "corners" // "corners" | "curved"
  readonly property bool frameCurved: frameStyle === "curved"
  // Radio de esquina cuando el estilo es "curved" (10-60, Avanzado → Interfaz)
  property int frameCurveRadius: 28
  // Grosor de las 3 líneas de borde del estilo "curved" (0-10)
  property int frameThickness: 3
  // Radio EFECTIVO de las piecitas de esquina según el estilo activo: lo
  // que en realidad lee Bar.qml (y ahora BAR/components/FrameCorner.qml)
  readonly property int frameCornerRadius: frameCurved ? frameCurveRadius : screenCorner

  function clampFrameCurveRadius(v) {
    const n = parseInt(v)
    if (isNaN(n)) return root.frameCurveRadius
    return Math.max(10, Math.min(60, n))
  }
  function clampFrameThickness(v) {
    const n = parseInt(v)
    if (isNaN(n)) return root.frameThickness
    // Antes topeaba en 10 (línea fina decorativa). Subido a 150 para poder
    // armar un marco completo: abajo cubre todo el ancho y los laterales
    // van de barra a barra, con las curvas en las esquinas internas donde
    // se encuentran (ver BAR/Border.qml + BAR/components/FrameCorner.qml).
    return Math.max(0, Math.min(150, n))
  }

  // Espejo de root.screenCorners (shell.qml): el ON/OFF general del marco.
  // Shell.qml lo mantiene sincronizado (onScreenCornersChanged); vive acá
  // en espejo para que cualquier popup lo lea sin recibirlo como prop.
  property bool screenCorners: true

  // "Brazo" del marco hasta la barra: mismo criterio que Bar.qml's
  // barModule.armTop/Bottom/Left/Right, pero accesible desde CUALQUIER
  // popup (Menu, AudioMenu, NetworkMenu, Settings...), no solo desde
  // dentro de Bar.qml. Activo solo con el marco prendido Y en estilo
  // "curved" (no en "corners", el cosmético de siempre) — igual que ahí.
  //
  // Los popups que cuelgan de la barra (FusedPanel, align: "start"/"end")
  // se alinean A LO LARGO de ella, así que lo único que les importa es el
  // grosor del marco en el lado PERPENDICULAR: con la barra horizontal,
  // izquierda/derecha; vertical, arriba/abajo. Sumar esto a Theme.barEdge
  // en su alignMargin es lo que hace que el panel quede pegado al marco en
  // vez de dejar un hueco cuando el estilo es "curved".
  readonly property bool frameArmsActive: screenCorners && frameCurved
  // ¿Hay marco de 3 líneas (estilo "curved") dibujado alrededor de la
  // pantalla? Mismo gate que BAR/Border.qml (`active`), sin barRebuilding
  // para que no parpadee. En modo Píldora la Bar no existe → no hay marco.
  readonly property bool frameBorderActive:
    screenCorners && frameCurved && !barSeparated && !pillMode

  // El Dock choca con ese marco (Border y Dock pelean por el mismo borde
  // de pantalla), así que con el marco activo no se muestra. La preferencia
  // dockEnabled NO se toca: al quitar el marco el Dock vuelve solo.
  readonly property bool dockUsable: dockEnabled && !frameBorderActive

  readonly property real frameSideArm: (frameArmsActive && frameThickness > 0) ? frameThickness : 0

  function setFrameStyle(style) {
    const next = (style === "curved") ? "curved" : "corners"
    if (next === root.frameStyle) return
    root.frameStyle = next
    root.savePrefs()
  }
  function setFrameCurveRadius(v) {
    const n = root.clampFrameCurveRadius(v)
    if (n === root.frameCurveRadius) return
    root.frameCurveRadius = n
    root.savePrefs()
  }
  function setFrameThickness(v) {
    const n = root.clampFrameThickness(v)
    if (n === root.frameThickness) return
    root.frameThickness = n
    root.savePrefs()
  }

  // Radio de las esquinas inferiores de los popups
  // Radio de tarjetas / botones internos
  // Duración base de la animación de "spawn"
  readonly property int animMs: 300

  // ─── Lado derecho de la barra ──────────────────────────────────
  // Ancho de la ventana del botón de menú ❄ (ver menuButtonPanel en
  // Bar.qml). RightModules lo usa para quedarse SIEMPRE a la izquierda
  // de ese botón: si cambiás uno, el otro se acomoda solo.
  readonly property int menuButtonWidth: Math.round(40 * barScale)
  // Respiro entre la píldora derecha y el botón ❄
  readonly property int rightGap: 8

  // ─── Tooltips (FusedTip) ───────────────────────────────────────
  // Misma familia que los popups (FusedPanel), en chico: curva cóncava
  // contra la barra, mismo color, misma animación de spawn.
  readonly property int tipFlare: root.cozy ? 8 : 10
  readonly property int tipRadius: root.cozy ? 8 : 14
  readonly property int tipMs: 200

  // ─── Estilo visual (Ajustes → Apariencia → Automático) ─────────
  // Dos "lenguajes" de forma para TODO el shell, independientes de la paleta:
  //   "soft"  → OozeSoft: el de siempre (fondos lisos, bordes finos).
  //   "cozy"  → CoOzey: estilo acogedor de juego de granja/pueblito — papel y
  //             madera cálidos, contorno grueso de "tinta", sombra dura
  //             desplazada, esquinas rellenas y tipografía redonda.
  // En Automático, CoOzey además "cozifica" la paleta de matugen (la calienta
  // hacia papel/madera — DESACTIVADO: ahora respeta matugen tal cual). Con
  // paletas fijas solo cambia la forma; los colores quedan como los elegiste.
  // Se guarda en ui.json (clave uiStyle) y por IPC: `theme style cozy|soft`.
  property string uiStyle: "soft"
  readonly property bool cozy: uiStyle === "cozy"

  function setUiStyle(style) {
    const next = (style === "cozy") ? "cozy" : "soft"
    if (next === root.uiStyle) return
    root.uiStyle = next
    root.savePrefs()
  }

  // Al cambiar de estilo se repinta la paleta vigente (la cozificación de
  // matugen depende del estilo). Con paletas fijas los colores no cambian.
  onUiStyleChanged: {
    if (root.paletteMode) root.applyManualPalette(root.manualPaletteIndex)
    else if (root.lastRaw !== "") root.applyPalette(root.lastRaw)
  }

  // ─── Tipografía ─────────────────────────────────────────────────
  // CoOzey es PIXEL: el texto usa una fuente pixel art y los ÍCONOS (glifos
  // Nerd Font) van SIEMPRE en su propia familia, así nunca se pierden.
  //
  //   monoFamily  → íconos (Text con font.family: Theme.monoFamily) y texto de OozeSoft.
  //   iconFamily  → alias de monoFamily.
  //   fontFamily  → texto normal. OozeSoft = monoFamily · CoOzey = pixelFamily.
  //
  // pixelFamily se elige sola: 1) assets/fonts/PixelFont.ttf si la pones ahí,
  // 2) "pixelFont" de ui.json, 3) la primera de pixelCandidates instalada en
  // el sistema (Qt.fontFamilies()), 4) Varela Round (incluida), 5) monoFamily.
  // Ver COOZEY.md → Fuentes.
  property var systemFonts: Qt.fontFamilies()
  function pickInstalled(list, fallback) {
    const have = root.systemFonts
    for (let i = 0; i < list.length; i++)
      if (have.indexOf(list[i]) >= 0) return list[i]
    return fallback
  }

  readonly property string monoFamily: root.pickInstalled(
    [ "JetBrainsMono Nerd Font", "JetBrainsMono NF", "JetBrainsMono Nerd Font Mono",
      "Symbols Nerd Font Mono", "Symbols Nerd Font" ], "JetBrainsMono Nerd Font")
  readonly property string iconFamily: root.monoFamily

  // Orden de preferencia (la primera instalada gana). Todas OFL/libres y con
  // acentos y ñ. DotGothic16 además trae kana/kanji (idioma japonés).
  readonly property var pixelCandidates: [
    "Pixelify Sans", "Jersey 10", "Jersey 15", "Silkscreen", "VT323",
    "Tiny5", "Micro 5", "DotGothic16", "Press Start 2P", "Departure Mono",
    "Monocraft", "Cozette", "ProggyClean Nerd Font"
  ]
  property string pixelFontPref: ""      // "" = automática (ui.json → "pixelFont")

  FontLoader { id: pixelBundled; source: Qt.resolvedUrl("../assets/fonts/PixelFont.ttf") }
  FontLoader { id: cozyFont; source: Qt.resolvedUrl("../assets/fonts/VarelaRound-Regular.ttf") }
  readonly property string softRoundFamily:
    cozyFont.status === FontLoader.Ready ? cozyFont.name : root.monoFamily

  readonly property string pixelFamily: {
    if (root.pixelFontPref !== "" && root.systemFonts.indexOf(root.pixelFontPref) >= 0)
      return root.pixelFontPref
    if (pixelBundled.status === FontLoader.Ready) return pixelBundled.name
    return root.pickInstalled(root.pixelCandidates, root.softRoundFamily)
  }
  // ¿Se encontró una fuente pixel de verdad?
  readonly property bool pixelFontFound:
    root.pixelFamily !== root.softRoundFamily && root.pixelFamily !== root.monoFamily

  readonly property string cozyFamily: root.pixelFamily
  readonly property string fontFamily: root.cozy ? root.pixelFamily : root.monoFamily

  function setPixelFont(name) {
    const v = String(name ?? "").trim()
    if (v === root.pixelFontPref) return
    root.pixelFontPref = v
    root.savePrefs()
  }

  // Medidas de forma según el estilo
  // En CoOzey los radios son chicos y múltiplos de 4: los paneles los dibujan
  // como ESCALONES (FusedPanel.corner) y un Rectangle con radius ≤ 4 se lee
  // como una esquina recortada de 1 pixel.
  readonly property int cardRadius:  root.cozy ? 4 : 12
  readonly property int panelRadius: root.cozy ? 12 : 20
  readonly property int islandRadius: root.cozy ? 8 : 13
  // Grosor del contorno de "tinta" de superficies grandes (barra, popups,
  // píldoras) y de tarjetas/botones. 0 en OozeSoft = sin contorno.
  readonly property int inkWidth:  root.cozy ? 2 : 0
  readonly property int bw1: root.cozy ? 2 : 1          // reemplaza a "border.width: 1"
  // Desplazamiento de la sombra dura bajo popups y botones (px)
  readonly property int shadowY: root.cozy ? 3 : 0

  // Colores de contorno derivados del fondo activo (cualquier paleta):
  //  • fondo oscuro → tinta MÁS oscura que el fondo (marrón-negro cálido)
  //  • fondo claro  → tinta = el texto oscuro atenuado
  readonly property bool bgIsDark: root.bg.hslLightness < 0.5
  property color ink: root.bgIsDark ? Qt.darker(root.bg, 2.4)
                                    : Qt.tint(root.bg, Qt.rgba(root.text.r, root.text.g, root.text.b, 0.82))
  // Borde de tarjetas: OozeSoft = divisor tenue de siempre; CoOzey = tinta
  readonly property color edge: root.cozy ? root.ink : root.divider
  // Sombra dura (offset) de popups/botones en CoOzey
  readonly property color shadowInk: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, root.bgIsDark ? 0.55 : 0.35)
  // Brillo interior superior de las tarjetas (efecto "papel" en CoOzey)
  readonly property color paperShine: Qt.rgba(1, 1, 1, root.bgIsDark ? 0.07 : 0.35)
  Behavior on ink { ColorAnimation { duration: 300 } }

  // Mezcla lineal de dos colores (t = 0 → a, t = 1 → b)
  function mix(a, b, t) {
    const x = (typeof a === "string") ? Qt.color(a) : a
    const y = (typeof b === "string") ? Qt.color(b) : b
    return Qt.rgba(x.r + (y.r - x.r) * t, x.g + (y.g - x.g) * t, x.b + (y.b - x.b) * t, 1)
  }

  // Cozifica un color de acento: un poco más saturado y con luminosidad en
  // una franja "pastel de juego" (ni neón ni apagado), conservando el matiz.
  function cozyAccent(c, dark) {
    const q = (typeof c === "string") ? Qt.color(c) : c
    const s = Math.min(1, q.hslSaturation * 1.08 + 0.04)
    const l = dark ? Math.max(0.62, Math.min(0.74, q.hslLightness))
                   : Math.max(0.38, Math.min(0.50, q.hslLightness))
    return Qt.hsla(q.hslHue, s, l, 1)
  }

  // Interpola dos matices (0‥1) por el camino corto del círculo cromático
  function hueLerp(a, b, t) {
    const d = ((b - a + 1.5) % 1) - 0.5
    return ((a + d * t) % 1 + 1) % 1
  }

  // CoOzey y OozeSoft siguen EXACTAMENTE la paleta de matugen (la del wallpaper).
  // Antes cozify() empujaba el matiz hacia marrón y fijaba saturación/luz, por
  // eso en Automático todo volvía al café-madera sin importar el wallpaper.
  // Ahora la paleta pasa tal cual; lo "cozy" es solo la FORMA (contornos,
  // sombra dura, esquinas pixel, fuente), no el color.
  function cozify(p, dark) { return p }

  // ─── Paleta (defaults = tu paleta actual) ──────────────────────
  property color bg:          "#0d0e11"   // = fondo de la barra y de TODOS los popups
  property color surface:     "#1e2030"   // tarjetas / botones
  property color surfaceHigh: "#292b3d"   // hover / knob / chips
  property color primary:     "#4a90d9"
  property color textOnPrimary:   "#ffffff"
  property color text:        "#e1e2e8"
  property color subtext:     "#8e9ab0"
  property color error:       "#e05a5a"
  property color textOnError:     "#ffffff"
  // Extras de matugen (los usa POWER/PowerMenu.qml, igual que @outline /
  // @p-container / @on-p-cont en el viejo powermenu de rofi)
  property color primaryContainer:   "#1f3a5f"
  property color textOnPrimaryContainer: "#d6e6ff"
  property color outline:            "#8e9ab0"

  // Velo del color del texto con transparencia `a` (0‥1): sirve de divisor,
  // de fondo de chips, de pista de sliders… y funciona en oscuro y en claro
  // (un blanco fijo desaparece sobre un fondo claro).
  function tint(a) { return Qt.rgba(root.text.r, root.text.g, root.text.b, a) }
  readonly property color divider: root.tint(0.10)

  // ─── Modo claro / oscuro ────────────────────────────────────────
  // matugen escribe las dos variantes en /tmp/matugen-colors.json; aquí solo
  // elegimos cuál leer. Walls además le pasa `-m light|dark` a matugen para
  // que el resto de tus apps (GTK, kitty, hyprland…) cambien igual.
  // Se guarda en ~/.config/oozeshell/ui.json y por IPC: `theme mode light`.
  property bool lightMode: false

  // Suavizado del modo claro: el claro de matugen es casi blanco y cansa la
  // vista. Se multiplica el brillo de los fondos (bg / tarjetas / hover) por
  // este factor: 1.0 = matugen tal cual · 0.92 = suave (por defecto) ·
  // 0.85 = más apagado, tipo papel. Los acentos y el texto no se tocan.
  property real lightSoftness: 0.92

  function soften(c) {
    const q = (typeof c === "string") ? Qt.color(c) : c
    const k = root.lightSoftness
    return Qt.rgba(q.r * k, q.g * k, q.b * k, 1)
  }
  readonly property string schemeMode: root.lightMode ? "light" : "dark"

  function setLightMode(on) {
    const v = on === true
    if (v === root.lightMode) return
    root.lightMode = v
    root.savePrefs()
  }

  // Al cambiar de modo se vuelve a leer la última paleta ya con la otra variante
  onLightModeChanged: { if (root.lastRaw !== "") root.applyPalette(root.lastRaw) }

  Behavior on bg          { ColorAnimation { duration: 300 } }
  Behavior on surface     { ColorAnimation { duration: 300 } }
  Behavior on surfaceHigh { ColorAnimation { duration: 300 } }
  Behavior on primary     { ColorAnimation { duration: 300 } }
  Behavior on textOnPrimary   { ColorAnimation { duration: 300 } }
  Behavior on text        { ColorAnimation { duration: 300 } }
  Behavior on subtext     { ColorAnimation { duration: 300 } }
  Behavior on error       { ColorAnimation { duration: 300 } }
  Behavior on primaryContainer   { ColorAnimation { duration: 300 } }
  Behavior on textOnPrimaryContainer { ColorAnimation { duration: 300 } }
  Behavior on outline            { ColorAnimation { duration: 300 } }

  // ─── Módulos plegables de la barra ─────────────────────────────
  // Cada uno se pliega con su mini botón ◂▸ (COMMON/BarToggle.qml) y queda
  // reducido a UN solo ícono:
  //   mprisCompact    → mpris: solo el ícono de estado (sin título;
  //                     el tooltip sigue mostrando la canción)
  //   taskbarCompact  → taskbar: un solo ícono en vez de uno por ventana
  //                     (el tooltip lista las ventanas abiertas)
  // Se persisten en ui.json. En barra vertical el mpris ya es solo ícono, así
  // que su botón no se muestra (la preferencia se conserva).
  property bool mprisCompact: false
  property bool taskbarCompact: false

  function setMprisCompact(on) {
    if (!!on === root.mprisCompact) return
    root.mprisCompact = !!on
    root.savePrefs()
  }

  function setTaskbarCompact(on) {
    if (!!on === root.taskbarCompact) return
    root.taskbarCompact = !!on
    root.savePrefs()
  }

  // ─── Dock (Ajustes → Interfaz) ──────────────────────────────────
  // Encendido/apagado de DOCK/Dock.qml. Las apps fijadas al dock viven
  // aparte, en DockBackend (mismo motivo que monitor/idioma/esquinas en
  // shell.qml: no todo tiene que pasar por ui.json).
  property bool dockEnabled: false

  function setDockEnabled(on) {
    if (!!on === root.dockEnabled) return
    root.dockEnabled = !!on
    root.savePrefs()
  }

  // dockPosition: "top" | "bottom" — elegible a mano SOLO cuando la barra
  // es lateral (izquierda/derecha), porque ahí el Dock no le pisa el lado
  // a la barra. Con la barra horizontal (arriba/abajo) el Dock no puede
  // elegirse solo: se va derecho al lado CONTRARIO de la barra (si la
  // barra baja, el Dock sube solo, y viceversa), así nunca se superponen.
  // Ver dockEffectivePosition, que es la que usa Dock.qml.
  property string dockPosition: "bottom"
  // Se esconde solo, dejando un borde finito (la "manija") para pasar el
  // mouse y que vuelva a aparecer. Ver Dock.qml.
  property bool dockAutoHide: false

  // ─── Tamaño PROPIO de Píldora y Dock (Ajustes → Interfaz) ───────
  // Independiente de "Barra" (barLevel/barScale): ni el Dock ni la Píldora
  // cambian con los niveles de escala de la barra. Porcentaje libre.
  //   pillScalePercent → píldora central + Workspaces + Tray/Batería
  //   dockScalePercent → DOCK/Dock.qml (íconos, alto, tooltips)
  readonly property int ownScaleMin: 50
  readonly property int ownScaleMax: 150
  readonly property int pillScaleDefault: 100
  readonly property int dockScaleDefault: 80
  property int pillScalePercent: 100
  property int dockScalePercent: 80
  readonly property real pillScale: root.pillScalePercent / 100

  // ─── Tamaño del Dashboard (modo Píldora) ────────────────────────
  // 5 niveles FIJOS (Ajustes → Interfaz → Barra → Tamaño del Dashboard).
  // Agrandan el Dashboard ENTERO —ventana, header, paneles y letras— con
  // medidas en píxeles reales (nada de `scale:` → no se ve borroso).
  // La fuente del Dashboard sigue AMBOS: este nivel Y Interfaz → Fuente
  // (nivel o tamaño manual): dfs = dashScale × fontScale.
  // Las medidas de layout (ds) crecen con la fuente solo el `dashFontFollow`
  // (75 %) del extra, para que el texto más grande no quede recortado en
  // las cajas del Dashboard sin inflarlo de más. Con fuente al 100 % =
  // exactamente el comportamiento de antes.
  //   ds(px)  → medida de layout del Dashboard      dfs(px) → font.pixelSize
  property int dashboardLevel: 0
  readonly property var dashScales: [1.0, 1.15, 1.3, 1.45, 1.6]
  readonly property real dashScale: root.dashScales[root.dashboardLevel] ?? 1.0
  readonly property real dashFontFollow: 0.75
  readonly property real dashGeomScale: root.dashScale * (1 + (root.fontScale - 1) * root.dashFontFollow)
  function ds(px)  { return Math.round(px * root.dashGeomScale) }
  function dfs(px) { return Math.max(6, Math.round(px * root.dashScale * root.fontScale)) }
  function setDashboardLevel(v) {
    const n = Math.max(0, Math.min(4, parseInt(v) || 0))
    if (n === root.dashboardLevel) return
    root.dashboardLevel = n
    root.savePrefs()
  }
  readonly property real dockScale: root.dockScalePercent / 100
  // Separación entre el borde de la pantalla y la píldora / el dock (px).
  // Antes 10 (el dock además la escalaba con la barra).
  readonly property int pillEdgeGap: 4
  readonly property int dockEdgeGap: 4
  // Alto de la píldora (38 px al 100 %)
  readonly property int pillHeight: Math.round(38 * root.pillScale)

  function clampOwnScale(v, fallback) {
    const n = parseInt(v)
    if (isNaN(n)) return fallback
    return Math.max(root.ownScaleMin, Math.min(root.ownScaleMax, n))
  }
  function setPillScalePercent(v) {
    const n = root.clampOwnScale(v, root.pillScalePercent)
    if (n === root.pillScalePercent) return
    root.pillScalePercent = n
    root.savePrefs()
  }
  function setDockScalePercent(v) {
    const n = root.clampOwnScale(v, root.dockScalePercent)
    if (n === root.dockScalePercent) return
    root.dockScalePercent = n
    root.savePrefs()
  }

  readonly property string dockEffectivePosition:
    root.barVertical ? root.dockPosition : (root.barPosition === "bottom" ? "top" : "bottom")

  function setDockPosition(pos) {
    const valid = ["top", "bottom"]
    const next = valid.indexOf(pos) >= 0 ? pos : "bottom"
    if (next === root.dockPosition) return
    root.rebuildBar()
    root.dockPosition = next
    root.savePrefs()
  }

  function setDockAutoHide(on) {
    if (!!on === root.dockAutoHide) return
    root.dockAutoHide = !!on
    root.savePrefs()
  }

  // ─── Indicador de batería (Ajustes → General → Barra) ──────────
  // Módulo de BAR/RIGHT/RightModules.qml. Si la máquina no tiene batería
  // (BatteryBackend.available === false) no se muestra aunque esté en ON.
  property bool batteryEnabled: true

  function setBatteryEnabled(on) {
    if (!!on === root.batteryEnabled) return
    root.batteryEnabled = !!on
    root.savePrefs()
  }

  // ─── Audio (Ajustes Avanzado → Audio) ──────────────────────────
  // Sección "Monitores (salidas físicas)": solo volumen/mute de los sinks
  // de hardware. La app OozeAudio suelta no la muestra (solo maneja
  // salidas virtuales + conexiones), así que queda como opcional acá.
  property bool audioMonitorsCardEnabled: true

  function setAudioMonitorsCardEnabled(on) {
    if (!!on === root.audioMonitorsCardEnabled) return
    root.audioMonitorsCardEnabled = !!on
    root.savePrefs()
  }

  // ─── Launcher y terminal (Ajustes → General) ───────────────────
  // launcherAttached: true  = el Launcher cuelga de la barra (con sus curvas)
  //                   false = sale centrado en la pantalla, como tarjeta flotante
  // Efectos extra (Ajustes → General → Efectos; también un botón en el selector
  // de wallpapers): zoom lento y resplandor del Launcher, entrada escalonada
  // de filas, clips animados del wallpaper en vivo, brillo/elevación de las
  // tarjetas de Walls. Apagados el shell consume menos CPU/GPU.
  property bool effectsOn: true

  property bool launcherAttached: true
  // Imagen (wallpaper) a la izquierda del Launcher. Apagada, el panel es
  // solo la lista y el título pasa arriba.
  property bool launcherShowImage: true
  // Tamaño del Launcher: 0 compacto · 1 normal · 2 grande
  property int launcherSize: 1
  // Partículas ambiente del Launcher (Launcher/LauncherParticles.qml) +
  // brillos (selección, buscador enfocado) — "fancy" al estilo de la
  // nieve del PowerMenu, pero propias del Launcher. Interruptor FINO
  // aparte del general (effectsOn): con effectsOn apagado esto tampoco se
  // anima aunque esté en true, pero se puede apagar solo esto y dejar
  // prendido el resto de los efectos (zoom del wallpaper, entrada de filas…).
  property bool launcherParticlesEnabled: true
  // Clip animado (gif) del wallpaper en vivo dentro del Launcher — ver
  // Launcher/Launcher.qml, `wall.fx`. Interruptor FINO aparte, igual que
  // el de partículas: podés tener las partículas SIN el gif del wallpaper
  // (o al revés), sin tocar el interruptor general de Efectos.
  property bool launcherWallpaperLiveEnabled: true

  // ─── Pantalla de bloqueo (LOCK/LockScreen.qml) ─────────────────
  // lockWallpaperMode: "auto" = el wallpaper puesto al momento de bloquear;
  // "custom" = la imagen de lockWallpaperPath (acepta ~ y $HOME al inicio).
  // Si la ruta no existe, el bloqueo cae al modo auto.
  property string lockWallpaperMode: "auto"
  property string lockWallpaperPath: ""

  // Terminal con la que se ejecutan los comandos (nix shell / nix profile
  // install en NixSearch, apps con Terminal=true y Ctrl+Enter en el Launcher).
  // `exec` es lo que va ANTES del comando: cada terminal pide su propia forma
  // de decir "corré esto" (foot -e, wezterm start --, gnome-terminal --…).
  readonly property var terminals: [
    { id: "foot",           name: "foot",           exec: ["foot", "-e"] },
    { id: "kitty",          name: "kitty",          exec: ["kitty"] },
    { id: "alacritty",      name: "Alacritty",      exec: ["alacritty", "-e"] },
    { id: "wezterm",        name: "WezTerm",        exec: ["wezterm", "start", "--"] },
    { id: "ghostty",        name: "Ghostty",        exec: ["ghostty", "-e"] },
    { id: "konsole",        name: "Konsole",        exec: ["konsole", "-e"] },
    { id: "gnome-terminal", name: "GNOME Terminal", exec: ["gnome-terminal", "--"] },
    { id: "xfce4-terminal", name: "Xfce Terminal",  exec: ["xfce4-terminal", "-x"] },
    { id: "xterm",          name: "xterm",          exec: ["xterm", "-e"] }
  ]
  property string terminalId: "foot"

  // Comando prefijo de la terminal elegida. Si el id no está en la lista (por
  // ejemplo lo escribiste a mano en ui.json) se usa tal cual con `-e`.
  readonly property var terminalCmd: {
    const t = root.terminals.find(x => x.id === root.terminalId)
    return t ? t.exec : [root.terminalId, "-e"]
  }

  // Terminales de la lista que están instaladas (se detectan una vez al
  // arrancar, con `command -v`). Vacío hasta que termina la detección.
  property var installedTerminals: []

  Process {
    id: detectTermProc
    property string buffer: ""
    command: ["sh", "-c",
      'for t in "$@"; do command -v "$t" >/dev/null 2>&1 && echo "$t"; done',
      "sh"].concat(root.terminals.map(t => t.exec[0]))
    running: true
    stdout: SplitParser { onRead: line => detectTermProc.buffer += line + "\n" }
    onRunningChanged: {
      if (running) return
      const bins = detectTermProc.buffer.split("\n").filter(l => l !== "")
      detectTermProc.buffer = ""
      // binario → id (el binario de cada terminal es el primer elemento de exec)
      root.installedTerminals = root.terminals
        .filter(t => bins.indexOf(t.exec[0]) >= 0)
        .map(t => t.id)
    }
  }

  function setEffects(on) {
    if (!!on === root.effectsOn) return
    root.effectsOn = !!on
    root.savePrefs()
  }

  function setLauncherAttached(on) {
    if (!!on === root.launcherAttached) return
    root.launcherAttached = !!on
    root.savePrefs()
  }

  function setLauncherShowImage(on) {
    if (!!on === root.launcherShowImage) return
    root.launcherShowImage = !!on
    root.savePrefs()
  }

  function setLauncherSize(n) {
    const v = Math.max(0, Math.min(2, parseInt(n)))
    if (isNaN(v) || v === root.launcherSize) return
    root.launcherSize = v
    root.savePrefs()
  }

  function setLauncherParticlesEnabled(on) {
    if (!!on === root.launcherParticlesEnabled) return
    root.launcherParticlesEnabled = !!on
    root.savePrefs()
  }

  function setLauncherWallpaperLiveEnabled(on) {
    if (!!on === root.launcherWallpaperLiveEnabled) return
    root.launcherWallpaperLiveEnabled = !!on
    root.savePrefs()
  }

  function setLockWallpaperMode(mode) {
    const m = mode === "custom" ? "custom" : "auto"
    if (m === root.lockWallpaperMode) return
    root.lockWallpaperMode = m
    root.savePrefs()
  }

  function setLockWallpaperPath(path) {
    const v = String(path ?? "").trim()
    if (v === root.lockWallpaperPath) return
    root.lockWallpaperPath = v
    root.savePrefs()
  }

  function setTerminal(id) {
    if (typeof id !== "string" || id === "" || id === root.terminalId) return
    root.terminalId = id
    root.savePrefs()
  }

  // ─── Paleta de matugen preferida (Ajustes → Configuración avanzada) ──
  // Única lista de esquemas del shell: Walls.qml apunta acá (wallsRoot.schemes
  // = Theme.schemes) para no mantener dos copias. `defaultSchemeIndex` es el
  // esquema con el que arranca un wallpaper NUEVO; si elegís uno distinto a
  // mano en el selector de Walls, esa elección manda para ESE wallpaper (esto
  // solo fija el punto de partida, no fuerza nada retroactivamente).
  readonly property var schemes: [
    { name: "vibrant",     label: "vibrant"  },
    { name: "tonal-spot",  label: "tonal"    },
    { name: "neutral",     label: "neutral"  },
    { name: "fruit-salad", label: "fruit"    },
    { name: "rainbow",     label: "rainbow"  },
    { name: "fidelity",    label: "fidelity" },
    { name: "content",     label: "content"  },
    { name: "monochrome",  label: "mono"     }
  ]
  property int defaultSchemeIndex: 0

  function setDefaultSchemeIndex(idx) {
    const n = Math.max(0, Math.min(root.schemes.length - 1, parseInt(idx) || 0))
    if (n === root.defaultSchemeIndex) return
    root.defaultSchemeIndex = n
    root.savePrefs()
  }

  // ─── Modo Paletas (Ajustes → Configuración avanzada → Apariencia) ────
  // El slider Automático/Paletas de AdvancedSettings vive acá:
  //   paletteMode = false → "Automático": el de siempre, matugen saca los
  //                 colores del wallpaper (Walls.runMatugen corre en cada
  //                 cambio de fondo/esquema/modo claro).
  //   paletteMode = true  → "Paletas": colores FIJOS, elegidos a mano de
  //                 manualPalettes. Matugen queda apagado del todo — Walls
  //                 lee este flag y ni siquiera lanza el proceso al cambiar
  //                 de wallpaper (ver runMatugen() en Walls.qml).
  // 6 paletas fijas, con el mismo set de campos que lee applyPalette() de
  // matugen (bg/surface/.../outline) para que todo el shell (barra, popups,
  // PowerMenu…) las pinte exactamente igual que a una paleta de matugen.
  readonly property var manualPalettes: [
    { name: "nord", label: "Nord",
      bg: "#2e3440", surface: "#3b4252", surfaceHigh: "#434c5e",
      primary: "#88c0d0", textOnPrimary: "#2e3440",
      text: "#eceff4", subtext: "#d8dee9",
      error: "#bf616a", textOnError: "#2e3440",
      primaryContainer: "#4c566a", textOnPrimaryContainer: "#eceff4",
      outline: "#81a1c1" },
    { name: "dracula", label: "Dracula",
      bg: "#282a36", surface: "#343746", surfaceHigh: "#44475a",
      primary: "#bd93f9", textOnPrimary: "#282a36",
      text: "#f8f8f2", subtext: "#6272a4",
      error: "#ff5555", textOnError: "#282a36",
      primaryContainer: "#6272a4", textOnPrimaryContainer: "#f8f8f2",
      outline: "#ff79c6" },
    { name: "gruvbox", label: "Gruvbox",
      bg: "#282828", surface: "#3c3836", surfaceHigh: "#504945",
      primary: "#d79921", textOnPrimary: "#282828",
      text: "#ebdbb2", subtext: "#a89984",
      error: "#cc241d", textOnError: "#ebdbb2",
      primaryContainer: "#7c6f64", textOnPrimaryContainer: "#ebdbb2",
      outline: "#b8bb26" },
    { name: "catppuccin", label: "Catppuccin",
      bg: "#1e1e2e", surface: "#313244", surfaceHigh: "#45475a",
      primary: "#cba6f7", textOnPrimary: "#1e1e2e",
      text: "#cdd6f4", subtext: "#a6adc8",
      error: "#f38ba8", textOnError: "#1e1e2e",
      primaryContainer: "#585b70", textOnPrimaryContainer: "#cdd6f4",
      outline: "#89b4fa" },
    { name: "solarized", label: "Solarized",
      bg: "#002b36", surface: "#073642", surfaceHigh: "#0a4552",
      primary: "#268bd2", textOnPrimary: "#002b36",
      text: "#eee8d5", subtext: "#93a1a1",
      error: "#dc322f", textOnError: "#eee8d5",
      primaryContainer: "#2aa198", textOnPrimaryContainer: "#002b36",
      outline: "#586e75" },
    { name: "tokyo-night", label: "Tokyo Night",
      bg: "#1a1b26", surface: "#24283b", surfaceHigh: "#2f3549",
      primary: "#7aa2f7", textOnPrimary: "#1a1b26",
      text: "#c0caf5", subtext: "#565f89",
      error: "#f7768e", textOnError: "#1a1b26",
      primaryContainer: "#3d59a1", textOnPrimaryContainer: "#c0caf5",
      outline: "#bb9af7" }
  ]

  // false = Automático (matugen) · true = Paletas (fijas, manuales)
  property bool paletteMode: false
  property int manualPaletteIndex: 0

  // Pinta root.bg/surface/.../outline con la paleta manual `idx`, tal cual
  // applyPalette() hace con el json de matugen (mismas Behavior → mismo
  // fundido de color en toda la interfaz).
  function applyManualPalette(idx) {
    const n = Math.max(0, Math.min(root.manualPalettes.length - 1, parseInt(idx) || 0))
    const p = root.manualPalettes[n]
    root.bg                     = p.bg
    root.surface                = p.surface
    root.surfaceHigh            = p.surfaceHigh
    root.primary                = p.primary
    root.textOnPrimary          = p.textOnPrimary
    root.text                   = p.text
    root.subtext                = p.subtext
    root.error                  = p.error
    root.textOnError            = p.textOnError
    root.primaryContainer       = p.primaryContainer
    root.textOnPrimaryContainer = p.textOnPrimaryContainer
    root.outline                = p.outline
  }

  function setManualPaletteIndex(idx) {
    const n = Math.max(0, Math.min(root.manualPalettes.length - 1, parseInt(idx) || 0))
    if (n === root.manualPaletteIndex) return
    root.manualPaletteIndex = n
    if (root.paletteMode) root.applyManualPalette(n)
    root.savePrefs()
  }

  // Prender "Paletas" pinta ya mismo la paleta manual elegida. Volver a
  // "Automático" repinta con la última paleta de matugen conocida (si hay
  // una) para no quedarse con los colores manuales hasta el próximo cambio
  // de wallpaper; Walls.qml además dispara un runMatugen() fresco al ver
  // este cambio, por si el wallpaper cambió mientras estabas en Paletas.
  function setPaletteMode(on) {
    const v = !!on
    if (v === root.paletteMode) return
    root.paletteMode = v
    if (v) root.applyManualPalette(root.manualPaletteIndex)
    else if (root.lastRaw !== "") root.applyPalette(root.lastRaw)
    root.savePrefs()
  }

  // ─── Tamaño de interfaz avanzado (Ajustes → Configuración avanzada) ──
  // Cuarta perilla, independiente de fuente/barra/ventanas: escala SOLO el
  // ancho de las tarjetas/paneles grandes (Ajustes, Configuración avanzada,
  // Walls...). Las tres perillas de siempre no tocan esto.
  //
  // A diferencia de fontLevel/barLevel/windowLevel (5 presets fijos, sin
  // slider libre — ver más arriba), esta SÍ es de valor libre: vive en la
  // Configuración avanzada, pensada para números exactos en vez de elegir
  // entre unos pocos tamaños con nombre (NumberStepper, no LevelPicker).
  readonly property int panelWidthMin: 50
  readonly property int panelWidthMax: 200
  property int panelWidthPercent: 100
  readonly property real panelWidthScale: root.panelWidthPercent / 100

  function clampPanelWidthPercent(v) {
    const n = parseInt(v)
    if (isNaN(n)) return root.panelWidthPercent
    return Math.max(root.panelWidthMin, Math.min(root.panelWidthMax, n))
  }

  function setPanelWidthPercent(v) {
    const n = root.clampPanelWidthPercent(v)
    if (n === root.panelWidthPercent) return
    root.panelWidthPercent = n
    root.savePrefs()
  }

  // ─── Persistencia de los niveles de UI ─────────────────────────
  readonly property string prefsDir: Quickshell.env("HOME") + "/.config/oozeshell"
  readonly property string prefsFile: prefsDir + "/ui.json"

  function clampLevel(v) {
    const n = parseInt(v)
    return isNaN(n) ? 2 : Math.max(0, Math.min(4, n))
  }

  function savePrefs() {
    savePrefsProc.json = JSON.stringify({
      fontLevel: root.fontLevel, fontPercent: root.fontPercent, barLevel: root.barLevel, windowLevel: root.windowLevel,
      uiAnimationMode: root.uiAnimationMode,
      barPosition: root.barPosition, barFloating: root.barFloatingPref,
      islands: root.islandsPref,
      pillMode: root.pillModePref, pillAutoHide: root.pillAutoHidePref,
      pillTraySync: root.pillTraySyncPref,
      lightMode: root.lightMode, uiStyle: root.uiStyle, pixelFont: root.pixelFontPref,
      launcherAttached: root.launcherAttached, terminal: root.terminalId,
      launcherImage: root.launcherShowImage, launcherSize: root.launcherSize,
      launcherParticles: root.launcherParticlesEnabled,
      launcherWallpaperLive: root.launcherWallpaperLiveEnabled,
      lockWallpaper: root.lockWallpaperMode, lockWallpaperPath: root.lockWallpaperPath,
      effects: root.effectsOn,
      mprisCompact: root.mprisCompact, taskbarCompact: root.taskbarCompact,
      dockEnabled: root.dockEnabled, batteryEnabled: root.batteryEnabled,
      dockPosition: root.dockPosition, dockAutoHide: root.dockAutoHide,
      pillScale: root.pillScalePercent, dockScale: root.dockScalePercent,
      dashboardLevel: root.dashboardLevel,
      defaultSchemeIndex: root.defaultSchemeIndex, panelWidthPercent: root.panelWidthPercent,
      audioMonitorsCardEnabled: root.audioMonitorsCardEnabled,
      paletteMode: root.paletteMode, manualPaletteIndex: root.manualPaletteIndex,
      frameStyle: root.frameStyle, frameCurveRadius: root.frameCurveRadius,
      frameThickness: root.frameThickness
    })
    // Con el proceso aún corriendo, `running = true` NO hace nada (y
    // `running = false` solo lo mata): si spameabas un botón (p. ej. el modo
    // claro) el último guardado se perdía o dejaba ui.json a medias. Ahora, si
    // hay uno en curso, se marca para repetir al terminar con lo más nuevo.
    if (savePrefsProc.running) root.saveAgain = true
    else savePrefsProc.running = true
  }
  property bool saveAgain: false

  // kind: "font" | "bar" | "window"
  function setLevel(kind, v) {
    const n = root.clampLevel(v)
    if (kind === "font") { root.fontLevel = n; root.fontPercent = 0 }
    else if (kind === "bar") root.barLevel = n
    else if (kind === "window") root.windowLevel = n
    else return
    root.savePrefs()
  }

  // Preset general: barra + ventanas juntas (la fuente no se toca)
  function setInterfaceLevel(v) {
    const n = root.clampLevel(v)
    root.barLevel = n
    root.windowLevel = n
    root.savePrefs()
  }

  // Al mover la barra o cambiar el modo flotante, las ventanas de la barra
  // (fondo, módulos, botón ❄, esquinas) se DESMAPEAN un instante y se vuelven a
  // crear ya con sus anclas nuevas. Cambiarles las anclas "en caliente" deja
  // el compositor dibujando el búfer viejo (transparente) encima de otras
  // ventanas a la altura donde estaba la barra: parece que se "extienden".
  // Cada ventana de la barra incluye `!Theme.barRebuilding` en su `visible`.
  property bool barRebuilding: false

  Timer {
    id: rebuildTimer
    interval: 180
    repeat: false
    onTriggered: root.barRebuilding = false
  }

  function rebuildBar() {
    root.barRebuilding = true
    rebuildTimer.restart()
  }

  // Se está aplicando un wallpaper (o esquema) nuevo: la barra se esconde
  // un momento (ver Left/Center/RightModules → `suppressed`, alimentado por
  // Walls.changing vía shell.qml) mientras awww/matugen hacen lo suyo y el
  // Theme recarga la paleta. Un popup que ya estaba abierto (Keybinds, Menu,
  // Ajustes...) quedaría "colgando" de una barra que en ese instante no está
  // — FusedWindow lee esto para que su FusedPanel se dibuje FLOTANTE
  // (mismo modo que con una ventana en fullscreen) en vez de con las curvas
  // pegadas a una barra invisible, y vuelva a unirse solo cuando la barra
  // reaparece.
  property bool wallpaperChanging: false

  function setBarPosition(pos) {
    const valid = ["top", "bottom", "left", "right"]
    const next = valid.indexOf(pos) >= 0 ? pos : "top"
    if (next === root.barPosition) return
    root.rebuildBar()
    root.barPosition = next
    root.savePrefs()
  }

  function setIslandsEnabled(on) {
    if (!!on === root.islandsPref) return
    root.rebuildBar()
    root.islandsPref = !!on
    // Excluyente con Modo Píldora: activar Islas lo apaga.
    if (on && root.pillModePref) root.pillModePref = false
    root.savePrefs()
  }

  function setPillModeEnabled(on) {
    if (!!on === root.pillModePref) return
    root.rebuildBar()
    root.pillModePref = !!on
    // Excluyente con Modo Islas: activar Píldora lo apaga.
    if (on && root.islandsPref) root.islandsPref = false
    if (!on) AppState.closeDashboard()
    root.savePrefs()
  }

  function setPillAutoHide(on) {
    if (!!on === root.pillAutoHidePref) return
    root.pillAutoHidePref = !!on
    AppState.pillAutoHide = root.pillAutoHidePref
    root.savePrefs()
  }

  function setPillTraySync(on) {
    if (!!on === root.pillTraySyncPref) return
    root.pillTraySyncPref = !!on
    AppState.pillTraySync = root.pillTraySyncPref
    root.savePrefs()
  }

  function setBarFloating(on) {
    if (!!on === root.barFloatingPref) return
    root.rebuildBar()
    root.barFloatingPref = !!on
    root.savePrefs()
  }

  function resetLevels() {
    root.fontPercent = 0
    root.fontLevel = 2
    root.barLevel = 2
    root.windowLevel = 2
    root.savePrefs()
  }

  Process {
    id: loadPrefsProc
    command: ["bash", "-c", "cat '" + root.prefsFile + "' 2>/dev/null"]
    running: true
    property string buffer: ""
    stdout: SplitParser { onRead: line => loadPrefsProc.buffer += line }
    onRunningChanged: {
      if (running) return
      const raw = loadPrefsProc.buffer.trim()
      loadPrefsProc.buffer = ""
      if (raw === "") return
      try {
        const j = JSON.parse(raw)
        root.fontLevel   = root.clampLevel(j.fontLevel ?? 2)
        root.fontPercent = (j.fontPercent ?? 0) > 0 ? root.clampFontPercent(j.fontPercent) : 0
        root.barLevel    = root.clampLevel(j.barLevel ?? 2)
        root.windowLevel = root.clampLevel(j.windowLevel ?? 2)
        root.uiAnimationMode = ["normal", "minimal", "off"].indexOf(j.uiAnimationMode) >= 0 ? j.uiAnimationMode : "normal"
        root.barPosition = ["top", "bottom", "left", "right"].indexOf(j.barPosition) >= 0
                           ? j.barPosition : "top"
        root.barFloatingPref = j.barFloating === true
        root.islandsPref = j.islands === true
        root.pillModePref = j.pillMode === true
        root.pillAutoHidePref = j.pillAutoHide === true
        root.pillTraySyncPref = j.pillTraySync === true
        AppState.pillAutoHide = root.pillAutoHidePref
        AppState.pillTraySync = root.pillTraySyncPref
        root.uiStyle = (j.uiStyle === "cozy") ? "cozy" : "soft"
        root.pixelFontPref = typeof j.pixelFont === "string" ? j.pixelFont : ""
        root.lightMode = j.lightMode === true
        root.launcherAttached = j.launcherAttached !== false
        root.effectsOn = j.effects !== false
        root.mprisCompact = j.mprisCompact === true
        root.taskbarCompact = j.taskbarCompact === true
        root.launcherShowImage = j.launcherImage !== false
        root.launcherSize = Math.max(0, Math.min(2, parseInt(j.launcherSize ?? 1) || 0))
        root.launcherParticlesEnabled = j.launcherParticles !== false
        root.launcherWallpaperLiveEnabled = j.launcherWallpaperLive !== false
        root.lockWallpaperMode = j.lockWallpaper === "custom" ? "custom" : "auto"
        root.lockWallpaperPath = typeof j.lockWallpaperPath === "string" ? j.lockWallpaperPath : ""
        root.terminalId = (typeof j.terminal === "string" && j.terminal !== "") ? j.terminal : "foot"
        root.dockEnabled = j.dockEnabled === true
        root.batteryEnabled = j.batteryEnabled !== false
        root.dockPosition = ["top", "bottom"].indexOf(j.dockPosition) >= 0 ? j.dockPosition : "bottom"
        root.dockAutoHide = j.dockAutoHide === true
        root.pillScalePercent = root.clampOwnScale(j.pillScale ?? root.pillScaleDefault, root.pillScaleDefault)
        root.dockScalePercent = root.clampOwnScale(j.dockScale ?? root.dockScaleDefault, root.dockScaleDefault)
        root.dashboardLevel = Math.max(0, Math.min(4, parseInt(j.dashboardLevel ?? 0) || 0))
        root.defaultSchemeIndex = Math.max(0, Math.min(root.schemes.length - 1,
          parseInt(j.defaultSchemeIndex ?? 0) || 0))
        root.audioMonitorsCardEnabled = j.audioMonitorsCardEnabled !== false
        root.manualPaletteIndex = Math.max(0, Math.min(root.manualPalettes.length - 1,
          parseInt(j.manualPaletteIndex ?? 0) || 0))
        root.paletteMode = j.paletteMode === true
        root.frameStyle = (j.frameStyle === "curved") ? "curved" : "corners"
        root.frameCurveRadius = root.clampFrameCurveRadius(j.frameCurveRadius ?? 28)
        root.frameThickness = root.clampFrameThickness(j.frameThickness ?? 3)
        // Si arrancás en modo Paletas, pintá ya la paleta manual: si no, la
        // primera lectura de matugen-colors.json (loadColors, más abajo,
        // también corre al iniciar) la pisaría con la del wallpaper.
        if (root.paletteMode) root.applyManualPalette(root.manualPaletteIndex)
        // Clave vieja (panelWidthLevel, 0-4) de versiones anteriores: se
        // migra a porcentaje para no perder la preferencia guardada.
        if (j.panelWidthPercent !== undefined) {
          root.panelWidthPercent = root.clampPanelWidthPercent(j.panelWidthPercent)
        } else if (j.panelWidthLevel !== undefined) {
          const oldScales = [85, 92, 100, 112, 125]
          root.panelWidthPercent = root.clampPanelWidthPercent(
            oldScales[root.clampLevel(j.panelWidthLevel)])
        }
      } catch (e) {
        console.log("Theme: error leyendo ui.json:", e)
      }
    }
  }

  Process {
    id: savePrefsProc
    property string json: ""
    // Se escribe a un temporal y se renombra: si el proceso muere a medias,
    // ui.json anterior queda intacto en vez de vacío o cortado.
    command: ["bash", "-c",
      "mkdir -p '" + root.prefsDir + "' && cat > '" + root.prefsFile + ".tmp' << 'OOZE_EOF'\n" + json + "\nOOZE_EOF\n" +
      "mv -f '" + root.prefsFile + ".tmp' '" + root.prefsFile + "'"]
    running: false
    onRunningChanged: {
      if (running || !root.saveAgain) return
      root.saveAgain = false
      Qt.callLater(() => { savePrefsProc.running = true })
    }
  }

  // ─── Lectura de matugen ────────────────────────────────────────
  property string lastRaw: ""

  // Relee /tmp/matugen-colors.json YA (sin esperar al sondeo de 3 s).
  // Walls lo llama apenas matugen termina de escribir la paleta nueva.
  // Si justo hay una lectura en curso, encadena otra al terminar.
  property bool reloadAgain: false
  function reload() {
    if (loadColors.running) root.reloadAgain = true
    else loadColors.running = true
  }

  Process {
    id: loadColors
    command: ["cat", "/tmp/matugen-colors.json"]
    running: true
    property string buffer: ""

    stdout: SplitParser { onRead: line => loadColors.buffer += line }

    onRunningChanged: {
      if (running) return
      if (root.reloadAgain) {
        root.reloadAgain = false
        Qt.callLater(() => { loadColors.running = true })
      }
      const raw = loadColors.buffer
      loadColors.buffer = ""
      // Si no cambió nada, no reparseamos ni retocamos ningún color
      if (raw === "" || raw === root.lastRaw) return
      // En modo Paletas matugen ni siquiera corre, pero igual guardamos el
      // último json conocido (por si quedó de antes de activar Paletas) sin
      // pisar los colores manuales; se aplica recién al volver a Automático.
      if (root.paletteMode) { root.lastRaw = raw; return }
      root.applyPalette(raw)
    }
  }

  // Aplica la paleta `raw` (JSON de matugen) con la variante del modo actual.
  function applyPalette(raw) {
    try {
      const c = JSON.parse(raw).colors
      // Directo de lightMode: `schemeMode` es un binding derivado y, cuando
      // esto corre desde onLightModeChanged, puede no haberse actualizado
      // todavía (el orden no está garantizado) → paleta del modo contrario.
      const m = root.lightMode ? "light" : "dark"
      const p = k => c[k]?.[m]?.color
      const sf = col => root.lightMode ? root.soften(col) : col
      const pal = {
        bg:          sf(p("surface") ?? p("background") ?? root.bg),
        surface:     sf(p("surface_container") ?? root.surface),
        surfaceHigh: sf(p("surface_container_high") ?? root.surfaceHigh),
        primary:     p("primary") ?? root.primary,
        textOnPrimary: p("on_primary") ?? root.textOnPrimary,
        text:        p("on_surface") ?? p("on_background") ?? root.text,
        subtext:     p("secondary") ?? root.subtext,
        error:       p("error") ?? root.error,
        textOnError: p("on_error") ?? root.textOnError,
        primaryContainer:       p("primary_container") ?? root.primaryContainer,
        textOnPrimaryContainer: p("on_primary_container") ?? root.textOnPrimaryContainer,
        outline:     p("outline") ?? root.outline
      }
      // CoOzey: la paleta de matugen se calienta hacia papel/madera
      const f = root.cozy ? root.cozify(pal, !root.lightMode) : pal
      root.bg                     = f.bg
      root.surface                = f.surface
      root.surfaceHigh            = f.surfaceHigh
      root.primary                = f.primary
      root.textOnPrimary          = f.textOnPrimary
      root.text                   = f.text
      root.subtext                = f.subtext
      root.error                  = f.error
      root.textOnError            = f.textOnError
      root.primaryContainer       = f.primaryContainer
      root.textOnPrimaryContainer = f.textOnPrimaryContainer
      root.outline                = f.outline
      root.lastRaw = raw
    } catch (e) {
      console.log("Theme: error leyendo matugen:", e)
    }
  }

  Timer {
    interval: 3000
    running: true
    repeat: true
    onTriggered: { if (!loadColors.running) loadColors.running = true }
  }
}
