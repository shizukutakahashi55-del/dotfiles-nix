// SECCION: LAYERBG CAPA WAYLAND PROPIA PARA IMAGENES ESTATICAS
// IPC: __bg (proceso hijo) pidfile bg_<salida>.bgpid socket bg_<salida>.bgsock comando SET handshake "ready" por stdout
use std::collections::HashMap;
use std::io::{BufRead, BufReader, Write};
use std::os::unix::net::{UnixListener, UnixStream};
use std::os::fd::{AsFd, FromRawFd, OwnedFd};
use std::path::PathBuf;
use std::process::{Command, Stdio};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::{Duration, Instant};

use wayland_client::globals::{registry_queue_init, GlobalListContents};
use wayland_client::protocol::{
    wl_buffer, wl_callback, wl_compositor, wl_output, wl_region, wl_registry, wl_shm, wl_shm_pool, wl_surface,
};
use wayland_client::{Connection, Dispatch, QueueHandle};
use wayland_protocols_wlr::layer_shell::v1::client::{zwlr_layer_shell_v1, zwlr_layer_surface_v1};

// ---------------------------------------------------------------- lado padre

fn pidfile_for(output: &str) -> PathBuf {
    let clean: String = output
        .chars()
        .filter(|c| c.is_alphanumeric() || *c == '-' || *c == '_')
        .collect();
    let name = if output == "*" || clean.is_empty() {
        String::from("all")
    } else {
        clean
    };
    crate::ipc::socket_dir().join(format!("bg_{}.bgpid", name))
}

fn bgsock_for(output: &str) -> PathBuf {
    pidfile_for(output).with_extension("bgsock")
}

fn switch_running(
    output: &str,
    file: &str,
    scaling: &str,
    tr: &crate::transition::Transition,
) -> Option<u32> {
    if !crate::engine::mpvpaper_pids().is_empty() {
        return None;
    }
    let pid = read_pid(&pidfile_for(output)).filter(|p| is_bg_process(*p))?;
    let mut stream = UnixStream::connect(bgsock_for(output)).ok()?;
    stream.set_read_timeout(Some(Duration::from_secs(5))).ok()?;
    stream.set_write_timeout(Some(Duration::from_secs(2))).ok()?;
    let r = tr.resolved();
    let kind = if r.enabled() { r.kind.clone() } else { String::from("none") };
    let msg = format!("SET\t{}\t{}\t{}\t{}\n", kind, r.ms, scaling, file);
    stream.write_all(msg.as_bytes()).ok()?;
    let mut line = String::new();
    BufReader::new(stream).read_line(&mut line).ok()?;
    if line.trim() == "ok" {
        Some(pid)
    } else {
        None
    }
}

fn read_pid(p: &std::path::Path) -> Option<u32> {
    std::fs::read_to_string(p).ok()?.trim().parse().ok()
}

fn is_bg_process(pid: u32) -> bool {
    std::fs::read(format!("/proc/{}/cmdline", pid))
        .map(|b| String::from_utf8_lossy(&b).contains("__bg"))
        .unwrap_or(false)
}

/// PIDs vivos de capas estaticas (todas las salidas).
pub fn pids() -> Vec<u32> {
    let mut v = Vec::new();
    if let Ok(rd) = std::fs::read_dir(crate::ipc::socket_dir()) {
        for e in rd.filter_map(|x| x.ok()) {
            let p = e.path();
            if p.extension().and_then(|x| x.to_str()) != Some("bgpid") {
                continue;
            }
            match read_pid(&p) {
                Some(pid) if is_bg_process(pid) => v.push(pid),
                _ => {
                    let _ = std::fs::remove_file(&p);
                }
            }
        }
    }
    v
}

fn kill_pidfile(p: &std::path::Path, except: Option<u32>) {
    if let Some(pid) = read_pid(p) {
        if Some(pid) != except && is_bg_process(pid) {
            unsafe {
                libc::kill(pid as i32, libc::SIGTERM);
            }
        }
        if Some(pid) != except {
            let _ = std::fs::remove_file(p);
        }
    } else {
        let _ = std::fs::remove_file(p);
    }
}

/// Baja la capa de una salida (y la "*" si aplica).
pub fn stop_output(output: &str) {
    kill_pidfile(&pidfile_for(output), None);
    if output != "*" {
        kill_pidfile(&pidfile_for("*"), None);
    }
}

pub fn stop_all() {
    if let Ok(rd) = std::fs::read_dir(crate::ipc::socket_dir()) {
        for e in rd.filter_map(|x| x.ok()) {
            let p = e.path();
            if p.extension().and_then(|x| x.to_str()) == Some("bgpid") {
                kill_pidfile(&p, None);
            }
        }
    }
}

