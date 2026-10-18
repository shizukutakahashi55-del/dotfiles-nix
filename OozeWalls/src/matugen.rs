// SECCION: MATUGEN PALETA REAL (colors.json del shell)
// IPC: palette matugen probe
//
// Replica lo que hace OozeShell/WALLS/Walls.qml: corre matugen con esquema,
// modo e indice de color fuente, aplica las plantillas y deja el JSON `hex`
// en colors.json, que Theme.qml vigila y recarga solo.
use std::path::Path;
use std::process::{Command, Stdio};

/// (nombre matugen, etiqueta corta) en el mismo orden que Theme.schemes del shell.
pub const SCHEMES: &[(&str, &str)] = &[
    ("vibrant", "vibrant"),
    ("tonal-spot", "tonal"),
    ("neutral", "neutral"),
    ("fruit-salad", "fruit"),
    ("rainbow", "rainbow"),
    ("fidelity", "fidelity"),
    ("content", "content"),
    ("monochrome", "mono"),
];

pub fn palette_hook(image: &str) -> String {
    image.to_string()
}

fn base(image: &str, mode: &str, scheme: &str, index: u8) -> Command {
    let mut c = Command::new("matugen");
    c.args(["image", image, "-m", mode])
        .args(["--source-color-index", &index.to_string()])
        .args(["-t", &format!("scheme-{}", scheme)])
        .stdin(Stdio::null());
    c
}

fn json_slice(text: &str) -> Option<&str> {
    let a = text.find('{')?;
    let b = text.rfind('}')?;
    if b > a {
        Some(&text[a..=b])
    } else {
        None
    }
}

/// Genera la paleta y la escribe (atomico) en `out`.
pub fn generate(
    image: &str,
    mode: &str,
    scheme: &str,
    index: u8,
    out: &Path,
) -> Result<(), String> {
    if !Path::new(image).is_file() {
        return Err(format!("no existe {}", image));
    }
    let mut idx = index;
    // 1) aplica las plantillas de matugen (si el indice no existe, vuelve al 0)
    let ok = base(image, mode, scheme, idx)
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .map(|s| s.success())
        .map_err(|e| format!("matugen {}", e))?;
    if !ok {
        idx = 0;
        let ok0 = base(image, mode, scheme, 0)
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .status()
            .map(|s| s.success())
            .unwrap_or(false);
        if !ok0 {
            return Err(String::from("matugen fallo"));
        }
    }
    // 2) mismo comando con --json hex para el colors.json del shell
    let o = base(image, mode, scheme, idx)
        .args(["--json", "hex"])
        .stderr(Stdio::null())
        .output()
        .map_err(|e| format!("matugen {}", e))?;
    let text = String::from_utf8_lossy(&o.stdout).to_string();
    let json = json_slice(&text).ok_or_else(|| String::from("matugen no devolvio JSON"))?;
    if serde_json::from_str::<serde_json::Value>(json).is_err() {
        return Err(String::from("JSON de matugen invalido"));
    }
    if let Some(dir) = out.parent() {
        let _ = std::fs::create_dir_all(dir);
    }
    let tmp = out.with_extension(format!("json.tmp{}", std::process::id()));
    std::fs::write(&tmp, json).map_err(|e| e.to_string())?;
    std::fs::rename(&tmp, out).map_err(|e| e.to_string())?;
    Ok(())
}

/// Colores `primary` de los indices fuente 0..5 (sin tocar nada).
pub fn probe(image: &str, mode: &str, scheme: &str) -> Vec<String> {
    let help = Command::new("matugen")
        .args(["image", "--help"])
        .stdin(Stdio::null())
        .output();
    match help {
        Ok(h) => {
            let t = format!(
                "{}{}",
                String::from_utf8_lossy(&h.stdout),
                String::from_utf8_lossy(&h.stderr)
            );
            if !t.contains("--dry-run") {
                return Vec::new();
            }
        }
        Err(_) => return Vec::new(),
    }
    let mut v: Vec<String> = Vec::new();
    for i in 0..6u8 {
        let o = base(image, mode, scheme, i)
            .args(["--dry-run", "--json", "hex"])
            .stderr(Stdio::null())
            .output();
        let Ok(o) = o else { break };
        let text = String::from_utf8_lossy(&o.stdout).to_string();
        let Some(json) = json_slice(&text) else { break };
        let Ok(j) = serde_json::from_str::<serde_json::Value>(json) else {
            break;
        };
        let hex = j["colors"]["primary"][mode]["color"].as_str();
        match hex {
            Some(h) if !v.iter().any(|x| x == h) => v.push(h.to_string()),
            Some(_) => {}
            None => break,
        }
    }
    v
}

/// Compat: salida cruda de matugen (comando `oozewalls matugen`).
pub fn run_matugen(image: &str, mode: &str, scheme: &str) -> Result<String, String> {
    let out = Command::new("matugen")
        .args([
            "image",
            image,
            "-m",
            mode,
            "-t",
            &format!("scheme-{}", scheme),
        ])
        .output()
        .map_err(|e| format!("matugen {}", e))?;
    if out.status.success() {
        Ok(String::from_utf8_lossy(&out.stdout).to_string())
    } else {
        Err(String::from_utf8_lossy(&out.stderr).to_string())
    }
}
