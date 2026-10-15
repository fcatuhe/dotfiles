import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons

PanelWindow {
  id: prompt

  required property var spaces

  property string mode: ""
  property string target: ""

  function open(nextMode, text, address) {
    mode = nextMode
    target = address
    input.text = text
    input.selectAll()
    input.forceActiveFocus()
  }

  function close() {
    mode = ""
    target = ""
  }

  function submit() {
    var text = input.text
    var submitted = { mode: mode, target: target }
    close()
    spaces.submitPrompt(submitted.mode, text, submitted.target)
  }

  visible: mode !== ""
  anchors { top: true; bottom: true; left: true; right: true }
  exclusionMode: ExclusionMode.Ignore
  color: Util.alpha(Color.background, 0.4)
  WlrLayershell.namespace: "spaces-prompt"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

  MouseArea {
    anchors.fill: parent
    onClicked: prompt.close()
  }

  Rectangle {
    id: box
    anchors.horizontalCenter: parent.horizontalCenter
    y: Math.round(parent.height * 0.25)
    width: Math.min(parent.width - Style.space(80), Style.space(620))
    height: column.implicitHeight + Style.space(28)
    radius: Math.max(Style.cornerRadius, Style.space(10))
    color: Color.popups.background
    border.color: Color.popups.border
    border.width: Math.max(1, Style.space(2))

    MouseArea {
      anchors.fill: parent
    }

    Column {
      id: column
      anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: Style.space(18) }
      spacing: Style.space(8)

      Text {
        text: prompt.mode === "edit-url" ? "Open in this pane" : "New Tab"
        color: Color.popups.text
        opacity: 0.6
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
      }

      TextInput {
        id: input
        width: parent.width
        clip: true
        color: Color.popups.text
        selectionColor: Style.selectionFill
        font.family: Style.font.family
        font.pixelSize: Style.font.heading
        Keys.onReturnPressed: prompt.submit()
        Keys.onEnterPressed: prompt.submit()
        Keys.onEscapePressed: prompt.close()

        Text {
          anchors.fill: parent
          visible: input.text === ""
          text: "Search or enter a URL, or a path for a terminal"
          color: Color.popups.text
          opacity: 0.35
          font: input.font
          elide: Text.ElideRight
        }
      }
    }
  }
}
