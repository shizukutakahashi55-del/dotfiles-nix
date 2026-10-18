// SECCION: GUI BIBLIOTECA CARPETAS AJUSTES ESTADO
// IPC: apply next prev stop pause resume toggle status list browse dirs dirs-add dirs-remove volume mute scaling hwdec matugen
use eframe::egui::{
    self, pos2, vec2, Align, Align2, Color32, FontFamily, FontId, Layout, Rect, RichText, Rounding,
    Sense, Stroke, TextStyle,
};
use oozewalls::{actions, config, engine, ipc, matugen, outputs, scan, thumbs, transition};
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::{
    atomic::{AtomicU64, Ordering},
    mpsc::{channel, Receiver, Sender},
    Arc,
};
use std::time::{Duration, Instant};

// SECCION: PALETA
const ACCENT: Color32 = Color32::from_rgb(56, 189, 248);
const ACCENT_SOFT: Color32 = Color32::from_rgb(16, 48, 68);
const BG: Color32 = Color32::from_rgb(12, 15, 20);
const PANEL: Color32 = Color32::from_rgb(17, 21, 28);
const CARD: Color32 = Color32::from_rgb(23, 28, 38);
const CARD_HOVER: Color32 = Color32::from_rgb(31, 38, 52);
const BORDER: Color32 = Color32::from_rgb(38, 46, 62);
const TEXT: Color32 = Color32::from_rgb(226, 232, 240);
const DIM: Color32 = Color32::from_rgb(128, 142, 163);
const OK: Color32 = Color32::from_rgb(74, 222, 128);
const WARN: Color32 = Color32::from_rgb(251, 191, 36);
const BAD: Color32 = Color32::from_rgb(248, 113, 113);
const RAM_BUDGET: u64 = 500;
const POLL: Duration = Duration::from_millis(1500);

// SECCION: ESTADO MENSAJES
#[derive(Clone, Default)]
struct SockInfo {
    output: String,
    pause: Option<bool>,
}

#[derive(Default)]
struct Status {
    current: String,
    running: bool,
    paused: bool,
    ram: u64,
    over: bool,
    pids: Vec<u32>,
    socks: Vec<SockInfo>,
}

fn read_status() -> Status {
    let cfg = config::Config::load();
    let socks: Vec<SockInfo> = ipc::discover()
        .iter()
        .map(|s| SockInfo {
            output: ipc::output_for_socket(s),
            pause: ipc::get_bool(s, "pause"),
        })
        .collect();
    let pids = engine::mpvpaper_pids();
    let ram = engine::rss_mb();
    Status {
        current: cfg.current.unwrap_or_default(),
        running: !pids.is_empty(),
        paused: engine::paused_state(),
        ram,
        over: ram > RAM_BUDGET,
        pids,
        socks,
    }
}

enum Msg {
    Thumb {
        gen: u64,
        path: String,
        size: [usize; 2],
        rgba: Vec<u8>,
    },
    Status(Status),
    Applied(Result<String, String>),
    Task(Result<String, String>),
    PickDir(Option<PathBuf>),
    PickFile(Option<PathBuf>),
    Swatches(String, Vec<String>),
}

enum Act {
    None,
    Select(String),
    Apply(String, Option<String>),
    Open(String),
    Home,
    Up,
    Remove(String),
}

struct Toast {
    text: String,
    bad: bool,
    at: Instant,
}

// SECCION: HELPERS
fn short_name(path: &str) -> String {
    Path::new(path)
        .file_name()
        .map(|s| s.to_string_lossy().to_string())
        .unwrap_or_else(|| path.to_string())
}

fn stem(name: &str) -> String {
    Path::new(name)
        .file_stem()
        .map(|s| s.to_string_lossy().to_string())
        .unwrap_or_else(|| name.to_string())
}

fn ext_upper(name: &str) -> String {
    Path::new(name)
        .extension()
        .map(|s| s.to_string_lossy().to_uppercase())
        .unwrap_or_default()
}

fn trim_chars(s: &str, max: usize) -> String {
    if s.chars().count() <= max {
        s.to_string()
    } else {
        let cut: String = s.chars().take(max.saturating_sub(1)).collect();
        format!("{}…", cut)
    }
}

fn middle_trim(s: &str, max: usize) -> String {
    let n = s.chars().count();
    if n <= max {
        return s.to_string();
    }
    let keep = max.saturating_sub(1);
    let head: String = s.chars().take(keep / 2).collect();
    let tail: String = s.chars().skip(n - (keep - keep / 2)).collect();
    format!("{}…{}", head, tail)
}

fn size_text(bytes: u64) -> String {
    if bytes >= 1_073_741_824 {
        format!("{:.1} GB", bytes as f64 / 1_073_741_824.0)
    } else if bytes >= 1_048_576 {
        format!("{} MB", bytes / 1_048_576)
    } else {
        format!("{} KB", bytes.max(1) / 1024)
    }
}

fn text_w(ui: &egui::Ui, text: &str, size: f32) -> f32 {
    ui.fonts(|f| {
        f.layout_no_wrap(text.to_string(), FontId::proportional(size), Color32::WHITE)
            .size()
            .x
    })
}

fn draw_badge(ui: &egui::Ui, min: egui::Pos2, text: &str, bg: Color32, fg: Color32) -> f32 {
    let w = text_w(ui, text, 10.0) + 12.0;
    let r = Rect::from_min_size(min, vec2(w, 18.0));
    ui.painter().rect_filled(r, Rounding::same(5.0), bg);
    ui.painter().text(
        r.center(),
        Align2::CENTER_CENTER,
        text,
        FontId::proportional(10.0),
        fg,
    );
    w
}

fn theme(ctx: &egui::Context) {
    let mut v = egui::Visuals::dark();
    v.panel_fill = BG;
    v.window_fill = PANEL;
    v.window_stroke = Stroke::new(1.0, BORDER);
    v.window_rounding = Rounding::same(12.0);
    v.extreme_bg_color = Color32::from_rgb(9, 11, 15);
    v.faint_bg_color = CARD;
    v.selection.bg_fill = ACCENT_SOFT;
    v.selection.stroke = Stroke::new(1.0, ACCENT);
    v.widgets.noninteractive.bg_stroke = Stroke::new(1.0, BORDER);
    v.widgets.noninteractive.fg_stroke = Stroke::new(1.0, TEXT);
    v.widgets.inactive.rounding = Rounding::same(8.0);
    v.widgets.hovered.rounding = Rounding::same(8.0);
    v.widgets.active.rounding = Rounding::same(8.0);
    v.widgets.open.rounding = Rounding::same(8.0);
    v.widgets.inactive.weak_bg_fill = CARD;
    v.widgets.inactive.bg_fill = CARD;
    v.widgets.inactive.bg_stroke = Stroke::new(1.0, BORDER);
    v.widgets.inactive.fg_stroke = Stroke::new(1.0, TEXT);
    v.widgets.hovered.weak_bg_fill = CARD_HOVER;
    v.widgets.hovered.bg_fill = CARD_HOVER;
    v.widgets.hovered.bg_stroke = Stroke::new(1.0, ACCENT);
    v.widgets.hovered.fg_stroke = Stroke::new(1.0, Color32::WHITE);
    v.widgets.active.weak_bg_fill = ACCENT_SOFT;
    v.widgets.active.bg_fill = ACCENT_SOFT;
    v.widgets.active.bg_stroke = Stroke::new(1.0, ACCENT);
    ctx.set_visuals(v);
    ctx.style_mut(|s| {
        s.spacing.item_spacing = vec2(8.0, 8.0);
        s.spacing.button_padding = vec2(12.0, 6.0);
        s.spacing.interact_size.y = 28.0;
        s.text_styles.insert(
            TextStyle::Heading,
            FontId::new(22.0, FontFamily::Proportional),
        );
        s.text_styles
            .insert(TextStyle::Body, FontId::new(14.0, FontFamily::Proportional));
        s.text_styles.insert(
            TextStyle::Button,
            FontId::new(14.0, FontFamily::Proportional),
        );
        s.text_styles.insert(
            TextStyle::Small,
            FontId::new(11.5, FontFamily::Proportional),
        );
    });
}

fn card_frame() -> egui::Frame {
    egui::Frame::none()
        .fill(CARD)
        .rounding(Rounding::same(12.0))
        .stroke(Stroke::new(1.0, BORDER))
        .inner_margin(egui::Margin::same(16.0))
}

fn section_label(ui: &mut egui::Ui, text: &str) {
    ui.add_space(4.0);
    ui.label(RichText::new(text).size(11.5).strong().color(DIM));
}

fn chip(ui: &mut egui::Ui, text: &str, col: Color32) {
    egui::Frame::none()
        .fill(CARD)
        .rounding(Rounding::same(6.0))
        .stroke(Stroke::new(1.0, BORDER))
        .inner_margin(egui::Margin::symmetric(8.0, 3.0))
        .show(ui, |ui| {
            ui.label(RichText::new(text).size(11.5).color(col));
        });
}

fn nav_btn(ui: &mut egui::Ui, text: &str, active: bool) -> bool {
    let size = vec2(ui.available_width(), 36.0);
    let (rect, resp) = ui.allocate_exact_size(size, Sense::click());
    let bg = if active {
        ACCENT_SOFT
    } else if resp.hovered() {
        CARD_HOVER
    } else {
        Color32::TRANSPARENT
    };
    ui.painter().rect_filled(rect, Rounding::same(8.0), bg);
    if active {
        let bar = Rect::from_min_size(rect.min + vec2(0.0, 8.0), vec2(3.0, rect.height() - 16.0));
        ui.painter().rect_filled(bar, Rounding::same(2.0), ACCENT);
    }
    ui.painter().text(
        rect.left_center() + vec2(16.0, 0.0),
        Align2::LEFT_CENTER,
        text,
        FontId::proportional(14.0),
        if active { ACCENT } else { TEXT },
    );
    resp.on_hover_cursor(egui::CursorIcon::PointingHand)
        .clicked()
}

