// AgendaPage — categoría "Agenda": alarmas del ToDo.

import QtQuick
import QtQuick.Layouts
import ".."
import "../../COMMON"
import "../../Services/Lang"

SettingsPage {
  id: page
  catId: "agenda"

  TodoAlarmSettings { Layout.fillWidth: true }
}
