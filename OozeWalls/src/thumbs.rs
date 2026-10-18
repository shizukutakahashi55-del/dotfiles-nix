// SECCION: THUMBS CACHE FFMPEG IMAGE
// IPC: thumb
use std::path::{Path, PathBuf};
use std::process::Command;

pub const W: u32 = 384;
pub const H: u32 = 216;

pub fn dir() -> PathBuf {
    let home = std::env::var("HOME").unwrap_or_else(|_| String::from("/tmp"));
    let p = PathBuf::from(home).join(".cache/oozewalls/thumbs");
    let _ = std::fs::create_dir_all(&p);
    p
}

fn hash_name(s: &str) -> String {
    use std::collections::hash_map::DefaultHasher;
    use std::hash::{Hash, Hasher};
    let mut h = DefaultHasher::new();
    s.hash(&mut h);
    format!("{:016x}", h.finish())
}

pub fn path_for(file: &str) -> PathBuf {
    dir().join(format!("{}.jpg", hash_name(&format!("v2|{}", file))))
}

pub fn cached_path(file: &str) -> Option<PathBuf> {
    let p = path_for(file);
    if p.is_file() {
        Some(p)
    } else {
        None
    }
}

fn source_newer(file: &str, thumb: &Path) -> bool {
    let src = Path::new(file).metadata().and_then(|m| m.modified()).ok();
    let dst = thumb.metadata().and_then(|m| m.modified()).ok();
    match (src, dst) {
        (Some(a), Some(b)) => a > b,
        _ => true,
    }
}

fn run_ffmpeg(video: &str, out: &Path) -> bool {
    let fast = Command::new("ffmpeg")
        .args([
            "-nostdin",
            "-y",
            "-v",
            "error",
            "-ss",
            "1",
            "-i",
            video,
            "-frames:v",
            "1",
            "-vf",
            "scale=384:-2",
            "-q:v",
            "4",
        ])
        .arg(out)
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false);
    if fast && out.is_file() {
        return true;
    }
    Command::new("ffmpeg")
        .args([
            "-nostdin",
            "-y",
            "-v",
            "error",
            "-i",
            video,
            "-frames:v",
            "1",
            "-vf",
            "scale=384:-2",
            "-q:v",
            "4",
        ])
        .arg(out)
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false)
        && out.is_file()
}

fn small(img: &image::RgbImage) -> image::RgbImage {
    let (w, h) = (img.width().max(1), img.height().max(1));
    let target = W as f32 / H as f32;
    let aspect = w as f32 / h as f32;
    let (x, y, cw, ch) = if aspect > target {
        let nw = ((h as f32 * target) as u32).clamp(1, w);
        ((w - nw) / 2, 0, nw, h)
    } else {
        let nh = ((w as f32 / target) as u32).clamp(1, h);
        (0, (h - nh) / 2, w, nh)
    };
    let view = image::imageops::crop_imm(img, x, y, cw, ch).to_image();
    image::imageops::resize(&view, W, H, image::imageops::FilterType::Triangle)
}

fn run_image(src: &str, out: &Path) -> bool {
    let img = match image::open(src) {
        Ok(i) => i.to_rgb8(),
        Err(_) => return false,
    };
    small(&img)
        .save_with_format(out, image::ImageFormat::Jpeg)
        .is_ok()
}

pub fn ensure(file: &str, is_video: bool) -> Option<PathBuf> {
    let out = path_for(file);
    if out.is_file() && !source_newer(file, &out) {
        return Some(out);
    }
    let ok = if is_video {
        run_ffmpeg(file, &out)
    } else {
        run_image(file, &out)
    };
    if ok {
        Some(out)
    } else {
        None
    }
}

fn read_rgba(p: &Path) -> Option<(usize, usize, Vec<u8>)> {
    let img = image::open(p).ok()?.to_rgb8();
    let rgba = image::DynamicImage::ImageRgb8(small(&img)).to_rgba8();
    Some((
        rgba.width() as usize,
        rgba.height() as usize,
        rgba.into_raw(),
    ))
}

pub fn load_cached(file: &str, is_video: bool) -> Option<(usize, usize, Vec<u8>)> {
    let p = ensure(file, is_video)?;
    read_rgba(&p)
}

pub fn peek(file: &str) -> Option<(usize, usize, Vec<u8>)> {
    let p = cached_path(file)?;
    read_rgba(&p)
}