fn side_row(ui: &mut egui::Ui, text: &str, active: bool) -> egui::Response {
    let size = vec2(ui.available_width(), 30.0);
    let (rect, resp) = ui.allocate_exact_size(size, Sense::click());
    if active {
        ui.painter()
            .rect_filled(rect, Rounding::same(7.0), ACCENT_SOFT);
    } else if resp.hovered() {
        ui.painter()
            .rect_filled(rect, Rounding::same(7.0), CARD_HOVER);
    }
    let ic = Rect::from_min_size(rect.left_center() + vec2(12.0, -6.0), vec2(14.0, 11.0));
    let col = if active { ACCENT } else { DIM };
    ui.painter().rect_filled(
        Rect::from_min_size(ic.min, vec2(6.0, 3.0)),
        Rounding::same(1.5),
        col,
    );
    ui.painter().rect_filled(
        Rect::from_min_max(pos2(ic.left(), ic.top() + 2.0), ic.max),
        Rounding::same(2.5),
        col,
    );
    ui.painter()
        .with_clip_rect(rect.shrink2(vec2(4.0, 0.0)))
        .text(
            rect.left_center() + vec2(36.0, 0.0),
            Align2::LEFT_CENTER,
            trim_chars(text, 22),
            FontId::proportional(13.0),
            if active { TEXT } else { DIM },
        );
    resp.on_hover_cursor(egui::CursorIcon::PointingHand)
}

fn paint_icon(p: &egui::Painter, kind: &str, c: egui::Pos2, s: f32, col: Color32) {
    let h = s * 0.5;
    let st = Stroke::new(1.8, col);
    let tri = |pts: Vec<egui::Pos2>| {
        p.add(egui::Shape::convex_polygon(pts, col, Stroke::NONE));
    };
    match kind {
        "stop" => {
            p.rect_filled(
                Rect::from_center_size(c, vec2(s * 0.62, s * 0.62)),
                Rounding::same(2.0),
                col,
            );
        }
        "play" => tri(vec![
            c + vec2(-h * 0.5, -h * 0.85),
            c + vec2(h * 0.85, 0.0),
            c + vec2(-h * 0.5, h * 0.85),
        ]),
        "next" => {
            tri(vec![
                c + vec2(-h * 0.8, -h * 0.8),
                c + vec2(h * 0.55, 0.0),
                c + vec2(-h * 0.8, h * 0.8),
            ]);
            p.rect_filled(
                Rect::from_center_size(c + vec2(h * 0.8, 0.0), vec2(2.2, h * 1.6)),
                Rounding::same(1.0),
                col,
            );
        }
        "prev" => {
            tri(vec![
                c + vec2(h * 0.8, -h * 0.8),
                c + vec2(-h * 0.55, 0.0),
                c + vec2(h * 0.8, h * 0.8),
            ]);
            p.rect_filled(
                Rect::from_center_size(c + vec2(-h * 0.8, 0.0), vec2(2.2, h * 1.6)),
                Rounding::same(1.0),
                col,
            );
        }
        "pause" => {
            for dx in [-h * 0.42, h * 0.42] {
                p.rect_filled(
                    Rect::from_center_size(c + vec2(dx, 0.0), vec2(h * 0.55, h * 1.7)),
                    Rounding::same(1.5),
                    col,
                );
            }
        }
        "back" => {
            let (l, r) = (c + vec2(-h * 0.85, 0.0), c + vec2(h * 0.85, 0.0));
            p.line_segment([l, r], st);
            p.line_segment([l, l + vec2(h * 0.6, -h * 0.6)], st);
            p.line_segment([l, l + vec2(h * 0.6, h * 0.6)], st);
        }
        "close" => {
            let d = h * 0.6;
            p.line_segment([c + vec2(-d, -d), c + vec2(d, d)], st);
            p.line_segment([c + vec2(-d, d), c + vec2(d, -d)], st);
        }
        "refresh" => {
            let r = h * 0.72;
            let (a0, a1) = (0.9f32, 5.6f32);
            let n = 20;
            let pts: Vec<egui::Pos2> = (0..=n)
                .map(|i| {
                    let a = a0 + (a1 - a0) * i as f32 / n as f32;
                    c + vec2(a.cos() * r, a.sin() * r)
                })
                .collect();
            p.add(egui::Shape::line(pts.clone(), st));
            let e = *pts.last().unwrap();
            tri(vec![
                e + vec2(-h * 0.1, -h * 0.55),
                e + vec2(h * 0.55, h * 0.15),
                e + vec2(-h * 0.5, h * 0.3),
            ]);
        }
        _ => {}
    }
}

fn glyph_btn(ui: &mut egui::Ui, kind: &str, size: egui::Vec2) -> egui::Response {
    let (rect, resp) = ui.allocate_exact_size(size, Sense::click());
    let hot = resp.hovered();
    ui.painter().rect(
        rect,
        Rounding::same(8.0),
        if hot { CARD_HOVER } else { CARD },
        Stroke::new(1.0, if hot { ACCENT } else { BORDER }),
    );
    paint_icon(
        ui.painter(),
        kind,
        rect.center(),
        16.0,
        if hot { Color32::WHITE } else { TEXT },
    );
    resp.on_hover_cursor(egui::CursorIcon::PointingHand)
}

fn scheme_chips(ui: &mut egui::Ui, current: &mut String) -> bool {
    let mut changed = false;
    ui.horizontal_wrapped(|ui| {
        ui.spacing_mut().item_spacing = vec2(6.0, 6.0);
        for (name, label) in matugen::SCHEMES {
            let active = current.as_str() == *name;
            let b = egui::Button::new(RichText::new(*label).size(12.0).color(if active {
                ACCENT
            } else {
                TEXT
            }))
            .fill(if active { ACCENT_SOFT } else { CARD })
            .stroke(Stroke::new(1.0, if active { ACCENT } else { BORDER }))
            .rounding(Rounding::same(12.0))
            .min_size(vec2(0.0, 24.0));
            if ui.add(b).clicked() && !active {
                *current = name.to_string();
                changed = true;
            }
        }
    });
    changed
}

fn hex_color(h: &str) -> Color32 {
    let t = h.trim_start_matches('#');
    if t.len() >= 6 {
        if let (Ok(r), Ok(g), Ok(b)) = (
            u8::from_str_radix(&t[0..2], 16),
            u8::from_str_radix(&t[2..4], 16),
            u8::from_str_radix(&t[4..6], 16),
        ) {
            return Color32::from_rgb(r, g, b);
        }
    }
    DIM
}

fn swatch_row(ui: &mut egui::Ui, colors: &[String], active: u8) -> Option<u8> {
    let mut hit = None;
    ui.horizontal_wrapped(|ui| {
        ui.spacing_mut().item_spacing = vec2(8.0, 6.0);
        for (i, c) in colors.iter().enumerate() {
            let (rect, resp) = ui.allocate_exact_size(vec2(26.0, 26.0), Sense::click());
            let on = i as u8 == active;
            ui.painter()
                .rect_filled(rect, Rounding::same(13.0), hex_color(c));
            ui.painter().rect_stroke(
                rect,
                Rounding::same(13.0),
                Stroke::new(
                    if on { 2.0 } else { 1.0 },
                    if on { Color32::WHITE } else { BORDER },
                ),
            );
            let lum = {
                let k = hex_color(c);
                0.299 * k.r() as f32 + 0.587 * k.g() as f32 + 0.114 * k.b() as f32
            };
            ui.painter().text(
                rect.center(),
                Align2::CENTER_CENTER,
                format!("{}", i + 1),
                FontId::proportional(11.0),
                if lum > 140.0 {
                    Color32::BLACK
                } else {
                    Color32::WHITE
                },
            );
            if resp
                .on_hover_cursor(egui::CursorIcon::PointingHand)
                .clicked()
            {
                hit = Some(i as u8);
            }
        }
    });
    hit
}

fn icon_btn(ui: &mut egui::Ui, text: &str, primary: bool, enabled: bool) -> bool {
    let (rect, resp) = ui.allocate_exact_size(vec2(36.0, 36.0), Sense::click());
    let bg = if primary {
        if resp.hovered() {
            Color32::from_rgb(125, 211, 252)
        } else {
            ACCENT
        }
    } else if resp.hovered() {
        CARD_HOVER
    } else {
        CARD
    };
    ui.painter().rect(
        rect,
        Rounding::same(18.0),
        bg,
        Stroke::new(1.0, if primary { ACCENT } else { BORDER }),
    );
    let fg = if primary {
        Color32::BLACK
    } else if enabled {
        TEXT
    } else {
        DIM
    };
    paint_icon(ui.painter(), text, rect.center(), 16.0, fg);
    resp.on_hover_cursor(egui::CursorIcon::PointingHand)
        .clicked()
        && enabled
}

// SECCION: APP
struct Gui {
    cfg: config::Config,
    outs: Vec<String>,
    compositor: String,
    nav: Option<String>,
    folders: Vec<scan::Folder>,
    entries: Vec<scan::Entry>,
    selected: Option<String>,
    scroll_to: Option<String>,
    filter: String,
    kind: u8,
    sort: u8,
    card: f32,
    cols: usize,
    tab: u8,
    status: Status,
    textures: HashMap<String, egui::TextureHandle>,
    now_key: String,
    now_tex: Option<egui::TextureHandle>,
    tx: Sender<Msg>,
    rx: Receiver<Msg>,
    thumb_gen: Arc<AtomicU64>,
    last_poll: Option<Instant>,
    inflight: bool,
    applying: Option<String>,
    picking: bool,
    toast: Option<Toast>,
    vol_dirty: Option<Instant>,
    swatches: Vec<String>,
    swatch_key: String,
    probing: bool,
}

