import QtQuick 2.0
import Sailfish.Silica 1.0

CoverBackground {
  id: cover

  Image {
    anchors.centerIn: parent
    width: parent.width
    height: parent.width
    sourceSize.width: width
    sourceSize.height: height

    opacity: 0.4
    source: "../../img/electrocosm.svg"
  }
}
