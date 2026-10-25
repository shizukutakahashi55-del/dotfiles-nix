// SECCION: GUI BIBLIOTECA CARPETAS AJUSTES ESTADO
// IPC: apply next prev stop pause resume toggle status list browse dirs dirs-add dirs-remove volume mute scaling hwdec matugen
use eframe::egui::{
    self, pos2, vec2, Align, Align2, Color32, FontFamily, FontId, Layout, Rect, RichText, Rounding,
    Sense, Stroke, TextStyle,
};
use oozewalls::{actions, config, engine, ipc, layerbg, matugen, outputs, scan, thumbs, transition};
use std::collections::HashMap;
use std::io::Write as _;
use std::path::{Path, PathBuf};
use std::sync::{
    atomic::{AtomicBool, AtomicI32, AtomicU32, AtomicU64, AtomicUsize, Ordering},
    mpsc::{channel, Receiver, Sender},
    Arc,
};
use std::time::{Duration, Instant};

// SECCION: PALETA
const OK: Color32 = Color32::from_rgb(74, 222, 128);
const WARN: Color32 = Color32::from_rgb(251, 191, 36);
const BAD: Color32 = Color32::from_rgb(248, 113, 113);
const RAM_BUDGET: u64 = 500;
const POLL: Duration = Duration::from_millis(1500);

struct Palette {
    id: &'static str,
    name_es: &'static str,
    name_en: &'static str,
    accent: Color32,
    accent_hover: Color32,
    accent_soft: Color32,
    pink: Color32,
    bg: Color32,
    panel: Color32,
    card: Color32,
    card_hover: Color32,
    border: Color32,
    border_hi: Color32,
    text: Color32,
    dim: Color32,
}

const fn rgb(r: u8, g: u8, b: u8) -> Color32 {
    Color32::from_rgb(r, g, b)
}

static PALETTES: [Palette; 6] = [
    Palette {
        id: "violet",
        name_es: "Violeta",
        name_en: "Violet",
        accent: rgb(139, 124, 246),
        accent_hover: rgb(167, 155, 255),
        accent_soft: rgb(40, 35, 72),
        pink: rgb(244, 114, 182),
        bg: rgb(10, 12, 18),
        panel: rgb(15, 18, 26),
        card: rgb(21, 25, 35),
        card_hover: rgb(29, 34, 47),
        border: rgb(40, 46, 62),
        border_hi: rgb(72, 80, 104),
        text: rgb(236, 239, 247),
        dim: rgb(139, 148, 168),
    },
    Palette {
        id: "ocean",
        name_es: "Océano",
        name_en: "Ocean",
        accent: rgb(56, 189, 248),
        accent_hover: rgb(125, 211, 252),
        accent_soft: rgb(12, 48, 70),
        pink: rgb(244, 114, 182),
        bg: rgb(8, 13, 20),
        panel: rgb(12, 18, 27),
        card: rgb(17, 25, 37),
        card_hover: rgb(24, 35, 51),
        border: rgb(34, 48, 66),
        border_hi: rgb(64, 84, 110),
        text: rgb(232, 240, 248),
        dim: rgb(131, 148, 168),
    },
    Palette {
        id: "emerald",
        name_es: "Esmeralda",
        name_en: "Emerald",
        accent: rgb(52, 211, 153),
        accent_hover: rgb(110, 231, 183),
        accent_soft: rgb(12, 52, 40),
        pink: rgb(244, 114, 182),
        bg: rgb(8, 14, 13),
        panel: rgb(12, 20, 19),
        card: rgb(17, 28, 26),
        card_hover: rgb(24, 39, 36),
        border: rgb(33, 52, 48),
        border_hi: rgb(62, 92, 84),
        text: rgb(232, 246, 240),
        dim: rgb(131, 160, 150),
    },
    Palette {
        id: "rose",
        name_es: "Rosa",
        name_en: "Rose",
        accent: rgb(251, 113, 133),
        accent_hover: rgb(253, 164, 175),
        accent_soft: rgb(74, 24, 36),
        pink: rgb(244, 114, 182),
        bg: rgb(16, 10, 13),
        panel: rgb(24, 15, 19),
        card: rgb(33, 21, 27),
        card_hover: rgb(46, 30, 38),
        border: rgb(62, 40, 50),
        border_hi: rgb(104, 72, 86),
        text: rgb(247, 236, 240),
        dim: rgb(168, 139, 150),
    },
    Palette {
        id: "amber",
        name_es: "Ámbar",
        name_en: "Amber",
        accent: rgb(251, 191, 36),
        accent_hover: rgb(252, 211, 77),
        accent_soft: rgb(66, 48, 10),
        pink: rgb(244, 114, 182),
        bg: rgb(15, 12, 8),
        panel: rgb(23, 19, 12),
        card: rgb(32, 27, 18),
        card_hover: rgb(44, 38, 25),
        border: rgb(62, 54, 36),
        border_hi: rgb(104, 92, 62),
        text: rgb(248, 243, 232),
        dim: rgb(168, 158, 139),
    },
    Palette {
        id: "graphite",
        name_es: "Grafito",
        name_en: "Graphite",
        accent: rgb(148, 163, 184),
        accent_hover: rgb(203, 213, 225),
        accent_soft: rgb(38, 44, 56),
        pink: rgb(244, 114, 182),
        bg: rgb(12, 12, 13),
        panel: rgb(18, 18, 20),
        card: rgb(25, 25, 28),
        card_hover: rgb(34, 34, 38),
        border: rgb(48, 48, 54),
        border_hi: rgb(82, 82, 92),
        text: rgb(240, 240, 243),
        dim: rgb(145, 145, 155),
    },
];

const FONT_LEVELS: [(&str, &str, &str, u32); 4] = [
    ("small", "Pequeña", "Small", 90),
    ("normal", "Normal", "Normal", 100),
    ("large", "Grande", "Large", 115),
    ("xlarge", "Muy grande", "Extra large", 130),
];

static PAL_IDX: AtomicUsize = AtomicUsize::new(0);
static FONT_PCT: AtomicU32 = AtomicU32::new(100);

fn pal() -> &'static Palette {
    &PALETTES[PAL_IDX.load(Ordering::Relaxed).min(PALETTES.len() - 1)]
}

fn fs(size: f32) -> f32 {
    size * FONT_PCT.load(Ordering::Relaxed) as f32 / 100.0
}

fn pf(size: f32) -> FontId {
    FontId::proportional(fs(size))
}

trait Scaled {
    fn sz(self, size: f32) -> Self;
}

impl Scaled for RichText {
    fn sz(self, size: f32) -> Self {
        self.size(fs(size))
    }
}

fn set_look(palette: &str, font: &str) {
    let idx = PALETTES.iter().position(|p| p.id == palette).unwrap_or(0);
    PAL_IDX.store(idx, Ordering::Relaxed);
    let pct = FONT_LEVELS
        .iter()
        .find(|l| l.0 == font)
        .map(|l| l.3)
        .unwrap_or(100);
    FONT_PCT.store(pct, Ordering::Relaxed);
}

fn palette_swatch(ui: &mut egui::Ui, p: &Palette, active: bool, en: bool) -> bool {
    let name = if en { p.name_en } else { p.name_es };
    let w = text_w(ui, name, 12.0) + 46.0;
    let (rect, resp) = ui.allocate_exact_size(vec2(w, 32.0), Sense::click());
    let fill = if resp.hovered() { p.card_hover } else { p.card };
    ui.painter().rect(
        rect,
        Rounding::same(10.0),
        fill,
        Stroke::new(
            if active { 2.0 } else { 1.0 },
            if active { p.accent } else { p.border },
        ),
    );
    let cy = rect.center().y;
    ui.painter()
        .circle_filled(pos2(rect.left() + 17.0, cy), 7.0, p.accent);
    ui.painter().text(
        pos2(rect.left() + 32.0, cy),
        Align2::LEFT_CENTER,
        name,
        pf(12.0),
        p.text,
    );
    resp.on_hover_cursor(egui::CursorIcon::PointingHand)
        .clicked()
}

macro_rules! tr {
    ($en:expr, $es:expr, $ing:expr) => {
        if $en {
            $ing
        } else {
            $es
        }
    };
}

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
    let sock_paths = ipc::discover();
    let socks: Vec<SockInfo> = sock_paths
        .iter()
        .map(|s| SockInfo {
            output: ipc::output_for_socket(s),
            pause: ipc::get_bool(s, "pause"),
        })
        .collect();
    let pids = engine::mpvpaper_pids();
    let mut all = pids.clone();
    all.extend(layerbg::pids());
    let ram = engine::rss_of(&all);
    let paused = socks.iter().any(|s| s.pause == Some(true))
        || (!pids.is_empty() && pids.iter().all(|p| engine::is_pid_stopped(*p)));
    Status {
        current: cfg.current.unwrap_or_default(),
        running: !pids.is_empty(),
        paused,
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
    Now {
        key: String,
        img: Option<(usize, usize, Vec<u8>)>,
    },
    Status(Status),
    View {
        gen: u64,
        folders: Vec<scan::Folder>,
        entries: Vec<scan::Entry>,
    },
    Outputs(Vec<String>, String),
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
    Fav(String),
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
        f.layout_no_wrap(text.to_string(), pf(size), Color32::WHITE)
            .size()
            .x
    })
}

fn draw_badge(ui: &egui::Ui, min: egui::Pos2, text: &str, bg: Color32, fg: Color32) -> f32 {
    let w = text_w(ui, text, 10.0) + 20.0;
    let r = Rect::from_min_size(min, vec2(w, 20.0));
    ui.painter().rect_filled(r, Rounding::same(6.0), bg);
    ui.painter().circle_filled(
        r.left_center() + vec2(9.0, 0.0),
        2.0,
        fg.gamma_multiply(0.85),
    );
    ui.painter().text(
        r.left_center() + vec2(15.0, 0.0),
        Align2::LEFT_CENTER,
        text,
        pf(9.5),
        fg,
    );
    w
}

fn nav_btn(ui: &mut egui::Ui, icon: &str, text: &str, active: bool) -> bool {
    let size = vec2(ui.available_width(), 38.0);
    let (rect, resp) = ui.allocate_exact_size(size, Sense::click());
    let bg = if active {
        pal().accent_soft
    } else if resp.hovered() {
        pal().card_hover
    } else {
        Color32::TRANSPARENT
    };
    ui.painter().rect_filled(rect, Rounding::same(10.0), bg);
    if active {
        let bar = Rect::from_min_size(
            rect.min + vec2(0.0, 9.0),
            vec2(2.5, rect.height() - 18.0),
        );
        ui.painter().rect_filled(bar, Rounding::same(2.0), pal().accent);
    }
    paint_icon(
        ui.painter(),
        icon,
        rect.left_center() + vec2(24.0, 0.0),
        16.0,
        if active { pal().accent } else { pal().dim },
    );
    ui.painter().with_clip_rect(rect).text(
        rect.left_center() + vec2(44.0, 0.0),
        Align2::LEFT_CENTER,
        text,
        pf(13.5),
        if active { pal().text } else { pal().dim },
    );
    resp.on_hover_cursor(egui::CursorIcon::PointingHand)
        .clicked()
}

fn side_row(
    ui: &mut egui::Ui,
    text: &str,
    count: Option<u32>,
    active: bool,
) -> egui::Response {
    let size = vec2(ui.available_width(), 32.0);
    let (rect, resp) = ui.allocate_exact_size(size, Sense::click());
    if active {
        ui.painter()
            .rect_filled(rect, Rounding::same(8.0), pal().accent_soft);
    } else if resp.hovered() {
        ui.painter()
            .rect_filled(rect, Rounding::same(8.0), pal().card_hover);
    }
    paint_icon(
        ui.painter(),
        "folder",
        rect.left_center() + vec2(19.0, 0.0),
        15.0,
        if active { pal().accent } else { pal().dim },
    );
    let label_max = if count.is_some() { 19 } else { 24 };
    ui.painter().with_clip_rect(rect).text(
        rect.left_center() + vec2(36.0, 0.0),
        Align2::LEFT_CENTER,
        trim_chars(text, label_max),
        pf(12.5),
        if active { pal().text } else { pal().dim },
    );
    if let Some(n) = count {
        let w = text_w(ui, &n.to_string(), 10.0) + 12.0;
        let pill = Rect::from_min_size(
            pos2(rect.right() - w - 8.0, rect.center().y - 8.0),
            vec2(w, 16.0),
        );
        ui.painter()
            .rect_filled(pill, Rounding::same(8.0), Color32::from_rgb(30, 35, 48));
        ui.painter().text(
            pill.center(),
            Align2::CENTER_CENTER,
            n.to_string(),
            pf(10.0),
            pal().dim,
        );
    }
    resp.on_hover_cursor(egui::CursorIcon::PointingHand)
}

fn filter_chip(ui: &mut egui::Ui, text: &str, active: bool, dot: Option<Color32>) -> bool {
    let w = text_w(ui, text, 12.0) + if dot.is_some() { 30.0 } else { 22.0 };
    let (rect, resp) = ui.allocate_exact_size(vec2(w, 28.0), Sense::click());
    let hot = resp.hovered();
    ui.painter().rect(
        rect,
        Rounding::same(14.0),
        if active {
            pal().accent_soft
        } else if hot {
            pal().card_hover
        } else {
            pal().card
        },
        Stroke::new(1.0, if active { pal().accent } else { pal().border }),
    );
    let mut x = rect.left() + 11.0;
    if let Some(c) = dot {
        ui.painter()
            .circle_filled(pos2(x + 2.0, rect.center().y), 2.5, c);
        x += 12.0;
    }
    ui.painter().text(
        pos2(x, rect.center().y),
        Align2::LEFT_CENTER,
        text,
        pf(12.0),
        if active { pal().accent } else { pal().dim },
    );
    resp.on_hover_cursor(egui::CursorIcon::PointingHand)
        .clicked()
}

fn folder_combo(
    ui: &mut egui::Ui,
    dirs: &[String],
    fav_only: bool,
    nav: Option<&str>,
    label: &str,
    width: f32,
    en: bool,
    pick: &mut Option<usize>,
) {
    egui::ComboBox::from_id_source("folder_dd")
        .width(width)
        .selected_text(RichText::new(label).sz(12.5).color(pal().text))
        .show_ui(ui, |ui| {
            if ui
                .selectable_label(fav_only, tr!(en, "Favoritos", "Favorites"))
                .clicked()
            {
                *pick = Some(1);
            }
            if ui
                .selectable_label(
                    !fav_only && nav.is_none(),
                    tr!(en, "Todas las carpetas", "All folders"),
                )
                .clicked()
            {
                *pick = Some(2);
            }
            ui.separator();
            for (i, d) in dirs.iter().enumerate() {
                let active = !fav_only
                    && nav
                        .map(|n| scan::is_inside(n, d))
                        .unwrap_or(false);
                if ui.selectable_label(active, short_name(d)).clicked() {
                    *pick = Some(3 + i);
                }
            }
        });
}

