import QtQuick 2.0
import Sailfish.Silica 1.0

PageHeader {
  id: fit_page_header

  Component.onCompleted: {
    _titleItem.truncationMode = TruncationMode.None
    _titleItem.fontSizeMode = Text.HorizontalFit
    _titleItem.minimumPixelSize = Theme.fontSizeExtraSmall
  }
}
