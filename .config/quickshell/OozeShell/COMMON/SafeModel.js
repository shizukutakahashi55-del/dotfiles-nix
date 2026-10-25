.pragma library

// ScriptModel (Quickshell 0.3.0) emite rowsMoved cuando cambia el orden relativo
// de los elementos que se mantienen. Con Qt 6.11.2 eso puede provocar un segfault en
// QQmlDelegateModelPrivate::itemsInserted. Esta funcion detecta ese caso para que
// quien llama reinicie el modelo (vaciar y rellenar) en vez de dejar que se mueva.
//
// Inserciones y borrados puros NO generan moves, asi que devuelve false para ellos.
// Si hay claves duplicadas tampoco es seguro, asi que devuelve true.
function wouldMove(prev, next, keyOf) {
  if (!prev || !next || prev.length === 0 || next.length === 0) return false
  const pos = new Map()
  for (let i = 0; i < prev.length; i++) {
    const k = String(keyOf(prev[i]))
    if (pos.has(k)) return true
    pos.set(k, i)
  }
  const seen = new Set()
  let last = -1
  for (let i = 0; i < next.length; i++) {
    const k = String(keyOf(next[i]))
    if (seen.has(k)) return true
    seen.add(k)
    if (!pos.has(k)) continue
    const p = pos.get(k)
    if (p < last) return true
    last = p
  }
  return false
}
