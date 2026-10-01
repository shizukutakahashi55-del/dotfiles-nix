pragma Singleton
import Quickshell
import QtQuick

// PowerActions — QUÉ acciones de energía existen y CÓMO se ejecutan.
// Antes vivía adentro de PowerMenu.qml; se separó para que
// DASHBOARD/DashboardPower.qml pueda mostrar las mismas 3-5 acciones sin
// duplicar comandos (ver especificación: "no debe duplicarse
// innecesariamente el backend"). PowerMenu.qml ahora lee `actions` de acá
// y llama a `run()` para ejecutar; sigue siendo dueño de SU animación de
// cierre antes de ejecutar (eso es UI, no backend).
QtObject {
    id: root

    // Mango no tiene "hyprshutdown": apagar/reiniciar van por systemd y el
    // logout sale del compositor con mmsg.
    function logoutCmd() {
        return ["mmsg", "dispatch", "quit"]
    }

    // closesApps: informativo, para elegir el mensaje de confirmación en
    // quien lo use (PowerMenu ya lo hacía así).
    readonly property var actions: [
        { id: "shutdown",  icon: "󰐥", labelKey: "powerShutdown",  confirmKey: "powerConfirmShutdown",
          closesApps: true,
          cmd: ["systemctl", "poweroff"] },
        { id: "reboot",    icon: "󰑐", labelKey: "powerReboot",    confirmKey: "powerConfirmReboot",
          closesApps: true,
          cmd: ["systemctl", "reboot"] },
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

    // Ejecuta YA (execDetached: sobrevive a que el comando mate Mango,
    // como shutdown/reboot/logout, y con él a Quickshell). Quien llame
    // desde una UI con animación de cierre (PowerMenu) puede esperar a que
    // termine esa animación y recién ahí llamar a esto — ver PowerMenu.qml.
    function run(action) {
        if (action) Quickshell.execDetached(action.cmd)
    }
}
