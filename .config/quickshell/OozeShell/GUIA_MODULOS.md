# OozeShell — Guía para agregar módulos

Esta guía explica cada pieza del sistema de módulos y cómo agregar cosas
nuevas. Hay dos tipos de "cosa nueva":

| Quiero agregar… | Cuánto trabajo | Sección |
|-----------------|----------------|---------|
| Una **categoría** en Ajustes avanzados | 1 archivo + 1 entrada | [§3](#3-agregar-una-categoría-a-ajustes-avanzados) |
| Una **sección o fila** dentro de una categoría | ~10 líneas | [§4](#4-agregar-una-sección-o-una-fila) |

> **Nota de estado.** Todo esto se escribió sin poder ejecutar Quickshell. La
> lista de comprobación de [§10](#10-checklist-y-problemas-típicos) dice qué
> mirar en la primera prueba.

---

## 1. Mapa del proyecto

```
OozeShell/
├── shell.qml                    ← arranque; cablea señales de AdvancedSettings
├── LANG/languages/Lang{Es,En,Id,Ja}.qml   ← textos, una clave por línea
├── SETTINGS/                    ← ventana "Ajustes avanzados"
│   ├── AdvancedSettings.qml     ← EL MARCO: ventana, barra lateral, buscador, scroll
│   ├── SettingsRegistry.qml     ← LISTA de categorías (una entrada por categoría)
│   ├── SettingsPage.qml         ← raíz de toda página
│   ├── SettingsSection.qml      ← tarjeta base (borde, título, descripción)
│   ├── SettingsPanelTitle.qml   ← título de la categoría (ícono + nombre)
│   ├── SettingsBtn.qml          ← botón chico de acción
│   ├── NumberStepper / ScaleSlider / LevelPicker / ImageBrowser   ← controles
│   └── pages/                   ← una página por categoría migrada
│       ├── AgendaPage.qml
│       ├── ServicesPage.qml
│       └── AboutPage.qml
└── tools/check.sh               ← chequeos rápidos (páginas, traducciones, qmllint)
```

Registro de categorías:

- **`SettingsRegistry`** → cada entrada es una categoría de Ajustes. De ahí
  salen solos: el ítem de la barra lateral, la carga de la página y sus
  entradas del buscador.

---

## 3. Agregar una categoría a Ajustes avanzados

Una categoría nueva = **una página en `SETTINGS/pages/` + una entrada en
`SettingsRegistry.qml`**. La página solo existe mientras su categoría está
elegida (la carga un `Loader`), así que sus `Process` y `Timer` no gastan nada
el resto del tiempo.

### 3.1 La página — `SETTINGS/pages/MiPage.qml`

```qml
import QtQuick
import QtQuick.Layouts
import ".."                 // SettingsPage, SettingsSection, SettingsBtn…
import "../../COMMON"       // Theme, SectionLabel…
import "../../LANG"         // Translations

SettingsPage {
  id: page
  catId: "mi"               // = id de la entrada del registro (pone el título solo)

  SettingsSection {
    titleKey: "miSeccionTitulo"
    hintKey:  "miSeccionHint"

    RowLayout {
      Layout.fillWidth: true
      SettingsBtn {
        icon: "󰐊"
        text: Translations.t("miAccion")
        primary: true
        onClicked: console.log("hola")
      }
      Item { Layout.fillWidth: true }
    }
  }
}
```

`SettingsPage` es un `ColumnLayout` con el título de la categoría ya puesto;
todo lo que declares adentro se apila debajo. `SettingsSection` es la tarjeta
(fondo, borde, `SectionLabel`, descripción); lo que declares adentro se apila
en su columna.

Propiedades útiles de `SettingsSection`:

| Propiedad | Para qué |
|-----------|----------|
| `titleKey`, `hintKey` | Título y descripción (opcionales) |
| `borderColor` | Resaltar el borde (ej. `flag ? Theme.primary : Theme.divider`) |
| `padding` | Margen interno (16 por defecto) |
| `spacing` | Separación entre hijos (10 por defecto) |

Sin `titleKey`/`hintKey` es solo la tarjeta vacía: úsala cuando dibujas tu propio
encabezado (como Tachidesk en `ServicesPage.qml`).

### 3.2 La entrada — `SETTINGS/SettingsRegistry.qml`

En `categories`, en la posición donde quieras que salga en la barra lateral:

```qml
{ id: "mi", icon: "󰀻", titleKey: "advCatMi", page: "pages/MiPage.qml",
  sections: [
    { titleKey: "miSeccionTitulo", hintKey: "miSeccionHint",
      kw: "palabras clave es en para el buscador",
      rows: [
        { labelKey: "miAccion", kw: "hacer accion run" }
      ] }
  ] }
```

| Campo | Significado |
|-------|-------------|
| `id` | String estable. Es el valor de `category` y el `catId` de la página |
| `icon` | Glifo Nerd Font del chip |
| `titleKey` | Clave de traducción del nombre |
| `page` | Archivo relativo a `SETTINGS/`. `""` = categoría todavía inline |
| `sections` | Lo buscable (ver §4) |

### 3.3 Traducciones

`advCatMi` (nombre de la categoría) y las claves de tus secciones, en los 4
idiomas.

No hace falta tocar `qmldir` para las páginas: se cargan por ruta de archivo,
no por nombre de tipo.

### 3.4 Contrato entre el marco y la página

El `Loader` del marco inyecta dos propiedades en tu página:

| Propiedad | Qué es | Uso típico |
|-----------|--------|------------|
| `page.active` | `true` mientras la ventana está abierta | `Timer { running: page.active … }` |
| `page.host` | El `AdvancedSettings` (marco) | Señales y propiedades del marco |

Desde `host` se llega a lo que antes era `root`:

```qml
onClicked: page.host.languageChosen("en")          // emitir una señal del marco
text: page.host ? page.host.targetMonitor : ""     // leer una propiedad
```

Las señales que hoy emite el marco (y por tanto las páginas pueden reenviar):
`closeRequested`, `backRequested`, `requestMonitorEditor`, `languageChosen`,
`monitorChosen`, `requestCornersToggle`, `appearancePreviewChanged`,
`appearanceValueCommitted`, `appearanceToggleChanged`. Propiedades:
`targetMonitor`, `resolvedMonitor`, `screenCorners`, `appearanceValues`. El
cableado de `shell.qml` no cambia.

`host` puede ser `null` un instante mientras la página se construye: léelo
dentro de bindings y handlers, no en un `Component.onCompleted` que dependa de
él al primer instante.

### 3.5 Estado, Process y Timer

Todo lo que solo usa tu página va **dentro de la página**: propiedades,
funciones, `Process`, `Timer`. Modelos a copiar:

- `pages/ServicesPage.qml` — polling con `Timer { running: page.active }` y dos
  `Process` (estado y acción).
- `pages/AboutPage.qml` — un `Process` que se lanza una vez en
  `Component.onCompleted` y con un botón de refrescar.

Consecuencia a tener presente: al cambiar de categoría la página se destruye y
su estado se pierde; al volver, se reconstruye. Si algo debe sobrevivir
(un caché, una lista cara de calcular), va en un singleton propio o en el marco.

---

## 4. Agregar una sección o una fila

### 4.1 Una sección nueva en una página existente

1. En la página, agrega otro `SettingsSection { … }`.
2. En `SettingsRegistry.qml`, en `sections` de esa categoría, agrega su
   metadato `{ titleKey, hintKey, kw, rows }`.
3. Traducciones.

### 4.2 Una fila nueva dentro de una sección

1. Agrega el control dentro de la sección.
2. En el registro, agrega `{ labelKey: "…", kw: "…" }` a las `rows` de esa sección.

### 4.3 Por qué el metadato está en el registro y no en la sección

Las páginas se cargan bajo demanda. Cuando escribes en el buscador, la página
donde está la opción no existe, así que no puede "registrarse sola". Por eso lo
buscable se declara junto a la entrada de la categoría, en `sections`. El costo
es declarar la fila dos veces (el control y su metadato). Si eso molesta más
adelante, la alternativa es un manifiesto generado o cargar las páginas de
forma invisible; hoy se prefirió no cargar todo.

---

## 5. Cómo funciona el buscador

1. **Índice.** `AdvancedSettings.searchIndex` junta: las filas escritas a mano
   de las categorías que siguen inline (`E("id", key, hint, kw, sec)`), los
   sliders de Hyprland y `SettingsRegistry.searchEntries` (generado desde
   `sections`).
2. **Filtrado.** Todos los términos deben aparecer en el label, la sección, el
   nombre de la categoría, la descripción o las palabras clave. El label pesa
   más. Sin tildes ni mayúsculas.
3. **Resultado → salto.** Al elegir uno, `goToEntry` cambia `category`; el
   `Loader` carga la página; en `onLoaded` se arma el temporizador y
   `scrollToAnchor` busca **el texto visible** (`Text.text` o `SettingsBtn.text`)
   que coincida y resalta la tarjeta que lo contiene.

Reglas para que un resultado "aterrice":

- El texto del `labelKey` (o `anchor` si lo defines) debe existir **tal cual**
  en la página, en un `Text`/`SectionLabel`/`SettingsBtn` visible.
- `anchor` sirve cuando el label no es el texto que se ve.
- Una entrada cuya clave no tiene traducción se descarta del buscador
  (la tarjeta se dibuja igual).

---

## 6. Componentes reutilizables

| Componente | Para qué |
|------------|----------|
| `SettingsBtn` | Botón chico: `icon`, `text`, `primary`, `enabled`, `onClicked` |
| `SettingsSection` | Tarjeta con título/descripción |
| `SettingsPanelTitle` | Título de categoría (`catId` o `icon` + `title`) |
| `NumberStepper` | Número con − / + y edición directa (`value`, `min`, `max`, `step`, `suffix`, `onEdited`) |
| `ScaleSlider` | Slider de porcentaje (`value`, `min`, `max`, `step`, `defaultValue`, `suffix`, `onEdited`) |
| `LevelPicker` | 5 presets fijos, Pequeño…Exorbitante (`level`, `names`, `showNames`, `onPicked`) |
| `ImageBrowser` | Mini explorador de imágenes (`onPicked(path)`, `onCancelled`, `go(dir)`) |
| `SectionLabel` (COMMON) | Encabezado en versalitas |

Los **inline components no se pueden usar desde otros archivos**. Si algo lo
necesita más de una página, hazlo archivo propio en `SETTINGS/` y regístralo en
`SETTINGS/qmldir`. (Pendiente: `AudioRow` sigue inline dentro del marco.)

---

## 7. Traducciones

Cada clave va en los cuatro archivos, una por línea:

```qml
// LANG/languages/LangEs.qml  (dentro de strings: ({ … }))
miSeccionTitulo: "Mi sección",
```

Un texto que falta en un idioma cae al inglés; si tampoco existe, `t()`
devuelve la clave tal cual (nunca revienta, pero se ve la clave).

`bash tools/check.sh` verifica que toda clave usada en los registros y en las
páginas exista en es/en/id/ja.

---

## 8. Migrar una categoría que sigue inline

Quedan inline: Perfil, General, HyprMonitor, Apariencia, Interfaz y Audio. La
receta, que es la misma que se siguió con Agenda, Servicios y Acerca de:

1. **Ubicar el bloque.** En `AdvancedSettings.qml`, el `ColumnLayout` con
   `visible: !root.searching && root.category === "id"`, junto con su comentario
   de banner.
2. **Ubicar su estado.** Propiedades, funciones, `Process` y `Timer` que solo
   ese bloque usa (busca por el prefijo: `hm…`, `oozeAudio…`, etc.).
3. **Crear `pages/XPage.qml`** con `SettingsPage { catId: "id" … }`.
4. **Mover el estado** dentro de la página cambiando `root.` → `page.`.
   `Timer { running: root.open && root.category === X }` → `running: page.active`.
5. **Mover el contenido.** Cada tarjeta `Rectangle { … ColumnLayout {…} }` pasa a
   `SettingsSection { … }` (su contenido interno, sin el `Rectangle` ni el
   `ColumnLayout` envolventes).
6. **Lo que depende del marco** (señales, `targetMonitor`…) se reemplaza por
   `page.host.*`.
7. **Registro.** En `SettingsRegistry.qml`, `page: "pages/XPage.qml"` y pasa sus
   `E("id", …)` de `searchIndex` a `sections`.
8. **Limpiar el marco.** Borra el bloque, el estado migrado, sus `E(...)` y
   la rama de `Connections { onCategoryChanged }` si la tenía.
9. `bash tools/check.sh`, abrir la categoría, probar buscar sus opciones.

Puntos a vigilar según la categoría:

| Categoría | Complicación |
|-----------|--------------|
| Perfil | Usa `browsing` / `profileBrowser` (explorador de imágenes) del marco |
| General | Varias señales del marco: `languageChosen`, `monitorChosen`, `requestMonitorEditor` |
| HyprMonitor | La más grande: mapa de arrastre y escritura de `monitors.lua`. Separar en `HyprMonitorPage` + `HmMap.qml`. Hoy se redetecta en `onCategoryChanged`; en la página pasa a `Component.onCompleted` |
| Apariencia / Interfaz | Usan `appearanceValues` y sus tres señales; muchas filas que también están en el `searchIndex` |
| Audio | `AudioRow` inline; el `Connections` a `AudioService.onCommandFailed`, `oozeAudioError` y el refresco de la primera vez |

---

## 9. Ciclo de vida (por qué pasa lo que pasa)

```
elegir categoría ─► category = "id" ─► pageLoader.source cambia
                                       ├─ destruye la página anterior (y sus Process/Timer)
                                       └─ construye la nueva ─► onLoaded:
                                              item.host   = AdvancedSettings
                                              item.active = binding a root.open
buscar             ─► pageLoader.active = false (se ven resultados, no páginas)
cerrar la ventana  ─► page.active = false; al terminar el fade se destruye la página
```

Consecuencias: una página nunca está "medio viva" en segundo plano; `active`
solo se necesita para pausar lo que corre mientras la ventana está cerrada; una
página que necesita datos al abrirse los pide en `Component.onCompleted`.

---

## 10. Checklist y problemas típicos

Primera prueba tras estos cambios:

- [ ] `bash tools/check.sh` sin errores.
- [ ] El shell arranca sin errores en la consola.
- [ ] Barra lateral con las 9 categorías, en el mismo orden de siempre.
- [ ] **Agenda**: aparece la tarjeta de alarmas del ToDo.
- [ ] **Servicios**: el badge pasa de "desconocido" a activo/inactivo; Iniciar/Detener/Reiniciar funcionan; la salida se autoscrollea.
- [ ] **Acerca de**: carga la info del sistema; el botón de refrescar gira; los repos abren en el navegador.
- [ ] Buscar "tachidesk", "reloj", "github", "alarma": el resultado lleva a la categoría, scrollea y resalta la tarjeta.
- [ ] Cambiar entre categorías migradas e inline no deja contenido a medias ni el scroll fuera de lugar.
- [ ] Cerrar la ventana con Servicios abierto: no queda `tachidesk status` ejecutándose (mirar `ps`).

Problemas típicos:

| Síntoma | Causa probable |
|---------|----------------|
| La página no aparece / error "type not found" para `SettingsPage`, `SettingsBtn`… | El `import ".."` de la página no resuelve el `qmldir` de `SETTINGS/`. Plan B: mover las páginas a `SETTINGS/` (sin subcarpeta), quitar el `import ".."`, cambiar `"../../COMMON"` por `"../COMMON"` (igual con LANG y WIDGETS), registrarlas en `SETTINGS/qmldir` y poner `page: "MiPage.qml"` en el registro |
| `SettingsRegistry is not defined` | Falta la línea `singleton SettingsRegistry …` en `SETTINGS/qmldir` |
| La página se carga pero mide 0 de alto | El `Loader` no propaga el tamaño: revisa que la raíz de la página sea el `SettingsPage` (un `ColumnLayout`) y no un `Item` sin `implicitHeight` |
| Buscar y elegir un resultado abre la categoría pero no scrollea | El texto del `labelKey` no coincide con el visible. Usa `anchor` o corrige la clave |
| Cambio de idioma y el buscador queda en el idioma anterior | Un binding no lee `Translations.t(...)` durante su evaluación (se guardó un string ya traducido en una propiedad no reactiva) |
| Un `Timer` de la página sigue corriendo cerrada la ventana | Falta atarlo a `page.active` |

---

## 11. Estado de la migración

| Categoría | `id` | Estado |
|-----------|------|--------|
| Agenda | `agenda` | ✅ página (`pages/AgendaPage.qml`) |
| Servicios | `services` | ✅ página (`pages/ServicesPage.qml`) |
| Acerca de | `about` | ✅ página (`pages/AboutPage.qml`) |
| Perfil | `profile` | inline |
| General | `general` | inline |
| HyprMonitor | `hypr` | inline |
| Apariencia | `appearance` | inline |
| Interfaz | `interface` | inline |
| Audio | `audio` | inline |

Cambios de diseño respecto de `SIGUIENTE_FASE.md`:

- `category` es un **string** (`"services"`), ya no un número.
- `SettingsSection` **no lleva `kw`**: lo buscable vive en `sections` del
  registro, porque una página sin cargar no puede responderle al buscador
  (ver §4.3).
- La página se destruye al cerrar la ventana (`Loader.active`), no solo al
  cambiar de categoría.
