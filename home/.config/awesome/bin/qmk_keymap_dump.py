#!/usr/bin/env python3
"""Read the keymap out of the ErgoDox EZ over raw HID.

The firmware (qmk_firmware keyboards/ergodox_ez/keymaps/phil) answers a small
request/response protocol; see raw_hid_receive there for the packet layout.
Prints a Lua table (awesome has no JSON parser) or, with --json, JSON.

Only the standard library is used: raw HID on Linux is plain read/write on
/dev/hidrawN. The right node is found by its report descriptor rather than by
number, since numbers shift whenever the keyboard re-enumerates.

Exit codes: 2 keyboard or raw interface not found, 3 permission denied,
4 protocol error or timeout.
"""

import argparse
import glob
import json
import os
import select
import struct
import sys

VENDOR_ID = 0x3297
PRODUCT_ID = 0x4974
# Usage page 0xFF60, usage 0x61: QMK's raw HID interface.
RAW_DESCRIPTOR_PREFIX = bytes.fromhex("0660ff0961")
REPORT_SIZE = 32
UDEV_RULE = "70-qmk-hidraw.rules (dotfiles-qmk deb)"

CMD_INFO = 0x01
CMD_KEYCODES = 0x02
CMD_LAYER_NAME = 0x03
CMD_STATE = 0x04
CMD_USER_NAME = 0x05
RESP_ERROR = 0xFF

PROTOCOL = 1
NAME_LEN = 8
MAX_KEYCODES = (REPORT_SIZE - 4) // 2


class DumpError(Exception):
    def __init__(self, message, code):
        super().__init__(message)
        self.code = code


def find_device():
    """Returns the /dev/hidraw path of the keyboard's raw HID interface."""
    hid_id = "HID_ID=0003:%08X:%08X" % (VENDOR_ID, PRODUCT_ID)
    saw_keyboard = False
    for sysdir in sorted(glob.glob("/sys/class/hidraw/hidraw*")):
        try:
            with open(os.path.join(sysdir, "device", "uevent")) as f:
                if hid_id not in f.read():
                    continue
            saw_keyboard = True
            with open(os.path.join(sysdir, "device", "report_descriptor"), "rb") as f:
                if f.read(len(RAW_DESCRIPTOR_PREFIX)) == RAW_DESCRIPTOR_PREFIX:
                    return "/dev/" + os.path.basename(sysdir)
        except OSError:
            continue
    if saw_keyboard:
        raise DumpError("ErgoDox is connected but its firmware has no raw HID interface (RAW_ENABLE)", 2)
    raise DumpError("ErgoDox EZ not connected", 2)


class Device:
    def __init__(self, path):
        try:
            self.fd = os.open(path, os.O_RDWR)
        except PermissionError:
            raise DumpError("no permission for %s; install the udev rule %s" % (path, UDEV_RULE), 3)
        except OSError as e:
            raise DumpError("cannot open %s: %s" % (path, e.strerror), 2)

    def close(self):
        os.close(self.fd)

    def request(self, *payload, timeout=0.5, retries=1):
        """Sends one packet and returns the matching reply."""
        packet = bytes(payload).ljust(REPORT_SIZE, b"\0")
        for _ in range(retries + 1):
            # hidraw wants a leading report ID byte; the raw interface has none.
            os.write(self.fd, b"\0" + packet)
            while select.select([self.fd], [], [], timeout)[0]:
                resp = os.read(self.fd, REPORT_SIZE * 2)
                if len(resp) < REPORT_SIZE:
                    continue
                if resp[0] == RESP_ERROR and resp[1] == payload[0]:
                    raise DumpError("keyboard rejected command 0x%02x: error %d" % (payload[0], resp[2]), 4)
                if resp[0] == payload[0]:
                    return resp
                # A stale reply from an earlier, interrupted run; skip it.
        raise DumpError("keyboard did not answer command 0x%02x" % payload[0], 4)


def cstring(data):
    return data.split(b"\0", 1)[0].decode("ascii", "replace")


def dump(dev):
    info = dev.request(CMD_INFO)
    if info[5:8] != b"KMP" or info[1] != PROTOCOL:
        raise DumpError("unexpected INFO reply: %s" % info.hex(), 4)
    rows, cols, layers, n_user = info[2], info[3], info[4], info[8]

    layer_names = [cstring(dev.request(CMD_LAYER_NAME, l)[2:2 + NAME_LEN]) for l in range(layers)]
    user_names = [cstring(dev.request(CMD_USER_NAME, n)[2:2 + NAME_LEN]) for n in range(n_user)]

    state = dev.request(CMD_STATE)
    layer_state, default_layer_state = struct.unpack_from("<II", state, 1)
    highest_layer = state[9]

    keycodes = []
    for layer in range(layers):
        flat = []
        for start in range(0, rows * cols, MAX_KEYCODES):
            count = min(MAX_KEYCODES, rows * cols - start)
            resp = dev.request(CMD_KEYCODES, layer, start, count)
            if resp[1:4] != bytes((layer, start, count)):
                raise DumpError("mismatched KEYCODES reply: %s" % resp.hex(), 4)
            flat.extend(struct.unpack_from("<%dH" % count, resp, 4))
        keycodes.append([flat[r * cols:(r + 1) * cols] for r in range(rows)])

    return {
        "protocol": PROTOCOL,
        "rows": rows,
        "cols": cols,
        "layer_state": layer_state,
        "default_layer_state": default_layer_state,
        "highest_layer": highest_layer,
        "layer_names": layer_names,
        "user_names": user_names,
        "keycodes": keycodes,
    }


def lua_string(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def to_lua(d):
    """Renders the dump as a Lua chunk; lists become 1-based tables."""
    lines = ["return {"]
    for key in ("protocol", "rows", "cols", "layer_state", "default_layer_state", "highest_layer"):
        lines.append("  %s = %d," % (key, d[key]))
    for key in ("layer_names", "user_names"):
        lines.append("  %s = {%s}," % (key, ", ".join(lua_string(s) for s in d[key])))
    lines.append("  keycodes = {")
    for layer in d["keycodes"]:
        lines.append("    {")
        for row in layer:
            lines.append("      {%s}," % ", ".join("0x%04X" % kc for kc in row))
        lines.append("    },")
    lines.append("  },")
    lines.append("}")
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    parser.add_argument("--json", action="store_true", help="print JSON instead of a Lua table")
    args = parser.parse_args()
    try:
        dev = Device(find_device())
        try:
            data = dump(dev)
        finally:
            dev.close()
    except DumpError as e:
        print("qmk_keymap_dump: %s" % e, file=sys.stderr)
        return e.code
    if args.json:
        json.dump(data, sys.stdout)
        print()
    else:
        sys.stdout.write(to_lua(data))
    return 0


if __name__ == "__main__":
    sys.exit(main())
