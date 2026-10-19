// ProfilePage — categoría "Perfil": foto y nombre para mostrar.

import QtQuick
import QtQuick.Layouts
import ".."
import "../../COMMON"
import "../../Services/Lang"

SettingsPage {
  id: page
  catId: "profile"

  property bool browsing: false

  onBrowsingChanged: { if (page.browsing) profileBrowser.go(profileBrowser.home + "/Pictures") }

  SettingsSection {
    titleKey: "profilePhoto"

    SettingsRow {
      title: UserProfile.shownName.length > 0 ? UserProfile.shownName : "—"
      hint: UserProfile.busy ? Translations.t("profileSaving")
          : UserProfile.avatarSource !== "" ? Translations.t("profilePhoto")
          : Translations.t("profileNoPhoto")

      SettingsBtn {
        visible: UserProfile.avatarPath !== ""
        icon: "󰆴"
        text: Translations.t("profileRemove")
        onClicked: UserProfile.clearAvatar()
      }
      SettingsBtn {
        primary: true
        icon: "󰋩"
        text: UserProfile.avatarSource !== "" ? Translations.t("profileChange")
                                              : Translations.t("profileChoose")
        onClicked: page.browsing = !page.browsing
      }
      Avatar {
        Layout.preferredWidth: 56
        Layout.preferredHeight: 56
        size: 56
        source: UserProfile.avatarUrl
        letter: UserProfile.shownName.length > 0 ? UserProfile.shownName.charAt(0).toUpperCase() : "?"
      }
    }

    SettingsNote {
      visible: page.browsing
      text: Translations.t("profileBrowseHint")
    }

    SettingsRow {
      visible: page.browsing
      stacked: true
      ImageBrowser {
        id: profileBrowser
        Layout.fillWidth: true
        Layout.preferredHeight: 290
        onPicked: path => {
          UserProfile.chooseAvatar(path)
          page.browsing = false
        }
        onCancelled: page.browsing = false
      }
    }
  }

  SettingsSection {
    titleKey: "profileDisplayName"
    hintKey: "profileDisplayNameHint"

    SettingsRow {
      stacked: true
      SettingsField {
        placeholder: Translations.t("profileDisplayNamePlaceholder")
        value: UserProfile.displayName
        onSubmitted: text => UserProfile.setDisplayName(text)
      }
    }
  }
}
