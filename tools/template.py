#!/usr/bin/python

import os
import sys
import distutils
import argparse

def main(mainargs):
    parser = argparse.ArgumentParser()
    parser.add_argument('template', help='Which template to instantiate.')

    args = parser.parse(mainargs)

    srcdir = os.path.join(os.environ('HOME'), '.templates', args.template)
    destdir = os.path.join(os.getcwd(), '.')

    distutils.dir_util.copy_tree(srcdir, destdir)

if __name__ == '__main__':
    main(sys.argv)
