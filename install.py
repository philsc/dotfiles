#!/usr/bin/env python3

import os
import sys
import argparse
import errno
import subprocess

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


def create_folders():
    # Create a certain set of folders that are needed by the dotfiles.
    dirs = [
            '.bin',
            '.config',
            ]

    for directory in [os.path.join(HOME, d) for d in dirs]:
        os.makedirs(directory, exist_ok=True)

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

    from os.path import join
    links = [(l, l) for l in direct] + \
            [(l, join('.config', l)) for l in config] + \
            misc

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


def create_empty_files():
    # Some dotfiles are ignored by git so that local configuration can be done.
    # If the files already exist, then we should simply do nothing.
    local_rc = [
            '.bash/paths.local',
            '.bash/exports.d/local',
            '.bash/aliases.d/local',
            ]

    for rc in local_rc:
        with open(rc, 'a+') as rc_file: pass


def create_git_configs():
    configs = [
            ('init.templatedir', os.path.join(HOME, '.git_template')),
            ('alias.ctags', '!.git/hooks/ctags'),
            ('alias.graph', 'log --all --graph --oneline --decorate=short'),
            ('alias.lgraph', 'log --graph --oneline --decorate=short HEAD'),
            ('alias.compress', 'repack -a -d --depth=250 --window=250'),
            ('color.diff', 'auto'),
            ('color.ui', 'auto'),
            ('credential.helper', 'cache --timeout=3600'),
            ]

    for config in configs:
        cmd = 'git config --global'.split(' ') + [config[0]]
        if subprocess.call(cmd, stdout=subprocess.DEVNULL) == 0:
            info('git config %s already configured\n' % config[0])


def main(arguments):
    parser = argparse.ArgumentParser(description='Install dotfiles.')
    args = parser.parse_args(arguments[1:])

    create_folders()
    create_links()
    create_min_files()
    create_empty_files()
    create_git_configs()


main(sys.argv)
