import json
import os
import re
import sys
import tomllib

_BARE = re.compile(r"^[A-Za-z0-9_-]+$")
_ESC = {"\\": "\\\\", '"': '\\"', "\b": "\\b", "\t": "\\t", "\n": "\\n", "\f": "\\f", "\r": "\\r"}


def _clean(v):
    if v is None:
        return None
    if isinstance(v, dict):
        out = {}
        for k, x in v.items():
            c = _clean(x)
            if c is not None:
                out[str(k)] = c
        return out
    if isinstance(v, (list, tuple)):
        return [c for c in (_clean(x) for x in v) if c is not None]
    if isinstance(v, (str, bool, int, float)):
        return v
    return str(v)


def _quote(s):
    def sub(m):
        c = m.group(0)
        return _ESC.get(c) or "\\u%04x" % ord(c)

    return '"' + re.sub(r'[\\"\x00-\x1f\x7f]', sub, s) + '"'


def _key(k):
    return k if _BARE.match(k) else _quote(k)


def _number(v):
    if v != v:
        return "nan"
    if v == float("inf"):
        return "inf"
    if v == float("-inf"):
        return "-inf"
    return repr(v)


def _inline(v):
    if isinstance(v, str):
        return _quote(v)
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, int):
        return str(v)
    if isinstance(v, float):
        return _number(v)
    if isinstance(v, list):
        return "[" + ", ".join(_inline(x) for x in v) + "]"
    if not v:
        return "{}"
    return "{ " + ", ".join(_key(k) + " = " + _inline(x) for k, x in v.items()) + " }"


def _is_table_array(v):
    return isinstance(v, list) and len(v) > 0 and all(isinstance(x, dict) for x in v)


def _emit(obj, path, out):
    for k, v in obj.items():
        if not isinstance(v, dict) and not _is_table_array(v):
            out.append(_key(k) + " = " + _inline(v))
    for k, v in obj.items():
        p = path + [k]
        head = ".".join(_key(x) for x in p)
        if isinstance(v, dict):
            out.append("")
            out.append("[" + head + "]")
            _emit(v, p, out)
        elif _is_table_array(v):
            for el in v:
                out.append("")
                out.append("[[" + head + "]]")
                _emit(el, p, out)


def dumps(obj):
    c = _clean(obj)
    out = []
    _emit(c if isinstance(c, dict) else {}, [], out)
    return "\n".join(out).lstrip("\n") + "\n"


def loads(text):
    t = text.strip()
    if t == "":
        return {}
    if t.startswith("{"):
        return json.loads(t)
    return tomllib.loads(t)


def read(path, legacy=None):
    for p in (path, legacy):
        if not p:
            continue
        try:
            with open(p, "r", encoding="utf-8") as f:
                return loads(f.read())
        except FileNotFoundError:
            continue
    return None


def write(path, obj, legacy=None):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(dumps(obj))
    os.replace(tmp, path)
    if legacy and os.path.exists(legacy):
        os.replace(legacy, legacy + ".bak")


def _main(argv):
    if len(argv) >= 3 and argv[1] == "to-json":
        data = read(argv[2], argv[3] if len(argv) > 3 else None)
        if data is None:
            return 1
        sys.stdout.write(json.dumps(data, ensure_ascii=False, default=str))
        return 0
    if len(argv) >= 2 and argv[1] == "from-json":
        sys.stdout.write(dumps(json.loads(sys.stdin.read())))
        return 0
    return 2


if __name__ == "__main__":
    try:
        sys.exit(_main(sys.argv))
    except Exception as e:
        sys.stderr.write("ooze_toml: %s\n" % e)
        sys.exit(1)
