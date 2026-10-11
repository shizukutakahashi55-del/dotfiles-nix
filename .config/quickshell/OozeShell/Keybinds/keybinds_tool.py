# keybinds_tool.py — parsea y edita los binds de Hyprland para OozeShell.
# Comandos (imprimen JSON a stdout; errores a stderr + exit != 0):

import hashlib
import json
import os
import re
import shutil
import sys

HOME = os.path.expanduser("~")
HYPR = os.path.join(HOME, ".config", "hypr")
KEYBINDS_LUA = os.path.join(HYPR, "modules", "input", "keybinds.lua")
MANGO_BINDS = os.path.join(HOME, ".config", "mango", "conf", "keybinds.conf")
NIRI_BINDS = os.path.join(HOME, ".config", "niri", "modules", "binds.kdl")
AUTOGEN_DIR = os.path.join(HYPR, "modules", "input", "autogen")
AUTOGEN_LUA = os.path.join(AUTOGEN_DIR, "binds.lua")
OOZE_DIR = os.path.join(HOME, ".config", "oozeshell")
STATE_JSON = os.path.join(OOZE_DIR, "keybinds.json")

MARK_DISABLED = "OOZE-DISABLED"
MARK_OVERRIDE = "OOZE-OVERRIDE"

AUTOGEN_HEADER = """-- ============================================================================
--  MODULE: modules/input/autogen/binds.lua
--  Auto-generado por OozeShell (Ajustes avanzados → Keybinds). NO EDITAR
--  A MANO: se regenera entero en cada guardado desde el editor.
--
--  Contiene SOLO overrides de binds originales (con combo cambiado) y binds
--  nuevos creados desde el editor. Los binds originales siguen viviendo en
--  modules/input/keybinds.lua; al borrar/desactivar uno, el editor lo comenta
--  ahi con `-- OOZE-DISABLED <id>` en vez de borrarlo, asi se puede restaurar.
--  El estado espejo vive en ~/.config/oozeshell/keybinds.json.
--
--  Los overrides copian el hl.bind() original tal cual (solo cambia el
--  combo), asi que necesitan los mismos requires que keybinds.lua para
--  `programs.*` y `functions.*` (snippets en modules/input/snippets/).
-- ============================================================================

local programs = require("modules.startup.programs")
local functions = require("modules.input.snippets.keybind_functions")
"""


def fail(msg):
    sys.stderr.write("keybinds_tool: %s\n" % msg)
    sys.exit(1)


def norm_combo(combo):
    """SUPER+shift+t  ->  SUPER + SHIFT + T (mods en mayus, tecla intacta)."""
    parts = [p.strip() for p in str(combo).split("+")]
    parts = [p for p in parts if p]
    out = []
    for p in parts:
        if p.upper() in ("SUPER", "SHIFT", "CTRL", "CONTROL", "ALT", "META"):
            p = "CTRL" if p.upper() == "CONTROL" else p.upper()
            if p == "META":
                p = "SUPER"
            out.append(p)
        else:
            out.append(p)
    return " + ".join(out)


def combo_key(combo):
    return re.sub(r"\s+", " ", str(combo).strip().upper())


def valid_combo(combo):
    c = str(combo).strip()
    if not c:
        return False

    if "+" not in c:
        return re.match(r"^[A-Za-z0-9_:]+$", c) is not None
    parts = [p.strip() for p in c.split("+")]
    return all(re.match(r"^[A-Za-z0-9_:]+$", p) for p in parts) and len(parts) >= 2


def orig_id(combo_norm, action_norm):
    h = hashlib.sha1(("%s|%s" % (combo_key(combo_norm), action_norm)).encode()).hexdigest()
    return "o" + h[:8]


def custom_id(combo, cmd):
    h = hashlib.sha1(("%s|%s" % (combo_key(combo), cmd.strip())).encode()).hexdigest()
    return "c" + h[:8]


def lua_escape(s):
    return str(s).replace("\\", "\\\\").replace('"', '\\"').replace("\n", " ")


def load_state():
    try:
        with open(STATE_JSON, "r", encoding="utf-8") as f:
            st = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        st = {}
    st.setdefault("overrides", {})
    st.setdefault("disabled", [])
    st.setdefault("customs", [])
    return st


