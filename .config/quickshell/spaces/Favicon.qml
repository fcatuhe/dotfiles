import QtQuick
import qs.Commons

Item {
  id: icon

  property string url: ""
  property string label: ""

  readonly property string origin: {
    var match = /^[a-z][a-z0-9+.-]*:\/\/[^\/?#]+/i.exec(url)
    return match ? match[0] : ""
  }

  width: Style.space(16)
  height: width

  Image {
    id: favicon
    anchors.fill: parent
    source: icon.origin ? icon.origin + "/favicon.ico" : ""
    sourceSize.width: width * 2
    sourceSize.height: height * 2
    asynchronous: true
    smooth: true
    visible: status === Image.Ready
  }

  Rectangle {
    anchors.fill: parent
    visible: !favicon.visible
    radius: Style.space(4)
    color: Util.alpha(Color.foreground, 0.15)

    Text {
      anchors.centerIn: parent
      text: (icon.label || "?").charAt(0).toUpperCase()
      color: Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      font.bold: true
    }
  }
}
