// Fuzzy — coincidencia difusa para los buscadores (Launcher, NixSearch).
// Un término coincide si aparece como subcadena o, si no, como SUBSECUENCIA de letras en orden ("ffx" → "firefox"). Las subcadenas puntúan más que las subsecuencias, y dentro de cada grupo pesa que

pragma Singleton
import QtQml

QtObject {
  id: root


  function terms(query) {
    return String(query || "").toLowerCase().split(/\s+/).filter(t => t !== "")
  }


  function boundary(t, i) {
    if (i <= 0) return true
    const p = t.charAt(i - 1)
    return p === " " || p === "-" || p === "_" || p === "." || p === "/"
  }


  function scoreTerm(q, t) {
    if (q === "" || t === "") return -1

    const i = t.indexOf(q)
    if (i >= 0) {
      let s = 1000 - i * 4 - (t.length - q.length)
      if (i === 0) s += 400
      else if (root.boundary(t, i)) s += 250
      if (t.length === q.length) s += 300
      return Math.max(600, s)
    }


    let from = 0, prev = -2, s = 0
    for (let k = 0; k < q.length; k++) {
      const j = t.indexOf(q.charAt(k), from)
      if (j < 0) return -1
      if (j === prev + 1) s += 15
      else s -= Math.min(8, j - from)
      if (root.boundary(t, j)) s += 25
      prev = j
      from = j + 1
    }
    return Math.max(1, Math.min(500, 200 + s))
  }


  function match(terms, fields) {
    let total = 0
    for (let a = 0; a < terms.length; a++) {
      let best = -1
      for (let b = 0; b < fields.length; b++) {
        const f = fields[b]
        const s = root.scoreTerm(terms[a], f.text)
        if (s >= 0 && s * f.w > best) best = s * f.w
      }
      if (best < 0) return -1
      total += best
    }
    return total
  }
}
