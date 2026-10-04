#!/usr/bin/env python3
"""Get or set the Apple Studio Display's brightness over USB HID.

The display ignores DDC/CI. Its brightness is the USB monitor control class's
Brightness (VESA Virtual Controls page 0x82, usage 0x10), feature report 1:
a 32-bit value from 400 to 60000, then a 16-bit transition time in ms. Shown
and taken here as a percent of that range.

Only the standard library is used: feature reports on Linux are ioctls on
/dev/hidrawN. The right node is found by its report descriptor rather than by
number, since numbers shift whenever the display re-enumerates.

Exit codes: 2 display or its monitor interface not found, 3 permission denied.
"""

import argparse
import fcntl
import glob
import os
import struct
import sys

VENDOR_ID = 0x05AC
# The monitor control interface's descriptor: Usage Page (USB Monitor), Usage
# (Monitor Control), Collection, Report ID 1, Usage Page (VESA Virtual
# Controls), Usage (Brightness).
MONITOR_DESCRIPTOR_PREFIX = bytes.fromhex("05800901a10185010682000910")
REPORT_ID = 1
# Report ID, brightness (u32), transition time in ms (u16).
REPORT = struct.Struct("<BIH")
BRIGHTNESS_MIN, BRIGHTNESS_MAX = 400, 60000
UDEV_RULE = "90-backlight.rules (homelab-backlight deb)"


class BrightnessError(Exception):
    def __init__(self, message, code):
        super().__init__(message)
        self.code = code


def _iowr(nr, size):
    # _IOC(_IOC_READ | _IOC_WRITE, 'H', nr, size) from linux/hidraw.h.
    return (3 << 30) | (size << 16) | (ord("H") << 8) | nr


HIDIOCSFEATURE = _iowr(0x06, REPORT.size)
HIDIOCGFEATURE = _iowr(0x07, REPORT.size)


def find_device():
    """Returns the /dev/hidraw path of the display's monitor control interface."""
    vendor = "HID_ID=0003:%08X:" % VENDOR_ID
    for sysdir in sorted(glob.glob("/sys/class/hidraw/hidraw*")):
        try:
            with open(os.path.join(sysdir, "device", "uevent")) as f:
                if vendor not in f.read():
                    continue
            with open(os.path.join(sysdir, "device", "report_descriptor"), "rb") as f:
                if f.read(len(MONITOR_DESCRIPTOR_PREFIX)) == MONITOR_DESCRIPTOR_PREFIX:
                    return "/dev/" + os.path.basename(sysdir)
        except OSError:
            continue
    raise BrightnessError("No Apple Studio Display found", 2)


def open_device():
    path = find_device()
    try:
        return os.open(path, os.O_RDWR)
    except PermissionError:
        raise BrightnessError("Cannot open %s; is %s installed?" % (path, UDEV_RULE), 3)


def get_percent(fd):
    buf = bytearray(REPORT.pack(REPORT_ID, 0, 0))
    fcntl.ioctl(fd, HIDIOCGFEATURE, buf)
    _, value, _ = REPORT.unpack(buf)
    return round((value - BRIGHTNESS_MIN) * 100 / (BRIGHTNESS_MAX - BRIGHTNESS_MIN))


def set_percent(fd, percent):
    percent = max(0, min(100, percent))
    value = BRIGHTNESS_MIN + round(percent * (BRIGHTNESS_MAX - BRIGHTNESS_MIN) / 100)
    fcntl.ioctl(fd, HIDIOCSFEATURE, bytearray(REPORT.pack(REPORT_ID, value, 0)))


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("get", help="print the brightness in percent")
    setter = sub.add_parser("set", help="set the brightness in percent")
    setter.add_argument("percent", type=int)
    args = parser.parse_args()

    try:
        fd = open_device()
        try:
            if args.command == "set":
                set_percent(fd, args.percent)
            print(get_percent(fd))
        finally:
            os.close(fd)
    except BrightnessError as e:
        print(e, file=sys.stderr)
        return e.code
    return 0


if __name__ == "__main__":
    sys.exit(main())
