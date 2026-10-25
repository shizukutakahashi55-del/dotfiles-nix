.pragma library

const ESC = { "\\": "\\\\", "\"": "\\\"", "\b": "\\b", "\t": "\\t", "\n": "\\n", "\f": "\\f", "\r": "\\r" }
const BARE = /^[A-Za-z0-9_-]+$/

function isJson(text) {
  return String(text || "").trim().charAt(0) === "{"
}

function parseAny(text) {
  const t = String(text || "").trim()
  if (t === "") return {}
  return isJson(t) ? JSON.parse(t) : parse(t)
}

function parse(text) {
  const s = String(text).replace(/^\uFEFF/, "")
  const n = s.length
  const root = {}
  let cur = root
  let i = 0

  function fail(msg) {
    let line = 1
    for (let k = 0; k < i && k < n; k++) if (s.charCodeAt(k) === 10) line++
    throw new Error("toml línea " + line + ": " + msg)
  }

  function skipWs() {
    while (i < n && (s[i] === " " || s[i] === "\t")) i++
  }

  function skipComment() {
    if (s[i] === "#") while (i < n && s[i] !== "\n") i++
  }

  function skipAll() {
    while (i < n) {
      const c = s[i]
      if (c === " " || c === "\t" || c === "\n" || c === "\r") i++
      else if (c === "#") skipComment()
      else break
    }
  }

  function hex(len) {
    const h = s.substr(i, len)
    if (h.length !== len || !/^[0-9A-Fa-f]+$/.test(h)) fail("escape unicode inválido")
    i += len
    return String.fromCodePoint(parseInt(h, 16))
  }

  function escape(multi) {
    const c = s[i++]
    switch (c) {
      case "b": return "\b"
      case "t": return "\t"
      case "n": return "\n"
      case "f": return "\f"
      case "r": return "\r"
      case "e": return "\u001b"
      case "\"": return "\""
      case "\\": return "\\"
      case "x": return hex(2)
      case "u": return hex(4)
      case "U": return hex(8)
    }
    if (multi && (c === " " || c === "\t" || c === "\n" || c === "\r")) {
      i--
      let k = i
      while (k < n && (s[k] === " " || s[k] === "\t")) k++
      if (s[k] === "\r") k++
      if (s[k] !== "\n") fail("escape inválido")
      while (k < n && (s[k] === " " || s[k] === "\t" || s[k] === "\n" || s[k] === "\r")) k++
      i = k
      return ""
    }
    fail("escape inválido")
  }

  function basicString() {
    i++
    let out = ""
    while (true) {
      if (i >= n || s[i] === "\n") fail("cadena sin cerrar")
      const c = s[i++]
      if (c === "\"") return out
      out += c === "\\" ? escape(false) : c
    }
  }

  function literalString() {
    i++
    const end = s.indexOf("'", i)
    if (end < 0) fail("cadena sin cerrar")
    const out = s.slice(i, end)
    if (out.indexOf("\n") >= 0) fail("cadena sin cerrar")
    i = end + 1
    return out
  }

  function multiBasic() {
    i += 3
    if (s[i] === "\r" && s[i + 1] === "\n") i += 2
    else if (s[i] === "\n") i++
    let out = ""
    while (true) {
      if (i >= n) fail("cadena sin cerrar")
      if (s.startsWith("\"\"\"", i)) {
        let q = 0
        while (s[i + q] === "\"") q++
        out += "\"".repeat(Math.min(q - 3, 2))
        i += q
        return out
      }
      const c = s[i++]
      out += c === "\\" ? escape(true) : c
    }
  }

  function multiLiteral() {
    i += 3
    if (s[i] === "\r" && s[i + 1] === "\n") i += 2
    else if (s[i] === "\n") i++
    const end = s.indexOf("'''", i)
    if (end < 0) fail("cadena sin cerrar")
    let stop = end
    while (s[stop + 3] === "'") stop++
    const out = s.slice(i, stop)
    i = stop + 3
    return out
  }

  function keyPart() {
    const c = s[i]
    if (c === "\"") return basicString()
    if (c === "'") return literalString()
    const m = /^[A-Za-z0-9_-]+/.exec(s.slice(i, i + 256))
    if (!m) fail("clave inválida")
    i += m[0].length
    return m[0]
  }

  function keyPath() {
    const keys = []
    while (true) {
      skipWs()
      keys.push(keyPart())
      skipWs()
      if (s[i] === ".") i++
      else break
    }
    return keys
  }

  function step(obj, key) {
    let next = obj[key]
    if (next === undefined) {
      next = {}
      obj[key] = next
    }
    if (Array.isArray(next)) {
      if (next.length === 0 || typeof next[next.length - 1] !== "object") fail("clave redefinida: " + key)
      next = next[next.length - 1]
    }
    if (next === null || typeof next !== "object") fail("clave redefinida: " + key)
    return next
  }

  function descend(base, keys) {
    let obj = base
    for (let k = 0; k < keys.length; k++) obj = step(obj, keys[k])
    return obj
  }

  function assign(base, keys, value) {
    const parent = descend(base, keys.slice(0, -1))
    parent[keys[keys.length - 1]] = value
  }

  function array() {
    i++
    const out = []
    while (true) {
      skipAll()
      if (s[i] === "]") { i++; return out }
      out.push(value())
      skipAll()
      if (s[i] === ",") { i++; continue }
      if (s[i] === "]") { i++; return out }
      fail("se esperaba ',' o ']'")
    }
  }

  function inlineTable() {
    i++
    const out = {}
    skipAll()
    if (s[i] === "}") { i++; return out }
    while (true) {
      skipAll()
      const keys = keyPath()
      skipWs()
      if (s[i] !== "=") fail("se esperaba '='")
      i++
      skipWs()
      assign(out, keys, value())
      skipAll()
      if (s[i] === ",") { i++; continue }
      if (s[i] === "}") { i++; return out }
      fail("se esperaba ',' o '}'")
    }
  }

  function scalar() {
    const m = /^[^\s,\]}#]+/.exec(s.slice(i, i + 128))
    if (!m) fail("valor inválido")
    let tok = m[0]
    if (/^\d{4}-\d{2}-\d{2}$/.test(tok) && s[i + tok.length] === " " && /\d/.test(s[i + tok.length + 1] || "")) {
      const t = /^[^\s,\]}#]+/.exec(s.slice(i + tok.length + 1, i + tok.length + 40))
      if (t) tok += " " + t[0]
    }
    i += tok.length
    if (tok === "true") return true
    if (tok === "false") return false
    if (/^[+-]?inf$/.test(tok)) return tok[0] === "-" ? -Infinity : Infinity
    if (/^[+-]?nan$/.test(tok)) return NaN
    if (/^\d{4}-\d{2}-\d{2}/.test(tok) || /^\d{2}:\d{2}:\d{2}/.test(tok)) return tok
    const clean = tok.replace(/_/g, "")
    if (/^0x[0-9A-Fa-f]+$/.test(clean)) return parseInt(clean.slice(2), 16)
    if (/^0o[0-7]+$/.test(clean)) return parseInt(clean.slice(2), 8)
    if (/^0b[01]+$/.test(clean)) return parseInt(clean.slice(2), 2)
    if (/^[+-]?(\d+)(\.\d+)?([eE][+-]?\d+)?$/.test(clean)) return Number(clean)
    fail("valor inválido: " + tok)
  }

  function value() {
    skipWs()
    const c = s[i]
    if (c === "\"") return s.startsWith("\"\"\"", i) ? multiBasic() : basicString()
    if (c === "'") return s.startsWith("'''", i) ? multiLiteral() : literalString()
    if (c === "[") return array()
    if (c === "{") return inlineTable()
    return scalar()
  }

  function endOfLine() {
    skipWs()
    skipComment()
    if (i < n && s[i] !== "\n" && s[i] !== "\r") fail("texto inesperado")
  }

  while (true) {
    skipAll()
    if (i >= n) break
    if (s[i] === "[") {
      const isArr = s[i + 1] === "["
      i += isArr ? 2 : 1
      const keys = keyPath()
      skipWs()
      if (isArr) {
        if (s[i] !== "]" || s[i + 1] !== "]") fail("se esperaba ']]'")
        i += 2
        const parent = descend(root, keys.slice(0, -1))
        const last = keys[keys.length - 1]
        if (parent[last] === undefined) parent[last] = []
        if (!Array.isArray(parent[last])) fail("clave redefinida: " + last)
        const item = {}
        parent[last].push(item)
        cur = item
      } else {
        if (s[i] !== "]") fail("se esperaba ']'")
        i++
        cur = descend(root, keys)
      }
      endOfLine()
    } else {
      const keys = keyPath()
      skipWs()
      if (s[i] !== "=") fail("se esperaba '='")
      i++
      assign(cur, keys, value())
      endOfLine()
    }
  }
  return root
}