fn cli_bin() -> std::ffi::OsString {
    if let Ok(exe) = std::env::current_exe() {
        if exe.file_name().and_then(|n| n.to_str()) == Some("oozewalls") {
            return exe.into_os_string();
        }
        if let Some(parent) = exe.parent() {
            let sib = parent.join("oozewalls");
            if sib.is_file() {
                return sib.into_os_string();
            }
        }
    }
    if let Ok(home) = std::env::var("HOME") {
        let p = PathBuf::from(home).join(".local/bin/oozewalls");
        if p.is_file() {
            return p.into_os_string();
        }
    }
    String::from("oozewalls").into()
}

fn previous_image(output: &str, new_file: &str) -> Option<String> {
    let cfg = crate::config::Config::load();
    let path = cfg
        .wallpapers
        .get(output)
        .or_else(|| cfg.wallpapers.get("*"))
        .or_else(|| cfg.wallpapers.values().next())
        .or(cfg.current.as_ref())?
        .clone();
    if path == new_file {
        return None;
    }
    let p = std::path::Path::new(&path);
    if !p.is_file() {
        return None;
    }
    if crate::scan::is_video_path(p) {
        return crate::thumbs::ensure(&path, true).map(|x| x.to_string_lossy().to_string());
    }
    Some(path)
}

/// Lanza la capa y espera a que pinte el primer frame. Luego baja las capas
/// previas que quedan tapadas (sin parpadeo). Devuelve el pid.
pub fn spawn(
    output: &str,
    file: &str,
    scaling: &str,
    layer: &str,
    tr: &crate::transition::Transition,
) -> Result<u32, String> {
    if let Some(pid) = switch_running(output, file, scaling, tr) {
        return Ok(pid);
    }
    let pf = pidfile_for(output);
    let had_prev = !pids().is_empty() || !crate::engine::mpvpaper_pids().is_empty();
    let old_image = if had_prev && tr.enabled() {
        previous_image(output, file)
    } else {
        None
    };
    let tr = if old_image.is_some() {
        tr.resolved()
    } else {
        crate::transition::Transition::none()
    };
    let mut cmd = Command::new(cli_bin());
    cmd.arg("__bg")
        .arg(output)
        .arg(file)
        .arg(scaling)
        .arg(layer)
        .arg(&tr.kind)
        .arg(tr.ms.to_string())
        .arg(old_image.unwrap_or_else(|| String::from("-")))
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::null());
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
    let mut child = cmd.spawn().map_err(|e| format!("spawn capa {}", e))?;
    let pid = child.id();
    let out = child.stdout.take();
    let (ltx, lrx) = std::sync::mpsc::channel();
    if let Some(out) = out {
        std::thread::spawn(move || {
            let mut line = String::new();
            let _ = BufReader::new(out).read_line(&mut line);
            let _ = ltx.send(line);
        });
    }
    let line = lrx.recv_timeout(Duration::from_secs(12)).unwrap_or_default();
    if !line.trim().starts_with("ready") {
        let _ = child.kill();
        let _ = child.wait();
        let msg = line.trim().trim_start_matches("err").trim().to_string();
        return Err(if msg.is_empty() {
            String::from("capa salio sin pintar")
        } else {
            format!("capa: {}", msg)
        });
    }
    // recoger el zombie cuando la capa termine (el padre puede ser la GUI)
    std::thread::spawn(move || {
        let _ = child.wait();
    });
    // reemplazo: bajar lo que este debajo
    if output == "*" {
        stop_all_except(pid);
    } else {
        kill_pidfile(&pf, Some(pid));
        kill_pidfile(&pidfile_for("*"), Some(pid));
    }
    let _ = std::fs::write(&pf, pid.to_string());
    Ok(pid)
}

fn stop_all_except(keep: u32) {
    if let Ok(rd) = std::fs::read_dir(crate::ipc::socket_dir()) {
        for e in rd.filter_map(|x| x.ok()) {
            let p = e.path();
            if p.extension().and_then(|x| x.to_str()) == Some("bgpid") {
                kill_pidfile(&p, Some(keep));
            }
        }
    }
}

// ----------------------------------------------------------------- lado hijo

struct OutInfo {
    wl: wl_output::WlOutput,
    name: String,
    scale: i32,
    global: u32,
    removed: bool,
}

#[derive(Clone, Copy)]
struct BufData {
    surf: usize,
    id: u64,
}

