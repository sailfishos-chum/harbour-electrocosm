import QtQuick 2.0
import io.thp.pyotherside 1.5

Python {
  id: python

  Component.onCompleted: {
    setHandler('error', error_handler);

    addImportPath(Qt.resolvedUrl('../../src'));

    importModule('api', function () {
      console.log('PythonHandler - api module ready');
    });
  }

  onError: {
    console.log('ERROR - unhandled error received:', traceback);
    app.signal_error('python', 'call', friendly_error_message(traceback));
  }

  onReceived: {
    console.log('ERROR - unhandled data received:', data);
  }

  function error_handler(module_id, method_id, description) {
    console.log('Module ERROR - source:', module_id, method_id, 'error:', description);
    app.signal_error(module_id, method_id, description);
  }

  function friendly_error_message(traceback) {
    var lines = traceback.trim().split('\n');
    var last_line = lines[lines.length - 1].trim();

    if (/timed out|Timeout|ConnectionError|URLError|HTTPError|gaierror/.test(last_line)) {
      return "Couldn't reach Electroverse - check your connection and try again.";
    }

    return last_line || "Something went wrong.";
  }

  function request_chargers_bbox(min_lat, min_lon, max_lat, max_lon, zoom) {
    call('api.get_chargers_bbox', [min_lat, min_lon, max_lat, max_lon, zoom], function (chargers) {
      var by_id = {};
      for (var i = 0; i < chargers.length; i++) {
        by_id[chargers[i].id] = chargers[i];
      }
      app.chargers = by_id;
      app.signal_chargers_updated(chargers);
    });
  }

  function request_location(pk) {
    call('api.fetch_location', [pk], function (location) {
      app.selected_location = location;
      app.signal_location_ready(location);
    });
  }

  function request_photos(pk) {
    call('api.fetch_photos', [pk], function (photos) {
      app.signal_photos_ready(pk, photos);
    });
  }
}
