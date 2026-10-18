// SECCION: TRANSITION CATALOGO FRAMES AWWW MPV
// IPC: --transition --transition-duration --no-transition transitions set_property
use std::path::Path;
use std::time::{Duration, Instant};

// ---------------------------------------------------------------- CATALOGO

pub const KINDS: &[(&str, &str)] = &[
    ("none", "Sin animación"),
    ("fade", "Desvanecer"),
    ("slide-left", "Deslizar desde la izquierda"),
    ("slide-right", "Deslizar desde la derecha"),
    ("slide-up", "Deslizar desde arriba"),
    ("slide-down", "Deslizar desde abajo"),
    ("wipe-left", "Barrido desde la izquierda"),
    ("wipe-right", "Barrido desde la derecha"),
    ("wipe-up", "Barrido desde arriba"),
    ("wipe-down", "Barrido desde abajo"),
    ("circle", "Círculo desde el centro"),
    ("zoom", "Zoom con desvanecido"),
    ("blinds", "Persianas"),
    ("random", "Aleatoria"),
];

pub const DEFAULT_KIND: &str = "fade";
pub const DEFAULT_MS: u32 = 600;
pub const MIN_MS: u32 = 100;
pub const MAX_MS: u32 = 3000;

pub fn is_valid(kind: &str) -> bool {
    KINDS.iter().any(|(k, _)| *k == kind)
}

pub fn clamp_ms(ms: u32) -> u32 {
    ms.clamp(MIN_MS, MAX_MS)
}

pub fn label_of(kind: &str) -> &'static str {
    KINDS
        .iter()
        .find(|(k, _)| *k == kind)
        .map(|(_, l)| *l)
        .unwrap_or("Desvanecer")
}

fn concrete_kinds() -> Vec<&'static str> {
    KINDS
        .iter()
        .map(|(k, _)| *k)
        .filter(|k| *k != "none" && *k != "random")
        .collect()
}

// -------------------------------------------------------------- TRANSITION

#[derive(Debug, Clone)]
pub struct Transition {
    pub kind: String,
    pub ms: u32,
}

impl Transition {
    pub fn none() -> Self {
        Self {
            kind: String::from("none"),
            ms: DEFAULT_MS,
        }
    }

    pub fn from_config(cfg: &crate::config::Config) -> Self {
        Self {
            kind: cfg.transition.clone(),
            ms: clamp_ms(cfg.transition_ms),
        }
    }

    pub fn with_overrides(mut self, kind: Option<&str>, ms: Option<u32>) -> Self {
        if let Some(k) = kind {
            if is_valid(k) {
                self.kind = k.to_string();
            }
        }
        if let Some(m) = ms {
            self.ms = clamp_ms(m);
        }
        self
    }

    pub fn enabled(&self) -> bool {
        self.kind != "none" && self.ms > 0
    }

    pub fn resolved(&self) -> Self {
        if self.kind != "random" {
            return self.clone();
        }
        let pool = concrete_kinds();
        let seed = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.subsec_nanos() as usize)
            .unwrap_or(0);
        Self {
            kind: pool[seed % pool.len()].to_string(),
            ms: self.ms,
        }
    }

    pub fn awww_args(&self) -> Vec<String> {
        let r = self.resolved();
        let ty = match r.kind.as_str() {
            "none" => "none",
            "fade" => "fade",
            "slide-left" | "wipe-left" => "left",
            "slide-right" | "wipe-right" => "right",
            "slide-up" | "wipe-up" => "top",
            "slide-down" | "wipe-down" => "bottom",
            "circle" => "center",
            "zoom" => "grow",
            "blinds" => "wave",
            _ => "fade",
        };
        let mut v = vec![String::from("--transition-type"), ty.to_string()];
        if ty != "none" {
            v.push(String::from("--transition-duration"));
            v.push(format!("{:.2}", r.ms as f32 / 1000.0));
            v.push(String::from("--transition-fps"));
            v.push(String::from("60"));
        }
        v
    }
}