struct SurfInfo {
    surface: wl_surface::WlSurface,
    layer: zwlr_layer_surface_v1::ZwlrLayerSurfaceV1,
    out: usize,
    size: (u32, u32),
    dirty: bool,
    drawn: bool,
    closed: bool,
    live: HashMap<u64, wl_buffer::WlBuffer>,
    next_id: u64,
}

struct State {
    compositor: wl_compositor::WlCompositor,
    shm: wl_shm::WlShm,
    shell: zwlr_layer_shell_v1::ZwlrLayerShellV1,
    outs: Vec<OutInfo>,
    surfs: Vec<SurfInfo>,
    wild: bool,
    file: String,
    scaling: String,
    layer: zwlr_layer_shell_v1::Layer,
    anim: Option<(String, u32)>,
    old_file: Option<String>,
}

impl State {
    fn add_surface(&mut self, qh: &QueueHandle<State>, out: usize) {
        let idx = self.surfs.len();
        let surface = self.compositor.create_surface(qh, ());
        let layer = self.shell.get_layer_surface(
            &surface,
            Some(&self.outs[out].wl),
            self.layer,
            String::from("oozewalls"),
            qh,
            idx,
        );
        layer.set_anchor(
            zwlr_layer_surface_v1::Anchor::Top
                | zwlr_layer_surface_v1::Anchor::Bottom
                | zwlr_layer_surface_v1::Anchor::Left
                | zwlr_layer_surface_v1::Anchor::Right,
        );
        layer.set_size(0, 0);
        layer.set_exclusive_zone(-1);
        layer.set_keyboard_interactivity(zwlr_layer_surface_v1::KeyboardInteractivity::None);
        let region = self.compositor.create_region(qh, ());
        surface.set_input_region(Some(&region));
        region.destroy();
        surface.commit();
        self.surfs.push(SurfInfo {
            surface,
            layer,
            out,
            size: (0, 0),
            dirty: false,
            drawn: false,
            closed: false,
            live: HashMap::new(),
            next_id: 0,
        });
    }

    fn bind_output(
        &mut self,
        registry: &wl_registry::WlRegistry,
        name: u32,
        version: u32,
        qh: &QueueHandle<State>,
    ) -> usize {
        let idx = self.outs.len();
        let wl: wl_output::WlOutput = registry.bind(name, version.min(4), qh, idx);
        self.outs.push(OutInfo {
            wl,
            name: String::new(),
            scale: 1,
            global: name,
            removed: false,
        });
        idx
    }
}

// ------------------------------------------------------------- BLOQUE: SHM

fn decode_scaled(file: &str, scaling: &str, pw: u32, ph: u32) -> Result<image::RgbImage, String> {
    use image::imageops::FilterType;
    let img = image::open(file).map_err(|e| format!("decodificar {}", e))?;
    let rgb = match scaling {
        "fill" => img.resize_to_fill(pw, ph, FilterType::Lanczos3).to_rgb8(),
        "stretch" => img.resize_exact(pw, ph, FilterType::Lanczos3).to_rgb8(),
        _ => img.resize(pw, ph, FilterType::Lanczos3).to_rgb8(),
    };
    Ok(rgb)
}

fn blit_bgrx(dst: &mut [u8], rgb: &image::RgbImage, pw: usize, ph: usize) {
    let stride = pw * 4;
    let (rw, rh) = (rgb.width() as usize, rgb.height() as usize);
    let (cw, ch) = (rw.min(pw), rh.min(ph));
    let (ox, oy) = ((pw - cw) / 2, (ph - ch) / 2);
    let src = rgb.as_raw();
    for y in 0..ch {
        let drow = (y + oy) * stride + ox * 4;
        let srow = y * rw * 3;
        for x in 0..cw {
            let d = drow + x * 4;
            let s = srow + x * 3;
            dst[d] = src[s + 2];
            dst[d + 1] = src[s + 1];
            dst[d + 2] = src[s];
            dst[d + 3] = 255;
        }
    }
    if cw < pw || ch < ph {
        for px in dst.chunks_exact_mut(4) {
            px[3] = 255;
        }
    }
}

