// SettingsRegistry — lista única de las categorías de Ajustes avanzados, ordenadas por grupo (Usuario · Aspecto · Escritorio · Sistema · Acerca de).

pragma Singleton
import QtQuick
import Quickshell
import "../Services/Lang"
import "../COMMON"

Singleton {
  id: root


  readonly property var allCategories: [
    { id: "profile", group: "personal",    icon: "󰀄", titleKey: "advCatProfile",     page: "pages/ProfilePage.qml" },

    { id: "general", group: "personal",    icon: "󰒓", titleKey: "advCatGeneral",     page: "pages/GeneralPage.qml" },

    { id: "appearance", group: "look", icon: "󰏘", titleKey: "advCatAppearance",  page: "pages/AppearancePage.qml" },

    { id: "interface", group: "look",  icon: "󰕰", titleKey: "advCatInterface",   page: "pages/InterfacePage.qml" },

    { id: "wallpapers", group: "look",  icon: "󰸉", titleKey: "advCatWallpapers",  page: "pages/WallpapersPage.qml",
      sections: [
        { titleKey: "wallsFoldersTitle",
          kw: "carpeta carpetas folder directorio ruta path wallpapers livewallpapers live video videos imagenes fondo examinar descargas download",
          rows: [
            { labelKey: "wallsFolderStatic", kw: "wallpapers imagenes fondos carpeta folder ruta path jpg png" },
            { labelKey: "wallsFolderLive",   kw: "livewallpapers live video videos mp4 mpvpaper carpeta folder ruta path" },
            { labelKey: "wallsOnlineSaveDir", kw: "carpeta descargas folder download guardar ruta path online" }
          ] },
        { titleKey: "wallsLayoutTitle",
          kw: "galeria layout diseno disposicion compacto compact top normal selectores barra panel wallpapers fondos",
          rows: [
            { labelKey: "wallsLayoutChoice", hintKey: "wallsLayoutChoiceHint", kw: "layout compacto compact normal top selectores barra galeria disposicion" },
            { labelKey: "wallsLayoutSize", kw: "tamano tamaño size escala scale slider galeria compact normal porcentaje" }
          ] },
        { titleKey: "advMatugenTitle", hintKey: "advPaletteHint",
          kw: "matugen palette paleta colores color esquema scheme wallpaper fondo automatico",
          rows: [] },
        { titleKey: "wallsStaticTitle",
          kw: "estatico estaticos imagen awww oozewalls ajuste fit crop stretch no recortar encajar estirar bandas relleno color",
          rows: [
            { labelKey: "wallsStaticEngine", hintKey: "wallsStaticEngineHint", kw: "motor engine backend awww oozewalls capa layer imagen estatico ligero ram" },
            { labelKey: "wallsStaticFit", kw: "ajuste fit crop llenar encajar estirar stretch original recortar resize" },
            { labelKey: "wallsStaticFill", hintKey: "wallsStaticFillHint", kw: "color relleno bandas fill hex negro" }
          ] },
        { titleKey: "wallsAnimTitle",
          kw: "animacion transicion cambio fade desvanecer deslizar slide barrido wipe circulo zoom persianas aleatoria random efecto duracion",
          rows: [
            { labelKey: "wallsAnimKind", hintKey: "wallsAnimHint", kw: "animacion transicion cambio fade desvanecer deslizar slide barrido wipe circulo zoom persianas aleatoria random efecto" },
            { labelKey: "wallsAnimDuration", kw: "duracion tiempo velocidad milisegundos ms animacion transicion" }
          ] },
        { titleKey: "wallsLiveTitle",
          kw: "live en vivo video animado mpvpaper mpv fondo animado rendimiento gpu cpu matugen",
          rows: [
            { labelKey: "wallsLiveEngine", hintKey: "wallsLiveEngineHint", kw: "motor engine backend mpvpaper oozewalls control restaurar inicio" },
            { labelKey: "wallsLiveFit", kw: "ajuste llenar encajar fill fit panscan recortar bandas" },
            { labelKey: "wallsLiveLayer", hintKey: "wallsLiveLayerHint", kw: "capa layer bottom background" },
            { labelKey: "wallsLiveHwdec", hintKey: "wallsLiveHwdecHint", kw: "hwdec hardware decodificacion vaapi nvdec gpu" }
          ] },
        { titleKey: "wallsLiveSaveTitle",
          kw: "ahorro recursos rendimiento ram vram memoria live en vivo video optimizar",
          rows: [
            { labelKey: "wallsLiveOptimize", hintKey: "wallsLiveOptimizeHint", kw: "copia liviana optimizar ffmpeg reencodear ligera ahorro memoria" },
            { labelKey: "wallsLiveMaxHeight", kw: "alto maximo altura resolucion 1080p 720p height" },
            { labelKey: "wallsLiveMaxFps", kw: "fps cuadros fotogramas 30 60 framerate" },
            { labelKey: "wallsLiveSwap", hintKey: "wallsLiveSwapHint", kw: "cambiar copia parpadeo relanzar swap" },
            { labelKey: "wallsLiveStopHidden", hintKey: "wallsLiveStopHiddenHint", kw: "parar pausar fullscreen pantalla completa ahorro energia power-saver ocultar" },
            { labelKey: "wallsLiveRam", hintKey: "wallsLiveRamHint", kw: "ram memoria tope limite fuga vigilante watchdog mb" }
          ] },
        { titleKey: "wallsOnlineTitle", hintKey: "wallsOnlineHint",
          kw: "online internet en linea wallhaven bing descargar descarga fuente remoto nube wallpapers fondos busqueda sfw matugen",
          rows: [
            { labelKey: "wallsOnlineSource", kw: "fuente source wallhaven bing" },
            { labelKey: "wallsOnlineQuery", hintKey: "wallsOnlineQueryHint", kw: "busqueda buscar search consulta palabras clave keywords tags" },
            { labelKey: "wallsOnlineSorting", kw: "orden sorting top popular aleatorio random recientes latest relevancia vistas" },
            { labelKey: "wallsOnlineCats", kw: "categorias categories general anime personas people" },
            { labelKey: "wallsOnlineRes", kw: "resolucion minima resolution 1080p 1440p 4k" },
            { labelKey: "wallsOnlinePurity", hintKey: "wallsOnlinePurityHint", kw: "pureza purity nsfw sfw sketchy adulto +18 contenido" },
            { labelKey: "wallsOnlineApiKey", hintKey: "wallsOnlineApiKeyHint", kw: "api key clave token wallhaven" }
          ] },
        { titleKey: "wallsToolsTitle", hintKey: "wallsToolsHint",
          kw: "herramientas instalar instalado dependencias requisitos awww oozewalls mpvpaper ffmpeg socat curl jq matugen tools install",
          rows: [] }
      ] },

    { id: "bar", group: "desktop", icon: "shape:bar", titleKey: "advCatBar", page: "pages/BarPage.qml",
      sections: [
        { titleKey: "barBackendTitle", hintKey: "barBackendHint",
          kw: "barra bar backend motor waybar ooze propio",
          rows: [
            { labelKey: "barOoze", kw: "ooze propio quickshell" },
            { labelKey: "barWaybar", kw: "waybar" }
          ] },
        { titleKey: "barSection", hintKey: "barSectionHint",
          kw: "barra bar posicion arriba abajo izquierda derecha flotante islas ocultar esconder marco frame position top bottom left right floating",
          rows: [
            { labelKey: "barPosition", kw: "posicion position arriba abajo izquierda derecha top bottom left right" },
            { labelKey: "barFloating", kw: "flotante floating" },
            { labelKey: "barIslands", hintKey: "barIslandsHint", kw: "islas islands pildoras" },
            { labelKey: "barHide", hintKey: "barHideHint", kw: "ocultar esconder hide barra bar oculta" },
            { labelKey: "barRevealMode", hintKey: "barRevealHint", kw: "mostrar revelar hover click raton" },
            { labelKey: "barHideFrame", hintKey: "barHideFrameHint", kw: "marco marcos frame esquinas corners ocultar" }
          ] },
        { titleKey: "barModulesTitle", hintKey: "barModulesHint",
          kw: "modulos modules isla islands picker elegir orden order mover move izquierda centro derecha left center right reloj clock audio bateria tray bandeja taskbar mpris notificaciones",
          rows: [] },
        { titleKey: "barGlass", hintKey: "barGlassHint",
          kw: "cristal glass transparencia translucido opacidad blur desenfoque vidrio",
          rows: [
            { labelKey: "barGlassOpacity", kw: "opacidad transparencia opacity" },
            { labelKey: "barGlassBlur", hintKey: "barGlassBlurHint", kw: "blur desenfoque xray compositor niri" },
            { labelKey: "barGlassSeam", hintKey: "barGlassSeamHint", kw: "union linea sombra franja seam borde barra oscura" }
          ] },
        { titleKey: "barFloatWin", hintKey: "barFloatWinHint",
          kw: "flotante flotantes floating ventanas windows tooltips popups animacion animation resorte spring zoom pop slide fade",
          rows: [
            { labelKey: "barWinAnim", hintKey: "barWinAnimHint", kw: "animacion animation estilo style resorte spring suave smooth zoom pop deslizar slide fade desvanecer" }
          ] },
        { titleKey: "barPillMode", hintKey: "barPillModeHint",
          kw: "pildora pill compacta ocultar",
          rows: [
            { labelKey: "barPillAutoHide", kw: "ocultar esconder auto" },
            { labelKey: "barPillTraySync", kw: "tray bandeja sincronizar" },
            { labelKey: "pillSize", hintKey: "pillSizeHint", kw: "pildora pill tamano size escala scale grande pequeno" }
          ] },
        { titleKey: "dashSection", hintKey: "dashSectionHint",
          kw: "dashboard tablero panel barra pildora pill bar",
          rows: [
            { labelKey: "dashSize", hintKey: "dashSizeHint", kw: "dashboard tablero panel barra bar pildora pill tamano size grande pequeno niveles" }
          ] },
        { titleKey: "batterySection", hintKey: "batteryHint",
          kw: "bateria battery energia",
          rows: [] }
      ] },

    { id: "dock", group: "desktop", icon: "shape:dock", titleKey: "advCatDock", page: "pages/DockPage.qml",
      sections: [
        { titleKey: "dockSection",
          kw: "dock iconos apps barra de aplicaciones",
          rows: [
            { labelKey: "dockEnable",   kw: "dock mostrar show activar encender apagar" },
            { labelKey: "dockAutoHide", kw: "auto ocultar hide esconder" },
            { labelKey: "dockPosition", kw: "posicion position arriba abajo izquierda derecha" }
          ] },
        { titleKey: "advDockLookTitle", hintKey: "advDockLookHint",
          kw: "apariencia modo pildora pill panel fusionado fused flotante floating tamano size escala scale opacidad opacity transparencia blur desenfoque difuminado",
          rows: [
            { labelKey: "advDockModeLabel", hintKey: "advDockModeHint", kw: "modo mode pildora pill panel fusionado fused flotante floating" },
            { labelKey: "dockSize", hintKey: "dockSizeHint", kw: "tamano size escala scale dock grande pequeno" },
            { labelKey: "advDockOpacity",   kw: "opacidad opacity transparencia dock" },
            { labelKey: "advDockBlur",      kw: "blur desenfoque difuminado dock" }
          ] }
      ] },

    { id: "widgets", group: "desktop",    icon: "󰕮", titleKey: "advCatWidgets",     page: "pages/WidgetsPage.qml",
      sections: [
        { titleKey: "wgGlobalTitle", hintKey: "wgGlobalHint",
          kw: "widgets global todos apagar encender opacidad blur desenfoque difuminado off on",
          rows: [
            { labelKey: "wgEnabled", kw: "apagar encender todos on off enable" },
            { labelKey: "wgGlobalOpacity", kw: "opacidad opacity transparencia" },
            { labelKey: "wgGlobalBlur", kw: "blur desenfoque difuminado" },
            { labelKey: "wgGlobalBorder", kw: "borde bordes border borders contorno degradado" }
          ] },
        { titleKey: "wgGeneralTitle", hintKey: "wgGeneralHint",
          kw: "widgets escritorio desktop reloj clock sistema cpu ram gpu pomodoro temporizador timer mover arrastrar editar redimensionar resize tamano capa layer wallpaper fondo mpvpaper awww",
          rows: [
            { labelKey: "wgQuickTitle", hintKey: "wgQuickHint", kw: "ajustes rapidos panel lateral compacto clic derecho quick settings side panel right click" },
            { labelKey: "wgEditMode", kw: "mover arrastrar editar posicion redimensionar resize tamano move drag edit" },
            { labelKey: "wgLayerTitle", hintKey: "wgLayerHint", kw: "capa layer bottom background fondo wallpaper encima debajo" },
            { labelKey: "wgFreeMove", hintKey: "wgFreeMoveHint", kw: "movimiento libre mover escritorio arrastrar free move drag" },
            { labelKey: "wgArrange", kw: "ordenar alinear acomodar arrange align overlap encimar" },
            { labelKey: "wgRaise", kw: "subir levantar tapa mpvpaper fondo animado live raise" }
          ] },
        { titleKey: "wgAddTitle", hintKey: "wgAddHint",
          kw: "agregar anadir nuevo crear widget add new create reloj clock sistema system pomodoro" },
        { titleKey: "wgListTitle",
          kw: "lista widgets estilo style monitor pantalla posicion tamano size opciones apagar encender quitar eliminar blur desenfoque difuminado cristal vidrio pomodoro" }
      ] },

    { id: "launcher", group: "desktop",    icon: "󰀻", titleKey: "advCatLauncher",    page: "pages/LauncherPage.qml",
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

    { id: "quickbar", group: "desktop",    icon: "󰍉", titleKey: "advCatQuickBar",  page: "pages/QuickBarPage.qml",
      sections: [
        { titleKey: "qbLookTitle", hintKey: "qbLookHint",
          kw: "quicksearch quick search barra rapida quick bar spotlight posicion arriba abajo centro ancho tamano position width top bottom center compacto",
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

    { id: "powermenu", group: "desktop",   icon: "󰐥", titleKey: "advCatPowerMenu",   page: "pages/PowerMenuPage.qml",
      sections: [
        { titleKey: "pmBackendTitle", hintKey: "pmBackendHint",
          kw: "powermenu energia apagar reiniciar suspender backend rofi quickshell sesion power",
          rows: [
            { labelKey: "pmQuickshell", kw: "quickshell ooze propio" },
            { labelKey: "pmRofi", kw: "rofi script" }
          ] }
      ] },

    { id: "oozelock", group: "desktop", icon: String.fromCodePoint(0xF033E), titleKey: "advCatOozeLock", page: "pages/OozeLockPage.qml",
      sections: [
        { titleKey: "olBackgroundTitle", hintKey: "olBackgroundHint",
          kw: "bloqueo lock lockscreen pantalla fondo wallpaper imagen blur desenfoque oscurecer brillo oozelock",
          rows: [
            { labelKey: "lockModeAuto", kw: "automatico auto wallpaper actual fondo" },
            { labelKey: "lockModeCustom", kw: "imagen personalizada custom ruta path" },
            { labelKey: "olBlur", hintKey: "olBlurHint", kw: "blur desenfoque difuminado fondo" },
            { labelKey: "olDim", hintKey: "olDimHint", kw: "oscurecer oscuro brillo dim darken fondo" }
          ] },
        { titleKey: "olLayoutTitle", hintKey: "olLayoutHint",
          kw: "bloqueo lock distribucion layout disposicion posicion reloj acceso login input campo contrasena izquierda derecha centro abajo oozelock",
          rows: [
            { labelKey: "olLayoutTitle", hintKey: "olLayoutHint", kw: "distribucion layout disposicion posicion reloj acceso login input campo contrasena sddm centrado columna esquina" },
            { labelKey: "olShowPower", hintKey: "olShowPowerHint", kw: "apagar reiniciar energia power shutdown reboot botones" }
          ] },
        { titleKey: "olInfoTitle", hintKey: "olInfoHint",
          kw: "bloqueo lock reloj hora 24 12 formato fecha avatar foto nombre teclado idioma bateria oozelock",
          rows: [
            { labelKey: "olClock24h", kw: "reloj hora 24 12 formato am pm" },
            { labelKey: "olClockStyle", kw: "reloj estilo clasico apilado minimalista tarjetas analogico clock style analog" },
            { labelKey: "olClockScale", kw: "reloj tamano escala size scale grande pequeno" },
            { labelKey: "olShowDate", kw: "fecha dia date" },
            { labelKey: "olShowAvatar", hintKey: "olShowAvatarHint", kw: "avatar foto perfil nombre bienvenida" },
            { labelKey: "olShowLayout", hintKey: "olShowLayoutHint", kw: "teclado idioma layout distribucion" },
            { labelKey: "olShowBattery", hintKey: "olShowBatteryHint", kw: "bateria battery porcentaje carga" }
          ] },
        { titleKey: "olWidgetsTitle", hintKey: "olWidgetsHint",
          kw: "bloqueo lock widgets addons complementos posicion arriba abajo clima musica oozelock",
          rows: [
            { labelKey: "olWidgetsStyle", hintKey: "olWidgetsStyleHint", kw: "dashboard panel vertical tarjetas cards diseno estilo widgets unificado" },
            { labelKey: "olDashScale", hintKey: "olDashScaleHint", kw: "dashboard tamano escala size scale panel grande pequeno" },
            { labelKey: "olSideWidth", hintKey: "olSideWidthHint", kw: "ancho panel lateral width izquierda derecha tamano" },
            { labelKey: "olPlacement", hintKey: "olPlacementHint", kw: "posicion arriba abajo izquierda derecha lateral vertical dashboard panel top bottom left right widgets" }
          ] },
        { titleKey: "olWeatherTitle", hintKey: "olWeatherHint",
          kw: "bloqueo lock clima weather temperatura pronostico ciudad celsius fahrenheit open-meteo oozelock",
          rows: [
            { labelKey: "olWeatherEnable", kw: "clima weather activar desactivar encender apagar" },
            { labelKey: "olWeatherCity", hintKey: "olWeatherCityHint", kw: "ciudad city lugar ubicacion coordenadas" },
            { labelKey: "olCardScale", hintKey: "olCardScaleHint", kw: "tamano escala size scale grande pequeno agrandar reducir clima weather" },
            { labelKey: "olWeatherStyle", hintKey: "olWeatherStyleHint", kw: "estilo forecast pronostico tarjeta card clasico widget diseno" },
            { labelKey: "olWeatherUnits", kw: "unidades celsius fahrenheit grados km mph" },
            { labelKey: "olWeatherForecast", hintKey: "olWeatherForecastHint", kw: "pronostico forecast proximos dias" },
            { labelKey: "olWeatherDays", hintKey: "olWeatherDaysHint", kw: "dias pronostico cantidad semana" },
            { labelKey: "olWeatherTint", hintKey: "olWeatherTintHint", kw: "color tinte velo degradado clima" },
            { labelKey: "olWeatherRefresh", kw: "actualizar refrescar minutos intervalo" }
          ] },
        { titleKey: "olMediaTitle", hintKey: "olMediaHint",
          kw: "bloqueo lock musica reproductor mpris media player spotify controles portada oozelock",
          rows: [
            { labelKey: "olMediaEnable", kw: "musica mpris reproductor activar desactivar" },
            { labelKey: "olCardScale", hintKey: "olCardScaleHint", kw: "tamano escala size scale grande pequeno agrandar reducir musica reproductor player" },
            { labelKey: "olMediaStyle", hintKey: "olMediaStyleHint", kw: "estilo reproductor player clasico audio visualizer diseno" },
            { labelKey: "olMediaVisualizer", hintKey: "olMediaVisualizerHint", kw: "espectro visualizador barras cava audio ecualizador" },
            { labelKey: "olMediaCover", kw: "portada caratula cover album" },
            { labelKey: "olMediaOnlyPlaying", hintKey: "olMediaOnlyPlayingHint", kw: "solo reproduciendo pausado ocultar" }
          ] },
        { titleKey: "olNotifTitle", hintKey: "olNotifHint",
          kw: "bloqueo lock notificaciones avisos apps privacidad notifications oozelock",
          rows: [
            { labelKey: "olNotifMode", kw: "notificaciones avisos apps solo mostrar ocultar privacidad contenido" },
            { labelKey: "olCardScale", hintKey: "olCardScaleHint", kw: "tamano escala size scale grande pequeno agrandar reducir notificaciones avisos" },
            { labelKey: "olNotifMax", hintKey: "olNotifMaxHint", kw: "maximo cantidad limite notificaciones avisos" }
          ] },
        { titleKey: "olResetTitle",
          kw: "restaurar reset valores predeterminados bloqueo lock oozelock",
          rows: [
            { labelKey: "olResetLabel", hintKey: "olResetHint", kw: "restaurar reset predeterminado defecto" }
          ] }
      ] },

    { id: "agenda", group: "desktop",      icon: "󰃭", titleKey: "advCatAgenda",      page: "pages/AgendaPage.qml",
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

    { id: "globalmanager", group: "system", icon: "󰖯", titleKey: "advCatGlobalManager", page: "pages/GlobalManagerPage.qml",
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

    { id: "hypr", group: "system",       icon: "󰹑", titleKey: "advCatHyprMonitor", page: "", requires: "monitorEditor" },

    { id: "audio", group: "system",      icon: "󰕾", titleKey: "advCatAudio",       page: "pages/AudioPage.qml" },

    { id: "keybinds", group: "system",   icon: "󰌌", titleKey: "advCatKeybinds",  page: "pages/KeybindsPage.qml",
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

    { id: "defaultapps", group: "system", icon: "󰓎", titleKey: "advCatDefaultApps", page: "pages/DefaultAppsPage.qml",
      sections: [
        { titleKey: "daAppsTitle", hintKey: "daAppsHint",
          kw: "apps predeterminadas default aplicaciones navegador terminal archivos editor musica video imagenes sistema xdg-open",
          rows: [
            { labelKey: "daRoleBrowser",  kw: "navegador browser firefox chromium brave zen web" },
            { labelKey: "daRoleTerminal", kw: "terminal foot kitty alacritty wezterm ghostty konsole" },
            { labelKey: "daRoleFiles",    kw: "archivos gestor files file manager thunar nautilus dolphin yazi ranger carpetas" },
            { labelKey: "daRoleEditor",   kw: "editor texto nvim neovim vim helix code zed kate nano" },
            { labelKey: "daRoleMusic",    kw: "musica music audio spotify rhythmbox cmus" },
            { labelKey: "daRoleVideo",    kw: "video mpv vlc reproductor player" },
            { labelKey: "daCustomLabel",  hintKey: "daCustomHint", kw: "comando personalizado custom command flatpak" }
          ] },
        { titleKey: "daIpcTitle", hintKey: "daIpcHint",
          kw: "ipc atajos bind keybind mango mangowm niri spawn quickshell qs apps abrir comando teclado",
          rows: [
            { labelKey: "daIpcCommand", kw: "comando shell qs quickshell ipc call apps open" },
            { labelKey: "daIpcMango",   kw: "mango mangowm bind spawn config" },
            { labelKey: "daIpcNiri",    kw: "niri bind spawn spawn-sh kdl config" },
            { labelKey: "daIpcFull",    kw: "comando completo qs quickshell ipc -p ruta" },
            { labelKey: "daIpcInstall", kw: "instalar oozeshell comando path enlace symlink ln local bin" }
          ] }
      ] },

    { id: "services", group: "system",   icon: "󰆍", titleKey: "advCatServices",    page: "pages/ServicesPage.qml",
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

    { id: "about", group: "about",      icon: "󰋽", titleKey: "advCatAbout",       page: "pages/AboutPage.qml",
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


  readonly property var groupOrder: ["personal", "look", "desktop", "system", "about"]
  function groupLabel(id) {
    const k = { personal: "setGroupUser", look: "setGroupLook", desktop: "setGroupDesktop", system: "setGroupSystem" }[id]
    return k ? Translations.t(k) : ""
  }

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
