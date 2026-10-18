// SECCION: CLI APPLY NEXT PREV STOP PAUSE STATUS LIST DIRS
// IPC: apply next prev stop pause resume toggle status list browse capabilities matugen dirs dirs-add dirs-remove volume mute scaling hwdec transitions
use std::path::{Path, PathBuf};

fn usage() -> String {
    let lines = [
        "oozewalls apply <archivo> [--output N] [--scaling fit|fill|stretch] [--no-palette] [--transition K] [--transition-duration MS] [--no-transition]",
        "oozewalls restore [--force] [--only live|static]",
        "oozewalls palette [--scheme S] [--index N] [--mode dark|light] [--image P] [--probe --json]",
        "oozewalls set <clave> <valor>   (static_backend scheme source_index palette_mode palette_auto transition transition_ms ...)",
        "oozewalls transitions [--json]",
        "oozewalls config",
        "oozewalls next [--output N] [--all]",
        "oozewalls prev [--output N] [--all]",
        "oozewalls stop [--output N]",
        "oozewalls pause",
        "oozewalls resume",
        "oozewalls toggle",
        "oozewalls status [--json]",
        "oozewalls list [--json] [--folder <carpeta>]",
        "oozewalls browse [--path <carpeta>] [--json]",
        "oozewalls capabilities [--json]",
        "oozewalls volume [0-100]",
        "oozewalls mute [on|off]",
        "oozewalls scaling [fit|fill|stretch] [--output N]",
        "oozewalls hwdec [auto-safe|vaapi|nvdec|no]",
        "oozewalls matugen <imagen> [--mode dark|light] [--scheme content]",
        "oozewalls dirs [--json]",
        "oozewalls dirs-add <carpeta>",
        "oozewalls dirs-remove <carpeta>",
    ];
    lines.join("\n")
}

fn flag_value(args: &[String], key: &str) -> Option<String> {
    let mut it = args.iter().peekable();
    while let Some(a) = it.next() {
        if a == key {
            if let Some(v) = it.next() {
                return Some(v.clone());
            }
        }
        if let Some(v) = a.strip_prefix(&format!("{}=", key)) {
            return Some(v.to_string());
        }
    }
    None
}

fn has_flag(args: &[String], key: &str) -> bool {
    args.iter().any(|a| a == key)
}

fn resolve_path(s: &str) -> PathBuf {
    let p = PathBuf::from(s);
    if p.is_relative() {
        std::env::current_dir().unwrap_or_default().join(p)
    } else {
        p
    }
}

fn pick_output(args: &[String], cfg: &crate::config::Config) -> String {
    if let Some(o) = flag_value(args, "--output").or_else(|| flag_value(args, "-o")) {
        return o;
    }
    if !cfg.output.is_empty() {
        return cfg.output.clone();
    }
    String::from("*")
}

fn pool(cfg: &crate::config::Config) -> Vec<crate::scan::Entry> {
    crate::scan::scan(&cfg.dirs)
}

fn transition_names() -> String {
    crate::transition::KINDS
        .iter()
        .map(|(k, _)| *k)
        .collect::<Vec<_>>()
        .join("|")
}

fn cmd_transitions(json: bool) -> i32 {
    let cfg = crate::config::Config::load();
    if json {
        let kinds: Vec<serde_json::Value> = crate::transition::KINDS
            .iter()
            .map(|(k, l)| serde_json::json!({"id": k, "label": l}))
            .collect();
        let v = serde_json::json!({
            "current": cfg.transition,
            "duration_ms": cfg.transition_ms,
            "min_ms": crate::transition::MIN_MS,
            "max_ms": crate::transition::MAX_MS,
            "kinds": kinds,
        });
        println!("{}", serde_json::to_string_pretty(&v).unwrap_or_default());
    } else {
        for (k, l) in crate::transition::KINDS {
            let mark = if *k == cfg.transition { "*" } else { " " };
            println!("{} {} {}", mark, k, l);
        }
        println!("duracion {} ms", cfg.transition_ms);
    }
    0
}