fn shm_buffer<F: FnOnce(&mut [u8])>(
    shm: &wl_shm::WlShm,
    qh: &QueueHandle<State>,
    pw: u32,
    ph: u32,
    format: wl_shm::Format,
    data: BufData,
    fill: F,
) -> Result<wl_buffer::WlBuffer, String> {
    let stride = pw as usize * 4;
    let size = stride * ph as usize;
    let fd = unsafe {
        let raw = libc::memfd_create(
            b"oozewalls\0".as_ptr() as *const libc::c_char,
            libc::MFD_CLOEXEC,
        );
        if raw < 0 {
            return Err(String::from("memfd_create fallo"));
        }
        OwnedFd::from_raw_fd(raw)
    };
    let rc = unsafe { libc::ftruncate(std::os::fd::AsRawFd::as_raw_fd(&fd), size as libc::off_t) };
    if rc != 0 {
        return Err(String::from("ftruncate fallo"));
    }
    unsafe {
        let map = libc::mmap(
            std::ptr::null_mut(),
            size,
            libc::PROT_READ | libc::PROT_WRITE,
            libc::MAP_SHARED,
            std::os::fd::AsRawFd::as_raw_fd(&fd),
            0,
        );
        if map == libc::MAP_FAILED {
            return Err(String::from("mmap fallo"));
        }
        let dst = std::slice::from_raw_parts_mut(map as *mut u8, size);
        fill(dst);
        libc::munmap(map, size);
    }
    let pool = shm.create_pool(fd.as_fd(), size as i32, qh, ());
    let buf = pool.create_buffer(0, pw as i32, ph as i32, stride as i32, format, qh, data);
    pool.destroy();
    Ok(buf)
}

fn render_buffer(
    shm: &wl_shm::WlShm,
    qh: &QueueHandle<State>,
    file: &str,
    scaling: &str,
    pw: u32,
    ph: u32,
    data: BufData,
) -> Result<wl_buffer::WlBuffer, String> {
    let rgb = decode_scaled(file, scaling, pw, ph)?;
    shm_buffer(shm, qh, pw, ph, wl_shm::Format::Xrgb8888, data, |dst| {
        blit_bgrx(dst, &rgb, pw as usize, ph as usize)
    })
}

// ------------------------------------------------------ BLOQUE: TRANSICION

struct Job {
    idx: usize,
    pw: u32,
    ph: u32,
    scale: u32,
    old: Vec<u8>,
    new: Vec<u8>,
}

struct Cmd {
    kind: String,
    ms: u32,
    scaling: String,
    file: String,
    reply: UnixStream,
}

fn first_draw_targets(state: &State) -> Vec<usize> {
    (0..state.surfs.len())
        .filter(|&i| {
            let s = &state.surfs[i];
            s.dirty && !s.drawn && !s.closed && s.size.0 > 0 && s.size.1 > 0
        })
        .collect()
}

fn drawn_targets(state: &State) -> Vec<usize> {
    (0..state.surfs.len())
        .filter(|&i| {
            let s = &state.surfs[i];
            s.drawn && !s.closed && s.size.0 > 0 && s.size.1 > 0
        })
        .collect()
}

fn compose_base(file: &str, scaling: &str, pw: u32, ph: u32) -> Result<Vec<u8>, String> {
    let rgb = decode_scaled(file, scaling, pw, ph)?;
    let mut base = vec![0u8; pw as usize * ph as usize * 4];
    blit_bgrx(&mut base, &rgb, pw as usize, ph as usize);
    Ok(base)
}

fn black_base(pw: u32, ph: u32) -> Vec<u8> {
    let mut base = vec![0u8; pw as usize * ph as usize * 4];
    for px in base.chunks_exact_mut(4) {
        px[3] = 255;
    }
    base
}

fn build_jobs(
    state: &State,
    idxs: &[usize],
    old_file: &str,
    old_scaling: &str,
) -> Result<Vec<Job>, String> {
    let mut jobs: Vec<Job> = Vec::new();
    for &i in idxs {
        let (w, h) = state.surfs[i].size;
        let scale = state.outs[state.surfs[i].out].scale.max(1) as u32;
        let (pw, ph) = (w * scale, h * scale);
        let (old, new) = std::thread::scope(|sc| {
            let old_h = sc.spawn(|| compose_base(old_file, old_scaling, pw, ph));
            let new = compose_base(&state.file, &state.scaling, pw, ph);
            let old = old_h
                .join()
                .ok()
                .and_then(|r| r.ok())
                .unwrap_or_else(|| black_base(pw, ph));
            (old, new)
        });
        jobs.push(Job {
            idx: i,
            pw,
            ph,
            scale,
            old,
            new: new?,
        });
    }
    Ok(jobs)
}

fn next_buf_data(state: &mut State, idx: usize) -> BufData {
    let s = &mut state.surfs[idx];
    let id = s.next_id;
    s.next_id = s.next_id.wrapping_add(1);
    BufData { surf: idx, id }
}