// ------------------------------------------------------------------ EASING

pub fn ease(t: f32) -> f32 {
    let t = t.clamp(0.0, 1.0);
    if t < 0.5 {
        4.0 * t * t * t
    } else {
        let u = -2.0 * t + 2.0;
        1.0 - u * u * u / 2.0
    }
}

// ------------------------------------------------------------------ FRAMES

fn copy_cols(dst: &mut [u8], src: &[u8], w: usize, h: usize, d0: usize, s0: usize, n: usize) {
    if n == 0 {
        return;
    }
    for y in 0..h {
        let row = y * w * 4;
        let d = row + d0 * 4;
        let s = row + s0 * 4;
        dst[d..d + n * 4].copy_from_slice(&src[s..s + n * 4]);
    }
}

fn copy_rows(dst: &mut [u8], src: &[u8], w: usize, d0: usize, s0: usize, n: usize) {
    if n == 0 {
        return;
    }
    let stride = w * 4;
    dst[d0 * stride..(d0 + n) * stride].copy_from_slice(&src[s0 * stride..(s0 + n) * stride]);
}

fn mix_weight(e: f32) -> u32 {
    (e * 256.0).round().clamp(0.0, 256.0) as u32
}

fn mix(a: u8, b: u8, k: u32) -> u8 {
    ((a as u32 * (256 - k) + b as u32 * k) >> 8) as u8
}

fn frame_fade(dst: &mut [u8], old: &[u8], new: &[u8], e: f32) {
    let k = mix_weight(e);
    for ((d, o), n) in dst.iter_mut().zip(old.iter()).zip(new.iter()) {
        *d = mix(*o, *n, k);
    }
}

fn frame_circle(dst: &mut [u8], new: &[u8], w: usize, h: usize, e: f32) {
    let cx = w as f32 / 2.0;
    let cy = h as f32 / 2.0;
    let max_r = (cx * cx + cy * cy).sqrt();
    let r = e * max_r;
    if r <= 0.0 {
        return;
    }
    for y in 0..h {
        let dy = y as f32 + 0.5 - cy;
        if dy.abs() >= r {
            continue;
        }
        let half = (r * r - dy * dy).sqrt();
        let x0 = (cx - half).round().max(0.0) as usize;
        let x1 = ((cx + half).round() as usize).min(w);
        if x1 > x0 {
            let row = y * w * 4;
            dst[row + x0 * 4..row + x1 * 4].copy_from_slice(&new[row + x0 * 4..row + x1 * 4]);
        }
    }
}

fn frame_blinds(dst: &mut [u8], new: &[u8], w: usize, h: usize, e: f32) {
    let bands = 12usize;
    let bw = (w + bands - 1) / bands;
    let shown = (e * bw as f32).round() as usize;
    if shown == 0 {
        return;
    }
    for k in 0..bands {
        let x0 = k * bw;
        if x0 >= w {
            break;
        }
        let n = shown.min(w - x0);
        copy_cols(dst, new, w, h, x0, x0, n);
    }
}

fn frame_zoom(dst: &mut [u8], old: &[u8], new: &[u8], w: usize, h: usize, e: f32) {
    let s = 1.0 + 0.15 * (1.0 - e);
    let k = mix_weight(e);
    let cx = w as f32 / 2.0;
    let cy = h as f32 / 2.0;
    let xs: Vec<usize> = (0..w)
        .map(|x| {
            let sx = cx + (x as f32 + 0.5 - cx) / s;
            (sx as usize).min(w - 1)
        })
        .collect();
    for y in 0..h {
        let sy = cy + (y as f32 + 0.5 - cy) / s;
        let sy = (sy as usize).min(h - 1);
        let srow = sy * w * 4;
        let drow = y * w * 4;
        for x in 0..w {
            let si = srow + xs[x] * 4;
            let di = drow + x * 4;
            dst[di] = mix(old[di], new[si], k);
            dst[di + 1] = mix(old[di + 1], new[si + 1], k);
            dst[di + 2] = mix(old[di + 2], new[si + 2], k);
            dst[di + 3] = 255;
        }
    }
}

