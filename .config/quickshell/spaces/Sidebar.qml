import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons

PanelWindow {
  id: sidebar

  required property var spaces

  readonly property var monitor: Hyprland.monitorFor(screen)
  readonly property int workspace: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : 0
  readonly property var space: spaces.spaceFor(workspace)
  readonly property var tabs: spaces.tabsFor(space)
  readonly property var pinnedTabs: tabs.filter(function (tab) { return tab.pinned })
  readonly property var openTabs: tabs.filter(function (tab) { return !tab.pinned })

  visible: space !== null
  anchors { top: true; bottom: true; left: true }
  implicitWidth: Style.space(220)
  exclusionMode: ExclusionMode.Auto
  color: Color.background
  WlrLayershell.namespace: "spaces"
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

  function activatePane(tab, pane) {
    if (pane.open) spaces.focusWindow(pane.address)
    else spaces.openTab(space, tab)
  }

  component SpaceTab: TabRow {
    width: column.width
    onActivated: sidebar.spaces.openTab(sidebar.space, tab)
    onCloseRequested: sidebar.spaces.closeTab(tab)
    onPinToggled: sidebar.spaces.togglePin(sidebar.space, tab)
    onPaneActivated: function (pane) { sidebar.activatePane(tab, pane) }
    onPaneCloseRequested: function (pane) { sidebar.spaces.closeWindow(pane.address) }
  }

  Text {
    id: header
    anchors { top: parent.top; left: parent.left; right: parent.right; margins: Style.space(12) }
    text: sidebar.space ? sidebar.space.name : ""
    textFormat: Text.PlainText
    elide: Text.ElideRight
    color: Color.foreground
    font.family: Style.font.family
    font.pixelSize: Style.font.heading
    font.bold: true
  }

  Text {
    id: errorLine
    anchors { top: header.bottom; left: parent.left; right: parent.right; margins: Style.space(12) }
    visible: sidebar.spaces.configError !== ""
    height: visible ? implicitHeight : 0
    text: "spaces.json: " + sidebar.spaces.configError
    wrapMode: Text.Wrap
    color: Color.urgent
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
  }

  Flickable {
    anchors { top: errorLine.bottom; bottom: switcher.top; left: parent.left; right: parent.right; margins: Style.space(6) }
    contentHeight: column.implicitHeight
    clip: true

    Column {
      id: column
      width: parent.width
      spacing: Style.space(2)

      Repeater {
        model: sidebar.pinnedTabs

        SpaceTab {
          required property var modelData
          tab: modelData
        }
      }

      Item {
        width: column.width
        height: Style.space(13)

        Rectangle {
          anchors.centerIn: parent
          width: parent.width - Style.space(16)
          height: Math.max(1, Style.space(1))
          color: Util.alpha(Color.foreground, 0.15)
        }
      }

      Rectangle {
        width: column.width
        height: Style.space(30)
        radius: Math.max(Style.cornerRadius, Style.space(6))
        color: newTabHover.hovered ? Style.hoverFill : "transparent"

        HoverHandler { id: newTabHover }

        MouseArea {
          anchors.fill: parent
          onClicked: sidebar.spaces.openPrompt("new-tab")
        }

        Text {
          anchors { left: parent.left; leftMargin: Style.space(8); verticalCenter: parent.verticalCenter }
          text: "+  New Tab"
          color: Color.foreground
          opacity: 0.6
          font.family: Style.font.family
          font.pixelSize: Style.font.body
        }
      }

      Repeater {
        model: sidebar.openTabs

        SpaceTab {
          required property var modelData
          tab: modelData
        }
      }
    }
  }

  Row {
    id: switcher
    anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: Style.space(10) }
    spacing: Style.space(6)

    Repeater {
      model: sidebar.spaces.config.spaces.filter(function (space) { return space.on })

      Rectangle {
        required property var modelData
        readonly property bool current: sidebar.space !== null && modelData.workspace === sidebar.space.workspace

        width: Style.space(22)
        height: width
        radius: Math.max(Style.cornerRadius, Style.space(5))
        color: current ? Style.selectedFill : (dotHover.hovered ? Style.hoverFill : "transparent")

        HoverHandler { id: dotHover }

        Text {
          anchors.centerIn: parent
          text: modelData.name.charAt(0).toUpperCase()
          color: Color.foreground
          opacity: parent.current ? 1 : 0.6
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          font.bold: parent.current
        }

        MouseArea {
          anchors.fill: parent
          onClicked: sidebar.spaces.focusWorkspace(modelData.workspace)
        }
      }
    }
  }
}