fn finish_frame(
    state: &mut State,
    idx: usize,
    pw: u32,
    ph: u32,
    scale: i32,
    data: BufData,
    buf: wl_buffer::WlBuffer,
) {
    let s = &mut state.surfs[idx];
    s.surface.set_buffer_scale(scale);
    s.surface.attach(Some(&buf), 0, 0);
    s.surface.damage_buffer(0, 0, pw as i32, ph as i32);
    s.surface.commit();
    s.live.insert(data.id, buf);
}

fn commit_frame(
    state: &mut State,
    qh: &QueueHandle<State>,
    job: &Job,
    kind: &str,
    t: f32,
) -> Result<(), String> {
    let data = next_buf_data(state, job.idx);
    let buf = shm_buffer(
        &state.shm,
        qh,
        job.pw,
        job.ph,
        wl_shm::Format::Xrgb8888,
        data,
        |dst| {
            crate::transition::frame_into(
                dst,
                &job.old,
                &job.new,
                job.pw as usize,
                job.ph as usize,
                kind,
                t,
            )
        },
    )?;
    finish_frame(
        state,
        job.idx,
        job.pw,
        job.ph,
        job.scale as i32,
        data,
        buf,
    );
    Ok(())
}

fn announce_ready(ready: &Arc<AtomicBool>) {
    if !ready.swap(true, Ordering::SeqCst) {
        println!("ready");
        let _ = std::io::stdout().flush();
    }
}

fn animate_jobs(
    state: &mut State,
    qh: &QueueHandle<State>,
    conn: &Connection,
    queue: &mut wayland_client::EventQueue<State>,
    jobs: &[Job],
    kind: &str,
    ms: u32,
) -> Result<(), String> {
    let total = Duration::from_millis(ms as u64);
    let step = Duration::from_micros(16_666);
    let start = Instant::now();
    loop {
        let el = start.elapsed();
        if el >= total {
            break;
        }
        let t = el.as_secs_f32() / total.as_secs_f32();
        for job in jobs {
            commit_frame(state, qh, job, kind, t)?;
        }
        conn.flush().map_err(|e| format!("flush {}", e))?;
        queue
            .dispatch_pending(state)
            .map_err(|e| format!("dispatch {}", e))?;
        let spent = start.elapsed() - el;
        if spent < step {
            std::thread::sleep(step - spent);
        }
    }
    for job in jobs {
        commit_frame(state, qh, job, kind, 1.0)?;
    }
    conn.flush().map_err(|e| format!("flush {}", e))?;
    queue
        .dispatch_pending(state)
        .map_err(|e| format!("dispatch {}", e))?;
    Ok(())
}

fn play_transition(
    state: &mut State,
    qh: &QueueHandle<State>,
    conn: &Connection,
    queue: &mut wayland_client::EventQueue<State>,
    idxs: &[usize],
    kind: &str,
    ms: u32,
    ready: &Arc<AtomicBool>,
) -> Result<(), String> {
    let old_file = state.old_file.clone().unwrap_or_default();
    let old_scaling = state.scaling.clone();
    let jobs = build_jobs(state, idxs, &old_file, &old_scaling)?;
    for job in &jobs {
        commit_frame(state, qh, job, kind, 0.0)?;
    }
    conn.flush().map_err(|e| format!("flush {}", e))?;
    announce_ready(ready);
    animate_jobs(state, qh, conn, queue, &jobs, kind, ms)?;
    for job in &jobs {
        let s = &mut state.surfs[job.idx];
        s.dirty = false;
        s.drawn = true;
    }
    Ok(())
}

fn switch_to(
    state: &mut State,
    qh: &QueueHandle<State>,
    conn: &Connection,
    queue: &mut wayland_client::EventQueue<State>,
    cmd: Cmd,
    ready: &Arc<AtomicBool>,
) -> Result<(), String> {
    let mut reply = cmd.reply;
    let prev_file = std::mem::replace(&mut state.file, cmd.file);
    let prev_scaling = std::mem::replace(&mut state.scaling, cmd.scaling);
    let kind = if crate::transition::is_valid(&cmd.kind) {
        cmd.kind
    } else {
        String::from("none")
    };
    let targets = drawn_targets(state);
    let animate = kind != "none" && cmd.ms > 0 && !targets.is_empty() && prev_file != state.file;
    if animate {
        match build_jobs(state, &targets, &prev_file, &prev_scaling) {
            Ok(jobs) => {
                let _ = reply.write_all(b"ok\n");
                let ms = crate::transition::clamp_ms(cmd.ms);
                animate_jobs(state, qh, conn, queue, &jobs, &kind, ms)?;
            }
            Err(e) => {
                state.file = prev_file;
                state.scaling = prev_scaling;
                let _ = reply.write_all(format!("err {}\n", e).as_bytes());
            }
        }
        return Ok(());
    }
    for s in state.surfs.iter_mut() {
        s.dirty = true;
    }
    let res = draw_pending(state, qh, conn, queue, ready);
    match &res {
        Ok(()) => {
            let _ = reply.write_all(b"ok\n");
        }
        Err(e) => {
            state.file = prev_file;
            state.scaling = prev_scaling;
            let _ = reply.write_all(format!("err {}\n", e).as_bytes());
        }
    }
    res
}

