// AgendaView — el calendario nuevo: mes a la derecha, panel lateral a la
// izquierda que alterna (toggle) entre el DÍA seleccionado en grande y la
// lista ToDo de ese día (TodoBackend).
//
// Es solo CONTENIDO (sin fondo ni posición propia), para reutilizarlo:
//   • DASHBOARD/DashboardCalendar.qml  → sección del Dashboard (modo Píldora)
//   • AGENDA/AgendaPopup.qml           → popup del clic derecho en el reloj
//                                        (barra clásica / islas)
//
// Toca un día para seleccionarlo (las tareas son de ese día); los días con
// pendientes llevan un punto. El título del mes vuelve a hoy.
import QtQuick
import QtQuick.Layouts
import "../COMMON"
import "../LANG"
import "../AGENDA"

Item {
  id: root

  // Esc dentro del campo de texto (ahí el teclado no llega a quien cierra)
  signal closeRequested()

  // true cuando vive dentro del Dashboard: medidas y letras siguen el nivel de
  // tamaño del Dashboard (Theme.ds / Theme.dfs). En el popup del reloj queda
  // en false y todo sigue como antes (Theme.fs, medidas base).
  property bool dash: false
  // Las medidas de esta vista nacieron para el popup del reloj (656×392, letras
  // de 13‥18 y un día de 76). El resto de secciones del Dashboard usa cajas de
  // 440‥560 y letras de 9‥13, así que dentro del Dashboard el calendario se
  // compacta con estos factores (geometría / texto) para verse del mismo
  // tamaño. En el popup del reloj no aplican.
  readonly property real dashGeom: 0.78
  readonly property real dashText: 0.80
  function sz(px) { return root.dash ? Theme.ds(px * root.dashGeom) : px }
  function f(px) { return root.dash ? Theme.dfs(px * root.dashText) : Theme.fs(px) }

  readonly property int pad: root.sz(16)
  readonly property int sideW: root.sz(256)
  implicitWidth: root.sz(656)
  implicitHeight: root.sz(392)

  // ─── Fechas ───────────────────────────────────────────────────
  // Nombres de días/mes en el idioma del shell (no en el del sistema)
  readonly property var loc: Qt.locale(({ en: "en_US", es: "es_ES", id: "id_ID", ja: "ja_JP" })[Translations.current] || "en_US")

  property var today: new Date()
  property int monthOffset: 0
  property var selected: new Date()
  // Primer día del mes que se está mirando
  readonly property var viewDate: new Date(today.getFullYear(), today.getMonth() + monthOffset, 1)
  readonly property string selKey: TodoBackend.dateKey(selected)
  readonly property string todayKey: TodoBackend.dateKey(today)
  readonly property bool selIsToday: selKey === todayKey
  readonly property bool viewingCurrentMonth: monthOffset === 0

  function reset() {
    root.today = new Date()
    root.monthOffset = 0
    root.selected = new Date()
  }
  function goToday() { root.reset() }

  // Se refresca solo pasada la medianoche
  Timer {
    interval: 60000
    running: true
    repeat: true
    onTriggered: root.today = new Date()
  }

  function cap(s) { return s.length ? s.charAt(0).toUpperCase() + s.slice(1) : s }
  function dayLong(d)    { return root.cap(root.loc.dayName(d.getDay(), Locale.LongFormat)) }
  function monthLong(d)  { return root.cap(root.loc.monthName(d.getMonth(), Locale.LongFormat)) }
  function monthShort(d) { return root.cap(root.loc.monthName(d.getMonth(), Locale.ShortFormat)) }

  // Lunes = 0 ... Domingo = 6. Siempre 42 celdas (6 semanas): el alto no
  // cambia de un mes a otro.
  readonly property var calCells: {
    const y = viewDate.getFullYear()
    const m = viewDate.getMonth()
    const total = new Date(y, m + 1, 0).getDate()
    const offset = (new Date(y, m, 1).getDay() + 6) % 7
    const cells = []
    for (let i = 0; i < offset; i++) cells.push(0)
    for (let d = 1; d <= total; d++) cells.push(d)
    while (cells.length < 42) cells.push(0)
    return cells
  }

  // Letras de la semana empezando en lunes
  readonly property var dayLetters: {
    const out = []
    for (let i = 0; i < 7; i++) out.push(root.loc.dayName((i + 1) % 7, Locale.NarrowFormat))
    return out
  }

  // ─── Contenido ────────────────────────────────────────────────
  RowLayout {
    anchors.fill: parent
    anchors.margins: root.pad
    spacing: root.sz(12)

    // ══════════════ PANEL LATERAL: día ⇄ ToDo ══════════════
    Rectangle {
      id: side
      Layout.preferredWidth: root.sideW
      Layout.fillHeight: true
      radius: root.sz(14)
      color: Theme.surface
      clip: true

      readonly property bool todoMode: TodoBackend.showTodo

      // Toggle: día ⇄ ToDo
      Rectangle {
        id: toggleBtn
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: root.sz(8)
        width: root.sz(36)
        height: root.sz(36)
        radius: root.sz(11)
        z: 2
        color: side.todoMode ? Theme.primary
             : (toggleMouse.containsMouse ? Theme.surfaceHigh : "transparent")
        Behavior on color { ColorAnimation { duration: 150 } }
        scale: toggleMouse.pressed ? 0.9 : 1.0
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }

        Text {
          anchors.centerIn: parent
          text: "󰉹"
          color: side.todoMode ? Theme.textOnPrimary : Theme.text
          font.pixelSize: root.f(18)
          font.family: Theme.monoFamily
        }
        // Puntito: hay pendientes hoy y estás viendo el día
        Rectangle {
          visible: !side.todoMode && TodoBackend.pendingFor(root.selKey) > 0
          width: root.sz(8); height: root.sz(8); radius: root.sz(4)
          color: Theme.primary
          anchors.top: parent.top
          anchors.right: parent.right
          anchors.margins: root.sz(4)
        }
        MouseArea {
          id: toggleMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: TodoBackend.setShowTodo(!TodoBackend.showTodo)
        }
      }

      // ── Modo DÍA ──────────────────────────────────────────
      Item {
        id: dayView
        anchors.fill: parent
        opacity: side.todoMode ? 0 : 1
        visible: opacity > 0.01
        enabled: !side.todoMode
        Behavior on opacity { NumberAnimation { duration: 180 } }

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: root.sz(14)
          spacing: 0

          Text {
            Layout.fillWidth: true
            Layout.rightMargin: 42
            text: root.dayLong(root.selected)
            color: Theme.primary
            font.pixelSize: root.f(14)
            font.bold: true
            font.family: Theme.fontFamily
            elide: Text.ElideRight
          }

          Text {
            Layout.topMargin: 6
            text: root.selected.getDate()
            color: Theme.text
            font.pixelSize: root.f(76)
            font.bold: true
            font.family: Theme.fontFamily
          }

          Text {
            Layout.fillWidth: true
            text: root.monthLong(root.selected)
            color: Theme.text
            font.pixelSize: root.f(18)
            font.family: Theme.fontFamily
            elide: Text.ElideRight
          }
          Text {
            text: root.selected.getFullYear()
            color: Theme.subtext
            font.pixelSize: root.f(14)
            font.family: Theme.fontFamily
          }

          Item { Layout.fillHeight: true }

          // "Hoy": vuelve al día actual (solo si miraste otro)
          Rectangle {
            visible: !root.selIsToday || !root.viewingCurrentMonth
            Layout.fillWidth: true
            Layout.preferredHeight: root.sz(38)
            Layout.bottomMargin: 6
            radius: root.sz(11)
            color: todayMouse.containsMouse ? Theme.primary : Theme.surfaceHigh
            Behavior on color { ColorAnimation { duration: 150 } }
            Text {
              anchors.centerIn: parent
              text: Translations.t("agendaToday")
              color: todayMouse.containsMouse ? Theme.textOnPrimary : Theme.text
              font.pixelSize: root.f(13)
              font.family: Theme.fontFamily
            }
            MouseArea {
              id: todayMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.goToday()
            }
          }

          // Resumen de tareas del día → abre la lista
          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: root.sz(38)
            radius: root.sz(11)
            color: sumMouse.containsMouse ? Theme.surfaceHigh : "transparent"
            Behavior on color { ColorAnimation { duration: 150 } }
            RowLayout {
              anchors.centerIn: parent
              spacing: root.sz(6)
              Text {
                text: "󰄬"
                color: Theme.primary
                font.pixelSize: root.f(16)
                font.family: Theme.monoFamily
              }
              Text {
                readonly property int n: TodoBackend.pendingFor(root.selKey)
                text: n > 0 ? (n + " " + Translations.t("agendaPending")) : Translations.t("agendaNoTasks")
                color: Theme.subtext
                font.pixelSize: root.f(13)
                font.family: Theme.fontFamily
              }
            }
            MouseArea {
              id: sumMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: TodoBackend.setShowTodo(true)
            }
          }
        }
      }

      // ── Modo TODO ─────────────────────────────────────────
      Item {
        id: todoView
        anchors.fill: parent
        opacity: side.todoMode ? 1 : 0
        visible: opacity > 0.01
        enabled: side.todoMode
        Behavior on opacity { NumberAnimation { duration: 180 } }

        readonly property var tasks: TodoBackend.tasksFor(root.selKey)

        function submit() {
          if (input.text.trim() === "") return
          const tm = TodoBackend.normTime(timeInput.text)
          // Hora escrita pero inválida: no se crea, se deja el foco en ella
          if (timeInput.text.trim() !== "" && tm === "") { timeInput.forceActiveFocus(); return }
          TodoBackend.add(input.text, root.selKey, tm)
          input.text = ""
          timeInput.text = ""
        }

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: root.sz(14)
          spacing: root.sz(10)

          // Cabecera: día seleccionado (compacto)
          ColumnLayout {
            Layout.fillWidth: true
            Layout.rightMargin: 42
            spacing: 0
            Text {
              Layout.fillWidth: true
              text: root.dayLong(root.selected)
              color: Theme.primary
              font.pixelSize: root.f(13)
              font.bold: true
              font.family: Theme.fontFamily
              elide: Text.ElideRight
            }
            Text {
              Layout.fillWidth: true
              text: root.selected.getDate() + " " + root.monthShort(root.selected)
              color: Theme.text
              font.pixelSize: root.f(18)
              font.bold: true
              font.family: Theme.fontFamily
              elide: Text.ElideRight
            }
          }

          // Lista
          Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Text {
              anchors.centerIn: parent
              visible: todoView.tasks.length === 0
              text: Translations.t("agendaNoTasks")
              color: Theme.subtext
              font.pixelSize: root.f(13)
              font.family: Theme.fontFamily
            }

            ListView {
              id: list
              anchors.fill: parent
              clip: true
              spacing: root.sz(3)
              boundsBehavior: Flickable.StopAtBounds
              model: todoView.tasks

              delegate: Rectangle {
                id: row
                required property var modelData
                width: ListView.view.width
                height: root.sz(38)
                radius: root.sz(10)
                color: rowHover.hovered ? Theme.surfaceHigh : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }

                // HoverHandler y no MouseArea.containsMouse: los MouseArea de encima
                // (la hora, el tacho) le "roban" el hover a este, y el estado de la fila
                // parpadeaba al pasar el mouse por ellos.
                HoverHandler { id: rowHover }

                MouseArea {
                  id: rowMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  onClicked: TodoBackend.toggle(row.modelData.id)
                  cursorShape: Qt.PointingHandCursor
                }

                RowLayout {
                  anchors.fill: parent
                  anchors.leftMargin: root.sz(8)
                  anchors.rightMargin: root.sz(6)
                  spacing: root.sz(8)

                  Text {
                    text: row.modelData.done ? "󰄳" : "󰄰"
                    color: row.modelData.done ? Theme.primary : Theme.subtext
                    font.pixelSize: root.f(17)
                    font.family: Theme.monoFamily
                  }
                  Text {
                    Layout.fillWidth: true
                    text: row.modelData.text
                    color: row.modelData.done ? Theme.subtext : Theme.text
                    font.pixelSize: root.f(13)
                    font.strikeout: row.modelData.done
                    font.family: Theme.fontFamily
                    elide: Text.ElideRight
                  }
                  // Alarma de la tarea: clic en la hora la quita
                  Rectangle {
                    visible: row.modelData.time !== ""
                    Layout.preferredHeight: root.sz(24)
                    Layout.preferredWidth: timeRow.implicitWidth + 14
                    radius: root.sz(8)
                    color: timeChipMouse.containsMouse
                      ? Theme.error
                      : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, row.modelData.done ? 0.08 : 0.16)
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Row {
                      id: timeRow
                      anchors.centerIn: parent
                      spacing: root.sz(4)
                      Text {
                        // Ancho fijo: las dos campanas (activa / tachada) pueden medir
                        // distinto y la etiqueta no debe cambiar de tamaño al pasar el mouse
                        width: root.f(14)
                        horizontalAlignment: Text.AlignHCenter
                        text: timeChipMouse.containsMouse ? "󰂛" : "󰂞"
                        color: timeChipMouse.containsMouse ? Theme.textOnPrimary
                             : (row.modelData.done ? Theme.subtext : Theme.primary)
                        font.pixelSize: root.f(11)
                        font.family: Theme.monoFamily
                      }
                      Text {
                        text: row.modelData.time
                        color: timeChipMouse.containsMouse ? Theme.textOnPrimary
                             : (row.modelData.done ? Theme.subtext : Theme.primary)
                        font.pixelSize: root.f(11)
                        font.bold: true
                        font.family: Theme.fontFamily
                      }
                    }
                    MouseArea {
                      id: timeChipMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: TodoBackend.clearTime(row.modelData.id)
                    }
                  }
                  Rectangle {
                    Layout.preferredWidth: root.sz(28)
                    Layout.preferredHeight: root.sz(28)
                    radius: root.sz(8)
                    // Siempre visible (atenuado): antes solo aparecía con el mouse encima, y al
                    // aparecer empujaba la hora hacia la izquierda → el mouse quedaba fuera de
                    // ella, el tacho desaparecía, volvía todo… un parpadeo sin fin.
                    opacity: (rowHover.hovered || delMouse.containsMouse) ? 1 : 0.4
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                    color: delMouse.containsMouse ? Theme.error : "transparent"
                    Text {
                      anchors.centerIn: parent
                      text: "󰆴"
                      color: delMouse.containsMouse ? Theme.textOnPrimary : Theme.subtext
                      font.pixelSize: root.f(14)
                      font.family: Theme.monoFamily
                    }
                    MouseArea {
                      id: delMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: TodoBackend.remove(row.modelData.id)
                    }
                  }
                }
              }
            }
          }

          // Limpiar completadas
          Text {
            visible: TodoBackend.doneFor(root.selKey) > 0
            Layout.alignment: Qt.AlignHCenter
            text: Translations.t("agendaClearDone")
            color: clearMouse.containsMouse ? Theme.primary : Theme.subtext
            font.pixelSize: root.f(12)
            font.family: Theme.fontFamily
            MouseArea {
              id: clearMouse
              anchors.fill: parent
              anchors.margins: -4
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: TodoBackend.clearDone(root.selKey)
            }
          }

          // Nueva tarea: el texto va en su propia barra a todo el ancho y debajo
          // la hora + el botón (antes todo iba en una sola fila de 30 px con el
          // texto cortado en "Nueva t…").
          ColumnLayout {
            Layout.fillWidth: true
            spacing: root.sz(6)

            Rectangle {
              Layout.fillWidth: true
              Layout.preferredHeight: root.sz(40)
              radius: root.sz(12)
              color: Theme.surfaceHigh
              border.width: input.activeFocus ? 1.5 : 0
              border.color: Theme.primary

              // Toda la barra enfoca el campo (no solo el texto)
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.IBeamCursor
                onClicked: input.forceActiveFocus()
              }

              TextInput {
                id: input
                anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.text
                selectionColor: Theme.primary
                selectedTextColor: Theme.textOnPrimary
                font.pixelSize: root.f(13)
                font.family: Theme.fontFamily
                clip: true
                selectByMouse: true

                onAccepted: todoView.submit()
                // Esc: 1.º borra lo escrito, 2.º cierra (acá el teclado no
                // llega al que cierra el popup/dock)
                Keys.onEscapePressed: event => {
                  if (input.text !== "") input.text = ""
                  else { input.focus = false; root.closeRequested() }
                  event.accepted = true
                }

                Text {
                  anchors.fill: parent
                  verticalAlignment: Text.AlignVCenter
                  visible: input.text === ""
                  text: Translations.t("agendaNewTask")
                  color: Theme.subtext
                  font: input.font
                  elide: Text.ElideRight
                }
              }
            }

            RowLayout {
              Layout.fillWidth: true
              spacing: root.sz(6)

              // Hora de la alarma (opcional): 18:30 · 1830 · 9 → 09:00
              Rectangle {
                readonly property bool bad: timeInput.text.trim() !== "" && TodoBackend.normTime(timeInput.text) === ""
                Layout.fillWidth: true
                Layout.preferredHeight: root.sz(36)
                radius: root.sz(11)
                color: Theme.surfaceHigh
                opacity: TodoBackend.alarmsEnabled ? 1 : 0.55
                border.width: (bad || timeInput.activeFocus) ? 1.5 : 0
                border.color: bad ? Theme.error : Theme.primary

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.IBeamCursor
                  onClicked: timeInput.forceActiveFocus()
                }

                RowLayout {
                  anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                  spacing: root.sz(8)
                  Text {
                    text: "󰂞"
                    color: timeInput.text !== "" ? Theme.primary : Theme.subtext
                    font.pixelSize: root.f(15)
                    font.family: Theme.monoFamily
                  }
                  TextInput {
                    id: timeInput
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    color: Theme.text
                    selectionColor: Theme.primary
                    selectedTextColor: Theme.textOnPrimary
                    font.pixelSize: root.f(13)
                    font.family: Theme.monoFamily
                    maximumLength: 5
                    clip: true
                    selectByMouse: true
                    validator: RegularExpressionValidator { regularExpression: /^[0-9:]{0,5}$/ }
                    onAccepted: todoView.submit()
                    Keys.onEscapePressed: event => {
                      if (timeInput.text !== "") timeInput.text = ""
                      else { timeInput.focus = false; root.closeRequested() }
                      event.accepted = true
                    }
                    Text {
                      anchors.fill: parent
                      verticalAlignment: Text.AlignVCenter
                      visible: timeInput.text === ""
                      text: "hh:mm"
                      color: Theme.subtext
                      font: timeInput.font
                    }
                  }
                }
              }

              Rectangle {
                Layout.preferredHeight: root.sz(36)
                Layout.preferredWidth: addRow.implicitWidth + 28
                radius: root.sz(11)
                color: addMouse.containsMouse ? Qt.lighter(Theme.primary, 1.12) : Theme.primary
                opacity: input.text.trim() !== "" ? 1 : 0.5
                Behavior on color { ColorAnimation { duration: 120 } }
                scale: addMouse.pressed ? 0.95 : 1.0
                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }

                Row {
                  id: addRow
                  anchors.centerIn: parent
                  spacing: root.sz(6)
                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰐕"
                    color: Theme.textOnPrimary
                    font.pixelSize: root.f(15)
                    font.family: Theme.monoFamily
                  }
                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Translations.t("agendaAdd")
                    color: Theme.textOnPrimary
                    font.pixelSize: root.f(13)
                    font.bold: true
                    font.family: Theme.fontFamily
                  }
                }
                MouseArea {
                  id: addMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: todoView.submit()
                }
              }
            }
          }
        }
      }
    }

    // ══════════════ MES ══════════════
    ColumnLayout {
      id: gridCol
      Layout.fillWidth: true
      Layout.fillHeight: true
      spacing: root.sz(8)

      readonly property int gap: 5
      readonly property real cellW: (width - 6 * gap) / 7

      // Mes / año + flechas
      RowLayout {
        Layout.fillWidth: true
        spacing: root.sz(4)

        Rectangle {
          Layout.preferredWidth: root.sz(34)
          Layout.preferredHeight: root.sz(34)
          radius: root.sz(10)
          color: prevMouse.containsMouse ? Theme.surface : "transparent"
          Behavior on color { ColorAnimation { duration: 120 } }
          Text {
            anchors.centerIn: parent
            text: "󰅁"
            color: Theme.text
            font.pixelSize: root.f(18)
            font.family: Theme.monoFamily
          }
          MouseArea {
            id: prevMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.monthOffset -= 1
          }
        }

        Text {
          Layout.fillWidth: true
          horizontalAlignment: Text.AlignHCenter
          text: root.monthLong(root.viewDate) + " " + root.viewDate.getFullYear()
          color: root.viewingCurrentMonth ? Theme.text : Theme.primary
          font.pixelSize: root.f(14)
          font.bold: true
          font.family: Theme.fontFamily
          Behavior on color { ColorAnimation { duration: 150 } }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.goToday()
          }
        }

        Rectangle {
          Layout.preferredWidth: root.sz(34)
          Layout.preferredHeight: root.sz(34)
          radius: root.sz(10)
          color: nextMouse.containsMouse ? Theme.surface : "transparent"
          Behavior on color { ColorAnimation { duration: 120 } }
          Text {
            anchors.centerIn: parent
            text: "󰅂"
            color: Theme.text
            font.pixelSize: root.f(18)
            font.family: Theme.monoFamily
          }
          MouseArea {
            id: nextMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.monthOffset += 1
          }
        }
      }

      Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }

      GridLayout {
        Layout.fillWidth: true
        columns: 7
        columnSpacing: gridCol.gap
        rowSpacing: gridCol.gap

        Repeater {
          model: root.dayLetters
          delegate: Text {
            Layout.preferredWidth: gridCol.cellW
            horizontalAlignment: Text.AlignHCenter
            text: modelData
            color: Theme.subtext
            font.pixelSize: root.f(12)
            font.family: Theme.monoFamily
          }
        }

        Repeater {
          model: root.calCells
          delegate: Rectangle {
            id: cell
            required property var modelData

            readonly property bool valid: modelData !== 0
            readonly property string key: valid
              ? TodoBackend.dateKey(new Date(root.viewDate.getFullYear(), root.viewDate.getMonth(), modelData))
              : ""
            readonly property bool isToday: valid && key === root.todayKey
            readonly property bool isSel: valid && key === root.selKey
            readonly property bool hasTasks: valid && (TodoBackend.pending[key] || 0) > 0

            Layout.preferredWidth: gridCol.cellW
            Layout.preferredHeight: root.sz(38)
            radius: root.sz(10)
            color: isToday ? Theme.primary
                 : (valid && cellMouse.containsMouse) ? Theme.surface : "transparent"
            border.width: (isSel && !isToday) ? 1.5 : 0
            border.color: Theme.primary
            Behavior on color { ColorAnimation { duration: 120 } }

            Text {
              anchors.centerIn: parent
              anchors.verticalCenterOffset: cell.hasTasks ? -2 : 0
              text: cell.valid ? cell.modelData : ""
              color: cell.isToday ? Theme.textOnPrimary : Theme.text
              font.pixelSize: root.f(13)
              font.bold: cell.isToday || cell.isSel
              font.family: Theme.fontFamily
            }

            // Punto: ese día tiene tareas pendientes
            Rectangle {
              visible: cell.hasTasks
              width: root.sz(5); height: root.sz(5); radius: root.sz(3)
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.bottom: parent.bottom
              anchors.bottomMargin: root.sz(3)
              color: cell.isToday ? Theme.textOnPrimary : Theme.primary
            }

            MouseArea {
              id: cellMouse
              anchors.fill: parent
              enabled: cell.valid
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.selected = new Date(root.viewDate.getFullYear(), root.viewDate.getMonth(), cell.modelData)
            }
          }
        }
      }
    }
  }
}
