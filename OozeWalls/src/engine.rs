// SECCION: BUILD SPAWN APPLY STATIC STOP PAUSE VOLUME STATUS
// IPC: apply stop pause resume toggle set_property loadfile quit status awww swww transition
use std::path::PathBuf;
use std::process::{Command, Stdio};

pub fn mpvpaper_bin() -> std::ffi::OsString {
    if let Ok(exe) = std::env::current_exe() {
        if let Some(parent) = exe.parent() {
            let sib = parent.join("mpvpaper");
            if sib.is_file() {
                return sib.into_os_string();
            }
        }
    }
    if let Ok(home) = std::env::var("HOME") {
        let p = PathBuf::from(home).join(".local/bin/mpvpaper");
        if p.is_file() {
            return p.into_os_string();
        }
    }
    for cand in ["/usr/local/bin/mpvpaper", "/usr/bin/mpvpaper"] {
        if PathBuf::from(cand).is_file() {
            return cand.into();
        }
    }
    String::from("mpvpaper").into()
}

pub fn shader_dir() -> PathBuf {
    if let Some(x) = std::env::var_os("XDG_CACHE_HOME") {
        if !x.is_empty() {
            let p = PathBuf::from(x).join("oozewalls/mpv_shaders");
            let _ = std::fs::create_dir_all(&p);
            return p;
        }
    }
    let home = std::env::var("HOME").unwrap_or_else(|_| String::from("/tmp"));
    let p = PathBuf::from(home).join(".cache/oozewalls/mpv_shaders");
    let _ = std::fs::create_dir_all(&p);
    p
}

pub fn build_opts(scaling: &str, mute: bool, volume: u8, hwdec: &str) -> String {
    let mut o = format!(
        "loop-file=inf --image-display-duration=inf --hwdec={} --no-config --demuxer-max-bytes=16M --demuxer-readahead-secs=2 --vd-lavc-threads=2 --vd-lavc-dr=yes --gpu-shader-cache-dir={} --sub-auto=no --audio-display=no --no-osc --no-osd-bar --osd-level=0 --hr-seek=no --background-color=#000000 --profile=fast --load-scripts=no --ytdl=no",
        hwdec,
        shader_dir().display()
    );
    if mute || volume == 0 {
        o.push_str(" --no-audio");
    } else {
        o.push_str(&format!(" --volume={}", volume.min(100)));
    }
    match scaling {
        "fill" => o.push_str(" --panscan=1.0"),
        "stretch" => o.push_str(" --no-keepaspect"),
        _ => {}
    }
    o
}

fn is_mpvpaper_name(n: &str) -> bool {
    let n = n.trim();
    n == "mpvpaper" || n == ".mpvpaper-wrapped"
}

pub fn mpvpaper_pids() -> Vec<u32> {
    let me = std::process::id();
    let parent = std::os::unix::process::parent_id();
    let mut v = Vec::new();
    if let Ok(entries) = std::fs::read_dir("/proc") {
        for e in entries.filter_map(|x| x.ok()) {
            let name = e.file_name().to_string_lossy().to_string();
            if !name.chars().all(|c| c.is_ascii_digit()) {
                continue;
            }
            if let Ok(pid) = name.parse::<u32>() {
                if pid == me || pid == parent {
                    continue;
                }
                let hit_comm = std::fs::read_to_string(format!("/proc/{}/comm", pid))
                    .map(|c| is_mpvpaper_name(&c))
                    .unwrap_or(false);
                let hit_cmd = std::fs::read(format!("/proc/{}/cmdline", pid))
                    .map(|b| {
                        let first = b.split(|x| *x == 0).next().unwrap_or(&[]);
                        let argv0 = String::from_utf8_lossy(first).to_string();
                        let base = argv0.rsplit('/').next().unwrap_or("").to_string();
                        is_mpvpaper_name(&base)
                    })
                    .unwrap_or(false);
                if hit_comm || hit_cmd {
                    v.push(pid);
                }
            }
        }
    }
    v
}

