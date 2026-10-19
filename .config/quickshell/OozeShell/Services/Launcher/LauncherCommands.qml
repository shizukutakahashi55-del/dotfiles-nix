// LauncherCommands — paleta de comandos del Launcher (modo `>`).

import QtQuick
import "../../COMMON"
import "../Lang"

QtObject {
  id: root


  readonly property var all: [
    { id: "settings", glyph: "󰒓", cmd: "settings", arg: "", submode: "", kw: "config configuracion ajustes preferences options opciones" },
    { id: "theme", glyph: "󰏘", cmd: "", arg: "", submode: ">theme ", kw: "tema color dark light oscuro claro colorful colorido modo" },
    { id: "walls", glyph: "󰸉", cmd: "walls", arg: "", submode: "", kw: "wallpaper fondo background imagen papel tapiz" },
    { id: "appearance", glyph: "󰏘", cmd: "appearance", arg: "", submode: "", kw: "apariencia aspecto look estilo style" },
    { id: "keybinds", glyph: "󰌌", cmd: "keybinds", arg: "", submode: "", kw: "atajos shortcuts teclas bindings hotkeys" },
    { id: "packages", glyph: "󰏖", cmd: "packages", arg: "", submode: "", kw: "paquetes install instalar pacman nix apt software" },
    { id: "clipboard", glyph: "󰅌", cmd: "clipboard", arg: "", submode: "", kw: "portapapeles copiar pegar paste historial history" },
    { id: "shotArea", glyph: "󰄀", cmd: "shot-area-copy", arg: "", submode: "", kw: "screenshot captura pantallazo screen area copiar" },
    { id: "shotAreaSave", glyph: "󰄀", cmd: "shot-area-save", arg: "", submode: "", kw: "screenshot captura pantallazo screen area guardar" },
    { id: "shotFull", glyph: "󰄀", cmd: "shot-full-save", arg: "", submode: "", kw: "screenshot captura pantallazo screen completa full" },
    { id: "power", glyph: "󰐥", cmd: "power", arg: "", submode: "", kw: "apagar reiniciar suspender shutdown reboot suspend logout salir" },
    { id: "lock", glyph: "󰌾", cmd: "lock", arg: "", submode: "", kw: "bloquear lock sesion session" },
    { id: "overview", glyph: "󰕮", cmd: "overview", arg: "", submode: "", kw: "ventanas windows workspaces escritorios vista general mission alttab" },
    { id: "agenda", glyph: "󰃭", cmd: "agenda", arg: "", submode: "", kw: "calendar calendario tareas todo agenda" },
    { id: "audio", glyph: "󰕾", cmd: "audio", arg: "", submode: "", kw: "sonido volumen volume sound speakers altavoces mic" },
    { id: "network", glyph: "󰖩", cmd: "network", arg: "", submode: "", kw: "wifi internet red wlan ethernet" },
    { id: "bluetooth", glyph: "󰂯", cmd: "bluetooth", arg: "", submode: "", kw: "bt auriculares headphones dispositivos devices" },
    { id: "notify", glyph: "󰂜", cmd: "notify", arg: "", submode: "", kw: "notificaciones notifications avisos dnd" },
    { id: "monitor", glyph: "󰍹", cmd: "monitor", arg: "", submode: "", kw: "pantalla display screen salida output" },
    { id: "lang", glyph: "󰗊", cmd: "lang", arg: "", submode: "", kw: "idioma language locale traduccion translate" },
    { id: "tmux", glyph: "󰆍", cmd: "", arg: "", submode: "!", kw: "terminal sesion session multiplexer" }
  ]

  function key(id, suffix) {
    return "lc" + id.charAt(0).toUpperCase() + id.slice(1) + (suffix || "")
  }


  readonly property var items: all.map(c => {
    const name = Translations.t(root.key(c.id))
    const sub = Translations.t(root.key(c.id, "Sub"))
    return {
      id: "cmd:" + c.id,
      kind: "command",
      glyph: c.glyph,
      name: name,
      sub: sub,
      cmd: c.cmd,
      arg: c.arg,
      submode: c.submode,
      hay: [
        { text: name.toLowerCase(), w: 1.0 },
        { text: c.id.toLowerCase(),  w: 0.8 },
        { text: c.kw,               w: 0.5 },
        { text: sub.toLowerCase(),  w: 0.25 }
      ]
    }
  })


  readonly property var themeItems: [
    { mode: "dark",     glyph: "󰖔", key: "lcThemeDark" },
    { mode: "light",    glyph: "󰖙", key: "lcThemeLight" },
    { mode: "colorful", glyph: "󰏘", key: "lcThemeColorful" }
  ].map(m => {
    const name = Translations.t(m.key)
    const current = Theme.themeMode === m.mode
    return {
      id: "theme:" + m.mode,
      kind: "command",
      glyph: m.glyph,
      name: name,
      sub: current ? Translations.t("lcThemeCurrent") : "",
      cmd: "theme",
      arg: m.mode,
      submode: "",
      hay: [
        { text: name.toLowerCase(), w: 1.0 },
        { text: m.mode,             w: 0.8 }
      ]
    }
  })
}