function clean(v) {
  if (v === undefined || v === null || typeof v === "function") return undefined
  if (v instanceof Date) return isNaN(v.getTime()) ? undefined : v.toISOString()
  if (Array.isArray(v)) {
    const out = []
    for (let k = 0; k < v.length; k++) {
      const c = clean(v[k])
      if (c !== undefined) out.push(c)
    }
    return out
  }
  if (typeof v === "object") {
    if (typeof v.toJSON === "function") return clean(v.toJSON())
    const out = {}
    for (const k of Object.keys(v)) {
      const c = clean(v[k])
      if (c !== undefined) out[k] = c
    }
    return out
  }
  return v
}

function isTable(v) {
  return v !== null && typeof v === "object" && !Array.isArray(v)
}

function isTableArray(v) {
  return Array.isArray(v) && v.length > 0 && v.every(isTable)
}

function quote(str) {
  return "\"" + String(str).replace(/[\\"\u0000-\u001f\u007f]/g, c =>
    ESC[c] || "\\u" + ("0000" + c.charCodeAt(0).toString(16)).slice(-4)) + "\""
}

function keyText(k) {
  return BARE.test(k) ? k : quote(k)
}

function number(v) {
  if (isNaN(v)) return "nan"
  if (v === Infinity) return "inf"
  if (v === -Infinity) return "-inf"
  return String(v)
}

function inline(v) {
  if (typeof v === "string") return quote(v)
  if (typeof v === "boolean") return v ? "true" : "false"
  if (typeof v === "number") return number(v)
  if (Array.isArray(v)) return "[" + v.map(inline).join(", ") + "]"
  const keys = Object.keys(v)
  if (keys.length === 0) return "{}"
  return "{ " + keys.map(k => keyText(k) + " = " + inline(v[k])).join(", ") + " }"
}

function emit(obj, path, out) {
  const keys = Object.keys(obj)
  for (const k of keys) {
    const v = obj[k]
    if (!isTable(v) && !isTableArray(v)) out.push(keyText(k) + " = " + inline(v))
  }
  for (const k of keys) {
    const v = obj[k]
    const p = path.concat(k)
    const head = p.map(keyText).join(".")
    if (isTable(v)) {
      out.push("")
      out.push("[" + head + "]")
      emit(v, p, out)
    } else if (isTableArray(v)) {
      for (const el of v) {
        out.push("")
        out.push("[[" + head + "]]")
        emit(el, p, out)
      }
    }
  }
}

function stringify(obj) {
  const c = clean(obj)
  const out = []
  emit(isTable(c) ? c : {}, [], out)
  return out.join("\n").replace(/^\n+/, "") + "\n"
}
