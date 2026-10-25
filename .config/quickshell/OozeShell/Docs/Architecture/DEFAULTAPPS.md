# DEFAULTAPPS — apps predeterminadas e IPC `apps`

- Qué es
  - Una capa que responde a una pregunta: "¿qué app abro para esto?". Cada **función** (navegador, archivos, editor…) tiene una app elegida; el shell la abre sola o a pedido de MangoWM / niri vía IPC.
  - Se configura en **Ajustes avanzados → Apps predeterminadas** y se usa desde fuera con el target IPC `apps`.
- Archivos
  - `Services/DefaultApps/DefaultApps.qml` → singleton con el catálogo, la elección del usuario, la construcción del comando y la persistencia.
  - `Services/DefaultApps/DefaultAppsHost.qml` → `Scope` que expone el `IpcHandler` `apps` y avisa con una notificación si no hay app disponible.
  - `Tools/oozeshell` → lanzador corto para el IPC (`oozeshell apps open browser`).
  - `Services/DefaultApps/qmldir` → registra el singleton y el host.
  - `Settings/pages/DefaultAppsPage.qml` → página de ajustes (elección por función + comandos listos para copiar).
  - `Settings/SettingsRegistry.qml` → categoría `defaultapps` y su índice de búsqueda.
  - `Services/Lang/languages/Lang{En,Es}.qml` → claves `da*` y `advCatDefaultApps`.
  - `shell.qml` → `import "Services/DefaultApps"` y una instancia `DefaultAppsHost {}` junto a QuickSearch.

## Funciones (roles)

| id | Qué abre | Origen de la elección |
|---|---|---|
| `browser` | navegador (con URL opcional, ventana privada opcional) | compartida con QuickSearch (`QuickBarConfig.browserId`) |
| `terminal` | terminal (con comando opcional) | compartida con `Theme.terminalId` |
| `files` | gestor de archivos (con carpeta opcional) | `defaultapps.toml` |
| `editor` | editor de texto (con archivo opcional) | `defaultapps.toml` |
| `mail` | cliente de correo (con `mailto:` opcional) | `defaultapps.toml` |
| `music` | reproductor de música | `defaultapps.toml` |
| `video` | reproductor de video | `defaultapps.toml` |
| `images` | visor de imágenes | `defaultapps.toml` |
| `pdf` | lector de PDF | `defaultapps.toml` |
| `monitor` | monitor del sistema | `defaultapps.toml` |

`browser` y `terminal` no se guardan en este módulo: leen y escriben la misma preferencia que ya usan QuickSearch y el Launcher, para que haya una sola fuente de verdad. Por eso no tienen opción "Personalizada".

## Cómo se decide qué comando se ejecuta

Para cada función, `DefaultApps.argvFor(role, args, priv)` sigue este orden:

1. `browser` y `terminal` → se arma con `QuickBarConfig.browserCommand` / `Theme.terminalCmd`.
2. Elección **Personalizada** → el comando escrito por el usuario + los argumentos (archivo, URL…). Si está vacío, se cae al paso 3.
3. Elección **Predeterminada del sistema** (`system`) →
   - con argumento: `xdg-open <argumento>`;
   - sin argumento: carpeta personal para `files`, `mailto:` para `mail`, y para el resto la primera app instalada del catálogo.
4. Elección de una **app del catálogo** → su binario detectado + argumentos. Si la app es de terminal (`term: true`: nvim, yazi, btop…), se antepone `Theme.terminalCmd`.

Si no sale ningún comando, `run()` devuelve `no-app`, emite la señal `failed(role)` y el host muestra una notificación.

## Mapa de bloques de `DefaultApps.qml`

