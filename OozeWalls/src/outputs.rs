// SECCION: OUTPUTS DETECT CAPABILITIES COMPOSITOR
// IPC: capabilities list detect
use serde::{Deserialize, Serialize};
use std::process::Command;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Output {
    pub name: String,
    pub width: u32,
    pub height: u32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Capabilities {
    pub compositor: String,
    pub outputs: Vec<Output>,
    pub layer: String,
    pub static_setter: String,
    pub hwdec_options: Vec<String>,
    pub fullscreen_probe: String,
}

pub fn detect_compositor() -> String {
    if std::env::var_os("HYPRLAND_INSTANCE_SIGNATURE").is_some() {
        return String::from("hyprland");
    }
    let cur = std::env::var("XDG_CURRENT_DESKTOP").unwrap_or_default();
    let low = cur.to_lowercase();
    if low.contains("niri") {
        return String::from("niri");
    }
    if low.contains("mango") {
        return String::from("mango");
    }
    if low.contains("hyprland") {
        return String::from("hyprland");
    }
    String::from("wayland")
}

fn from_hyprland() -> Vec<Output> {
    let mut v = Vec::new();
    if let Ok(o) = Command::new("hyprctl").args(["monitors", "-j"]).output() {
        if o.status.success() {
            if let Ok(json) = serde_json::from_slice::<serde_json::Value>(&o.stdout) {
                if let Some(arr) = json.as_array() {
                    for m in arr {
                        let name = m
                            .get("name")
                            .and_then(|x| x.as_str())
                            .unwrap_or("")
                            .to_string();
                        let w = m.get("width").and_then(|x| x.as_u64()).unwrap_or(1920) as u32;
                        let h = m.get("height").and_then(|x| x.as_u64()).unwrap_or(1080) as u32;
                        if !name.is_empty() {
                            v.push(Output {
                                name,
                                width: w,
                                height: h,
                            });
                        }
                    }
                }
            }
        }
    }
    v
}

fn from_niri() -> Vec<Output> {
    let mut v = Vec::new();
    if let Ok(o) = Command::new("niri").args(["msg", "outputs"]).output() {
        if o.status.success() {
            let text = String::from_utf8_lossy(&o.stdout);
            for line in text.lines() {
                let t = line.trim();
                if t.starts_with("Output ") {
                    let name = t
                        .strip_prefix("Output ")
                        .unwrap_or("")
                        .split_whitespace()
                        .next()
                        .unwrap_or("")
                        .trim_matches(|c| c == '"' || c == '\'')
                        .to_string();
                    if !name.is_empty() && !v.iter().any(|x: &Output| x.name == name) {
                        v.push(Output {
                            name,
                            width: 1920,
                            height: 1080,
                        });
                    }
                }
            }
        }
    }
    v
}

fn from_mpvpaper() -> Vec<Output> {
    let mut v = Vec::new();
    let bin = crate::engine::mpvpaper_bin();
    if let Ok(o) = Command::new(bin).arg("-d").output() {
        if o.status.success() {
            let text = String::from_utf8_lossy(&o.stdout);
            for line in text.lines() {
                if let Some(rest) = line.strip_prefix("[*] Output") {
                    let name = rest
                        .trim_start_matches(':')
                        .split_whitespace()
                        .next()
                        .unwrap_or("");
                    if !name.is_empty() && name != "found" {
                        v.push(Output {
                            name: name.to_string(),
                            width: 1920,
                            height: 1080,
                        });
                    }
                }
            }
        }
    }
    v
}

pub fn detect() -> Vec<Output> {
    let comp = detect_compositor();
    let mut v = match comp.as_str() {
        "hyprland" => from_hyprland(),
        "niri" => from_niri(),
        _ => Vec::new(),
    };
    if v.is_empty() {
        v = from_mpvpaper();
    }
    if v.is_empty() {
        v.push(Output {
            name: String::from("*"),
            width: 1920,
            height: 1080,
        });
    }
    v
}

pub fn capabilities() -> Capabilities {
    let comp = detect_compositor();
    let outputs = detect();
    let static_setter = match comp.as_str() {
        "hyprland" => String::from("hyprpaper|hyprctl hyprpaper"),
        "niri" => String::from("swaybg"),
        "mango" => String::from("swaybg"),
        _ => String::from("swaybg|awww"),
    };
    let probe = match comp.as_str() {
        "hyprland" => String::from("hyprctl activewindow -j | fullscreen"),
        "niri" => String::from("niri msg focused-output"),
        _ => String::from("none"),
    };
    Capabilities {
        compositor: comp,
        outputs,
        layer: String::from("background"),
        static_setter,
        hwdec_options: vec![
            String::from("auto-safe"),
            String::from("vaapi"),
            String::from("nvdec"),
            String::from("no"),
        ],
        fullscreen_probe: probe,
    }
}
