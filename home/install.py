#!/usr/bin/env python3

import os
import sys
import stat
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


def symlink(origin, target, force=False):
    if os.path.islink(target):
        if force:
            os.unlink(target)
        else:
            info("Symlink %s already installed\n" % target)
            return

    if os.path.exists(target):
        warn("%s already exists, but not a symlink\n" % target)
    else:
        dirname = os.path.dirname(target)
        if not os.path.exists(dirname):
            new("Creating folder %s\n" % dirname)
            os.makedirs(dirname)
        new("Installing symlink %s\n" % target)
        os.symlink(origin, target)


class DefaultFile:
    def __init__(self, target, source, executable=False):
        self.target = target
        self.source = source
        self.executable = executable


def setup_default_file(default, skip_if_exists=False):
    target = os.path.join(HOME, default.target)

    file_exists = os.path.exists(target)
    overwrite_contents = False

    with open(os.path.join('defaults', default.source), 'r') as default_file:
        default_content = default_file.read()

    if file_exists:
        if skip_if_exists:
            info("Skipping default install for %s\n" % target)
        else:
            with open(target, 'r') as content_file:
                current_content = content_file.read()

            if current_content == default_content:
                info("Skipping default install for %s\n" % target)
                return

            answer = input('Overwrite %s with default? ' % target)
            overwrite_contents = answer[0].lower() == 'y'
    else:
        overwrite_contents = True

    if overwrite_contents:
        new("Installed file %s with default content\n" % target)
        with open(target, 'w') as f:
            f.write(default_content)

    if default.executable:
        st = os.stat(target)
        if not st.st_mode & stat.S_IEXEC:
            new("Marking file %s as executable\n" % target)
            os.chmod(target, st.st_mode | stat.S_IEXEC)


def warn_missing_programs():
    # TODO Add warnings for
    # - ctags
    # - ack
    # - git
    # - xsel
    # - autocutsel
    pass


def create_folders():
    # Create a certain set of folders that are needed by the dotfiles.
    dirs = [
        '.bin',
        '.config',
        '.gnupg',
    ]

    for directory in [os.path.join(HOME, d) for d in dirs]:
        try:
            os.makedirs(directory, exist_ok=True)
        except OSError as exc:
            # Because makedirs will raise an error when the mode is different,
            # we will simply ignore the corresponding exception when it is
            # raised.
            if exc.errno != errno.EEXIST:
                raise
            else:
                pass


def create_links(force=False):
    # Create symbolic links to various dotfiles.
    direct = [
        '.bash',
        '.git_template',
        '.git_global_ignore',
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
        '.pythonrc.py',
        '.tmux',
        '.gdbinit',
        '.config/awesome',
        '.config/fontconfig',
    ]
    misc = [
        ('tools/q/bin/q', '.bin/q'),
        ('tools/nsenter/docker-enter', '.bin/docker-enter'),
        ('tools/vimpager/vimcat', '.bin/vimcat'),
        ('tools/vimpager/vimpager', '.bin/vimpager'),
        ('tools/template.py', '.bin/template.py'),
        ('tools/crypt-helper.py', '.bin/crypt-helper.py'),
        ('tools/git-ll', '.bin/git-ll'),
        ('tools/webserver.py', '.bin/webserver.py'),
        ('tools/dtc-wrapper.sh', '.bin/dtc-wrapper.sh'),
        ('tools/fzf/bin/fzf', '.bin/fzf'),
        ('tools/fzf/bin/fzf-tmux', '.bin/fzf-tmux'),
        ('tools/fzf/shell/completion.bash', '.bash/completion.d/fzf'),
        ('python/autopep8/autopep8.py', '.bin/autopep8'),
        ('python', '.python'),
        ('fontconfig/fonts.conf', '.fonts.conf'),
        ('gpg.conf', '.gnupg/gpg.conf'),
        ('templates', '.templates'),
    ]

    from os.path import join
    links = [(l, l) for l in direct] + \
        misc

    for link in links:
        symlink(join(ROOT, link[0]), join(HOME, link[1]), force=force)


def create_default_files():
    default_files = [
        DefaultFile('.xprofile.local', '.xprofile.local', executable=True),
        DefaultFile('.vim/vimrc.local', 'vimrc.local'),
        DefaultFile('.config/awesome/prefs.lua', 'prefs.lua'),
        DefaultFile('.bazelrc', '.bazelrc'),
    ]

    for default in default_files:
        setup_default_file(default, skip_if_exists=True)


def create_min_files():
    # Create certain "minimum" files that will source the dotfiles symlinked
    # earlier. The idea is to keep the configuration all within the dotfiles.
    min_files = [
        DefaultFile('.vimrc', '.vimrc'),
        DefaultFile('.bashrc', '.bashrc'),
        DefaultFile('.bash_profile', '.bash_profile'),
        DefaultFile('.muttrc', '.muttrc'),
        DefaultFile('.xsessionrc', '.xsessionrc'),
    ]

    for default in min_files:
        setup_default_file(default)


def create_empty_files():
    # Some dotfiles are ignored by git so that local configuration can be done.
    # If the files already exist, then we should simply do nothing.
    local_rc = [
        '.bash/paths.local',
        '.bash/exports.d/local',
        '.bash/aliases.d/local',
    ]

    for rc in local_rc:
        with open(rc, 'a+') as rc_file:
            pass