impl Gui {
    fn new(cc: &eframe::CreationContext<'_>) -> Self {
        theme(&cc.egui_ctx);
        let cfg = config::Config::load();
        let (tx, rx) = channel();
        let mut outs = vec![String::from("*")];
        for o in outputs::detect() {
            if !outs.contains(&o.name) {
                outs.push(o.name);
            }
        }
        if !outs.contains(&cfg.output) {
            outs.push(cfg.output.clone());
        }
        let mut app = Self {
            cfg,
            outs,
            compositor: outputs::detect_compositor(),
            nav: None,
            folders: Vec::new(),
            entries: Vec::new(),
            selected: None,
            scroll_to: None,
            filter: String::new(),
            kind: 0,
            sort: 0,
            card: 210.0,
            cols: 4,
            tab: 0,
            status: Status::default(),
            textures: HashMap::new(),
            now_key: String::new(),
            now_tex: None,
            tx,
            rx,
            thumb_gen: Arc::new(AtomicU64::new(0)),
            last_poll: None,
            inflight: false,
            applying: None,
            picking: false,
            toast: None,
            vol_dirty: None,
            swatches: Vec::new(),
            swatch_key: String::new(),
            probing: false,
        };
        app.load_view(&cc.egui_ctx);
        app
    }

    fn toast(&mut self, text: String, bad: bool) {
        self.toast = Some(Toast {
            text,
            bad,
            at: Instant::now(),
        });
    }

    fn commit(&mut self) {
        let mine = self.cfg.clone();
        let mut disk = config::Config::load();
        disk.volume = mine.volume;
        disk.mute = mine.mute;
        disk.hwdec = mine.hwdec;
        disk.layer = mine.layer;
        disk.output = mine.output;
        disk.scaling = mine.scaling;
        disk.dirs = mine.dirs;
        disk.static_backend = mine.static_backend;
        disk.transition = mine.transition;
        disk.transition_ms = mine.transition_ms;
        disk.scheme = mine.scheme;
        disk.source_index = mine.source_index;
        disk.palette_mode = mine.palette_mode;
        disk.palette_auto = mine.palette_auto;
        disk.colors_file = mine.colors_file;
        match disk.save() {
            Ok(_) => self.cfg = disk,
            Err(e) => self.toast(format!("error {}", e), true),
        }
    }

    fn sync_cfg(&mut self) {
        let fresh = config::Config::load();
        self.cfg.current = fresh.current;
        self.cfg.wallpapers = fresh.wallpapers;
    }

    fn task<F>(&self, ctx: &egui::Context, f: F)
    where
        F: FnOnce() -> Result<String, String> + Send + 'static,
    {
        let tx = self.tx.clone();
        let ctx = ctx.clone();
        std::thread::spawn(move || {
            let _ = tx.send(Msg::Task(f()));
            ctx.request_repaint();
        });
    }

    // SECCION: BIBLIOTECA CARGA NAVEGACION
    fn load_view(&mut self, ctx: &egui::Context) {
        match self.nav.clone() {
            Some(p) => {
                let (f, e) = scan::list_dir(&p);
                self.folders = f;
                self.entries = e;
            }
            None => {
                self.folders = self.cfg.dirs.iter().map(|d| scan::folder_info(d)).collect();
                self.entries.clear();
            }
        }
        let keep = self
            .selected
            .as_ref()
            .map(|s| self.entries.iter().any(|e| &e.path == s))
            .unwrap_or(true);
        if !keep {
            self.selected = None;
        }
        let alive: std::collections::HashSet<String> =
            self.entries.iter().map(|e| e.path.clone()).collect();
        self.textures.retain(|k, _| alive.contains(k));
        self.start_thumbs(ctx);
    }

    fn start_thumbs(&mut self, ctx: &egui::Context) {
        let gen = self.thumb_gen.fetch_add(1, Ordering::Relaxed) + 1;
        let jobs: Vec<(String, bool)> = self
            .entries
            .iter()
            .filter(|e| !self.textures.contains_key(&e.path))
            .map(|e| (e.path.clone(), e.is_video))
            .collect();
        for k in 0..2usize {
            let part: Vec<(String, bool)> = jobs.iter().skip(k).step_by(2).cloned().collect();
            if part.is_empty() {
                continue;
            }
            let tx = self.tx.clone();
            let cur = self.thumb_gen.clone();
            let ctx = ctx.clone();
            std::thread::spawn(move || {
                for (path, vid) in part {
                    if cur.load(Ordering::Relaxed) != gen {
                        break;
                    }
                    if let Some((w, h, raw)) = thumbs::load_cached(&path, vid) {
                        let m = Msg::Thumb {
                            gen,
                            path,
                            size: [w, h],
                            rgba: raw,
                        };
                        if tx.send(m).is_err() {
                            break;
                        }
                        ctx.request_repaint();
                    }
                }
            });
        }
    }

    fn open(&mut self, ctx: &egui::Context, path: Option<String>) {
        self.nav = path;
        self.selected = None;
        self.textures.clear();
        self.filter.clear();
        self.tab = 0;
        self.load_view(ctx);
    }

    fn visible(&self) -> (Vec<scan::Folder>, Vec<scan::Entry>) {
        let f = self.filter.trim().to_lowercase();
        let folders: Vec<scan::Folder> = self
            .folders
            .iter()
            .filter(|x| f.is_empty() || x.name.to_lowercase().contains(&f))
            .cloned()
            .collect();
        let mut entries: Vec<scan::Entry> = self
            .entries
            .iter()
            .filter(|e| match self.kind {
                1 => e.is_video,
                2 => !e.is_video,
                _ => true,
            })
            .filter(|e| f.is_empty() || e.name.to_lowercase().contains(&f))
            .cloned()
            .collect();
        match self.sort {
            1 => entries.sort_by(|a, b| b.mtime.cmp(&a.mtime)),
            2 => entries.sort_by(|a, b| b.bytes.cmp(&a.bytes)),
            _ => {}
        }
        (folders, entries)
    }

    fn crumbs(&self) -> Vec<(String, String)> {
        let mut v = Vec::new();
        let nav = match &self.nav {
            Some(n) => n.clone(),
            None => return v,
        };
        let root = self
            .cfg
            .dirs
            .iter()
            .filter(|r| scan::is_inside(&nav, r))
            .max_by_key(|r| r.len())
            .cloned()
            .unwrap_or_else(|| nav.clone());
        v.push((short_name(&root), root.clone()));
        let rel: PathBuf = Path::new(&nav)
            .strip_prefix(&root)
            .map(|p| p.to_path_buf())
            .unwrap_or_default();
        let mut acc = PathBuf::from(&root);
        for c in rel.components() {
            acc.push(c);
            v.push((
                c.as_os_str().to_string_lossy().to_string(),
                acc.to_string_lossy().to_string(),
            ));
        }
        v
    }

    fn move_sel(&mut self, delta: isize) {
        let (_, items) = self.visible();
        if items.is_empty() {
            return;
        }
        let cur = self
            .selected
            .as_ref()
            .and_then(|s| items.iter().position(|e| &e.path == s));
        let next = match cur {
            Some(i) => (i as isize + delta).clamp(0, items.len() as isize - 1) as usize,
            None => 0,
        };
        let p = items[next].path.clone();
        self.selected = Some(p.clone());
        self.scroll_to = Some(p);
    }

    // SECCION: ACCIONES APPLY CONTROL
    fn act(&mut self, ctx: &egui::Context, a: Act) {
        match a {
            Act::None => {}
            Act::Select(p) => self.selected = Some(p),
            Act::Apply(p, out) => {
                self.selected = Some(p.clone());
                self.apply(ctx, p, out);
            }
            Act::Open(p) => self.open(ctx, Some(p)),
            Act::Home => self.open(ctx, None),
            Act::Up => {
                let target = match &self.nav {
                    None => return,
                    Some(n) => {
                        if self.cfg.dirs.iter().any(|d| d == n) {
                            None
                        } else {
                            Path::new(n)
                                .parent()
                                .map(|p| p.to_string_lossy().to_string())
                        }
                    }
                };
                self.open(ctx, target);
            }
            Act::Remove(p) => self.remove_dir(ctx, &p),
        }
    }

    fn apply(&mut self, ctx: &egui::Context, path: String, out: Option<String>) {
        if self.applying.is_some() {
            return;
        }
        let out = out.unwrap_or_else(|| self.cfg.output.clone());
        self.applying = Some(short_name(&path));
        let tx = self.tx.clone();
        let ctx = ctx.clone();
        std::thread::spawn(move || {
            let r =
                actions::apply_file(&path, &out).map(|_| format!("aplicado {}", short_name(&path)));
            let _ = tx.send(Msg::Applied(r));
            ctx.request_repaint();
        });
    }

    fn ctl_step(&self, ctx: &egui::Context, dir: i32) {
        let out = self.cfg.output.clone();
        self.task(ctx, move || {
            actions::step(dir, &out, false).map(|_| String::from("aplicado"))
        });
    }

    fn ctl_toggle(&self, ctx: &egui::Context) {
        self.task(ctx, || {
            let p = engine::toggle_all();
            Ok(String::from(if p { "pausado" } else { "reanudado" }))
        });
    }

    fn ctl_pause(&self, ctx: &egui::Context, pause: bool) {
        self.task(ctx, move || {
            if pause {
                engine::pause_all();
                Ok(String::from("pausado"))
            } else {
                engine::resume_all();
                Ok(String::from("reanudado"))
            }
        });
    }

    fn ctl_stop(&self, ctx: &egui::Context) {
        let out = self.cfg.output.clone();
        self.task(ctx, move || {
            actions::stop_out(&out);
            Ok(format!("detenido en {}", out))
        });
    }

    fn palette_src(&mut self, path: &str, is_video: bool) -> Option<String> {
        if !is_video {
            return Some(path.to_string());
        }
        match thumbs::cached_path(path) {
            Some(p) => Some(p.to_string_lossy().to_string()),
            None => {
                self.toast(String::from("sin miniatura para la paleta"), true);
                None
            }
        }
    }

    fn run_matugen(&mut self, ctx: &egui::Context, path: String, is_video: bool) {
        let Some(src) = self.palette_src(&path, is_video) else {
            return;
        };
        let cfg = self.cfg.clone();
        self.task(ctx, move || {
            actions::run_palette(&cfg, &src).map(|_| String::from("paleta generada"))
        });
    }