fn start_listener(
    output: &str,
    conn: Connection,
    qh: QueueHandle<State>,
) -> std::sync::mpsc::Receiver<Cmd> {
    let (tx, rx) = std::sync::mpsc::channel();
    let path = bgsock_for(output);
    let _ = std::fs::remove_file(&path);
    if let Ok(listener) = UnixListener::bind(&path) {
        std::thread::spawn(move || {
            for stream in listener.incoming().flatten() {
                let _ = stream.set_read_timeout(Some(Duration::from_secs(2)));
                let mut line = String::new();
                let read_ok = match stream.try_clone() {
                    Ok(c) => BufReader::new(c).read_line(&mut line).is_ok(),
                    Err(_) => false,
                };
                if !read_ok {
                    continue;
                }
                let parts: Vec<&str> = line.trim_end_matches('\n').splitn(5, '\t').collect();
                if parts.len() != 5 || parts[0] != "SET" {
                    continue;
                }
                let _ = stream.set_read_timeout(None);
                let cmd = Cmd {
                    kind: parts[1].to_string(),
                    ms: parts[2].parse().unwrap_or(0),
                    scaling: parts[3].to_string(),
                    file: parts[4].to_string(),
                    reply: stream,
                };
                if tx.send(cmd).is_err() {
                    break;
                }
                let _ = conn.display().sync(&qh, ());
                let _ = conn.flush();
            }
        });
    }
    rx
}

fn draw_pending(
    state: &mut State,
    qh: &QueueHandle<State>,
    conn: &Connection,
    queue: &mut wayland_client::EventQueue<State>,
    ready: &Arc<AtomicBool>,
) -> Result<(), String> {
    if state.anim.is_some() && !first_draw_targets(state).is_empty() {
        let targets = first_draw_targets(state);
        if let Some((kind, ms)) = state.anim.take() {
            if !targets.is_empty() {
                play_transition(state, qh, conn, queue, &targets, &kind, ms, ready)?;
            }
        }
    }
    for i in 0..state.surfs.len() {
        let (w, h) = state.surfs[i].size;
        if !state.surfs[i].dirty || state.surfs[i].closed || w == 0 || h == 0 {
            continue;
        }
        let scale = state.outs[state.surfs[i].out].scale.max(1) as u32;
        let (pw, ph) = (w * scale, h * scale);
        let data = next_buf_data(state, i);
        let buf = render_buffer(
            &state.shm,
            qh,
            &state.file,
            &state.scaling,
            pw,
            ph,
            data,
        )?;
        finish_frame(state, i, pw, ph, scale as i32, data, buf);
        state.surfs[i].dirty = false;
        state.surfs[i].drawn = true;
    }
    Ok(())
}

pub fn run(args: &[String]) -> i32 {
    let output = args.get(2).cloned().unwrap_or_else(|| String::from("*"));
    let file = args.get(3).cloned().unwrap_or_default();
    let scaling = args.get(4).cloned().unwrap_or_else(|| String::from("fit"));
    let layer_name = args
        .get(5)
        .cloned()
        .unwrap_or_else(|| String::from("background"));
    let kind = args
        .get(6)
        .cloned()
        .unwrap_or_else(|| String::from("none"));
    let ms: u32 = args.get(7).and_then(|v| v.parse().ok()).unwrap_or(0);
    let old_file = args
        .get(8)
        .cloned()
        .filter(|v| v != "-" && !v.is_empty());
    let anim = if kind != "none"
        && ms > 0
        && old_file.is_some()
        && crate::transition::is_valid(&kind)
    {
        Some((kind, crate::transition::clamp_ms(ms)))
    } else {
        None
    };

    let ready = Arc::new(AtomicBool::new(false));
    {
        let ready = ready.clone();
        std::thread::spawn(move || {
            std::thread::sleep(Duration::from_secs(10));
            if !ready.load(Ordering::SeqCst) {
                println!("err sin respuesta del compositor");
                let _ = std::io::stdout().flush();
                std::process::exit(1);
            }
        });
    }

    match run_inner(&output, &file, &scaling, &layer_name, anim, old_file, &ready) {
        Ok(()) => 0,
        Err(e) => {
            if !ready.load(Ordering::SeqCst) {
                println!("err {}", e);
                let _ = std::io::stdout().flush();
            } else {
                eprintln!("capa: {}", e);
            }
            1
        }
    }
}