| Bloque | Qué contiene |
|---|---|
| `ESTADO` | `choices`, `customs`, `installed`, `detected`, `loaded`, señal `failed`, ruta del TOML |
| `CATÁLOGO` | `roles` (cada una con `id`, `icon`, `nameKey`, `linked`, `apps[]`) y `extRoles` (extensión → función) |
| `CONSULTAS` | `roleInfo`, `appInfo`, `binOf`, `isInstalled`, `choiceOf`, `choicesFor` |
| `CAMBIAR` | `setChoice`, `setCustom` |
| `COMANDOS` | `splitArgs`, `expandPath`, `appArgv`, `systemArgv`, `browserArgv`, `terminalArgv`, `argvFor`, `run` |
| `DESTINOS` | `openUrl`, `openFile`, `openDir`, `openAny`, `runInTerminal`, `describe`, `snapshot` |
| `DETECCIÓN` | `Process` que busca con `command -v` cada binario del catálogo |
| `PERSISTENCIA` | `save()` (escritura atómica `.tmp` + `mv`) y `loadProc` (valida lo leído) |

Cada app del catálogo es `{ id, name, bins[], term }`: `bins` son los nombres de binario alternativos y `term` indica si necesita terminal.

## IPC

Target `apps`. Todas las funciones devuelven una cadena: `ok`, `no-app` (no hay app para esa función), `invalid`, `unknown-role` o `empty`; `get`, `state` y `sysget` devuelven JSON y `list` los ids separados por `, `.

| Función | Efecto |
|---|---|
| `open <rol>` | abre la app de esa función |
| `openWith <rol> <arg>` | la abre pasándole un argumento (archivo, carpeta, URL) |
| `any <destino>` | decide sola: `mailto:` → correo, URL → navegador, carpeta (termina en `/` o `~`) → archivos, archivo → según extensión |
| `url <dirección>` / `urlPrivate <dirección>` | navegador (normal / ventana privada); `mailto:` va al correo |
| `file <ruta>` | abre un archivo con la función que corresponde a su extensión; si no la conoce usa `xdg-open` |
| `dir <ruta>` | gestor de archivos en esa carpeta (sin ruta, la personal) |
| `term <comando>` | ejecuta el comando dentro de la terminal elegida |
| `set <rol> <app>` | cambia la app (`system`, `custom` o el id del catálogo) |
| `custom <rol> <comando>` | fija un comando personalizado y lo activa |
| `get <rol>` | JSON `{role, choice, custom, shared, command}` |
| `list` | ids de las funciones separados por coma |
| `state` | JSON con `get` de todas las funciones |
| `sysget <rol>` | consulta con `xdg-mime` el predeterminado del sistema; JSON `{role, id, pending, error}` |
| `sysset <rol> <desktopId>` | fija con `xdg-mime` el predeterminado del sistema para esa función |

```sh
oozeshell apps open browser
oozeshell apps url https://archlinux.org
oozeshell apps dir '~/Descargas'
oozeshell apps file '~/Documentos/manual.pdf'
oozeshell apps term 'btop'
oozeshell apps set files thunar
oozeshell apps custom browser 'flatpak run org.mozilla.firefox'
oozeshell apps get editor
```

Los argumentos con espacios van entre comillas. `oozeshell` es el lanzador corto de `Tools/oozeshell`; ver la sección siguiente.

## El comando `oozeshell`

`qs ipc` siempre necesita saber qué shell consultar (`-p <carpeta>` o `-c <nombre>`); sin eso busca una config llamada `default`. `Tools/oozeshell` resuelve esa ruta solo y pasa el resto a `qs ipc call`.

Instalación (una vez):

```sh
ln -s ~/.config/quickshell/OozeShell/Tools/oozeshell ~/.local/bin/oozeshell
```

En NixOS con home-manager:

```nix
home.packages = [
  (pkgs.writeShellScriptBin "oozeshell" ''exec ${pkgs.bash}/bin/bash /home/USUARIO/.config/quickshell/OozeShell/Tools/oozeshell "$@"'')
];
```

Formas aceptadas (todas equivalentes a `qs ipc -p <shell> call -- …`):

| Escribes | Ejecuta |
|---|---|
| `oozeshell apps open browser` | `apps open browser` |
| `oozeshell open browser` | `apps open browser` (si el segundo término es una función de `apps`) |
| `oozeshell launcher toggle` | `launcher toggle` |
| `oozeshell toggle launcher` | `launcher toggle` (verbo primero: `toggle`, `open`, `close`) |
| `oozeshell open launcher windows` | `launcher open windows` |
| `oozeshell call apps open files` | `apps open files` |
| `oozeshell list` | `qs ipc show` (targets y funciones) |
| `oozeshell where` | carpeta del shell que se está usando |

