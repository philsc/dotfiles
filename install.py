#!/usr/bin/env python2

import os
import sys
import argparse

MIN_FILES = {
        'vimrc': "source ~/.vim/vimrc\n",
        'bashrc': "source ~/.bash/bashrc\n",
        'muttrc': "source ~/.mutt/muttrc\n",
        }

ROOT = os.path.dirname(os.path.realpath(__file__))
HOME = os.getenv('HOME')


def info(message):
    sys.stdout.write("INFO " + message)


def warn(message):
    sys.stdout.write("WARNING " + message)


def new(message):
    sys.stdout.write("NEW " + message)


def ensure_installed(program):
    pass


def symlink(origin, target):
    if os.path.islink(target):
        info("Symlink %s already installed\n" % target)
    elif os.path.exists(target):
        warn("%s already exists, but is a symlink\n" % target)
    else:
        new("Installing symlink %s\n" % target)
        os.symlink(origin, target)


def setup_min_file(min_file_index, target):
    overwrite_file = True

    if os.path.exists(target):
        with open(target, 'r') as content_file:
            content = content_file.read()

        if content == MIN_FILES[min_file_index]:
            info("Skipping default install for %s\n" % target)
            overwrite_file = False
        else:
            input = raw_input('Overwrite %s with default? ' % target)
            overwrite_file = (input[0].lower() == 'y')

    if overwrite_file:
        with open(target, 'w') as min_file:
            min_file.write(MIN_FILES[min_file_index])
        new("Installed file %s with default content\n" % target)


def create_links():
    # Create symbolic links to various dotfiles.
    direct = [
            '.bash',
            '.git_template',
            '.tmux.conf',
            '.vim',
            '.irbrc',
            '.rvmrc',
            '.colordiffrc',
            '.mutt',
            '.Xresources',
            '.xprofile',
            '.xinitrc',
            '.gtkrc-2.0',
            '.fonts',
            '.urxvt',
            ]
    config = [
            'awesome',
            'fontconfig',
            ]
    misc = [
            ('tools/q/bin/q', '.bin/q'),
            ('tools/vimpager/vimcat', '.bin/vimcat'),
            ('tools/vimpager/vimpager', '.bin/vimpager'),
            ('fontconfig/fonts.conf', '.fonts.conf'),
            ]

    links = [(l, l) for l in direct] + \
            [(l, join('.config', l)) for l in config] + \
            misc

    from os.path import join
    for link in links:
        symlink(join(ROOT, link[0]), join(HOME, link[1]))


def create_min_files():
    # Create certain "minimum" files that will source the dotfiles symlinked 
    # earlier. The idea is to keep the configuration all within the dotfiles.
    min_files = [
            ('vimrc', '.vimrc'),
            ('bashrc', '.bashrc'),
            ('muttrc', '.muttrc'),
            ]

    for min_file in min_files:
        setup_min_file(min_file[0], os.path.join(HOME, min_file[1]))


def main(arguments):
    parser = argparse.ArgumentParser(description='Install dotfiles.')
    args = parser.parse_args(arguments[1:])

    create_links()
    create_min_files()


main(sys.argv)