fn run_inner(
    output: &str,
    file: &str,
    scaling: &str,
    layer_name: &str,
    anim: Option<(String, u32)>,
    old_file: Option<String>,
    ready: &Arc<AtomicBool>,
) -> Result<(), String> {
    let conn = Connection::connect_to_env().map_err(|e| format!("wayland {}", e))?;
    let (globals, mut queue) =
        registry_queue_init::<State>(&conn).map_err(|e| format!("registry {}", e))?;
    let qh = queue.handle();

    let compositor: wl_compositor::WlCompositor = globals
        .bind(&qh, 3..=6, ())
        .map_err(|_| String::from("falta wl_compositor"))?;
    let shm: wl_shm::WlShm = globals
        .bind(&qh, 1..=1, ())
        .map_err(|_| String::from("falta wl_shm"))?;
    let shell: zwlr_layer_shell_v1::ZwlrLayerShellV1 = globals
        .bind(&qh, 1..=4, ())
        .map_err(|_| String::from("el compositor no ofrece wlr-layer-shell"))?;

    let layer = match layer_name {
        "bottom" => zwlr_layer_shell_v1::Layer::Bottom,
        "top" => zwlr_layer_shell_v1::Layer::Top,
        "overlay" => zwlr_layer_shell_v1::Layer::Overlay,
        _ => zwlr_layer_shell_v1::Layer::Background,
    };

    let mut state = State {
        compositor,
        shm,
        shell,
        outs: Vec::new(),
        surfs: Vec::new(),
        wild: output == "*",
        file: file.to_string(),
        scaling: scaling.to_string(),
        layer,
        anim,
        old_file,
    };

    let found: Vec<(u32, u32)> = globals.contents().with_list(|l| {
        l.iter()
            .filter(|g| g.interface == "wl_output")
            .map(|g| (g.name, g.version))
            .collect()
    });
    for (name, ver) in found {
        state.bind_output(globals.registry(), name, ver, &qh);
    }
    // nombres y escalas llegan tras el bind
    queue
        .roundtrip(&mut state)
        .map_err(|e| format!("roundtrip {}", e))?;

    let targets: Vec<usize> = (0..state.outs.len())
        .filter(|&i| {
            !state.outs[i].removed && (state.wild || state.outs[i].name == output)
        })
        .collect();
    if targets.is_empty() {
        return Err(format!("salida {} no encontrada", output));
    }
    for i in targets {
        state.add_surface(&qh, i);
    }

    let rx = start_listener(output, conn.clone(), qh.clone());

    loop {
        queue
            .blocking_dispatch(&mut state)
            .map_err(|e| format!("dispatch {}", e))?;
        draw_pending(&mut state, &qh, &conn, &mut queue, ready)?;
        if !ready.load(Ordering::SeqCst)
            && !state.surfs.is_empty()
            && state.surfs.iter().all(|s| s.drawn)
        {
            ready.store(true, Ordering::SeqCst);
            println!("ready");
            let _ = std::io::stdout().flush();
        }
        let mut latest: Option<Cmd> = None;
        while let Ok(c) = rx.try_recv() {
            if let Some(mut skipped) = latest.replace(c) {
                let _ = skipped.reply.write_all(b"ok\n");
            }
        }
        if let Some(c) = latest {
            switch_to(&mut state, &qh, &conn, &mut queue, c, ready)?;
        }
        if !state.surfs.is_empty() && state.surfs.iter().all(|s| s.closed) {
            return Ok(());
        }
    }
}

// ---------------------------------------------------------- dispatch wayland

