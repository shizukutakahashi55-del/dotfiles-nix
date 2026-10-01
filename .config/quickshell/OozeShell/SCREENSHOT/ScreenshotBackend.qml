//
//   quickshell ipc -p .../shell.qml call -- screenshot areaCopy
//   quickshell ipc -p .../shell.qml call -- screenshot fullSave
//   quickshell ipc -p .../shell.qml call -- screenshot areaSave
//
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../COMMON"
import "../LANG"

QtObject {
  id: root

  // Grosor del marco de selección, en píxeles lógicos.
  property int borderWidth: 2

  property real backgroundOpacity: 0.1

  property real settleDelay: 0.3   // (sin uso desde el selector congelado; ver freezeSettleMs)

  // ─── Color del tema → hex RRGGBBAA ──
  function toHex8(c, alpha) {
    const h = v => Math.round(Math.max(0, Math.min(1, v)) * 255).toString(16).padStart(2, "0")
    return h(c.r) + h(c.g) + h(c.b) + h(alpha === undefined ? c.a : alpha)
  }

  // Carpeta de destino de las capturas guardadas: $XDG_PICTURES_DIR/Screenshots
  // si `xdg-user-dir` está disponible, si no $HOME/Pictures/Screenshots. Se
  // crea sola si todavía no existe.
  readonly property string dirExpr:
    'd="$(xdg-user-dir PICTURES 2>/dev/null)"; [ -z "$d" ] && d="$HOME/Pictures"; ' +
    'd="$d/Screenshots"; mkdir -p "$d" 2>/dev/null; printf %s "$d"'

  function run(script, args) {
    Quickshell.execDetached(["sh", "-c", script, "sh"].concat(args ?? []))
  }

  // ─── Selección de área (con la pantalla congelada) ───────────────
  // areaCopy/areaSave ya no lanzan slurp: abren el selector de
  // SCREENSHOT/ScreenshotFreeze.qml, que congela cada monitor (un cuadro
  // fijo vía ScreencopyView) y deja elegir el área encima. Al soltar el
  // mouse, ScreenshotFreeze llama a captureArea(geo) con el rectángulo en
  // coordenadas globales (formato de grim: "x,y wxh").
  property bool pickerOpen: false
  // "copy" → portapapeles · "save" → carpeta de capturas
  property string pickerMode: "copy"
  // true entre soltar el mouse y terminar grim: el selector esconde su
  // marco/oscurecido (para que no salgan en la captura) pero deja el cuadro
  // congelado a la vista, que es lo que grim termina copiando.
  property bool capturing: false
  // Espera (ms) desde que se esconde el marco hasta correr grim: unos
  // frames para que el compositor ya no dibuje el marco.
  property int freezeSettleMs: 90

  function openPicker(mode) {
    if (root.pickerOpen) return
    root.pickerMode = mode
    root.capturing = false
    root.pickerOpen = true
  }
  function closePicker() {
    root.pickerOpen = false
    root.capturing = false
  }

  function areaCopy() { root.openPicker("copy") }
  function areaSave() { root.openPicker("save") }

  // Comando (para Process) que recorta `geo` del cuadro congelado.
  function captureCommand(geo) {
    const copy = root.pickerMode === "copy"
    const script = copy
      ? 'command -v grim >/dev/null 2>&1 && command -v wl-copy >/dev/null 2>&1 || ' +
        '{ notify-send -u critical -a OozeShell "$1" "$4"; exit 127; }; ' +
        'grim -g "$5" - | wl-copy; s=$?; ' +
        'if [ "$s" -eq 0 ]; then notify-send -a OozeShell "$1" "$2"; ' +
        'else notify-send -u critical -a OozeShell "$1" "$3"; fi'
      : 'command -v grim >/dev/null 2>&1 || ' +
        '{ notify-send -u critical -a OozeShell "$1" "$4"; exit 127; }; ' +
        'd="$(' + root.dirExpr + ')"; ' +
        'f="$d/Screenshot_$(date +%Y-%m-%d_%H-%M-%S).png"; ' +
        'grim -g "$5" "$f"; s=$?; ' +
        'if [ "$s" -eq 0 ]; then notify-send -a OozeShell "$1" "$f"; ' +
        'else notify-send -u critical -a OozeShell "$1" "$2"; fi'
    return ["sh", "-c", script, "sh",
      Translations.t("scrTitle"),
      copy ? Translations.t("scrCopied") : Translations.t("scrSaveFailed"),
      Translations.t("scrCopyFailed"),
      copy ? Translations.t("scrMissingCopy") : Translations.t("scrMissingFull"),
      geo]
  }

  // ─── Pantalla completa → directorio ──────────────────────────────
  function fullSave() {
    root.run(
      'command -v grim >/dev/null 2>&1 || { notify-send -u critical -a OozeShell "$1" "$3"; exit 127; }; ' +
      'd="$(' + root.dirExpr + ')"; ' +
      'f="$d/Screenshot_$(date +%Y-%m-%d_%H-%M-%S).png"; ' +
      'grim "$f"; s=$?; ' +
      'if [ "$s" -eq 0 ]; then notify-send -a OozeShell "$1" "$f"; ' +
      'else notify-send -u critical -a OozeShell "$1" "$2"; fi',
      [Translations.t("scrTitle"), Translations.t("scrSaveFailed"), Translations.t("scrMissingFull")]
    )
  }
}
