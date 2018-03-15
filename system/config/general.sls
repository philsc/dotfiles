# Set up backports.
{% if grains['os'] == 'Debian' %}
apt_backports:
  file.managed:
    - name: /etc/apt/sources.list.d/backports.list
    - user: root
    - group: root
    - mode: 644
    - contents: |
        deb http://ftp.debian.org/debian {{ grains['oscodename'] }}-backports main contrib
{% endif %}

# Install regular system packages.
general_packages:
  pkg.installed:
    - pkgs:
      - acpi
      - apt-transport-https
      - colordiff
      - curl
      - gdebi-core
      - git
{% if grains['oscodename'] == 'jessie' %}
      - gnupg-curl
{% else %}
      - gnupg1-curl
{% endif %}
      - keychain
      - openssh-client
      - pass
      - sudo
      - tmux
      - vim-nox
    - reload_modules: true

# Map Caps-Lock to Control in the virtual terminal.
setup_keymaps:
  cmd.run:
    - name: sed -i 's#XKBOPTIONS=".*"#XKBOPTIONS="ctrl:nocaps"#' /etc/default/keyboard
    - runas: root
    - unless:
      - grep -q 'XKBOPTIONS="ctrl:nocaps"' /etc/default/keyboard

apply_keymaps:
  cmd.wait:
    - name: dpkg-reconfigure -f noninteractive  -phigh console-setup
    - runas: root
    - watch:
      - cmd: setup_keymaps
    - env:
        DEBIAN_FRONTEND: noninteractive
        DEBCONF_NONINTERACTIVE_SEEN: "true"

# Disable the PC speaker beep.
disable_pcspkr:
  file.managed:
    - name: /etc/modprobe.d/pcspkr.conf
    - mode: 644
    - contents: |
        blacklist pcspkr