pub fn frame_into(
    dst: &mut [u8],
    old: &[u8],
    new: &[u8],
    w: usize,
    h: usize,
    kind: &str,
    t: f32,
) {
    let total = w * h * 4;
    if w == 0 || h == 0 || dst.len() < total || old.len() < total || new.len() < total {
        return;
    }
    let e = ease(t);
    match kind {
        "fade" => return frame_fade(&mut dst[..total], &old[..total], &new[..total], e),
        "zoom" => return frame_zoom(&mut dst[..total], &old[..total], &new[..total], w, h, e),
        _ => {}
    }
    dst[..total].copy_from_slice(&old[..total]);
    match kind {
        "slide-left" => {
            let off = ((1.0 - e) * w as f32).round() as usize;
            copy_cols(dst, new, w, h, 0, off.min(w), w.saturating_sub(off));
        }
        "slide-right" => {
            let off = ((1.0 - e) * w as f32).round() as usize;
            copy_cols(dst, new, w, h, off.min(w), 0, w.saturating_sub(off));
        }
        "slide-up" => {
            let off = ((1.0 - e) * h as f32).round() as usize;
            copy_rows(dst, new, w, 0, off.min(h), h.saturating_sub(off));
        }
        "slide-down" => {
            let off = ((1.0 - e) * h as f32).round() as usize;
            copy_rows(dst, new, w, off.min(h), 0, h.saturating_sub(off));
        }
        "wipe-left" => {
            let n = ((e * w as f32).round() as usize).min(w);
            copy_cols(dst, new, w, h, 0, 0, n);
        }
        "wipe-right" => {
            let n = ((e * w as f32).round() as usize).min(w);
            copy_cols(dst, new, w, h, w - n, w - n, n);
        }
        "wipe-up" => {
            let n = ((e * h as f32).round() as usize).min(h);
            copy_rows(dst, new, w, 0, 0, n);
        }
        "wipe-down" => {
            let n = ((e * h as f32).round() as usize).min(h);
            copy_rows(dst, new, w, h - n, h - n, n);
        }
        "circle" => frame_circle(dst, new, w, h, e),
        "blinds" => frame_blinds(dst, new, w, h, e),
        _ => frame_fade(dst, old, new, e),
    }
}

// --------------------------------------------------------------- VIDEO MPV

const PAN_AWAY: f64 = 1.5;
const ZOOM_IN: f64 = 0.2;

fn lerp(a: f64, b: f64, t: f64) -> f64 {
    a + (b - a) * t
}

fn ramp(sock: &Path, props: &[(&str, f64, f64)], ms: u32) {
    let total = Duration::from_millis(ms as u64);
    let step = Duration::from_millis(16);
    let start = Instant::now();
    loop {
        let el = start.elapsed();
        let t = if el >= total {
            1.0
        } else {
            ease(el.as_secs_f32() / total.as_secs_f32()) as f64
        };
        for (p, a, b) in props {
            let _ = crate::ipc::set_prop(sock, p, lerp(*a, *b, t));
        }
        if el >= total {
            break;
        }
        let spent = start.elapsed() - el;
        if spent < step {
            std::thread::sleep(step - spent);
        }
    }
}

fn slide_axis(kind: &str) -> Option<(&'static str, f64)> {
    match kind {
        "slide-left" => Some(("video-pan-x", -1.0)),
        "slide-right" => Some(("video-pan-x", 1.0)),
        "slide-up" => Some(("video-pan-y", -1.0)),
        "slide-down" => Some(("video-pan-y", 1.0)),
        _ => None,
    }
}

