import QtQuick
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "francois.updates"

  readonly property var service: bar && bar.shell ? bar.shell.serviceFor(moduleName) : null
  readonly property int total: service ? service.total : 0
  readonly property string lastError: service ? service.lastError : ""
  property bool expanded: false

  function runUpdate() {
    var command = service ? service.updateCommand() : ""
    if (!command || !root.bar) return
    var script = command + "; status=$?; omarchy-shell -q francois.updates refresh; (exit $status)"
    root.bar.run("omarchy-launch-floating-terminal-with-presentation " + Util.shellQuote(script))
  }

  visible: total > 0 || lastError !== ""
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.expanded && root.service ? root.service.breakdown : "\uf487 " + (root.lastError ? "!" : root.total)
    active: root.lastError !== ""
    fontSize: Style.font.caption
    horizontalMargin: 6
    tooltipText: root.lastError || "Pending updates"
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.RightButton) root.runUpdate()
      else if (mouseButton === Qt.MiddleButton && root.service) root.service.refresh()
      else root.expanded = !root.expanded
    }
  }
}
