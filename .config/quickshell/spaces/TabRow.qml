import QtQuick
import qs.Commons

Column {
  id: row

  required property var tab

  signal activated()
  signal closeRequested()
  signal pinToggled()
  signal paneActivated(var pane)
  signal paneCloseRequested(var pane)

  readonly property var iconPane: tab.panes.find(function (pane) { return pane.url !== "" }) || null
  readonly property bool showPanes: tab.panes.length > 1

  spacing: Style.space(1)

  Rectangle {
    width: row.width
    height: Style.space(30)
    radius: Math.max(Style.cornerRadius, Style.space(6))
    color: row.tab.active ? Style.selectedFill : (hover.hovered ? Style.hoverFill : "transparent")

    HoverHandler { id: hover }

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
      onClicked: function (event) {
        if (event.button === Qt.LeftButton) row.activated()
        else if (event.button === Qt.MiddleButton) row.closeRequested()
        else row.pinToggled()
      }
    }

    Favicon {
      id: icon
      anchors { left: parent.left; leftMargin: Style.space(8); verticalCenter: parent.verticalCenter }
      url: row.iconPane ? row.iconPane.url : ""
      label: row.tab.name
      opacity: row.tab.open || row.tab.active ? 1 : 0.5
    }

    Text {
      anchors { left: icon.right; leftMargin: Style.space(8); right: closeButton.visible ? closeButton.left : parent.right; rightMargin: Style.space(8); verticalCenter: parent.verticalCenter }
      text: row.tab.name
      textFormat: Text.PlainText
      elide: Text.ElideRight
      maximumLineCount: 1
      color: Color.foreground
      opacity: row.tab.open || row.tab.active ? 1 : 0.5
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      font.bold: row.tab.active
    }

    CloseButton {
      id: closeButton
      anchors { right: parent.right; rightMargin: Style.space(8); verticalCenter: parent.verticalCenter }
      visible: row.tab.open && hover.hovered
      onClicked: row.closeRequested()
    }
  }

  Repeater {
    model: row.showPanes ? row.tab.panes : []

    Rectangle {
      required property var modelData

      width: row.width
      height: Style.space(24)
      radius: Math.max(Style.cornerRadius, Style.space(5))
      color: modelData.active ? Util.alpha(Color.foreground, 0.08) : (paneHover.hovered ? Style.hoverFill : "transparent")

      HoverHandler { id: paneHover }

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: function (event) {
          if (event.button === Qt.LeftButton) row.paneActivated(modelData)
          else if (modelData.open) row.paneCloseRequested(modelData)
        }
      }

      Rectangle {
        id: guide
        anchors { left: parent.left; leftMargin: Style.space(15); top: parent.top; bottom: parent.bottom }
        width: Math.max(1, Style.space(1))
        color: Util.alpha(Color.foreground, modelData.active ? 0.6 : 0.15)
      }

      Text {
        anchors { left: guide.right; leftMargin: Style.space(10); right: paneClose.visible ? paneClose.left : parent.right; rightMargin: Style.space(8); verticalCenter: parent.verticalCenter }
        text: modelData.title
        textFormat: Text.PlainText
        elide: Text.ElideRight
        maximumLineCount: 1
        color: Color.foreground
        opacity: modelData.open ? 0.8 : 0.45
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
      }

      CloseButton {
        id: paneClose
        anchors { right: parent.right; rightMargin: Style.space(8); verticalCenter: parent.verticalCenter }
        visible: modelData.open && paneHover.hovered
        onClicked: row.paneCloseRequested(modelData)
      }
    }
  }
}
