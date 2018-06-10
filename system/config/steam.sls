steam:
  # Download and install steam.
  debconf.set:
    - data:
        steam/question: {'type': 'select', 'value': 'I AGREE'}
        steam/license: {'type': 'note', 'value': ''}

  pkg.installed:
    - sources:
      - steam-launcher: https://steamcdn-a.akamaihd.net/client/installer/steam.deb
    - require:
      - debconf: steam

  # Set up a steam user/group for isolating gameplay.
  group.present:
    - system: False

  user.present:
    - fullname: Steam
    - home: /home/steam
    - gid: steam
    - groups:
      - pulse-access
      - video
    # Generated via:
    # python -c 'import crypt; print(crypt.crypt(PASS, "$6$SALTsalt$"));'
    - password: $6$SALTsalt$X863t7VBm4Y09JZiTvgZOxD2RqBB/reAtHz6yraHdiUsJwfWHUgYlccIn1UDbimSd0Y/rrtPFC1Xp9U46mf4A1
    - require:
      - group: steam

# The following two files is my attempt to securely give the steam user access
# to the X server. I know it's stupid to consider that this is actually secure,
# but it's slightly better than running these games as my own user.
steam_launcher:
  file.managed:
    - name: /usr/bin/steam-wrapper
    - mode: 755
    - contents: |
        #!/usr/bin/env bash
        set -e
        set -u
        readonly TEMP=/tmp/steam-Xauthority
        cleanup() { rm -f "$TEMP"; }
        trap cleanup EXIT
        touch "$TEMP"
        chown :steam "$TEMP"
        chmod 640 "$TEMP"
        xauth extract "$TEMP" "$DISPLAY"
        sudo /bin/su - steam -c steam-wrapper-impl
    - require:
      - file: steam_launcher_impl
      - file: steam_permissions

steam_launcher_impl:
  file.managed:
    - name: /usr/bin/steam-wrapper-impl
    - mode: 755
    - contents: |
        #!/usr/bin/env bash
        set -e
        set -u
        readonly TEMP=/tmp/steam-Xauthority
        unset XAUTHORITY
        xauth -i merge "$TEMP"
        # Disable UI scaling.
        # TODO(phil): Figure out how to change this per-machine.
        export GDK_SCALE=1
        steam
        rm -f "$HOME"/.Xauthority

# This is necessary to make the X forwarding work without a password.
steam_sudoers_d:
  file.directory:
    - name: /etc/sudoers.d
    - mode: 755

steam_permissions:
  file.managed:
    - name: /etc/sudoers.d/steam
    - mode: 440
    - contents: |
        # Allow members of the steam group to run steam.
        %steam  ALL = NOPASSWD: /bin/su - steam -c steam-wrapper-impl
    - require:
      - file: steam_sudoers_d
