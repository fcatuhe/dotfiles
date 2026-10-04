import QtQuick
import Quickshell.Hyprland
import Quickshell.Io
import qs.Ui
import qs.Commons
import "KeyboardLayoutModel.js" as KeyboardLayoutModel

BarWidget {
  id: root
  moduleName: "omarchy.keyboard-layout"

  property var keyboard: null
  property var states: ({})
  property var layoutBriefs: ({})
  property bool refreshPending: false

  readonly property string keymap: keyboard ? keyboard.active_keymap : ""
  readonly property int layoutCount: keyboard ? keyboard.layout.split(",").length : 0
  readonly property bool digitsLocked: !!keyboard && !keyboard.numLock && keymap.startsWith("frenchy-clavier")

  function refresh() {
    refreshPending = queryProc.running
    if (!refreshPending) queryProc.running = true
  }

  function cycleLayout() {
    if (keyboard && bar) bar.run("hyprctl switchxkblayout all " + (keyboard.active_layout_index + 1) % layoutCount)
  }

  Component.onCompleted: {
    briefsProc.running = true
    refresh()
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      // INFO: fc 11sep26 the digit lock raises no Hyprland event, so bindings.lua has the key raise this one
      if (["activelayout", "configreloaded"].includes(event.name) || (event.name === "custom" && event.data === "digitlock")) root.refresh()
    }
  }

  Process {
    id: queryProc
    command: ["hyprctl", "-j", "devices"]
    onRunningChanged: if (!running && root.refreshPending) root.refresh()
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        const keyboards = JSON.parse(text).keyboards
        root.keyboard = KeyboardLayoutModel.follow(keyboards, root.states, root.keyboard && root.keyboard.name) || null
        root.states = KeyboardLayoutModel.states(keyboards)
      }
    }
  }

  Process {
    id: briefsProc
    command: ["xkbcli", "list", "--load-exotic"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.layoutBriefs = KeyboardLayoutModel.layoutBriefs(text)
    }
  }

  visible: keymap !== "" && layoutCount > 1
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: KeyboardLayoutModel.shortLabel(root.keymap, root.layoutBriefs) + (root.digitsLocked ? "#" : "")
    fontSize: Style.font.caption
    horizontalMargin: 6
    tooltipText: root.digitsLocked ? root.keymap + " + verrou des chiffres" : root.keymap
    onPressed: function() { root.cycleLayout() }
  }
}
