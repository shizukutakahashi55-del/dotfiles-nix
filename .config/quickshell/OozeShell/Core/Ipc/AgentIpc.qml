import Quickshell
import Quickshell.Io
import QtQuick
import "../../Services/Agents"

Item {
  id: self
  property var shell
  IpcHandler {
    target: "agent"
    function toggle(): void { AgentsService.toggleBubble(self.shell.resolveMonitor()) }
    function open(): void { AgentsService.openBubble(self.shell.resolveMonitor()) }
    function close(): void { AgentsService.closeBubble() }
    function ask(question: string): void {
      AgentsService.openBubble(self.shell.resolveMonitor())
      AgentsService.ask(question)
    }
    function copy(): void { AgentsService.copyLast() }
    function newchat(): void { AgentsService.newChat() }
    function unlock(): void { AgentsService.unlock() }
    function lock(): void { AgentsService.lock() }
  }
}