def save_state(st):
    os.makedirs(OOZE_DIR, exist_ok=True)
    tmp = STATE_JSON + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(st, f, indent=2, ensure_ascii=False)
        f.write("\n")
    os.replace(tmp, STATE_JSON)


def strip_ooze_marker(line):
    """Quita `-- OOZE-... ...` inicial, devuelve (codigo, marker_id o None)."""
    m = re.match(r"^\s*--\s*(OOZE-DISABLED|OOZE-OVERRIDE)\s+(\S+)?\s?(.*)$", line)
    if m:
        return m.group(3), m.group(2)
    m2 = re.match(r"^\s*--\s?(.*)$", line)
    if m2:
        return m2.group(1), None
    return line, None


def is_plain_comment(line):
    return line.strip().startswith("--")


def find_main_mod(lines):
    for line in lines:
        m = re.search(r'local\s+mainMod\s*=\s*"([^"]+)"', line)
        if m:
            return m.group(1)
    return "SUPER"


def split_top_level(s):
    """Divide por comas de nivel 0 (respeta (), {}, strings)."""
    parts, depth, cur = [], 0, []
    i, n = 0, len(s)
    quote = None
    while i < n:
        ch = s[i]
        if quote:
            cur.append(ch)
            if ch == "\\" and i + 1 < n:
                cur.append(s[i + 1])
                i += 2
                continue
            if ch == quote:
                quote = None
        elif ch in ('"', "'"):
            quote = ch
            cur.append(ch)
        elif ch in "([{":
            depth += 1
            cur.append(ch)
        elif ch in ")]}":
            depth -= 1
            cur.append(ch)
        elif ch == "," and depth == 0:
            parts.append("".join(cur))
            cur = []
        else:
            cur.append(ch)
        i += 1
    parts.append("".join(cur))
    return parts


def paren_end(lines, si, pos):
    """Balancea desde el '(' en lines[si][pos]; devuelve (ei, epos)."""
    depth, quote = 0, None
    for li in range(si, len(lines)):
        line = lines[li]
        start = pos if li == si else 0
        i = start
        while i < len(line):
            ch = line[i]
            if quote:
                if ch == "\\":
                    i += 2
                    continue
                if ch == quote:
                    quote = None
            elif ch in ('"', "'"):

                quote = ch
            elif ch == "(":
                depth += 1
            elif ch == ")":
                depth -= 1
                if depth == 0:
                    return li, i
            i += 1
    return None, None


def resolve_combo(expr, main_mod):
    e = expr.strip()

    e2 = re.sub(r"\bmainMod\b", '"%s"' % main_mod, e)
    if ".." in e2:
        chunks = [c.strip() for c in e2.split("..")]
        lit = True
        acc = []
        for c in chunks:
            m = re.match(r'^"(.*)"$', c, re.S) or re.match(r"^'(.*)'$", c, re.S)
            if not m:
                lit = False
                break
            acc.append(m.group(1))
        if lit:
            return norm_combo("".join(acc)), False
        return norm_combo("".join(acc)), True
    m = re.match(r'^"(.*)"$', e2, re.S) or re.match(r"^'(.*)'$", e2, re.S)
    if m:
        return norm_combo(m.group(1)), False
    return norm_combo(e2.strip("\"' ")), True


def action_summary(action_expr):
    a = re.sub(r"\s+", " ", action_expr.strip())
    m = re.search(r'exec_cmd\(\s*"((?:[^"\\]|\\.)*)"', a) or re.search(
        r"exec_cmd\(\s*'((?:[^'\\]|\\.)*)'", a)
    if m:
        cmd = m.group(1)
        return (cmd[:60] + "…") if len(cmd) > 60 else cmd, "exec"
    m = re.search(r"hl\.dsp\.([a-zA-Z0-9_.]+)", a)
    if m:
        return m.group(1), "dsp"
    if a.startswith("function") or "function(" in a or "function (" in a:
        return "custom function", "lua"
    if re.match(r"^hl\.[a-zA-Z0-9_.]+\s*(\(.*\))?$", a):
        return a[:60], "hl"
    return (a[:60] + "…") if len(a) > 60 else a, "lua"


