// LockLayouts

pragma Singleton
import QtQuick

QtObject {
  id: root

  // ── Distribuciones ──
  readonly property var ids: ["center", "stack-left", "stack-right", "split-center", "split-right", "split-left"]

  readonly property var table: ({
    "center": {
      joined: true,
      clock:   { h: "center", v: "middle" },
      auth:    { h: "center", v: "middle" },
      status:  { h: "center" },
      power:   { h: "right",  v: "bottom" },
      widgets: "bottom"
    },
    "stack-left": {
      joined: false,
      clock:   { h: "left",   v: "top" },
      auth:    { h: "left",   v: "middle" },
      status:  { h: "left" },
      power:   { h: "right",  v: "bottom" },
      widgets: "right"
    },
    "stack-right": {
      joined: false,
      clock:   { h: "right",  v: "top" },
      auth:    { h: "right",  v: "middle" },
      status:  { h: "right" },
      power:   { h: "left",   v: "bottom" },
      widgets: "left"
    },
    "split-center": {
      joined: false,
      clock:   { h: "left",   v: "top" },
      auth:    { h: "center", v: "bottom" },
      status:  { h: "left" },
      power:   { h: "right",  v: "bottom" },
      widgets: "right"
    },
    "split-right": {
      joined: false,
      clock:   { h: "left",   v: "top" },
      auth:    { h: "right",  v: "bottom" },
      status:  { h: "left" },
      power:   { h: "right",  v: "bottom" },
      widgets: "left"
    },
    "split-left": {
      joined: false,
      clock:   { h: "right",  v: "top" },
      auth:    { h: "left",   v: "bottom" },
      status:  { h: "right" },
      power:   { h: "left",   v: "top" },
      widgets: "right"
    }
  })

  // ── Consulta ──
  function spec(id) { return root.table[id] ?? root.table["center"] }
  function align(h) { return h === "left" ? Qt.AlignLeft : h === "right" ? Qt.AlignRight : Qt.AlignHCenter }
}
