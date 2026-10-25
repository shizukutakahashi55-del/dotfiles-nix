# palette-apply.py — tools

"""Tools/palette-apply.py — aplica una paleta FIJA de OozeShell a todo lo que
pasa por matugen (terminales, hyprland, qt6ct, kde, vesktop, yazi, btop...).

En modo "Paletas" matugen queda apagado, así que sus plantillas no se
regeneraban. Este script hace ese trabajo sin matugen: toma los colores de la
paleta, completa los roles Material 3 que faltan, y rellena EXACTAMENTE las
mismas plantillas de ~/.config/matugen/config.toml (mismas rutas de salida y
mismos post_hook). Si agregás una plantilla nueva al config.toml, entra sola.

Uso:
  palette-apply.py '<json de la paleta>'            # lo llama OozeShell
  palette-apply.py paleta.json --dry-run /tmp/out   # solo escribe a /tmp/out
  palette-apply.py paleta.json --force              # corre hooks aunque no cambie

Solo usa la librería estándar (Python >= 3.11, por tomllib).
"""
import argparse
import colorsys
import json
import os
import re
import subprocess
import sys

try:
    import tomllib
except ImportError:
    tomllib = None

REQUIRED = [
    "bg", "surface", "surfaceHigh", "primary", "textOnPrimary", "text",
    "subtext", "error", "textOnError", "primaryContainer",
    "textOnPrimaryContainer", "outline",
]


# ─── color ─────────────────────────────────────────────────────────────────
def parse_hex(s):
    s = str(s).strip().lstrip("#")
    if len(s) == 3:
        s = "".join(c * 2 for c in s)
    if len(s) == 8:
        s = s[:6]
    if not re.fullmatch(r"[0-9a-fA-F]{6}", s):
        raise ValueError(f"color inválido: {s!r}")
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4))


def to_hex(rgb):
    return "#%02x%02x%02x" % tuple(max(0, min(255, int(round(c)))) for c in rgb)


def mix(a, b, t):
    a, b = parse_hex(a), parse_hex(b)
    return to_hex(tuple(x * (1 - t) + y * t for x, y in zip(a, b)))


