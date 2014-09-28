#!/usr/bin/env python3

import os
import sys
import argparse
import errno
import subprocess
import errno
import urllib.request
import zipfile
import tempfile
import shutil

ROOT = os.path.dirname(os.path.realpath(__file__))
HOME = os.getenv('HOME')


def make_printer(prefix):
    return lambda message: sys.stdout.write("%s %s" % (prefix, message))

info = make_printer('INFO')
warn = make_printer('WARNING')
new = make_printer('NEW')
done = make_printer('')


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


def setup_min_file(target, min_file_content):
    if os.path.exists(target):
        with open(target, 'r') as content_file:
            content = content_file.read()

        if content == min_file_content:
            info("Skipping default install for %s\n" % target)
            return

        answer = input('Overwrite %s with default? ' % target)

        if answer[0].lower() != 'y':
            return

    with open(target, 'w') as min_file:
        min_file.write(min_file_content)

    new("Installed file %s with default content\n" % target)


def create_folders():
    # Create a certain set of folders that are needed by the dotfiles.
    dirs = [
            '.bin',
            '.config',
            ]

    for directory in [os.path.join(HOME, d) for d in dirs]:
        try:
            os.makedirs(directory, exist_ok=True)
        except OSError as exc:
            # Because makedirs will raise an error when the mode is different, 
            # we will simply ignore the corresponding exception when it is 
            # raised.
            if exc.errno != errno.EEXIST: raise
            else: pass

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
            ('.vimrc', "source ~/.vim/vimrc\n"),
            ('.bashrc', "source ~/.bash/bashrc\n"),
            ('.muttrc', "source ~/.mutt/muttrc\n"),
            ]

    for min_file in min_files:
        setup_min_file(os.path.join(HOME, min_file[0]), min_file[1])


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

    with open(os.devnull, 'wb') as devnull:
        for config in configs:
            cmd = 'git config --global'.split(' ') + [config[0]]

            if subprocess.call(cmd, stdout=devnull) == 0:
                info('git config %s already configured\n' % config[0])
            else:
                subprocess.call(cmd + [config[1]], stdout=devnull)
                new('git configured %s\n' % config[0])


def install_vim_plugins():
    plugins = [
            ('https://github.com/docker/docker/archive/master.zip', \
                    'contrib/syntax/vim', 'docker'),
            ('https://github.com/rust-lang/rust/archive/master.zip', \
                    'src/etc/vim', 'rust'),
            ]

    for plugin in plugins:

        target = os.path.join(HOME, '.vim/bundle', plugin[2] + '.vim')

        if os.path.isdir(target):
            info("vim plugin for %s already installed\n" % plugin[2])
            continue

        # Download the zip file and save it as a temporary file.
        new("Installing vim plugin for %s..." % plugin[2])

        (temp_file, _) = urllib.request.urlretrieve(plugin[0])

        print("Temporary file %s" % temp_file)

        with zipfile.ZipFile(temp_file) as zip_file:
            temp_dir = tempfile.mkdtemp()
            zip_file.extractall(temp_dir)
            shutil.move(os.path.join(temp_dir, plugin[1]), \
                    os.path.join(HOME, '.vim/bundle', plugin[2] + '.vim'))
            shutil.rmtree(temp_dir)

        shutil.rm(temp_file)

        done("done\n" % plugin[2])


def main(arguments):
    parser = argparse.ArgumentParser(description='Install dotfiles.')
    args = parser.parse_args(arguments[1:])

    create_folders()
    create_links()
    create_min_files()
    create_empty_files()
    create_git_configs()
    install_vim_plugins()


main(sys.argv)