def lookup_desc(lines, si):
    for j in range(si - 1, max(si - 4, -1), -1):
        t = lines[j].strip()
        if t == "" or re.match(r"^--\s*-+\s*$", t):
            continue
        if t.startswith("--"):
            body = re.sub(r"^--\s?", "", t).strip()
            if not body or "hl.bind" in body or body.startswith(("OOZE-", "TODO", "NOTE")):
                continue
            if re.match(r"^[A-Z /-]{4,}$", body):
                continue
            return body[:80]
        break
    return ""


def parse_file():
    with open(KEYBINDS_LUA, "r", encoding="utf-8") as f:
        raw_lines = f.read().splitlines()
    main_mod = find_main_mod(raw_lines)
    binds = []
    i = 0
    n = len(raw_lines)
    while i < n:
        line = raw_lines[i]
        code, marker = strip_ooze_marker(line) if is_plain_comment(line) else (line, None)
        m = re.search(r"(?:^|[\s;])hl\.bind\s*\(", code)
        if not m:
            i += 1
            continue

        if is_plain_comment(line) and marker is None:

            ei, ep = paren_end([code] + raw_lines[i + 1:], 0, code.index("hl.bind") + 7)
            if ei is not None:
                i += ei + 1
            else:
                i += 1
            continue
        par = code.index("hl.bind") + len("hl.bind")
        ei_rel, _ = paren_end([code] + raw_lines[i + 1:], 0, par)
        if ei_rel is None:
            i += 1
            continue
        ei = i + ei_rel
        block = [code] + [strip_ooze_marker(l)[0] if is_plain_comment(l) else l
                          for l in raw_lines[i + 1:ei + 1]]
        call_text = "\n".join(block)
        inner = call_text[call_text.index("(", call_text.index("hl.bind")) + 1: call_text.rindex(")")]
        args = split_top_level(inner)
        if len(args) < 2:
            i = ei + 1
            continue
        combo_raw = args[0]
        combo, generated = resolve_combo(combo_raw, main_mod)
        action_expr = args[1].strip()
        action_norm = re.sub(r"\s+", " ", action_expr)
        summary, kind = action_summary(action_expr)
        desc = ""
        if len(args) >= 3:
            dm = re.search(r'description\s*=\s*"((?:[^"\\]|\\.)*)"', args[2])
            if dm:
                desc = dm.group(1)[:80]
        if not desc:
            desc = lookup_desc(raw_lines, i)
        bid = orig_id(combo, action_norm)
        binds.append({
            "id": bid,
            "combo": combo,
            "desc": desc,
            "action": summary,
            "actionKind": ("generated" if generated else kind),
            "generated": generated,
            "enabled": marker is None,
            "marker": marker,
            "start": i + 1,
            "end": ei + 1,


            "src": "\n".join(block),
        })
        i = ei + 1
    return binds, raw_lines


def effective_combos(binds, st):
    eff = {}
    for b in binds:
        if b["id"] in st["overrides"]:
            eff[b["id"]] = combo_key(st["overrides"][b["id"]]["combo"])
        elif b["enabled"]:
            eff[b["id"]] = combo_key(b["combo"])
    for c in st["customs"]:
        eff[c["id"]] = combo_key(c["combo"])
    return eff


def check_conflict(binds, st, combo, skip_id=None):
    key = combo_key(combo)
    for bid, ck in effective_combos(binds, st).items():
        if bid != skip_id and ck == key:
            return bid
    return None


def backup_once():
    bak = KEYBINDS_LUA + ".bak"
    if not os.path.exists(bak):
        shutil.copy2(KEYBINDS_LUA, bak)


def comment_range(lines, start0, end0, marker, bid):
    for k in range(start0, end0 + 1):
        if lines[k].strip() == "":
            lines[k] = "-- %s %s" % (marker, bid)
        elif not lines[k].lstrip().startswith("--"):
            lines[k] = "-- %s %s %s" % (marker, bid, lines[k])
    return lines


