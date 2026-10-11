// SettingsRegistry — lista única de las categorías de Ajustes avanzados.
// TODO lo genérico se arma desde acá:

pragma Singleton
import QtQuick
import Quickshell
import "../LANG"
import "../COMMON"

Singleton {
  id: root


  readonly property var allCategories: [
    { id: "profile",    icon: "󰀄", titleKey: "advCatProfile",     page: "" },
    { id: "general",    icon: "󰒓", titleKey: "advCatGeneral",     page: "" },
    { id: "globalmanager", icon: "󰖯", titleKey: "advCatGlobalManager", page: "pages/GlobalManagerPage.qml",
      sections: [
        { titleKey: "gmWmTitle", hintKey: "gmWmHint",
          kw: "window manager wm compositor hyprland mango mangowm niri sesion",
          rows: [] },
        { titleKey: "gmDistroTitle", hintKey: "gmDistroHint",
          kw: "distro distribucion arch nixos paquetes package search buscador nix-search",
          rows: [
            { labelKey: "gmPkgHelperTitle", kw: "paru yay pacman aur gestor paquetes helper" }
          ] },
        { titleKey: "gmCapsTitle", hintKey: "gmCapsHint",
          kw: "compatibilidad capacidades soporte blur sombras animaciones layouts monitor",
          rows: [] }
      ] },
    { id: "hypr",       icon: "󰹑", titleKey: "advCatHyprMonitor", page: "", requires: "monitorEditor" },
    { id: "keybinds",   icon: "󰌌", titleKey: "advCatKeybinds",  page: "pages/KeybindsPage.qml",
      sections: [
        { titleKey: "kbListTitle", hintKey: "kbListHint",
          kw: "keybinds binds atajos teclado shortcuts combinacion combo editar borrar restaurar hyprland",
          rows: [
            { labelKey: "kbEdit", kw: "editar cambiar combo edit change" },
            { labelKey: "kbDelete", kw: "borrar desactivar eliminar quitar delete remove disable" },
            { labelKey: "kbRestore", kw: "restaurar recuperar restore" }
          ] },
        { titleKey: "kbNewTitle", hintKey: "kbNewHint",
          kw: "nuevo agregar crear bind custom personalizado add new create comando exec",
          rows: [
            { labelKey: "kbAdd", kw: "agregar anadir nuevo crear add" }
          ] }
      ] },
    { id: "appearance", icon: "󰏘", titleKey: "advCatAppearance",  page: "" },
    { id: "wallpapers",  icon: "󰸉", titleKey: "advCatWallpapers",  page: "pages/WallpapersPage.qml",
      sections: [
        { titleKey: "wallsFoldersTitle", hintKey: "wallsFoldersHint",
          kw: "carpeta carpetas folder directorio ruta path wallpapers livewallpapers live video videos imagenes fondo examinar",
          rows: [
            { labelKey: "wallsFolderStatic", kw: "wallpapers imagenes fondos carpeta folder ruta path jpg png" },
            { labelKey: "wallsFolderLive",   kw: "livewallpapers live video videos mp4 mpvpaper carpeta folder ruta path" }
          ] },
        { titleKey: "wallsStaticTitle", hintKey: "wallsStaticHint",
          kw: "estatico estaticos imagen awww ajuste fit crop stretch no recortar encajar estirar bandas relleno color",
          rows: [
            { labelKey: "wallsStaticFit",  hintKey: "wallsStaticFitHint", kw: "ajuste fit crop llenar encajar estirar stretch original recortar resize" },
            { labelKey: "wallsStaticFill", hintKey: "wallsStaticFillHint", kw: "color relleno bandas fill hex negro" }
          ] },
        { titleKey: "wallsOnlineTitle", hintKey: "wallsOnlineHint",
          kw: "online internet en linea wallhaven bing descargar descarga fuente remoto nube wallpapers fondos busqueda sfw matugen",
          rows: [
            { labelKey: "wallsOnlineSource",  kw: "fuente source wallhaven bing" },
            { labelKey: "wallsOnlineQuery",   hintKey: "wallsOnlineQueryHint", kw: "busqueda buscar search consulta palabras clave keywords tags" },
            { labelKey: "wallsOnlineSorting", kw: "orden sorting top popular aleatorio random recientes latest relevancia vistas" },
            { labelKey: "wallsOnlineCats",    kw: "categorias categories general anime personas people" },
            { labelKey: "wallsOnlinePurity", hintKey: "wallsOnlinePurityHint", kw: "pureza purity nsfw sfw sketchy adulto +18 contenido" },
            { labelKey: "wallsOnlineRes",     kw: "resolucion minima resolution 1080p 1440p 4k" },
            { labelKey: "wallsOnlineApiKey",  hintKey: "wallsOnlineApiKeyHint", kw: "api key clave token wallhaven" },
            { labelKey: "wallsOnlineSaveDir", hintKey: "wallsOnlineSaveDirHint", kw: "carpeta descargas folder download guardar ruta path" }
          ] },
        { titleKey: "wallsLiveTitle", hintKey: "wallsLiveHint",
          kw: "live en vivo video animado mpvpaper mpv fondo animado rendimiento ram vram gpu cpu matugen",
          rows: [
            { labelKey: "wallsLiveOptimize",   hintKey: "wallsLiveOptimizeHint", kw: "copia liviana optimizar ffmpeg reencodear ligera ahorro memoria" },
            { labelKey: "wallsLiveMaxHeight",  kw: "alto maximo altura resolucion 1080p 720p height" },
            { labelKey: "wallsLiveMaxFps",     kw: "fps cuadros fotogramas 30 60 framerate" },
            { labelKey: "wallsLiveSwap",       hintKey: "wallsLiveSwapHint", kw: "cambiar copia parpadeo relanzar swap" },
            { labelKey: "wallsLiveStopHidden", hintKey: "wallsLiveStopHiddenHint", kw: "parar pausar fullscreen pantalla completa ahorro energia power-saver ocultar" },
            { labelKey: "wallsLiveRam",        hintKey: "wallsLiveRamHint", kw: "ram memoria tope limite fuga vigilante watchdog mb" },
            { labelKey: "wallsLiveFit",        hintKey: "wallsLiveFitHint", kw: "ajuste llenar encajar fill fit panscan recortar bandas" },
            { labelKey: "wallsLiveLayer",      hintKey: "wallsLiveLayerHint", kw: "capa layer bottom background" },
            { labelKey: "wallsLiveHwdec",      hintKey: "wallsLiveHwdecHint", kw: "hwdec hardware decodificacion vaapi nvdec gpu" }
          ] },
        { titleKey: "wallsToolsTitle", hintKey: "wallsToolsHint",
          kw: "herramientas instalar instalado dependencias requisitos awww mpvpaper ffmpeg socat curl jq matugen tools install",
          rows: [] },
        { titleKey: "cozyTitle", hintKey: "cozyHint",
          kw: "coozey cozy pixel acogedor papel cacao hoja paleta parchment cocoa meadow moss pumpkin calido warm estilo style",
          rows: [
            { labelKey: "cozyWarm",  hintKey: "cozyHint", kw: "calido tonos warm intensidad matugen automatico" }
          ] },
        { titleKey: "advMatugenTitle", hintKey: "advPaletteHint",
          kw: "matugen palette paleta colores color esquema scheme wallpaper fondo automatico",
          rows: [] }
      ] },
    { id: "interface",  icon: "󰍹", titleKey: "advCatInterface",   page: "" },

    { id: "dock",        icon: "▃", titleKey: "advCatDock",        page: "pages/DockPage.qml",
      sections: [
        { titleKey: "dockSection",
          kw: "dock iconos apps barra de aplicaciones",
          rows: [
            { labelKey: "dockEnable",   kw: "dock mostrar show activar encender apagar" },
            { labelKey: "dockAutoHide", kw: "auto ocultar hide esconder" },
            { labelKey: "dockPosition", kw: "posicion position arriba abajo izquierda derecha" }
          ] },
        { titleKey: "dockSize", hintKey: "dockSizeHint",
          kw: "tamano size escala scale dock grande pequeno",
          rows: [] },
        { titleKey: "advDockLookTitle", hintKey: "advDockLookHint",
          kw: "apariencia modo pildora pill panel fusionado fused flotante floating opacidad opacity transparencia blur desenfoque difuminado",
          rows: [
            { labelKey: "advDockModeLabel", hintKey: "advDockModeHint", kw: "modo mode pildora pill panel fusionado fused flotante floating" },
            { labelKey: "advDockOpacity",   kw: "opacidad opacity transparencia dock" },
            { labelKey: "advDockBlur",      kw: "blur desenfoque difuminado dock" }
          ] }
      ] },

    { id: "bar",         icon: "▀", titleKey: "advCatBar",         page: "pages/BarPage.qml",
      sections: [
        { titleKey: "barBackendTitle", hintKey: "barBackendHint",
          kw: "barra bar backend waybar ooze propio",
          rows: [
            { labelKey: "barOoze", kw: "ooze propio quickshell" },
            { labelKey: "barWaybar", kw: "waybar" }
          ] },
        { titleKey: "barSection", hintKey: "barSectionHint",
          kw: "barra bar posicion arriba abajo izquierda derecha flotante position top bottom left right floating",
          rows: [] },
        { titleKey: "barIslands", hintKey: "barIslandsHint",
          kw: "islas islands pildoras",
          rows: [] },
        { titleKey: "barGlass", hintKey: "barGlassHint",
          kw: "cristal glass transparencia translucido opacidad blur desenfoque vidrio",
          rows: [
            { labelKey: "barGlassOpacity", kw: "opacidad transparencia opacity" },
            { labelKey: "barGlassBlur", hintKey: "barGlassBlurHint", kw: "blur desenfoque xray compositor niri" },
            { labelKey: "barGlassSeam", hintKey: "barGlassSeamHint", kw: "union linea sombra franja seam borde barra oscura" }
          ] },
        { titleKey: "barPillMode", hintKey: "barPillModeHint",
          kw: "pildora pill dashboard compacta ocultar",
          rows: [
            { labelKey: "barPillAutoHide", kw: "ocultar esconder auto" },
            { labelKey: "barPillTraySync", kw: "tray bandeja sincronizar" },
            { labelKey: "pillSize", hintKey: "pillSizeHint", kw: "pildora pill tamano size escala scale grande pequeno" },
            { labelKey: "dashSize", hintKey: "dashSizeHint", kw: "dashboard tablero panel pildora pill tamano size grande pequeno niveles" }
          ] },
        { titleKey: "batterySection", hintKey: "batteryHint",
          kw: "bateria battery energia",
          rows: [] }
      ] },

    { id: "quickbar",    icon: "󰍉", titleKey: "advCatQuickBar",  page: "pages/QuickBarPage.qml",
      sections: [
        { titleKey: "qbLookTitle", hintKey: "qbLookHint",
          kw: "barra rapida quick bar spotlight posicion arriba abajo centro ancho tamano position width top bottom center compacto",
          rows: [
            { labelKey: "qbPosition", kw: "posicion arriba abajo centro top bottom center" },
            { labelKey: "qbWidth", kw: "ancho tamano compacto amplio width compact wide" }
          ] },
        { titleKey: "qbBrowserTitle", hintKey: "qbBrowserHint",
          kw: "navegador browser firefox chromium chrome brave librewolf zen vivaldi edge xdg-open",
          rows: [
            { labelKey: "qbBrowserPref", kw: "navegador preferido instalado firefox chromium brave default predeterminado" },
            { labelKey: "qbPrivate", hintKey: "qbPrivateHint", kw: "privada incognito privado private window ventana" }
          ] },
        { titleKey: "qbSearchTitle", hintKey: "qbSearchHint",
          kw: "busqueda web buscador google duckduckgo brave bing startpage ecosia search engine url",
          rows: [
            { labelKey: "qbEngine", kw: "buscador google duckduckgo bing ecosia startpage motor engine" },
            { labelKey: "qbCustomUrl", hintKey: "qbCustomUrlHint", kw: "personalizado custom url plantilla template" },
            { labelKey: "qbBangs", hintKey: "qbBangsHint", kw: "atajos sitio bang yt youtube gh github wiki wikipedia prefijo shortcuts" }
          ] },
        { titleKey: "qbFilesTitle", hintKey: "qbFilesHint",
          kw: "archivos carpetas buscar files search nvim neovim terminal editor fd find",
          rows: [
            { labelKey: "qbFilesEnable", kw: "archivos activar desactivar encender apagar on off files" },
            { labelKey: "qbFilesOpener", hintKey: "qbFilesOpenerHint", kw: "abrir con nvim neovim terminal editor xdg-open app" },
            { labelKey: "qbFilesEditor", hintKey: "qbFilesEditorHint", kw: "editor comando nvim vim helix neovim" },
            { labelKey: "qbFilesSmart", hintKey: "qbFilesSmartHint", kw: "imagenes pdf video audio no editables binarios" },
            { labelKey: "qbFilesRoots", hintKey: "qbFilesRootsHint", kw: "carpetas rutas home donde buscar folders paths" },
            { labelKey: "qbFilesDepth", hintKey: "qbFilesDepthHint", kw: "profundidad niveles subcarpetas depth" },
            { labelKey: "qbFilesMax", kw: "resultados cantidad maximo results" },
            { labelKey: "qbFilesHidden", kw: "ocultos hidden dotfiles" }
          ] }
      ] },

    { id: "launcher",    icon: "󰀻", titleKey: "advCatLauncher",    page: "pages/LauncherPage.qml",
      sections: [
        { titleKey: "lnBackendTitle", hintKey: "lnBackendHint",
          kw: "launcher lanzador backend rofi quickshell ooze aplicaciones apps drun",
          rows: [
            { labelKey: "lnQuickshell", kw: "quickshell ooze propio" },
            { labelKey: "lnRofi", kw: "rofi script" }
          ] },
        { titleKey: "settingsLauncherSection", hintKey: "settingsLauncherHint",
          kw: "launcher lanzador aplicaciones apps ubicacion posicion centro barra center bar imagen image tamano size",
          rows: [
            { labelKey: "settingsLauncherPlacement", kw: "ubicacion posicion centro barra center bar" },
            { labelKey: "settingsLauncherBar", kw: "barra bar pegado conectado" },
            { labelKey: "settingsLauncherCenter", kw: "centro centrado center" },
            { labelKey: "settingsLauncherImage", kw: "imagen image quitar" },
            { labelKey: "settingsLauncherSize", kw: "tamano size" }
          ] },
        { titleKey: "settingsLauncherPrefixes", hintKey: "settingsLauncherPrefixesHint",
          kw: "prefijos prefixes comandos commands paleta palette tmux busqueda search",
          rows: [
            { labelKey: "settingsLauncherPrefixes", hintKey: "settingsLauncherPrefixesHint", kw: "prefijos prefixes comandos commands paleta palette tmux" }
          ] },
        { titleKey: "settingsEffectsSection", hintKey: "settingsEffectsHint",
          kw: "efectos effects cpu gpu rendimiento performance",
          rows: [
            { labelKey: "settingsEffectsLabel", hintKey: "settingsEffectsHint", kw: "efectos effects" },
            { labelKey: "settingsLauncherParticles", hintKey: "settingsLauncherParticlesHint", kw: "particulas brillos particles glow" },
            { labelKey: "settingsLauncherWallpaperLive", hintKey: "settingsLauncherWallpaperLiveHint", kw: "fondo animado wallpaper video mpvpaper walls live" }
          ] }
      ] },

    { id: "powermenu",   icon: "󰐥", titleKey: "advCatPowerMenu",   page: "pages/PowerMenuPage.qml",
      sections: [
        { titleKey: "pmBackendTitle", hintKey: "pmBackendHint",
          kw: "powermenu energia apagar reiniciar suspender backend rofi quickshell sesion power",
          rows: [
            { labelKey: "pmQuickshell", kw: "quickshell ooze propio" },
            { labelKey: "pmRofi", kw: "rofi script" }
          ] }
      ] },

    { id: "agenda",      icon: "󰃭", titleKey: "advCatAgenda",      page: "pages/AgendaPage.qml",
      sections: [
        { titleKey: "todoAlarmsTitle", hintKey: "todoAlarmsHint",
          kw: "alarma alarmas recordatorio recordatorios aviso notificacion hora reminder alarm todo agenda",
          rows: [
            { labelKey: "todoAlarmsEnable", kw: "alarma alarmas activar desactivar encender apagar on off" },
            { labelKey: "todoAlarmSound", hintKey: "todoAlarmSoundHint", kw: "sonido audio pitido campana beep sound pw-play paplay" },
            { labelKey: "todoAlarmPersistent", hintKey: "todoAlarmPersistentHint", kw: "notificacion persistente fija pantalla critica cerrar sticky" },
            { labelKey: "todoAlarmTest", kw: "probar prueba test alarma notificacion" }
          ] }
      ] },

    { id: "services",   icon: "󰆍", titleKey: "advCatServices",    page: "pages/ServicesPage.qml",
      sections: [
        { titleKey: "advTachideskTitle", hintKey: "advTachideskHint",
          kw: "manga servidor server systemd servicio service",
          rows: [
            { labelKey: "advTachideskStart",       kw: "iniciar start encender tachidesk" },
            { labelKey: "advTachideskStop",        kw: "detener stop apagar tachidesk" },
            { labelKey: "advTachideskRestart",     kw: "reiniciar restart tachidesk" },
            { labelKey: "advTachideskOutputTitle", kw: "salida output estado status log" }
          ] }
      ] },

    { id: "audio",      icon: "󰕾", titleKey: "advCatAudio",       page: "" },

    { id: "widgets",    icon: "󰕮", titleKey: "advCatWidgets",     page: "pages/WidgetsPage.qml",
      sections: [
        { titleKey: "wgGlobalTitle", hintKey: "wgGlobalHint",
          kw: "widgets global todos apagar encender opacidad blur desenfoque difuminado off on",
          rows: [
            { labelKey: "wgEnabled", kw: "apagar encender todos on off enable" },
            { labelKey: "wgGlobalOpacity", kw: "opacidad opacity transparencia" },
            { labelKey: "wgGlobalBlur", kw: "blur desenfoque difuminado" }
          ] },
        { titleKey: "wgGeneralTitle", hintKey: "wgGeneralHint",
          kw: "widgets escritorio desktop reloj clock sistema cpu ram gpu pomodoro temporizador timer mover arrastrar editar redimensionar resize tamano capa layer wallpaper fondo mpvpaper awww",
          rows: [
            { labelKey: "wgEditMode", kw: "mover arrastrar editar posicion redimensionar resize tamano move drag edit" },
            { labelKey: "wgLayerTitle", hintKey: "wgLayerHint", kw: "capa layer bottom background fondo wallpaper encima debajo" },
            { labelKey: "wgRaise", kw: "subir levantar tapa mpvpaper fondo animado live raise" }
          ] },
        { titleKey: "wgAddTitle", hintKey: "wgAddHint",
          kw: "agregar anadir nuevo crear widget add new create reloj clock sistema system pomodoro" },
        { titleKey: "wgListTitle",
          kw: "lista widgets estilo style monitor pantalla posicion tamano size opciones apagar encender quitar eliminar blur desenfoque difuminado cristal vidrio pomodoro" }
      ] },

    { id: "about",      icon: "󰋽", titleKey: "advCatAbout",       page: "pages/AboutPage.qml",
      sections: [
        { titleKey: "advAboutSysInfoTitle", kw: "sistema system info hostname kernel uname cpu ram quickshell qt version",
          rows: [
            { labelKey: "advAboutCopy", kw: "copiar copy portapapeles clipboard reporte bug info sistema" }
          ] },
        { titleKey: "advAboutPathsTitle", kw: "carpeta carpetas ruta paths config cache shell directorio abrir folder" },
        { titleKey: "advAboutRepoTitle", kw: "github git repositorio repos dotfiles codigo",
          rows: [
            { labelKey: "advAboutRepoDotfilesTitle", kw: "dotfiles hyprland github git" },
            { labelKey: "advAboutRepoNixTitle",      kw: "nixos nix home configuracion github git" }
          ] }
      ] }
  ]


  readonly property var categories: root.allCategories.filter(c => !c.requires || WM.has(c.requires))

  // ── Consultas ────────────────────────────────────────────────────────
  function byId(id) {
    for (const c of root.categories) if (c.id === id) return c
    return null
  }
  function iconOf(id)     { const c = root.byId(id); return c ? c.icon : "" }
  function titleKeyOf(id) { const c = root.byId(id); return c ? c.titleKey : "" }
  function pageOf(id)     { const c = root.byId(id); return (c && c.page) ? c.page : "" }


  readonly property var searchEntries: {
    const out = []
    for (const c of root.categories) {
      for (const s of (c.sections ?? [])) {
        out.push({ cat: c.id, key: s.titleKey, text: "", hint: s.hintKey ?? "",
                   kw: s.kw ?? "", sec: "", anchor: s.anchor ?? "" })
        for (const r of (s.rows ?? []))
          out.push({ cat: c.id, key: r.labelKey, text: "", hint: r.hintKey ?? "",
                     kw: r.kw ?? "", sec: s.titleKey, anchor: r.anchor ?? "" })
      }
    }
    return out
  }
}