fn cmd_apply(target: &str, output: &str, args: &[String]) -> i32 {
    let scaling = flag_value(args, "--scaling").map(|x| x.to_lowercase());
    if let Some(sc) = scaling.as_ref() {
        if sc != "fit" && sc != "fill" && sc != "stretch" {
            eprintln!("uso: --scaling fit|fill|stretch");
            return 1;
        }
    }
    let transition = flag_value(args, "--transition").map(|x| x.to_lowercase());
    if let Some(k) = transition.as_ref() {
        if !crate::transition::is_valid(k) {
            eprintln!("uso: --transition {}", transition_names());
            return 1;
        }
    }
    let transition_ms = match flag_value(args, "--transition-duration") {
        Some(v) => match v.parse::<u32>() {
            Ok(n) => Some(n),
            Err(_) => {
                eprintln!("uso: --transition-duration <milisegundos>");
                return 1;
            }
        },
        None => None,
    };
    let opts = crate::actions::Opts {
        scaling,
        palette: !has_flag(args, "--no-palette"),
        animate: !has_flag(args, "--no-transition"),
        transition,
        transition_ms,
    };
    match crate::actions::apply_file_opts(target, output, &opts) {
        Ok(line) => {
            println!("{}", line);
            0
        }
        Err(e) => {
            eprintln!("{}", e);
            1
        }
    }
}

fn cmd_step(dir: i32, output: &str, all: bool) -> i32 {
    match crate::actions::step(dir, output, all) {
        Ok(line) => {
            println!("{}", line);
            0
        }
        Err(e) => {
            eprintln!("{}", e);
            1
        }
    }
}

fn cmd_stop(output: &str) -> i32 {
    println!("{}", crate::actions::stop_out(output));
    0
}

fn status_json() -> serde_json::Value {
    let cfg = crate::config::Config::load();
    let socks = crate::ipc::discover();
    let pids = crate::engine::mpvpaper_pids();
    let paused = crate::engine::paused_state();
    let ram = crate::engine::rss_mb();
    let outs: Vec<serde_json::Value> = socks
        .iter()
        .map(|s| {
            let out = crate::ipc::output_for_socket(s);
            serde_json::json!({
                "output": out,
                "socket": s.to_string_lossy(),
                "pause": crate::ipc::get_bool(s, "pause"),
                "pid": crate::ipc::get_u64(s, "pid"),
            })
        })
        .collect();
    serde_json::json!({
        "current": cfg.current,
        "running": !pids.is_empty(),
        "paused": paused,
        "ram_mb": ram,
        "ram_budget_mb": 500,
        "over_budget": ram > 500,
        "pids": pids,
        "static_pids": crate::layerbg::pids(),
        "sockets": outs,
        "hwdec": cfg.hwdec,
        "mute": cfg.mute,
        "volume": cfg.volume,
        "wallpapers": cfg.wallpapers,
        "dirs": cfg.dirs,
        "output": cfg.output,
        "scaling": cfg.scaling,
        "transition": cfg.transition,
        "transition_ms": cfg.transition_ms,
        "compositor": crate::outputs::detect_compositor(),
    })
}

fn cmd_status(json: bool) -> i32 {
    let v = status_json();
    if json {
        println!("{}", serde_json::to_string_pretty(&v).unwrap_or_default());
    } else {
        let cur = v
            .get("current")
            .and_then(|x| x.as_str())
            .unwrap_or("ninguno");
        println!("actual: {}", cur);
        println!(
            "running: {}",
            v.get("running").and_then(|x| x.as_bool()).unwrap_or(false)
        );
        println!(
            "paused: {}",
            v.get("paused").and_then(|x| x.as_bool()).unwrap_or(false)
        );
        println!(
            "ram_mb: {}",
            v.get("ram_mb").and_then(|x| x.as_u64()).unwrap_or(0)
        );
        println!(
            "hwdec: {}",
            v.get("hwdec").and_then(|x| x.as_str()).unwrap_or("")
        );
    }
    0
}

