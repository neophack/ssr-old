#!/usr/bin/env python
import json
import sys

def main(key):
    with open('config-local.json') as f:
        data = f.read()
    js = json.loads(data)
    print(js[key])
    return js[key]

if __name__ == "__main__":
    if len(sys.argv) > 1:
        main(sys.argv[1])
