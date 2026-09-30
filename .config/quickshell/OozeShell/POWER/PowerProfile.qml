// PowerProfile — perfil de energía (power-profiles-daemon).
//
// Antes vivía adentro de MENU/Menu.qml, mezclado con su UI. Se separa acá
// por la misma razón que PowerActions.qml y MPRIS/MprisBackend.qml: para
// que DASHBOARD/DashboardPerformance.qml pueda mostrar y cambiar el mismo
// perfil sin correr un segundo `powerprofilesctl` por su cuenta. Menu.qml
// ahora lee `current` de acá también (ver ese archivo).
//
// Mismo patrón que MprisBackend: solo sondea mientras alguien lo pide.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var wanters: ({})
    readonly property bool wanted: Object.keys(root.wanters).length > 0
    function setWanted(who, on) {
        if ((root.wanters[who] === true) === on) return
        const n = Object.assign({}, root.wanters)
        if (on) n[who] = true
        else delete n[who]
        root.wanters = n
    }

    property string current: "balanced"

    readonly property var profiles: [
        { key: "power-saver", icon: "󰌪", labelKey: "powerProfileSaver" },
        { key: "balanced",    icon: "󰗑", labelKey: "powerProfileBalanced" },
        { key: "performance", icon: "󰓅", labelKey: "powerProfilePerformance" }
    ]

    function set(profile) {
        setProc.profile = profile
        setProc.running = false
        setProc.running = true
    }

    Process {
        id: getProc
        // Primero por PATH; si el shell heredó un PATH recortado (exec-once/
        // systemd en NixOS), cae a la ruta fija del sistema.
        command: ["sh", "-c",
            'powerprofilesctl get 2>/dev/null || /run/current-system/sw/bin/powerprofilesctl get']
        running: false
        stdout: SplitParser { onRead: line => root.current = line.trim() }
    }

    Process {
        id: setProc
        property string profile: "balanced"
        // stderr a stdout: el motivo (perfil no disponible, polkit, binario
        // no encontrado…) queda en el log con el prefijo [power].
        command: ["sh", "-c",
            'powerprofilesctl set "$1" 2>&1 || /run/current-system/sw/bin/powerprofilesctl set "$1" 2>&1',
            "sh", profile]
        stdout: SplitParser { onRead: line => console.log("[power] set " + setProc.profile + ": " + line) }
        onRunningChanged: { if (!running) getProc.running = true }
    }

    Timer {
        interval: 500
        running: root.wanted
        repeat: false
        onTriggered: getProc.running = true
    }

    // Mientras alguien lo mire, refresca cada tanto (por si el perfil
    // cambió desde afuera: otra app, un atajo del sistema, etc.)
    Timer {
        interval: 4000
        running: root.wanted
        repeat: true
        onTriggered: { if (!getProc.running) getProc.running = true }
    }
}