pub fn rss_of(pids: &[u32]) -> u64 {
    let mut total_kb: u64 = 0;
    for pid in pids {
        if let Ok(text) = std::fs::read_to_string(format!("/proc/{}/status", pid)) {
            for line in text.lines() {
                if line.starts_with("VmRSS:") {
                    let digits: String = line.chars().filter(|c| c.is_ascii_digit()).collect();
                    if let Ok(kb) = digits.parse::<u64>() {
                        total_kb += kb;
                    }
                }
            }
        }
    }
    total_kb / 1024
}

pub fn rss_mb() -> u64 {
    let mut all = mpvpaper_pids();
    all.extend(crate::layerbg::pids());
    rss_of(&all)
}

pub fn is_pid_stopped(pid: u32) -> bool {
    if let Ok(text) = std::fs::read_to_string(format!("/proc/{}/status", pid)) {
        for line in text.lines() {
            if line.starts_with("State:") {
                return line.contains('T');
            }
        }
    }
    false
}

fn spawn_detached(output: &str, file: &str, opts: &str, layer: &str) -> Result<u32, String> {
    let sock = crate::ipc::socket_for(output);
    let _ = std::fs::remove_file(&sock);
    let bin = mpvpaper_bin();
    let mut cmd = Command::new(&bin);
    cmd.arg("-l")
        .arg(layer)
        .arg("-o")
        .arg(format!("{} --input-ipc-server={}", opts, sock.display()))
        .arg(output)
        .arg(file)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null());
    #[cfg(unix)]
    {
        use std::os::unix::process::CommandExt;
        unsafe {
            cmd.pre_exec(|| {
                libc::setsid();
                libc::signal(libc::SIGHUP, libc::SIG_IGN);
                Ok(())
            });
        }
    }
    let mut child = cmd.spawn().map_err(|e| {
        if e.kind() == std::io::ErrorKind::NotFound {
            String::from("falta mpvpaper instala mpv ffmpeg")
        } else {
            format!("spawn {}", e)
        }
    })?;
    std::thread::sleep(std::time::Duration::from_millis(60));
    match child.try_wait().map_err(|e| e.to_string())? {
        Some(st) => Err(format!("mpvpaper salio {:?}", st.code())),
        None => Ok(child.id()),
    }
}

fn apply_scaling(sock: &std::path::Path, scaling: &str) {
    match scaling {
        "fill" => {
            let _ = crate::ipc::set_prop(sock, "panscan", 1.0f32);
            let _ = crate::ipc::set_prop(sock, "keepaspect", true);
        }
        "stretch" => {
            let _ = crate::ipc::set_prop(sock, "panscan", 0.0f32);
            let _ = crate::ipc::set_prop(sock, "keepaspect", false);
        }
        _ => {
            let _ = crate::ipc::set_prop(sock, "panscan", 0.0f32);
            let _ = crate::ipc::set_prop(sock, "keepaspect", true);
        }
    }
}

pub fn apply_video(
    output: &str,
    file: &str,
    scaling: &str,
    mute: bool,
    volume: u8,
    hwdec: &str,
    layer: &str,
    tr: &crate::transition::Transition,
) -> Result<u32, String> {
    let pid = apply_video_inner(output, file, scaling, mute, volume, hwdec, layer, tr)?;
    // mpv ya pinta: bajar la capa estatica que quedo debajo
    if output == "*" {
        crate::layerbg::stop_all();
    } else {
        crate::layerbg::stop_output(output);
    }
    Ok(pid)
}