impl Dispatch<wl_registry::WlRegistry, GlobalListContents> for State {
    fn event(
        state: &mut Self,
        registry: &wl_registry::WlRegistry,
        event: wl_registry::Event,
        _: &GlobalListContents,
        _: &Connection,
        qh: &QueueHandle<Self>,
    ) {
        // monitor nuevo: solo en modo "*"
        match event {
            wl_registry::Event::Global {
                name,
                interface,
                version,
            } => {
                if state.wild
                    && interface == "wl_output"
                    && !state.outs.iter().any(|o| o.global == name)
                {
                    let idx = state.bind_output(registry, name, version, qh);
                    state.add_surface(qh, idx);
                }
            }
            wl_registry::Event::GlobalRemove { name } => {
                if let Some(idx) = state
                    .outs
                    .iter()
                    .position(|o| o.global == name && !o.removed)
                {
                    state.outs[idx].removed = true;
                    for s in state.surfs.iter_mut().filter(|s| s.out == idx) {
                        if s.closed {
                            continue;
                        }
                        s.closed = true;
                        s.layer.destroy();
                        s.surface.destroy();
                        for (_, b) in s.live.drain() {
                            b.destroy();
                        }
                    }
                    let out = &state.outs[idx];
                    out.wl.release();
                }
            }
            _ => {}
        }
    }
}

impl Dispatch<wl_output::WlOutput, usize> for State {
    fn event(
        state: &mut Self,
        _: &wl_output::WlOutput,
        event: wl_output::Event,
        idx: &usize,
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
        match event {
            wl_output::Event::Name { name } => state.outs[*idx].name = name,
            wl_output::Event::Scale { factor } => {
                let f = factor.max(1);
                if state.outs[*idx].scale != f {
                    state.outs[*idx].scale = f;
                    for s in state.surfs.iter_mut().filter(|s| s.out == *idx) {
                        s.dirty = true;
                    }
                }
            }
            _ => {}
        }
    }
}

impl Dispatch<zwlr_layer_surface_v1::ZwlrLayerSurfaceV1, usize> for State {
    fn event(
        state: &mut Self,
        proxy: &zwlr_layer_surface_v1::ZwlrLayerSurfaceV1,
        event: zwlr_layer_surface_v1::Event,
        idx: &usize,
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
        match event {
            zwlr_layer_surface_v1::Event::Configure {
                serial,
                width,
                height,
            } => {
                proxy.ack_configure(serial);
                let s = &mut state.surfs[*idx];
                if s.size != (width, height) || !s.drawn {
                    s.size = (width, height);
                    s.dirty = true;
                }
            }
            zwlr_layer_surface_v1::Event::Closed => {
                let s = &mut state.surfs[*idx];
                s.closed = true;
                s.layer.destroy();
                s.surface.destroy();
                for (_, b) in s.live.drain() {
                    b.destroy();
                }
            }
            _ => {}
        }
    }
}

impl Dispatch<wl_callback::WlCallback, ()> for State {
    fn event(
        _: &mut Self,
        _: &wl_callback::WlCallback,
        _: wl_callback::Event,
        _: &(),
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
    }
}

impl Dispatch<wl_compositor::WlCompositor, ()> for State {
    fn event(
        _: &mut Self,
        _: &wl_compositor::WlCompositor,
        _: wl_compositor::Event,
        _: &(),
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
    }
}

impl Dispatch<wl_surface::WlSurface, ()> for State {
    fn event(
        _: &mut Self,
        _: &wl_surface::WlSurface,
        _: wl_surface::Event,
        _: &(),
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
    }
}

impl Dispatch<wl_region::WlRegion, ()> for State {
    fn event(
        _: &mut Self,
        _: &wl_region::WlRegion,
        _: wl_region::Event,
        _: &(),
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
    }
}

impl Dispatch<wl_shm::WlShm, ()> for State {
    fn event(
        _: &mut Self,
        _: &wl_shm::WlShm,
        _: wl_shm::Event,
        _: &(),
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
    }
}

impl Dispatch<wl_shm_pool::WlShmPool, ()> for State {
    fn event(
        _: &mut Self,
        _: &wl_shm_pool::WlShmPool,
        _: wl_shm_pool::Event,
        _: &(),
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
    }
}

impl Dispatch<wl_buffer::WlBuffer, BufData> for State {
    fn event(
        state: &mut Self,
        proxy: &wl_buffer::WlBuffer,
        event: wl_buffer::Event,
        data: &BufData,
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
        if let wl_buffer::Event::Release = event {
            if let Some(s) = state.surfs.get_mut(data.surf) {
                s.live.remove(&data.id);
            }
            proxy.destroy();
        }
    }
}

impl Dispatch<zwlr_layer_shell_v1::ZwlrLayerShellV1, ()> for State {
    fn event(
        _: &mut Self,
        _: &zwlr_layer_shell_v1::ZwlrLayerShellV1,
        _: zwlr_layer_shell_v1::Event,
        _: &(),
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
    }
}
