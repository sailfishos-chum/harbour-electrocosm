import json
import urllib.request
import mvt
import cache

TILE_URL = "https://electroverse.com/api/proxy/rest/locations/tiles/elastic/%d/%d/%d"
GRAPHQL_URL = "https://electroverse.com/api/proxy/graphql"

HEADERS = {
  'Referer': 'https://electroverse.com/map',
  'Origin': 'https://electroverse.com',
  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36',
}

# Tiles and location detail carry live charger/EVSE status (can change within minutes),
# unlike photos/operator/pricing which barely change - so they get a much shorter TTL
# than cache.DEFAULT_TTL_SECONDS.
STATUS_TTL_SECONDS = 2 * 60

LOCATION_QUERY = """
query chargingLocation($pk: String!) {
  chargingLocation(pk: $pk) {
    pk chargingLocationPk externalId name address city postalCode country
    coordinates
    isEjnLocation facilities locationFacilities
    alerts { type content }
    operator { pk name logoDark hasPartneredLocations supportPhoneNumber supportWebsite supportEmail isGreenEnergy }
    indicativePrice { isComplexTariff maxIndicativePrice minIndicativePrice currency { symbol decimalDigits minorUnitConversion } }
    openingHours { twentyFourSeven regularHours { weekday periodBegin periodEnd } }
    capabilities {
      __typename
      ... on EJNApp { name }
      ... on OperatorApp { androidAppUrl iosAppUrl name }
      ... on QRCode { name }
      ... on RFID { name }
      ... on TeslaCar { name }
      ... on Card { name }
      ... on Contactless { name }
      ... on Free { name }
      ... on Web { name site }
      ... on PlugAndCharge { name }
    }
    evses {
      totalCount
      edges { node {
        pk physicalReference supportsInAppCharging status
        connectors { edges { node {
          pk isChargingFree kilowatts speed
          standard { pk humanName name }
          priceComponents {
            __typename
            ... on ConsumptionRate { currencyDetails { symbol decimalDigits minorUnitConversion } unitAmount perUnit }
            ... on TimeRate { currencyDetails { symbol decimalDigits minorUnitConversion } unitAmount perUnit }
            ... on ConnectionFee { currencyDetails { symbol decimalDigits minorUnitConversion } unitAmount }
          }
          pricing { discount { variety } }
        } } }
      } }
    }
  }
}
"""

PHOTOS_QUERY = """
query locationPhotos($chargingLocation: String!) {
  locationPhotos(chargingLocation: $chargingLocation) {
    pk
    photo
    updatedAt
    photoType
  }
}
"""


def fetch_tile(z, x, y):
  key = '%d_%d_%d.pbf' % (z, x, y)
  cached = cache.get_bytes(key, STATUS_TTL_SECONDS)
  if cached is not None:
    return cached

  url = TILE_URL % (z, x, y)
  req = urllib.request.Request(url, headers=HEADERS)
  with urllib.request.urlopen(req, timeout=10) as resp:
    data = resp.read()

  cache.set_bytes(key, data)
  return data

MAX_TILES_PER_REQUEST = 16


def _chargers_from_tile(zoom, x, y):
  data = fetch_tile(zoom, x, y)
  layers = mvt.decode_tile(data)

  chargers = []
  for layer in layers:
    if layer.get('name') != 'hits':
      continue

    extent = layer.get('extent', 4096)
    for feature in layer['features']:
      props = feature['properties']
      for path in feature['geometry']:
        for px, py in path:
          lon_f, lat_f = mvt.tile_to_lonlat(zoom, x, y, extent, px, py)
          chargers.append({
            'id': props.get('_id'),
            'lat': lat_f,
            'lon': lon_f,
            'status': props.get('current_status'),
            'speed': props.get('max_speed'),
            'operator': props.get('display_operator'),
          })

  return chargers

def get_chargers(lat, lon, zoom):
  x, y = mvt.lonlat_to_tile(lat, lon, zoom)
  return _chargers_from_tile(zoom, x, y)

def get_chargers_bbox(min_lat, min_lon, max_lat, max_lon, zoom):
  x_min, y_min = mvt.lonlat_to_tile(max_lat, min_lon, zoom)
  x_max, y_max = mvt.lonlat_to_tile(min_lat, max_lon, zoom)

  tile_count = (x_max - x_min + 1) * (y_max - y_min + 1)
  if tile_count > MAX_TILES_PER_REQUEST:
    return []

  by_id = {}
  for x in range(x_min, x_max + 1):
    for y in range(y_min, y_max + 1):
      for charger in _chargers_from_tile(zoom, x, y):
        by_id[charger['id']] = charger

  return list(by_id.values())

def graphql(operation_name, query, variables):
  body = json.dumps({
    'operationName': operation_name,
    'query': query,
    'variables': variables,
  }).encode('utf-8')

  headers = dict(HEADERS)
  headers['Content-Type'] = 'application/json'

  req = urllib.request.Request(GRAPHQL_URL, data=body, headers=headers, method='POST')
  with urllib.request.urlopen(req, timeout=10) as resp:
    result = json.loads(resp.read())

  if 'errors' in result:
    raise RuntimeError(result['errors'])

  return result['data']

def fetch_location(pk):
  key = 'location_%s' % pk
  cached = cache.get_json(key, STATUS_TTL_SECONDS)
  if cached is not None:
    return cached

  data = graphql('chargingLocation', LOCATION_QUERY, {'pk': str(pk)})['chargingLocation']
  cache.set_json(key, data)
  return data

def fetch_photos(pk):
  key = 'photos_%s' % pk
  photos = cache.get_json(key)
  if photos is None:
    photos = graphql('locationPhotos', PHOTOS_QUERY, {'chargingLocation': str(pk)})['locationPhotos']
    cache.set_json(key, photos)

  return cache_photo_files(photos)

def cache_photo_files(photos):
  for photo in photos:
    url = photo.get('photo')
    if not url:
      continue

    filename = url.rsplit('/', 1)[-1]
    local_path = cache.get_image_path(filename)

    if local_path is None:
      try:
        req = urllib.request.Request(url, headers=HEADERS)
        with urllib.request.urlopen(req, timeout=10) as resp:
          local_path = cache.set_image(filename, resp.read())
      except Exception as err:
        continue

    photo['photo'] = 'file://' + local_path

  return photos