pub fn video_reset(sock: &Path) {
    let _ = crate::ipc::set_prop(sock, "brightness", 0.0f64);
    let _ = crate::ipc::set_prop(sock, "video-pan-x", 0.0f64);
    let _ = crate::ipc::set_prop(sock, "video-pan-y", 0.0f64);
    let _ = crate::ipc::set_prop(sock, "video-zoom", 0.0f64);
}

pub fn video_out(sock: &Path, tr: &Transition) {
    if !tr.enabled() {
        return;
    }
    let r = tr.resolved();
    let half = (r.ms / 2).max(50);
    match slide_axis(&r.kind) {
        Some((prop, dir)) => {
            ramp(sock, &[(prop, 0.0, -dir * PAN_AWAY)], half);
            let _ = crate::ipc::set_prop(sock, prop, dir * PAN_AWAY);
        }
        None => {
            ramp(sock, &[("brightness", 0.0, -100.0)], half);
        }
    }
}

pub fn video_in(sock: &Path, tr: &Transition) {
    if !tr.enabled() {
        return;
    }
    let r = tr.resolved();
    let half = (r.ms / 2).max(50);
    match slide_axis(&r.kind) {
        Some((prop, dir)) => {
            ramp(sock, &[(prop, dir * PAN_AWAY, 0.0)], half);
        }
        None if r.kind == "zoom" => {
            ramp(
                sock,
                &[("brightness", -100.0, 0.0), ("video-zoom", ZOOM_IN, 0.0)],
                half,
            );
        }
        None => {
            ramp(sock, &[("brightness", -100.0, 0.0)], half);
        }
    }
    video_reset(sock);
}

pub fn video_intro_opts(tr: &Transition) -> String {
    if !tr.enabled() {
        return String::new();
    }
    let r = tr.resolved();
    match slide_axis(&r.kind) {
        Some((prop, dir)) => format!(" --{}={}", prop, dir * PAN_AWAY),
        None if r.kind == "zoom" => format!(" --brightness=-100 --video-zoom={}", ZOOM_IN),
        None => String::from(" --brightness=-100"),
    }
}

pub fn wait_socket(sock: &Path, max_ms: u64) -> bool {
    let start = Instant::now();
    while start.elapsed() < Duration::from_millis(max_ms) {
        if crate::ipc::is_alive(sock) {
            return true;
        }
        std::thread::sleep(Duration::from_millis(40));
    }
    false
}

// ------------------------------------------------------------------- TESTS

#[cfg(test)]
mod tests {
    use super::*;

    fn pattern(w: usize, h: usize, flip: bool) -> Vec<u8> {
        let mut v = vec![0u8; w * h * 4];
        for (i, px) in v.chunks_exact_mut(4).enumerate() {
            let mut c = [
                (i % 251) as u8 + 1,
                ((i / 3) % 251) as u8 + 1,
                ((i / 7) % 251) as u8 + 1,
            ];
            if flip {
                for ch in c.iter_mut() {
                    *ch ^= 0x55;
                }
            }
            px[0] = c[0];
            px[1] = c[1];
            px[2] = c[2];
            px[3] = 255;
        }
        v
    }

    fn render(kind: &str, t: f32, w: usize, h: usize, old: &[u8], new: &[u8]) -> Vec<u8> {
        let mut dst = vec![0u8; w * h * 4];
        frame_into(&mut dst, old, new, w, h, kind, t);
        dst
    }

    fn px(buf: &[u8], w: usize, x: usize, y: usize) -> [u8; 4] {
        let i = (y * w + x) * 4;
        [buf[i], buf[i + 1], buf[i + 2], buf[i + 3]]
    }

