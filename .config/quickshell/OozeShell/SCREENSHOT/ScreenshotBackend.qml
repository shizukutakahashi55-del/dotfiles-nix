// ScreenshotBackend.qml — SCREENSHOT
// quickshell ipc -p .../shell.qml call -- screenshot areaCopy

pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../COMMON"
import "../LANG"

QtObject {
  id: root


  property int borderWidth: 2

  property real backgroundOpacity: 0.1

  property real settleDelay: 0.3

  // ─── Color del tema → hex RRGGBBAA ──
  function toHex8(c, alpha) {
    const h = v => Math.round(Math.max(0, Math.min(1, v)) * 255).toString(16).padStart(2, "0")
    return h(c.r) + h(c.g) + h(c.b) + h(alpha === undefined ? c.a : alpha)
  }


  readonly property string dirExpr:
    'd="$(xdg-user-dir PICTURES 2>/dev/null)"; [ -z "$d" ] && d="$HOME/Pictures"; ' +
    'd="$d/Screenshots"; mkdir -p "$d" 2>/dev/null; printf %s "$d"'

  function run(script, args) {
    Quickshell.execDetached(["sh", "-c", script, "sh"].concat(args ?? []))
  }

  // ─── Selección de área (con la pantalla congelada) ───────────────


  property bool pickerOpen: false

  property string pickerMode: "copy"


  property bool capturing: false


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
