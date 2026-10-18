// SECCION: SOCKET SEND ALIVE LOAD PROP PAUSE QUIT
// IPC: loadfile set_property get_property cycle pause quit
use std::io::{BufRead, BufReader, Write};
use std::os::unix::net::UnixStream;
use std::path::{Path, PathBuf};

pub fn socket_dir() -> PathBuf {
    if let Some(dir) = std::env::var_os("XDG_RUNTIME_DIR") {
        if !dir.is_empty() {
            let p = PathBuf::from(dir).join("oozewalls");
            let _ = std::fs::create_dir_all(&p);
            return p;
        }
    }
    let home = std::env::var("HOME").unwrap_or_else(|_| String::from("/tmp"));
    let p = PathBuf::from(home).join(".cache/oozewalls/ipc");
    let _ = std::fs::create_dir_all(&p);
    p
}

pub fn socket_for(output: &str) -> PathBuf {
    let clean: String = output
        .chars()
        .filter(|c| c.is_alphanumeric() || *c == '-' || *c == '_')
        .collect();
    let name = if clean.is_empty() {
        String::from("all")
    } else {
        clean
    };
    socket_dir().join(format!("mpv_{}.sock", name))
}

pub fn output_for_socket(sock: &Path) -> String {
    let stem = sock
        .file_stem()
        .and_then(|s| s.to_str())
        .unwrap_or("mpv_all");
    let raw = stem.strip_prefix("mpv_").unwrap_or("all");
    if raw == "all" {
        String::from("*")
    } else {
        raw.to_string()
    }
}

pub fn send(sock: &Path, json_cmd: &str) -> Result<String, String> {
    let mut stream = UnixStream::connect(sock).map_err(|e| format!("ipc connect {}", e))?;
    stream
        .set_read_timeout(Some(std::time::Duration::from_millis(400)))
        .map_err(|e| format!("ipc rtimeout {}", e))?;
    stream
        .set_write_timeout(Some(std::time::Duration::from_millis(400)))
        .map_err(|e| format!("ipc wtimeout {}", e))?;
    stream
        .write_all(json_cmd.as_bytes())
        .map_err(|e| format!("ipc write {}", e))?;
    stream
        .write_all(b"\n")
        .map_err(|e| format!("ipc newline {}", e))?;
    stream.flush().map_err(|e| format!("ipc flush {}", e))?;
    let mut reader = BufReader::new(stream);
    let mut last = String::new();
    for _ in 0..32 {
        let mut line = String::new();
        let n = reader
            .read_line(&mut line)
            .map_err(|e| format!("ipc read {}", e))?;
        if n == 0 {
            break;
        }
        if line.contains("\"error\"") {
            return Ok(line);
        }
        last = line;
    }
    if last.is_empty() {
        Err(String::from("ipc sin respuesta"))
    } else {
        Ok(last)
    }
}

pub fn is_alive(sock: &Path) -> bool {
    if !sock.exists() {
        return false;
    }
    match send(sock, r#"{"command": ["get_property", "pause"]}"#) {
        Ok(resp) => resp.contains("error") && resp.contains("success"),
        Err(_) => false,
    }
}

pub fn discover() -> Vec<PathBuf> {
    let mut out = Vec::new();
    if let Ok(entries) = std::fs::read_dir(socket_dir()) {
        for e in entries.filter_map(|x| x.ok()) {
            let p = e.path();
            if p.extension().and_then(|x| x.to_str()) == Some("sock") && is_alive(&p) {
                out.push(p);
            }
        }
    }
    out.sort();
    out
}

pub fn loadfile(sock: &Path, file: &str) -> Result<(), String> {
    let cmd = serde_json::json!({"command": ["loadfile", file, "replace"]});
    let text = serde_json::to_string(&cmd).map_err(|e| e.to_string())?;
    let resp = send(sock, &text)?;
    if resp.contains("\"error\":\"success\"") {
        Ok(())
    } else {
        Err(format!("loadfile {}", resp))
    }
}

pub fn set_prop<T: serde::Serialize>(sock: &Path, prop: &str, val: T) -> Result<(), String> {
    let cmd = serde_json::json!({"command": ["set_property", prop, val]});
    let text = serde_json::to_string(&cmd).map_err(|e| e.to_string())?;
    let resp = send(sock, &text)?;
    if resp.contains("\"error\":\"success\"") {
        Ok(())
    } else {
        Err(format!("set_property {}", resp))
    }
}

pub fn get_bool(sock: &Path, prop: &str) -> Option<bool> {
    let cmd = format!("{{\"command\": [\"get_property\", \"{}\"]}}", prop);
    let resp = send(sock, &cmd).ok()?;
    serde_json::from_str::<serde_json::Value>(&resp)
        .ok()?
        .get("data")?
        .as_bool()
}

pub fn get_u64(sock: &Path, prop: &str) -> Option<u64> {
    let cmd = format!("{{\"command\": [\"get_property\", \"{}\"]}}", prop);
    let resp = send(sock, &cmd).ok()?;
    serde_json::from_str::<serde_json::Value>(&resp)
        .ok()?
        .get("data")?
        .as_u64()
}

pub fn cycle_pause(sock: &Path) -> Result<bool, String> {
    let _ = send(sock, r#"{"command": ["cycle", "pause"]}"#)?;
    let resp = send(sock, r#"{"command": ["get_property", "pause"]}"#)?;
    if let Ok(val) = serde_json::from_str::<serde_json::Value>(&resp) {
        if let Some(b) = val.get("data").and_then(|d| d.as_bool()) {
            return Ok(b);
        }
    }
    Ok(false)
}

pub fn quit(sock: &Path) {
    let _ = send(sock, r#"{"command": ["quit"]}"#);
}
