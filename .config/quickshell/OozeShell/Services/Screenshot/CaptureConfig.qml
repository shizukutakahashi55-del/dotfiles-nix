// CaptureConfig — SCREENSHOT

pragma Singleton
import QtQuick
import Quickshell
import "../../Core"
import "../Lang"

QtObject {
  id: root

  readonly property var cfg: ConfigService.config.capture ?? ({})
  function opt(k, d) {
    const v = root.cfg[k]
    return v === undefined || v === null ? d : v
  }
  function set(k, v) {
    const c = Object.assign({}, root.cfg)
    c[k] = v
    ConfigService.set("capture", c)
  }

  readonly property string shotDir: root.opt("shotDir", "")
  readonly property string recDir: root.opt("recDir", "")
  readonly property string shotFormat: root.opt("shotFormat", "png")
  readonly property int shotQuality: root.opt("shotQuality", 90)
  readonly property string shotPattern: root.opt("shotPattern", "Screenshot_%Y-%m-%d_%H-%M-%S")
  readonly property bool shotCursor: root.opt("shotCursor", false)
  readonly property bool shotClipboard: root.opt("shotClipboard", false)
  readonly property string recPattern: root.opt("recPattern", "Recording_%Y-%m-%d_%H-%M-%S")
  readonly property string recFormat: root.opt("recFormat", "mp4")
  readonly property int recFps: root.opt("recFps", 30)
  readonly property string recQuality: root.opt("recQuality", "medium")
  readonly property string recAudio: root.opt("recAudio", "none")
  readonly property string recEncoder: root.opt("recEncoder", root.opt("recHw", false) ? "vaapi" : "cpu")
  readonly property int recDelay: root.opt("recDelay", 0)
  readonly property bool notify: root.opt("notify", true)

  readonly property string shotExt: root.shotFormat === "jpeg" ? "jpg" : "png"
  readonly property string recExt: root.recFormat
  readonly property string recCodec: root.recFormat === "webm" ? "vp8" : (root.recEncoder === "nvenc" ? "nvenc" : (root.recEncoder === "vaapi" ? "vaapi" : "x264"))
  readonly property int recCrf: {
    const q = root.recQuality
    if (root.recCodec === "vp8") return q === "low" ? 38 : (q === "high" ? 20 : (q === "ultra" ? 12 : 30))
    if (root.recCodec === "nvenc") return q === "low" ? 30 : (q === "high" ? 20 : (q === "ultra" ? 16 : 24))
    if (root.recCodec === "vaapi") return q === "low" ? 28 : (q === "high" ? 18 : (q === "ultra" ? 14 : 22))
    return q === "low" ? 28 : (q === "high" ? 17 : (q === "ultra" ? 12 : 21))
  }
  readonly property string recPreset: root.recQuality === "low" || root.recQuality === "medium" ? "veryfast" : "fast"

  readonly property string script:
    decodeURIComponent(Qt.resolvedUrl("../../Tools/ooze-capture.sh").toString().replace("file://", ""))

  function cmd(sub, env, args) {
    const out = ["env"]
    for (const k in env) out.push(k + "=" + env[k])
    return out.concat(["bash", root.script, sub], args ?? [])
  }

  function shotCommand(copyOnly, geo) {
    return root.cmd("shot", {
      CAP_GEO: geo ?? "",
      CAP_DIR: root.shotDir,
      CAP_PATTERN: root.shotPattern,
      CAP_FMT: root.shotFormat,
      CAP_EXT: root.shotExt,
      CAP_Q: String(root.shotQuality),
      CAP_CURSOR: root.shotCursor ? "1" : "0",
      CAP_CLIP: root.shotClipboard ? "1" : "0",
      CAP_COPY_ONLY: copyOnly ? "1" : "0",
      CAP_NOTIFY: root.notify ? "1" : "0",
      CAP_T_TITLE: Translations.t("scrTitle"),
      CAP_T_COPIED: Translations.t("scrCopied"),
      CAP_T_COPYFAIL: Translations.t("scrCopyFailed"),
      CAP_T_SAVEFAIL: Translations.t("scrSaveFailed"),
      CAP_T_MISSCOPY: Translations.t("scrMissingCopy"),
      CAP_T_MISSFULL: Translations.t("scrMissingFull")
    })
  }

  function openFolder(kind) {
    Quickshell.execDetached(root.cmd("open", {
      CAP_DIR: kind === "rec" ? root.recDir : root.shotDir
    }, [kind]))
  }
}