    #[test]
    fn every_kind_starts_as_old_and_ends_as_new() {
        let (w, h) = (48, 30);
        let old = pattern(w, h, false);
        let new = pattern(w, h, true);
        for (k, _) in KINDS {
            if *k == "none" || *k == "random" {
                continue;
            }
            assert_eq!(render(k, 0.0, w, h, &old, &new), old, "{} inicio", k);
            assert_eq!(render(k, 1.0, w, h, &old, &new), new, "{} final", k);
        }
    }

    #[test]
    fn region_kinds_are_partial_at_midpoint() {
        let (w, h) = (48, 30);
        let old = pattern(w, h, false);
        let new = pattern(w, h, true);
        for k in ["slide-left", "slide-right", "slide-up", "slide-down"] {
            let mid = render(k, 0.5, w, h, &old, &new);
            assert_ne!(mid, old, "{} igual al inicio", k);
            assert_ne!(mid, new, "{} igual al final", k);
        }
        for k in [
            "wipe-left", "wipe-right", "wipe-up", "wipe-down", "circle", "blinds",
        ] {
            let mid = render(k, 0.5, w, h, &old, &new);
            let from_new = (0..w * h).filter(|i| mid[i * 4..i * 4 + 4] == new[i * 4..i * 4 + 4]).count();
            let from_old = (0..w * h).filter(|i| mid[i * 4..i * 4 + 4] == old[i * 4..i * 4 + 4]).count();
            assert!(from_new > 0 && from_old > 0, "{} no mezcla", k);
            assert_eq!(from_new + from_old, w * h, "{} pixel ajeno", k);
        }
    }

    #[test]
    fn fade_and_zoom_blend_between_old_and_new() {
        let (w, h) = (32, 20);
        let old = pattern(w, h, false);
        let new = pattern(w, h, true);
        let mid = render("fade", 0.5, w, h, &old, &new);
        for i in 0..w * h * 4 {
            let (lo, hi) = (old[i].min(new[i]), old[i].max(new[i]));
            assert!(mid[i] >= lo && mid[i] <= hi);
        }
        let z = render("zoom", 0.5, w, h, &old, &new);
        assert!(z.chunks_exact(4).all(|p| p[3] == 255));
        assert_ne!(z, old);
        assert_ne!(z, new);
    }

    #[test]
    fn slide_left_enters_from_left_edge() {
        let (w, h) = (40, 4);
        let old = pattern(w, h, false);
        let new = pattern(w, h, true);
        let mid = render("slide-left", 0.5, w, h, &old, &new);
        assert_eq!(px(&mid, w, 0, 0), px(&new, w, 20, 0));
        assert_eq!(px(&mid, w, w - 1, 0), px(&old, w, w - 1, 0));
    }

    #[test]
    fn slide_right_enters_from_right_edge() {
        let (w, h) = (40, 4);
        let old = pattern(w, h, false);
        let new = pattern(w, h, true);
        let mid = render("slide-right", 0.5, w, h, &old, &new);
        assert_eq!(px(&mid, w, 0, 0), px(&old, w, 0, 0));
        assert_eq!(px(&mid, w, w - 1, 0), px(&new, w, 19, 0));
    }

    #[test]
    fn validation_and_clamp() {
        assert!(is_valid("fade"));
        assert!(!is_valid("spin"));
        assert_eq!(clamp_ms(5), MIN_MS);
        assert_eq!(clamp_ms(99999), MAX_MS);
    }

    #[test]
    fn random_resolves_to_concrete() {
        let t = Transition {
            kind: String::from("random"),
            ms: 500,
        };
        let r = t.resolved();
        assert!(r.kind != "random" && r.kind != "none" && is_valid(&r.kind));
    }

    #[test]
    fn awww_mapping() {
        let t = Transition {
            kind: String::from("wipe-up"),
            ms: 800,
        };
        let a = t.awww_args();
        assert_eq!(a[1], "top");
        assert!(a.contains(&String::from("0.80")));
        let n = Transition::none().awww_args();
        assert_eq!(n, vec!["--transition-type", "none"]);
    }
}
