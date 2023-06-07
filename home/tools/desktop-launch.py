#!/usr/bin/env python3

import os
import subprocess
import shlex
import sys
from pathlib import Path

def main(argv):
    desktop_file = Path(argv[1])

    for line in desktop_file.read_text().splitlines():
        if line.startswith("Exec="):
            _, _, cmd = line.partition("=")
            split_cmd = shlex.split(cmd)
            os.execvp(split_cmd[0], split_cmd)

    raise ValueError(f"Could not find Exec= line in {desktop_file}")

if __name__ == "__main__":
    sys.exit(main(sys.argv))
