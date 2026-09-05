import QtQuick 2.0
import Sailfish.Silica 1.0
import "pages"

ApplicationWindow {
  id: app

  property string appVersion: "0.1.0"

  signal signal_error(string module_id, string method_id, string description)
  signal signal_chargers_updated(var chargers)
  signal signal_location_ready(var location)
  signal signal_photos_ready(var pk, var photos)

  property var chargers: ({})
  property var selected_location: null

  PythonHandler {
    id: python
  }

  NotificationsHandler {
    id: notifications_handler
  }

  initialPage: Component {
    id: initial_page

    MainPage {
      id: main_page
    }
  }

  cover: Component {
    id: cover_component

    CoverPage {
      id: cover_page
    }
  }

  Component.onCompleted: {
    Qt.application.name = "harbour-electrocosm";
    Qt.application.organization = "app.qml";
  }
}