    fn probe_swatches(&mut self, ctx: &egui::Context, path: &str, is_video: bool) {
        let key = format!("{}|{}|{}", path, self.cfg.scheme, self.cfg.palette_mode);
        if key == self.swatch_key || self.probing {
            return;
        }
        let src = if is_video {
            match thumbs::cached_path(path) {
                Some(p) => p.to_string_lossy().to_string(),
                None => return,
            }
        } else {
            path.to_string()
        };
        self.probing = true;
        let (mode, scheme) = (self.cfg.palette_mode.clone(), self.cfg.scheme.clone());
        let tx = self.tx.clone();
        let ctx = ctx.clone();
        std::thread::spawn(move || {
            let v = matugen::probe(&src, &mode, &scheme);
            let _ = tx.send(Msg::Swatches(key, v));
            ctx.request_repaint();
        });
    }

    fn pick_dir(&mut self, ctx: &egui::Context) {
        if self.picking {
            return;
        }
        self.picking = true;
        let tx = self.tx.clone();
        let ctx = ctx.clone();
        std::thread::spawn(move || {
            let p = rfd::FileDialog::new().pick_folder();
            let _ = tx.send(Msg::PickDir(p));
            ctx.request_repaint();
        });
    }

    fn pick_file(&mut self, ctx: &egui::Context) {
        if self.picking {
            return;
        }
        self.picking = true;
        let tx = self.tx.clone();
        let ctx = ctx.clone();
        std::thread::spawn(move || {
            let p = rfd::FileDialog::new()
                .add_filter(
                    "Media",
                    &[
                        "mp4", "mkv", "webm", "mov", "avi", "m4v", "png", "jpg", "jpeg", "webp",
                        "gif",
                    ],
                )
                .pick_file();
            let _ = tx.send(Msg::PickFile(p));
            ctx.request_repaint();
        });
    }

    fn add_dir(&mut self, ctx: &egui::Context, full: String) {
        if !Path::new(&full).is_dir() {
            self.toast(format!("no es carpeta {}", full), true);
            return;
        }
        if !self.cfg.dirs.contains(&full) {
            self.cfg.dirs.push(full.clone());
            self.commit();
        }
        self.toast(format!("agregada {}", short_name(&full)), false);
        self.open(ctx, Some(full));
    }

    fn remove_dir(&mut self, ctx: &egui::Context, path: &str) {
        self.cfg.dirs.retain(|d| d.as_str() != path);
        self.commit();
        let inside = self
            .nav
            .as_ref()
            .map(|n| scan::is_inside(n, path))
            .unwrap_or(false);
        if inside {
            self.open(ctx, None);
        } else {
            self.load_view(ctx);
        }
        self.toast(format!("quitada {}", short_name(path)), false);
    }

    // SECCION: PUMP TECLAS
    fn pump(&mut self, ctx: &egui::Context) {
        while let Ok(m) = self.rx.try_recv() {
            match m {
                Msg::Thumb {
                    gen,
                    path,
                    size,
                    rgba,
                } => {
                    if gen != self.thumb_gen.load(Ordering::Relaxed) {
                        continue;
                    }
                    let img = egui::ColorImage::from_rgba_unmultiplied(size, &rgba);
                    let tex = ctx.load_texture(path.clone(), img, egui::TextureOptions::LINEAR);
                    self.textures.insert(path, tex);
                }
                Msg::Status(s) => {
                    self.status = s;
                    self.inflight = false;
                }
                Msg::Applied(r) => {
                    self.applying = None;
                    self.sync_cfg();
                    match r {
                        Ok(t) => self.toast(t, false),
                        Err(e) => self.toast(e, true),
                    }
                    self.last_poll = None;
                }
                Msg::Task(r) => {
                    self.sync_cfg();
                    match r {
                        Ok(t) => {
                            if !t.is_empty() {
                                self.toast(t, false);
                            }
                        }
                        Err(e) => self.toast(e, true),
                    }
                    self.last_poll = None;
                }
                Msg::Swatches(key, v) => {
                    self.probing = false;
                    self.swatch_key = key;
                    self.swatches = v;
                }
                Msg::PickDir(p) => {
                    self.picking = false;
                    if let Some(p) = p {
                        self.add_dir(ctx, p.to_string_lossy().to_string());
                    }
                }
                Msg::PickFile(p) => {
                    self.picking = false;
                    if let Some(p) = p {
                        self.apply(ctx, p.to_string_lossy().to_string(), None);
                    }
                }
            }
        }
        let due = self.last_poll.map(|t| t.elapsed() >= POLL).unwrap_or(true);
        if due && !self.inflight {
            self.inflight = true;
            self.last_poll = Some(Instant::now());
            let tx = self.tx.clone();
            let c = ctx.clone();
            std::thread::spawn(move || {
                let _ = tx.send(Msg::Status(read_status()));
                c.request_repaint();
            });
        }
        ctx.request_repaint_after(POLL);
        if let Some(t) = self.vol_dirty {
            if t.elapsed() > Duration::from_millis(160) && !ctx.input(|i| i.pointer.any_down()) {
                self.vol_dirty = None;
                self.commit();
                let (v, m) = (self.cfg.volume, self.cfg.mute);
                self.task(ctx, move || {
                    engine::set_volume_all(v);
                    engine::set_mute_all(m);
                    Ok(String::new())
                });
            } else {
                ctx.request_repaint_after(Duration::from_millis(80));
            }
        }
        let cur = self.status.current.clone();
        if self.now_key != cur {
            self.now_key = cur.clone();
            self.now_tex = if cur.is_empty() {
                None
            } else {
                thumbs::peek(&cur).map(|(w, h, raw)| {
                    let img = egui::ColorImage::from_rgba_unmultiplied([w, h], &raw);
                    ctx.load_texture("now", img, egui::TextureOptions::LINEAR)
                })
            };
        }
    }

    fn keys(&mut self, ctx: &egui::Context) {
        let dropped: Vec<PathBuf> = ctx.input(|i| {
            i.raw
                .dropped_files
                .iter()
                .filter_map(|f| f.path.clone())
                .collect()
        });
        for p in dropped {
            if p.is_dir() {
                self.add_dir(ctx, p.to_string_lossy().to_string());
            } else {
                self.apply(ctx, p.to_string_lossy().to_string(), None);
            }
        }
        if self.tab != 0 || ctx.wants_keyboard_input() {
            return;
        }
        let (esc, enter, back, l, r, u, d) = ctx.input(|i| {
            (
                i.key_pressed(egui::Key::Escape),
                i.key_pressed(egui::Key::Enter),
                i.key_pressed(egui::Key::Backspace),
                i.key_pressed(egui::Key::ArrowLeft),
                i.key_pressed(egui::Key::ArrowRight),
                i.key_pressed(egui::Key::ArrowUp),
                i.key_pressed(egui::Key::ArrowDown),
            )
        });
        if esc {
            self.selected = None;
        }
        if enter {
            if let Some(p) = self.selected.clone() {
                self.apply(ctx, p, None);
            }
        }
        if back {
            self.act(ctx, Act::Up);
        }
        let cols = self.cols.max(1) as isize;
        let delta = if l {
            -1
        } else if r {
            1
        } else if u {
            -cols
        } else if d {
            cols
        } else {
            0
        };
        if delta != 0 {
            self.move_sel(delta);
        }
    }

    // SECCION: SIDEBAR
    fn sidebar(&mut self, ctx: &egui::Context) {
        let mut act = Act::None;
        egui::SidePanel::left("side")
            .exact_width(220.0)
            .resizable(false)
            .frame(
                egui::Frame::none()
                    .fill(PANEL)
                    .inner_margin(egui::Margin::same(14.0)),
            )
            .show(ctx, |ui| {
                ui.add_space(4.0);
                ui.label(RichText::new("OozeWalls").size(22.0).strong().color(TEXT));
                ui.label(RichText::new("wallpapers vivos").size(12.0).color(DIM));
                ui.add_space(14.0);
                if nav_btn(ui, "Biblioteca", self.tab == 0) {
                    self.tab = 0;
                }
                if nav_btn(ui, "Ajustes", self.tab == 1) {
                    self.tab = 1;
                }
                if nav_btn(ui, "Estado", self.tab == 2) {
                    self.tab = 2;
                }
                ui.add_space(10.0);
                section_label(ui, "CARPETAS");
                let list_h = (ui.available_height() - 100.0).max(60.0);
                egui::ScrollArea::vertical()
                    .max_height(list_h)
                    .auto_shrink([false, false])
                    .show(ui, |ui| {
                        ui.spacing_mut().item_spacing.y = 2.0;
                        for d in self.cfg.dirs.clone() {
                            let active = self.tab == 0
                                && self
                                    .nav
                                    .as_ref()
                                    .map(|n| scan::is_inside(n, &d))
                                    .unwrap_or(false);
                            let resp =
                                side_row(ui, &short_name(&d), active).on_hover_text(d.clone());
                            if resp.clicked() {
                                act = Act::Open(d.clone());
                            }
                            resp.context_menu(|ui| {
                                if ui.button("Quitar de la biblioteca").clicked() {
                                    act = Act::Remove(d.clone());
                                    ui.close_menu();
                                }
                            });
                        }
                    });
                ui.with_layout(Layout::bottom_up(Align::Min), |ui| {
                    let w = ui.available_width();
                    if ui
                        .add_sized([w, 34.0], egui::Button::new("Aplicar archivo…"))
                        .clicked()
                    {
                        self.pick_file(ctx);
                    }
                    if ui
                        .add_sized([w, 34.0], egui::Button::new("+ Agregar carpeta"))
                        .clicked()
                    {
                        self.pick_dir(ctx);
                    }
                });
            });
        self.act(ctx, act);
    }

