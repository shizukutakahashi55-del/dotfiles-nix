pragma Singleton
import QtQuick

// AppState — estado compartido entre Pill / Dashboard / Tray.
//
// Administra ESTADO, no geometría: nada de x/y/width/pillGroupWidth acá.
// Cada superficie (PILL/Pill.qml, DASHBOARD/Dashboard.qml, TRAY/Tray.qml)
// lee lo que le importa y calcula su propia geometría con su propio
// Theme.* — ver la especificación (Pill + Dashboard + Tray) para el porqué.
//
// Los tres estados de acá abajo son independientes A PROPÓSITO: abrir el
// Dashboard no debe apagar la Tray ni el auto-hide, y viceversa.
QtObject {
    id: root

    // ── Dashboard ────────────────────────────────────────────────
    // Como Menu/AudioMenu/Mpris (shell.qml), solo hay UNO abierto a la vez
    // en TODA la máquina — `dashboardScreen` dice en cuál de los monitores
    // (si hay varios). Sigue siendo "estado", no geometría: cada Pill.qml
    // decide sola cómo se ve/anima en su propia pantalla.
    property bool dashboardOpen: false
    property string dashboardScreen: ""
    // "power" | "mpris" | "performance" | "audio" | "calendar" | "quickaccess" | "overview"
    property string dashboardSection: "power"

    function openDashboard(section, screen) {
        if (section) root.dashboardSection = section
        if (screen) root.dashboardScreen = screen
        root.dashboardOpen = true
    }
    function closeDashboard() {
        root.dashboardOpen = false
    }
    // Mismo botón (o la misma Pill) que ya estaba abierto → cierra.
    // Otra sección, u otra pantalla → cambia a esa, sin cerrar/reabrir.
    function toggleDashboard(section, screen) {
        const samePlace = !screen || screen === root.dashboardScreen
        if (root.dashboardOpen && samePlace && (!section || section === root.dashboardSection)) {
            root.closeDashboard()
        } else {
            root.openDashboard(section, screen)
        }
    }

    // ── Tray (independiente: no depende de dashboardOpen) ───────────
    property bool trayVisible: true

    // ── Auto-hide de la Píldora (independiente de todo lo anterior) ─
    property bool pillAutoHide: false
    // Oculta de verdad ahora mismo (lo mueve Pill.qml según inactividad /
    // proximidad del mouse a la trigger zone). Nadie más debería tocarlo.
    property bool pillHiddenNow: false
    // false (por defecto): la píldora central y la de Tray/Batería se esconden y
    // reaparecen cada una por su cuenta. true: se esconden/aparecen juntas.
    property bool pillTraySync: false

    // ── Gaps de Hyprland (general:gaps_out) ─────────────────────
    // Lo copia shell.qml desde `appearance.gapsOut`. Pill.qml lo usa para
    // calcular cuánto espacio reservar: Hyprland SUMA el exclusiveZone a
    // gaps_out, así que si el gap ya cubre parte de la franja del trigger
    // solo hace falta reservar la diferencia.
    property int gapsOut: 6
}