fn search_field(ui: &mut egui::Ui, value: &mut String, width: f32, en: bool) {
    let (rect, resp) = ui.allocate_exact_size(vec2(width, 38.0), Sense::click());
    let inner_rect = Rect::from_min_max(
        pos2(rect.left() + 34.0, rect.top() + 6.0),
        pos2(rect.right() - 10.0, rect.bottom() - 6.0),
    );
    let te = egui::TextEdit::singleline(value)
        .frame(false)
        .hint_text(tr!(en, "Buscar wallpapers…", "Search wallpapers…"))
        .desired_width(inner_rect.width())
        .text_color(pal().text)
        .font(pf(13.0));
    let edit = ui.put(inner_rect, te);
    let focused = edit.has_focus();
    ui.painter().rect(
        rect,
        Rounding::same(10.0),
        if focused { Color32::from_rgb(24, 29, 41) } else { pal().card },
        Stroke::new(1.0, if focused { pal().accent } else if resp.hovered() { pal().border_hi } else { pal().border }),
    );
    paint_icon(
        ui.painter(),
        "search",
        rect.left_center() + vec2(17.0, 0.0),
        15.0,
        if focused { pal().accent } else { pal().dim },
    );
    if resp.clicked() {
        edit.request_focus();
    }
}

fn primary_button(ui: &mut egui::Ui, label: &str, icon: &str, enabled: bool) -> bool {
    let (rect, resp) = ui.allocate_exact_size(vec2(ui.available_width(), 44.0), Sense::click());
    let hot = resp.hovered() && enabled;
    ui.painter().rect_filled(
        rect,
        Rounding::same(11.0),
        if !enabled {
            Color32::from_rgb(55, 50, 80)
        } else if hot {
            pal().accent_hover
        } else {
            pal().accent
        },
    );
    let fg = if enabled {
        Color32::from_rgb(12, 12, 18)
    } else {
        pal().dim
    };
    if !icon.is_empty() {
        paint_icon(
            ui.painter(),
            icon,
            rect.left_center() + vec2(24.0, 0.0),
            15.0,
            fg,
        );
    }
    ui.painter().text(
        rect.center() + vec2(if icon.is_empty() { 0.0 } else { 8.0 }, 0.0),
        Align2::CENTER_CENTER,
        label,
        pf(14.0),
        fg,
    );
    resp.on_hover_cursor(egui::CursorIcon::PointingHand).clicked() && enabled
}

fn secondary_button(ui: &mut egui::Ui, label: &str, icon: &str) -> bool {
    let (rect, resp) = ui.allocate_exact_size(vec2(ui.available_width(), 38.0), Sense::click());
    let hot = resp.hovered();
    ui.painter().rect(
        rect,
        Rounding::same(10.0),
        if hot { pal().card_hover } else { pal().card },
        Stroke::new(1.0, if hot { pal().border_hi } else { pal().border }),
    );
    paint_icon(
        ui.painter(),
        icon,
        rect.left_center() + vec2(22.0, 0.0),
        15.0,
        if hot { pal().text } else { pal().dim },
    );
    ui.painter().text(
        rect.center() + vec2(7.0, 0.0),
        Align2::CENTER_CENTER,
        label,
        pf(13.0),
        if hot { pal().text } else { pal().dim },
    );
    resp.on_hover_cursor(egui::CursorIcon::PointingHand)
        .clicked()
}

fn theme(ctx: &egui::Context) {
    let mut v = egui::Visuals::dark();
    v.panel_fill = pal().bg;
    v.window_fill = pal().panel;
    v.window_stroke = Stroke::new(1.0, pal().border);
    v.window_rounding = Rounding::same(14.0);
    v.menu_rounding = Rounding::same(12.0);
    v.extreme_bg_color = Color32::from_rgb(8, 10, 15);
    v.faint_bg_color = pal().card;
    v.selection.bg_fill = pal().accent_soft;
    v.selection.stroke = Stroke::new(1.0, pal().accent);
    v.widgets.noninteractive.bg_stroke = Stroke::new(1.0, pal().border);
    v.widgets.noninteractive.fg_stroke = Stroke::new(1.0, pal().text);
    v.widgets.inactive.rounding = Rounding::same(9.0);
    v.widgets.hovered.rounding = Rounding::same(9.0);
    v.widgets.active.rounding = Rounding::same(9.0);
    v.widgets.open.rounding = Rounding::same(9.0);
    v.widgets.inactive.weak_bg_fill = pal().card;
    v.widgets.inactive.bg_fill = pal().card;
    v.widgets.inactive.bg_stroke = Stroke::new(1.0, pal().border);
    v.widgets.inactive.fg_stroke = Stroke::new(1.0, pal().text);
    v.widgets.hovered.weak_bg_fill = pal().card_hover;
    v.widgets.hovered.bg_fill = pal().card_hover;
    v.widgets.hovered.bg_stroke = Stroke::new(1.0, pal().border_hi);
    v.widgets.hovered.fg_stroke = Stroke::new(1.0, Color32::WHITE);
    v.widgets.active.weak_bg_fill = pal().accent_soft;
    v.widgets.active.bg_fill = pal().accent_soft;
    v.widgets.active.bg_stroke = Stroke::new(1.0, pal().accent);
    ctx.set_visuals(v);
    ctx.style_mut(|s| {
        s.spacing.item_spacing = vec2(10.0, 8.0);
        s.spacing.button_padding = vec2(12.0, 7.0);
        s.spacing.interact_size.y = 30.0;
        s.animation_time = 0.12;
        s.text_styles.insert(
            TextStyle::Heading,
            FontId::new(fs(23.0), FontFamily::Proportional),
        );
        s.text_styles
            .insert(TextStyle::Body, FontId::new(fs(14.0), FontFamily::Proportional));
        s.text_styles.insert(
            TextStyle::Button,
            FontId::new(fs(13.5), FontFamily::Proportional),
        );
        s.text_styles.insert(
            TextStyle::Small,
            FontId::new(fs(11.5), FontFamily::Proportional),
        );
    });
}

fn card_frame() -> egui::Frame {
    egui::Frame::none()
        .fill(pal().card)
        .rounding(Rounding::same(14.0))
        .stroke(Stroke::new(1.0, pal().border))
        .inner_margin(egui::Margin::same(18.0))
}

fn section_label(ui: &mut egui::Ui, text: &str) {
    ui.add_space(4.0);
    ui.label(RichText::new(text).sz(11.5).strong().color(pal().dim));
}

fn chip(ui: &mut egui::Ui, text: &str, col: Color32) {
    egui::Frame::none()
        .fill(pal().card)
        .rounding(Rounding::same(6.0))
        .stroke(Stroke::new(1.0, pal().border))
        .inner_margin(egui::Margin::symmetric(8.0, 3.0))
        .show(ui, |ui| {
            ui.label(RichText::new(text).sz(11.5).color(col));
        });
}

fn arc_pts(c: egui::Pos2, r: f32, a0: f32, a1: f32, n: usize) -> Vec<egui::Pos2> {
    (0..=n)
        .map(|i| {
            let a = a0 + (a1 - a0) * i as f32 / n as f32;
            c + vec2(a.cos() * r, a.sin() * r)
        })
        .collect()
}

fn heart_pts(c: egui::Pos2, s: f32) -> Vec<egui::Pos2> {
    (0..=52)
        .map(|i| {
            let t = i as f32 / 52.0 * std::f32::consts::TAU;
            let x = 16.0 * t.sin().powi(3);
            let y = -(13.0 * t.cos()
                - 5.0 * (2.0 * t).cos()
                - 2.0 * (3.0 * t).cos()
                - (4.0 * t).cos());
            c + vec2(x, y - 2.5) * (s / 36.0)
        })
        .collect()
}

fn logo_mark(p: &egui::Painter, rect: Rect) {
    p.rect_filled(rect, Rounding::same(11.0), pal().accent_soft);
    p.rect_stroke(
        rect,
        Rounding::same(11.0),
        Stroke::new(1.0, pal().accent.gamma_multiply(0.55)),
    );
    let inner = rect.shrink(rect.width() * 0.22);
    p.circle_filled(
        pos2(
            inner.left() + inner.width() * 0.7,
            inner.top() + inner.height() * 0.28,
        ),
        inner.width() * 0.1,
        pal().accent,
    );
    let base = inner.bottom();
    p.add(egui::Shape::convex_polygon(
        vec![
            pos2(inner.left(), base),
            pos2(
                inner.left() + inner.width() * 0.46,
                inner.top() + inner.height() * 0.32,
            ),
            pos2(inner.left() + inner.width() * 0.84, base),
        ],
        pal().accent,
        Stroke::NONE,
    ));
    p.add(egui::Shape::convex_polygon(
        vec![
            pos2(inner.left() + inner.width() * 0.36, base),
            pos2(
                inner.left() + inner.width() * 0.68,
                inner.top() + inner.height() * 0.58,
            ),
            pos2(inner.right(), base),
        ],
        pal().accent_hover,
        Stroke::NONE,
    ));
}