    // SECCION: NOW BAR
    fn now_bar(&mut self, ctx: &egui::Context) {
        let mut prev = false;
        let mut toggle = false;
        let mut next = false;
        let mut stop = false;
        let mut vol_changed = false;
        egui::TopBottomPanel::bottom("now")
            .exact_height(72.0)
            .frame(
                egui::Frame::none()
                    .fill(PANEL)
                    .inner_margin(egui::Margin::symmetric(16.0, 10.0)),
            )
            .show(ctx, |ui| {
                ui.horizontal_centered(|ui| {
                    let (tr, _) = ui.allocate_exact_size(vec2(76.0, 43.0), Sense::hover());
                    let tex = self
                        .textures
                        .get(&self.status.current)
                        .or(self.now_tex.as_ref());
                    match tex {
                        Some(t) => {
                            egui::Image::new(t)
                                .rounding(Rounding::same(7.0))
                                .paint_at(ui, tr);
                        }
                        None => {
                            ui.painter()
                                .rect_filled(tr, Rounding::same(7.0), CARD_HOVER);
                        }
                    }
                    let cur = self.status.current.clone();
                    let multi = self.cfg.wallpapers.len() > 1;
                    ui.vertical(|ui| {
                        ui.spacing_mut().item_spacing.y = 2.0;
                        ui.add_space(4.0);
                        let title = if cur.is_empty() {
                            String::from("Sin fondo activo")
                        } else {
                            trim_chars(&stem(&short_name(&cur)), 34)
                        };
                        ui.label(RichText::new(title).size(14.0).strong().color(TEXT));
                        let sub = if !self.status.running {
                            if cur.is_empty() {
                                String::from("detenido")
                            } else {
                                String::from("estático")
                            }
                        } else if self.status.paused {
                            String::from("live · pausado")
                        } else if multi {
                            format!("live · {} salidas", self.cfg.wallpapers.len())
                        } else {
                            format!("live · salida {}", self.cfg.output)
                        };
                        ui.label(RichText::new(sub).size(12.0).color(DIM));
                    });
                    ui.with_layout(Layout::right_to_left(Align::Center), |ui| {
                        let room = ui.available_width();
                        let show_ram = room > 560.0;
                        let show_vol = room > 400.0;
                        let ram_col = if self.status.over {
                            BAD
                        } else if self.status.ram * 100 / RAM_BUDGET > 80 {
                            WARN
                        } else {
                            OK
                        };
                        if show_ram {
                            egui::Frame::none()
                                .fill(CARD)
                                .rounding(Rounding::same(12.0))
                                .stroke(Stroke::new(1.0, BORDER))
                                .inner_margin(egui::Margin::symmetric(10.0, 4.0))
                                .show(ui, |ui| {
                                    ui.label(
                                        RichText::new(format!(
                                            "RAM {} / {} MB",
                                            self.status.ram, RAM_BUDGET
                                        ))
                                        .size(12.0)
                                        .color(ram_col),
                                    );
                                });
                            ui.add_space(8.0);
                        }
                        ui.spacing_mut().slider_width = 96.0;
                        if show_vol {
                            if ui
                                .add(
                                    egui::Slider::new(&mut self.cfg.volume, 0..=100)
                                        .show_value(false),
                                )
                                .changed()
                            {
                                vol_changed = true;
                            }
                            let mute_txt = RichText::new("Silencio")
                                .size(12.0)
                                .color(if self.cfg.mute { ACCENT } else { DIM });
                            if ui
                                .add(egui::Button::new(mute_txt).fill(if self.cfg.mute {
                                    ACCENT_SOFT
                                } else {
                                    CARD
                                }))
                                .clicked()
                            {
                                self.cfg.mute = !self.cfg.mute;
                                vol_changed = true;
                            }
                        }
                        ui.add_space(12.0);
                        let live = self.status.running;
                        if icon_btn(ui, "stop", false, true) {
                            stop = true;
                        }
                        if icon_btn(ui, "next", false, true) {
                            next = true;
                        }
                        if icon_btn(
                            ui,
                            if self.status.paused { "play" } else { "pause" },
                            true,
                            live,
                        ) {
                            toggle = true;
                        }
                        if icon_btn(ui, "prev", false, true) {
                            prev = true;
                        }
                    });
                });
            });
        if prev {
            self.ctl_step(ctx, -1);
        }
        if next {
            self.ctl_step(ctx, 1);
        }
        if toggle {
            self.ctl_toggle(ctx);
        }
        if stop {
            self.ctl_stop(ctx);
        }
        if vol_changed {
            self.vol_dirty = Some(Instant::now());
        }
    }

    // SECCION: BIBLIOTECA UI
    fn library(&mut self, ui: &mut egui::Ui, ctx: &egui::Context) {
        let mut act = Act::None;
        let mut out_changed = false;
        let narrow = ui.available_width() < 640.0;
        let crumb_max = if narrow { 14 } else { 28 };
        ui.horizontal_wrapped(|ui| {
            if self.nav.is_some()
                && glyph_btn(ui, "back", vec2(34.0, 30.0))
                    .on_hover_text("Subir un nivel")
                    .clicked()
            {
                act = Act::Up;
            }
            let crumbs = self.crumbs();
            let at_home = crumbs.is_empty();
            let home = ui.add(
                egui::Button::new(
                    RichText::new("Biblioteca")
                        .size(18.0)
                        .strong()
                        .color(if at_home { TEXT } else { DIM }),
                )
                .frame(false),
            );
            if home.clicked() && !at_home {
                act = Act::Home;
            }
            let n = crumbs.len();
            for (i, (label, path)) in crumbs.iter().enumerate() {
                ui.label(RichText::new("/").size(16.0).color(DIM));
                let last = i + 1 == n;
                let b = ui.add(
                    egui::Button::new(
                        RichText::new(trim_chars(label, crumb_max))
                            .size(18.0)
                            .strong()
                            .color(if last { TEXT } else { DIM }),
                    )
                    .frame(false),
                );
                if b.clicked() && !last {
                    act = Act::Open(path.clone());
                }
            }
            if glyph_btn(ui, "refresh", vec2(30.0, 30.0))
                .on_hover_text("Recargar")
                .clicked()
            {
                self.cfg = config::Config::load();
                self.load_view(ctx);
                self.last_poll = None;
            }
        });
        ui.horizontal_wrapped(|ui| {
            ui.label(RichText::new("Aplicar en").size(12.0).color(DIM));
            egui::ComboBox::from_id_source("lib_out")
                .selected_text(if self.cfg.output == "*" {
                    String::from("Todas las salidas")
                } else {
                    self.cfg.output.clone()
                })
                .show_ui(ui, |ui| {
                    for o in self.outs.clone() {
                        let label = if o == "*" {
                            String::from("Todas las salidas")
                        } else {
                            o.clone()
                        };
                        if ui
                            .selectable_value(&mut self.cfg.output, o.clone(), label)
                            .changed()
                        {
                            out_changed = true;
                        }
                    }
                });
        });
        if self.nav.is_some() {
            ui.horizontal_wrapped(|ui| {
                let sw = (ui.available_width() * 0.45).clamp(110.0, 210.0);
                ui.add(
                    egui::TextEdit::singleline(&mut self.filter)
                        .hint_text("Buscar…")
                        .desired_width(sw),
                );
                ui.selectable_value(&mut self.kind, 0, "Todos");
                ui.selectable_value(&mut self.kind, 1, "Live");
                ui.selectable_value(&mut self.kind, 2, "Imágenes");
            });
            ui.horizontal_wrapped(|ui| {
                ui.label(RichText::new("Orden").size(12.0).color(DIM));
                egui::ComboBox::from_id_source("lib_sort")
                    .selected_text(["Nombre", "Recientes", "Tamaño"][self.sort as usize])
                    .show_ui(ui, |ui| {
                        ui.selectable_value(&mut self.sort, 0, "Nombre");
                        ui.selectable_value(&mut self.sort, 1, "Recientes");
                        ui.selectable_value(&mut self.sort, 2, "Tamaño");
                    });
                ui.label(RichText::new("Tamaño").size(12.0).color(DIM));
                ui.add(egui::Slider::new(&mut self.card, 150.0..=320.0).show_value(false));
            });
        }
        if out_changed {
            self.commit();
        }
        ui.add_space(2.0);
        let (folders, entries) = self.visible();
        let sp = 10.0;
        let avail = (ui.available_width() - 16.0).max(220.0);
        let cols = (((avail + sp) / (self.card + sp)).floor() as usize).max(1);
        self.cols = cols;
        let wall_w = ((avail - sp * (cols as f32 - 1.0)) / cols as f32).floor();
        let fcols = (((avail + sp) / (250.0 + sp)).floor() as usize).max(1);
        let folder_w = ((avail - sp * (fcols as f32 - 1.0)) / fcols as f32).floor();
        let scroll_to = self.scroll_to.take();
        let at_root = self.nav.is_none();
        egui::ScrollArea::vertical()
            .auto_shrink([false, false])
            .show(ui, |ui| {
                ui.spacing_mut().item_spacing = vec2(sp, sp);
                if !folders.is_empty() {
                    section_label(
                        ui,
                        if at_root {
                            "CARPETAS DE LA BIBLIOTECA"
                        } else {
                            "CARPETAS"
                        },
                    );
                    for row in folders.chunks(fcols) {
                        ui.horizontal(|ui| {
                            for f in row {
                                let a = self.folder_card(ui, f, folder_w, at_root);
                                if !matches!(a, Act::None) {
                                    act = a;
                                }
                            }
                        });
                    }
                }
                if !entries.is_empty() {
                    ui.add_space(6.0);
                    section_label(
                        ui,
                        &format!(
                            "FONDOS · {}   ·   doble click para aplicar · click derecho para más",
                            entries.len()
                        ),
                    );
                    for row in entries.chunks(cols) {
                        ui.horizontal(|ui| {
                            for e in row {
                                let go = scroll_to.as_deref() == Some(e.path.as_str());
                                let a = self.wall_card(ui, e, wall_w, go);
                                if !matches!(a, Act::None) {
                                    act = a;
                                }
                            }
                        });
                    }
                }
                if folders.is_empty() && entries.is_empty() {
                    ui.add_space(60.0);
                    ui.vertical_centered(|ui| {
                        let msg = if at_root {
                            "Agrega una carpeta para empezar"
                        } else if self.filter.is_empty() {
                            "Esta carpeta no tiene fondos"
                        } else {
                            "Sin coincidencias"
                        };
                        ui.label(RichText::new(msg).size(16.0).color(DIM));
                        if at_root {
                            ui.label(
                                RichText::new("También puedes arrastrar una carpeta a la ventana")
                                    .size(12.5)
                                    .color(DIM),
                            );
                        }
                    });
                }
            });
        self.act(ctx, act);
    }