def luminance(c):
    def lin(v):
        v /= 255
        return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
    r, g, b = (lin(v) for v in parse_hex(c))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a, b):
    la, lb = luminance(a), luminance(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


def to_hsl(c):
    r, g, b = (v / 255 for v in parse_hex(c))
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    return h * 360, s * 100, l * 100


def from_hsl(h, s, l):
    r, g, b = colorsys.hls_to_rgb((h % 360) / 360, max(0, min(100, l)) / 100,
                                  max(0, min(100, s)) / 100)
    return to_hex((r * 255, g * 255, b * 255))


# ─── roles Material 3 ──────────────────────────────────────────────────────
def derive_roles(p):
    """Paleta de OozeShell (12 campos) → roles M3 de matugen.

    Los 12 campos se mapean igual que Theme.applyPalette() los lee de matugen
    (bg=surface, surface=surface_container, surfaceHigh=surface_container_high,
    subtext=secondary...). Lo que la paleta no trae se deriva mezclando.
    Se puede afinar por paleta con el campo opcional "m3": {"rol": "#hex"}.
    """
    B, S, H = p["bg"], p["surface"], p["surfaceHigh"]
    P, onP = p["primary"], p["textOnPrimary"]
    T, SUB = p["text"], p["subtext"]
    E, onE = p["error"], p["textOnError"]
    PC, onPC = p["primaryContainer"], p["textOnPrimaryContainer"]
    O = p["outline"]
    light = luminance(B) > 0.5
    deep = "#ffffff" if light else "#000000"

    def on(c):
        return B if contrast(c, B) >= contrast(c, T) else T

    TER = p.get("tertiary")
    if not TER:
        h, s, l = to_hsl(P)
        TER = from_hsl(h + 50, s if s < 10 else max(s, 40), l)
    SEC = SUB

    r = {
        "background": B, "on_background": T,
        "surface": B, "surface_dim": B, "surface_bright": H,
        "surface_container_lowest": mix(B, deep, 0.35),
        "surface_container_low": mix(B, S, 0.5),
        "surface_container": S,
        "surface_container_high": H,
        "surface_container_highest": mix(H, T, 0.10),
        "surface_variant": H,
        "on_surface": T,
        "on_surface_variant": mix(T, SUB, 0.5),
        "outline": O, "outline_variant": mix(O, B, 0.55),
        "shadow": "#000000", "scrim": "#000000",
        "inverse_surface": T, "inverse_on_surface": B,
        "inverse_primary": mix(P, B, 0.45),
        "surface_tint": P,
        "primary": P, "on_primary": onP,
        "primary_container": PC, "on_primary_container": onPC,
        "secondary": SEC, "on_secondary": on(SEC),
        "secondary_container": mix(H, SEC, 0.30), "on_secondary_container": T,
        "tertiary": TER, "on_tertiary": on(TER),
        "tertiary_container": mix(H, TER, 0.30), "on_tertiary_container": T,
        "error": E, "on_error": onE,
        "error_container": mix(B, E, 0.35),
        "on_error_container": mix(E, "#ffffff" if not light else "#000000", 0.6),
        "source_color": P,
    }
    for name, c in (("primary", P), ("secondary", SEC), ("tertiary", TER)):
        r[f"{name}_fixed"] = mix(c, "#ffffff", 0.30)
        r[f"{name}_fixed_dim"] = c
        r[f"on_{name}_fixed"] = B
        r[f"on_{name}_fixed_variant"] = PC
    for k, v in (p.get("m3") or {}).items():
        r[k] = to_hex(parse_hex(v))
    return r, light


# ─── plantillas (subconjunto de matugen que usan las de OozeShell) ──────────
TAG = re.compile(r"\{\{\s*(.*?)\s*\}\}")


def fmt_color(hexv, fmt):
    r, g, b = parse_hex(hexv)
    h, s, l = to_hsl(hexv)
    return {
        "hex": to_hex((r, g, b)),
        "hex_stripped": to_hex((r, g, b))[1:],
        "red": str(r), "green": str(g), "blue": str(b),
        "rgb": f"rgb({r}, {g}, {b})",
        "rgba": f"rgba({r}, {g}, {b}, 1.0)",
        "hue": str(int(round(h))),
        "saturation": str(int(round(s))),
        "lightness": str(int(round(l))),
        "hsl": f"hsl({int(round(h))}, {int(round(s))}%, {int(round(l))}%)",
    }.get(fmt)


def apply_filter(value, name, args, light):
    """Aproximación de los filtros de matugen (en HSL, puntos porcentuales)."""
    try:
        parse_hex(value)
    except ValueError:
        return value
    amount = float(args[0]) if args else 0.0
    h, s, l = to_hsl(value)
    if name == "lighten":
        return from_hsl(h, s, l + amount)
    if name == "darken":
        return from_hsl(h, s, l - amount)
    if name == "saturate":
        return from_hsl(h, s + amount, l)
    if name == "desaturate":
        return from_hsl(h, s - amount, l)
    if name == "auto_lightness":
        return from_hsl(h, s, l - amount if light else l + amount)
    return value


def render(text, roles, light, image, warn):
    def sub(m):
        parts = [x.strip() for x in m.group(1).split("|")]
        head = parts[0]
        if head == "image":
            return image
        mm = re.fullmatch(r"colors\.([a-z_0-9]+)\.(dark|light|default)\.([a-z_]+)", head)
        if not mm or mm.group(1) not in roles:
            warn(f"etiqueta sin resolver: {m.group(0)}")
            return m.group(0)
        out = fmt_color(roles[mm.group(1)], mm.group(3))
        if out is None:
            warn(f"formato desconocido: {m.group(0)}")
            return m.group(0)
        for f in parts[1:]:
            name, _, rest = f.partition(":")
            args = [a.strip() for a in rest.split(",") if a.strip()]
            out = apply_filter(out, name.strip(), args, light)
        return out
    return TAG.sub(sub, text)


# ─── main ──────────────────────────────────────────────────────────────────
def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("palette", help="JSON de la paleta (texto o ruta a un archivo)")
    ap.add_argument("--config", default=os.environ.get(
        "OOZE_MATUGEN_CONFIG", "~/.config/matugen/config.toml"))
    ap.add_argument("--dry-run", metavar="DIR",
                    help="escribe las salidas en DIR y no corre hooks")
    ap.add_argument("--force", action="store_true",
                    help="corre los post_hook aunque el archivo no haya cambiado")
    a = ap.parse_args()

    if tomllib is None:
        print("[palette] hace falta Python >= 3.11 (tomllib)", file=sys.stderr)
        return 3

    raw = a.palette
    if not raw.lstrip().startswith("{"):
        with open(os.path.expanduser(raw), encoding="utf-8") as fh:
            raw = fh.read()
    p = json.loads(raw)
    missing = [k for k in REQUIRED if k not in p]
    if missing:
        print(f"[palette] faltan campos: {', '.join(missing)}", file=sys.stderr)
        return 2

    roles, light = derive_roles(p)

    cfg_path = os.path.expanduser(a.config)
    if not os.path.isfile(cfg_path):
        print(f"[palette] no existe {cfg_path}: nada que aplicar", file=sys.stderr)
        return 0
    cfg_dir = os.path.dirname(cfg_path)
    with open(cfg_path, "rb") as fh:
        cfg = tomllib.load(fh)

    image = ""
    try:
        with open(os.path.expanduser("~/.cache/awww/last"), encoding="utf-8") as fh:
            image = fh.read().strip()
    except OSError:
        pass

    def path_of(s):
        s = os.path.expanduser(s)
        return s if os.path.isabs(s) else os.path.normpath(os.path.join(cfg_dir, s))

    changed_n = skipped_n = 0
    for name, t in (cfg.get("templates") or {}).items():
        src, dst = t.get("input_path"), t.get("output_path")
        if not src or not dst:
            continue
        src, dst = path_of(src), path_of(dst)
        if not os.path.isfile(src):
            print(f"[palette] {name}: plantilla no encontrada ({src}), se omite",
                  file=sys.stderr)
            skipped_n += 1
            continue
        with open(src, encoding="utf-8") as fh:
            body = render(fh.read(), roles, light, image,
                          lambda msg, n=name: print(f"[palette] {n}: {msg}", file=sys.stderr))
        if a.dry_run:
            dst = os.path.join(os.path.expanduser(a.dry_run),
                               f"{name}__{os.path.basename(dst)}")
        old = None
        try:
            with open(dst, encoding="utf-8") as fh:
                old = fh.read()
        except OSError:
            pass
        changed = old != body
        if changed:
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            with open(dst, "w", encoding="utf-8") as fh:
                fh.write(body)
            changed_n += 1
        hook = t.get("post_hook")
        if hook and not a.dry_run and (changed or a.force):
            try:
                subprocess.run(["sh", "-c", hook], timeout=20, check=False,
                               stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                               stderr=subprocess.DEVNULL)
            except subprocess.TimeoutExpired:
                print(f"[palette] {name}: el post_hook tardó demasiado", file=sys.stderr)

    print(f"[palette] {'claro' if light else 'oscuro'} · {changed_n} archivo(s) "
          f"actualizado(s)" + (f" · {skipped_n} omitida(s)" if skipped_n else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
