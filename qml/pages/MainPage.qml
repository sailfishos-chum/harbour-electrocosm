import QtQuick 2.0
import Sailfish.Silica 1.0
import MapboxMap 1.0
import QtPositioning 5.3

Page {
  id: main_page

  property real pos_latitude: 51.5074
  property real pos_longitude: -0.1278
  property real pos_accuracy: 9999

  property string mapbox_key: "CLIENT" + "ID"

  property var viewport_tl: null
  property var viewport_br: null
  property bool position_initialized: false
  property bool follow_location: false

  PositionSource {
    id: position_source
    updateInterval: 2000
    active: true

    onPositionChanged: {
      if (isNaN(position.coordinate.latitude) || isNaN(position.coordinate.longitude)) return

      pos_latitude = position.coordinate.latitude
      pos_longitude = position.coordinate.longitude
      pos_accuracy = position.horizontalAccuracy || 9999

      if (!position_initialized) {
        position_initialized = true
        map.center = QtPositioning.coordinate(pos_latitude, pos_longitude)
      }

      draw_location()
    }
  }

  Timer {
    id: chargers_update_timer
    interval: 1000
    repeat: false
    onTriggered: query_viewport_chargers()
  }

  function query_viewport_chargers() {
    viewport_tl = null
    viewport_br = null
    map.queryCoordinateForPixel(Qt.point(0, 0), "viewport_tl")
    map.queryCoordinateForPixel(Qt.point(map.width, map.height), "viewport_br")
  }

  MapboxMap {
    id: map
    anchors.fill: parent

    center: QtPositioning.coordinate(pos_latitude, pos_longitude)
    zoomLevel: 14.0
    minimumZoomLevel: 0
    maximumZoomLevel: 20
    pixelRatio: 3.0

    accessToken: mapbox_key
    cacheDatabaseMaximalSize: 1024*1024*1024
    cacheDatabasePath: "/home/defaultuser/.local/share/app.qml/electrocosm/mbgl-cache.db"

    styleUrl: "mapbox://styles/mapbox/streets-v12"

    onCenterChanged: chargers_update_timer.restart()
    onZoomLevelChanged: chargers_update_timer.restart()

    MapboxMapGestureArea {
      map: map
      activeClickedGeo: true

      onClickedGeo: {
        var nearest = find_nearest_charger(geocoordinate, degLatPerPixel, degLonPerPixel)
        if (nearest) {
          python.request_location(nearest.id)
          pageStack.push(Qt.resolvedUrl("ChargerDetailPage.qml"), {charger_id: String(nearest.id)})
        }
      }
    }

    Connections {
      target: map

      onReplyCoordinateForPixel: {
        if (tag === "viewport_tl") {
          viewport_tl = geocoordinate
        } else if (tag === "viewport_br") {
          viewport_br = geocoordinate
        }

        if (viewport_tl && viewport_br) {
          python.request_chargers_bbox(viewport_br.latitude, viewport_tl.longitude, viewport_tl.latitude, viewport_br.longitude, Math.round(map.zoomLevel))
          viewport_tl = null
          viewport_br = null
        }
      }
    }
  }

  Rectangle {
    id: position_marker_item
    anchors {
      right: parent.right
      bottom: parent.bottom
      rightMargin: Theme.paddingLarge
      bottomMargin: Theme.paddingLarge
    }

    color: "lightgrey"
    width: Theme.itemSizeSmall
    height: width
    radius: width / 2

    Rectangle {
      height: position_marker_item.height * 0.63
      width: height
      radius: width / 2
      color: "grey"
      anchors.centerIn: parent
    }

    Rectangle {
      height: position_marker_item.height * 0.3
      width: height
      radius: width / 2
      color: follow_location ? "green" : "blue"
      anchors.centerIn: parent
    }

    MouseArea {
      anchors.fill: parent
      onClicked: {
        follow_location = !follow_location
        if (follow_location) {
          map.center = QtPositioning.coordinate(pos_latitude, pos_longitude)
        }
      }
    }
  }

  Component.onCompleted: {
    create_chargers_layer()
    create_position_layer()

    app.signal_chargers_updated.connect(update_chargers)

    chargers_update_timer.restart()
  }

  Component.onDestruction: {
    app.signal_chargers_updated.disconnect(update_chargers)
  }

  function create_chargers_layer() {
    map.addSource("chargers", {
      "type": "geojson",
      "data": { "type": "FeatureCollection", "features": [] }
    })

    map.addLayer("chargers_case", {"type": "circle", "source": "chargers"})
    map.setPaintProperty("chargers_case", "circle-radius", 8)
    map.setPaintProperty("chargers_case", "circle-color", "white")

    map.addLayer("chargers_layer", {"type": "circle", "source": "chargers"})
    map.setPaintProperty("chargers_layer", "circle-radius", 6)
    map.setPaintProperty("chargers_layer", "circle-color", [
      "match", ["get", "status"],
      "AVAILABLE", "#4caf50",
      "CHARGING", "#ff9800",
      "OUTOFORDER", "#f44336",
      "#9e9e9e"
    ])
  }

  function create_position_layer() {
    map.addSource("location", {
      "type": "geojson",
      "data": {
        "type": "Feature",
        "properties": { "name": "location" },
        "geometry": { "type": "Point", "coordinates": [pos_longitude, pos_latitude] }
      }
    })

    map.addLayer("location-case", {"type": "circle", "source": "location"})
    map.setPaintProperty("location-case", "circle-radius", 10)
    map.setPaintProperty("location-case", "circle-color", "white")

    map.addLayer("location", {"type": "circle", "source": "location"})
    map.setPaintProperty("location", "circle-radius", 5)
    map.setPaintProperty("location", "circle-color", "blue")

    map.addSource("accuracy_circle", create_map_circle(pos_latitude, pos_longitude, pos_accuracy))
    map.addLayer("accuracy_layer", {"type": "fill", "source": "accuracy_circle"})
    map.setPaintProperty("accuracy_layer", "fill-color", "#87cefa")
    map.setPaintProperty("accuracy_layer", "fill-opacity", 0.25)
  }

  function draw_location() {
    map.updateSource("location", {
      "type": "geojson",
      "data": {
        "type": "Feature",
        "properties": { "name": "location" },
        "geometry": { "type": "Point", "coordinates": [pos_longitude, pos_latitude] }
      }
    })
    map.updateSource("accuracy_circle", create_map_circle(pos_latitude, pos_longitude, pos_accuracy))

    if (follow_location) {
      map.center = QtPositioning.coordinate(pos_latitude, pos_longitude)
    }
  }

  function create_map_circle(latitude, longitude, radius) {
    const angles = 20
    var coordinate_pairs = []
    for (var i = 0; i < angles; i++) {
      coordinate_pairs.push([
        longitude + (radius / (111320 * Math.cos(latitude * Math.PI / 180)) * Math.cos((i / angles) * (2 * Math.PI))),
        latitude + (radius / 110574 * Math.sin((i / angles) * (2 * Math.PI)))
      ])
    }
    coordinate_pairs.push(coordinate_pairs[0])

    return {
      "type": "geojson",
      "data": {
        "type": "FeatureCollection",
        "features": [{
          "type": "Feature",
          "geometry": { "type": "Polygon", "coordinates": [coordinate_pairs] }
        }]
      }
    }
  }

  function update_chargers(chargers) {
    var features = []

    for (var i = 0; i < chargers.length; i++) {
      var charger = chargers[i]
      features.push({
        "type": "Feature",
        "properties": {
          "id": charger.id,
          "status": charger.status,
          "speed": charger.speed,
          "operator": charger.operator
        },
        "geometry": { "type": "Point", "coordinates": [charger.lon, charger.lat] }
      })
    }

    map.updateSource("chargers", {
      "type": "geojson",
      "data": { "type": "FeatureCollection", "features": features }
    })
  }

  function find_nearest_charger(geocoordinate, degLatPerPixel, degLonPerPixel) {
    var nearest = null
    var nearest_distance_px = 24

    for (var id in app.chargers) {
      var charger = app.chargers[id]

      var dx_px = (charger.lon - geocoordinate.longitude) / degLonPerPixel
      var dy_px = (charger.lat - geocoordinate.latitude) / degLatPerPixel
      var distance_px = Math.sqrt(dx_px * dx_px + dy_px * dy_px)

      if (distance_px < nearest_distance_px) {
        nearest_distance_px = distance_px
        nearest = charger
      }
    }

    return nearest
  }
}