fn paint_icon(p: &egui::Painter, kind: &str, c: egui::Pos2, s: f32, col: Color32) {
    let h = s * 0.5;
    let st = Stroke::new(1.7, col);
    let tri = |pts: Vec<egui::Pos2>| {
        p.add(egui::Shape::convex_polygon(pts, col, Stroke::NONE));
    };
    match kind {
        "stop" => {
            p.rect_filled(
                Rect::from_center_size(c, vec2(s * 0.58, s * 0.58)),
                Rounding::same(2.0),
                col,
            );
        }
        "play" => tri(vec![
            c + vec2(-h * 0.48, -h * 0.82),
            c + vec2(h * 0.82, 0.0),
            c + vec2(-h * 0.48, h * 0.82),
        ]),
        "next" => {
            tri(vec![
                c + vec2(-h * 0.78, -h * 0.78),
                c + vec2(h * 0.5, 0.0),
                c + vec2(-h * 0.78, h * 0.78),
            ]);
            p.rect_filled(
                Rect::from_center_size(c + vec2(h * 0.76, 0.0), vec2(2.0, h * 1.52)),
                Rounding::same(1.0),
                col,
            );
        }
        "prev" => {
            tri(vec![
                c + vec2(h * 0.78, -h * 0.78),
                c + vec2(-h * 0.5, 0.0),
                c + vec2(h * 0.78, h * 0.78),
            ]);
            p.rect_filled(
                Rect::from_center_size(c + vec2(-h * 0.76, 0.0), vec2(2.0, h * 1.52)),
                Rounding::same(1.0),
                col,
            );
        }
        "pause" => {
            for dx in [-h * 0.4, h * 0.4] {
                p.rect_filled(
                    Rect::from_center_size(c + vec2(dx, 0.0), vec2(h * 0.52, h * 1.62)),
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
        "check" => {
            p.line_segment([c + vec2(-h * 0.7, 0.0), c + vec2(-h * 0.15, h * 0.55)], st);
            p.line_segment([c + vec2(-h * 0.15, h * 0.55), c + vec2(h * 0.72, -h * 0.55)], st);
        }
        "plus" => {
            p.line_segment([c + vec2(-h * 0.7, 0.0), c + vec2(h * 0.7, 0.0)], st);
            p.line_segment([c + vec2(0.0, -h * 0.7), c + vec2(0.0, h * 0.7)], st);
        }
        "chevron" => {
            p.line_segment([c + vec2(-h * 0.45, -h * 0.22), c + vec2(0.0, h * 0.28)], st);
            p.line_segment([c + vec2(0.0, h * 0.28), c + vec2(h * 0.45, -h * 0.22)], st);
        }
        "update" => {
            let r = h * 0.72;
            p.add(egui::Shape::line(
                arc_pts(c, r, 0.7, 5.55, 24),
                st,
            ));
            let e = c + vec2(0.7f32.cos() * r, 0.7f32.sin() * r);
            tri(vec![
                e + vec2(-h * 0.1, -h * 0.58),
                e + vec2(h * 0.6, h * 0.05),
                e + vec2(-h * 0.5, h * 0.28),
            ]);
        }
        "search" => {
            p.circle_stroke(c + vec2(-h * 0.12, -h * 0.12), h * 0.58, st);
            p.line_segment(
                [
                    c + vec2(h * 0.28, h * 0.28),
                    c + vec2(h * 0.78, h * 0.78),
                ],
                st,
            );
        }
        "library" => {
            let d = s * 0.31;
            let g = s * 0.07;
            for (i, j) in [(0.0, 0.0), (1.0, 0.0), (0.0, 1.0), (1.0, 1.0)] {
                let r = Rect::from_min_size(
                    c + vec2(i * (d + g) - d - g * 0.5, j * (d + g) - d - g * 0.5),
                    vec2(d, d),
                );
                p.rect_filled(r, Rounding::same(2.0), col);
            }
        }
        "settings" => {
            for (i, k) in [(-0.55f32, -0.22f32), (0.0, 0.3f32), (0.55, -0.05f32)] {
                let y = c.y + i * s;
                p.line_segment(
                    [pos2(c.x - h * 0.8, y), pos2(c.x + h * 0.8, y)],
                    Stroke::new(1.4, col),
                );
                p.circle_filled(pos2(c.x + k * s, y), s * 0.11, col);
            }
        }
        "activity" => {
            let pts = vec![
                c + vec2(-h * 0.88, h * 0.05),
                c + vec2(-h * 0.5, h * 0.05),
                c + vec2(-h * 0.22, -h * 0.55),
                c + vec2(h * 0.08, h * 0.62),
                c + vec2(h * 0.38, -h * 0.28),
                c + vec2(h * 0.6, h * 0.05),
                c + vec2(h * 0.88, h * 0.05),
            ];
            p.add(egui::Shape::line(pts, Stroke::new(1.6, col)));
        }
        "folder" => {
            p.rect_filled(
                Rect::from_min_size(
                    c + vec2(-h * 0.78, -h * 0.62),
                    vec2(s * 0.36, s * 0.22),
                ),
                Rounding::same(2.0),
                col,
            );
            p.rect_filled(
                Rect::from_min_size(
                    c + vec2(-h * 0.78, -h * 0.44),
                    vec2(s * 0.78, s * 0.62),
                ),
                Rounding::same(3.0),
                col,
            );
        }
        "folder-plus" => {
            p.rect_filled(
                Rect::from_min_size(
                    c + vec2(-h * 0.85, -h * 0.68),
                    vec2(s * 0.36, s * 0.22),
                ),
                Rounding::same(2.0),
                col,
            );
            p.rect_filled(
                Rect::from_min_size(
                    c + vec2(-h * 0.85, -h * 0.5),
                    vec2(s * 0.82, s * 0.62),
                ),
                Rounding::same(3.0),
                col,
            );
            let pc = c + vec2(h * 0.5, h * 0.75);
            p.circle_filled(pc, s * 0.27, pal().panel);
            p.line_segment(
                [pc + vec2(-s * 0.12, 0.0), pc + vec2(s * 0.12, 0.0)],
                Stroke::new(1.4, col),
            );
            p.line_segment(
                [pc + vec2(0.0, -s * 0.12), pc + vec2(0.0, s * 0.12)],
                Stroke::new(1.4, col),
            );
        }
        "file" => {
            let r = Rect::from_center_size(c, vec2(s * 0.6, s * 0.76));
            p.rect_stroke(r, Rounding::same(2.5), st);
            let d = r.width() * 0.28;
            p.line_segment(
                [pos2(r.right() - d, r.top()), pos2(r.right(), r.top() + d)],
                st,
            );
            for k in 0..2 {
                let y = r.top() + r.height() * (0.55 + 0.15 * k as f32);
                p.line_segment(
                    [pos2(r.left() + 4.0, y), pos2(r.right() - 4.0, y)],
                    Stroke::new(1.2, col),
                );
            }
        }
        "heart" | "heart-fill" => {
            if kind == "heart" {
                p.add(egui::Shape::closed_line(heart_pts(c, s), st));
            } else {
                p.circle_filled(c + vec2(-s * 0.16, -s * 0.13), s * 0.2, col);
                p.circle_filled(c + vec2(s * 0.16, -s * 0.13), s * 0.2, col);
                tri(vec![
                    c + vec2(-s * 0.35, -s * 0.06),
                    c + vec2(s * 0.35, -s * 0.06),
                    c + vec2(0.0, s * 0.38),
                ]);
            }
        }
        "volume" => {
            tri(vec![
                c + vec2(-h * 0.68, -h * 0.22),
                c + vec2(-h * 0.34, -h * 0.22),
                c + vec2(-h * 0.34, h * 0.22),
            ]);
            p.add(egui::Shape::convex_polygon(
                vec![
                    c + vec2(-h * 0.68, -h * 0.22),
                    c + vec2(-h * 0.68, h * 0.22),
                    c + vec2(-h * 0.2, h * 0.45),
                    c + vec2(-h * 0.2, -h * 0.45),
                ],
                col,
                Stroke::NONE,
            ));
            p.add(egui::Shape::line(
                arc_pts(c + vec2(-h * 0.05, 0.0), s * 0.35, -0.85, 0.85, 10),
                Stroke::new(1.5, col),
            ));
            p.add(egui::Shape::line(
                arc_pts(c + vec2(-h * 0.05, 0.0), s * 0.62, -0.85, 0.85, 12),
                Stroke::new(1.5, col),
            ));
        }
        "mute" => {
            p.add(egui::Shape::convex_polygon(
                vec![
                    c + vec2(-h * 0.72, -h * 0.2),
                    c + vec2(-h * 0.6, -h * 0.2),
                    c + vec2(-h * 0.12, -h * 0.46),
                    c + vec2(-h * 0.12, h * 0.46),
                    c + vec2(-h * 0.6, h * 0.2),
                    c + vec2(-h * 0.72, h * 0.2),
                ],
                col,
                Stroke::NONE,
            ));
            let d = s * 0.22;
            p.line_segment(
                [c + vec2(h * 0.2, -d), c + vec2(h * 0.7, d)],
                Stroke::new(1.6, col),
            );
            p.line_segment(
                [c + vec2(h * 0.2, d), c + vec2(h * 0.7, -d)],
                Stroke::new(1.6, col),
            );
        }
        "monitor" => {
            let r = Rect::from_center_size(c + vec2(0.0, -h * 0.12), vec2(s * 0.82, s * 0.58));
            p.rect_stroke(r, Rounding::same(3.0), st);
            p.line_segment(
                [
                    c + vec2(0.0, r.bottom()),
                    c + vec2(0.0, h * 0.55),
                ],
                st,
            );
            p.line_segment(
                [
                    c + vec2(-s * 0.2, h * 0.55),
                    c + vec2(s * 0.2, h * 0.55),
                ],
                st,
            );
        }
        "palette" => {
            p.circle_stroke(c, h * 0.72, st);
            for k in 0..3 {
                let a = -0.9 + k as f32 * 0.9;
                p.circle_filled(
                    c + vec2(a.cos() * h * 0.36, a.sin() * h * 0.36),
                    s * 0.075,
                    col,
                );
            }
        }
        "sparkle" => {
            let r = h * 0.82;
            tri(vec![
                c + vec2(0.0, -r),
                c + vec2(r * 0.22, 0.0),
                c + vec2(0.0, r),
                c + vec2(-r * 0.22, 0.0),
            ]);
            tri(vec![
                c + vec2(-r, 0.0),
                c + vec2(0.0, -r * 0.22),
                c + vec2(r, 0.0),
                c + vec2(0.0, r * 0.22),
            ]);
        }
        "image" => {
            let r = Rect::from_center_size(c, vec2(s * 0.8, s * 0.68));
            p.rect_stroke(r, Rounding::same(2.5), Stroke::new(1.3, col));
            p.circle_filled(r.left_top() + vec2(r.width() * 0.72, r.height() * 0.28), s * 0.07, col);
            tri(vec![
                r.left_bottom() + vec2(r.width() * 0.12, -r.height() * 0.1),
                r.left_bottom() + vec2(r.width() * 0.42, -r.height() * 0.52),
                r.left_bottom() + vec2(r.width() * 0.72, -r.height() * 0.18),
            ]);
        }
        "video" => {
            let r = Rect::from_center_size(c, vec2(s * 0.8, s * 0.62));
            p.rect_stroke(r, Rounding::same(3.0), Stroke::new(1.3, col));
            tri(vec![
                c + vec2(-h * 0.15, -h * 0.24),
                c + vec2(h * 0.3, 0.0),
                c + vec2(-h * 0.15, h * 0.24),
            ]);
        }
        "trash" => {
            let r = Rect::from_min_size(
                c + vec2(-h * 0.5, -h * 0.45),
                vec2(s * 0.5, s * 0.72),
            );
            p.rect_stroke(r, Rounding::same(2.0), Stroke::new(1.4, col));
            p.line_segment(
                [c + vec2(-h * 0.7, -h * 0.58), c + vec2(h * 0.7, -h * 0.58)],
                Stroke::new(1.4, col),
            );
            p.line_segment(
                [c + vec2(-h * 0.2, -h * 0.74), c + vec2(h * 0.2, -h * 0.74)],
                Stroke::new(1.4, col),
            );
        }
        "chip" => {
            let r = Rect::from_center_size(c, vec2(s * 0.55, s * 0.55));
            p.rect_stroke(r, Rounding::same(2.0), Stroke::new(1.3, col));
            p.rect_stroke(r.shrink(s * 0.12), Rounding::same(1.0), Stroke::new(1.0, col));
            for k in [-1.0f32, 0.0, 1.0] {
                let d = k * s * 0.2;
                p.line_segment(
                    [c + vec2(d, -h * 0.68), c + vec2(d, -h * 0.4)],
                    Stroke::new(1.2, col),
                );
                p.line_segment(
                    [c + vec2(d, h * 0.4), c + vec2(d, h * 0.68)],
                    Stroke::new(1.2, col),
                );
            }
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
        if hot { pal().card_hover } else { pal().card },
        Stroke::new(1.0, if hot { pal().accent } else { pal().border }),
    );
    paint_icon(
        ui.painter(),
        kind,
        rect.center(),
        16.0,
        if hot { Color32::WHITE } else { pal().text },
    );
    resp.on_hover_cursor(egui::CursorIcon::PointingHand)
}

fn scheme_chips(ui: &mut egui::Ui, current: &mut String) -> bool {
    let mut changed = false;
    ui.horizontal_wrapped(|ui| {
        ui.spacing_mut().item_spacing = vec2(6.0, 6.0);
        for (name, label) in matugen::SCHEMES {
            let active = current.as_str() == *name;
            let b = egui::Button::new(RichText::new(*label).sz(12.0).color(if active {
                pal().accent
            } else {
                pal().text
            }))
            .fill(if active { pal().accent_soft } else { pal().card })
            .stroke(Stroke::new(1.0, if active { pal().accent } else { pal().border }))
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
    pal().dim
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
                    if on { Color32::WHITE } else { pal().border },
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
                pf(11.0),
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

fn round_btn(
    ui: &mut egui::Ui,
    rect: Rect,
    id: egui::Id,
    kind: &str,
    primary: bool,
    enabled: bool,
) -> bool {
    let resp = ui.interact(rect, id, Sense::click());
    let hot = resp.hovered() && enabled;
    let r = rect.width() * 0.5;
    if primary {
        ui.painter().circle_filled(
            rect.center(),
            r,
            if hot {
                pal().accent_hover
            } else if enabled {
                pal().accent
            } else {
                Color32::from_rgb(55, 50, 80)
            },
        );
    } else if hot {
        ui.painter()
            .circle_filled(rect.center(), r, pal().card_hover);
    }
    let fg = if !enabled {
        pal().dim
    } else if primary {
        Color32::from_rgb(12, 12, 18)
    } else if hot {
        pal().text
    } else {
        pal().dim
    };
    paint_icon(ui.painter(), kind, rect.center(), rect.width() * 0.44, fg);
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
    fav_only: bool,
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
    now_pending: bool,
    tx: Sender<Msg>,
    rx: Receiver<Msg>,
    thumb_gen: Arc<AtomicU64>,
    view_gen: Arc<AtomicU64>,
    active: Arc<AtomicBool>,
    heartbeat: Arc<AtomicU64>,
    nudge: Sender<()>,
    loading: bool,
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
        let cfg = config::Config::load();
        set_look(&cfg.ui_palette, &cfg.ui_font);
        theme(&cc.egui_ctx);
        let compositor = if cfg.language == "en" {
            String::from("detecting")
        } else {
            String::from("detectando")
        };
        let (tx, rx) = channel();
        let (nudge, _) = channel();
        let active = Arc::new(AtomicBool::new(true));
        let heartbeat = Arc::new(AtomicU64::new(0));
        let mut outs = vec![String::from("*")];
        if !outs.contains(&cfg.output) {
            outs.push(cfg.output.clone());
        }
        let mut app = Self {
            cfg,
            outs,
            compositor,
            nav: None,
            fav_only: false,
            folders: Vec::new(),
            entries: Vec::new(),
            selected: None,
            scroll_to: None,
            filter: String::new(),
            kind: 0,
            sort: 0,
            card: 260.0,
            cols: 3,
            tab: 0,
            status: Status::default(),
            textures: HashMap::new(),
            now_key: String::new(),
            now_tex: None,
            now_pending: false,
            tx,
            rx,
            thumb_gen: Arc::new(AtomicU64::new(0)),
            view_gen: Arc::new(AtomicU64::new(0)),
            active,
            heartbeat,
            nudge,
            loading: true,
            applying: None,
            picking: false,
            toast: None,
            vol_dirty: None,
            swatches: Vec::new(),
            swatch_key: String::new(),
            probing: false,
        };
        app.spawn_status_worker(&cc.egui_ctx);
        app.spawn_outputs(&cc.egui_ctx);
        if std::env::var_os("OOZEWALLS_GUI_WATCHDOG").is_some() {
            install_watchdog(app.heartbeat.clone(), app.active.clone());
        }
        app.load_view(&cc.egui_ctx);
        app
    }

    fn spawn_status_worker(&mut self, ctx: &egui::Context) {
        let tx = self.tx.clone();
        let ctx = ctx.clone();
        let active = self.active.clone();
        let (nudge, nrx) = channel::<()>();
        self.nudge = nudge;
        std::thread::spawn(move || loop {
            let _ = nrx.recv_timeout(POLL);
            if !active.load(Ordering::Relaxed) {
                continue;
            }
            let st = read_status();
            if tx.send(Msg::Status(st)).is_err() {
                break;
            }
            if active.load(Ordering::Relaxed) {
                ctx.request_repaint();
            }
        });
    }

    fn spawn_outputs(&self, ctx: &egui::Context) {
        let tx = self.tx.clone();
        let ctx = ctx.clone();
        let active = self.active.clone();
        std::thread::spawn(move || {
            let comp = outputs::detect_compositor();
            let mut names: Vec<String> = outputs::detect().into_iter().map(|o| o.name).collect();
            names.sort();
            names.dedup();
            let _ = tx.send(Msg::Outputs(names, comp));
            if active.load(Ordering::Relaxed) {
                ctx.request_repaint();
            }
        });
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
        disk.favorites = mine.favorites;
        disk.static_backend = mine.static_backend;
        disk.transition = mine.transition;
        disk.transition_ms = mine.transition_ms;
        disk.language = mine.language;
        disk.ui_palette = mine.ui_palette;
        disk.ui_font = mine.ui_font;
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
        self.cfg.favorites = fresh.favorites;
    }

    fn task<F>(&self, ctx: &egui::Context, f: F)
    where
        F: FnOnce() -> Result<String, String> + Send + 'static,
    {
        let tx = self.tx.clone();
        let ctx = ctx.clone();
        let active = self.active.clone();
        std::thread::spawn(move || {
            let r = std::panic::catch_unwind(std::panic::AssertUnwindSafe(f))
                .unwrap_or_else(|_| Err(String::from("error interno")));
            let _ = tx.send(Msg::Task(r));
            if active.load(Ordering::Relaxed) {
                ctx.request_repaint();
            }
        });
    }

    // SECCION: BIBLIOTECA CARGA NAVEGACION
    fn load_view(&mut self, ctx: &egui::Context) {
        let gen = self.view_gen.fetch_add(1, Ordering::Relaxed) + 1;
        self.loading = true;
        let nav = self.nav.clone();
        let favs = if self.fav_only {
            Some(self.cfg.favorites.clone())
        } else {
            None
        };
        let dirs = self.cfg.dirs.clone();
        let tx = self.tx.clone();
        let ctx2 = ctx.clone();
        let active = self.active.clone();
        std::thread::spawn(move || {
            let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
                if let Some(favs) = favs {
                    let entries = favs.iter().filter_map(|p| scan::entry_for(p)).collect();
                    (Vec::new(), entries)
                } else {
                    match nav {
                        Some(p) => scan::list_dir(&p),
                        None => (
                            dirs.iter().map(|d| scan::folder_info(d)).collect(),
                            Vec::new(),
                        ),
                    }
                }
            }));
            let (folders, entries) = result.unwrap_or_default();
            let _ = tx.send(Msg::View {
                gen,
                folders,
                entries,
            });
            if active.load(Ordering::Relaxed) {
                ctx2.request_repaint();
            }
        });
    }

    fn start_thumbs(&mut self, ctx: &egui::Context) {
        if !self.active.load(Ordering::Relaxed) {
            return;
        }
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
            let active = self.active.clone();
            std::thread::spawn(move || {
                for (path, vid) in part {
                    if cur.load(Ordering::Relaxed) != gen || !active.load(Ordering::Relaxed) {
                        break;
                    }
                    let thumb =
                        std::panic::catch_unwind(|| thumbs::load_cached(&path, vid))
                            .unwrap_or(None);
                    if let Some((w, h, raw)) = thumb {
                        let m = Msg::Thumb {
                            gen,
                            path,
                            size: [w, h],
                            rgba: raw,
                        };
                        if tx.send(m).is_err() {
                            break;
                        }
                        if active.load(Ordering::Relaxed) {
                            ctx.request_repaint();
                        }
                    }
                }
            });
        }
    }

    fn open(&mut self, ctx: &egui::Context, path: Option<String>) {
        self.nav = path;
        self.fav_only = false;
        self.selected = None;
        self.textures.clear();
        self.filter.clear();
        self.tab = 0;
        self.load_view(ctx);
    }

    fn open_favs(&mut self, ctx: &egui::Context) {
        self.nav = None;
        self.fav_only = true;
        self.selected = None;
        self.textures.clear();
        self.filter.clear();
        self.tab = 0;
        self.load_view(ctx);
    }

    fn visible(&self) -> (Vec<scan::Folder>, Vec<scan::Entry>) {
        let f = self.filter.trim().to_lowercase();
        let folders: Vec<scan::Folder> = if self.fav_only {
            Vec::new()
        } else {
            self.folders
                .iter()
                .filter(|x| f.is_empty() || x.name.to_lowercase().contains(&f))
                .cloned()
                .collect()
        };
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
        if self.fav_only {
            return v;
        }
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
                if self.fav_only {
                    self.open(ctx, None);
                    return;
                }
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
            Act::Fav(p) => {
                if let Some(i) = self.cfg.favorites.iter().position(|f| f == &p) {
                    self.cfg.favorites.remove(i);
                } else {
                    self.cfg.favorites.push(p.clone());
                    self.cfg.favorites.sort();
                    self.cfg.favorites.dedup();
                }
                self.commit();
                if self.fav_only {
                    self.load_view(ctx);
                }
            }
        }
    }

    fn apply(&mut self, ctx: &egui::Context, path: String, out: Option<String>) {
        if self.applying.is_some() {
            return;
        }
        let out = out.unwrap_or_else(|| self.cfg.output.clone());
        self.applying = Some(short_name(&path));
        let en = self.cfg.language == "en";
        let tx = self.tx.clone();
        let ctx = ctx.clone();
        let active = self.active.clone();
        std::thread::spawn(move || {
            let r = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
                actions::apply_file(&path, &out)
            }))
            .unwrap_or_else(|_| Err(String::from("error interno al aplicar")));
            let r = r.map(|_| {
                format!(
                    "{} {}",
                    tr!(en, "aplicado", "applied"),
                    short_name(&path)
                )
            });
            let _ = tx.send(Msg::Applied(r));
            if active.load(Ordering::Relaxed) {
                ctx.request_repaint();
            }
        });
    }

    fn ctl_step(&self, ctx: &egui::Context, dir: i32) {
        let out = self.cfg.output.clone();
        let en = self.cfg.language == "en";
        self.task(ctx, move || {
            actions::step(dir, &out, false)
                .map(|_| String::from(tr!(en, "aplicado", "applied")))
        });
    }

    fn ctl_toggle(&self, ctx: &egui::Context) {
        let en = self.cfg.language == "en";
        self.task(ctx, move || {
            let p = engine::toggle_all();
            Ok(String::from(if p {
                tr!(en, "pausado", "paused")
            } else {
                tr!(en, "reanudado", "resumed")
            }))
        });
    }

    fn ctl_pause(&self, ctx: &egui::Context, pause: bool) {
        let en = self.cfg.language == "en";
        self.task(ctx, move || {
            if pause {
                engine::pause_all();
                Ok(String::from(tr!(en, "pausado", "paused")))
            } else {
                engine::resume_all();
                Ok(String::from(tr!(en, "reanudado", "resumed")))
            }
        });
    }

    fn ctl_stop(&self, ctx: &egui::Context) {
        let out = self.cfg.output.clone();
        let en = self.cfg.language == "en";
        self.task(ctx, move || {
            actions::stop_out(&out);
            Ok(format!(
                "{} {}",
                tr!(en, "detenido en", "stopped on"),
                out
            ))
        });
    }

    fn palette_src(&mut self, path: &str, is_video: bool) -> Option<String> {
        if !is_video {
            return Some(path.to_string());
        }
        match thumbs::cached_path(path) {
            Some(p) => Some(p.to_string_lossy().to_string()),
            None => {
                self.toast(
                    String::from(tr!(
                        self.cfg.language == "en",
                        "sin miniatura para la paleta",
                        "no thumbnail for the palette"
                    )),
                    true,
                );
                None
            }
        }
    }

    fn run_matugen(&mut self, ctx: &egui::Context, path: String, is_video: bool) {
        let Some(src) = self.palette_src(&path, is_video) else {
            return;
        };
        let cfg = self.cfg.clone();
        let en = self.cfg.language == "en";
        self.task(ctx, move || {
            actions::run_palette(&cfg, &src)
                .map(|_| String::from(tr!(en, "paleta generada", "palette generated")))
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
        let active = self.active.clone();
        std::thread::spawn(move || {
            let v = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
                matugen::probe(&src, &mode, &scheme)
            }))
            .unwrap_or_default();
            let _ = tx.send(Msg::Swatches(key, v));
            if active.load(Ordering::Relaxed) {
                ctx.request_repaint();
            }
        });
    }

    fn pick_dir(&mut self, ctx: &egui::Context) {
        if self.picking {
            return;
        }
        self.picking = true;
        let tx = self.tx.clone();
        let ctx = ctx.clone();
        let active = self.active.clone();
        std::thread::spawn(move || {
            let p = std::panic::catch_unwind(|| rfd::FileDialog::new().pick_folder())
                .unwrap_or(None);
            let _ = tx.send(Msg::PickDir(p));
            if active.load(Ordering::Relaxed) {
                ctx.request_repaint();
            }
        });
    }

    fn pick_file(&mut self, ctx: &egui::Context) {
        if self.picking {
            return;
        }
        self.picking = true;
        let tx = self.tx.clone();
        let ctx = ctx.clone();
        let active = self.active.clone();
        std::thread::spawn(move || {
            let p = std::panic::catch_unwind(|| {
                rfd::FileDialog::new()
                    .add_filter(
                        "Media",
                        &[
                            "mp4", "mkv", "webm", "mov", "avi", "m4v", "png", "jpg", "jpeg",
                            "webp", "gif",
                        ],
                    )
                    .pick_file()
            })
            .unwrap_or(None);
            let _ = tx.send(Msg::PickFile(p));
            if active.load(Ordering::Relaxed) {
                ctx.request_repaint();
            }
        });
    }

    fn add_dir(&mut self, ctx: &egui::Context, full: String) {
        let en = self.cfg.language == "en";
        if !Path::new(&full).is_dir() {
            self.toast(
                format!("{} {}", tr!(en, "no es carpeta", "not a folder"), full),
                true,
            );
            return;
        }
        if !self.cfg.dirs.contains(&full) {
            self.cfg.dirs.push(full.clone());
            self.commit();
        }
        self.toast(
            format!("{} {}", tr!(en, "agregada", "added"), short_name(&full)),
            false,
        );
        self.open(ctx, Some(full));
    }

    fn remove_dir(&mut self, ctx: &egui::Context, path: &str) {
        let en = self.cfg.language == "en";
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
        self.toast(
            format!("{} {}", tr!(en, "quitada", "removed"), short_name(path)),
            false,
        );
    }

    // SECCION: PUMP TECLAS
    fn pump(&mut self, ctx: &egui::Context, active: bool) {
        let mut budget = 12usize;
        while budget > 0 {
            let m = match self.rx.try_recv() {
                Ok(m) => m,
                Err(_) => break,
            };
            budget -= 1;
            match m {
                Msg::Thumb {
                    gen,
                    path,
                    size,
                    rgba,
                } => {
                    if !active || gen != self.thumb_gen.load(Ordering::Relaxed) {
                        continue;
                    }
                    let img = egui::ColorImage::from_rgba_unmultiplied(size, &rgba);
                    let tex = ctx.load_texture(path.clone(), img, egui::TextureOptions::LINEAR);
                    self.textures.insert(path, tex);
                }
                Msg::Now { key, img } => {
                    self.now_pending = false;
                    if !active || key != self.now_key {
                        continue;
                    }
                    self.now_tex = img.map(|(w, h, raw)| {
                        let img = egui::ColorImage::from_rgba_unmultiplied([w, h], &raw);
                        ctx.load_texture("now", img, egui::TextureOptions::LINEAR)
                    });
                }
                Msg::Status(s) => {
                    self.status = s;
                }
                Msg::View {
                    gen,
                    folders,
                    entries,
                } => {
                    if gen != self.view_gen.load(Ordering::Relaxed) {
                        continue;
                    }
                    self.folders = folders;
                    self.entries = entries;
                    self.loading = false;
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
                Msg::Outputs(names, comp) => {
                    self.compositor = comp;
                    let mut outs = vec![String::from("*")];
                    for n in names {
                        if !outs.contains(&n) {
                            outs.push(n);
                        }
                    }
                    if !outs.contains(&self.cfg.output) {
                        outs.push(self.cfg.output.clone());
                    }
                    self.outs = outs;
                }
                Msg::Applied(r) => {
                    self.applying = None;
                    self.now_key.clear();
                    self.sync_cfg();
                    match r {
                        Ok(t) => self.toast(t, false),
                        Err(e) => self.toast(e, true),
                    }
                    let _ = self.nudge.send(());
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
                    let _ = self.nudge.send(());
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
        if budget == 0 {
            ctx.request_repaint();
        }
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
            } else if active {
                ctx.request_repaint_after(Duration::from_millis(80));
            }
        }
        let cur = self.status.current.clone();
        if self.now_key != cur {
            self.now_key = cur.clone();
            self.now_tex = None;
            self.now_pending = false;
        }
        if active && !self.now_key.is_empty() && self.now_tex.is_none() && !self.now_pending {
            self.now_pending = true;
            let key = self.now_key.clone();
            let tx = self.tx.clone();
            let ctx2 = ctx.clone();
            let active2 = self.active.clone();
            std::thread::spawn(move || {
                let img = std::panic::catch_unwind(|| thumbs::peek(&key)).unwrap_or(None);
                let _ = tx.send(Msg::Now { key, img });
                if active2.load(Ordering::Relaxed) {
                    ctx2.request_repaint();
                }
            });
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
        let (esc, enter, back, l, r, u, d, fav) = ctx.input(|i| {
            (
                i.key_pressed(egui::Key::Escape),
                i.key_pressed(egui::Key::Enter),
                i.key_pressed(egui::Key::Backspace),
                i.key_pressed(egui::Key::ArrowLeft),
                i.key_pressed(egui::Key::ArrowRight),
                i.key_pressed(egui::Key::ArrowUp),
                i.key_pressed(egui::Key::ArrowDown),
                i.key_pressed(egui::Key::F),
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
        if fav {
            if let Some(p) = self.selected.clone() {
                self.act(ctx, Act::Fav(p));
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
        let en = self.cfg.language == "en";
        let mut act = Act::None;
        let mut add = false;
        egui::SidePanel::left("side")
            .exact_width(236.0)
            .resizable(false)
            .frame(
                egui::Frame::none()
                    .fill(pal().panel)
                    .inner_margin(egui::Margin::symmetric(16.0, 18.0)),
            )
            .show(ctx, |ui| {
                ui.horizontal(|ui| {
                    let (r, _) = ui.allocate_exact_size(vec2(40.0, 40.0), Sense::hover());
                    logo_mark(ui.painter(), r);
                    ui.add_space(4.0);
                    ui.vertical(|ui| {
                        ui.spacing_mut().item_spacing.y = 1.0;
                        ui.label(RichText::new("OozeWalls").sz(19.0).strong().color(pal().text));
                        ui.label(RichText::new("live wallpapers").sz(11.0).color(pal().dim));
                    });
                });
                ui.add_space(22.0);
                if nav_btn(
                    ui,
                    "library",
                    tr!(en, "Biblioteca", "Library"),
                    self.tab == 0 && !self.fav_only,
                ) {
                    if self.fav_only {
                        self.open(ctx, None);
                    } else {
                        self.tab = 0;
                    }
                }
                if nav_btn(
                    ui,
                    "heart",
                    tr!(en, "Favoritos", "Favorites"),
                    self.tab == 0 && self.fav_only,
                ) {
                    self.open_favs(ctx);
                }
                if nav_btn(
                    ui,
                    "settings",
                    tr!(en, "Ajustes", "Settings"),
                    self.tab == 1,
                ) {
                    self.tab = 1;
                }
                if nav_btn(
                    ui,
                    "activity",
                    tr!(en, "Estado", "Status"),
                    self.tab == 2,
                ) {
                    self.tab = 2;
                }
                ui.add_space(20.0);
                ui.horizontal(|ui| {
                    ui.label(
                        RichText::new(tr!(en, "CARPETAS", "FOLDERS"))
                            .sz(10.0)
                            .strong()
                            .color(pal().dim),
                    );
                    ui.with_layout(Layout::right_to_left(Align::Center), |ui| {
                        if glyph_btn(ui, "plus", vec2(22.0, 22.0))
                            .on_hover_text(tr!(en, "Agregar carpeta", "Add folder"))
                            .clicked()
                        {
                            add = true;
                        }
                    });
                });
                ui.add_space(4.0);
                let list_h = (ui.available_height() - 104.0).max(60.0);
                egui::ScrollArea::vertical()
                    .max_height(list_h)
                    .auto_shrink([false, false])
                    .show(ui, |ui| {
                        ui.spacing_mut().item_spacing.y = 2.0;
                        for d in self.cfg.dirs.clone() {
                            let active = self.tab == 0
                                && !self.fav_only
                                && self
                                    .nav
                                    .as_ref()
                                    .map(|n| scan::is_inside(n, &d))
                                    .unwrap_or(false);
                            let info = self.folders.iter().find(|f| f.path == d);
                            let count = info.map(|f| f.videos + f.images);
                            let resp = side_row(ui, &short_name(&d), count, active)
                                .on_hover_text(d.clone());
                            if resp.clicked() {
                                act = Act::Open(d.clone());
                            }
                            resp.context_menu(|ui| {
                                if ui
                                    .button(tr!(
                                        en,
                                        "Quitar de la biblioteca",
                                        "Remove from library"
                                    ))
                                    .clicked()
                                {
                                    act = Act::Remove(d.clone());
                                    ui.close_menu();
                                }
                            });
                        }
                    });
                ui.with_layout(Layout::bottom_up(Align::Min), |ui| {
                    if secondary_button(
                        ui,
                        tr!(en, "Aplicar archivo…", "Apply file…"),
                        "file",
                    ) {
                        self.pick_file(ctx);
                    }
                    ui.add_space(2.0);
                    if secondary_button(
                        ui,
                        tr!(en, "Agregar carpeta", "Add folder"),
                        "folder-plus",
                    ) {
                        self.pick_dir(ctx);
                    }
                });
            });
        if add {
            self.pick_dir(ctx);
        }
        self.act(ctx, act);
    }

    // SECCION: NOW BAR
    fn now_bar(&mut self, ctx: &egui::Context) {
        let en = self.cfg.language == "en";
        let mut prev = false;
        let mut toggle = false;
        let mut next = false;
        let mut stop = false;
        let mut vol_changed = false;
        egui::TopBottomPanel::bottom("now")
            .exact_height(84.0)
            .frame(egui::Frame::none().fill(pal().panel))
            .show(ctx, |ui| {
                let rect = ui.max_rect();
                let cy = rect.center().y;
                ui.painter().line_segment(
                    [rect.left_top(), rect.right_top()],
                    Stroke::new(1.0, pal().border),
                );
                let thumb = Rect::from_min_size(
                    pos2(rect.left() + 18.0, cy - 29.0),
                    vec2(104.0, 58.0),
                );
                let tex = self
                    .textures
                    .get(&self.status.current)
                    .or(self.now_tex.as_ref());
                match tex {
                    Some(t) => {
                        egui::Image::new(t)
                            .rounding(Rounding::same(10.0))
                            .paint_at(ui, thumb);
                    }
                    None => {
                        ui.painter()
                            .rect_filled(thumb, Rounding::same(10.0), pal().card_hover);
                        paint_icon(ui.painter(), "image", thumb.center(), 22.0, pal().dim);
                    }
                }
                ui.painter().rect_stroke(
                    thumb,
                    Rounding::same(10.0),
                    Stroke::new(1.0, pal().border),
                );

                let centre = pos2(rect.center().x, cy);
                let title_left = thumb.right() + 14.0;
                let title_right = centre.x - 104.0;
                if title_right > title_left + 80.0 {
                    let cur = self.status.current.clone();
                    let title = if cur.is_empty() {
                        String::from(tr!(en, "Sin fondo activo", "No active wallpaper"))
                    } else {
                        trim_chars(&stem(&short_name(&cur)), 38)
                    };
                    let clip = Rect::from_min_max(
                        pos2(title_left, rect.top()),
                        pos2(title_right, rect.bottom()),
                    );
                    let p = ui.painter().with_clip_rect(clip);
                    p.text(
                        pos2(title_left, cy - 12.0),
                        Align2::LEFT_CENTER,
                        title,
                        pf(14.5),
                        pal().text,
                    );
                    let (dot, sub) = if !self.status.running {
                        (pal().dim, String::from(tr!(en, "detenido", "stopped")))
                    } else if self.status.paused {
                        (WARN, String::from(tr!(en, "live · pausado", "live · paused")))
                    } else if self.cfg.wallpapers.len() > 1 {
                        (
                            OK,
                            format!(
                                "live · {} {}",
                                self.cfg.wallpapers.len(),
                                tr!(en, "salidas", "outputs")
                            ),
                        )
                    } else {
                        (OK, format!("live · {}", self.cfg.output))
                    };
                    p.circle_filled(pos2(title_left + 3.0, cy + 11.0), 3.0, dot);
                    p.text(
                        pos2(title_left + 12.0, cy + 11.0),
                        Align2::LEFT_CENTER,
                        sub,
                        pf(11.5),
                        pal().dim,
                    );
                }

                let pause_r = Rect::from_center_size(centre, vec2(44.0, 44.0));
                let prev_r =
                    Rect::from_center_size(centre + vec2(-54.0, 0.0), vec2(34.0, 34.0));
                let next_r =
                    Rect::from_center_size(centre + vec2(54.0, 0.0), vec2(34.0, 34.0));
                let stop_r =
                    Rect::from_center_size(centre + vec2(102.0, 0.0), vec2(28.0, 28.0));
                if round_btn(ui, prev_r, ui.id().with("transport-prev"), "prev", false, true) {
                    prev = true;
                }
                if round_btn(
                    ui,
                    pause_r,
                    ui.id().with("transport-toggle"),
                    if self.status.paused { "play" } else { "pause" },
                    true,
                    self.status.running,
                ) {
                    toggle = true;
                }
                if round_btn(ui, next_r, ui.id().with("transport-next"), "next", false, true) {
                    next = true;
                }
                if rect.width() >= 900.0
                    && round_btn(
                        ui,
                        stop_r,
                        ui.id().with("transport-stop"),
                        "stop",
                        false,
                        self.status.running,
                    )
                {
                    stop = true;
                }

                let right = rect.right() - 18.0;
                let ram_w = 150.0;
                let ram_shown = rect.width() >= 1050.0;
                if ram_shown {
                    let ram =
                        Rect::from_min_size(pos2(right - ram_w, cy - 14.0), vec2(ram_w, 28.0));
                    ui.painter().rect(
                        ram,
                        Rounding::same(14.0),
                        pal().card,
                        Stroke::new(1.0, pal().border),
                    );
                    let col = if self.status.over {
                        BAD
                    } else if self.status.ram * 100 / RAM_BUDGET > 80 {
                        WARN
                    } else {
                        OK
                    };
                    ui.painter()
                        .circle_filled(ram.left_center() + vec2(13.0, 0.0), 3.0, col);
                    ui.painter().text(
                        ram.left_center() + vec2(22.0, 0.0),
                        Align2::LEFT_CENTER,
                        format!("RAM {} / {} MB", self.status.ram, RAM_BUDGET),
                        pf(10.5),
                        pal().dim,
                    );
                }
                if rect.width() >= 800.0 {
                    let mute_r = Rect::from_center_size(
                        pos2(right - if ram_shown { ram_w + 30.0 } else { 30.0 }, cy),
                        vec2(30.0, 30.0),
                    );
                    if round_btn(
                        ui,
                        mute_r,
                        ui.id().with("mute"),
                        if self.cfg.mute { "mute" } else { "volume" },
                        false,
                        true,
                    ) {
                        self.cfg.mute = !self.cfg.mute;
                        vol_changed = true;
                    }
                    let track_w = 104.0;
                    let track_right = mute_r.left() - 14.0;
                    let track = Rect::from_min_size(
                        pos2(track_right - track_w, cy - 2.0),
                        vec2(track_w, 4.0),
                    );
                    let vr = ui.interact(
                        track.expand2(vec2(6.0, 10.0)),
                        ui.id().with("volume"),
                        Sense::click_and_drag(),
                    );
                    if vr.dragged() || vr.clicked() {
                        if let Some(p) = vr.interact_pointer_pos() {
                            let t = ((p.x - track.left()) / track.width()).clamp(0.0, 1.0);
                            let v = (t * 100.0).round() as u8;
                            if v != self.cfg.volume {
                                self.cfg.volume = v;
                                vol_changed = true;
                            }
                        }
                    }
                    ui.painter()
                        .rect_filled(track, Rounding::same(2.0), pal().card_hover);
                    let fill_w = track.width() * (self.cfg.volume as f32 / 100.0);
                    ui.painter().rect_filled(
                        Rect::from_min_size(track.min, vec2(fill_w, track.height())),
                        Rounding::same(2.0),
                        if self.cfg.mute { pal().dim } else { pal().accent },
                    );
                    ui.painter().circle_filled(
                        pos2(track.left() + fill_w, cy),
                        5.0,
                        if self.cfg.mute { pal().dim } else { pal().accent_hover },
                    );
                }
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
        let mut refresh = false;
        let mut go_fav = false;
        let mut go_all = false;
        let mut pick: Option<usize> = None;
        let en = self.cfg.language == "en";
        let avail0 = ui.available_width();
        let stacked = avail0 < 620.0;
        let tight = avail0 < 430.0;
        let crumbs = self.crumbs();
        let at_home = crumbs.is_empty() && !self.fav_only;
        let mut dd_label = if self.fav_only {
            String::from(tr!(en, "Favoritos", "Favorites"))
        } else if let Some(n) = &self.nav {
            short_name(n)
        } else if tight {
            String::from(tr!(en, "Carpetas", "Folders"))
        } else {
            String::from(tr!(en, "Todas las carpetas", "All folders"))
        };
        if tight && dd_label.chars().count() > 13 {
            dd_label = trim_chars(&dd_label, 13);
        }
        let dd_w = if tight {
            132.0
        } else if stacked {
            166.0
        } else {
            196.0
        };

        if stacked {
            ui.label(
                RichText::new(if self.fav_only {
                    tr!(en, "Favoritos", "Favorites")
                } else {
                    tr!(en, "Biblioteca", "Library")
                })
                .sz(24.0)
                    .strong()
                    .color(pal().text),
            );
            ui.label(
                RichText::new(if self.fav_only {
                    tr!(en, "Los fondos que guardaste", "The wallpapers you saved")
                } else {
                    tr!(en, "Explora y aplica tus wallpapers", "Browse and apply your wallpapers")
                })
                .sz(12.0)
                .color(pal().dim),
            );
            ui.add_space(6.0);
            if avail0 < 290.0 {
                search_field(ui, &mut self.filter, ui.available_width(), en);
                ui.add_space(2.0);
                folder_combo(
                    ui,
                    &self.cfg.dirs,
                    self.fav_only,
                    self.nav.as_deref(),
                    &dd_label,
                    ui.available_width().min(180.0),
                    en,
                    &mut pick,
                );
            } else {
                ui.horizontal(|ui| {
                    let sw = (ui.available_width() - dd_w - 10.0).max(80.0);
                    search_field(ui, &mut self.filter, sw, en);
                    folder_combo(
                        ui,
                        &self.cfg.dirs,
                        self.fav_only,
                        self.nav.as_deref(),
                        &dd_label,
                        dd_w,
                        en,
                        &mut pick,
                    );
                });
            }
        } else {
            ui.horizontal(|ui| {
                ui.vertical(|ui| {
                    ui.spacing_mut().item_spacing.y = 2.0;
                    ui.label(
                        RichText::new(if self.fav_only {
                            tr!(en, "Favoritos", "Favorites")
                        } else {
                            tr!(en, "Biblioteca", "Library")
                        })
                        .sz(25.0)
                            .strong()
                            .color(pal().text),
                    );
                    ui.label(
                        RichText::new(if self.fav_only {
                            tr!(en, "Los fondos que guardaste", "The wallpapers you saved")
                        } else {
                            tr!(
                                en,
                                "Explora y aplica tus wallpapers",
                                "Browse and apply your wallpapers"
                            )
                        })
                        .sz(12.0)
                        .color(pal().dim),
                    );
                });
                ui.with_layout(Layout::right_to_left(Align::Center), |ui| {
                    folder_combo(
                        ui,
                        &self.cfg.dirs,
                        self.fav_only,
                        self.nav.as_deref(),
                        &dd_label,
                        dd_w,
                        en,
                        &mut pick,
                    );
                    search_field(
                        ui,
                        &mut self.filter,
                        if avail0 < 760.0 { 190.0 } else { 240.0 },
                        en,
                    );
                });
            });
        }
        if let Some(k) = pick {
            if k == 1 {
                self.open_favs(ctx);
            } else if k == 2 {
                self.open(ctx, None);
            } else if let Some(d) = self.cfg.dirs.get(k - 3).cloned() {
                self.open(ctx, Some(d));
            }
        }
        ui.add_space(9.0);
        ui.separator();
        ui.add_space(5.0);

        ui.horizontal(|ui| {
            if !at_home || self.fav_only {
                if glyph_btn(ui, "back", vec2(28.0, 26.0))
                    .on_hover_text(tr!(en, "Subir un nivel", "Go up one level"))
                    .clicked()
                {
                    act = Act::Up;
                }
            }
            let show_refresh = avail0 > 390.0;
            let room = ui.available_width() - if show_refresh { 34.0 } else { 0.0 };
            if self.fav_only {
                ui.label(
                    RichText::new(tr!(en, "Favoritos", "Favorites"))
                        .sz(14.0)
                        .strong()
                        .color(pal().text),
                );
            } else if at_home {
                ui.label(
                    RichText::new(tr!(en, "Biblioteca", "Library"))
                        .sz(14.0)
                        .strong()
                        .color(pal().text),
                );
            } else {
                let show_root = room > 250.0;
                let max_crumbs = if room > 430.0 {
                    3
                } else if room > 300.0 {
                    2
                } else {
                    1
                };
                let per = (((room - 40.0) / (max_crumbs as f32 * 7.4)).max(8.0)) as usize;
                let start = crumbs.len().saturating_sub(max_crumbs);
                if show_root {
                    if ui
                        .add(
                            egui::Button::new(
                                RichText::new(tr!(en, "Biblioteca", "Library"))
                                    .sz(13.5)
                                    .color(pal().dim),
                            )
                            .frame(false),
                        )
                        .clicked()
                    {
                        act = Act::Home;
                    }
                } else if start > 0 {
                    ui.label(RichText::new("…").sz(13.0).color(pal().dim));
                }
                for (i, (label, path)) in crumbs.iter().enumerate().skip(start) {
                    if show_root || i > start {
                        ui.label(RichText::new("/").sz(13.0).color(pal().dim));
                    }
                    let last = i + 1 == crumbs.len();
                    if ui
                        .add(
                            egui::Button::new(
                                RichText::new(trim_chars(label, per))
                                    .sz(13.5)
                                    .strong()
                                    .color(if last { pal().text } else { pal().dim }),
                            )
                            .frame(false),
                        )
                        .clicked()
                        && !last
                    {
                        act = Act::Open(path.clone());
                    }
                }
            }
            if show_refresh {
                ui.with_layout(Layout::right_to_left(Align::Center), |ui| {
                    if glyph_btn(ui, "update", vec2(28.0, 26.0))
                        .on_hover_text(tr!(en, "Recargar", "Refresh"))
                        .clicked()
                    {
                        refresh = true;
                    }
                });
            }
        });
        if refresh {
            self.cfg = config::Config::load();
            self.load_view(ctx);
            let _ = self.nudge.send(());
        }
        ui.add_space(4.0);
        let lbl_all = tr!(en, "Todos", "All");
        let lbl_images = tr!(en, "Imágenes", "Images");
        let lbl_favs = tr!(en, "Favoritos", "Favorites");
        let lbl_sort = tr!(en, "Ordenar", "Sort");
        let lbl_size = tr!(en, "Tamaño", "Size");
        let lbl_apply = tr!(en, "Aplicar en", "Apply to");
        let gap = ui.spacing().item_spacing.x;
        let out_w = if tight { 126.0 } else { 156.0 };
        let items: [(u8, f32); 7] = [
            (0, text_w(ui, lbl_all, 12.0) + 22.0),
            (1, text_w(ui, "Live", 12.0) + 30.0),
            (2, text_w(ui, lbl_images, 12.0) + 22.0),
            (3, text_w(ui, lbl_favs, 12.0) + 30.0),
            (4, text_w(ui, lbl_sort, 11.0) + gap + 94.0 + 8.0),
            (5, text_w(ui, lbl_size, 11.0) + gap + 64.0 + 26.0),
            (
                6,
                text_w(ui, lbl_apply, 11.0) + gap + out_w + 8.0 + if self.loading { 26.0 } else { 0.0 },
            ),
        ];
        let flow_w = (ui.available_width() - 4.0).max(60.0);
        let mut rows: Vec<Vec<u8>> = vec![Vec::new()];
        let mut used = 0.0f32;
        for (code, w) in items {
            let next = if used > 0.0 { used + gap + w } else { w };
            if used > 0.0 && next > flow_w {
                rows.push(Vec::new());
                used = w;
            } else {
                used = next;
            }
            if let Some(row) = rows.last_mut() {
                row.push(code);
            }
        }
        for row in rows {
            ui.horizontal(|ui| {
                for code in row {
                    match code {
                        0 => {
                            if filter_chip(ui, lbl_all, self.kind == 0, None) {
                                self.kind = 0;
                            }
                        }
                        1 => {
                            if filter_chip(ui, "Live", self.kind == 1, Some(pal().accent)) {
                                self.kind = 1;
                            }
                        }
                        2 => {
                            if filter_chip(ui, lbl_images, self.kind == 2, None) {
                                self.kind = 2;
                            }
                        }
                        3 => {
                            if filter_chip(ui, lbl_favs, self.fav_only, Some(pal().pink)) {
                                if self.fav_only {
                                    go_all = true;
                                } else {
                                    go_fav = true;
                                }
                            }
                        }
                        4 => {
                            ui.label(RichText::new(lbl_sort).sz(11.0).color(pal().dim));
                            egui::ComboBox::from_id_source("lib_sort")
                                .width(94.0)
                                .selected_text(
                                    RichText::new(
                                        [
                                            tr!(en, "Nombre", "Name"),
                                            tr!(en, "Recientes", "Recent"),
                                            tr!(en, "Tamaño", "Size"),
                                        ][self.sort as usize],
                                    )
                                    .sz(12.0)
                                    .color(pal().text),
                                )
                                .show_ui(ui, |ui| {
                                    ui.selectable_value(&mut self.sort, 0, tr!(en, "Nombre", "Name"));
                                    ui.selectable_value(&mut self.sort, 1, tr!(en, "Recientes", "Recent"));
                                    ui.selectable_value(&mut self.sort, 2, tr!(en, "Tamaño", "Size"));
                                });
                        }
                        5 => {
                            ui.label(RichText::new(lbl_size).sz(11.0).color(pal().dim));
                            ui.spacing_mut().slider_width = 64.0;
                            ui.add(egui::Slider::new(&mut self.card, 190.0..=340.0).show_value(false));
                        }
                        _ => {
                            ui.label(RichText::new(lbl_apply).sz(11.0).color(pal().dim));
                            egui::ComboBox::from_id_source("lib_out")
                                .width(out_w)
                                .selected_text(
                                    RichText::new(if self.cfg.output == "*" {
                                        String::from(tr!(en, "Todas las salidas", "All outputs"))
                                    } else {
                                        self.cfg.output.clone()
                                    })
                                    .sz(12.0)
                                    .color(pal().text),
                                )
                                .show_ui(ui, |ui| {
                                    for o in self.outs.clone() {
                                        let label = if o == "*" {
                                            String::from(tr!(en, "Todas las salidas", "All outputs"))
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
                            if self.loading {
                                ui.spinner();
                            }
                        }
                    }
                }
            });
        }
        if out_changed {
            self.commit();
        }
        if go_fav {
            self.open_favs(ctx);
        }
        if go_all {
            self.open(ctx, None);
        }

        let (folders, entries) = self.visible();
        let sp = 12.0;
        let avail = (ui.available_width() - 10.0).max(1.0);
        let cols = (((avail + sp) / (self.card + sp)).floor() as usize).max(1);
        self.cols = cols;
        let wall_w = ((avail - sp * (cols as f32 - 1.0)) / cols as f32).floor();
        let fcols = (((avail + sp) / (230.0 + sp)).floor() as usize).max(1);
        let folder_w = ((avail - sp * (fcols as f32 - 1.0)) / fcols as f32).floor();
        let scroll_to = self.scroll_to.take();
        let at_root = !self.fav_only && self.nav.is_none();
        let loading = self.loading;
        let fav_only = self.fav_only;
        let filter_empty = self.filter.trim().is_empty();

        egui::ScrollArea::vertical()
            .auto_shrink([false, false])
            .show(ui, |ui| {
                ui.spacing_mut().item_spacing = vec2(sp, sp);
                if !folders.is_empty() {
                    section_label(
                        ui,
                        if at_root {
                            tr!(en, "CARPETAS DE LA BIBLIOTECA", "LIBRARY FOLDERS")
                        } else {
                            tr!(en, "CARPETAS", "FOLDERS")
                        },
                    );
                    ui.add_space(2.0);
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
                    ui.add_space(8.0);
                }
                if !entries.is_empty() {
                    section_label(ui, &format!("{} · {}", tr!(en, "FONDOS", "WALLPAPERS"), entries.len()));
                    ui.add_space(2.0);
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
                    ui.add_space(52.0);
                    ui.vertical_centered(|ui| {
                        let (icon, msg, hint) = if loading {
                            ("update", tr!(en, "Cargando…", "Loading…"), "")
                        } else if fav_only {
                            (
                                "heart",
                                tr!(en, "Aún no tienes favoritos", "No favorites yet"),
                                tr!(
                                    en,
                                    "Toca el corazón de cualquier fondo para guardarlo aquí",
                                    "Tap the heart on any wallpaper to save it here"
                                ),
                            )
                        } else if at_root {
                            (
                                "folder-plus",
                                tr!(en, "Agrega una carpeta para empezar", "Add a folder to start"),
                                tr!(
                                    en,
                                    "Arrastra una carpeta a la ventana o usa Agregar carpeta",
                                    "Drag a folder into the window or use Add folder"
                                ),
                            )
                        } else if !filter_empty {
                            (
                                "search",
                                tr!(en, "Sin coincidencias", "No matches"),
                                tr!(
                                    en,
                                    "Prueba con otro nombre o filtro",
                                    "Try a different name or filter"
                                ),
                            )
                        } else {
                            (
                                "image",
                                tr!(en, "Esta carpeta no tiene fondos", "This folder has no wallpapers"),
                                "",
                            )
                        };
                        let (r, _) = ui.allocate_exact_size(vec2(54.0, 54.0), Sense::hover());
                        ui.painter()
                            .rect_filled(r, Rounding::same(16.0), pal().card);
                        paint_icon(ui.painter(), icon, r.center(), 24.0, pal().dim);
                        ui.add_space(8.0);
                        ui.label(RichText::new(msg).sz(15.0).strong().color(pal().text));
                        if !hint.is_empty() {
                            ui.label(RichText::new(hint).sz(12.0).color(pal().dim));
                        }
                    });
                }
            });
        self.act(ctx, act);
    }

    fn folder_card(&self, ui: &mut egui::Ui, f: &scan::Folder, w: f32, root: bool) -> Act {
        let en = self.cfg.language == "en";
        let (rect, resp) = ui.allocate_exact_size(vec2(w, 76.0), Sense::click());
        let hot = resp.hovered();
        ui.painter().rect(
            rect,
            Rounding::same(12.0),
            if hot { pal().card_hover } else { pal().card },
            Stroke::new(1.0, if hot { pal().border_hi } else { pal().border }),
        );
        let col = if f.missing { BAD } else { pal().accent };
        paint_icon(
            ui.painter(),
            "folder",
            rect.left_center() + vec2(30.0, 0.0),
            32.0,
            col,
        );
        let mut parts: Vec<String> = Vec::new();
        if f.videos > 0 {
            parts.push(format!("{} {}", f.videos, tr!(en, "live", "live")));
        }
        if f.images > 0 {
            parts.push(format!("{} {}", f.images, tr!(en, "img", "img")));
        }
        if f.subfolders > 0 {
            parts.push(format!(
                "{} {}{}",
                f.subfolders,
                tr!(en, "carpeta", "folder"),
                if f.subfolders == 1 {
                    ""
                } else {
                    tr!(en, "s", "s")
                }
            ));
        }
        let meta = if f.missing {
            String::from(tr!(en, "no existe", "missing"))
        } else if parts.is_empty() {
            String::from(tr!(en, "vacía", "empty"))
        } else {
            parts.join(" · ")
        };
        let text_x = rect.left() + 54.0;
        let text_right = rect.right() - 12.0;
        let p = ui.painter().with_clip_rect(Rect::from_min_max(
            pos2(text_x, rect.top()),
            pos2(text_right, rect.bottom()),
        ));
        p.text(
            pos2(text_x, rect.center().y - 10.0),
            Align2::LEFT_CENTER,
            trim_chars(&f.name, ((w - 70.0) / 7.0) as usize),
            pf(14.0),
            pal().text,
        );
        p.text(
            pos2(text_x, rect.center().y + 10.0),
            Align2::LEFT_CENTER,
            meta,
            pf(11.0),
            if f.missing { BAD } else { pal().dim },
        );
        let resp = resp.on_hover_cursor(egui::CursorIcon::PointingHand);
        let mut act = Act::None;
        if resp.clicked() {
            act = Act::Open(f.path.clone());
        }
        if root {
            resp.context_menu(|ui| {
                if ui
                    .button(tr!(en, "Quitar de la biblioteca", "Remove from library"))
                    .clicked()
                {
                    act = Act::Remove(f.path.clone());
                    ui.close_menu();
                }
            });
        }
        act
    }

    fn wall_card(&self, ui: &mut egui::Ui, e: &scan::Entry, w: f32, scroll: bool) -> Act {
        let en = self.cfg.language == "en";
        let pad = 8.0;
        let iw = w - pad * 2.0;
        let ih = (iw * 9.0 / 16.0).floor();
        let h = pad + ih + 10.0 + 21.0 + 16.0 + pad;
        let (rect, resp) = ui.allocate_exact_size(vec2(w, h), Sense::click());
        let selected = self.selected.as_deref() == Some(e.path.as_str());
        let used = self.cfg.wallpapers.values().any(|p| p == &e.path);
        let fav = self.cfg.favorites.iter().any(|p| p == &e.path);
        let hot = resp.hovered();
        let fill = if selected {
            pal().accent_soft
        } else if hot {
            pal().card_hover
        } else {
            pal().card
        };
        let stroke = if selected {
            Stroke::new(1.6, pal().accent)
        } else if used {
            Stroke::new(1.2, OK.gamma_multiply(0.7))
        } else if hot {
            Stroke::new(1.0, pal().border_hi)
        } else {
            Stroke::new(1.0, pal().border)
        };
        ui.painter()
            .rect(rect, Rounding::same(14.0), fill, stroke);
        let ir = Rect::from_min_size(rect.min + vec2(pad, pad), vec2(iw, ih));
        match self.textures.get(&e.path) {
            Some(t) => {
                egui::Image::new(t)
                    .rounding(Rounding::same(10.0))
                    .paint_at(ui, ir);
            }
            None => {
                ui.painter()
                    .rect_filled(ir, Rounding::same(10.0), Color32::from_rgb(26, 31, 43));
                paint_icon(
                    ui.painter(),
                    if e.is_video { "video" } else { "image" },
                    ir.center(),
                    26.0,
                    pal().dim,
                );
            }
        }
        if e.is_video {
            draw_badge(ui, ir.min + vec2(8.0, 8.0), "LIVE", pal().accent, Color32::from_rgb(12, 12, 18));
        }
        if used {
            let c = ir.left_bottom() + vec2(13.0, -13.0);
            ui.painter()
                .circle_filled(c, 9.0, Color32::from_black_alpha(170));
            ui.painter().circle_filled(c, 4.0, OK);
        }
        let heart = Rect::from_center_size(
            pos2(ir.right() - 20.0, ir.top() + 20.0),
            vec2(28.0, 28.0),
        );
        let hresp = ui.interact(
            heart.expand(2.0),
            ui.id().with(("fav", e.path.as_str())),
            Sense::click(),
        );
        ui.painter()
            .circle_filled(heart.center(), 14.0, Color32::from_black_alpha(150));
        paint_icon(
            ui.painter(),
            if fav { "heart-fill" } else { "heart" },
            heart.center(),
            15.0,
            if fav { pal().pink } else { Color32::WHITE },
        );
        if hresp
            .on_hover_cursor(egui::CursorIcon::PointingHand)
            .on_hover_text(if fav {
                tr!(en, "Quitar de favoritos", "Remove from favorites")
            } else {
                tr!(en, "Agregar a favoritos", "Add to favorites")
            })
            .clicked()
        {
            return Act::Fav(e.path.clone());
        }
        if hot {
            let bar = Rect::from_min_max(pos2(ir.left(), ir.bottom() - 26.0), ir.max);
            ui.painter().rect_filled(
                bar,
                Rounding {
                    nw: 0.0,
                    ne: 0.0,
                    sw: 10.0,
                    se: 10.0,
                },
                Color32::from_black_alpha(170),
            );
            paint_icon(
                ui.painter(),
                "play",
                bar.left_center() + vec2(15.0, 0.0),
                10.0,
                Color32::WHITE,
            );
            ui.painter().text(
                bar.left_center() + vec2(26.0, 0.0),
                Align2::LEFT_CENTER,
                tr!(en, "Doble click para aplicar", "Double click to apply"),
                pf(10.5),
                Color32::WHITE,
            );
        }
        let tx = rect.left() + pad + 2.0;
        let ty = ir.bottom() + 10.0;
        let clip = ui
            .painter()
            .with_clip_rect(Rect::from_min_size(pos2(tx, ty), vec2(iw - 4.0, 42.0)));
        clip.text(
            pos2(tx, ty),
            Align2::LEFT_TOP,
            trim_chars(&stem(&e.name), (iw / 7.2) as usize),
            pf(13.0),
            pal().text,
        );
        clip.text(
            pos2(tx, ty + 20.0),
            Align2::LEFT_TOP,
            format!("{} · {}", ext_upper(&e.name), size_text(e.bytes)),
            pf(10.5),
            pal().dim,
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
            if ui.button(tr!(en, "Aplicar", "Apply")).clicked() {
                act = Act::Apply(e.path.clone(), None);
                ui.close_menu();
            }
            if ui
                .button(if fav {
                    tr!(en, "Quitar de favoritos", "Remove from favorites")
                } else {
                    tr!(en, "Agregar a favoritos", "Add to favorites")
                })
                .clicked()
            {
                act = Act::Fav(e.path.clone());
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
                    let name = if o == "*" {
                        tr!(en, "todas", "all")
                    } else {
                        o.as_str()
                    };
                    if ui
                        .button(format!(
                            "{} {}",
                            tr!(en, "Aplicar en", "Apply to"),
                            name
                        ))
                        .clicked()
                    {
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
        let en = self.cfg.language == "en";
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
        let mut fav_toggle = false;
        let fav = self.cfg.favorites.iter().any(|p| p == &e.path);
        let screen_w = ctx.screen_rect().width();
        let detail_w = if screen_w < 760.0 {
            260.0
        } else if screen_w < 1000.0 {
            300.0
        } else {
            318.0
        };
        egui::SidePanel::right("detail")
            .exact_width(detail_w)
            .resizable(false)
            .frame(
                egui::Frame::none()
                    .fill(pal().panel)
                    .inner_margin(egui::Margin::symmetric(18.0, 16.0)),
            )
            .show(ctx, |ui| {
                ui.horizontal(|ui| {
                    ui.label(
                        RichText::new(tr!(en, "DETALLE", "DETAILS"))
                            .sz(10.5)
                            .strong()
                            .color(pal().dim),
                    );
                    ui.with_layout(Layout::right_to_left(Align::Center), |ui| {
                        if glyph_btn(ui, "close", vec2(26.0, 24.0))
                            .on_hover_text(tr!(en, "Cerrar", "Close"))
                            .clicked()
                        {
                            close = true;
                        }
                        let (r, resp) =
                            ui.allocate_exact_size(vec2(26.0, 24.0), Sense::click());
                        paint_icon(
                            ui.painter(),
                            if fav { "heart-fill" } else { "heart" },
                            r.center(),
                            14.0,
                            if fav { pal().pink } else { pal().dim },
                        );
                        if resp
                            .on_hover_cursor(egui::CursorIcon::PointingHand)
                            .on_hover_text(if fav {
                                tr!(en, "Quitar de favoritos", "Remove from favorites")
                            } else {
                                tr!(en, "Agregar a favoritos", "Add to favorites")
                            })
                            .clicked()
                        {
                            fav_toggle = true;
                        }
                    });
                });
                self.probe_swatches(ctx, &e.path, e.is_video);
                egui::ScrollArea::vertical()
                    .auto_shrink([false, false])
                    .show(ui, |ui| {
                        let w = ui.available_width();
                        let (r, _) = ui.allocate_exact_size(
                            vec2(w, (w * 9.0 / 16.0).floor()),
                            Sense::hover(),
                        );
                        match self.textures.get(&e.path) {
                            Some(t) => {
                                egui::Image::new(t)
                                    .rounding(Rounding::same(11.0))
                                    .paint_at(ui, r);
                            }
                            None => {
                                ui.painter()
                                    .rect_filled(r, Rounding::same(11.0), pal().card);
                                paint_icon(
                                    ui.painter(),
                                    if e.is_video { "video" } else { "image" },
                                    r.center(),
                                    28.0,
                                    pal().dim,
                                );
                            }
                        }
                        ui.painter().rect_stroke(
                            r,
                            Rounding::same(11.0),
                            Stroke::new(1.0, pal().border),
                        );
                        ui.add_space(8.0);
                        ui.label(
                            RichText::new(trim_chars(&stem(&e.name), 36))
                                .sz(17.0)
                                .strong()
                                .color(pal().text),
                        );
                        ui.horizontal(|ui| {
                            chip(
                                ui,
                                if e.is_video {
                                    "LIVE"
                                } else {
                                    tr!(en, "IMAGEN", "IMAGE")
                                },
                                pal().accent,
                            );
                            chip(ui, &ext_upper(&e.name), pal().dim);
                            chip(ui, &size_text(e.bytes), pal().dim);
                        });
                        ui.label(
                            RichText::new(middle_trim(&e.path, 44))
                                .sz(11.0)
                                .color(pal().dim),
                        )
                        .on_hover_text(e.path.clone());
                        let mut used: Vec<String> = self
                            .cfg
                            .wallpapers
                            .iter()
                            .filter(|(_, p)| p.as_str() == e.path)
                            .map(|(o, _)| {
                                if o == "*" {
                                    String::from(tr!(en, "todas", "all"))
                                } else {
                                    o.clone()
                                }
                            })
                            .collect();
                        used.sort();
                        if !used.is_empty() {
                            ui.label(
                                RichText::new(format!(
                                    "● {}: {}",
                                    tr!(en, "En uso en", "In use on"),
                                    used.join(", ")
                                ))
                                    .sz(12.0)
                                    .color(OK),
                            );
                        }
                        ui.add_space(6.0);
                        ui.separator();
                        ui.add_space(4.0);
                        section_label(ui, tr!(en, "Aplicar en", "Apply to"));
                        egui::ComboBox::from_id_source("det_out")
                            .width(ui.available_width() - 8.0)
                            .selected_text(if self.cfg.output == "*" {
                                String::from(tr!(en, "Todas las salidas", "All outputs"))
                            } else {
                                self.cfg.output.clone()
                            })
                            .show_ui(ui, |ui| {
                                for o in self.outs.clone() {
                                    let label = if o == "*" {
                                        String::from(tr!(
                                            en,
                                            "Todas las salidas",
                                            "All outputs"
                                        ))
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
                        section_label(ui, tr!(en, "Escala", "Scale"));
                        let mut sc = self.cfg.scaling_for(&self.cfg.output);
                        let before = sc.clone();
                        ui.horizontal(|ui| {
                            for (k, l) in [
                                ("fit", tr!(en, "Ajustar", "Fit")),
                                ("fill", tr!(en, "Llenar", "Fill")),
                                ("stretch", tr!(en, "Estirar", "Stretch")),
                            ] {
                                ui.selectable_value(&mut sc, k.to_string(), l);
                            }
                        });
                        if sc != before {
                            self.cfg.scaling.insert(self.cfg.output.clone(), sc);
                            changed = true;
                            rescale = true;
                        }
                        section_label(ui, tr!(en, "Paleta (matugen)", "Palette (matugen)"));
                        let mut pal_changed = scheme_chips(ui, &mut self.cfg.scheme);
                        let want_key =
                            format!("{}|{}|{}", e.path, self.cfg.scheme, self.cfg.palette_mode);
                        if self.swatch_key == want_key && self.swatches.len() > 1 {
                            if let Some(i) =
                                swatch_row(ui, &self.swatches, self.cfg.source_index)
                            {
                                self.cfg.source_index = i;
                                pal_changed = true;
                            }
                        }
                        if pal_changed {
                            changed = true;
                            regen = self.cfg.current.as_deref() == Some(e.path.as_str());
                        }
                        ui.add_space(10.0);
                        let busy = self.applying.is_some();
                        if primary_button(
                            ui,
                            if busy {
                                tr!(en, "Aplicando…", "Applying…")
                            } else {
                                tr!(en, "Aplicar fondo", "Apply wallpaper")
                            },
                            "play",
                            !busy,
                        ) {
                            apply_now = true;
                        }
                        ui.add_space(2.0);
                        if secondary_button(
                            ui,
                            tr!(en, "Generar paleta", "Generate palette"),
                            "palette",
                        ) {
                            mat = true;
                        }
                        ui.add_space(6.0);
                    });
            });
        if fav_toggle {
            self.act(ctx, Act::Fav(e.path.clone()));
        }
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
        let en = self.cfg.language == "en";
        let mut lang = self.cfg.language.clone();
        let mut changed = false;
        let mut remove: Option<String> = None;
        let mut add = false;
        let mut new_palette: Option<String> = None;
        let mut new_font: Option<String> = None;
        let mut look_changed = false;
        let card_w = (ui.available_width() - 36.0).max(180.0);
        egui::ScrollArea::vertical()
            .auto_shrink([false, false])
            .show(ui, |ui| {
                ui.label(RichText::new(tr!(en, "Ajustes", "Settings")).sz(24.0).strong());
                ui.add_space(6.0);
                card_frame().show(ui, |ui| {
                    ui.set_width(card_w);
                    ui.label(
                        RichText::new(tr!(en, "Idioma", "Language"))
                            .sz(15.0)
                            .strong(),
                    );
                    ui.add_space(4.0);
                    ui.horizontal(|ui| {
                        ui.selectable_value(&mut lang, String::from("es"), "Español");
                        ui.selectable_value(&mut lang, String::from("en"), "English");
                    });
                });
                ui.add_space(4.0);
                card_frame().show(ui, |ui| {
                    ui.set_width(card_w);
                    ui.label(
                        RichText::new(tr!(en, "Apariencia", "Appearance"))
                            .sz(15.0)
                            .strong(),
                    );
                    ui.add_space(4.0);
                    ui.label(
                        RichText::new(tr!(en, "Paleta de colores", "Color palette"))
                            .sz(12.0)
                            .color(pal().dim),
                    );
                    ui.add_space(2.0);
                    ui.horizontal_wrapped(|ui| {
                        ui.spacing_mut().item_spacing = vec2(8.0, 8.0);
                        for (i, p) in PALETTES.iter().enumerate() {
                            let on = i == PAL_IDX.load(Ordering::Relaxed);
                            if palette_swatch(ui, p, on, en) && !on {
                                new_palette = Some(p.id.to_string());
                            }
                        }
                    });
                    ui.add_space(8.0);
                    ui.label(
                        RichText::new(tr!(en, "Tamaño de fuente", "Font size"))
                            .sz(12.0)
                            .color(pal().dim),
                    );
                    ui.add_space(2.0);
                    ui.horizontal_wrapped(|ui| {
                        ui.spacing_mut().item_spacing = vec2(8.0, 8.0);
                        for (id, es, ing, _) in FONT_LEVELS {
                            let on = self.cfg.ui_font == id;
                            if filter_chip(ui, tr!(en, es, ing), on, None) && !on {
                                new_font = Some(id.to_string());
                            }
                        }
                    });
                });
                ui.add_space(4.0);
                card_frame().show(ui, |ui| {
                    ui.set_width(card_w);
                    ui.label(
                        RichText::new(tr!(en, "Reproducción", "Playback"))
                            .sz(15.0)
                            .strong(),
                    );
                    ui.add_space(4.0);
                    egui::Grid::new("set_play")
                        .num_columns(2)
                        .spacing([28.0, 14.0])
                        .show(ui, |ui| {
                            ui.label(tr!(en, "Salida por defecto", "Default output"));
                            egui::ComboBox::from_id_source("set_out")
                                .selected_text(if self.cfg.output == "*" {
                                    String::from(tr!(en, "Todas las salidas", "All outputs"))
                                } else {
                                    self.cfg.output.clone()
                                })
                                .show_ui(ui, |ui| {
                                    for o in self.outs.clone() {
                                        let label = if o == "*" {
                                            String::from(tr!(
                                                en,
                                                "Todas las salidas",
                                                "All outputs"
                                            ))
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
                            ui.label(tr!(en, "Escala en esa salida", "Scale on that output"));
                            let mut sc = self.cfg.scaling_for(&self.cfg.output);
                            let before = sc.clone();
                            ui.horizontal(|ui| {
                                for (k, l) in [
                                    ("fit", tr!(en, "Ajustar", "Fit")),
                                    ("fill", tr!(en, "Llenar", "Fill")),
                                    ("stretch", tr!(en, "Estirar", "Stretch")),
                                ] {
                                    ui.selectable_value(&mut sc, k.to_string(), l);
                                }
                            });
                            if sc != before {
                                self.cfg.scaling.insert(self.cfg.output.clone(), sc);
                                changed = true;
                            }
                            ui.end_row();
                            ui.label(tr!(en, "Volumen", "Volume"));
                            ui.horizontal(|ui| {
                                if ui
                                    .add(egui::Slider::new(&mut self.cfg.volume, 0..=100))
                                    .changed()
                                {
                                    changed = true;
                                }
                                if ui
                                    .checkbox(&mut self.cfg.mute, tr!(en, "Silenciar", "Mute"))
                                    .changed()
                                {
                                    changed = true;
                                }
                            });
                            ui.end_row();
                        });
                });
                ui.add_space(4.0);
                card_frame().show(ui, |ui| {
                    ui.set_width(card_w);
                    ui.label(
                        RichText::new(tr!(en, "Rendimiento", "Performance"))
                            .sz(15.0)
                            .strong(),
                    );
                    ui.add_space(4.0);
                    egui::Grid::new("set_perf")
                        .num_columns(2)
                        .spacing([28.0, 14.0])
                        .show(ui, |ui| {
                            ui.label(tr!(en, "Decodificación (hwdec)", "Decoding (hwdec)"));
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
                            ui.label(tr!(en, "Capa", "Layer"));
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
                            tr!(
                                en,
                                "hwdec, capa y silencio inicial aplican al próximo video que arranque.",
                                "hwdec, layer and initial mute apply to the next video that starts."
                            ),
                        )
                        .sz(12.0)
                        .color(pal().dim),
                    );
                });
                ui.add_space(4.0);
                card_frame().show(ui, |ui| {
                    ui.set_width(card_w);
                    ui.horizontal(|ui| {
                        ui.label(
                            RichText::new(tr!(
                                en,
                                "Carpetas de la biblioteca",
                                "Library folders"
                            ))
                                .sz(15.0)
                                .strong(),
                        );
                        if ui.button(tr!(en, "+ Agregar", "+ Add")).clicked() {
                            add = true;
                        }
                    });
                    ui.add_space(4.0);
                    for d in self.cfg.dirs.clone() {
                        ui.horizontal(|ui| {
                            let ok = Path::new(&d).is_dir();
                            let path_w = (ui.available_width() - 86.0).max(80.0);
                            ui.add_sized(
                                [path_w, 18.0],
                                egui::Label::new(
                                    RichText::new(&d).color(if ok { pal().text } else { BAD }),
                                )
                                .truncate(),
                            )
                            .on_hover_text(&d);
                            if ui.button(tr!(en, "Quitar", "Remove")).clicked() {
                                remove = Some(d.clone());
                            }
                        });
                    }
                });
            });
        if lang != self.cfg.language {
            self.cfg.language = lang;
            changed = true;
        }
        if let Some(p) = new_palette {
            self.cfg.ui_palette = p;
            changed = true;
            look_changed = true;
        }
        if let Some(f) = new_font {
            self.cfg.ui_font = f;
            changed = true;
            look_changed = true;
        }
        if look_changed {
            set_look(&self.cfg.ui_palette, &self.cfg.ui_font);
            theme(ctx);
            ctx.request_repaint();
        }
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
        let en = self.cfg.language == "en";
        let mut pause = false;
        let mut resume = false;
        let mut stop = false;
        let mut mat = false;
        let mut changed = false;
        let card_w = (ui.available_width() - 36.0).max(180.0);
        egui::ScrollArea::vertical()
            .auto_shrink([false, false])
            .show(ui, |ui| {
                ui.label(RichText::new(tr!(en, "Estado", "Status")).sz(24.0).strong());
                ui.add_space(6.0);
                card_frame().show(ui, |ui| {
                    ui.set_width(card_w);
                    ui.label(
                        RichText::new(tr!(en, "Fondos activos", "Active wallpapers"))
                            .sz(15.0)
                            .strong(),
                    );
                    ui.add_space(4.0);
                    if self.cfg.wallpapers.is_empty() {
                        ui.label(RichText::new(tr!(en, "ninguno", "none")).color(pal().dim));
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
                                        RichText::new(if o == "*" {
                                            String::from(tr!(en, "todas", "all"))
                                        } else {
                                            o
                                        })
                                            .color(pal().accent),
                                    );
                                    ui.add(
                                        egui::Label::new(
                                            RichText::new(middle_trim(&p, 80)).color(pal().text),
                                        )
                                        .truncate(),
                                    )
                                    .on_hover_text(p.clone());
                                    ui.end_row();
                                }
                            });
                    }
                });
                ui.add_space(4.0);
                card_frame().show(ui, |ui| {
                    ui.set_width(card_w);
                    ui.label(
                        RichText::new(tr!(en, "Rendimiento", "Performance"))
                            .sz(15.0)
                            .strong(),
                    );
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
                            ui.label(RichText::new(tr!(en, "Procesos", "Processes")).color(pal().dim));
                            ui.label(format!("{}", self.status.pids.len()));
                            ui.end_row();
                            ui.label(
                                RichText::new(tr!(en, "Reproducción", "Playback")).color(pal().dim),
                            );
                            ui.label(if !self.status.running {
                                tr!(en, "detenido", "stopped")
                            } else if self.status.paused {
                                tr!(en, "pausado", "paused")
                            } else {
                                tr!(en, "activo", "active")
                            });
                            ui.end_row();
                            ui.label(RichText::new("Compositor").color(pal().dim));
                            ui.label(self.compositor.clone());
                            ui.end_row();
                            ui.label(RichText::new("hwdec").color(pal().dim));
                            ui.label(self.cfg.hwdec.clone());
                            ui.end_row();
                            for s in self.status.socks.clone() {
                                ui.label(
                                    RichText::new(format!(
                                        "{} {}",
                                        tr!(en, "Salida", "Output"),
                                        if s.output == "*" {
                                            String::from(tr!(en, "todas", "all"))
                                        } else {
                                            s.output
                                        }
                                    ))
                                    .color(pal().dim),
                                );
                                ui.label(match s.pause {
                                    Some(true) => tr!(en, "pausada", "paused"),
                                    Some(false) => tr!(en, "reproduciendo", "playing"),
                                    None => tr!(en, "sin respuesta", "no response"),
                                });
                                ui.end_row();
                            }
                        });
                    ui.add_space(4.0);
                    ui.horizontal(|ui| {
                        if ui.button(tr!(en, "Pausar", "Pause")).clicked() {
                            pause = true;
                        }
                        if ui.button(tr!(en, "Reanudar", "Resume")).clicked() {
                            resume = true;
                        }
                        if ui.button(tr!(en, "Detener", "Stop")).clicked() {
                            stop = true;
                        }
                    });
                });
                ui.add_space(4.0);
                card_frame().show(ui, |ui| {
                    ui.set_width(card_w);
                    ui.label(
                        RichText::new(tr!(en, "Fondos estáticos", "Static wallpapers"))
                            .sz(15.0)
                            .strong(),
                    );
                    ui.add_space(4.0);
                    ui.label(
                        RichText::new(tr!(
                            en,
                            "Motor que pinta las imágenes",
                            "Engine that paints images"
                        ))
                            .sz(12.0)
                            .color(pal().dim),
                    );
                    ui.horizontal_wrapped(|ui| {
                        for (k, l) in [
                            ("auto", "Auto"),
                            (
                                "builtin",
                                tr!(en, "OozeWalls (capa propia)", "OozeWalls (built-in layer)"),
                            ),
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
                            tr!(
                                en,
                                "Auto: awww si está instalado, si no la capa propia (pocos MB). mpvpaper solo como último recurso.",
                                "Auto: awww if installed, otherwise the built-in layer (few MB). mpvpaper only as a last resort."
                            ),
                        )
                        .sz(12.0)
                        .color(pal().dim),
                    );
                });
                ui.add_space(4.0);
                card_frame().show(ui, |ui| {
                    ui.set_width(card_w);
                    ui.label(
                        RichText::new(tr!(
                            en,
                            "Animación al cambiar fondo",
                            "Animation on wallpaper change"
                        ))
                        .sz(15.0)
                        .strong(),
                    );
                    ui.add_space(4.0);
                    egui::Grid::new("set_anim")
                        .num_columns(2)
                        .spacing([28.0, 14.0])
                        .show(ui, |ui| {
                            ui.label(tr!(en, "Transición", "Transition"));
                            egui::ComboBox::from_id_source("set_transition")
                                .selected_text(transition::label_of_lang(
                                    &self.cfg.transition,
                                    en,
                                ))
                                .show_ui(ui, |ui| {
                                    for (k, _) in transition::KINDS {
                                        if ui
                                            .selectable_value(
                                                &mut self.cfg.transition,
                                                k.to_string(),
                                                transition::label_of_lang(k, en),
                                            )
                                            .changed()
                                        {
                                            changed = true;
                                        }
                                    }
                                });
                            ui.end_row();
                            ui.label(tr!(en, "Duración", "Duration"));
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
                            tr!(
                                en,
                                "Imágenes: todas las animaciones (capa propia) o su equivalente en awww. Videos: desvanecer, deslizar y zoom; el resto se ve como desvanecer. Aplica al próximo cambio de fondo.",
                                "Images: all animations (built-in layer) or their awww equivalent. Videos: fade, slide and zoom; the rest are shown as fade. Applies to the next wallpaper change."
                            ),
                        )
                        .sz(12.0)
                        .color(pal().dim),
                    );
                });
                ui.add_space(4.0);
                card_frame().show(ui, |ui| {
                    ui.set_width(card_w);
                    ui.label(
                        RichText::new(tr!(en, "Paleta (matugen)", "Palette (matugen)"))
                            .sz(15.0)
                            .strong(),
                    );
                    ui.add_space(4.0);
                    if ui
                        .checkbox(
                            &mut self.cfg.palette_auto,
                            tr!(
                                en,
                                "Generar al aplicar un fondo",
                                "Generate when applying a wallpaper"
                            ),
                        )
                        .changed()
                    {
                        changed = true;
                    }
                    ui.add_space(2.0);
                    ui.label(RichText::new(tr!(en, "Esquema", "Scheme")).sz(12.0).color(pal().dim));
                    if scheme_chips(ui, &mut self.cfg.scheme) {
                        changed = true;
                    }
                    ui.add_space(2.0);
                    ui.horizontal_wrapped(|ui| {
                        ui.label(RichText::new(tr!(en, "Modo", "Mode")).sz(12.0).color(pal().dim));
                        for k in ["dark", "light"] {
                            if ui
                                .selectable_value(&mut self.cfg.palette_mode, k.to_string(), k)
                                .changed()
                            {
                                changed = true;
                            }
                        }
                        ui.label(
                            RichText::new(tr!(en, "Color fuente", "Source color"))
                                .sz(12.0)
                                .color(pal().dim),
                        );
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
                    ui.label(
                        RichText::new(tr!(en, "Archivo de colores", "Colors file"))
                            .sz(12.0)
                            .color(pal().dim),
                    );
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
                        RichText::new(tr!(
                            en,
                            "OozeShell vigila ese JSON y recarga los colores solo.",
                            "OozeShell watches that JSON and reloads colors automatically."
                        ))
                            .sz(12.0)
                            .color(pal().dim),
                    );
                    ui.add_space(4.0);
                    if ui
                        .button(tr!(
                            en,
                            "Generar del fondo actual",
                            "Generate from current wallpaper"
                        ))
                        .clicked()
                    {
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
                self.toast(
                    String::from(tr!(en, "no hay fondo actual", "no current wallpaper")),
                    true,
                );
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
            (
                format!(
                    "{} {}…",
                    if self.cfg.language == "en" {
                        "applying"
                    } else {
                        "aplicando"
                    },
                    a
                ),
                false,
            )
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
        let avail = (ctx.screen_rect().width() - 56.0).max(160.0);
        let font = pf(14.0);
        let mut shown = trim_chars(&text, 140);
        let mut galley = ctx.fonts(|f| f.layout_no_wrap(shown.clone(), font.clone(), pal().text));
        for _ in 0..3 {
            if galley.size().x <= avail || shown.chars().count() <= 6 {
                break;
            }
            let keep = ((shown.chars().count() as f32 * avail / galley.size().x).floor() as usize)
                .max(4);
            shown = trim_chars(&shown, keep);
            galley = ctx.fonts(|f| f.layout_no_wrap(shown.clone(), font.clone(), pal().text));
        }
        let size = galley.size() + vec2(28.0, 20.0);
        let screen = ctx.screen_rect();
        let rect = Rect::from_min_size(
            pos2(screen.right() - 20.0 - size.x, screen.bottom() - 88.0 - size.y),
            size,
        );
        let painter = ctx.layer_painter(egui::LayerId::new(
            egui::Order::Foreground,
            egui::Id::new("toast"),
        ));
        painter.rect(
            rect,
            Rounding::same(10.0),
            pal().card_hover,
            Stroke::new(1.0, if bad { BAD } else { pal().accent }),
        );
        painter.galley(rect.min + vec2(14.0, 10.0), galley, pal().text);
    }
}

fn diag_log(msg: &str) {
    let Some(home) = std::env::var_os("HOME") else {
        return;
    };
    let dir = PathBuf::from(home).join(".cache/oozewalls");
    let _ = std::fs::create_dir_all(&dir);
    if let Ok(mut f) = std::fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(dir.join("gui-crash.log"))
    {
        let ts = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_secs())
            .unwrap_or(0);
        let _ = writeln!(f, "[{}] {}", ts, msg);
    }
}

fn install_watchdog(hb: Arc<AtomicU64>, on: Arc<AtomicBool>) {
    std::thread::spawn(move || {
        let mut last = hb.load(Ordering::Relaxed);
        let mut stalled = 0u32;
        loop {
            std::thread::sleep(Duration::from_secs(1));
            if !on.load(Ordering::Relaxed) {
                last = hb.load(Ordering::Relaxed);
                stalled = 0;
                continue;
            }
            let now = hb.load(Ordering::Relaxed);
            if now == last {
                stalled += 1;
            } else {
                stalled = 0;
                last = now;
            }
            if stalled == 30 {
                let mut report = format!(
                    "ANR heartbeat={} pid={}\n",
                    now,
                    std::process::id()
                );
                if let Ok(dir) = std::fs::read_dir("/proc/self/task") {
                    for ent in dir.flatten() {
                        let tid = ent.file_name().to_string_lossy().to_string();
                        let base = format!("/proc/self/task/{}", tid);
                        let comm = std::fs::read_to_string(format!("{}/comm", base))
                            .unwrap_or_default();
                        let wchan = std::fs::read_to_string(format!("{}/wchan", base))
                            .unwrap_or_default();
                        let stat = std::fs::read_to_string(format!("{}/stat", base))
                            .unwrap_or_default();
                        let state = stat.split_whitespace().nth(2).unwrap_or("?");
                        report.push_str(&format!(
                            "tid {} state {} wchan {} comm {}\n",
                            tid,
                            state,
                            wchan.trim(),
                            comm.trim()
                        ));
                    }
                }
                diag_log(&report);
            }
        }
    });
}

static SIGNAL_LOG_FD: AtomicI32 = AtomicI32::new(-1);

extern "C" fn on_fatal_signal(sig: libc::c_int) {
    let fd = SIGNAL_LOG_FD.load(Ordering::Relaxed);
    if fd >= 0 {
        let msg: &[u8] = match sig {
            libc::SIGTERM => b"signal: SIGTERM\n",
            libc::SIGHUP => b"signal: SIGHUP\n",
            libc::SIGINT => b"signal: SIGINT\n",
            _ => b"signal: other\n",
        };
        unsafe {
            libc::write(fd, msg.as_ptr() as *const libc::c_void, msg.len());
        }
    }
    unsafe {
        libc::signal(sig, libc::SIG_DFL);
        libc::raise(sig);
    }
}

fn install_signal_log() {
    use std::os::fd::IntoRawFd;
    let Some(home) = std::env::var_os("HOME") else {
        return;
    };
    let dir = PathBuf::from(home).join(".cache/oozewalls");
    let _ = std::fs::create_dir_all(&dir);
    let Ok(f) = std::fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(dir.join("gui-crash.log"))
    else {
        return;
    };
    SIGNAL_LOG_FD.store(f.into_raw_fd(), Ordering::Relaxed);
    for sig in [libc::SIGTERM, libc::SIGHUP, libc::SIGINT] {
        unsafe {
            libc::signal(
                sig,
                on_fatal_signal as extern "C" fn(libc::c_int) as libc::sighandler_t,
            );
        }
    }
}

impl eframe::App for Gui {
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) {
        let focused = ctx.input(|i| i.focused);
        let minimized = ctx.input(|i| i.viewport().minimized.unwrap_or(false));
        let active = focused && !minimized;
        let was = self.active.swap(active, Ordering::Relaxed);
        self.heartbeat.fetch_add(1, Ordering::Relaxed);
        if active && !was {
            let _ = self.nudge.send(());
            self.start_thumbs(ctx);
        }
        self.pump(ctx, active);
        self.keys(ctx);
        self.now_bar(ctx);
        let narrow_detail = self.tab == 0
            && self.selected.is_some()
            && ctx.screen_rect().width() < 820.0;
        if !narrow_detail {
            self.sidebar(ctx);
        }
        if self.tab == 0 {
            self.detail(ctx);
        }
        egui::CentralPanel::default()
            .frame(
                egui::Frame::none()
                    .fill(pal().bg)
                    .inner_margin(egui::Margin::symmetric(22.0, 16.0)),
            )
            .show(ctx, |ui| match self.tab {
                1 => self.settings(ui, ctx),
                2 => self.state_tab(ui, ctx),
                _ => self.library(ui, ctx),
            });
        self.toast_ui(ctx);
        if active {
            ctx.request_repaint_after(POLL);
        }
    }
}

fn main() -> eframe::Result<()> {
    let default = std::panic::take_hook();
    std::panic::set_hook(Box::new(move |info| {
        diag_log(&format!("panic: {}", info));
        default(info);
    }));
    install_signal_log();
    let opts = eframe::NativeOptions {
        viewport: egui::ViewportBuilder::default()
            .with_inner_size([1200.0, 800.0])
            .with_min_inner_size([640.0, 520.0])
            .with_app_id("oozewalls")
            .with_title("OozeWalls"),
        ..Default::default()
    };
    let result = eframe::run_native("OozeWalls", opts, Box::new(|cc| Ok(Box::new(Gui::new(cc)))));
    match &result {
        Ok(()) => diag_log("exit: ok"),
        Err(e) => diag_log(&format!("exit: error {}", e)),
    }
    result
}
