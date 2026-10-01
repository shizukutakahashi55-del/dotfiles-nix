// Fuzzy — coincidencia difusa para los buscadores (Launcher, NixSearch).
//
// Un término coincide si aparece como subcadena o, si no, como
// SUBSECUENCIA de letras en orden ("ffx" → "firefox"). Las subcadenas
// puntúan más que las subsecuencias, y dentro de cada grupo pesa que
// empiece al principio del texto o de una palabra, y que sea corta.
//
// Uso (los textos ya deben venir en minúsculas: se preparan UNA vez al
// armar la lista, no en cada tecla):
//
//   const terms = Fuzzy.terms("fire fox")            // ["fire", "fox"]
//   const s = Fuzzy.match(terms, [
//     { text: "firefox web browser", w: 1.0 },       // w = peso del campo
//     { text: "navegador",           w: 0.6 } ])
//   // s < 0 → no coincide; si no, mayor = mejor
//
// Todos los términos tienen que coincidir (AND); el puntaje de cada uno es
// el del campo donde mejor le va, por el peso de ese campo.
pragma Singleton
import QtQml

QtObject {
  id: root

  // "  fire   Fox " → ["fire", "fox"]
  function terms(query) {
    return String(query || "").toLowerCase().split(/\s+/).filter(t => t !== "")
  }

  // ¿La posición i empieza una palabra? (después de espacio, - _ . /)
  function boundary(t, i) {
    if (i <= 0) return true
    const p = t.charAt(i - 1)
    return p === " " || p === "-" || p === "_" || p === "." || p === "/"
  }

  // Puntaje de UN término en UN texto (ambos en minúsculas). -1 = no coincide.
  //   subcadena      → 600 … 1900
  //   subsecuencia   → 1 … 500
  function scoreTerm(q, t) {
    if (q === "" || t === "") return -1

    const i = t.indexOf(q)
    if (i >= 0) {
      let s = 1000 - i * 4 - (t.length - q.length)
      if (i === 0) s += 400
      else if (root.boundary(t, i)) s += 250
      if (t.length === q.length) s += 300          // coincidencia exacta
      return Math.max(600, s)
    }

    // Subsecuencia: cada letra del término, en orden, en algún lugar del texto
    let from = 0, prev = -2, s = 0
    for (let k = 0; k < q.length; k++) {
      const j = t.indexOf(q.charAt(k), from)
      if (j < 0) return -1
      if (j === prev + 1) s += 15                   // letras seguidas
      else s -= Math.min(8, j - from)               // cuánto se saltó
      if (root.boundary(t, j)) s += 25             // empieza una palabra
      prev = j
      from = j + 1
    }
    return Math.max(1, Math.min(500, 200 + s))
  }

  // Puntaje de varios términos contra varios campos { text, w }. -1 = no coincide.
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