fn apply_video_inner(
    output: &str,
    file: &str,
    scaling: &str,
    mute: bool,
    volume: u8,
    hwdec: &str,
    layer: &str,
    tr: &crate::transition::Transition,
) -> Result<u32, String> {
    let tr = tr.resolved();
    if output == "*" {
        for sock in crate::ipc::discover() {
            let out = crate::ipc::output_for_socket(&sock);
            if out != "*" {
                crate::ipc::quit(&sock);
                let _ = std::fs::remove_file(&sock);
            }
        }
    } else {
        let wild = crate::ipc::socket_for("*");
        if crate::ipc::is_alive(&wild) {
            crate::ipc::quit(&wild);
            let _ = std::fs::remove_file(&wild);
        }
    }
    let sock = crate::ipc::socket_for(output);
    if crate::ipc::is_alive(&sock) {
        let _ = crate::ipc::set_prop(&sock, "mute", mute);
        let _ = crate::ipc::set_prop(&sock, "volume", volume.min(100));
        let _ = crate::ipc::set_prop(&sock, "pause", false);
        apply_scaling(&sock, scaling);
        crate::transition::video_out(&sock, &tr);
        if crate::ipc::loadfile(&sock, file).is_ok() {
            if tr.enabled() {
                std::thread::sleep(std::time::Duration::from_millis(120));
                crate::transition::video_in(&sock, &tr);
            }
            if let Some(pid) = crate::ipc::get_u64(&sock, "pid") {
                return Ok(pid as u32);
            }
            return Ok(0);
        }
        crate::transition::video_reset(&sock);
    }
    let mut opts = build_opts(scaling, mute, volume, hwdec);
    opts.push_str(&crate::transition::video_intro_opts(&tr));
    let pid = spawn_detached(output, file, &opts, layer)?;
    if tr.enabled() && crate::transition::wait_socket(&sock, 3000) {
        crate::transition::video_in(&sock, &tr);
    }
    Ok(pid)
}

pub fn stop_output(output: &str) {
    crate::layerbg::stop_output(output);
    stop_mpv_output(output);
}

fn stop_mpv_output(output: &str) {
    let sock = crate::ipc::socket_for(output);
    if crate::ipc::is_alive(&sock) {
        crate::ipc::quit(&sock);
    }
    let _ = std::fs::remove_file(&sock);
}

pub fn stop_all() {
    crate::layerbg::stop_all();
    for sock in crate::ipc::discover() {
        crate::ipc::quit(&sock);
        let _ = std::fs::remove_file(&sock);
    }
    let dir = crate::ipc::socket_dir();
    if let Ok(entries) = std::fs::read_dir(&dir) {
        for e in entries.filter_map(|x| x.ok()) {
            let p = e.path();
            if p.extension().and_then(|x| x.to_str()) == Some("sock") {
                let _ = std::fs::remove_file(&p);
            }
        }
    }
    for pid in mpvpaper_pids() {
        unsafe {
            libc::kill(pid as i32, libc::SIGTERM);
        }
    }
}

pub fn for_each_sock_alive<F: Fn(&PathBuf)>(f: F) {
    let mut socks = crate::ipc::discover();
    if socks.is_empty() {
        return;
    }
    socks.sort();
    for s in &socks {
        f(s);
    }
}

pub fn set_volume_all(volume: u8) {
    for_each_sock_alive(|s| {
        let _ = crate::ipc::set_prop(s, "volume", volume.min(100));
    });
}

pub fn set_mute_all(mute: bool) {
    for_each_sock_alive(|s| {
        let _ = crate::ipc::set_prop(s, "mute", mute);
    });
}

pub fn pause_all() {
    for_each_sock_alive(|s| {
        let _ = crate::ipc::set_prop(s, "pause", true);
    });
    for pid in mpvpaper_pids() {
        unsafe {
            libc::kill(pid as i32, libc::SIGSTOP);
        }
    }
}

pub fn resume_all() {
    for pid in mpvpaper_pids() {
        unsafe {
            libc::kill(pid as i32, libc::SIGCONT);
        }
    }
    for_each_sock_alive(|s| {
        let _ = crate::ipc::set_prop(s, "pause", false);
    });
}

pub fn toggle_all() -> bool {
    let socks = crate::ipc::discover();
    let mut toggled = false;
    let mut now_paused = false;
    for s in &socks {
        if let Ok(p) = crate::ipc::cycle_pause(s) {
            toggled = true;
            now_paused = p;
        }
    }
    if toggled {
        return now_paused;
    }
    let pids = mpvpaper_pids();
    if pids.is_empty() {
        return false;
    }
    let stopped = pids.iter().any(|p| is_pid_stopped(*p));
    if stopped {
        resume_all();
        false
    } else {
        pause_all();
        true
    }
}

