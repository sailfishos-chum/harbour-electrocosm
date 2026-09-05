import os
import json
import time

CACHE_DIR = os.path.expanduser('~/.cache/app.qml/electrocosm')
DEFAULT_TTL_SECONDS = 3 * 24 * 60 * 60  # a few days - will be user-configurable later


def _path(*parts):
  path = os.path.join(CACHE_DIR, *parts)
  os.makedirs(os.path.dirname(path), exist_ok=True)
  return path

def _is_fresh(path, ttl):
  return os.path.exists(path) and (time.time() - os.path.getmtime(path)) <= ttl

def get_json(key, ttl=DEFAULT_TTL_SECONDS):
  path = _path('json', key + '.json')
  if not _is_fresh(path, ttl):
    return None
  try:
    with open(path) as f:
      return json.load(f)
  except Exception as err:
    return None

def set_json(key, data):
  with open(_path('json', key + '.json'), 'w') as f:
    json.dump(data, f)

def get_bytes(key, ttl=DEFAULT_TTL_SECONDS):
  path = _path('bin', key)
  if not _is_fresh(path, ttl):
    return None
  try:
    with open(path, 'rb') as f:
      return f.read()
  except Exception as err:
    return None

def set_bytes(key, data):
  with open(_path('bin', key), 'wb') as f:
    f.write(data)

def get_image_path(key):
  path = _path('images', key)
  return path if os.path.exists(path) else None

def set_image(key, data):
  path = _path('images', key)
  with open(path, 'wb') as f:
    f.write(data)
  return path
