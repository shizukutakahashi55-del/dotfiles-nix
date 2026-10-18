// SECCION: ACTIONS APPLY STEP STOP
// IPC: apply next prev stop
use std::path::PathBuf;

pub fn resolve_path(s: &str) -> PathBuf {
    let p = PathBuf::from(s);
    if p.is_relative() {
        std::env::current_dir().unwrap_or_default().join(p)
    } else {
        p
    }
}

pub struct Opts {
    pub scaling: Option<String>,
    pub palette: bool,
    pub animate: bool,
    pub transition: Option<String>,
    pub transition_ms: Option<u32>,
}

impl Opts {
    pub fn plain(palette: bool, animate: bool) -> Self {
        Self {
            scaling: None,
            palette,
            animate,
            transition: None,
            transition_ms: None,
        }
    }
}

pub fn apply_file(target: &str, output: &str) -> Result<String, String> {
    apply_file_opts(
        target,
        output,
        &Opts::plain(true, true),
    )
}

fn write_last(path: &str) {
    if let Ok(home) = std::env::var("HOME") {
        let dir = PathBuf::from(home).join(".cache/awww");
        let _ = std::fs::create_dir_all(&dir);
        let _ = std::fs::write(dir.join("last"), format!("{}\n", path));
    }
}

/// Imagen de la que sale la paleta: la propia imagen, o un frame del video.
fn palette_source(path: &str, is_video: bool) -> Option<String> {
    if !is_video {
        return Some(path.to_string());
    }
    crate::thumbs::ensure(path, true).map(|p| p.to_string_lossy().to_string())
}

pub fn run_palette(cfg: &crate::config::Config, image: &str) -> Result<(), String> {
    crate::matugen::generate(
        image,
        &cfg.palette_mode,
        &cfg.scheme,
        cfg.source_index,
        &cfg.colors_path(),
    )
}

pub fn apply_file_opts(target: &str, output: &str, opts: &Opts) -> Result<String, String> {
    let full = resolve_path(target);
    if !full.is_file() {
        return Err(format!("no existe {}", full.display()));
    }
    let ext = full
        .extension()
        .and_then(|e| e.to_str())
        .unwrap_or_default()
        .to_string();
    if !crate::scan::is_supported(&ext) {
        return Err(format!("formato no soportado .{}", ext));
    }
    let mut cfg = crate::config::Config::load();
    if let Some(sc) = opts.scaling.as_ref() {
        cfg.scaling.insert(output.to_string(), sc.clone());
    }
    let scaling = cfg.scaling_for(output);
    let path_str = full.to_string_lossy().to_string();
    let is_video = crate::scan::is_video_path(&full);
    let tr = if opts.animate {
        crate::transition::Transition::from_config(&cfg)
            .with_overrides(opts.transition.as_deref(), opts.transition_ms)
    } else {
        crate::transition::Transition::none()
    };
    let detail = if is_video {
        let pid = crate::engine::apply_video(
            output, &path_str, &scaling, cfg.mute, cfg.volume, &cfg.hwdec, &cfg.layer, &tr,
        )?;
        format!("{} {}", path_str, pid)
    } else {
        crate::engine::apply_static(
            output, &path_str, &scaling, cfg.mute, cfg.volume, &cfg.hwdec, &cfg.layer, &tr,
        )?;
        path_str.clone()
    };
    if output == "*" {
        cfg.wallpapers.clear();
    } else {
        cfg.wallpapers.remove("*");
    }
    cfg.wallpapers.insert(output.to_string(), path_str.clone());
    cfg.current = Some(path_str.clone());
    cfg.output = output.to_string();
    cfg.save()?;
    // --no-palette = modo integrado: el shell maneja su propio "last" y su paleta
    if opts.palette {
        let src = palette_source(&path_str, is_video);
        if let Some(img) = src.as_ref() {
            write_last(img);
            if cfg.palette_auto {
                if let Err(e) = run_palette(&cfg, img) {
                    eprintln!("paleta: {}", e);
                }
            }
        }
    }
    Ok(detail)
}

/// Reaplica lo guardado en config.json (arranque de sesion). Reintenta
/// mientras el compositor termina de levantar.
pub fn restore(force: bool, only: Option<&str>) -> Result<String, String> {
    let want_video = match only {
        Some("live") => Some(true),
        Some("static") => Some(false),
        Some(other) => return Err(format!("--only invalido: {} (live|static)", other)),
        None => None,
    };
    let cfg = crate::config::Config::load();
    if cfg.wallpapers.is_empty() {
        return Err(String::from("nada que restaurar"));
    }
    if !force {
        let video_up = !crate::engine::mpvpaper_pids().is_empty();
        let static_up = !crate::layerbg::pids().is_empty();
        let active = match want_video {
            Some(true) => video_up,
            Some(false) => static_up,
            None => video_up || static_up,
        };
        if active {
            return Ok(String::from("ya activo"));
        }
    }
    let mut done = 0;
    for (out, path) in cfg.wallpapers.iter() {
        let p = PathBuf::from(path);
        if !p.is_file() {
            continue;
        }
        if let Some(v) = want_video {
            if crate::scan::is_video_path(&p) != v {
                continue;
            }
        }
        let mut last = String::new();
        for _ in 0..20 {
            match apply_file_opts(
                path,
                out,
                &Opts::plain(false, false),
            ) {
                Ok(_) => {
                    done += 1;
                    last.clear();
                    break;
                }
                Err(e) => {
                    last = e;
                    std::thread::sleep(std::time::Duration::from_millis(500));
                }
            }
        }
        if !last.is_empty() {
            return Err(last);
        }
    }
    Ok(format!("restaurado {}", done))
}

pub fn step(dir: i32, output: &str, all: bool) -> Result<String, String> {
    let cfg = crate::config::Config::load();
    let mut pool = crate::scan::scan(&cfg.dirs);
    if !all {
        if let Some(cur) = cfg.current.as_ref() {
            let folder = pool
                .iter()
                .find(|e| &e.path == cur)
                .map(|e| e.folder.clone());
            if let Some(f) = folder {
                pool.retain(|e| e.folder == f);
            }
        }
    }
    if pool.is_empty() {
        return Err(String::from("biblioteca vacia"));
    }
    pool.sort_by(|a, b| a.path.cmp(&b.path));
    let next = match cfg
        .current
        .as_ref()
        .and_then(|c| pool.iter().position(|e| &e.path == c))
    {
        Some(i) => {
            let n = pool.len() as i32;
            (((i as i32 + dir) % n + n) % n) as usize
        }
        None => {
            if dir < 0 {
                pool.len() - 1
            } else {
                0
            }
        }
    };
    let target = pool[next].path.clone();
    apply_file(&target, output)
}

pub fn stop_out(output: &str) -> String {
    if output == "*" || output == "all" {
        crate::engine::stop_all();
    } else {
        crate::engine::stop_output(output);
    }
    let mut cfg = crate::config::Config::load();
    if output == "*" || output == "all" {
        cfg.wallpapers.clear();
        cfg.current = None;
    } else {
        cfg.wallpapers.remove(output);
    }
    let _ = cfg.save();
    format!("stop {}", output)
}
