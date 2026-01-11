#!/usr/bin/python3

import argparse
import os
import stat
import pprint

"""
A python implementation / prototype.
"""

def attrs(value):
  elements = value.split('/')
  return { a: None for a in filter(len, elements) }

parser = argparse.ArgumentParser(prog='lx.py', description = 'link query')
parser.add_argument('-a', '--attributes', nargs=1, type=attrs)
parser.add_argument('-e', '--expand', action='store_true')
parser.add_argument('-d', '--delimiter', default="/")
parser.add_argument('paths', nargs = '+')
parsed = parser.parse_args()

def query(indent, path, expand, devinos, attributes):
  prev = 0
  rest = None
  prefix = path

  pending = None
  st = None

  while True:
    slash = path.find('/', prev + 1)
    if slash < 0:
      break
    if prev:
      name = path[prev+1:slash]
      if pending:
        attributes[pending] = name
        pending = None
      if name in attributes:
        pending = name
    prefix = path[0:slash]
    st = os.lstat(prefix)
    if not stat.S_ISDIR(st.st_mode):
      rest = path[slash + 1:]
      break
    st = None
    prev = slash
  
  name = path
  if prev > 0:
    dirname = path[0:prev]
    os.chdir(dirname)
    start = prev + 1
    end = slash if slash > 0 else None
    name = path[start:end]
    prefix = path[:end]

  if not st:
    st = os.lstat(name)
  if st.st_ino in devinos:
    print(f"{'':<{indent*2}}...")
    return

  devinos[st.st_ino] = True

  if stat.S_ISLNK(st.st_mode):
    target = os.readlink(name)
    if expand:
      print(f"{'':<{indent*2}}{prefix} -> {target}")
      indent += 1
    if rest:
      target = os.path.join(target, rest)
    return query(indent, target, expand, devinos, attributes);

  print(f"{'':<{indent*2}}{path}")

  indent += 1
  for key, value in attributes.items():
    if value:
        print(f"{'':<{indent*2}}{key}{parsed.delimiter}{value}")

dot = os.open('.', os.O_RDONLY)
for i in range(0, len(parsed.paths)):
  devinos = {}
  attributes = dict(parsed.attributes[0]) if parsed.attributes else {}
  os.fchdir(dot)
  expand = parsed.expand or len(attributes) == 0
  query(0, parsed.paths[i], expand, devinos, attributes)
