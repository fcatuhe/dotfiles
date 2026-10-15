import QtQuick
import qs.Commons

Text {
  id: button

  signal clicked()

  text: "\u00d7"
  color: Color.foreground
  opacity: mouse.containsMouse ? 1 : 0.6
  font.family: Style.font.family
  font.pixelSize: Style.font.title

  MouseArea {
    id: mouse
    anchors.fill: parent
    anchors.margins: -Style.space(4)
    hoverEnabled: true
    onClicked: button.clicked()
  }
}
