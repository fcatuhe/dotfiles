import QtQuick
import Quickshell.Io

Item {
  id: root

  property var pending: ({})
  property string lastError: ""
  readonly property int total: Object.values(pending).reduce((sum, count) => sum + count, 0)
  readonly property string breakdown: Object.entries(pending)
    .filter(([, count]) => count > 0)
    .map(([source, count]) => source + " " + count)
    .join("  ")

  function refresh() {
    if (!checkProc.running) checkProc.running = true
  }

  function updateCommand() {
    if (pending.pac || pending.aur) return "omarchy-update"
    if (pending.mise) return "omarchy-update-mise"
    if (pending.fw) return "omarchy-update-firmware"
    return ""
  }

  IpcHandler {
    target: "francois.updates"

    function refresh(): void {
      root.refresh()
    }
  }

  Process {
    id: checkProc
    command: [decodeURIComponent(Qt.resolvedUrl("updates-pending").toString().replace(/^file:\/\//, ""))]
    stdout: StdioCollector { id: checkStdout }
    stderr: StdioCollector { id: checkStderr }
    onExited: function(exitCode) {
      if (exitCode === 0) {
        root.pending = JSON.parse(checkStdout.text)
        root.lastError = ""
      } else {
        root.lastError = checkStderr.text.trim() || "updates-pending exited with " + exitCode
      }
    }
  }

  Timer {
    interval: 21600000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }
}
