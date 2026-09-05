import QtQuick 2.0
import Sailfish.Silica 1.0

Item {
  id: notifications_handler

  Notice {
    id: system_notice
    duration: Notice.Long
    text: "Info"
  }

  Component.onCompleted: {
    app.signal_error.connect(error_handler)
  }

  Component.onDestruction: {
    app.signal_error.disconnect(error_handler)
  }

  function error_handler(module_id, method_id, description) {
    console.log('error_handler - source:', module_id, method_id, 'error:', description);
    system_notice.text = description
    system_notice.show()
  }
}
