// SECCION: SCAN FILTER SORT BROWSE
// IPC: list scan browse folders
use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use std::path::{Path, PathBuf};

pub const VIDEO_EXTS: &[&str] = &["mp4", "mkv", "webm", "mov", "avi", "m4v"];
pub const IMAGE_EXTS: &[&str] = &["png", "jpg", "jpeg", "webp", "gif"];
const MAX_DEPTH: usize = 4;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Entry {
    pub name: String,
    pub path: String,
    pub is_video: bool,
    pub bytes: u64,
    pub mtime: u64,
    #[serde(default)]
    pub folder: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Folder {
    pub name: String,
    pub path: String,
    pub videos: u32,
    pub images: u32,
    pub subfolders: u32,
    pub missing: bool,
}

pub fn is_video_ext(ext: &str) -> bool {
    VIDEO_EXTS.contains(&ext.to_lowercase().as_str())
}

pub fn is_image_ext(ext: &str) -> bool {
    IMAGE_EXTS.contains(&ext.to_lowercase().as_str())
}

pub fn is_supported(ext: &str) -> bool {
    is_video_ext(ext) || is_image_ext(ext)
}

pub fn is_video_path(p: &Path) -> bool {
    p.extension()
        .and_then(|e| e.to_str())
        .map(is_video_ext)
        .unwrap_or(false)
}

fn is_hidden(name: &str) -> bool {
    name.starts_with('.')
}

fn base_name(p: &Path, fallback: &str) -> String {
    p.file_name()
        .map(|x| x.to_string_lossy().to_string())
        .unwrap_or_else(|| fallback.to_string())
}

fn entry_of(p: &Path) -> Option<Entry> {
    let ext = p.extension().and_then(|x| x.to_str())?;
    if !is_supported(ext) {
        return None;
    }
    let meta = std::fs::metadata(p).ok()?;
    if !meta.is_file() {
        return None;
    }
    let mtime = meta
        .modified()
        .ok()
        .and_then(|t| t.duration_since(std::time::UNIX_EPOCH).ok())
        .map(|d| d.as_secs())
        .unwrap_or(0);
    Some(Entry {
        name: base_name(p, ""),
        path: p.to_string_lossy().to_string(),
        is_video: is_video_ext(ext),
        bytes: meta.len(),
        mtime,
        folder: p
            .parent()
            .map(|x| x.to_string_lossy().to_string())
            .unwrap_or_default(),
    })
}

fn walk(dir: &Path, depth: usize, out: &mut Vec<Entry>, seen: &mut HashSet<String>) {
    let rd = match std::fs::read_dir(dir) {
        Ok(r) => r,
        Err(_) => return,
    };
    for e in rd.filter_map(|x| x.ok()) {
        let name = e.file_name().to_string_lossy().to_string();
        if is_hidden(&name) {
            continue;
        }
        let p = e.path();
        if p.is_dir() {
            if depth < MAX_DEPTH {
                walk(&p, depth + 1, out, seen);
            }
            continue;
        }
        if let Some(en) = entry_of(&p) {
            if seen.insert(en.path.clone()) {
                out.push(en);
            }
        }
    }
}

pub fn scan(dirs: &[String]) -> Vec<Entry> {
    let mut out = Vec::new();
    let mut seen = HashSet::new();
    for d in dirs {
        walk(Path::new(d), 0, &mut out, &mut seen);
    }
    out.sort_by(|a, b| b.mtime.cmp(&a.mtime).then_with(|| a.name.cmp(&b.name)));
    out
}

pub fn folder_info(path: &str) -> Folder {
    let p = Path::new(path);
    let mut f = Folder {
        name: base_name(p, path),
        path: path.to_string(),
        videos: 0,
        images: 0,
        subfolders: 0,
        missing: false,
    };
    let rd = match std::fs::read_dir(p) {
        Ok(r) => r,
        Err(_) => {
            f.missing = true;
            return f;
        }
    };
    for e in rd.filter_map(|x| x.ok()) {
        let name = e.file_name().to_string_lossy().to_string();
        if is_hidden(&name) {
            continue;
        }
        let q = e.path();
        if q.is_dir() {
            f.subfolders += 1;
            continue;
        }
        match q.extension().and_then(|x| x.to_str()) {
            Some(ext) if is_video_ext(ext) => f.videos += 1,
            Some(ext) if is_image_ext(ext) => f.images += 1,
            _ => {}
        }
    }
    f
}

pub fn list_dir(path: &str) -> (Vec<Folder>, Vec<Entry>) {
    let mut folders = Vec::new();
    let mut entries = Vec::new();
    if let Ok(rd) = std::fs::read_dir(path) {
        for e in rd.filter_map(|x| x.ok()) {
            let name = e.file_name().to_string_lossy().to_string();
            if is_hidden(&name) {
                continue;
            }
            let p = e.path();
            if p.is_dir() {
                folders.push(folder_info(&p.to_string_lossy()));
            } else if let Some(en) = entry_of(&p) {
                entries.push(en);
            }
        }
    }
    folders.sort_by(|a, b| a.name.to_lowercase().cmp(&b.name.to_lowercase()));
    entries.sort_by(|a, b| a.name.to_lowercase().cmp(&b.name.to_lowercase()));
    (folders, entries)
}

pub fn is_inside(path: &str, root: &str) -> bool {
    Path::new(path).starts_with(Path::new(root))
}

pub fn root_for(path: &str, roots: &[String]) -> Option<String> {
    let p: PathBuf = std::fs::canonicalize(path).ok()?;
    let mut best: Option<(usize, String)> = None;
    for r in roots {
        let rc = match std::fs::canonicalize(r) {
            Ok(x) => x,
            Err(_) => continue,
        };
        if p.starts_with(&rc) {
            let depth = rc.components().count();
            if best.as_ref().map(|b| depth > b.0).unwrap_or(true) {
                best = Some((depth, r.clone()));
            }
        }
    }
    best.map(|b| b.1)
}

pub fn same_dir(a: &str, b: &str) -> bool {
    match (std::fs::canonicalize(a), std::fs::canonicalize(b)) {
        (Ok(x), Ok(y)) => x == y,
        _ => a == b,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn ext_detect() {
        assert!(is_video_ext("mp4"));
        assert!(is_video_ext("MP4"));
        assert!(is_image_ext("jpg"));
        assert!(is_supported("webm"));
        assert!(!is_supported("txt"));
    }
    #[test]
    fn socket_names() {
        let a = crate::ipc::socket_for("*");
        assert!(a.to_string_lossy().ends_with("mpv_all.sock"));
        let b = crate::ipc::socket_for("HDMI-A-1");
        assert!(b.to_string_lossy().ends_with("mpv_HDMI-A-1.sock"));
        let c = crate::ipc::socket_for("HDMI-A-1/test");
        assert!(c.to_string_lossy().ends_with("mpv_HDMI-A-1test.sock"));
    }
    #[test]
    fn inside_roots() {
        assert!(is_inside("/a/b/c", "/a/b"));
        assert!(is_inside("/a/b", "/a/b"));
        assert!(!is_inside("/a/bc", "/a/b"));
    }
}