Cómo busca el shell, en orden: `$OOZESHELL_DIR`, la carpeta que contiene `shell.qml` (el directorio padre del script; funciona también a través de un enlace simbólico), `~/.config/quickshell/OozeShell`, `~/.config/quickshell/oozeshell`. `QS_BIN` cambia el binario (por defecto `qs`, o `quickshell` si no existe).

`~/.local/bin` debe estar en el `PATH` de quien lanza el comando. En MangoWM y niri los binds heredan el `PATH` del compositor: si no lo ves, instala por NixOS/home-manager o enlaza en una carpeta que sí esté en él.

## Uso desde MangoWM y niri

Ambos solo necesitan ejecutar el comando `oozeshell apps open <rol>`; la elección de app vive en el shell, así que cambiarla en Ajustes no obliga a tocar la configuración del compositor.

**MangoWM** (`~/.config/mango/conf/keybinds.conf`):

```
bind=SUPER,b,spawn,oozeshell apps open browser
bind=SUPER,e,spawn,oozeshell apps open files
bind=SUPER,n,spawn,oozeshell apps open editor
bind=SUPER,Return,spawn,oozeshell apps open terminal
```

**niri** (`~/.config/niri/modules/binds.kdl`, dentro de `binds { }`):

```kdl
Mod+T {
    spawn-sh "quickshell ipc -p ~/.config/quickshell/OozeShell/shell.qml call -- apps open terminal";
}
Mod+E {
    spawn-sh "quickshell ipc -p ~/.config/quickshell/OozeShell/shell.qml call -- apps open files";
}
Mod+B {
    spawn-sh "quickshell ipc -p ~/.config/quickshell/OozeShell/shell.qml call -- apps open browser";
}
Mod+R {
    spawn-sh "quickshell ipc -p ~/.config/quickshell/OozeShell/shell.qml call -- launcher toggle";
}
```

En niri se usa `spawn-sh` con el comando completo en una sola cadena: pasa por un shell, así que expande `~` y no depende de que `oozeshell` esté en el `PATH`. La página de Ajustes genera estos bloques para la función que elijas, con botón de copiar.

## Estado y datos

- `~/.config/oozeshell/defaultapps.toml`:

  ```toml
  [choices]
  files = "thunar"
  editor = "nvim"
  pdf = "system"

  [customs]
  music = "flatpak run com.spotify.Client"
  ```

- Una función sin entrada vale `system`. Al leer, se descartan ids que ya no existan en el catálogo.
- El navegador se guarda en `~/.config/oozeshell/quickbar.toml` y la terminal en `~/.config/oozeshell/ui.toml`.
- La detección de binarios corre una vez al arrancar; `installed` es `{ rol: { appId: binario } }`.

## Dependencias

- `DefaultApps.qml` importa `COMMON` (`Theme`) y `Modules/QuickBar` (`QuickBarConfig`).
- `DefaultAppsHost.qml` importa `Services/Lang`, `Services/Notify` (`NotificationsBackend.pushLocal`) y `Services/DefaultApps`.
- Externos: `qs`/`quickshell` (lo usa `oozeshell`), `xdg-open` (respaldo y "predeterminada del sistema") y `wl-copy` (botón copiar de la página).

## Notas

- Agregar una app a una función: añadir `{ id, name, bins, term }` en `apps[]` de esa función dentro de `DefaultApps.roles`. La página y la detección la toman solas.
- Agregar una función nueva: una entrada en `roles` con `linked: ""`, claves `daRoleXxx` en los idiomas (`Services/Lang/languages/LangEs.qml` y `LangEn.qml`) y, si procede, sus extensiones en `buildExtRoles()`. El IPC `apps open <id>` ya funciona sin más cambios.
- Agregar un idioma: replicar las claves `da*` en el nuevo `LangXx.qml`.
- El editor de este módulo es independiente del editor de archivos de QuickSearch (`QuickBarConfig.fileEditor`).
- Si el IPC se llama justo al arrancar el shell, antes de que se lea el TOML, usa los valores por defecto.