pub fn paused_state() -> bool {
    for s in crate::ipc::discover() {
        if let Some(p) = crate::ipc::get_bool(&s, "pause") {
            if p {
                return true;
            }
        }
    }
    let pids = mpvpaper_pids();
    !pids.is_empty() && pids.iter().all(|p| is_pid_stopped(*p))
}

fn which(bin: &str) -> bool {
    std::env::var_os("PATH")
        .map(|p| std::env::split_paths(&p).any(|d| d.join(bin).is_file()))
        .unwrap_or(false)
}

fn run_quiet(bin: &str, args: &[&str]) -> bool {
    Command::new(bin)
        .args(args)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .map(|s| s.success())
        .unwrap_or(false)
}

fn release(output: &str) {
    if output == "*" {
        stop_all();
        return;
    }
    let wild = crate::ipc::socket_for("*");
    if crate::ipc::is_alive(&wild) {
        crate::ipc::quit(&wild);
        let _ = std::fs::remove_file(&wild);
    }
    stop_output(output);
}

/// Baja solo mpv/mpvpaper de esa salida (la capa estatica nueva ya pinta).
fn release_video(output: &str) {
    if output == "*" {
        for sock in crate::ipc::discover() {
            crate::ipc::quit(&sock);
            let _ = std::fs::remove_file(&sock);
        }
        for pid in mpvpaper_pids() {
            unsafe {
                libc::kill(pid as i32, libc::SIGTERM);
            }
        }
        return;
    }
    let wild = crate::ipc::socket_for("*");
    if crate::ipc::is_alive(&wild) {
        crate::ipc::quit(&wild);
        let _ = std::fs::remove_file(&wild);
    }
    stop_mpv_output(output);
}

fn try_awww(output: &str, file: &str, scaling: &str, tr: &crate::transition::Transition) -> bool {
    let resize = if scaling == "fill" { "crop" } else { "fit" };
    let tr_args = tr.awww_args();
    for bin in ["awww", "swww"] {
        if !which(bin) {
            continue;
        }
        let mut args: Vec<&str> = vec!["img", "--resize", resize];
        if output != "*" {
            args.push("--outputs");
            args.push(output);
        }
        for a in &tr_args {
            args.push(a.as_str());
        }
        args.push(file);
        if run_quiet(bin, &args) {
            return true;
        }
        // el demonio no estaba arriba: levantarlo y reintentar una vez
        let daemon = format!("{}-daemon", bin);
        if which(&daemon) {
            let _ = Command::new(&daemon)
                .stdin(Stdio::null())
                .stdout(Stdio::null())
                .stderr(Stdio::null())
                .spawn();
            for _ in 0..10 {
                std::thread::sleep(std::time::Duration::from_millis(150));
                if run_quiet(bin, &args) {
                    return true;
                }
            }
        }
    }
    false
}

pub fn apply_static(
    output: &str,
    file: &str,
    scaling: &str,
    mute: bool,
    volume: u8,
    hwdec: &str,
    layer: &str,
    tr: &crate::transition::Transition,
) -> Result<u32, String> {
    let backend = crate::config::Config::load().static_backend;
    let may_awww = (backend == "auto" || backend == "awww") && scaling != "stretch";
    let may_builtin = backend == "auto" || backend == "awww" || backend == "builtin";
    if may_awww && try_awww(output, file, scaling, tr) {
        release(output);
        return Ok(0);
    }
    if may_builtin {
        let _ = layer;
        match crate::layerbg::spawn(output, file, scaling, "background", tr) {
            Ok(pid) => {
                release_video(output);
                return Ok(pid);
            }
            Err(e) => {
                if backend == "builtin" {
                    return Err(e);
                }
                eprintln!("capa propia fallo ({}), usando mpvpaper", e);
            }
        }
    }
    apply_video(output, file, scaling, mute, volume, hwdec, layer, &crate::transition::Transition::none())
}
