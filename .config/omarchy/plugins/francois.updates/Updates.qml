import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "francois.updates"

  readonly property var sources: [
    { name: "pacman", label: "pac" },
    { name: "aur", label: "aur" },
    { name: "mise", label: "mise" },
    { name: "firmware", label: "fw" }
  ]
  property var pending: ({})
  property bool expanded: false
  readonly property int total: sources.reduce((sum, source) => sum + (pending[source.name] || 0), 0)
  readonly property string breakdown: sources
    .filter(source => pending[source.name] > 0)
    .map(source => source.label + " " + pending[source.name])
    .join("  ")

  function refresh() {
    if (!checkProc.running) checkProc.running = true
  }

  function updateCommand() {
    if (pending.pacman || pending.aur) return "omarchy-update"
    if (pending.mise) return "omarchy-update-mise"
    if (pending.firmware) return "omarchy-update-firmware"
    return ""
  }

  function runUpdate() {
    var command = updateCommand()
    if (!command || !root.bar) return
    var script = command + "; status=$?; omarchy-shell -q francois.updates refresh; (exit $status)"
    root.bar.run("omarchy-launch-floating-terminal-with-presentation " + Util.shellQuote(script))
  }

  function parse(text) {
    var counts = {}
    text.trim().split("\n").forEach(line => {
      var fields = line.split(" ")
      counts[fields[0]] = Number(fields[1])
    })
    return counts
  }

  visible: total > 0
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  IpcHandler {
    target: "francois.updates"

    function refresh(): void {
      root.broadcast("refresh")
    }
  }

  Process {
    id: checkProc
    command: [decodeURIComponent(Qt.resolvedUrl("updates-pending").toString().replace(/^file:\/\//, ""))]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (text.trim() !== "") root.pending = root.parse(text)
    }
  }

  Timer {
    interval: 21600000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.expanded ? root.breakdown : "\uf487 " + root.total
    fontSize: Style.font.caption
    horizontalMargin: 6
    tooltipText: "Pending updates"
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.RightButton) root.runUpdate()
      else if (mouseButton === Qt.MiddleButton) root.refresh()
      else root.expanded = !root.expanded
    }
  }
}
