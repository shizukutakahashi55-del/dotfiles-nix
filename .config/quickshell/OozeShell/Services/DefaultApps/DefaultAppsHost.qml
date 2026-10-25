// DefaultAppsHost

import Quickshell
import Quickshell.Io
import QtQuick
import "../Lang"
import "../Notify"

Scope {
  id: host

  // ─── IPC ───

  IpcHandler {
    target: "apps"

    function open(role: string): string { return DefaultApps.run(role, [], false) }
    function openWith(role: string, arg: string): string { return DefaultApps.run(role, [arg], false) }
    function any(arg: string): string { return DefaultApps.openAny(arg) }
    function url(address: string): string { return DefaultApps.openUrl(address, false) }
    function urlPrivate(address: string): string { return DefaultApps.openUrl(address, true) }
    function file(path: string): string { return DefaultApps.openFile(path) }
    function dir(path: string): string { return DefaultApps.openDir(path) }
    function term(command: string): string { return DefaultApps.runInTerminal(command) }

    function set(role: string, app: string): string { return DefaultApps.setChoice(role, app) ? "ok" : "invalid" }
    function custom(role: string, command: string): string { return DefaultApps.setCustom(role, command) ? "ok" : "invalid" }
    function get(role: string): string { return JSON.stringify(DefaultApps.describe(role)) }
    function list(): string { return DefaultApps.roleIds().join(", ") }
    function state(): string { return JSON.stringify(DefaultApps.roleIds().map(r => DefaultApps.describe(r))) }
    function sysget(role: string): string {
      DefaultApps.refreshMime(role)
      const st = DefaultApps.mimeState[role] ?? {}
      return JSON.stringify({ role: role, id: st.id ?? "", pending: st.pending ?? false, error: st.error ?? "" })
    }
    function sysset(role: string, desktopId: string): string {
      return DefaultApps.setSystemDefault(role, desktopId) ? "ok" : "invalid"
    }
  }

  Connections {
    target: DefaultApps
    function onFailed(role) {
      NotificationsBackend.pushLocal("OozeShell", Translations.t("daFailed").replace("%1", role))
    }
  }
}
