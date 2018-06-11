# Get checksums from
# https://archive.mozilla.org/pub/firefox/releases/<RELEASE>/SHA256SUMS
{% set firefox_version = '60.0.2' -%}
{% set firefox_hash = '90e5d4c106ae1756e6834593b357925f48a4e60c539e5f95f4bc323b5b7f4196' %}

{% set firefox_profile = 'n6hqy50j.default' %}

firefox:
  # Set up a firefox user/group for isolating browsing.
  # TODO(phil): Also set up SELinux or something.
  group.present:
    - system: False

  user.present:
    - fullname: Firefox
    - home: /home/firefox
    - shell: /bin/false
    - gid: firefox
    - groups:
      - pulse-access
      - video
    # Generated via:
    # python -c 'import crypt; print(crypt.crypt(PASS, "$6$SALTsalt$"));'
    - password: $6$SALTsalt$s8qZV0HnE1jX3rN3Z//Fic24K7fzyEBVCvnWXdsUOxXrR8lpYgfQ/3Y1psLpiRZZGx7MeOC/GWdtRi49Niejx/
    - require:
      - group: firefox

  archive.extracted:
    - name: /opt
    - source: https://download-installer.cdn.mozilla.net/pub/firefox/releases/{{ firefox_version }}/linux-x86_64/en-US/firefox-{{ firefox_version }}.tar.bz2
    - source_hash: sha256={{ firefox_hash }}
    - if_missing: /opt/firefox
{% if salt['pkg.version_cmp'](grains['saltversion'], '2016.11.0') >= 0 %}
    - source_hash_update: True
    - keep_source: False
{% else %}
    - archive_format: tar
    - keep: False
{% endif %}

# The following two files is my attempt to securely give the firefox user access
# to the X server. I know it's stupid to consider that this is actually secure,
# but it's slightly better than running these games as my own user.
firefox_launcher:
  file.managed:
    - name: /usr/bin/firefox-wrapper
    - mode: 755
    - contents: |
        #!/usr/bin/env bash
        set -e
        set -u
        readonly TEMP=/tmp/firefox-Xauthority
        cleanup() { rm -f "$TEMP"; }
        trap cleanup EXIT
        touch "$TEMP"
        chown :firefox "$TEMP"
        chmod 640 "$TEMP"
        xauth extract "$TEMP" "$DISPLAY"
        sudo -u firefox /usr/bin/firefox-wrapper-impl
    - require:
      - file: firefox_launcher_impl
      - file: firefox_permissions

firefox_launcher_impl:
  file.managed:
    - name: /usr/bin/firefox-wrapper-impl
    - mode: 755
    - contents: |
        #!/usr/bin/env bash
        set -e
        set -u
        readonly TEMP=/tmp/firefox-Xauthority
        unset XAUTHORITY
        xauth -i merge "$TEMP"
        /opt/firefox/firefox
        rm -f "$HOME"/.Xauthority

# This is necessary to make the X forwarding work without a password.
firefox_sudoers_d:
  file.directory:
    - name: /etc/sudoers.d
    - mode: 755

firefox_permissions:
  file.managed:
    - name: /etc/sudoers.d/firefox
    - mode: 440
    - contents: |
        # Allow members of the firefox group to run firefox.
        %firefox  ALL = (firefox) NOPASSWD: /usr/bin/firefox-wrapper-impl
    - require:
      - file: firefox_sudoers_d

{% for dir in [
    "",
    "extensions",
    "firefox",
    "firefox/" + firefox_profile,
    "systemextensionsdev",
] %}
firefox_dir_{{ dir }}:
  file.directory:
    - name: /home/firefox/.mozilla/{{ dir }}
    - mode: 700
    - user: firefox
    - group: firefox
{% endfor %}

firefox_profiles_ini:
  file.managed:
    - name: /home/firefox/.mozilla/firefox/profiles.ini
    - mode: 600
    - user: firefox
    - group: firefox
    - contents: |
        [General]
        StartWithLastProfile=1
        [Profile0]
        Name=default
        IsRelative=1
        Path={{ firefox_profile }}
        Default=1

firefox_userchrome_css:
  file.managed:
    - name: /home/firefox/.mozilla/firefox/{{ firefox_profile }}/chrome/userChrome.css
    - mode: 600
    - user: firefox
    - group: firefox
    - source:
      - salt://firefox/userChrome.css

firefox_treestyletab_css:
  file.managed:
    - name: /home/firefox/.mozilla/firefox/{{ firefox_profile }}//browser-extension-data/treestyletab@piro.sakura.ne.jp/storage.js
    - mode: 600
    - user: firefox
    - group: firefox
    - source:
      - salt://firefox/treestyletab_storage.json
    - template: jinja

# TODO(phil): Figure out how to merge userStyleRules.css into storage.js.
# Maybe do something like https://stackoverflow.com/questions/37842020/salt-text-file-to-variable-and-use-the-same-variable-in-state-file-to-findrepl
# Would need to figure out how to get a file from the salt server into a variable.
