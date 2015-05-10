#!/usr/bin/env python3

# TODO list:
# - Make it so that mounting the file system and not changing any of its 
# contents do not change the image itself. Otherwise, git always notes changes 
# in the file system.

import os
import sys
import argparse
import subprocess
import humanfriendly

def create(filename, size):
    size_in_bytes = humanfriendly.parse_size(size)

    with open(filename, 'wb') as out:
        out.truncate(size_in_bytes)

    cmd = 'cryptsetup -y -v luksFormat %s' % filename
    subprocess.call(cmd.split())

    mapping_name = os.path.basename(filename)
    cmd = 'cryptsetup luksOpen %s %s' % (filename, mapping_name)
    subprocess.call(cmd.split())

    cmd = 'dd if=/dev/zero of=/dev/mapper/%s' % mapping_name
    subprocess.call(cmd.split())

    cmd = 'mkfs.ext4 /dev/mapper/%s' % mapping_name
    subprocess.call(cmd.split())

    cmd = 'cryptsetup luksClose %s' % mapping_name
    subprocess.call(cmd.split())

def mount(filename, mountdir):
    mapping_name = os.path.basename(filename)
    cmd = 'cryptsetup luksOpen %s %s' % (filename, mapping_name)
    subprocess.call(cmd.split())

    cmd = 'mount /dev/mapper/%s %s' % (mapping_name, mountdir)
    subprocess.call(cmd.split())

def unmount(filename, mountdir):
    cmd = 'umount %s' % mountdir
    subprocess.call(cmd.split())

    mapping_name = os.path.basename(filename)
    cmd = 'cryptsetup luksClose %s' % mapping_name
    subprocess.call(cmd.split())

def main(argv):
    parser = argparse.ArgumentParser(description= \
            'Manage LUKS-encrypted volumes inside a file')

    subparsers = parser.add_subparsers(help='sub-command help', dest='subcmd')

    # Create sub-command
    parser_create = subparsers.add_parser('create', \
            help='Create a new encrypted volume.')

    parser_create.add_argument('--size', '-s', type=str, action='store', \
            default='10M', help='Size of the volume.')

    parser_create.add_argument('filename', type=str, action='store', \
            help='What name to save the volume in.')

    # Mount sub-command
    parser_mount = subparsers.add_parser('mount', \
            help='Mount an encrypted volume.')

    parser_mount.add_argument('filename', type=str, action='store', \
            help='What volume file to mount.')

    parser_mount.add_argument('dir', type=str, action='store', \
            help='Where to mount the encrypted volume.')

    # Un-mount sub-command
    parser_unmount = subparsers.add_parser('unmount', \
            help='Unmount a mounted volume.')

    parser_unmount.add_argument('filename', type=str, action='store', \
            help='Which file to unmount.')

    parser_unmount.add_argument('dir', type=str, action='store', \
            help='Where the volume is currently mounted.')

    args = parser.parse_args(argv[1:])

    if args.subcmd == 'create':
        create(args.filename, args.size)

    elif args.subcmd == 'mount':
        mount(args.filename, args.dir)

    elif args.subcmd == 'unmount':
        unmount(args.filename, args.dir)


if __name__ == '__main__':
    main(sys.argv)
