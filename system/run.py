#!/usr/bin/env python3

import os
import argparse
import sys
import tempfile
import json
import socket
import subprocess


added_groups = []


AUTO_GROUPS = {
    "gallifrey": [
        "base",
        "general",
        "docker",
        "gitolite",
        "nginx",
        "gallifrey",
    ],
    "silence": [
        "base",
        "general",
        "development",
        "desktop",
        "openssh-server",
        "steam",
        "pulseaudio",
    ],
    "minitardis": [
        "base",
        "general",
        "development",
        "desktop",
        "openssh-server",
        "steam",
        "pulseaudio",
    ],
}


def add_group(parser, group_name, help, default=True):
    group_parser = parser.add_mutually_exclusive_group(required=False)
    group_parser.add_argument(
        '--' + group_name,
        dest=group_name,
        help=help,
        action='store_true')
    group_parser.add_argument(
        '--no-' + group_name,
        dest=group_name,
        action='store_false')
    parser.set_defaults(**{group_name: default})

    global added_groups
    added_groups.append(group_name)


def main(argv):
    parser = argparse.ArgumentParser(description='Apply salt configs.')
    parser.add_argument('--auto', action='store_true',
                        help='Determine groups based on hostname.')
    add_group(parser, 'base', help='Make sure salt is set up.', default=True)
    add_group(
        parser,
        'general',
        help='Installs useful command-line tools and compilers and such.',
        default=True)
    add_group(
        parser,
        'desktop',
        help='Installs GUI desktop-related programs such as awesome.',
        default=False)
    add_group(parser, 'pulseaudio',
              help='Sets up a system PulseAudio daemon.', default=False)
    add_group(parser, 'steam', help='Sets up Steam.', default=False)
    add_group(
        parser,
        'openssh-server',
        help='Sets up an OpenSSH server.',
        default=False)
    add_group(
        parser,
        'docker',
        help='Sets up the Docker container engine.',
        default=False)
    add_group(
        parser,
        'gitolite',
        help='Sets up a gitolite instance via docker.',
        default=False)
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Don\'t run salt, but print out everything that is about to happen')
    parser.add_argument(
        'positional',
        type=str,
        metavar='ARGS',
        nargs=argparse.REMAINDER,
        help='Passed to the underlying salt-call function')

    args = parser.parse_args(argv[1:])

    config_dir = os.path.dirname(os.path.realpath(__file__))
    pillar_dir = os.path.join(config_dir, 'pillar')
    pillar_files_dir = os.path.join(pillar_dir, 'files')

    minion_output = {
        'pillar_roots': {'base': [pillar_dir]},
        'file_roots': {'base': [os.path.join(config_dir, 'files'),
                                os.path.join(config_dir, 'config'),
                                pillar_files_dir]}}
    top_sls_output = {'base': {'*': []}}

    # Make it so that no one else can access the pillar directory.
    os.chmod(pillar_dir, 0o700)

    # Set up the groups if --auto was specifified.
    if args.auto:
        for group_name in AUTO_GROUPS[socket.gethostname()]:
            top_sls_output['base']['*'].append(group_name)

    global added_groups
    for group_name in added_groups:
        if vars(args)[group_name]:
            top_sls_output['base']['*'].append(group_name)

    with tempfile.TemporaryDirectory() as d:
        minion_output['file_roots']['base'].append(d)

        with open(os.path.join(d, 'minion'), 'w') as f:
            f.write(json.dumps(minion_output, indent=4) + '\n')

        with open(os.path.join(d, 'minion_id'), 'w') as f:
            f.write(socket.gethostname() + '\n')

        with open(os.path.join(d, 'top.sls'), 'w') as f:
            f.write(json.dumps(top_sls_output, indent=4) + '\n')

        if args.dry_run:
            print('Temporary directory is at: ' + d)
            print('Press any key to stop...')
            input()
            result = 0
        else:
            if args.positional and args.positional[0] == '--':
                args.positional = args.positional[1:]
            cmd = ['salt-call', '--local', '--config-dir=%s' % d,
                   'state.highstate'] + args.positional
            print('Executing: ' + ' '.join(cmd))
            result = subprocess.call(cmd)

    return result


if __name__ == '__main__':
    sys.exit(main(sys.argv))
