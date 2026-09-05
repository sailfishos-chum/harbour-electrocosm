import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
  id: charger_detail_page

  property string charger_id
  property var location: null
  property var photos: []

  SilicaFlickable {
    anchors.fill: parent
    contentHeight: column.height

    VerticalScrollDecorator {}

    Column {
      id: column
      width: parent.width

      FitPageHeader {
        title: location ? (location.name || location.address || "Charger") : "Loading…"
      }

      BusyIndicator {
        anchors.horizontalCenter: parent.horizontalCenter
        running: !location
        visible: !location
        size: BusyIndicatorSize.Large
      }

      Column {
        width: parent.width
        visible: !!location

        SilicaFlickable {
          visible: photos.length > 0
          width: parent.width
          height: photos.length > 0 ? Theme.itemSizeExtraLarge * 2 : 0
          contentWidth: photos_row.width
          clip: true

          Row {
            id: photos_row
            spacing: Theme.paddingSmall
            height: parent.height

            Repeater {
              model: photos
              delegate: Image {
                height: parent.height
                width: height
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                source: modelData.photo

                MouseArea {
                  anchors.fill: parent
                  onClicked: pageStack.push(Qt.resolvedUrl("PhotoPage.qml"), {
                    photo_url: modelData.photo,
                    page_title: location ? (location.name || location.address || "Charger") : ""
                  })
                }
              }
            }
          }
        }

        Repeater {
          model: location ? (location.alerts || []) : []
          delegate: Label {
            x: Theme.horizontalPageMargin
            width: parent.width - 2 * Theme.horizontalPageMargin
            wrapMode: Text.WordWrap
            color: Theme.errorColor
            font.pixelSize: Theme.fontSizeExtraSmall
            text: modelData.content
          }
        }

        SectionHeader {
          text: "Overview"
        }

        DetailItem {
          label: "Address"
          value: location ? format_address(location) : ""
          visible: !!value
        }

        DetailItem {
          label: "Operator"
          value: location && location.operator ? location.operator.name : ""
          visible: !!value
        }

        DetailItem {
          label: "Green Energy"
          value: location && location.operator && location.operator.isGreenEnergy ? "Yes" : "No"
        }

        DetailItem {
          label: "Support Phone"
          value: location && location.operator ? location.operator.supportPhoneNumber : ""
          visible: !!value
        }

        DetailItem {
          label: "Support Website"
          value: location && location.operator ? location.operator.supportWebsite : ""
          visible: !!value
        }

        DetailItem {
          label: "Hours"
          value: format_hours(location)
          visible: !!value
        }

        DetailItem {
          label: "Indicative Price"
          value: format_indicative_price(location)
          visible: !!value
        }

        SectionHeader {
          text: "Capabilities"
          visible: location && location.capabilities && location.capabilities.length > 0
        }

        Label {
          visible: location && location.capabilities && location.capabilities.length > 0
          x: Theme.horizontalPageMargin
          width: parent.width - 2 * Theme.horizontalPageMargin
          wrapMode: Text.WordWrap
          color: Theme.secondaryColor
          font.pixelSize: Theme.fontSizeExtraSmall
          text: location ? format_capabilities(location.capabilities) : ""
        }

        SectionHeader {
          text: "Connectors"
        }

        Repeater {
          model: location ? get_connectors(location) : []
          delegate: Column {
            width: parent.width

            Row {
              x: Theme.horizontalPageMargin
              width: parent.width - 2 * Theme.horizontalPageMargin
              spacing: Theme.paddingMedium

              Image {
                width: Theme.iconSizeMedium
                height: Theme.iconSizeMedium
                anchors.verticalCenter: parent.verticalCenter
                visible: !!modelData.icon
                source: modelData.icon
              }

              Column {
                width: parent.width - (modelData.icon ? (Theme.iconSizeMedium + Theme.paddingMedium) : 0)

                Label {
                  width: parent.width
                  truncationMode: TruncationMode.Fade
                  font.pixelSize: Theme.fontSizeMedium
                  text: modelData.standard + " · " + modelData.speed
                }
                DetailItem {
                  label: "Status"
                  value: modelData.evse_status
                  leftMargin: 0
                  rightMargin: 0
                }
                DetailItem {
                  label: "Power"
                  value: modelData.kilowatts + " kW"
                  leftMargin: 0
                  rightMargin: 0
                }
                DetailItem {
                  label: "Price"
                  value: modelData.price_text
                  visible: !!value
                  leftMargin: 0
                  rightMargin: 0
                }
              }
            }

            Separator {
              width: parent.width
              color: Theme.secondaryColor
            }
          }
        }
      }

      Item {
        width: 1
        height: Theme.paddingLarge
      }
    }
  }

  Component.onCompleted: {
    app.signal_location_ready.connect(handle_location_ready)
    app.signal_photos_ready.connect(handle_photos_ready)
    python.request_photos(charger_id)
  }

  Component.onDestruction: {
    app.signal_location_ready.disconnect(handle_location_ready)
    app.signal_photos_ready.disconnect(handle_photos_ready)
  }

  function handle_location_ready(loc) {
    if (loc && String(loc.chargingLocationPk) === String(charger_id)) {
      location = loc
    }
  }

  function handle_photos_ready(pk, loaded_photos) {
    if (String(pk) === String(charger_id)) {
      photos = loaded_photos
    }
  }

  function format_hours(loc) {
    if (!loc || !loc.openingHours) return ""
    if (loc.openingHours.twentyFourSeven) return "Open 24/7"
    if (!loc.openingHours.regularHours) return ""

    var parts = []
    for (var i = 0; i < loc.openingHours.regularHours.length; i++) {
      var period = loc.openingHours.regularHours[i]
      parts.push(period.weekday + ": " + period.periodBegin + "-" + period.periodEnd)
    }
    return parts.join("\n")
  }

  function format_indicative_price(loc) {
    if (!loc || !loc.indicativePrice) return ""
    var price = loc.indicativePrice
    if (!price.minIndicativePrice && !price.maxIndicativePrice) return ""

    var symbol = price.currency ? price.currency.symbol : ""
    var min_price = (price.minIndicativePrice / (price.currency ? price.currency.minorUnitConversion : 100)).toFixed(2)
    if (price.maxIndicativePrice !== price.minIndicativePrice) {
      var max_price = (price.maxIndicativePrice / (price.currency ? price.currency.minorUnitConversion : 100)).toFixed(2)
      return symbol + min_price + " - " + symbol + max_price + "/kWh"
    }
    return symbol + min_price + "/kWh"
  }

  function format_address(loc) {
    var parts = [loc.address, loc.city, loc.postalCode, loc.country]
    var clean = []
    for (var i = 0; i < parts.length; i++) {
      var part = parts[i]
      if (part && part.trim() !== "" && part.trim().toLowerCase() !== "unknown") {
        clean.push(part)
      }
    }
    return clean.join(", ")
  }

  function format_capabilities(capabilities) {
    var names = []
    for (var i = 0; i < capabilities.length; i++) {
      if (capabilities[i]) {
        names.push(capability_label(capabilities[i].__typename))
      }
    }
    return names.join(", ")
  }

  function capability_label(typename) {
    var labels = {
      "Card": "Electrocard",
      "Contactless": "Contactless",
      "EJNApp": "Electroverse App",
      "OperatorApp": "Operator App",
      "QRCode": "QR Code",
      "RFID": "RFID Card",
      "TeslaCar": "Tesla Vehicle",
      "Free": "Free",
      "Web": "Website",
      "PlugAndCharge": "Plug & Charge"
    }
    return labels[typename] || typename
  }

  function format_price_components(price_components) {
    if (!price_components) return ""

    var parts = []
    for (var i = 0; i < price_components.length; i++) {
      var component = price_components[i]
      var symbol = component.currencyDetails ? component.currencyDetails.symbol : ""
      var conversion = component.currencyDetails ? component.currencyDetails.minorUnitConversion : 100

      if ((component.__typename === "ConsumptionRate" || component.__typename === "TimeRate") && component.unitAmount > 0) {
        parts.push(symbol + (component.unitAmount / conversion).toFixed(2) + "/" + component.perUnit)
      } else if (component.__typename === "ConnectionFee" && component.unitAmount > 0) {
        parts.push(symbol + (component.unitAmount / conversion).toFixed(2) + " connection fee")
      }
    }
    return parts.join(", ")
  }

  function get_connectors(loc) {
    var connectors = []
    if (!loc || !loc.evses || !loc.evses.edges) return connectors

    for (var i = 0; i < loc.evses.edges.length; i++) {
      var evse = loc.evses.edges[i].node
      if (!evse.connectors || !evse.connectors.edges) continue

      for (var j = 0; j < evse.connectors.edges.length; j++) {
        var connector = evse.connectors.edges[j].node
        connectors.push({
          "evse_status": evse.status,
          "standard": connector.standard ? connector.standard.humanName : "Unknown",
          "icon": connector_icon(connector.standard ? connector.standard.name : ""),
          "speed": connector.speed,
          "kilowatts": connector.kilowatts,
          "price_text": connector.isChargingFree ? "Free" : format_price_components(connector.priceComponents)
        })
      }
    }
    return connectors
  }

  function connector_icon(standard_code) {
    var icons = {
      "IEC_62196_T1": "type1",
      "IEC_62196_T1_COMBO": "ccs",
      "IEC_62196_T2": "type2",
      "IEC_62196_T2_COMBO": "ccs",
      "CHADEMO": "chademo",
      "TESLA": "nacs",
      "NACS": "nacs"
    }
    var name = icons[standard_code]
    return name ? Qt.resolvedUrl("../../img/connectors/plug_" + name + ".svg") : ""
  }
}
