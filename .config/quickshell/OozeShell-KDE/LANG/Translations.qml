// OozeShell — Traducciones centralizadas
//
// Un solo lugar con todos los textos del shell en inglés, español
// y bahasa indonesia. Cualquier componente puede importar esta
// carpeta y usar:
//
//   import "../LANG"
//   ...
//   text: Translations.t("keybindingsTitle")
//
// Cambiar Translations.current re-evalúa automáticamente cualquier
// binding que haya llamado a t() o leído sectionsData, porque QML
// registra esas lecturas de propiedad como dependencias aunque
// pasen por una función.
//
// Se cambia el idioma activo desde LanguagePicker.qml (vía
// shell.qml, que persiste la elección en disco). No hace falta
// tocar este archivo para eso — solo para agregar textos nuevos.
// en otro momento subdivire por carpetas esto, para agregar mas idiomas pero 
//por ahora se queda asi

pragma Singleton
import QtQml

QtObject {
  id: root

  // Código de idioma activo: "en" | "es" | "id"
  property string current: "en"

  readonly property var availableLanguages: [
    { code: "en", name: "English" },
    { code: "es", name: "Español" },
    { code: "id", name: "Bahasa Indonesia" },
  ]

  // ─── Textos sueltos de la UI (headers, hints, etc.) ───────────
  readonly property var strings: ({
    en: {
      keybindingsTitle:  "Keybindings",
      tagline:           "OozeShell · Hyprland",
      footerHint:        "Esc · click outside to close",
      chooseLanguage:    "Choose your language",
      monitorPickerTitle:"Choose Main Screen",
      mprisTitle:        "Now Playing",
      mprisNoPlaying:    "Nothing playing",
      wallsApplyHint:    "↵ apply",
      tabKeybinds:       "Keybinds",
      tabVim:            "Vim",
    },
    es: {
      keybindingsTitle:  "Atajos de teclado",
      tagline:           "OozeShell · Hyprland",
      footerHint:        "Esc · clic afuera para cerrar",
      chooseLanguage:    "Elige tu idioma",
      monitorPickerTitle:"Elegir pantalla principal",
      mprisTitle:        "Reproduciendo",
      mprisNoPlaying:    "Sin reproducción",
      wallsApplyHint:    "↵ aplicar",
      tabKeybinds:       "Atajos",
      tabVim:            "Vim",
    },
    id: {
      keybindingsTitle:  "Pintasan Keyboard",
      tagline:           "OozeShell · Hyprland",
      footerHint:        "Esc · klik di luar untuk menutup",
      chooseLanguage:    "Pilih bahasamu",
      monitorPickerTitle:"Pilih Layar Utama",
      mprisTitle:        "Sedang Diputar",
      mprisNoPlaying:    "Tidak ada yang diputar",
      wallsApplyHint:    "↵ terapkan",
      tabKeybinds:       "Pintasan",
      tabVim:            "Vim",
    },
  })

  // Busca "key" en el idioma activo; si falta, cae a inglés;
  // si tampoco existe ahí, devuelve la key tal cual (nunca revienta).
  function t(key) {
    const table = root.strings[root.current] || root.strings.en
    if (table[key] !== undefined) return table[key]
    if (root.strings.en[key] !== undefined) return root.strings.en[key]
    return key
  }

  // ─── Contenido del panel de Keybinds, por idioma ──────────────
  // "keys" (las teclas en sí, ej. "SUPER", "Mouse LMB") NO se
  // traducen a propósito: son nombres de tecla, no prosa.
  readonly property var sectionsData: ({
    en: [
      {
        title: "Applications", icon: "󰀻",
        binds: [
          { keys: ["SUPER", "Q"], desc: "Open terminal" },
          { keys: ["SUPER", "E"], desc: "Open file manager" },
          { keys: ["SUPER", "R"], desc: "Open application launcher" },
          { keys: ["SUPER", "U"], desc: "Search Apps on Nix-Search" },
        ]
      },
      {
        title: "Windows", icon: "󱂬",
        binds: [
          { keys: ["SUPER", "C"], desc: "Close active window" },
          { keys: ["SUPER", "V"], desc: "Toggle floating window" },
          { keys: ["SUPER", "P"], desc: "Toggle pseudo mode" },
          { keys: ["SUPER", "J"], desc: "Toggle layout split" },
          { keys: ["SUPER", "Tab"], desc: "Cycle to next window" },
          { keys: ["SUPER SHIFT", "Tab"], desc: "Cycle to previous window" },
          { keys: ["SUPER", "Mouse LMB"], desc: "Move window with mouse" },
          { keys: ["SUPER", "Mouse RMB"], desc: "Resize window with mouse" },
        ]
      },
      {
        title: "Focus", icon: "󰁌",
        binds: [
          { keys: ["SUPER", "←"], desc: "Move focus left" },
          { keys: ["SUPER", "→"], desc: "Move focus right" },
          { keys: ["SUPER", "↑"], desc: "Move focus up" },
          { keys: ["SUPER", "↓"], desc: "Move focus down" },
        ]
      },
      {
        title: "Move Windows", icon: "󰆾",
        binds: [
          { keys: ["SUPER SHIFT", "←"], desc: "Move window left" },
          { keys: ["SUPER SHIFT", "→"], desc: "Move window right" },
          { keys: ["SUPER SHIFT", "↑"], desc: "Move window up" },
          { keys: ["SUPER SHIFT", "↓"], desc: "Move window down" },
        ]
      },
      {
        title: "Layout", icon: "󰕰",
        binds: [
          { keys: ["SUPER", ","], desc: "Move to previous column" },
          { keys: ["SUPER", "."], desc: "Move to next column" },
          { keys: ["SUPER", "["], desc: "Decrease column width" },
          { keys: ["SUPER", "]"], desc: "Increase column width" },
          { keys: ["SUPER", "K"], desc: "Cycle layout" },
        ]
      },
      {
        title: "Workspaces", icon: "󰊓",
        binds: [
          { keys: ["SUPER", "1–9"], desc: "Switch to workspace 1–9" },
          { keys: ["SUPER", "0"], desc: "Switch to workspace 10" },
          { keys: ["SUPER SHIFT", "1–9"], desc: "Move window to workspace 1–9" },
          { keys: ["SUPER SHIFT", "0"], desc: "Move window to workspace 10" },
          { keys: ["SUPER", "Scroll ↑↓"], desc: "Switch between workspaces" },
        ]
      },
      {
        title: "Special Workspace", icon: "󰘔",
        binds: [
          { keys: ["SUPER", "S"], desc: "Show or hide special workspace" },
          { keys: ["SUPER SHIFT", "S"], desc: "Move window to special workspace" },
          { keys: ["SUPER", "X"], desc: "Minimize or restore window" },
        ]
      },
      {
        title: "OozeShell", icon: "󰆍",
        binds: [
          { keys: ["SUPER", "W"], desc: "Open wallpaper selector" },
          { keys: ["SUPER", "L"], desc: "Select Shell monitor" },
          { keys: ["SUPER", "I"], desc: "Show keybind cheatsheet" },
          { keys: ["SUPER", "N"], desc: "Open notification center" },
          { keys: ["SUPER SHIFT", "P"], desc: "Restart OozeShell" },
          { keys: ["SUPER SHIFT", "M"], desc: "Open power menu" },
          { keys: ["SUPER", "G"], desc: "Open language picker" },
        ]
      },
      {
        title: "Screenshots", icon: "󰄀",
        binds: [
          { keys: ["Print"], desc: "Capture full screen and copy" },
          { keys: ["SUPER", "Print"], desc: "Select area and copy" },
          { keys: ["SUPER SHIFT", "Print"], desc: "Select area, save, and copy" },
        ]
      },
    ],

    es: [
      {
        title: "Aplicaciones", icon: "󰀻",
        binds: [
          { keys: ["SUPER", "Q"], desc: "Abrir terminal" },
          { keys: ["SUPER", "E"], desc: "Abrir gestor de archivos" },
          { keys: ["SUPER", "R"], desc: "Abrir lanzador de aplicaciones" },
          { keys: ["SUPER", "U"], desc: "Buscar apps en Nix-Search" },
        ]
      },
      {
        title: "Ventanas", icon: "󱂬",
        binds: [
          { keys: ["SUPER", "C"], desc: "Cerrar ventana activa" },
          { keys: ["SUPER", "V"], desc: "Alternar ventana flotante" },
          { keys: ["SUPER", "P"], desc: "Alternar modo pseudo" },
          { keys: ["SUPER", "J"], desc: "Alternar división de diseño" },
          { keys: ["SUPER", "Tab"], desc: "Ciclar a la siguiente ventana" },
          { keys: ["SUPER SHIFT", "Tab"], desc: "Ciclar a la ventana anterior" },
          { keys: ["SUPER", "Mouse LMB"], desc: "Mover ventana con el mouse" },
          { keys: ["SUPER", "Mouse RMB"], desc: "Redimensionar ventana con el mouse" },
        ]
      },
      {
        title: "Foco", icon: "󰁌",
        binds: [
          { keys: ["SUPER", "←"], desc: "Mover foco a la izquierda" },
          { keys: ["SUPER", "→"], desc: "Mover foco a la derecha" },
          { keys: ["SUPER", "↑"], desc: "Mover foco hacia arriba" },
          { keys: ["SUPER", "↓"], desc: "Mover foco hacia abajo" },
        ]
      },
      {
        title: "Mover ventanas", icon: "󰆾",
        binds: [
          { keys: ["SUPER SHIFT", "←"], desc: "Mover ventana a la izquierda" },
          { keys: ["SUPER SHIFT", "→"], desc: "Mover ventana a la derecha" },
          { keys: ["SUPER SHIFT", "↑"], desc: "Mover ventana hacia arriba" },
          { keys: ["SUPER SHIFT", "↓"], desc: "Mover ventana hacia abajo" },
        ]
      },
      {
        title: "Diseño", icon: "󰕰",
        binds: [
          { keys: ["SUPER", ","], desc: "Ir a la columna anterior" },
          { keys: ["SUPER", "."], desc: "Ir a la columna siguiente" },
          { keys: ["SUPER", "["], desc: "Reducir ancho de columna" },
          { keys: ["SUPER", "]"], desc: "Aumentar ancho de columna" },
          { keys: ["SUPER", "K"], desc: "Ciclar diseño" },
        ]
      },
      {
        title: "Escritorios", icon: "󰊓",
        binds: [
          { keys: ["SUPER", "1–9"], desc: "Cambiar al escritorio 1–9" },
          { keys: ["SUPER", "0"], desc: "Cambiar al escritorio 10" },
          { keys: ["SUPER SHIFT", "1–9"], desc: "Mover ventana al escritorio 1–9" },
          { keys: ["SUPER SHIFT", "0"], desc: "Mover ventana al escritorio 10" },
          { keys: ["SUPER", "Scroll ↑↓"], desc: "Cambiar entre escritorios" },
        ]
      },
      {
        title: "Escritorio especial", icon: "󰘔",
        binds: [
          { keys: ["SUPER", "S"], desc: "Mostrar u ocultar escritorio especial" },
          { keys: ["SUPER SHIFT", "S"], desc: "Mover ventana al escritorio especial" },
          { keys: ["SUPER", "X"], desc: "Minimizar o restaurar ventana" },
        ]
      },
      {
        title: "OozeShell", icon: "󰆍",
        binds: [
          { keys: ["SUPER", "W"], desc: "Abrir selector de fondos de pantalla" },
          { keys: ["SUPER", "L"], desc: "Seleccionar monitor del shell" },
          { keys: ["SUPER", "I"], desc: "Mostrar hoja de atajos" },
          { keys: ["SUPER", "N"], desc: "Abrir centro de notificaciones" },
          { keys: ["SUPER SHIFT", "P"], desc: "Reiniciar OozeShell" },
          { keys: ["SUPER SHIFT", "M"], desc: "Abrir menú de encendido" },
          { keys: ["SUPER", "G"], desc: "Elegir idioma" },
        ]
      },
      {
        title: "Capturas de pantalla", icon: "󰄀",
        binds: [
          { keys: ["Print"], desc: "Capturar pantalla completa y copiar" },
          { keys: ["SUPER", "Print"], desc: "Seleccionar área y copiar" },
          { keys: ["SUPER SHIFT", "Print"], desc: "Seleccionar área, guardar y copiar" },
        ]
      },
    ],

    id: [
      {
        title: "Aplikasi", icon: "󰀻",
        binds: [
          { keys: ["SUPER", "Q"], desc: "Buka terminal" },
          { keys: ["SUPER", "E"], desc: "Buka pengelola berkas" },
          { keys: ["SUPER", "R"], desc: "Buka peluncur aplikasi" },
          { keys: ["SUPER", "U"], desc: "Cari aplikasi di Nix-Search" },
        ]
      },
      {
        title: "Jendela", icon: "󱂬",
        binds: [
          { keys: ["SUPER", "C"], desc: "Tutup jendela aktif" },
          { keys: ["SUPER", "V"], desc: "Alihkan jendela mengambang" },
          { keys: ["SUPER", "P"], desc: "Alihkan mode pseudo" },
          { keys: ["SUPER", "J"], desc: "Alihkan pembagian tata letak" },
          { keys: ["SUPER", "Tab"], desc: "Beralih ke jendela berikutnya" },
          { keys: ["SUPER SHIFT", "Tab"], desc: "Beralih ke jendela sebelumnya" },
          { keys: ["SUPER", "Mouse LMB"], desc: "Pindahkan jendela dengan mouse" },
          { keys: ["SUPER", "Mouse RMB"], desc: "Ubah ukuran jendela dengan mouse" },
        ]
      },
      {
        title: "Fokus", icon: "󰁌",
        binds: [
          { keys: ["SUPER", "←"], desc: "Pindahkan fokus ke kiri" },
          { keys: ["SUPER", "→"], desc: "Pindahkan fokus ke kanan" },
          { keys: ["SUPER", "↑"], desc: "Pindahkan fokus ke atas" },
          { keys: ["SUPER", "↓"], desc: "Pindahkan fokus ke bawah" },
        ]
      },
      {
        title: "Pindahkan Jendela", icon: "󰆾",
        binds: [
          { keys: ["SUPER SHIFT", "←"], desc: "Pindahkan jendela ke kiri" },
          { keys: ["SUPER SHIFT", "→"], desc: "Pindahkan jendela ke kanan" },
          { keys: ["SUPER SHIFT", "↑"], desc: "Pindahkan jendela ke atas" },
          { keys: ["SUPER SHIFT", "↓"], desc: "Pindahkan jendela ke bawah" },
        ]
      },
      {
        title: "Tata Letak", icon: "󰕰",
        binds: [
          { keys: ["SUPER", ","], desc: "Pindah ke kolom sebelumnya" },
          { keys: ["SUPER", "."], desc: "Pindah ke kolom berikutnya" },
          { keys: ["SUPER", "["], desc: "Kurangi lebar kolom" },
          { keys: ["SUPER", "]"], desc: "Tambah lebar kolom" },
          { keys: ["SUPER", "K"], desc: "Ganti tata letak" },
        ]
      },
      {
        title: "Ruang Kerja", icon: "󰊓",
        binds: [
          { keys: ["SUPER", "1–9"], desc: "Pindah ke ruang kerja 1–9" },
          { keys: ["SUPER", "0"], desc: "Pindah ke ruang kerja 10" },
          { keys: ["SUPER SHIFT", "1–9"], desc: "Pindahkan jendela ke ruang kerja 1–9" },
          { keys: ["SUPER SHIFT", "0"], desc: "Pindahkan jendela ke ruang kerja 10" },
          { keys: ["SUPER", "Scroll ↑↓"], desc: "Beralih antar ruang kerja" },
        ]
      },
      {
        title: "Ruang Kerja Khusus", icon: "󰘔",
        binds: [
          { keys: ["SUPER", "S"], desc: "Tampilkan atau sembunyikan ruang kerja khusus" },
          { keys: ["SUPER SHIFT", "S"], desc: "Pindahkan jendela ke ruang kerja khusus" },
          { keys: ["SUPER", "X"], desc: "Minimalkan atau pulihkan jendela" },
        ]
      },
      {
        title: "OozeShell", icon: "󰆍",
        binds: [
          { keys: ["SUPER", "W"], desc: "Buka pemilih wallpaper" },
          { keys: ["SUPER", "L"], desc: "Pilih monitor shell" },
          { keys: ["SUPER", "I"], desc: "Tampilkan daftar pintasan" },
          { keys: ["SUPER", "N"], desc: "Buka pusat notifikasi" },
          { keys: ["SUPER SHIFT", "P"], desc: "Mulai ulang OozeShell" },
          { keys: ["SUPER SHIFT", "M"], desc: "Buka menu daya" },
          { keys: ["SUPER", "G"], desc: "Buka pemilih bahasa" },
        ]
      },
      {
        title: "Tangkapan Layar", icon: "󰄀",
        binds: [
          { keys: ["Print"], desc: "Tangkap layar penuh dan salin" },
          { keys: ["SUPER", "Print"], desc: "Pilih area dan salin" },
          { keys: ["SUPER SHIFT", "Print"], desc: "Pilih area, simpan, dan salin" },
        ]
      },
    ],
  })

  // Secciones del idioma activo, con fallback a inglés.
  function sections() {
    return root.sectionsData[root.current] || root.sectionsData.en
  }

  // ─── Contenido del panel de Vim, por idioma ───────────────────
  // Igual que sectionsData: las "keys" (comandos de Vim en sí) no
  // se traducen, solo las descripciones y los títulos de categoría.
  readonly property var vimSectionsData: ({
    en: [
      {
        title: "Modes", icon: "󰀻",
        binds: [
          { keys: ["i"], desc: "Insert before cursor" },
          { keys: ["a"], desc: "Insert after cursor" },
          { keys: ["I"], desc: "Insert at start of line" },
          { keys: ["A"], desc: "Insert at end of line" },
          { keys: ["o"], desc: "New line below" },
          { keys: ["O"], desc: "New line above" },
          { keys: ["Esc"], desc: "Return to Normal mode" },
          { keys: ["v"], desc: "Visual mode" },
          { keys: ["V"], desc: "Visual Line mode" },
          { keys: ["Ctrl+v"], desc: "Visual Block mode" },
          { keys: ["R"], desc: "Replace mode" },
        ]
      },
      {
        title: "Movement", icon: "󱂬",
        binds: [
          { keys: ["h", "j", "k", "l"], desc: "Move left / down / up / right" },
          { keys: ["w"], desc: "Next word" },
          { keys: ["b"], desc: "Previous word" },
          { keys: ["e"], desc: "End of word" },
          { keys: ["0"], desc: "Start of line" },
          { keys: ["^"], desc: "First non-blank character" },
          { keys: ["$"], desc: "End of line" },
          { keys: ["gg"], desc: "Start of file" },
          { keys: ["G"], desc: "End of file" },
          { keys: ["H"], desc: "Top of screen" },
          { keys: ["M"], desc: "Middle of screen" },
          { keys: ["L"], desc: "Bottom of screen" },
          { keys: ["Ctrl+d"], desc: "Half page down" },
          { keys: ["Ctrl+u"], desc: "Half page up" },
          { keys: ["Ctrl+f"], desc: "Full page down" },
          { keys: ["Ctrl+b"], desc: "Full page up" },
        ]
      },
      {
        title: "Editing", icon: "󰁌",
        binds: [
          { keys: ["x"], desc: "Delete character" },
          { keys: ["X"], desc: "Delete previous character" },
          { keys: ["dd"], desc: "Delete line" },
          { keys: ["dw"], desc: "Delete word" },
          { keys: ["D"], desc: "Delete to end of line" },
          { keys: ["cw"], desc: "Change word" },
          { keys: ["ciw"], desc: "Change entire word" },
          { keys: ["C"], desc: "Change to end of line" },
          { keys: ["r"], desc: "Replace character" },
          { keys: ["s"], desc: "Substitute character" },
          { keys: ["S"], desc: "Substitute entire line" },
          { keys: ["u"], desc: "Undo" },
          { keys: ["Ctrl+r"], desc: "Redo" },
          { keys: ["."], desc: "Repeat last change" },
        ]
      },
      {
        title: "Search", icon: "󰆾",
        binds: [
          { keys: ["/text"], desc: "Search forward" },
          { keys: ["?text"], desc: "Search backward" },
          { keys: ["n"], desc: "Next match" },
          { keys: ["N"], desc: "Previous match" },
          { keys: ["*"], desc: "Search word under cursor" },
          { keys: ["#"], desc: "Search word backward" },
          { keys: [":noh"], desc: "Clear search highlight" },
        ]
      },
      {
        title: "Save / Quit", icon: "󰕰",
        binds: [
          { keys: [":w"], desc: "Save" },
          { keys: [":q"], desc: "Quit" },
          { keys: [":wq"], desc: "Save and quit" },
          { keys: [":x"], desc: "Save and quit" },
          { keys: [":q!"], desc: "Quit without saving" },
          { keys: [":w!"], desc: "Force save" },
          { keys: ["ZZ"], desc: "Save and quit" },
          { keys: ["ZQ"], desc: "Quit without saving" },
        ]
      },
      {
        title: "Windows", icon: "󰊓",
        binds: [
          { keys: [":split"], desc: "Horizontal split" },
          { keys: [":vsplit"], desc: "Vertical split" },
          { keys: ["Ctrl+w", "h"], desc: "Move left" },
          { keys: ["Ctrl+w", "j"], desc: "Move down" },
          { keys: ["Ctrl+w", "k"], desc: "Move up" },
          { keys: ["Ctrl+w", "l"], desc: "Move right" },
          { keys: ["Ctrl+w", "q"], desc: "Close window" },
          { keys: ["Ctrl+w", "o"], desc: "Keep current window" },
          { keys: ["Ctrl+w", "="], desc: "Equal window sizes" },
        ]
      },
      {
        title: "Visual Mode", icon: "󰘔",
        binds: [
          { keys: ["v"], desc: "Character selection" },
          { keys: ["V"], desc: "Line selection" },
          { keys: ["Ctrl+v"], desc: "Block selection" },
          { keys: ["y"], desc: "Yank selection" },
          { keys: ["d"], desc: "Delete selection" },
          { keys: ["c"], desc: "Change selection" },
          { keys: [">"], desc: "Indent selection" },
          { keys: ["<"], desc: "Unindent selection" },
          { keys: ["~"], desc: "Toggle case" },
          { keys: ["u"], desc: "Lowercase" },
          { keys: ["U"], desc: "Uppercase" },
        ]
      },
      {
        title: "Indentation", icon: "󰆍",
        binds: [
          { keys: [">>"], desc: "Indent line" },
          { keys: ["<<"], desc: "Unindent line" },
          { keys: ["="], desc: "Auto-indent" },
          { keys: ["=="], desc: "Auto-indent line" },
          { keys: ["gg=G"], desc: "Format entire file" },
          { keys: ["=%"], desc: "Format block" },
        ]
      },
      {
        title: "Text Objects", icon: "󰄀",
        binds: [
          { keys: ["iw"], desc: "Inner word" },
          { keys: ["aw"], desc: "A word" },
          { keys: ["i\""], desc: "Inside quotes" },
          { keys: ["a\""], desc: "Around quotes" },
          { keys: ["i'"], desc: "Inside single quotes" },
          { keys: ["a'"], desc: "Around single quotes" },
          { keys: ["i("], desc: "Inside parentheses" },
          { keys: ["a("], desc: "Around parentheses" },
          { keys: ["i{"], desc: "Inside braces" },
          { keys: ["a{"], desc: "Around braces" },
          { keys: ["it"], desc: "Inside HTML/XML tag" },
        ]
      },
      {
        title: "Counts", icon: "󰀻",
        binds: [
          { keys: ["5j"], desc: "Move down 5 lines" },
          { keys: ["3w"], desc: "Move 3 words forward" },
          { keys: ["2dd"], desc: "Delete 2 lines" },
          { keys: ["4yy"], desc: "Yank 4 lines" },
          { keys: ["3p"], desc: "Paste 3 times" },
          { keys: ["10G"], desc: "Go to line 10" },
          { keys: ["5dw"], desc: "Delete 5 words" },
          { keys: ["2>>"], desc: "Indent 2 lines" },
        ]
      },
      {
        title: "Registers", icon: "󱂬",
        binds: [
          { keys: ["\"ayy"], desc: "Yank line into register a" },
          { keys: ["\"ap"], desc: "Paste from register a" },
          { keys: ["\"+y"], desc: "Yank to system clipboard" },
          { keys: ["\"+p"], desc: "Paste from system clipboard" },
          { keys: ["\"*y"], desc: "Yank to primary selection" },
          { keys: ["\"*p"], desc: "Paste primary selection" },
          { keys: [":reg"], desc: "Show registers" },
        ]
      },
      {
        title: "Macros", icon: "󰁌",
        binds: [
          { keys: ["qa"], desc: "Record macro into register a" },
          { keys: ["q"], desc: "Stop recording" },
          { keys: ["@a"], desc: "Execute macro a" },
          { keys: ["@@"], desc: "Repeat last macro" },
          { keys: ["5@a"], desc: "Execute macro a 5 times" },
        ]
      },
      {
        title: "Marks", icon: "󰆾",
        binds: [
          { keys: ["ma"], desc: "Set mark a" },
          { keys: ["'a"], desc: "Jump to line of mark a" },
          { keys: ["`a"], desc: "Jump to exact position of mark a" },
          { keys: [":marks"], desc: "Show marks" },
          { keys: ["''"], desc: "Jump to previous position" },
          { keys: ["`."], desc: "Jump to last change" },
        ]
      },
      {
        title: "Folds", icon: "󰕰",
        binds: [
          { keys: ["za"], desc: "Toggle fold" },
          { keys: ["zo"], desc: "Open fold" },
          { keys: ["zc"], desc: "Close fold" },
          { keys: ["zR"], desc: "Open all folds" },
          { keys: ["zM"], desc: "Close all folds" },
          { keys: ["zj"], desc: "Move to next fold" },
          { keys: ["zk"], desc: "Move to previous fold" },
        ]
      },
      {
        title: "Commands", icon: "󰊓",
        binds: [
          { keys: [":e file"], desc: "Open file" },
          { keys: [":enew"], desc: "New empty buffer" },
          { keys: [":bn"], desc: "Next buffer" },
          { keys: [":bp"], desc: "Previous buffer" },
          { keys: [":bd"], desc: "Delete buffer" },
          { keys: [":set nu"], desc: "Show line numbers" },
          { keys: [":set nonu"], desc: "Hide line numbers" },
          { keys: [":help cmd"], desc: "Open Vim help" },
          { keys: [":%s/a/b/g"], desc: "Replace all" },
          { keys: [":sort"], desc: "Sort selected lines" },
        ]
      },
    ],

    es: [
      {
        title: "Modos", icon: "󰀻",
        binds: [
          { keys: ["i"], desc: "Insertar antes del cursor" },
          { keys: ["a"], desc: "Insertar después del cursor" },
          { keys: ["I"], desc: "Insertar al inicio de la línea" },
          { keys: ["A"], desc: "Insertar al final de la línea" },
          { keys: ["o"], desc: "Nueva línea abajo" },
          { keys: ["O"], desc: "Nueva línea arriba" },
          { keys: ["Esc"], desc: "Volver a modo Normal" },
          { keys: ["v"], desc: "Modo Visual" },
          { keys: ["V"], desc: "Modo Visual de línea" },
          { keys: ["Ctrl+v"], desc: "Modo Visual de bloque" },
          { keys: ["R"], desc: "Modo Reemplazo" },
        ]
      },
      {
        title: "Movimiento", icon: "󱂬",
        binds: [
          { keys: ["h", "j", "k", "l"], desc: "Mover izquierda / abajo / arriba / derecha" },
          { keys: ["w"], desc: "Palabra siguiente" },
          { keys: ["b"], desc: "Palabra anterior" },
          { keys: ["e"], desc: "Fin de palabra" },
          { keys: ["0"], desc: "Inicio de línea" },
          { keys: ["^"], desc: "Primer carácter no vacío" },
          { keys: ["$"], desc: "Fin de línea" },
          { keys: ["gg"], desc: "Inicio del archivo" },
          { keys: ["G"], desc: "Fin del archivo" },
          { keys: ["H"], desc: "Arriba de la pantalla" },
          { keys: ["M"], desc: "Centro de la pantalla" },
          { keys: ["L"], desc: "Abajo de la pantalla" },
          { keys: ["Ctrl+d"], desc: "Media página abajo" },
          { keys: ["Ctrl+u"], desc: "Media página arriba" },
          { keys: ["Ctrl+f"], desc: "Página completa abajo" },
          { keys: ["Ctrl+b"], desc: "Página completa arriba" },
        ]
      },
      {
        title: "Edición", icon: "󰁌",
        binds: [
          { keys: ["x"], desc: "Borrar carácter" },
          { keys: ["X"], desc: "Borrar carácter anterior" },
          { keys: ["dd"], desc: "Borrar línea" },
          { keys: ["dw"], desc: "Borrar palabra" },
          { keys: ["D"], desc: "Borrar hasta el final de línea" },
          { keys: ["cw"], desc: "Cambiar palabra" },
          { keys: ["ciw"], desc: "Cambiar palabra completa" },
          { keys: ["C"], desc: "Cambiar hasta el final de línea" },
          { keys: ["r"], desc: "Reemplazar carácter" },
          { keys: ["s"], desc: "Sustituir carácter" },
          { keys: ["S"], desc: "Sustituir línea completa" },
          { keys: ["u"], desc: "Deshacer" },
          { keys: ["Ctrl+r"], desc: "Rehacer" },
          { keys: ["."], desc: "Repetir último cambio" },
        ]
      },
      {
        title: "Búsqueda", icon: "󰆾",
        binds: [
          { keys: ["/texto"], desc: "Buscar hacia adelante" },
          { keys: ["?texto"], desc: "Buscar hacia atrás" },
          { keys: ["n"], desc: "Siguiente coincidencia" },
          { keys: ["N"], desc: "Coincidencia anterior" },
          { keys: ["*"], desc: "Buscar palabra bajo el cursor" },
          { keys: ["#"], desc: "Buscar palabra hacia atrás" },
          { keys: [":noh"], desc: "Quitar resaltado de búsqueda" },
        ]
      },
      {
        title: "Guardar / Salir", icon: "󰕰",
        binds: [
          { keys: [":w"], desc: "Guardar" },
          { keys: [":q"], desc: "Salir" },
          { keys: [":wq"], desc: "Guardar y salir" },
          { keys: [":x"], desc: "Guardar y salir" },
          { keys: [":q!"], desc: "Salir sin guardar" },
          { keys: [":w!"], desc: "Forzar guardado" },
          { keys: ["ZZ"], desc: "Guardar y salir" },
          { keys: ["ZQ"], desc: "Salir sin guardar" },
        ]
      },
      {
        title: "Ventanas", icon: "󰊓",
        binds: [
          { keys: [":split"], desc: "División horizontal" },
          { keys: [":vsplit"], desc: "División vertical" },
          { keys: ["Ctrl+w", "h"], desc: "Mover a la izquierda" },
          { keys: ["Ctrl+w", "j"], desc: "Mover abajo" },
          { keys: ["Ctrl+w", "k"], desc: "Mover arriba" },
          { keys: ["Ctrl+w", "l"], desc: "Mover a la derecha" },
          { keys: ["Ctrl+w", "q"], desc: "Cerrar ventana" },
          { keys: ["Ctrl+w", "o"], desc: "Mantener solo esta ventana" },
          { keys: ["Ctrl+w", "="], desc: "Igualar tamaño de ventanas" },
        ]
      },
      {
        title: "Modo Visual", icon: "󰘔",
        binds: [
          { keys: ["v"], desc: "Selección de caracteres" },
          { keys: ["V"], desc: "Selección de línea" },
          { keys: ["Ctrl+v"], desc: "Selección de bloque" },
          { keys: ["y"], desc: "Copiar selección" },
          { keys: ["d"], desc: "Borrar selección" },
          { keys: ["c"], desc: "Cambiar selección" },
          { keys: [">"], desc: "Aumentar sangría" },
          { keys: ["<"], desc: "Reducir sangría" },
          { keys: ["~"], desc: "Alternar mayúsculas/minúsculas" },
          { keys: ["u"], desc: "Convertir a minúsculas" },
          { keys: ["U"], desc: "Convertir a mayúsculas" },
        ]
      },
      {
        title: "Sangría", icon: "󰆍",
        binds: [
          { keys: [">>"], desc: "Aumentar sangría de línea" },
          { keys: ["<<"], desc: "Reducir sangría de línea" },
          { keys: ["="], desc: "Auto-indentar" },
          { keys: ["=="], desc: "Auto-indentar línea" },
          { keys: ["gg=G"], desc: "Formatear archivo completo" },
          { keys: ["=%"], desc: "Formatear bloque" },
        ]
      },
      {
        title: "Objetos de texto", icon: "󰄀",
        binds: [
          { keys: ["iw"], desc: "Palabra interior" },
          { keys: ["aw"], desc: "Palabra completa" },
          { keys: ["i\""], desc: "Dentro de comillas" },
          { keys: ["a\""], desc: "Alrededor de comillas" },
          { keys: ["i'"], desc: "Dentro de comillas simples" },
          { keys: ["a'"], desc: "Alrededor de comillas simples" },
          { keys: ["i("], desc: "Dentro de paréntesis" },
          { keys: ["a("], desc: "Alrededor de paréntesis" },
          { keys: ["i{"], desc: "Dentro de llaves" },
          { keys: ["a{"], desc: "Alrededor de llaves" },
          { keys: ["it"], desc: "Dentro de etiqueta HTML/XML" },
        ]
      },
      {
        title: "Contadores", icon: "󰀻",
        binds: [
          { keys: ["5j"], desc: "Bajar 5 líneas" },
          { keys: ["3w"], desc: "Avanzar 3 palabras" },
          { keys: ["2dd"], desc: "Borrar 2 líneas" },
          { keys: ["4yy"], desc: "Copiar 4 líneas" },
          { keys: ["3p"], desc: "Pegar 3 veces" },
          { keys: ["10G"], desc: "Ir a la línea 10" },
          { keys: ["5dw"], desc: "Borrar 5 palabras" },
          { keys: ["2>>"], desc: "Sangrar 2 líneas" },
        ]
      },
      {
        title: "Registros", icon: "󱂬",
        binds: [
          { keys: ["\"ayy"], desc: "Copiar línea al registro a" },
          { keys: ["\"ap"], desc: "Pegar desde el registro a" },
          { keys: ["\"+y"], desc: "Copiar al portapapeles del sistema" },
          { keys: ["\"+p"], desc: "Pegar desde el portapapeles del sistema" },
          { keys: ["\"*y"], desc: "Copiar a la selección primaria" },
          { keys: ["\"*p"], desc: "Pegar la selección primaria" },
          { keys: [":reg"], desc: "Mostrar registros" },
        ]
      },
      {
        title: "Macros", icon: "󰁌",
        binds: [
          { keys: ["qa"], desc: "Grabar macro en el registro a" },
          { keys: ["q"], desc: "Detener grabación" },
          { keys: ["@a"], desc: "Ejecutar macro a" },
          { keys: ["@@"], desc: "Repetir última macro" },
          { keys: ["5@a"], desc: "Ejecutar macro a 5 veces" },
        ]
      },
      {
        title: "Marcas", icon: "󰆾",
        binds: [
          { keys: ["ma"], desc: "Poner marca a" },
          { keys: ["'a"], desc: "Saltar a la línea de la marca a" },
          { keys: ["`a"], desc: "Saltar a la posición exacta de la marca a" },
          { keys: [":marks"], desc: "Mostrar marcas" },
          { keys: ["''"], desc: "Saltar a la posición anterior" },
          { keys: ["`."], desc: "Saltar al último cambio" },
        ]
      },
      {
        title: "Pliegues", icon: "󰕰",
        binds: [
          { keys: ["za"], desc: "Alternar pliegue" },
          { keys: ["zo"], desc: "Abrir pliegue" },
          { keys: ["zc"], desc: "Cerrar pliegue" },
          { keys: ["zR"], desc: "Abrir todos los pliegues" },
          { keys: ["zM"], desc: "Cerrar todos los pliegues" },
          { keys: ["zj"], desc: "Ir al siguiente pliegue" },
          { keys: ["zk"], desc: "Ir al pliegue anterior" },
        ]
      },
      {
        title: "Comandos", icon: "󰊓",
        binds: [
          { keys: [":e archivo"], desc: "Abrir archivo" },
          { keys: [":enew"], desc: "Nuevo búfer vacío" },
          { keys: [":bn"], desc: "Búfer siguiente" },
          { keys: [":bp"], desc: "Búfer anterior" },
          { keys: [":bd"], desc: "Eliminar búfer" },
          { keys: [":set nu"], desc: "Mostrar números de línea" },
          { keys: [":set nonu"], desc: "Ocultar números de línea" },
          { keys: [":help cmd"], desc: "Abrir ayuda de Vim" },
          { keys: [":%s/a/b/g"], desc: "Reemplazar todo" },
          { keys: [":sort"], desc: "Ordenar líneas seleccionadas" },
        ]
      },
    ],

    id: [
      {
        title: "Mode", icon: "󰀻",
        binds: [
          { keys: ["i"], desc: "Sisipkan sebelum kursor" },
          { keys: ["a"], desc: "Sisipkan setelah kursor" },
          { keys: ["I"], desc: "Sisipkan di awal baris" },
          { keys: ["A"], desc: "Sisipkan di akhir baris" },
          { keys: ["o"], desc: "Baris baru di bawah" },
          { keys: ["O"], desc: "Baris baru di atas" },
          { keys: ["Esc"], desc: "Kembali ke mode Normal" },
          { keys: ["v"], desc: "Mode Visual" },
          { keys: ["V"], desc: "Mode Visual baris" },
          { keys: ["Ctrl+v"], desc: "Mode Visual blok" },
          { keys: ["R"], desc: "Mode Ganti" },
        ]
      },
      {
        title: "Pergerakan", icon: "󱂬",
        binds: [
          { keys: ["h", "j", "k", "l"], desc: "Gerak kiri / bawah / atas / kanan" },
          { keys: ["w"], desc: "Kata berikutnya" },
          { keys: ["b"], desc: "Kata sebelumnya" },
          { keys: ["e"], desc: "Akhir kata" },
          { keys: ["0"], desc: "Awal baris" },
          { keys: ["^"], desc: "Karakter non-kosong pertama" },
          { keys: ["$"], desc: "Akhir baris" },
          { keys: ["gg"], desc: "Awal berkas" },
          { keys: ["G"], desc: "Akhir berkas" },
          { keys: ["H"], desc: "Atas layar" },
          { keys: ["M"], desc: "Tengah layar" },
          { keys: ["L"], desc: "Bawah layar" },
          { keys: ["Ctrl+d"], desc: "Turun setengah halaman" },
          { keys: ["Ctrl+u"], desc: "Naik setengah halaman" },
          { keys: ["Ctrl+f"], desc: "Turun satu halaman penuh" },
          { keys: ["Ctrl+b"], desc: "Naik satu halaman penuh" },
        ]
      },
      {
        title: "Pengeditan", icon: "󰁌",
        binds: [
          { keys: ["x"], desc: "Hapus karakter" },
          { keys: ["X"], desc: "Hapus karakter sebelumnya" },
          { keys: ["dd"], desc: "Hapus baris" },
          { keys: ["dw"], desc: "Hapus kata" },
          { keys: ["D"], desc: "Hapus sampai akhir baris" },
          { keys: ["cw"], desc: "Ubah kata" },
          { keys: ["ciw"], desc: "Ubah seluruh kata" },
          { keys: ["C"], desc: "Ubah sampai akhir baris" },
          { keys: ["r"], desc: "Ganti karakter" },
          { keys: ["s"], desc: "Ganti karakter (substitute)" },
          { keys: ["S"], desc: "Ganti seluruh baris" },
          { keys: ["u"], desc: "Undo" },
          { keys: ["Ctrl+r"], desc: "Redo" },
          { keys: ["."], desc: "Ulangi perubahan terakhir" },
        ]
      },
      {
        title: "Pencarian", icon: "󰆾",
        binds: [
          { keys: ["/teks"], desc: "Cari maju" },
          { keys: ["?teks"], desc: "Cari mundur" },
          { keys: ["n"], desc: "Kecocokan berikutnya" },
          { keys: ["N"], desc: "Kecocokan sebelumnya" },
          { keys: ["*"], desc: "Cari kata di bawah kursor" },
          { keys: ["#"], desc: "Cari kata ke belakang" },
          { keys: [":noh"], desc: "Hapus sorotan pencarian" },
        ]
      },
      {
        title: "Simpan / Keluar", icon: "󰕰",
        binds: [
          { keys: [":w"], desc: "Simpan" },
          { keys: [":q"], desc: "Keluar" },
          { keys: [":wq"], desc: "Simpan dan keluar" },
          { keys: [":x"], desc: "Simpan dan keluar" },
          { keys: [":q!"], desc: "Keluar tanpa menyimpan" },
          { keys: [":w!"], desc: "Paksa simpan" },
          { keys: ["ZZ"], desc: "Simpan dan keluar" },
          { keys: ["ZQ"], desc: "Keluar tanpa menyimpan" },
        ]
      },
      {
        title: "Jendela", icon: "󰊓",
        binds: [
          { keys: [":split"], desc: "Bagi horizontal" },
          { keys: [":vsplit"], desc: "Bagi vertikal" },
          { keys: ["Ctrl+w", "h"], desc: "Pindah ke kiri" },
          { keys: ["Ctrl+w", "j"], desc: "Pindah ke bawah" },
          { keys: ["Ctrl+w", "k"], desc: "Pindah ke atas" },
          { keys: ["Ctrl+w", "l"], desc: "Pindah ke kanan" },
          { keys: ["Ctrl+w", "q"], desc: "Tutup jendela" },
          { keys: ["Ctrl+w", "o"], desc: "Pertahankan jendela ini saja" },
          { keys: ["Ctrl+w", "="], desc: "Samakan ukuran jendela" },
        ]
      },
      {
        title: "Mode Visual", icon: "󰘔",
        binds: [
          { keys: ["v"], desc: "Pilih karakter" },
          { keys: ["V"], desc: "Pilih baris" },
          { keys: ["Ctrl+v"], desc: "Pilih blok" },
          { keys: ["y"], desc: "Salin seleksi" },
          { keys: ["d"], desc: "Hapus seleksi" },
          { keys: ["c"], desc: "Ubah seleksi" },
          { keys: [">"], desc: "Tambah indentasi" },
          { keys: ["<"], desc: "Kurangi indentasi" },
          { keys: ["~"], desc: "Alihkan huruf besar/kecil" },
          { keys: ["u"], desc: "Ubah ke huruf kecil" },
          { keys: ["U"], desc: "Ubah ke huruf besar" },
        ]
      },
      {
        title: "Indentasi", icon: "󰆍",
        binds: [
          { keys: [">>"], desc: "Tambah indentasi baris" },
          { keys: ["<<"], desc: "Kurangi indentasi baris" },
          { keys: ["="], desc: "Auto-indentasi" },
          { keys: ["=="], desc: "Auto-indentasi baris" },
          { keys: ["gg=G"], desc: "Format seluruh berkas" },
          { keys: ["=%"], desc: "Format blok" },
        ]
      },
      {
        title: "Objek Teks", icon: "󰄀",
        binds: [
          { keys: ["iw"], desc: "Kata bagian dalam" },
          { keys: ["aw"], desc: "Seluruh kata" },
          { keys: ["i\""], desc: "Di dalam tanda kutip" },
          { keys: ["a\""], desc: "Di sekitar tanda kutip" },
          { keys: ["i'"], desc: "Di dalam kutip tunggal" },
          { keys: ["a'"], desc: "Di sekitar kutip tunggal" },
          { keys: ["i("], desc: "Di dalam tanda kurung" },
          { keys: ["a("], desc: "Di sekitar tanda kurung" },
          { keys: ["i{"], desc: "Di dalam kurung kurawal" },
          { keys: ["a{"], desc: "Di sekitar kurung kurawal" },
          { keys: ["it"], desc: "Di dalam tag HTML/XML" },
        ]
      },
      {
        title: "Hitungan", icon: "󰀻",
        binds: [
          { keys: ["5j"], desc: "Turun 5 baris" },
          { keys: ["3w"], desc: "Maju 3 kata" },
          { keys: ["2dd"], desc: "Hapus 2 baris" },
          { keys: ["4yy"], desc: "Salin 4 baris" },
          { keys: ["3p"], desc: "Tempel 3 kali" },
          { keys: ["10G"], desc: "Pergi ke baris 10" },
          { keys: ["5dw"], desc: "Hapus 5 kata" },
          { keys: ["2>>"], desc: "Indentasi 2 baris" },
        ]
      },
      {
        title: "Register", icon: "󱂬",
        binds: [
          { keys: ["\"ayy"], desc: "Salin baris ke register a" },
          { keys: ["\"ap"], desc: "Tempel dari register a" },
          { keys: ["\"+y"], desc: "Salin ke clipboard sistem" },
          { keys: ["\"+p"], desc: "Tempel dari clipboard sistem" },
          { keys: ["\"*y"], desc: "Salin ke seleksi utama" },
          { keys: ["\"*p"], desc: "Tempel seleksi utama" },
          { keys: [":reg"], desc: "Tampilkan register" },
        ]
      },
      {
        title: "Makro", icon: "󰁌",
        binds: [
          { keys: ["qa"], desc: "Rekam makro ke register a" },
          { keys: ["q"], desc: "Hentikan rekaman" },
          { keys: ["@a"], desc: "Jalankan makro a" },
          { keys: ["@@"], desc: "Ulangi makro terakhir" },
          { keys: ["5@a"], desc: "Jalankan makro a 5 kali" },
        ]
      },
      {
        title: "Penanda", icon: "󰆾",
        binds: [
          { keys: ["ma"], desc: "Pasang penanda a" },
          { keys: ["'a"], desc: "Lompat ke baris penanda a" },
          { keys: ["`a"], desc: "Lompat ke posisi persis penanda a" },
          { keys: [":marks"], desc: "Tampilkan penanda" },
          { keys: ["''"], desc: "Lompat ke posisi sebelumnya" },
          { keys: ["`."], desc: "Lompat ke perubahan terakhir" },
        ]
      },
      {
        title: "Lipatan", icon: "󰕰",
        binds: [
          { keys: ["za"], desc: "Alihkan lipatan" },
          { keys: ["zo"], desc: "Buka lipatan" },
          { keys: ["zc"], desc: "Tutup lipatan" },
          { keys: ["zR"], desc: "Buka semua lipatan" },
          { keys: ["zM"], desc: "Tutup semua lipatan" },
          { keys: ["zj"], desc: "Ke lipatan berikutnya" },
          { keys: ["zk"], desc: "Ke lipatan sebelumnya" },
        ]
      },
      {
        title: "Perintah", icon: "󰊓",
        binds: [
          { keys: [":e berkas"], desc: "Buka berkas" },
          { keys: [":enew"], desc: "Buffer kosong baru" },
          { keys: [":bn"], desc: "Buffer berikutnya" },
          { keys: [":bp"], desc: "Buffer sebelumnya" },
          { keys: [":bd"], desc: "Hapus buffer" },
          { keys: [":set nu"], desc: "Tampilkan nomor baris" },
          { keys: [":set nonu"], desc: "Sembunyikan nomor baris" },
          { keys: [":help cmd"], desc: "Buka bantuan Vim" },
          { keys: [":%s/a/b/g"], desc: "Ganti semua" },
          { keys: [":sort"], desc: "Urutkan baris terpilih" },
        ]
      },
    ],
  })

  // Secciones de Vim del idioma activo, con fallback a inglés.
  function vimSections() {
    return root.vimSectionsData[root.current] || root.vimSectionsData.en
  }
}
