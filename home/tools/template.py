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
        perform_copy = True

        if os.listdir(destdir):
            prompt = "Current directory isn't empty. Continue? [y/n] "

            try:
                answer = raw_input(prompt)
            except NameError:
                answer = input(prompt)

            if answer[0].lower() != 'y':
                perform_copy = False

        if perform_copy:
            distutils.dir_util.copy_tree(srcdir, destdir)

if __name__ == '__main__':
    main(sys.argv)
