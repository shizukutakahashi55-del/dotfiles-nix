pragma Singleton
import Quickshell
import QtQuick
import "../COMMON"

// PowerActions — QUÉ acciones de energía existen y CÓMO se ejecutan.
// Antes vivía adentro de PowerMenu.qml; se separó para que
// DASHBOARD/DashboardPower.qml pueda mostrar las mismas 3-5 acciones sin
// duplicar comandos (ver especificación: "no debe duplicarse
// innecesariamente el backend"). PowerMenu.qml ahora lee `actions` de acá
// y llama a `run()` para ejecutar; sigue siendo dueño de SU animación de
// cierre antes de ejecutar (eso es UI, no backend).
QtObject {
    id: root

    function hyprshutdownCmd(text, postCmd) {
        // hyprshutdown solo existe en Hyprland: en Mango y Niri se ejecuta el
        // comando final directo (systemd cierra la sesión)
        if (!WM.has("hyprshutdown")) return ["sh", "-c", postCmd || "true"]
        const c = ["hyprshutdown", "-t", text]
        if (postCmd) c.push("--post-cmd", postCmd)
        return c
    }
    function logoutCmd() {
        return WM.logoutCommand()
    }

    // closesApps: informativo, para elegir el mensaje de confirmación en
    // quien lo use (PowerMenu ya lo hacía así).
    readonly property var actions: [
        { id: "shutdown",  icon: "󰐥", labelKey: "powerShutdown",  confirmKey: "powerConfirmShutdown",
          closesApps: true,
          cmd: root.hyprshutdownCmd("Shutting down...", "systemctl poweroff") },
        { id: "reboot",    icon: "󰑐", labelKey: "powerReboot",    confirmKey: "powerConfirmReboot",
          closesApps: true,
          cmd: root.hyprshutdownCmd("Rebooting...", "reboot") },
        { id: "suspend",   icon: "󰒲", labelKey: "powerSuspend",   confirmKey: "powerConfirmSuspend",
          closesApps: false,
          cmd: ["systemctl", "suspend"] },
        { id: "logout",    icon: "󰍃", labelKey: "powerLogout",    confirmKey: "powerConfirmLogout",
          closesApps: true,
          cmd: root.logoutCmd() },
        { id: "hibernate", icon: "󰋊", labelKey: "powerHibernate", confirmKey: "powerConfirmHibernate",
          closesApps: false,
          cmd: ["systemctl", "hibernate"] }
    ]

    function byId(id) { return root.actions.find(a => a.id === id) ?? null }

    // Ejecuta YA (execDetached: sobrevive a que el comando mate Hyprland,
    // como shutdown/reboot/logout, y con él a Quickshell). Quien llame
    // desde una UI con animación de cierre (PowerMenu) puede esperar a que
    // termine esa animación y recién ahí llamar a esto — ver PowerMenu.qml.
    function run(action) {
        if (action) Quickshell.execDetached(action.cmd)
    }
}
