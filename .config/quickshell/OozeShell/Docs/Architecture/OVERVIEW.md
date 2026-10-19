# OVERVIEW — cuadrícula de todas las ventanas

- Qué es: popup casi a pantalla completa (90 % del monitor) con una tarjeta por cada ventana abierta,
  de todos los workspaces y monitores. Elegir una tarjeta enfoca la ventana y lleva al workspace donde
  está. Funciona igual en barra y en píldora.
- Compositores: en los WMs con overview nativo (`WM.hasNativeOverview`, hoy Niri) el target `overview`
  delega en el nativo y este popup no se usa. En Hyprland y Mango abre esta cuadrícula.
- Archivos:
  - `Modules/Overview/Overview.qml` → superficie `oozeshell-overview` (capa Overlay, teclado exclusivo),
    cuadrícula, teclado y miniaturas
  - `Core/Ipc/OverviewIpc.qml` → IPC `overview`
- Acceso: solo por IPC y por el comando `overview` del launcher. No hay botón en la barra ni sección
  en el dashboard.
- IPC (`Core/Ipc/OverviewIpc.qml`, target `overview`):

  | Función | Efecto |
  |---|---|
  | `toggle` | si `WM.hasNativeOverview`, alterna el nativo; si no, abre/cierra la cuadrícula |
  | `open` | abre |
  | `close` | cierra |

  ```sh
  quickshell ipc -c OozeShell call -- overview toggle
  quickshell ipc -c OozeShell call -- overview open
  quickshell ipc -c OozeShell call -- overview close
  ```
- Disposición: las tarjetas se ordenan por uso reciente (la enfocada primero). Las columnas se calculan
  para que quepan todas sin desplazar; si no caben con tarjetas de al menos 250 px, el grid hace scroll.
  Cada tarjeta muestra icono, título, clase, workspace (resaltado si está visible), marca de flotante y,
  con varios monitores, el monitor. La miniatura es en vivo para ventanas del workspace activo y una
  captura única para el resto.
- Teclado: flechas / `hjkl` / `Tab` mueven, `↵` o `Espacio` abre, `1–9` salta a la n-ésima, `Home` /
  `End`, `Esc` cierra. El clic fuera del panel o el botón de cerrar también cierran.
- Estado: `overviewOpen` en `shell.qml`, excluyente con el resto de popups (`closeAllPopupsExceptAdvanced`).
  Monta con `LazyPopup` y retiene clientes con `WM.retainClients("overview")` mientras está abierto
  (en Hyprland engancha `HyprState.retain`). Al elegir una ventana cierra primero y enfoca 140 ms
  después, para que el compositor no devuelva el foco a la ventana anterior.
- Dependencias: `COMMON` (WM, Theme, SkinRect), `Services/Lang`, `Quickshell.Wayland`.