def uncomment_id(lines, bid):
    pat = re.compile(r"^(\s*)--\s*(OOZE-DISABLED|OOZE-OVERRIDE)\s+%s\s?(.*)$" % re.escape(bid))
    changed = False
    for k, l in enumerate(lines):
        m = pat.match(l)
        if m:
            lines[k] = m.group(1) + m.group(3)
            changed = True

    return lines, changed


def write_lines(lines):
    tmp = KEYBINDS_LUA + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    os.replace(tmp, KEYBINDS_LUA)


def swap_combo(src, new_combo):
    """Reemplaza el primer argumento de hl.bind(...) por el combo nuevo."""
    idx = src.index("hl.bind")
    p0 = src.index("(", idx)

    depth, quote, i = 0, None, p0 + 1
    while i < len(src):
        ch = src[i]
        if quote:
            if ch == "\\":
                i += 2
                continue
            if ch == quote:
                quote = None
        elif ch in ('"', "'"):
            quote = ch
        elif ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        elif ch == "," and depth == 0:
            break
        i += 1
    if i >= len(src):
        fail("no se pudo separar el combo del bind original")
    return src[:p0 + 1] + '\n    "%s",%s' % (lua_escape(new_combo), src[i + 1:])


def regenerate(binds, st):
    os.makedirs(AUTOGEN_DIR, exist_ok=True)
    by_id = {b["id"]: b for b in binds}
    out = [AUTOGEN_HEADER]
    for bid, ov in st["overrides"].items():
        b = by_id.get(bid)
        if not b:
            continue
        new_src = swap_combo(
            "\n".join(b["src"].splitlines()), ov["combo"])
        out.append("-- %s %s orig: %s\n%s\n" % (MARK_OVERRIDE, bid, b["combo"], new_src))
    for c in st["customs"]:
        out.append(
            '-- custom %s: %s\nhl.bind("%s", hl.dsp.exec_cmd("%s"), '
            '{ description = "%s" })\n' % (
                c["id"], c.get("desc", ""), lua_escape(c["combo"]),
                lua_escape(c["cmd"]), lua_escape(c.get("desc", ""))))
    tmp = AUTOGEN_LUA + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write("\n".join(out))
        if not out[-1].endswith("\n"):
            f.write("\n")
    os.replace(tmp, AUTOGEN_LUA)


# ─── Categorías (mismas del cheatsheet) ───────────────────────────
CAT_SHOTS = re.compile(r"screenshot|screencopy|grimblast|hyprshot|\bgrim\b|\bslurp\b|flameshot|spectacle|captura")
CAT_SHELL = re.compile(r"\bqs\b|quickshell|\bipc\b|ooze|hyprlock|\block\b|lockscreen|powermenu|power-menu|clipboard|cliphist|portapapeles|notif|wallpaper|fondo|apariencia|appearance|idioma|language|xkb|teclado|keyboard|overview|vista previa|hoja de atajos|cheatsheet|performance|rendimiento|quicksearch|quickaccess")
CAT_SPECIAL = re.compile(r"special|scratchpad|minimi")
CAT_WORKSPACES = re.compile(r"workspace|desktop|escritorio|\bview\b|\btag\b|tagsilent|toggletag|viewto|tagto|mouse_(up|down)|scroll")
CAT_LAYOUT = re.compile(r"layout|togglesplit|splitratio|\bsplit\b|colresize|swapsplit|orientation|coding|diseno|diseño")
CAT_COLUMNS = re.compile(r"column|width|height")
CAT_MOUSE = re.compile(r"mouse:?\d|\blmb\b|\brmb\b|\bdrag\b|resizewindow")
CAT_WINDOWS = re.compile(r"float|fullscreen|pseudo|close|kill|cycle|bringactive|alternate|switcher|pin\b|tabbed|group")
CAT_MOVE = re.compile(r"\bmove\b|movewindow|movewin|swap|exchange")
CAT_FOCUS = re.compile(r"focus")
CAT_EXEC = re.compile(r"exec|\bspawn\b")


