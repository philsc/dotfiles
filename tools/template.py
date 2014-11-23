#!/usr/bin/python

import os
import sys
import distutils.dir_util
import argparse

def main(mainargs):
    parser = argparse.ArgumentParser()
    parser.add_argument('template', help='Which template to instantiate.')
    parser.add_argument('--list', '-l', action='store_true', \
            dest='list_templates', help='List the available templates.')
    args = parser.parse_args(mainargs[1:])

    if args.list_templates:
        sys.stderr.write('TODO: Implement listing templates.\n')
    else:
        srcdir = os.path.join(os.environ['HOME'], '.templates', args.template)
        destdir = os.path.join(os.getcwd(), '.')
        distutils.dir_util.copy_tree(srcdir, destdir)

if __name__ == '__main__':
    main(sys.argv)
