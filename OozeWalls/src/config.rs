// SECCION: CONFIG LOAD SAVE DIRS
// IPC: current wallpapers scaling mute volume hwdec
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::PathBuf;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Config {
    #[serde(default)]
    pub current: Option<String>,
    #[serde(default)]
    pub wallpapers: HashMap<String, String>,
    #[serde(default)]
    pub favorites: Vec<String>,
    #[serde(default)]
    pub scaling: HashMap<String, String>,
    #[serde(default)]
    pub dirs: Vec<String>,
    #[serde(default = "def_output")]
    pub output: String,
    #[serde(default = "def_true")]
    pub mute: bool,
    #[serde(default = "def_volume")]
    pub volume: u8,
    #[serde(default = "def_hwdec")]
    pub hwdec: String,
    #[serde(default = "def_layer")]
    pub layer: String,
    #[serde(default = "def_static_backend")]
    pub static_backend: String,
    #[serde(default = "def_scheme")]
    pub scheme: String,
    #[serde(default)]
    pub source_index: u8,
    #[serde(default = "def_pmode")]
    pub palette_mode: String,
    #[serde(default = "def_true")]
    pub palette_auto: bool,
    #[serde(default)]
    pub colors_file: String,
    #[serde(default = "def_transition")]
    pub transition: String,
    #[serde(default = "def_transition_ms")]
    pub transition_ms: u32,
    #[serde(default = "def_language")]
    pub language: String,
    #[serde(default = "def_ui_palette")]
    pub ui_palette: String,
    #[serde(default = "def_ui_font")]
    pub ui_font: String,
}

pub const STATIC_BACKENDS: &[&str] = &["auto", "awww", "builtin", "mpvpaper"];

fn def_static_backend() -> String {
    String::from("auto")
}

fn def_transition() -> String {
    String::from(crate::transition::DEFAULT_KIND)
}

fn def_transition_ms() -> u32 {
    crate::transition::DEFAULT_MS
}

fn def_scheme() -> String {
    String::from("vibrant")
}

fn def_pmode() -> String {
    String::from("dark")
}

fn def_output() -> String {
    String::from("*")
}

fn def_true() -> bool {
    true
}

fn def_volume() -> u8 {
    100
}

fn def_hwdec() -> String {
    String::from("auto-safe")
}

fn def_layer() -> String {
    String::from("background")
}

fn def_language() -> String {
    String::from("es")
}

fn def_ui_palette() -> String {
    String::from("violet")
}

fn def_ui_font() -> String {
    String::from("normal")
}

impl Default for Config {
    fn default() -> Self {
        Self {
            current: None,
            wallpapers: HashMap::new(),
            favorites: Vec::new(),
            scaling: HashMap::new(),
            dirs: default_dirs(),
            output: def_output(),
            mute: true,
            volume: 100,
            hwdec: def_hwdec(),
            layer: def_layer(),
            static_backend: def_static_backend(),
            scheme: def_scheme(),
            source_index: 0,
            palette_mode: def_pmode(),
            palette_auto: true,
            colors_file: String::new(),
            transition: def_transition(),
            transition_ms: def_transition_ms(),
            language: def_language(),
            ui_palette: def_ui_palette(),
            ui_font: def_ui_font(),
        }
    }
}

pub fn default_dirs() -> Vec<String> {
    let home = std::env::var("HOME").unwrap_or_else(|_| String::from("/tmp"));
    let mut v = vec![
        format!("{}/Pictures/Wallpapers", home),
        format!("{}/Videos/Wallpapers", home),
        format!("{}/.local/share/oozewalls/walls", home),
    ];
    v.retain(|d| PathBuf::from(d).exists());
    if v.is_empty() {
        v.push(format!("{}/Pictures/Wallpapers", home));
    }
    v
}

impl Config {
    pub fn dir() -> PathBuf {
        if let Some(x) = std::env::var_os("XDG_CONFIG_HOME") {
            if !x.is_empty() {
                return PathBuf::from(x).join("oozewalls");
            }
        }
        let home = std::env::var("HOME").unwrap_or_else(|_| String::from("."));
        PathBuf::from(home).join(".config/oozewalls")
    }

    pub fn file() -> PathBuf {
        Self::dir().join("config.json")
    }

    pub fn load() -> Self {
        let p = Self::file();
        if let Ok(text) = std::fs::read_to_string(&p) {
            if let Ok(mut c) = serde_json::from_str::<Config>(&text) {
                if c.dirs.is_empty() {
                    c.dirs = default_dirs();
                }
                c.volume = c.volume.min(100);
                c.favorites.sort();
                c.favorites.dedup();
                if c.language != "en" && c.language != "es" {
                    c.language = def_language();
                }
                if c.hwdec.is_empty() {
                    c.hwdec = def_hwdec();
                }
                if c.layer.is_empty() {
                    c.layer = def_layer();
                }
                if !STATIC_BACKENDS.contains(&c.static_backend.as_str()) {
                    c.static_backend = def_static_backend();
                }
                if !crate::matugen::SCHEMES.iter().any(|(n, _)| *n == c.scheme) {
                    c.scheme = def_scheme();
                }
                if c.palette_mode != "light" {
                    c.palette_mode = def_pmode();
                }
                c.source_index = c.source_index.min(9);
                if !crate::transition::is_valid(&c.transition) {
                    c.transition = def_transition();
                }
                c.transition_ms = crate::transition::clamp_ms(c.transition_ms);
                return c;
            }
        }
        Self::default()
    }

    pub fn save(&self) -> Result<(), String> {
        let dir = Self::dir();
        std::fs::create_dir_all(&dir).map_err(|e| e.to_string())?;
        let text = serde_json::to_string_pretty(self).map_err(|e| e.to_string())?;
        let tmp = dir.join(format!("config.json.tmp.{}", std::process::id()));
        std::fs::write(&tmp, text).map_err(|e| e.to_string())?;
        std::fs::rename(&tmp, Self::file()).map_err(|e| e.to_string())?;
        Ok(())
    }

    pub fn colors_path(&self) -> PathBuf {
        if !self.colors_file.is_empty() {
            return PathBuf::from(&self.colors_file);
        }
        let home = std::env::var("HOME").unwrap_or_else(|_| String::from("."));
        PathBuf::from(home).join(".cache/oozeshell/colors.json")
    }

    pub fn scaling_for(&self, output: &str) -> String {
        self.scaling
            .get(output)
            .cloned()
            .unwrap_or_else(|| String::from("fit"))
    }
}