    fn folder_card(&self, ui: &mut egui::Ui, f: &scan::Folder, w: f32, root: bool) -> Act {
        let (rect, resp) = ui.allocate_exact_size(vec2(w, 68.0), Sense::click());
        let hot = resp.hovered();
        ui.painter().rect(
            rect,
            Rounding::same(10.0),
            if hot { CARD_HOVER } else { CARD },
            Stroke::new(1.0, if hot { ACCENT } else { BORDER }),
        );
        let col = if f.missing { BAD } else { ACCENT };
        let ic = Rect::from_min_size(rect.left_center() + vec2(16.0, -14.0), vec2(38.0, 28.0));
        ui.painter().rect_filled(
            Rect::from_min_size(ic.min, vec2(16.0, 8.0)),
            Rounding::same(3.0),
            col.gamma_multiply(0.65),
        );
        ui.painter().rect_filled(
            Rect::from_min_max(pos2(ic.left(), ic.top() + 4.0), ic.max),
            Rounding::same(5.0),
            col,
        );
        let mut parts: Vec<String> = Vec::new();
        if f.videos > 0 {
            parts.push(format!("{} live", f.videos));
        }
        if f.images > 0 {
            parts.push(format!("{} img", f.images));
        }
        if f.subfolders > 0 {
            parts.push(format!(
                "{} carpeta{}",
                f.subfolders,
                if f.subfolders == 1 { "" } else { "s" }
            ));
        }
        let meta = if f.missing {
            String::from("no existe")
        } else if parts.is_empty() {
            String::from("vacía")
        } else {
            parts.join(" · ")
        };
        let clip = ui.painter().with_clip_rect(Rect::from_min_max(
            pos2(ic.right() + 12.0, rect.top()),
            rect.max,
        ));
        clip.text(
            pos2(ic.right() + 16.0, rect.center().y - 11.0),
            Align2::LEFT_CENTER,
            trim_chars(&f.name, ((w - 80.0) / 8.0) as usize),
            FontId::proportional(14.5),
            TEXT,
        );
        clip.text(
            pos2(ic.right() + 16.0, rect.center().y + 11.0),
            Align2::LEFT_CENTER,
            meta,
            FontId::proportional(12.0),
            DIM,
        );
        let resp = resp.on_hover_cursor(egui::CursorIcon::PointingHand);
        let mut act = Act::None;
        if resp.clicked() {
            act = Act::Open(f.path.clone());
        }
        if root {
            resp.context_menu(|ui| {
                if ui.button("Quitar de la biblioteca").clicked() {
                    act = Act::Remove(f.path.clone());
                    ui.close_menu();
                }
            });
        }
        act
    }

    fn wall_card(&self, ui: &mut egui::Ui, e: &scan::Entry, w: f32, scroll: bool) -> Act {
        let pad = 6.0;
        let iw = w - pad * 2.0;
        let ih = (iw * 9.0 / 16.0).floor();
        let h = pad + ih + 10.0 + 19.0 + 16.0 + pad;
        let (rect, resp) = ui.allocate_exact_size(vec2(w, h), Sense::click());
        let selected = self.selected.as_deref() == Some(e.path.as_str());
        let used = self.cfg.wallpapers.values().any(|p| p == &e.path);
        let hot = resp.hovered();
        let fill = if selected {
            ACCENT_SOFT
        } else if hot {
            CARD_HOVER
        } else {
            CARD
        };
        let stroke = if selected {
            Stroke::new(2.0, ACCENT)
        } else if used {
            Stroke::new(1.5, OK)
        } else {
            Stroke::new(1.0, if hot { DIM } else { BORDER })
        };
        ui.painter().rect(rect, Rounding::same(10.0), fill, stroke);
        let ir = Rect::from_min_size(rect.min + vec2(pad, pad), vec2(iw, ih));
        match self.textures.get(&e.path) {
            Some(t) => {
                egui::Image::new(t)
                    .rounding(Rounding::same(7.0))
                    .paint_at(ui, ir);
            }
            None => {
                ui.painter()
                    .rect_filled(ir, Rounding::same(7.0), Color32::from_rgb(28, 34, 46));
                ui.painter().text(
                    ir.center(),
                    Align2::CENTER_CENTER,
                    if e.is_video { "▶" } else { "…" },
                    FontId::proportional(22.0),
                    DIM,
                );
            }
        }
        if e.is_video {
            draw_badge(ui, ir.min + vec2(6.0, 6.0), "LIVE", ACCENT, Color32::BLACK);
        }
        if used {
            let bw = text_w(ui, "EN USO", 10.0) + 12.0;
            draw_badge(
                ui,
                pos2(ir.right() - bw - 6.0, ir.top() + 6.0),
                "EN USO",
                OK,
                Color32::BLACK,
            );
        }
        if hot {
            let bar = Rect::from_min_max(pos2(ir.left(), ir.bottom() - 26.0), ir.max);
            ui.painter().rect_filled(
                bar,
                Rounding {
                    nw: 0.0,
                    ne: 0.0,
                    sw: 7.0,
                    se: 7.0,
                },
                Color32::from_black_alpha(165),
            );
            ui.painter().text(
                bar.center(),
                Align2::CENTER_CENTER,
                "doble click para aplicar",
                FontId::proportional(11.5),
                Color32::WHITE,
            );
        }
        let tx = rect.left() + pad + 3.0;
        let ty = ir.bottom() + 10.0;
        let clip = ui
            .painter()
            .with_clip_rect(Rect::from_min_size(pos2(tx, ty), vec2(iw - 6.0, 40.0)));
        clip.text(
            pos2(tx, ty),
            Align2::LEFT_TOP,
            trim_chars(&stem(&e.name), (iw / 7.2) as usize),
            FontId::proportional(13.5),
            TEXT,
        );
        clip.text(
            pos2(tx, ty + 20.0),
            Align2::LEFT_TOP,
            format!("{} · {}", ext_upper(&e.name), size_text(e.bytes)),
            FontId::proportional(11.5),
            DIM,
        );
        let resp = resp.on_hover_cursor(egui::CursorIcon::PointingHand);
        if scroll {
            resp.scroll_to_me(Some(Align::Center));
        }
        let mut act = Act::None;
        if resp.double_clicked() {
            act = Act::Apply(e.path.clone(), None);
        } else if resp.clicked() {
            act = Act::Select(e.path.clone());
        }
        resp.context_menu(|ui| {
            if ui.button("Aplicar").clicked() {
                act = Act::Apply(e.path.clone(), None);
                ui.close_menu();
            }
            let others: Vec<&String> = self
                .outs
                .iter()
                .filter(|o| **o != self.cfg.output)
                .collect();
            if !others.is_empty() {
                ui.separator();
                for o in others {
                    let name = if o == "*" { "todas" } else { o.as_str() };
                    if ui.button(format!("Aplicar en {}", name)).clicked() {
                        act = Act::Apply(e.path.clone(), Some(o.clone()));
                        ui.close_menu();
                    }
                }
            }
        });
        act
    }