fn cmd_list(json: bool, folder: Option<String>) -> i32 {
    let cfg = crate::config::Config::load();
    let p = match folder {
        Some(f) => {
            let full = resolve_path(&f).to_string_lossy().to_string();
            crate::scan::list_dir(&full).1
        }
        None => pool(&cfg),
    };
    if json {
        println!("{}", serde_json::to_string_pretty(&p).unwrap_or_default());
    } else {
        for e in &p {
            println!("{} {}", if e.is_video { "live" } else { "img" }, e.path);
        }
    }
    0
}

fn cmd_browse(args: &[String]) -> i32 {
    let cfg = crate::config::Config::load();
    let json = has_flag(args, "--json");
    let (path, parent, folders, entries) = match flag_value(args, "--path") {
        None => {
            let folders: Vec<crate::scan::Folder> = cfg
                .dirs
                .iter()
                .map(|d| crate::scan::folder_info(d))
                .collect();
            (String::new(), None, folders, Vec::new())
        }
        Some(raw) => {
            let full = resolve_path(&raw).to_string_lossy().to_string();
            let root = match crate::scan::root_for(&full, &cfg.dirs) {
                Some(r) => r,
                None => {
                    eprintln!("fuera de la biblioteca {}", full);
                    return 1;
                }
            };
            let parent = if crate::scan::same_dir(&full, &root) {
                Some(String::new())
            } else {
                Path::new(&full)
                    .parent()
                    .map(|p| p.to_string_lossy().to_string())
            };
            let (folders, entries) = crate::scan::list_dir(&full);
            (full, parent, folders, entries)
        }
    };
    if json {
        let v = serde_json::json!({
            "path": path,
            "parent": parent,
            "folders": folders,
            "entries": entries,
        });
        println!("{}", serde_json::to_string_pretty(&v).unwrap_or_default());
    } else {
        for f in &folders {
            println!("dir {}", f.path);
        }
        for e in &entries {
            println!("{} {}", if e.is_video { "live" } else { "img" }, e.path);
        }
    }
    0
}

fn cmd_capabilities(json: bool) -> i32 {
    let c = crate::outputs::capabilities();
    if json {
        println!("{}", serde_json::to_string_pretty(&c).unwrap_or_default());
    } else {
        println!("compositor: {}", c.compositor);
        println!("layer: {}", c.layer);
        println!("static: {}", c.static_setter);
        for o in &c.outputs {
            println!("{} {}x{}", o.name, o.width, o.height);
        }
    }
    0
}

fn cmd_dirs(json: bool) -> i32 {
    let cfg = crate::config::Config::load();
    if json {
        println!(
            "{}",
            serde_json::to_string_pretty(&cfg.dirs).unwrap_or_default()
        );
    } else {
        for d in &cfg.dirs {
            println!("{}", d);
        }
    }
    0
}

fn cmd_dirs_add(path: &str) -> i32 {
    let full = resolve_path(path);
    if !full.is_dir() {
        eprintln!("no es carpeta {}", full.display());
        return 1;
    }
    let mut cfg = crate::config::Config::load();
    let s = full.to_string_lossy().to_string();
    if !cfg.dirs.contains(&s) {
        cfg.dirs.push(s.clone());
        let _ = cfg.save();
    }
    println!("{}", s);
    0
}

fn cmd_dirs_remove(path: &str) -> i32 {
    let mut cfg = crate::config::Config::load();
    let target = resolve_path(path).to_string_lossy().to_string();
    let before = cfg.dirs.len();
    cfg.dirs.retain(|d| d != &target && d != path);
    if cfg.dirs.len() == before {
        eprintln!("no estaba {}", path);
        return 1;
    }
    let _ = cfg.save();
    println!("ok");
    0
}

