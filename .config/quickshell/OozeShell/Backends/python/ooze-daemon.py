#!/usr/bin/env python3
# BACKEND — ooze-daemon
# Una sola herramienta para el trabajo pesado de OozeShell.
#
# Modo servidor (para futuros frontends con stdin):
#   echo '{"cmd":"ping","id":1}' | ooze-daemon.py
# Modo one-shot (el que usa Quickshell, sin stdin en Process):
#   ooze-daemon.py nix-search --channel nixos-25.05 --max 40 -- emacs firefox
#   ooze-daemon.py palette -- /ruta/wallpaper.png
# Siempre imprime UN documento JSON por stdout.

import argparse
import json
import os
import shutil
import subprocess
import sys

HOME = os.path.expanduser("~")
TIMEOUT_SEARCH = 20
TIMEOUT_PALETTE = 30
CAP_RESULTS = 200


def reply(obj):
    sys.stdout.write(json.dumps(obj) + "\n")
    sys.stdout.flush()


def cmd_ping(req):
    reply({"id": req.get("id"), "ok": True, "pong": True})


def run_nix_search(terms, channel, extra_args, max_results):
    if shutil.which("nix-search") is None:
        return {"ok": False, "error": "missing"}
    cmd = ["nix-search"] + list(extra_args or [])
    if channel:
        cmd += ["--channel", channel]
    cmd += ["--"] + list(terms)
    try:
        out = subprocess.run(
            cmd, capture_output=True, text=True, timeout=TIMEOUT_SEARCH)
    except subprocess.TimeoutExpired:
        return {"ok": False, "error": "timeout"}
    except Exception as e:
        return {"ok": False, "error": str(e)[:200]}
    if out.returncode != 0 and not (out.stdout or "").strip():
        err = (out.stderr or "").strip().splitlines()
        return {"ok": False, "error": (err[-1] if err else "failed")[:200]}
    items = []
    for line in (out.stdout or "").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            parsed = json.loads(line)
        except Exception:
            continue
        if isinstance(parsed, list):
            items.extend(parsed)
        else:
            items.append(parsed)
        if len(items) >= min(max_results, CAP_RESULTS):
            break
    return {"ok": True, "results": items}


def run_palette(path):
    if shutil.which("matugen") is None:
        return {"ok": False, "error": "missing"}
    if not path or not os.path.isfile(path):
        return {"ok": False, "error": "no-file"}
    try:
        out = subprocess.run(
            ["matugen", "image", path, "--json", "hex"],
            capture_output=True, text=True, timeout=TIMEOUT_PALETTE)
    except subprocess.TimeoutExpired:
        return {"ok": False, "error": "timeout"}
    except Exception as e:
        return {"ok": False, "error": str(e)[:200]}
    if out.returncode != 0:
        return {"ok": False, "error": "failed"}
    return {"ok": True, "data": (out.stdout or "")[:16000]}


def extract_json_object(text):
    start = text.find("{")
    if start < 0:
        return ""
    try:
        _, end = json.JSONDecoder().raw_decode(text[start:])
        return text[start:start + end]
    except Exception:
        return ""


def run_palette_file(out_path, index, last_file, path):
    if not out_path:
        return {"ok": False, "error": "no-out"}
    try:
        if os.path.isfile(out_path) and os.path.getsize(out_path) > 0:
            return {"ok": True, "skipped": True}
    except Exception:
        pass
    if not path and last_file:
        try:
            with open(os.path.expanduser(last_file)) as f:
                path = f.readline().strip()
        except Exception:
            path = ""
    if shutil.which("matugen") is None:
        return {"ok": False, "error": "missing"}
    if not path or not os.path.isfile(path):
        return {"ok": False, "error": "no-file"}
    try:
        out = subprocess.run(
            ["matugen", "image", path, "--source-color-index", str(index),
             "--json", "hex"],
            capture_output=True, text=True, timeout=TIMEOUT_PALETTE)
    except subprocess.TimeoutExpired:
        return {"ok": False, "error": "timeout"}
    except Exception as e:
        return {"ok": False, "error": str(e)[:200]}
    doc = extract_json_object(out.stdout or "")
    if not doc:
        return {"ok": False, "error": "no-json"}
    try:
        os.makedirs(os.path.dirname(out_path), exist_ok=True)
        tmp = out_path + ".tmp"
        with open(tmp, "w") as f:
            f.write(doc + "\n")
        os.replace(tmp, out_path)
    except Exception as e:
        return {"ok": False, "error": str(e)[:200]}
    return {"ok": True, "skipped": False}