    // SECCION: DETALLE
    fn detail(&mut self, ctx: &egui::Context) {
        let sel = match &self.selected {
            Some(s) => s.clone(),
            None => return,
        };
        let e = match self.entries.iter().find(|e| e.path == sel) {
            Some(e) => e.clone(),
            None => return,
        };
        let mut apply_now = false;
        let mut mat = false;
        let mut regen = false;
        let mut close = false;
        let mut changed = false;
        let mut rescale = false;
        egui::SidePanel::right("detail")
            .exact_width(304.0)
            .resizable(false)
            .frame(
                egui::Frame::none()
                    .fill(PANEL)
                    .inner_margin(egui::Margin::same(16.0)),
            )
            .show(ctx, |ui| {
                ui.horizontal(|ui| {
                    ui.label(RichText::new("DETALLE").size(11.5).strong().color(DIM));
                    ui.with_layout(Layout::right_to_left(Align::Center), |ui| {
                        if glyph_btn(ui, "close", vec2(26.0, 24.0)).clicked() {
                            close = true;
                        }
                    });
                });
                self.probe_swatches(ctx, &e.path, e.is_video);
                egui::ScrollArea::vertical()
                    .auto_shrink([false, false])
                    .show(ui, |ui| {
                        let w = ui.available_width();
                        let (r, _) = ui
                            .allocate_exact_size(vec2(w, (w * 9.0 / 16.0).floor()), Sense::hover());
                        match self.textures.get(&e.path) {
                            Some(t) => {
                                egui::Image::new(t)
                                    .rounding(Rounding::same(10.0))
                                    .paint_at(ui, r);
                            }
                            None => {
                                ui.painter().rect_filled(r, Rounding::same(10.0), CARD);
                            }
                        }
                        ui.add_space(4.0);
                        ui.label(
                            RichText::new(trim_chars(&stem(&e.name), 34))
                                .size(17.0)
                                .strong()
                                .color(TEXT),
                        );
                        ui.horizontal(|ui| {
                            chip(ui, if e.is_video { "LIVE" } else { "IMAGEN" }, ACCENT);
                            chip(ui, &ext_upper(&e.name), DIM);
                            chip(ui, &size_text(e.bytes), DIM);
                        });
                        ui.label(
                            RichText::new(middle_trim(&e.path, 42))
                                .size(11.5)
                                .color(DIM),
                        )
                        .on_hover_text(e.path.clone());
                        let mut used: Vec<String> = self
                            .cfg
                            .wallpapers
                            .iter()
                            .filter(|(_, p)| p.as_str() == e.path)
                            .map(|(o, _)| {
                                if o == "*" {
                                    String::from("todas")
                                } else {
                                    o.clone()
                                }
                            })
                            .collect();
                        used.sort();
                        if !used.is_empty() {
                            ui.label(
                                RichText::new(format!("En uso en: {}", used.join(", ")))
                                    .size(12.5)
                                    .color(OK),
                            );
                        }
                        ui.separator();
                        ui.label(RichText::new("Aplicar en").size(12.0).color(DIM));
                        egui::ComboBox::from_id_source("det_out")
                            .width(ui.available_width() - 8.0)
                            .selected_text(if self.cfg.output == "*" {
                                String::from("Todas las salidas")
                            } else {
                                self.cfg.output.clone()
                            })
                            .show_ui(ui, |ui| {
                                for o in self.outs.clone() {
                                    let label = if o == "*" {
                                        String::from("Todas las salidas")
                                    } else {
                                        o.clone()
                                    };
                                    if ui
                                        .selectable_value(&mut self.cfg.output, o.clone(), label)
                                        .changed()
                                    {
                                        changed = true;
                                    }
                                }
                            });
                        ui.label(RichText::new("Escala").size(12.0).color(DIM));
                        let mut sc = self.cfg.scaling_for(&self.cfg.output);
                        let before = sc.clone();
                        ui.horizontal(|ui| {
                            for (k, l) in [
                                ("fit", "Ajustar"),
                                ("fill", "Llenar"),
                                ("stretch", "Estirar"),
                            ] {
                                ui.selectable_value(&mut sc, k.to_string(), l);
                            }
                        });
                        if sc != before {
                            self.cfg.scaling.insert(self.cfg.output.clone(), sc);
                            changed = true;
                            rescale = true;
                        }
                        ui.add_space(4.0);
                        ui.label(RichText::new("Paleta (matugen)").size(12.0).color(DIM));
                        let mut pal_changed = scheme_chips(ui, &mut self.cfg.scheme);
                        let want_key =
                            format!("{}|{}|{}", e.path, self.cfg.scheme, self.cfg.palette_mode);
                        if self.swatch_key == want_key && self.swatches.len() > 1 {
                            if let Some(i) = swatch_row(ui, &self.swatches, self.cfg.source_index) {
                                self.cfg.source_index = i;
                                pal_changed = true;
                            }
                        }
                        if pal_changed {
                            changed = true;
                            regen = self.cfg.current.as_deref() == Some(e.path.as_str());
                        }
                        ui.add_space(6.0);
                        let busy = self.applying.is_some();
                        let btn = egui::Button::new(
                            RichText::new(if busy {
                                "Aplicando…"
                            } else {
                                "Aplicar fondo"
                            })
                            .size(15.0)
                            .strong()
                            .color(Color32::BLACK),
                        )
                        .fill(ACCENT)
                        .rounding(Rounding::same(10.0))
                        .min_size(vec2(ui.available_width(), 40.0));
                        if ui.add_enabled(!busy, btn).clicked() {
                            apply_now = true;
                        }
                        if ui
                            .add(
                                egui::Button::new("Generar paleta")
                                    .min_size(vec2(ui.available_width(), 34.0)),
                            )
                            .clicked()
                        {
                            mat = true;
                        }
                    });
            });
        if changed {
            self.commit();
        }
        if regen {
            self.run_matugen(ctx, e.path.clone(), e.is_video);
        }
        if rescale {
            if let Some(p) = self.cfg.wallpapers.get(&self.cfg.output).cloned() {
                let out = self.cfg.output.clone();
                self.apply(ctx, p, Some(out));
                apply_now = false;
            }
        }
        if apply_now {
            self.apply(ctx, e.path.clone(), None);
        }
        if mat {
            self.run_matugen(ctx, e.path.clone(), e.is_video);
        }
        if close {
            self.selected = None;
        }
    }

    // SECCION: AJUSTES
    fn settings(&mut self, ui: &mut egui::Ui, ctx: &egui::Context) {
        let mut changed = false;
        let mut remove: Option<String> = None;
        let mut add = false;
        egui::ScrollArea::vertical()
            .auto_shrink([false, false])
            .show(ui, |ui| {
                ui.label(RichText::new("Ajustes").size(24.0).strong());
                ui.add_space(6.0);
                card_frame().show(ui, |ui| {
                    ui.set_width(ui.available_width());
                    ui.label(RichText::new("Reproducción").size(15.0).strong());
                    ui.add_space(4.0);
                    egui::Grid::new("set_play")
                        .num_columns(2)
                        .spacing([28.0, 14.0])
                        .show(ui, |ui| {
                            ui.label("Salida por defecto");
                            egui::ComboBox::from_id_source("set_out")
                                .selected_text(if self.cfg.output == "*" {
                                    String::from("Todas las salidas")
                                } else {
                                    self.cfg.output.clone()
                                })
                                .show_ui(ui, |ui| {
                                    for o in self.outs.clone() {
                                        let label = if o == "*" {
                                            String::from("Todas las salidas")
                                        } else {
                                            o.clone()
                                        };
                                        if ui
                                            .selectable_value(
                                                &mut self.cfg.output,
                                                o.clone(),
                                                label,
                                            )
                                            .changed()
                                        {
                                            changed = true;
                                        }
                                    }
                                });
                            ui.end_row();
                            ui.label("Escala en esa salida");
                            let mut sc = self.cfg.scaling_for(&self.cfg.output);
                            let before = sc.clone();
                            ui.horizontal(|ui| {
                                for (k, l) in [
                                    ("fit", "Ajustar"),
                                    ("fill", "Llenar"),
                                    ("stretch", "Estirar"),
                                ] {
                                    ui.selectable_value(&mut sc, k.to_string(), l);
                                }
                            });
                            if sc != before {
                                self.cfg.scaling.insert(self.cfg.output.clone(), sc);
                                changed = true;
                            }
                            ui.end_row();
                            ui.label("Volumen");
                            ui.horizontal(|ui| {
                                if ui
                                    .add(egui::Slider::new(&mut self.cfg.volume, 0..=100))
                                    .changed()
                                {
                                    changed = true;
                                }
                                if ui.checkbox(&mut self.cfg.mute, "Silenciar").changed() {
                                    changed = true;
                                }
                            });
                            ui.end_row();
                        });
                });
                ui.add_space(4.0);
                card_frame().show(ui, |ui| {
                    ui.set_width(ui.available_width());
                    ui.label(RichText::new("Rendimiento").size(15.0).strong());
                    ui.add_space(4.0);
                    egui::Grid::new("set_perf")
                        .num_columns(2)
                        .spacing([28.0, 14.0])
                        .show(ui, |ui| {
                            ui.label("Decodificación (hwdec)");
                            ui.horizontal(|ui| {
                                for k in ["auto-safe", "vaapi", "nvdec", "no"] {
                                    if ui
                                        .selectable_value(&mut self.cfg.hwdec, k.to_string(), k)
                                        .changed()
                                    {
                                        changed = true;
                                    }
                                }
                            });
                            ui.end_row();
                            ui.label("Capa");
                            egui::ComboBox::from_id_source("set_layer")
                                .selected_text(self.cfg.layer.clone())
                                .show_ui(ui, |ui| {
                                    for k in ["background", "bottom"] {
                                        if ui
                                            .selectable_value(&mut self.cfg.layer, k.to_string(), k)
                                            .changed()
                                        {
                                            changed = true;
                                        }
                                    }
                                });
                            ui.end_row();
                        });
                    ui.label(
                        RichText::new(
                            "hwdec, capa y silencio inicial aplican al próximo video que arranque.",
                        )
                        .size(12.0)
                        .color(DIM),
                    );
                });
                ui.add_space(4.0);
                card_frame().show(ui, |ui| {
                    ui.set_width(ui.available_width());
                    ui.horizontal(|ui| {
                        ui.label(
                            RichText::new("Carpetas de la biblioteca")
                                .size(15.0)
                                .strong(),
                        );
                        ui.with_layout(Layout::right_to_left(Align::Center), |ui| {
                            if ui.button("+ Agregar").clicked() {
                                add = true;
                            }
                        });
                    });
                    ui.add_space(4.0);
                    for d in self.cfg.dirs.clone() {
                        ui.horizontal(|ui| {
                            let ok = Path::new(&d).is_dir();
                            ui.label(RichText::new(&d).color(if ok { TEXT } else { BAD }));
                            ui.with_layout(Layout::right_to_left(Align::Center), |ui| {
                                if ui.button("Quitar").clicked() {
                                    remove = Some(d.clone());
                                }
                            });
                        });
                    }
                });
            });
        if let Some(p) = remove {
            self.remove_dir(ctx, &p);
        }
        if add {
            self.pick_dir(ctx);
        }
        if changed {
            self.commit();
            self.vol_dirty = Some(Instant::now());
        }
    }

