#!/usr/bin/env python

import argparse
import json

def main():
    parser = argparse.ArgumentParser(description="parse config.json file")

    parser.add_argument("key",help="specify key in config.json")

    arg = parser.parse_args()

    with open('config-local.json') as f:
        data = f.read()
    js = json.loads(data)

    try:
        print(js[arg.key])
    except KeyError:
        pass

if __name__ == "__main__":
    main()
