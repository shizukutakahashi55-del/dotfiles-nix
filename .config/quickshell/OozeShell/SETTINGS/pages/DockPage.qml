// DockPage — categoría "Dock"

import QtQuick
import QtQuick.Layouts
import ".."
import "../../COMMON"
import "../../LANG"

SettingsPage {
  id: page
  catId: "dock"

  component Label: Text {
    Layout.preferredWidth: Math.min(implicitWidth, 140)
    Layout.maximumWidth: 140
    elide: Text.ElideRight
    color: Theme.text
    font.pixelSize: Theme.fs(12)
    font.bold: true
    font.family: Theme.fontFamily
  }

  component Hint: Text {
    Layout.fillWidth: true
    wrapMode: Text.WordWrap
    color: Theme.subtext
    font.pixelSize: Theme.fs(10)
    font.family: Theme.fontFamily
  }

  component Divider: Rectangle {
    Layout.fillWidth: true
    Layout.preferredHeight: 1
    color: Theme.divider
  }

  // ═══ Dock ══════════════════════════════════════════════════════
  SettingsSection {
    titleKey: "dockSection"

    Text {
      Layout.fillWidth: true
      visible: Theme.frameBorderActive
      wrapMode: Text.WordWrap
      text: Translations.t("dockFrameBlocked")
      color: Theme.primary
      font.pixelSize: Theme.fs(11)
      font.family: Theme.fontFamily
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: 10

      Label { text: Translations.t("dockEnable") }
      SettingsBtn {
        icon: Theme.dockEnabled ? "󰇙" : "󰇘"
        text: Theme.dockEnabled ? "ON" : "OFF"
        primary: Theme.dockEnabled
        onClicked: Theme.setDockEnabled(!Theme.dockEnabled)
      }

      Label { text: Translations.t("dockAutoHide") }
      SettingsBtn {
        icon: Theme.dockAutoHide ? "▣" : "▢"
        text: Theme.dockAutoHide ? "ON" : "OFF"
        primary: Theme.dockAutoHide
        onClicked: Theme.setDockAutoHide(!Theme.dockAutoHide)
      }
      Item { Layout.fillWidth: true }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: 10
      opacity: Theme.barVertical ? 1.0 : 0.4

      Label { text: Translations.t("dockPosition") }
      SettingsBtn {
        icon: "▀"
        text: Translations.t("barTop")
        primary: Theme.dockPosition === "top"
        onClicked: { if (Theme.barVertical) Theme.setDockPosition("top") }
      }
      SettingsBtn {
        icon: "▄"
        text: Translations.t("barBottom")
        primary: Theme.dockPosition === "bottom"
        onClicked: { if (Theme.barVertical) Theme.setDockPosition("bottom") }
      }
      Item { Layout.fillWidth: true }
    }
    Hint {
      text: Theme.barVertical ? Translations.t("dockPositionHint")
                              : Translations.t("dockPositionAutoHint")
    }
  }

  // ═══ Tamaño ════════════════════════════════════════════════════
  SettingsSection {
    titleKey: "dockSize"
    hintKey: "dockSizeHint"

    ScaleSlider {
      Layout.fillWidth: true
      value: Theme.dockScalePercent
      min: Theme.ownScaleMin
      max: Theme.ownScaleMax
      step: 5
      defaultValue: Theme.dockScaleDefault
      enabled: Theme.dockUsable
      opacity: Theme.dockUsable ? 1.0 : 0.4
      onEdited: v => Theme.setDockScalePercent(v)
    }
  }

  // ═══ Apariencia ════════════════════════════════════════════════
  SettingsSection {
    titleKey: "advDockLookTitle"
    hintKey: "advDockLookHint"

    RowLayout {
      Layout.fillWidth: true
      spacing: 10
      opacity: Theme.dockUsable ? 1.0 : 0.4

      Label { text: Translations.t("advDockModeLabel") }
      SettingsBtn {
        icon: "󰘔"
        text: Translations.t("advDockModePanel")
        primary: Theme.dockMode === "panel"
        onClicked: { if (Theme.dockUsable) Theme.setDockMode("panel") }
      }
      SettingsBtn {
        icon: "󰋙"
        text: Translations.t("advDockModePill")
        primary: Theme.dockMode === "pill"
        onClicked: { if (Theme.dockUsable) Theme.setDockMode("pill") }
      }
      Item { Layout.fillWidth: true }
    }
    Hint { text: Translations.t("advDockModeHint") }

    Divider {}

    Label { text: Translations.t("advDockOpacity") }
    ScaleSlider {
      Layout.fillWidth: true
      value: Theme.dockOpacity
      min: 0
      max: 100
      step: 5
      defaultValue: Theme.dockOpacityDefault
      enabled: Theme.dockUsable
      opacity: Theme.dockUsable ? 1.0 : 0.4
      onEdited: v => Theme.setDockOpacity(v)
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: 10
      opacity: Theme.dockUsable ? 1.0 : 0.4

      Label { text: Translations.t("advDockBlur") }
      SettingsBtn {
        icon: Theme.dockBlur > 0 ? "󰈈" : "󰈉"
        text: Theme.dockBlur > 0 ? "ON" : "OFF"
        primary: Theme.dockBlur > 0
        enabled: Theme.dockUsable
        onClicked: Theme.setDockBlur(Theme.dockBlur > 0 ? 0 : 100)
      }
      Item { Layout.fillWidth: true }
    }
    Hint {
      font.italic: true
      text: Translations.t("advDockLookNote")
    }
  }
}
