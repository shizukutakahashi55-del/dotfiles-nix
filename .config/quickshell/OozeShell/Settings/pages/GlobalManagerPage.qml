// GlobalManagerPage — categoría "Global-Manager": qué window manager y qué distro usa la shell. De esto dependen el buscador de paquetes y lo que se muestra según las capacidades del WM.

import QtQuick
import QtQuick.Layouts
import ".."
import "../../COMMON"
import "../../Services/Lang"

SettingsPage {
  id: page
  catId: "globalmanager"

  function wmName(id) {
    const w = WM.wmList.find(x => x.id === id)
    return w ? w.name : Translations.t("gmNone")
  }
  function distroName(id) {
    const d = WM.distroList.find(x => x.id === id)
    return d ? d.name : Translations.t("gmNone")
  }

  readonly property var wmChoices: [{ value: "auto", label: Translations.t("gmAuto") }]
    .concat(WM.wmList.map(w => ({ value: w.id, label: w.name })))
  readonly property var distroChoices: [{ value: "auto", label: Translations.t("gmAuto") }]
    .concat(WM.distroList.map(d => ({ value: d.id, label: d.name })))
  readonly property var helperChoices: [{ value: "auto", label: Translations.t("gmAuto") }]
    .concat(WM.pkgHelperList.map(h => ({
      value: h,
      label: h + (WM.isInstalled(h) ? "" : "  ·  " + Translations.t("gmMissing"))
    })))

  SettingsSection {
    titleKey: "gmWmTitle"
    hintKey: "gmWmHint"

    SettingsRow {
      stacked: true
      SettingsChips {
        model: page.wmChoices
        current: WM.wmPref
        onPicked: v => WM.setWm(v)
      }
    }

    SettingsRow {
      titleKey: "gmDetected"
      SettingsValue { text: page.wmName(WM.detectedWm) }
    }
    SettingsRow {
      titleKey: "gmActive"
      SettingsValue { text: page.wmName(WM.wm) }
    }

    SettingsNote {
      visible: WM.wmMismatch
      kind: "error"
      text: Translations.t("gmMismatch")
    }
  }

  SettingsSection {
    titleKey: "gmDistroTitle"
    hintKey: "gmDistroHint"

    SettingsRow {
      stacked: true
      SettingsChips {
        model: page.distroChoices
        current: WM.distroPref
        onPicked: v => WM.setDistro(v)
      }
    }

    SettingsRow {
      visible: WM.distro === "arch"
      titleKey: "gmPkgHelperTitle"
      stacked: true
      SettingsChips {
        model: page.helperChoices
        current: WM.pkgHelperPref
        onPicked: v => WM.setPkgHelper(v)
      }
    }

    SettingsRow {
      titleKey: "gmDetected"
      SettingsValue { text: page.distroName(WM.detectedDistro) }
    }
    SettingsRow {
      titleKey: "gmPkgBackend"
      SettingsValue { text: WM.packageBackend }
    }
  }

  SettingsSection {
    titleKey: "gmCapsTitle"
    hintKey: "gmCapsHint"

    Repeater {
      model: WM.capKeys
      delegate: SettingsRow {
        id: capRow
        required property string modelData
        readonly property bool ok: WM.has(capRow.modelData)

        title: Translations.t("gmCap_" + capRow.modelData)

        Text {
          Layout.alignment: Qt.AlignVCenter
          text: capRow.ok ? "󰄬" : "󰅖"
          color: capRow.ok ? Theme.primary : Theme.subtext
          font.pixelSize: Theme.sfs(14)
          font.family: Theme.monoFamily
        }
        Text {
          Layout.alignment: Qt.AlignVCenter
          text: Translations.t(capRow.ok ? "gmCapOn" : "gmCapOff")
          color: capRow.ok ? Theme.text : Theme.subtext
          font.pixelSize: Theme.sfs(11)
          font.family: Theme.fontFamily
        }
      }
    }

    SettingsNote {
      visible: WM.wm === "niri"
      text: Translations.t("gmNiriNote")
    }
  }
}