def categorize(action, desc="", combo="", kind="", generated=False):
    text = (str(action) + " " + str(desc)).lower()
    keys = str(combo).lower()
    if re.search(r"\bprint\b", keys) or CAT_SHOTS.search(text):
        return "shots"
    if CAT_SHELL.search(text):
        return "shell"
    if CAT_SPECIAL.search(text):
        return "special"
    if generated or CAT_WORKSPACES.search(text) or CAT_WORKSPACES.search(keys):
        return "workspaces"
    if CAT_LAYOUT.search(text):
        return "layout"
    if CAT_MOUSE.search(text) or CAT_MOUSE.search(keys):
        return "windows"
    if CAT_WINDOWS.search(text):
        return "windows"
    if CAT_MOVE.search(text):
        return "move"
    if CAT_FOCUS.search(text):
        return "focus"
    if CAT_COLUMNS.search(text):
        return "layout"
    if kind == "exec" or CAT_EXEC.search(text):
        return "apps"
    if "window" in text:
        return "windows"
    return "other"


def cmd_list():
    if not os.path.exists(KEYBINDS_LUA):
        fail("no existe %s" % KEYBINDS_LUA)
    binds, _ = parse_file()
    st = load_state()
    eff = effective_combos(binds, st)
    items = []
    for b in binds:
        status = "active"
        shown = b["combo"]
        if b["id"] in st["overrides"]:
            status = "modified"
            shown = st["overrides"][b["id"]]["combo"]
        elif not b["enabled"] or b["id"] in st["disabled"]:
            status = "disabled"
        items.append({
            "id": b["id"], "combo": shown, "origCombo": b["combo"],
            "desc": b["desc"], "action": b["action"], "kind": b["actionKind"],
            "generated": b["generated"], "editable": not b["generated"],
            "status": status, "custom": False,
            "category": categorize(b["src"], b["desc"], shown, b["actionKind"], b["generated"]),
        })
    for c in st["customs"]:
        items.append({
            "id": c["id"], "combo": c["combo"], "origCombo": "",
            "desc": c.get("desc", ""), "action": c["cmd"][:60], "kind": "exec",
            "generated": False, "editable": True,
            "status": "custom", "custom": True,
            "category": categorize(c["cmd"], c.get("desc", ""), c["combo"], "exec"),
        })
    print(json.dumps({"binds": items, "state": st}, ensure_ascii=False))


def wm_id(prefix, combo, action):
    h = hashlib.sha1(("%s|%s" % (combo_key(combo), action)).encode()).hexdigest()
    return prefix + h[:8]


def parse_mango():
    """Lee keybinds.conf de Mango: bind=MODS,tecla,accion[,args]. Solo lectura."""
    with open(MANGO_BINDS, "r", encoding="utf-8") as f:
        lines = f.read().splitlines()
    out = []
    for i, raw in enumerate(lines):
        line = raw.strip()
        if not line.startswith("bind="):
            continue
        body = line[len("bind="):]
        parts = [p.strip() for p in body.split(",")]
        if len(parts) < 3:
            continue
        combo = norm_combo(parts[0] + " + " + parts[1])
        action = ", ".join(parts[2:])
        desc = ""
        for j in range(i - 1, max(i - 4, -1), -1):
            t = lines[j].strip()
            if t == "" or re.match(r"^-+\s*$", t):
                continue
            if t.startswith("#"):
                b = re.sub(r"^#\s?", "", t).strip()
                if b and "hl.bind" not in b and not re.match(r"^[A-Z /-]{4,}$", b):
                    desc = b[:80]
            break
        out.append({
            "id": wm_id("m", combo, action), "combo": combo, "origCombo": combo,
            "desc": desc, "action": action[:80], "kind": "mango",
            "generated": False, "editable": False, "status": "active",
            "custom": False, "wm": "mango", "manual": True,
            "category": categorize(action, desc, combo, "mango"),
        })
    return out


