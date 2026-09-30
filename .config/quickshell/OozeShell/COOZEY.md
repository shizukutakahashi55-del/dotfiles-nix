# CoOzey — estilo acogedor de OozeShell

Ajustes avanzados → Apariencia → Automático: elige **OozeSoft** (el de siempre) o **CoOzey**.
Atajo: `quickshell ipc -p .../shell.qml call theme style cozy|soft`.

Tokens nuevos en `COMMON/Theme.qml`: `cozy`, `uiStyle`, `fontFamily` / `monoFamily` / `cozyFamily`,
`ink`, `edge`, `inkWidth`, `bw1`, `shadowY`, `shadowInk`, `paperShine`, `cardRadius`, `panelRadius`.

Para que un componente nuevo respete el estilo: usa `Theme.fontFamily` en textos, `Theme.monoFamily`
en íconos Nerd Font, `Theme.edge` / `Theme.bw1` en bordes de tarjetas y `Theme.ink` / `Theme.inkWidth`
en superficies grandes.

Fuente: Varela Round (OFL), en `assets/fonts/`.

## Kit semi pixel art (COMMON/)

Solo se usa con `Theme.cozy`; OozeSoft queda igual.

| Componente | Qué es |
|---|---|
| `NotchRect` | rectángulo con esquinas escalonadas (sin radio curvo) y degradado repartido en 3 franjas |
| `CozyBox` | tarjeta de papel: sombra dura + tinta + degradado cálido + filo de luz + tramado opcional (`dither`) |
| `CozyButton` | botón de juego: se hunde al pulsar; `active` lo "enciende" |
| `PixelBar` | barra de progreso por bloques |
| `PixelRing` | medidor circular de cuentas (reemplaza al arco liso) |
| `PixelSteps` | historial en columnas escalonadas (reemplaza al `Sparkline`) |
| `PixelLevels` | columna de LEDs para ecualizadores |

Aplicado en: `MPRIS/Mpris.qml` (+ `MprisWaves.qml`: colinas de píxeles a ~7 fps), `DASHBOARD/DashboardMpris.qml`,
`DASHBOARD/DashboardPerformance.qml`, `MENU/MetricCard.qml`.
Patrón: el original queda con `visible: !Theme.cozy` y la versión pixel con `visible: Theme.cozy`.
`CozyBox`/`CozyButton` dibujan la sombra FUERA de su alto (`shadowOffset`): deja ese margen debajo.

---

## CoOzey pixel (v2)

CoOzey ahora es pixel de punta a punta:

- **Paneles (`FusedPanel`)**: las esquinas y las curvas que los unen a la barra se dibujan como **escalones** de píxeles enteros (`FusedPanel.corner`), con contorno de ingletes (`MiterJoin`). OozeSoft sigue usando arcos.
- **Radios**: `cardRadius 4`, `panelRadius 12`, `islandRadius 8`, barra flotante 4 (OozeSoft no cambia). Los `radius: Theme.cozy ? N` de tarjetas pasaron a 4 / 2.
- **Fuente**: texto en fuente pixel; **íconos siempre en `Theme.monoFamily`** (Nerd Font). Los 3 sitios que aún mezclaban familia (`Mpris.qml` ícono de reproductor, campana de `CenterModules.qml`, etiquetas de `DashboardHeader`/`ServicesPage`) ya usan `monoFamily`.

## Fuentes

Instala UNA fuente pixel + UNA Nerd Font para los íconos:

| Para | Fuente | Notas |
|---|---|---|
| Texto (recomendada) | **Pixelify Sans** | legible desde 12 px, tiene acentos y ñ, pesos 400–700 |
| Texto (alternativas) | Jersey 10 / Jersey 15, Silkscreen, VT323, Tiny5, Press Start 2P | Silkscreen y Press Start 2P son más "arcade" (mejor en títulos, ≥ 13 px) |
| Japonés (idioma JA) | **DotGothic16** | Pixelify Sans no trae kana/kanji |
| Íconos (obligatoria) | **JetBrainsMono Nerd Font** (o *Symbols Nerd Font Mono*) | de aquí salen TODOS los glifos: dashboard, mpris, performance, visualizador |

`Theme.pixelFamily` elige sola, en este orden: `assets/fonts/PixelFont.ttf` → `"pixelFont"` de `~/.config/oozeshell/ui.json` → primera de `Theme.pixelCandidates` instalada → Varela Round → `monoFamily`.
Para forzar una: `"pixelFont": "VT323"` en `ui.json`, o `Theme.setPixelFont("VT323")`.

Si prefieres no instalar nada: copia el `.ttf` a `assets/fonts/PixelFont.ttf`.

Instalación: ver `tools/fonts/fonts.nix.example` (NixOS / home-manager) y `tools/fonts/99-oozeshell-pixel.conf` (fontconfig: manda los glifos que la fuente pixel no tenga a la Nerd Font).

Tras instalar: `fc-cache -f` y reinicia quickshell (`Qt.fontFamilies()` se lee al arrancar).

## Colores (v2.1)

Automático sigue matugen en AMBOS estilos. CoOzey ya no "calienta" la paleta hacia marrón:
`Theme.cozify()` devuelve la paleta de matugen sin tocar. Con paletas fijas (Nord, Gruvbox…) los colores son los elegidos.

## Menús pixel (v2.2)

Nuevo `COMMON/SkinRect.qml`: reemplazo directo de `Rectangle`. En OozeSoft es un Rectangle normal; en CoOzey dibuja caja pixel
(contorno de tinta con esquinas escalonadas, filo de luz y, con `raised: true`, sombra dura). `inkColor` cambia el contorno.
Aplicado en: `MENU/Menu.qml`, `POWER/PowerMenu.qml`, `AUDIO/AudioMenu.qml`, `NETWORK/NetworkMenu.qml`, `BLUETOOTH/BluetoothMenu.qml`.
- Sliders de volumen (Menú y Audio): en CoOzey se dibuja `PixelBar` (bloques) y el track suave se oculta; el arrastre no cambia.
- Sin `scale` al pulsar/seleccionar en CoOzey (escalar pixel art lo vuelve borroso).
- Tooltips: usan `FusedPanel`, así que heredan esquinas escalonadas y contorno; en CoOzey `tipFlare 8`, `tipRadius 8`, `flare 12`.
- `Avatar`: esquinas de 6 px en vez de círculo.
Para un componente nuevo: usa `SkinRect` en lugar de `Rectangle` si quieres que se vea pixel en CoOzey.

## Tamaño de fuente manual (v2.3)

Ajustes avanzados → General → Tamaño → Ajuste fino: campo numérico "Tamaño de fuente manual" (50–250 %, pasos de 5, o escribe el número + Enter),
justo encima de los selectores de nivel. `Theme.fontPercent` (0 = usar nivel) manda sobre `fontLevel`; se guarda en `ui.json` (`fontPercent`).
Elegir un nivel de Fuente o pulsar "Restablecer" lo vuelve a 0. `Theme.fs(px)` y `Theme.bfs(px)` ya lo usan.