def create_git_configs():
    gitcookies_filename = os.path.join(HOME, '.gitcookies')

    configs = [
        ('init.templatedir', os.path.join(HOME, '.git_template')),
        ('alias.ctags', '!.git/hooks/ctags'),
        ('alias.graph', 'log --all --graph --oneline --decorate=short'),
        ('alias.lgraph', 'log --graph --oneline --decorate=short HEAD'),
        ('alias.lg', "log --all --graph --pretty=format:'%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit --date=relative"),
        ('alias.llg', "log --graph --pretty=format:'%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit --date=relative"),
        ('alias.compress', 'repack -a -d --depth=250 --window=250'),
        ('alias.abbr', "!sh -c 'git rev-list --all | grep ^$1 | while read commit; do git --no-pager log -n1 --pretty=format:\"%H %ci %an %s%n\" $commit; done' -"),
        ('alias.aliases',
         "!git config --get-regexp 'alias.*' | colrm 1 6 | sed 's/[ ]/ = /'"),
        ('alias.graphviz',
         "!f() { echo 'digraph git {' ; git log --pretty='format:  %h -> { %p }' \"$@\" | sed 's/[0-9a-f][0-9a-f]*/\"&\"/g' ; echo '}'; }; f"),
        ('alias.serve', "!git daemon --reuseaddr --verbose  --base-path=. --export-all ./.git"),
        ('alias.diffstat', 'diff --stat'),
        ('alias.st', 'diff --name-status'),
        ('alias.whatis', "show -s --pretty='tformat:%h (%s, %ad)' --date=short"),
        ('alias.worddiff',
         """diff --word-diff --color-words='[^",:  /'"'"'()]+'"""),
        ('color.diff', 'auto'),
        ('color.ui', 'auto'),
        ('color.diff.whitespace', 'red reverse'),
        ('credential.helper', 'cache --timeout=3600'),
        ('core.pager', 'less -S'),
        ('core.excludesfile', os.path.join(HOME, '.git_global_ignore')),
        ('diff.renameLimit', '9124'),
        ('merge.tool', 'vimdiff'),
        ('merge.conflictstyle', 'diff3'),
        ('mergetool.keepBackup', 'false'),
        ('mergetool.prompt', 'false'),
        ('http.cookiefile', gitcookies_filename),
        ('fetch.prune', 'true'),
    ]

    # Make sure that the git cookies are not world-readable.
    with open(gitcookies_filename, 'a'):
        os.chmod(gitcookies_filename, 0o600)

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
        ('https://github.com/moby/moby/archive/master.zip',
         'contrib/syntax/vim', 'moby'),
    ]

    for plugin in plugins:

        target = os.path.join(HOME, '.vim/bundle', plugin[2] + '.vim')

        if os.path.isdir(target):
            info("vim plugin for %s already installed\n" % plugin[2])
            continue

        # Download the zip file and save it as a temporary file.
        new("Installing vim plugin for %s..." % plugin[2])

        (temp_file, _) = urllib.request.urlretrieve(plugin[0])

        # Unzip the zipfile and copy the right folder into the .vim structure.
        with zipfile.ZipFile(temp_file) as zip_file:
            temp_dir = tempfile.mkdtemp()
            zip_file.extractall(temp_dir)

            src = os.path.join(temp_dir, plugin[2] + '-master', plugin[1])
            dest = os.path.join(HOME, '.vim/bundle', plugin[2] + '.vim')
            shutil.move(src, dest)
            shutil.rmtree(temp_dir)

        os.remove(temp_file)

        done("done\n")


def install_certificates():
    certs = [
        ('https://sks-keyservers.net/sks-keyservers.netCA.pem',
         '.gnupg/sks-keyservers.netCA.pem'),
    ]

    for (url, target) in certs:
        dest = os.path.join(HOME, target)

        if os.path.exists(dest):
            info("Skipping certificate install for %s\n" % dest)
        else:
            new("Installing certificate for %s..." % dest)
            (temp_file, _) = urllib.request.urlretrieve(url)
            shutil.move(temp_file, dest)
            done("done\n")


def install_go_programs():
    programs = [
        "gopkg.in/Netflix-Skunkworks/go-jira.v1/cmd/jira",
        "github.com/junegunn/fzf",
        "github.com/bazelbuild/buildtools/buildifier",
    ]

    go_bin = shutil.which('go')
    if not go_bin:
        warn("Couln't find go in the PATH\n");
        for program in programs:
            warn("Skipping install of %s\n" % program)
        return

    with open(os.devnull, 'wb') as devnull:
        for program in programs:
            if subprocess.call(["go", "get", program], stdout=devnull) == 0:
                new('Installed %s\n' % program)
            else:
                warn("Failed to get %s\n" % program)


def main(argv):
    parser = argparse.ArgumentParser(description='Install dotfiles.')
    parser.add_argument('--force', '-f', dest='force', action='store_true',
                        help='Force overwrite any symlinks if they point to the '
                        'wrong target.')
    parser.set_defaults(force=False)
    args = parser.parse_args(argv[1:])

    warn_missing_programs()
    create_folders()
    create_links(force=args.force)
    create_default_files()
    create_min_files()
    create_empty_files()
    create_git_configs()
    install_vim_plugins()
    install_certificates()
    install_go_programs()


if __name__ == '__main__':
    sys.exit(main(sys.argv))