    // SECCION: ESTADO
    fn state_tab(&mut self, ui: &mut egui::Ui, ctx: &egui::Context) {
        let mut pause = false;
        let mut resume = false;
        let mut stop = false;
        let mut mat = false;
        let mut changed = false;
        egui::ScrollArea::vertical()
            .auto_shrink([false, false])
            .show(ui, |ui| {
                ui.label(RichText::new("Estado").size(24.0).strong());
                ui.add_space(6.0);
                card_frame().show(ui, |ui| {
                    ui.set_width(ui.available_width());
                    ui.label(RichText::new("Fondos activos").size(15.0).strong());
                    ui.add_space(4.0);
                    if self.cfg.wallpapers.is_empty() {
                        ui.label(RichText::new("ninguno").color(DIM));
                    } else {
                        let mut rows: Vec<(String, String)> = self
                            .cfg
                            .wallpapers
                            .iter()
                            .map(|(o, p)| (o.clone(), p.clone()))
                            .collect();
                        rows.sort();
                        egui::Grid::new("st_walls")
                            .num_columns(2)
                            .spacing([24.0, 8.0])
                            .show(ui, |ui| {
                                for (o, p) in rows {
                                    ui.label(
                                        RichText::new(if o == "*" { String::from("todas") } else { o })
                                            .color(ACCENT),
                                    );
                                    ui.label(RichText::new(middle_trim(&p, 80)).color(TEXT))
                                        .on_hover_text(p.clone());
                                    ui.end_row();
                                }
                            });
                    }
                });
                ui.add_space(4.0);
                card_frame().show(ui, |ui| {
                    ui.set_width(ui.available_width());
                    ui.label(RichText::new("Rendimiento").size(15.0).strong());
                    ui.add_space(4.0);
                    let frac = (self.status.ram as f32 / RAM_BUDGET as f32).min(1.0);
                    let col = if self.status.over {
                        BAD
                    } else if frac > 0.8 {
                        WARN
                    } else {
                        OK
                    };
                    ui.add(
                        egui::ProgressBar::new(frac)
                            .fill(col)
                            .text(format!("RAM {} / {} MB", self.status.ram, RAM_BUDGET)),
                    );
                    egui::Grid::new("st_info")
                        .num_columns(2)
                        .spacing([24.0, 8.0])
                        .show(ui, |ui| {
                            ui.label(RichText::new("Procesos").color(DIM));
                            ui.label(format!("{}", self.status.pids.len()));
                            ui.end_row();
                            ui.label(RichText::new("Reproducción").color(DIM));
                            ui.label(if !self.status.running {
                                "detenido"
                            } else if self.status.paused {
                                "pausado"
                            } else {
                                "activo"
                            });
                            ui.end_row();
                            ui.label(RichText::new("Compositor").color(DIM));
                            ui.label(self.compositor.clone());
                            ui.end_row();
                            ui.label(RichText::new("hwdec").color(DIM));
                            ui.label(self.cfg.hwdec.clone());
                            ui.end_row();
                            for s in self.status.socks.clone() {
                                ui.label(
                                    RichText::new(format!(
                                        "Salida {}",
                                        if s.output == "*" { String::from("todas") } else { s.output }
                                    ))
                                    .color(DIM),
                                );
                                ui.label(match s.pause {
                                    Some(true) => "pausada",
                                    Some(false) => "reproduciendo",
                                    None => "sin respuesta",
                                });
                                ui.end_row();
                            }
                        });
                    ui.add_space(4.0);
                    ui.horizontal(|ui| {
                        if ui.button("Pausar").clicked() {
                            pause = true;
                        }
                        if ui.button("Reanudar").clicked() {
                            resume = true;
                        }
                        if ui.button("Detener").clicked() {
                            stop = true;
                        }
                    });
                });
                ui.add_space(4.0);
                card_frame().show(ui, |ui| {
                    ui.set_width(ui.available_width());
                    ui.label(RichText::new("Fondos estáticos").size(15.0).strong());
                    ui.add_space(4.0);
                    ui.label(
                        RichText::new("Motor que pinta las imágenes")
                            .size(12.0)
                            .color(DIM),
                    );
                    ui.horizontal_wrapped(|ui| {
                        for (k, l) in [
                            ("auto", "Auto"),
                            ("builtin", "OozeWalls (capa propia)"),
                            ("awww", "awww"),
                            ("mpvpaper", "mpvpaper"),
                        ] {
                            if ui
                                .selectable_value(&mut self.cfg.static_backend, k.to_string(), l)
                                .changed()
                            {
                                changed = true;
                            }
                        }
                    });
                    ui.label(
                        RichText::new(
                            "Auto: awww si está instalado, si no la capa propia (pocos MB). mpvpaper solo como último recurso.",
                        )
                        .size(12.0)
                        .color(DIM),
                    );
                });
                ui.add_space(4.0);
                card_frame().show(ui, |ui| {
                    ui.set_width(ui.available_width());
                    ui.label(RichText::new("Animación al cambiar fondo").size(15.0).strong());
                    ui.add_space(4.0);
                    egui::Grid::new("set_anim")
                        .num_columns(2)
                        .spacing([28.0, 14.0])
                        .show(ui, |ui| {
                            ui.label("Transición");
                            egui::ComboBox::from_id_source("set_transition")
                                .selected_text(transition::label_of(&self.cfg.transition))
                                .show_ui(ui, |ui| {
                                    for (k, l) in transition::KINDS {
                                        if ui
                                            .selectable_value(
                                                &mut self.cfg.transition,
                                                k.to_string(),
                                                *l,
                                            )
                                            .changed()
                                        {
                                            changed = true;
                                        }
                                    }
                                });
                            ui.end_row();
                            ui.label("Duración");
                            let r = ui.add_enabled(
                                self.cfg.transition != "none",
                                egui::Slider::new(
                                    &mut self.cfg.transition_ms,
                                    transition::MIN_MS..=transition::MAX_MS,
                                )
                                .suffix(" ms"),
                            );
                            if r.drag_stopped() || (r.changed() && !r.dragged()) {
                                changed = true;
                            }
                            ui.end_row();
                        });
                    ui.label(
                        RichText::new(
                            "Imágenes: todas las animaciones (capa propia) o su equivalente en awww. Videos: desvanecer, deslizar y zoom; el resto se ve como desvanecer. Aplica al próximo cambio de fondo.",
                        )
                        .size(12.0)
                        .color(DIM),
                    );
                });
                ui.add_space(4.0);
                card_frame().show(ui, |ui| {
                    ui.set_width(ui.available_width());
                    ui.label(RichText::new("Paleta (matugen)").size(15.0).strong());
                    ui.add_space(4.0);
                    if ui
                        .checkbox(&mut self.cfg.palette_auto, "Generar al aplicar un fondo")
                        .changed()
                    {
                        changed = true;
                    }
                    ui.add_space(2.0);
                    ui.label(RichText::new("Esquema").size(12.0).color(DIM));
                    if scheme_chips(ui, &mut self.cfg.scheme) {
                        changed = true;
                    }
                    ui.add_space(2.0);
                    ui.horizontal_wrapped(|ui| {
                        ui.label(RichText::new("Modo").size(12.0).color(DIM));
                        for k in ["dark", "light"] {
                            if ui
                                .selectable_value(&mut self.cfg.palette_mode, k.to_string(), k)
                                .changed()
                            {
                                changed = true;
                            }
                        }
                        ui.label(RichText::new("Color fuente").size(12.0).color(DIM));
                        for i in 0..6u8 {
                            if ui
                                .selectable_value(&mut self.cfg.source_index, i, format!("{}", i + 1))
                                .changed()
                            {
                                changed = true;
                            }
                        }
                    });
                    ui.add_space(2.0);
                    ui.label(RichText::new("Archivo de colores").size(12.0).color(DIM));
                    let mut cf = if self.cfg.colors_file.is_empty() {
                        self.cfg.colors_path().to_string_lossy().to_string()
                    } else {
                        self.cfg.colors_file.clone()
                    };
                    if ui
                        .add(egui::TextEdit::singleline(&mut cf).desired_width(ui.available_width()))
                        .lost_focus()
                    {
                        let default = config::Config::default().colors_path().to_string_lossy().to_string();
                        self.cfg.colors_file = if cf == default { String::new() } else { cf };
                        changed = true;
                    }
                    ui.label(
                        RichText::new("OozeShell vigila ese JSON y recarga los colores solo.")
                            .size(12.0)
                            .color(DIM),
                    );
                    ui.add_space(4.0);
                    if ui.button("Generar del fondo actual").clicked() {
                        mat = true;
                    }
                });
            });
        if changed {
            self.commit();
        }
        if pause {
            self.ctl_pause(ctx, true);
        }
        if resume {
            self.ctl_pause(ctx, false);
        }
        if stop {
            self.ctl_stop(ctx);
        }
        if mat {
            let cur = self.status.current.clone();
            if cur.is_empty() {
                self.toast(String::from("no hay fondo actual"), true);
            } else {
                let vid = scan::is_video_path(Path::new(&cur));
                self.run_matugen(ctx, cur, vid);
            }
        }
    }

    // SECCION: TOAST
    fn toast_ui(&mut self, ctx: &egui::Context) {
        let snap = self
            .toast
            .as_ref()
            .map(|t| (t.text.clone(), t.bad, t.at.elapsed()));
        let (text, bad) = if let Some(a) = &self.applying {
            (format!("aplicando {}…", a), false)
        } else if let Some((t, b, age)) = snap {
            if age > Duration::from_millis(3500) {
                self.toast = None;
                return;
            }
            ctx.request_repaint_after(Duration::from_millis(400));
            (t, b)
        } else {
            return;
        };
        egui::Area::new(egui::Id::new("toast"))
            .order(egui::Order::Foreground)
            .anchor(Align2::RIGHT_BOTTOM, vec2(-20.0, -88.0))
            .interactable(false)
            .show(ctx, |ui| {
                egui::Frame::none()
                    .fill(CARD_HOVER)
                    .rounding(Rounding::same(10.0))
                    .stroke(Stroke::new(1.0, if bad { BAD } else { ACCENT }))
                    .inner_margin(egui::Margin::symmetric(14.0, 10.0))
                    .show(ui, |ui| {
                        ui.label(RichText::new(trim_chars(&text, 140)).color(TEXT));
                    });
            });
    }
}

impl eframe::App for Gui {
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) {
        self.pump(ctx);
        self.keys(ctx);
        self.now_bar(ctx);
        self.sidebar(ctx);
        if self.tab == 0 {
            self.detail(ctx);
        }
        egui::CentralPanel::default()
            .frame(
                egui::Frame::none()
                    .fill(BG)
                    .inner_margin(egui::Margin::symmetric(22.0, 16.0)),
            )
            .show(ctx, |ui| match self.tab {
                1 => self.settings(ui, ctx),
                2 => self.state_tab(ui, ctx),
                _ => self.library(ui, ctx),
            });
        self.toast_ui(ctx);
    }
}

fn main() -> eframe::Result<()> {
    let opts = eframe::NativeOptions {
        viewport: egui::ViewportBuilder::default()
            .with_inner_size([1200.0, 780.0])
            .with_min_inner_size([940.0, 580.0])
            .with_app_id("oozewalls")
            .with_title("OozeWalls"),
        ..Default::default()
    };
    eframe::run_native("OozeWalls", opts, Box::new(|cc| Ok(Box::new(Gui::new(cc)))))
}