fn cmd_matugen(args: &[String]) -> i32 {
    let raw = args.get(2).cloned().unwrap_or_default();
    let img = crate::matugen::palette_hook(&raw);
    if img.is_empty() || !Path::new(&img).is_file() {
        eprintln!("uso: oozewalls matugen <imagen> [--mode dark] [--scheme content]");
        return 1;
    }
    let mode = flag_value(args, "--mode").unwrap_or_else(|| String::from("dark"));
    let scheme = flag_value(args, "--scheme").unwrap_or_else(|| String::from("content"));
    match crate::matugen::run_matugen(&img, &mode, &scheme) {
        Ok(o) => {
            println!("{}", o);
            0
        }
        Err(e) => {
            eprintln!("{}", e);
            2
        }
    }
}

fn cmd_restore(args: &[String]) -> i32 {
    match crate::actions::restore(
        has_flag(args, "--force"),
        flag_value(args, "--only").as_deref(),
    ) {
        Ok(l) => {
            println!("{}", l);
            0
        }
        Err(e) => {
            eprintln!("{}", e);
            1
        }
    }
}

fn current_image(cfg: &crate::config::Config) -> Option<String> {
    let cur = cfg.current.clone()?;
    let is_video = crate::scan::is_video_path(Path::new(&cur));
    if !is_video {
        return Some(cur);
    }
    crate::thumbs::ensure(&cur, true).map(|p| p.to_string_lossy().to_string())
}

fn cmd_palette(args: &[String]) -> i32 {
    let mut cfg = crate::config::Config::load();
    let mut changed = false;
    if let Some(sc) = flag_value(args, "--scheme") {
        let name = crate::matugen::SCHEMES
            .iter()
            .find(|(n, l)| *n == sc || *l == sc)
            .map(|(n, _)| n.to_string());
        match name {
            Some(n) => {
                cfg.scheme = n;
                changed = true;
            }
            None => {
                eprintln!("esquema invalido: {}", sc);
                return 1;
            }
        }
    }
    if let Some(i) = flag_value(args, "--index") {
        cfg.source_index = i.parse::<u8>().unwrap_or(0).min(9);
        changed = true;
    }
    if let Some(m) = flag_value(args, "--mode") {
        cfg.palette_mode = if m == "light" { "light" } else { "dark" }.to_string();
        changed = true;
    }
    let img = flag_value(args, "--image")
        .map(|p| resolve_path(&p).to_string_lossy().to_string())
        .or_else(|| current_image(&cfg));
    if changed && !has_flag(args, "--no-save") {
        let _ = cfg.save();
    }
    let Some(img) = img else {
        eprintln!("sin imagen: usa --image o aplica un fondo primero");
        return 1;
    };
    if has_flag(args, "--probe") {
        let v = crate::matugen::probe(&img, &cfg.palette_mode, &cfg.scheme);
        if has_flag(args, "--json") {
            println!("{}", serde_json::json!(v));
        } else {
            for h in v {
                println!("{}", h);
            }
        }
        return 0;
    }
    match crate::actions::run_palette(&cfg, &img) {
        Ok(()) => {
            println!("ok {}", cfg.colors_path().display());
            0
        }
        Err(e) => {
            eprintln!("{}", e);
            2
        }
    }
}

const SET_KEYS: &[&str] = &[
    "static_backend",
    "scheme",
    "source_index",
    "palette_mode",
    "palette_auto",
    "colors_file",
    "transition",
    "transition_ms",
    "hwdec",
    "layer",
    "output",
    "mute",
    "volume",
];