def xdg_data_dirs():
    dirs = []
    home = os.path.join(HOME, ".local", "share")
    dirs.append(home)
    for d in (os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share").split(":"):
        if d:
            dirs.append(d)
    try:
        user = os.environ.get("USER") or os.path.basename(HOME)
        dirs.append("/etc/profiles/per-user/%s/share" % user)
    except Exception:
        pass
    dirs.append(os.path.expanduser("~/.nix-profile/share"))
    seen, out = set(), []
    for d in dirs:
        if d not in seen:
            seen.add(d)
            out.append(d)
    return out


def parse_desktop(path):
    info = {}
    section = ""
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            for raw in f:
                line = raw.strip()
                if not line or line.startswith("#"):
                    continue
                if line.startswith("[") and line.endswith("]"):
                    section = line[1:-1]
                    continue
                if section != "Desktop Entry" or "=" not in line:
                    continue
                k, v = line.split("=", 1)
                if k in ("Name", "Icon", "Exec", "MimeType", "NoDisplay", "Hidden"):
                    info[k] = v.strip()
    except Exception:
        return {}
    return info


def run_desktop_mimes(mime):
    apps = []
    seen = set()
    for base in xdg_data_dirs():
        appdir = os.path.join(base, "applications")
        try:
            files = os.listdir(appdir)
        except Exception:
            continue
        for fn in files:
            if not fn.endswith(".desktop") or fn in seen:
                continue
            seen.add(fn)
            info = parse_desktop(os.path.join(appdir, fn))
            if not info:
                continue
            if info.get("NoDisplay", "").lower() == "true":
                continue
            if info.get("Hidden", "").lower() == "true":
                continue
            mimes = [m.strip() for m in info.get("MimeType", "").split(";") if m.strip()]
            if mime not in mimes:
                continue
            apps.append({"id": fn, "name": info.get("Name", fn),
                         "icon": info.get("Icon", ""),
                         "exec": info.get("Exec", "")})
    apps.sort(key=lambda a: a["name"].lower())
    return {"ok": True, "apps": apps}


def handle_req(req):
    cmd = req.get("cmd", "")
    if cmd == "ping":
        cmd_ping(req)
    elif cmd == "nix-search":
        r = run_nix_search(req.get("terms", []), req.get("channel", ""),
                           req.get("args", []), int(req.get("max", 40) or 40))
        r["id"] = req.get("id")
        reply(r)
    elif cmd == "palette":
        r = run_palette(req.get("path", ""))
        r["id"] = req.get("id")
        reply(r)
    elif cmd == "palette-file":
        r = run_palette_file(req.get("out", ""), int(req.get("index", 0) or 0),
                             req.get("last", ""), req.get("path", ""))
        r["id"] = req.get("id")
        reply(r)
    elif cmd == "desktop-mimes":
        r = run_desktop_mimes(req.get("mime", ""))
        r["id"] = req.get("id")
        reply(r)
    else:
        reply({"id": req.get("id"), "ok": False, "error": "unknown cmd"})


def main():
    if len(sys.argv) > 1:
        ap = argparse.ArgumentParser(prog="ooze-daemon")
        sub = ap.add_subparsers(dest="cmd", required=True)
        ns = sub.add_parser("nix-search")
        ns.add_argument("--channel", default="")
        ns.add_argument("--max", type=int, default=40)
        ns.add_argument("terms", nargs="*")
        ns.add_argument("--args", nargs=argparse.REMAINDER, default=None)
        pl = sub.add_parser("palette")
        pl.add_argument("path", nargs="?")
        pl.add_argument("--args", nargs="*", default=[])
        pf = sub.add_parser("palette-file")
        pf.add_argument("--out", default="")
        pf.add_argument("--index", type=int, default=0)
        pf.add_argument("--last", default="")
        pf.add_argument("path", nargs="?")
        dm = sub.add_parser("desktop-mimes")
        dm.add_argument("mime", nargs="?")
        a = ap.parse_args()
        if a.cmd == "nix-search":
            extra = ["--json", "--max-results", "40"]
            terms = list(a.terms)
            if a.args:
                rest = list(a.args)
                if "--" in rest:
                    i = rest.index("--")
                    extra = rest[:i] or extra
                    terms = terms + rest[i + 1:]
                else:
                    extra = rest
            reply(run_nix_search(terms, a.channel, extra, a.max))
        elif a.cmd == "palette":
            path = a.path
            if path == "--" or path is None:
                path = ""
            reply(run_palette(path))
        elif a.cmd == "palette-file":
            reply(run_palette_file(a.out, a.index, a.last, a.path or ""))
        elif a.cmd == "desktop-mimes":
            reply(run_desktop_mimes(a.mime or ""))
        return
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            req = json.loads(line)
        except Exception:
            continue
        handle_req(req)


if __name__ == "__main__":
    main()
