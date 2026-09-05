import s_protobuf
import math

UINT = 'uint'

CMD_MOVETO = 1
CMD_LINETO = 2
CMD_CLOSEPATH = 7


def get_value(data_map, field_number):
  try:
    return data_map[field_number]
  except Exception as err:
    return None

def get_repeated(data_map, field_number):
  values = []
  if field_number in data_map:
    values.append(data_map[field_number])
  for entry in data_map.get('repeated', []):
    if field_number in entry:
      values.append(entry[field_number])
  return values

def setparam(record, field_name, data_map, field_number, value_type = bytes):
  try:
    if value_type == int:
      record[field_name] = int(data_map['i%d' % field_number])
    elif value_type == UINT:
      record[field_name] = int(data_map[field_number])
    elif value_type == float:
      record[field_name] = float(data_map['f%d' % field_number])
    elif value_type == bool:
      record[field_name] = data_map[field_number] > 0
    elif value_type == str:
      record[field_name] = data_map[field_number].decode('utf-8', 'replace')
    else:
      record[field_name] = data_map[field_number]
    return True
  except Exception as err:
    return False

def zigzag_decode(value):
  return (value >> 1) ^ -(value & 1)

def decode_packed_varints(data):
  values = []
  index = 0
  while index < len(data):
    value, blen, _ = s_protobuf.decode_varint(data[index:])
    values.append(value)
    index += blen
  return values

def decode_property_value(data):
  pb = s_protobuf.decode_protobuf(data)

  if 1 in pb:
    return pb[1].decode('utf-8', 'replace')
  if 2 in pb:
    return pb.get('f2')
  if 3 in pb:
    return pb.get('f3')
  if 4 in pb:
    return pb.get('i4', pb[4])
  if 5 in pb:
    return pb[5]
  if 6 in pb:
    return zigzag_decode(pb[6])
  if 7 in pb:
    return pb[7] > 0

  return None

def decode_geometry(commands):
  paths = []
  path = []
  x = 0
  y = 0
  index = 0

  while index < len(commands):
    cmd_int = commands[index]
    index += 1
    cmd_id = cmd_int & 0x7
    count = cmd_int >> 3

    if cmd_id == CMD_CLOSEPATH:
      if path:
        paths.append(path)
        path = []
      continue

    for _ in range(count):
      dx = zigzag_decode(commands[index])
      dy = zigzag_decode(commands[index + 1])
      index += 2
      x += dx
      y += dy

      if cmd_id == CMD_MOVETO:
        if path:
          paths.append(path)
        path = [(x, y)]
      else:
        path.append((x, y))

  if path:
    paths.append(path)

  return paths

def decode_feature(data, keys, values):
  pb = s_protobuf.decode_protobuf(data)

  feature = {}
  setparam(feature, 'id', pb, 1, UINT)
  feature['type'] = pb.get(3, 0)

  tag_ids = decode_packed_varints(pb[2]) if 2 in pb else []
  properties = {}
  for i in range(0, len(tag_ids) - 1, 2):
    key = keys[tag_ids[i]]
    value = values[tag_ids[i + 1]]
    properties[key] = value
  feature['properties'] = properties

  feature['geometry'] = decode_geometry(decode_packed_varints(pb[4])) if 4 in pb else []

  return feature

def decode_layer(data):
  pb = s_protobuf.decode_protobuf(data)

  layer = {}
  setparam(layer, 'name', pb, 1, str)
  if not setparam(layer, 'extent', pb, 5, UINT):
    layer['extent'] = 4096

  keys = [k.decode('utf-8', 'replace') for k in get_repeated(pb, 3)]
  values = [decode_property_value(v) for v in get_repeated(pb, 4)]

  layer['features'] = [decode_feature(f, keys, values) for f in get_repeated(pb, 2)]

  return layer

def decode_tile(data):
  pb = s_protobuf.decode_protobuf(data)
  return [decode_layer(l) for l in get_repeated(pb, 3)]

def tile_to_lonlat(tile_z, tile_x, tile_y, extent, px, py):
  n = 2 ** tile_z
  fx = tile_x + (px / extent)
  fy = tile_y + (py / extent)

  lon = fx / n * 360.0 - 180.0
  lat_rad = math.atan(math.sinh(math.pi * (1 - 2 * fy / n)))
  lat = math.degrees(lat_rad)

  return lon, lat

def lonlat_to_tile(lat, lon, zoom):
  lat_rad = math.radians(lat)
  n = 2 ** zoom

  x = int((lon + 180.0) / 360.0 * n)
  y = int((1.0 - math.asinh(math.tan(lat_rad)) / math.pi) / 2.0 * n)

  return x, y