fn cmd_set(args: &[String]) -> i32 {
    let (Some(key), Some(val)) = (args.get(2), args.get(3)) else {
        eprintln!("uso: oozewalls set <{}> <valor>", SET_KEYS.join("|"));
        return 1;
    };
    let mut cfg = crate::config::Config::load();
    let b = |v: &str| matches!(v, "on" | "1" | "true" | "yes");
    match key.as_str() {
        "static_backend" => {
            if !crate::config::STATIC_BACKENDS.contains(&val.as_str()) {
                eprintln!("valores: {}", crate::config::STATIC_BACKENDS.join("|"));
                return 1;
            }
            cfg.static_backend = val.clone();
        }
        "scheme" => match crate::matugen::SCHEMES
            .iter()
            .find(|(n, l)| n == val || l == val)
        {
            Some((n, _)) => cfg.scheme = n.to_string(),
            None => {
                eprintln!("esquema invalido");
                return 1;
            }
        },
        "source_index" => cfg.source_index = val.parse::<u8>().unwrap_or(0).min(9),
        "palette_mode" => cfg.palette_mode = if val == "light" { "light" } else { "dark" }.into(),
        "palette_auto" => cfg.palette_auto = b(val),
        "colors_file" => cfg.colors_file = val.clone(),
        "transition" => {
            let k = val.to_lowercase();
            if !crate::transition::is_valid(&k) {
                eprintln!("valores: {}", transition_names());
                return 1;
            }
            cfg.transition = k;
        }
        "transition_ms" => match val.parse::<u32>() {
            Ok(n) => cfg.transition_ms = crate::transition::clamp_ms(n),
            Err(_) => {
                eprintln!("uso: oozewalls set transition_ms <{}-{}>", crate::transition::MIN_MS, crate::transition::MAX_MS);
                return 1;
            }
        },
        "hwdec" => cfg.hwdec = val.clone(),
        "layer" => cfg.layer = val.clone(),
        "output" => cfg.output = val.clone(),
        "mute" => cfg.mute = b(val),
        "volume" => cfg.volume = val.parse::<u8>().unwrap_or(100).min(100),
        _ => {
            eprintln!("clave desconocida; validas: {}", SET_KEYS.join(", "));
            return 1;
        }
    }
    match cfg.save() {
        Ok(()) => {
            println!("ok");
            0
        }
        Err(e) => {
            eprintln!("{}", e);
            1
        }
    }
}

fn cmd_config() -> i32 {
    let cfg = crate::config::Config::load();
    println!(
        "{}",
        serde_json::to_string_pretty(&cfg).unwrap_or_else(|_| String::from("{}"))
    );
    0
}

fn cmd_volume(args: &[String]) -> i32 {
    let raw = args.get(2).cloned().unwrap_or_default();
    if raw.is_empty() {
        let cfg = crate::config::Config::load();
        println!("{}", cfg.volume);
        return 0;
    }
    let v: u8 = raw.parse::<u8>().unwrap_or(101).min(100);
    if v > 100 {
        eprintln!("uso: oozewalls volume 0-100");
        return 1;
    }
    let mut cfg = crate::config::Config::load();
    cfg.volume = v;
    let _ = cfg.save();
    crate::engine::set_volume_all(v);
    println!("{}", v);
    0
}

fn cmd_mute(args: &[String]) -> i32 {
    let raw = args.get(2).cloned().unwrap_or_default().to_lowercase();
    let mut cfg = crate::config::Config::load();
    if raw.is_empty() {
        println!("{}", if cfg.mute { "on" } else { "off" });
        return 0;
    }
    let val = match raw.as_str() {
        "on" | "1" | "true" => true,
        "off" | "0" | "false" => false,
        _ => {
            eprintln!("uso: oozewalls mute on|off");
            return 1;
        }
    };
    cfg.mute = val;
    let _ = cfg.save();
    crate::engine::set_mute_all(val);
    println!("{}", if val { "on" } else { "off" });
    0
}