def parse_niri():
    """Lee binds.kdl de Niri: Mod+T { spawn "foot"; }. Solo lectura."""
    with open(NIRI_BINDS, "r", encoding="utf-8") as f:
        text = f.read()
    lines = text.splitlines()

    code = []
    descs = {}
    for i, raw in enumerate(lines):
        s = raw.strip()
        if s.startswith("//"):
            code.append("")
            continue

        cut = raw.find("//")
        if cut >= 0 and raw[:cut].count('"') % 2 == 0:
            raw = raw[:cut]
        code.append(raw)
    flat = "\n".join(code)
    out = []
    for m in re.finditer(r"([A-Za-z0-9_+]+)\s*\{\s*([^{}]*?)\s*\}", flat):
        combo_raw, inner = m.group(1), m.group(2)
        if combo_raw == "binds":
            continue
        if inner.strip() == "" or re.search(r"\{", inner):
            continue
        combo = norm_combo(combo_raw.replace("+", " + "))
        action = re.sub(r"\s+", " ", inner.strip().rstrip(";"))[:80]

        desc = ""
        upto = flat[:m.start()].count("\n")
        for j in range(upto - 1, max(upto - 5, -1), -1):
            if j >= len(lines):
                continue
            t = lines[j].strip()
            if t == "":
                continue
            if t.startswith("//"):
                b = re.sub(r"^//\s?", "", t).strip()
                if b and not re.match(r"^[-=]{3,}", b):
                    desc = b[:80]
            break
        out.append({
            "id": wm_id("n", combo, action), "combo": combo, "origCombo": combo,
            "desc": desc, "action": action, "kind": "niri",
            "generated": False, "editable": False, "status": "active",
            "custom": False, "wm": "niri", "manual": True,
            "category": categorize(action, desc, combo, "niri"),
        })
    return out


def cmd_list_wm(wm):
    if wm == "mango":
        if not os.path.exists(MANGO_BINDS):
            fail("no existe %s" % MANGO_BINDS)
        items = parse_mango()
        path = MANGO_BINDS
    elif wm == "niri":
        if not os.path.exists(NIRI_BINDS):
            fail("no existe %s" % NIRI_BINDS)
        items = parse_niri()
        path = NIRI_BINDS
    else:
        fail("wm desconocido: %s" % wm)
    print(json.dumps({"binds": items, "wm": wm, "file": path}, ensure_ascii=False))


def cmd_disable(bid):
    binds, lines = parse_file()
    st = load_state()
    b = next((x for x in binds if x["id"] == bid and x["enabled"]), None)
    if not b:
        fail("bind %s no encontrado o ya desactivado" % bid)
    if b["generated"]:
        fail("bind generado (workspaces en bucle) no se puede borrar individual")
    backup_once()
    lines = comment_range(lines, b["start"] - 1, b["end"] - 1, MARK_DISABLED, bid)
    write_lines(lines)
    if bid not in st["disabled"]:
        st["disabled"].append(bid)
    save_state(st)
    binds2, _ = parse_file()
    regenerate(binds2, st)
    print(json.dumps({"ok": True, "id": bid}))


def cmd_restore(bid):
    binds, lines = parse_file()
    st = load_state()
    with open(KEYBINDS_LUA, "r", encoding="utf-8") as f:
        lines = f.read().splitlines()
    lines, _ = uncomment_id(lines, bid)
    write_lines(lines)
    st["disabled"] = [d for d in st["disabled"] if d != bid]
    st["overrides"].pop(bid, None)
    save_state(st)
    binds2, _ = parse_file()
    regenerate(binds2, st)
    print(json.dumps({"ok": True, "id": bid}))


def cmd_override(bid, combo):
    combo = norm_combo(combo)
    if not valid_combo(combo):
        fail("combo invalido: %s" % combo)
    binds, _ = parse_file()
    st = load_state()
    b = next((x for x in binds if x["id"] == bid), None)
    if not b:
        fail("bind %s no encontrado" % bid)
    if b["generated"]:
        fail("bind generado no editable")
    conf = check_conflict(binds, st, combo, skip_id=bid)
    if conf:
        fail("combo en uso por %s" % conf)
    with open(KEYBINDS_LUA, "r", encoding="utf-8") as f:
        lines = f.read().splitlines()
    lines, _ = uncomment_id(lines, bid)
    binds2, _ = parse_file()
    b2 = next((x for x in binds2 if x["id"] == bid and x["enabled"]), None)
    if b2 is None:
        fail("bind %s no esta activo" % bid)
    backup_once()
    lines = comment_range(lines, b2["start"] - 1, b2["end"] - 1, MARK_OVERRIDE, bid)
    write_lines(lines)
    st["overrides"][bid] = {"combo": combo, "origCombo": b2["combo"]}
    if bid not in st["disabled"]:
        st["disabled"].append(bid)
    save_state(st)
    binds3, _ = parse_file()
    regenerate(binds3, st)
    print(json.dumps({"ok": True, "id": bid, "combo": combo}))


