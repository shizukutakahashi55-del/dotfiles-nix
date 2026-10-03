// GlobalManagerPage — categoría "Global-Manager": qué window manager y qué
// distro usa la shell. De esto dependen el buscador de paquetes y lo que se
// muestra / adapta en el resto de Ajustes (ver COMMON/WM.qml).
import QtQuick
import QtQuick.Layouts
import ".."
import "../../COMMON"
import "../../LANG"

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

  // ── Window manager ──────────────────────────────────────────────
  SettingsSection {
    titleKey: "gmWmTitle"
    hintKey: "gmWmHint"

    Flow {
      Layout.fillWidth: true
      spacing: 8

      SettingsBtn {
        text: Translations.t("gmAuto")
        primary: WM.wmPref === "auto"
        onClicked: WM.setWm("auto")
      }
      Repeater {
        model: WM.wmList
        delegate: SettingsBtn {
          required property var modelData
          text: modelData.name
          primary: WM.wmPref === modelData.id
          onClicked: WM.setWm(modelData.id)
        }
      }
    }

    Text {
      Layout.fillWidth: true
      wrapMode: Text.WordWrap
      color: Theme.subtext
      font.pixelSize: Theme.fs(11)
      font.family: Theme.fontFamily
      text: Translations.t("gmDetected") + ": " + page.wmName(WM.detectedWm)
          + "  ·  " + Translations.t("gmActive") + ": " + page.wmName(WM.wm)
    }

    Text {
      visible: WM.wmMismatch
      Layout.fillWidth: true
      wrapMode: Text.WordWrap
      color: Theme.error
      font.pixelSize: Theme.fs(11)
      font.family: Theme.fontFamily
      text: Translations.t("gmMismatch")
    }
  }

  // ── Distribución + buscador de paquetes ─────────────────────────
  SettingsSection {
    titleKey: "gmDistroTitle"
    hintKey: "gmDistroHint"

    Flow {
      Layout.fillWidth: true
      spacing: 8

      SettingsBtn {
        text: Translations.t("gmAuto")
        primary: WM.distroPref === "auto"
        onClicked: WM.setDistro("auto")
      }
      Repeater {
        model: WM.distroList
        delegate: SettingsBtn {
          required property var modelData
          text: modelData.name
          primary: WM.distroPref === modelData.id
          onClicked: WM.setDistro(modelData.id)
        }
      }
    }

    // Gestor de paquetes: solo tiene sentido en Arch
    Text {
      visible: WM.distro === "arch"
      Layout.fillWidth: true
      Layout.topMargin: 6
      text: Translations.t("gmPkgHelperTitle")
      color: Theme.text
      font.pixelSize: Theme.fs(12)
      font.bold: true
      font.family: Theme.fontFamily
    }
    Flow {
      visible: WM.distro === "arch"
      Layout.fillWidth: true
      spacing: 8

      SettingsBtn {
        text: Translations.t("gmAuto")
        primary: WM.pkgHelperPref === "auto"
        onClicked: WM.setPkgHelper("auto")
      }
      Repeater {
        model: WM.pkgHelperList
        delegate: SettingsBtn {
          required property string modelData
          text: modelData + (WM.isInstalled(modelData) ? "" : "  ·  " + Translations.t("gmMissing"))
          primary: WM.pkgHelperPref === modelData
          onClicked: WM.setPkgHelper(modelData)
        }
      }
    }

    Text {
      Layout.fillWidth: true
      wrapMode: Text.WordWrap
      color: Theme.subtext
      font.pixelSize: Theme.fs(11)
      font.family: Theme.fontFamily
      text: Translations.t("gmDetected") + ": " + page.distroName(WM.detectedDistro)
          + "  ·  " + Translations.t("gmPkgBackend") + ": " + WM.packageBackend
    }
  }

  // ── Compatibilidad del WM elegido ───────────────────────────────
  SettingsSection {
    titleKey: "gmCapsTitle"
    hintKey: "gmCapsHint"

    Repeater {
      model: WM.capKeys
      delegate: RowLayout {
        required property string modelData
        readonly property bool ok: WM.has(modelData)
        Layout.fillWidth: true
        spacing: 10

        Text {
          text: parent.ok ? "󰄬" : "󰅖"
          color: parent.ok ? Theme.primary : Theme.subtext
          font.pixelSize: Theme.fs(14)
          font.family: Theme.monoFamily
        }
        Text {
          Layout.fillWidth: true
          text: Translations.t("gmCap_" + parent.modelData)
          color: parent.ok ? Theme.text : Theme.subtext
          font.pixelSize: Theme.fs(12)
          font.family: Theme.fontFamily
        }
        Text {
          text: Translations.t(parent.ok ? "gmCapOn" : "gmCapOff")
          color: Theme.subtext
          font.pixelSize: Theme.fs(10)
          font.family: Theme.fontFamily
        }
      }
    }

    Text {
      visible: WM.wm === "niri"
      Layout.fillWidth: true
      wrapMode: Text.WordWrap
      color: Theme.subtext
      font.pixelSize: Theme.fs(11)
      font.family: Theme.fontFamily
      text: Translations.t("gmNiriNote")
    }
  }
}
