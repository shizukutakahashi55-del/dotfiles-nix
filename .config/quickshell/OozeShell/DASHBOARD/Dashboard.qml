import QtQuick
import "../COMMON"

// Dashboard — el CONTENIDO del estado expandido de la Pastilla.

Item {
    id: root

    property string screenName: ""
    property bool open: false
    // Pill.qml lo deja en true mientras la superficie todavía se está
    // cerrando, para que la sección se funda en vez de desaparecer de golpe.
    property bool keepLoaded: false
    // Pill.qml lo activa con el mouse sobre la píldora: la sección se carga
    // ANTES del clic para que la animación de abrir no tenga que crearla.
    property bool warm: false

    // Tamaño BASE del dock (más grande que el anterior: 44 + 190).
    readonly property int headerH: Theme.ds(64)
    // Cada sección puede pedir su propio tamaño (preferredWidth /
    // preferredHeight / maxWidth); sin pedirlo, las medidas base de siempre.
    // La superficie de Pill.qml anima el cambio.
    readonly property int baseContentH: Theme.ds(224)
    // Mientras la sección carga (Loader asíncrono) NO hay item: se conserva
    // el último tamaño conocido para que el dock no encoja y vuelva a crecer.
    property int heldContentH: root.baseContentH
    property int heldFullWidth: root.minW
    readonly property int sectionH:
        sectionLoader.item && sectionLoader.item.preferredHeight
            ? Math.round(sectionLoader.item.preferredHeight) : 0
    onSectionHChanged: if (root.sectionH > 0) root.heldContentH = root.sectionH
    readonly property int contentH:
        root.sectionH > 0 ? root.sectionH
        : (sectionLoader.item ? root.baseContentH : root.heldContentH)
    readonly property int fullHeight: headerH + contentH
    // 6 ítems en el header (6×58 + 5×6 + margen) no caben en menos de ~400
    readonly property int minW: Theme.ds(400)
    readonly property int maxW: Theme.ds(500)
    readonly property int sectionMaxW:
        sectionLoader.item && sectionLoader.item.maxWidth
            ? sectionLoader.item.maxWidth : root.maxW
    readonly property int sectionPreferredWidth:
        sectionLoader.item && sectionLoader.item.preferredWidth
            ? sectionLoader.item.preferredWidth : root.minW
    // El header manda: con nombres largos (otros idiomas) sus botones se
    // ensanchan, y el dock nunca puede ser más angosto que ellos.
    readonly property int liveFullWidth: Math.max(root.minW, header.requiredWidth,
        Math.min(root.sectionMaxW, root.sectionPreferredWidth))
    onLiveFullWidthChanged: if (sectionLoader.item) root.heldFullWidth = root.liveFullWidth
    readonly property int fullWidth: sectionLoader.item
        ? root.liveFullWidth : Math.max(root.heldFullWidth, header.requiredWidth)

    // Teclas que Pill.qml reenvía: la sección activa decide si las usa
    // (hoy solo Overview). true = tecla consumida.
    function handleKey(key, modifiers) {
        const it = sectionLoader.item
        return (it && it.handleKey) ? it.handleKey(key, modifiers) === true : false
    }

    signal requestNetwork()
    signal requestBluetooth()
    signal requestAppearance()
    signal requestWalls()
    signal requestAdvancedSettings()

    DashboardHeader {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.headerH
        section: AppState.dashboardSection
        onSectionSelected: s => AppState.dashboardSection = s
        // Niri: el botón de workspaces abre el overview nativo del compositor
        onActionTriggered: id => {
            if (id === "overview") {
                AppState.closeDashboard()
                WM.toggleNativeOverview()
            }
        }
    }

    Loader {
        id: sectionLoader
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        active: root.open || root.keepLoaded || root.warm
        // Asíncrono: crear la sección (Overview, Mpris…) de una sola vez en
        // el hilo de la UI congelaba los primeros frames de la animación.
        asynchronous: true
        // Desplazamiento de entrada al cambiar de sección (ver sectionEnter).
        // A píxel entero: con fracciones el texto pixel se ve borroso.
        transform: Translate { id: sectionShift; y: Math.round(root.shiftY) }
        source: {
            switch (AppState.dashboardSection) {
                case "power":       return "DashboardPower.qml"
                case "mpris":       return "DashboardMpris.qml"
                case "performance": return "DashboardPerformance.qml"
                case "audio":       return "DashboardAudio.qml"
                case "calendar":    return "DashboardCalendar.qml"
                case "overview":    return "DashboardOverview.qml"
                default:            return "DashboardQuickAccess.qml"
            }
        }
    }

    // ── Cambio de sección ───────────────────────────────────────
    // El contenido nuevo entra con un fundido corto y sube unos px, en vez
    // de aparecer de golpe. (El tamaño lo anima Pill.qml: dockW/dockH.)
    property real shiftY: 0
    ParallelAnimation {
        id: sectionEnter
        NumberAnimation { target: sectionLoader; property: "opacity"; from: 0; to: 1; duration: Theme.animDuration(200); easing.type: Easing.OutCubic }
        NumberAnimation { target: root;          property: "shiftY";  from: 10; to: 0; duration: Theme.animDuration(260); easing.type: Easing.OutCubic }
    }
    // La entrada arranca cuando la sección YA existe (Loader asíncrono);
    // al cambiar de sección se deja oculto el hueco mientras carga.
    Connections {
        target: AppState
        function onDashboardSectionChanged() {
            if (!root.open) return
            sectionEnter.stop()
            sectionLoader.opacity = 0
        }
    }
    Connections {
        target: sectionLoader
        function onLoaded() {
            root.heldFullWidth = root.liveFullWidth
            if (root.sectionH > 0) root.heldContentH = root.sectionH
            if (root.open) sectionEnter.restart()
        }
    }
    // Si se cerró a mitad de la animación, no dejar la sección a medio fundir
    onOpenChanged: {
        if (root.open) {
            sectionEnter.stop()
            sectionLoader.opacity = 1
            root.shiftY = 0
        }
    }

    Connections {
        target: sectionLoader.item
        ignoreUnknownSignals: true
        function onRequestNetwork() { root.requestNetwork() }
        function onRequestBluetooth() { root.requestBluetooth() }
        function onRequestAppearance() { root.requestAppearance() }
        function onRequestWalls() { root.requestWalls() }
        function onRequestAdvancedSettings() { root.requestAdvancedSettings() }
        function onCloseRequested() { AppState.closeDashboard() }
    }
}