def cmd_add(combo, cmd, desc):
    combo = norm_combo(combo)
    if not valid_combo(combo):
        fail("combo invalido: %s" % combo)
    if not cmd.strip():
        fail("comando vacio")
    binds, _ = parse_file()
    st = load_state()
    conf = check_conflict(binds, st, combo)
    if conf:
        fail("combo en uso por %s" % conf)
    cid = custom_id(combo, cmd)
    if any(c["id"] == cid for c in st["customs"]):
        fail("ese bind ya existe")
    st["customs"].append({"id": cid, "combo": combo, "cmd": cmd.strip(), "desc": desc.strip()})
    save_state(st)
    regenerate(binds, st)
    print(json.dumps({"ok": True, "id": cid}))


def cmd_edit_custom(cid, combo, cmd, desc):
    binds, _ = parse_file()
    st = load_state()
    c = next((x for x in st["customs"] if x["id"] == cid), None)
    if not c:
        fail("custom %s no encontrado" % cid)
    if combo:
        combo = norm_combo(combo)
        if not valid_combo(combo):
            fail("combo invalido")
        conf = check_conflict(binds, st, combo, skip_id=cid)
        if conf:
            fail("combo en uso por %s" % conf)
        c["combo"] = combo
    if cmd:
        c["cmd"] = cmd.strip()
    if desc is not None:
        c["desc"] = desc.strip()
    save_state(st)
    regenerate(binds, st)
    print(json.dumps({"ok": True, "id": cid}))


def cmd_delete_custom(cid):
    binds, _ = parse_file()
    st = load_state()
    n = len(st["customs"])
    st["customs"] = [x for x in st["customs"] if x["id"] != cid]
    if len(st["customs"]) == n:
        fail("custom %s no encontrado" % cid)
    save_state(st)
    regenerate(binds, st)
    print(json.dumps({"ok": True, "id": cid}))


def main(argv):
    if len(argv) < 2:
        fail("uso: list [--wm hyprland|mango|niri]|disable|restore|override|add|edit-custom|delete-custom")
    cmd = argv[1]
    if cmd == "list":
        import argparse
        p = argparse.ArgumentParser()
        p.add_argument("--wm", default="hyprland")
        a = p.parse_args(argv[2:])
        if a.wm == "hyprland":
            cmd_list()
        else:
            cmd_list_wm(a.wm)
    elif cmd == "disable" and len(argv) == 3:
        cmd_disable(argv[2])
    elif cmd == "restore" and len(argv) == 3:
        cmd_restore(argv[2])
    elif cmd == "override" and len(argv) >= 3:
        import argparse
        p = argparse.ArgumentParser()
        p.add_argument("id")
        p.add_argument("--combo", required=True)
        a = p.parse_args(argv[2:])
        cmd_override(a.id, a.combo)
    elif cmd == "add":
        import argparse
        p = argparse.ArgumentParser()
        p.add_argument("--combo", required=True)
        p.add_argument("--cmd", required=True)
        p.add_argument("--desc", default="")
        a = p.parse_args(argv[2:])
        cmd_add(a.combo, a.cmd, a.desc)
    elif cmd == "edit-custom" and len(argv) >= 3:
        import argparse
        p = argparse.ArgumentParser()
        p.add_argument("id")
        p.add_argument("--combo", default=None)
        p.add_argument("--cmd", default=None)
        p.add_argument("--desc", default=None)
        a = p.parse_args(argv[2:])
        cmd_edit_custom(a.id, a.combo, a.cmd, a.desc)
    elif cmd == "delete-custom" and len(argv) == 3:
        cmd_delete_custom(argv[2])
    else:
        fail("comando o argumentos invalidos")


if __name__ == "__main__":
    main(sys.argv)
