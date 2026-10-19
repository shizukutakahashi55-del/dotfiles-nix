// PowerActions.qml — POWER

pragma Singleton
import Quickshell
import QtQuick
import "../../COMMON"


QtObject {
    id: root

    function hyprshutdownCmd(text, postCmd) {


        if (!WM.has("hyprshutdown")) return ["sh", "-c", postCmd || "true"]
        const c = ["hyprshutdown", "-t", text]
        if (postCmd) c.push("--post-cmd", postCmd)
        return c
    }
    function logoutCmd() {
        return WM.logoutCommand()
    }
    readonly property string shellPath:
        decodeURIComponent(Qt.resolvedUrl("../../shell.qml").toString().replace("file://", ""))


    readonly property var actions: [
        { id: "shutdown",  icon: OozeIcons.power, labelKey: "powerShutdown",  confirmKey: "powerConfirmShutdown",
          closesApps: true,
          cmd: root.hyprshutdownCmd("Shutting down...", "systemctl poweroff") },
        { id: "reboot",    icon: OozeIcons.reboot, labelKey: "powerReboot",    confirmKey: "powerConfirmReboot",
          closesApps: true,
          cmd: root.hyprshutdownCmd("Rebooting...", "reboot") },
        { id: "suspend",   icon: OozeIcons.suspend, labelKey: "powerSuspend",   confirmKey: "powerConfirmSuspend",
          closesApps: false,
          cmd: ["systemctl", "suspend"] },
        { id: "hibernate", icon: OozeIcons.hibernate, labelKey: "powerHibernate", confirmKey: "powerConfirmHibernate",
          closesApps: false,
          cmd: ["systemctl", "hibernate"] },
        { id: "lock",      icon: OozeIcons.lock, labelKey: "powerLock",      confirmKey: "powerConfirmLock",
          closesApps: false,
          cmd: ["sh", "-c", "quickshell ipc -p '" + root.shellPath + "' call lock lock"] },
        { id: "logout",    icon: OozeIcons.logout, labelKey: "powerLogout",    confirmKey: "powerConfirmLogout",
          closesApps: true,
          cmd: root.logoutCmd() }
    ]

    function byId(id) { return root.actions.find(a => a.id === id) ?? null }


    function run(action) {
        if (action) Quickshell.execDetached(action.cmd)
    }
}