fn cmd_scaling(args: &[String]) -> i32 {
    let cfg = crate::config::Config::load();
    let out = pick_output(args, &cfg);
    let raw = args.get(2).cloned().unwrap_or_default().to_lowercase();
    if raw.is_empty() {
        println!("{}", cfg.scaling_for(&out));
        return 0;
    }
    if raw != "fit" && raw != "fill" && raw != "stretch" {
        eprintln!("uso: oozewalls scaling fit|fill|stretch");
        return 1;
    }
    let mut cfg = crate::config::Config::load();
    cfg.scaling.insert(out.clone(), raw.clone());
    let _ = cfg.save();
    println!("{} {}", out, raw);
    0
}

fn cmd_hwdec(args: &[String]) -> i32 {
    let raw = args.get(2).cloned().unwrap_or_default().to_lowercase();
    if raw.is_empty() {
        println!("{}", crate::config::Config::load().hwdec);
        return 0;
    }
    if raw != "auto-safe" && raw != "vaapi" && raw != "nvdec" && raw != "no" {
        eprintln!("uso: oozewalls hwdec auto-safe|vaapi|nvdec|no");
        return 1;
    }
    let mut cfg = crate::config::Config::load();
    cfg.hwdec = raw.clone();
    let _ = cfg.save();
    println!("{}", raw);
    0
}

pub fn run(args: &[String]) -> i32 {
    if args.len() < 2 {
        eprintln!("{}", usage());
        return 1;
    }
    match args[1].as_str() {
        "__bg" => crate::layerbg::run(args),
        "restore" => cmd_restore(args),
        "palette" => cmd_palette(args),
        "set" => cmd_set(args),
        "config" => cmd_config(),
        "apply" => {
            if args.len() < 3 {
                eprintln!("uso: oozewalls apply <archivo>");
                return 1;
            }
            let cfg = crate::config::Config::load();
            let out = pick_output(args, &cfg);
            cmd_apply(&args[2].clone(), &out, args)
        }
        "next" => {
            let cfg = crate::config::Config::load();
            let out = pick_output(args, &cfg);
            cmd_step(1, &out, has_flag(args, "--all"))
        }
        "prev" => {
            let cfg = crate::config::Config::load();
            let out = pick_output(args, &cfg);
            cmd_step(-1, &out, has_flag(args, "--all"))
        }
        "stop" => {
            let cfg = crate::config::Config::load();
            let out = pick_output(args, &cfg);
            cmd_stop(&out)
        }
        "pause" => {
            crate::engine::pause_all();
            println!("pause");
            0
        }
        "resume" => {
            crate::engine::resume_all();
            println!("resume");
            0
        }
        "toggle" => {
            let p = crate::engine::toggle_all();
            println!("{}", if p { "pause" } else { "resume" });
            0
        }
        "status" => cmd_status(has_flag(args, "--json")),
        "list" => cmd_list(has_flag(args, "--json"), flag_value(args, "--folder")),
        "browse" => cmd_browse(args),
        "capabilities" => cmd_capabilities(has_flag(args, "--json")),
        "transitions" => cmd_transitions(has_flag(args, "--json")),
        "volume" => cmd_volume(args),
        "mute" => cmd_mute(args),
        "scaling" => cmd_scaling(args),
        "hwdec" => cmd_hwdec(args),
        "matugen" => cmd_matugen(args),
        "dirs" => cmd_dirs(has_flag(args, "--json")),
        "dirs-add" => {
            if args.len() < 3 {
                eprintln!("uso: oozewalls dirs-add <carpeta>");
                return 1;
            }
            let p = args[2].clone();
            cmd_dirs_add(&p)
        }
        "dirs-remove" => {
            if args.len() < 3 {
                eprintln!("uso: oozewalls dirs-remove <carpeta>");
                return 1;
            }
            let p = args[2].clone();
            cmd_dirs_remove(&p)
        }
        "help" | "--help" | "-h" => {
            println!("{}", usage());
            0
        }
        "version" | "--version" | "-v" => {
            println!("oozewalls {}", env!("CARGO_PKG_VERSION"));
            0
        }
        other => {
            eprintln!("comando {} ayuda: oozewalls help", other);
            1
        }
    }
}
