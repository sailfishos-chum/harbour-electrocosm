import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
  id: photo_page

  property string photo_url
  property string page_title

  FitPageHeader {
    id: header
    title: page_title
  }

  Image {
    anchors {
      top: header.bottom
      left: parent.left
      right: parent.right
      bottom: parent.bottom
    }
    fillMode: Image.PreserveAspectFit
    asynchronous: true
    source: photo_url

    BusyIndicator {
      anchors.centerIn: parent
      running: parent.status === Image.Loading
      size: BusyIndicatorSize.Large
    }
  }
}
