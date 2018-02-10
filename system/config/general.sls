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
      - systemd
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

# Create the teensy group.
teensy:
  group.present:
    - system: false

# Add the upstream teensy udev rules.
# Taken from http://www.pjrc.com/teensy/ and slightly modified.
setup_teensy_udev_rules:
  file.managed:
    - name: /etc/udev/rules.d/49-teensy.rules
    - mode: 644
    - contents: |
        ATTRS{idVendor}=="16c0", ATTRS{idProduct}=="04[789B]?", ENV{ID_MM_DEVICE_IGNORE}="1"
        ATTRS{idVendor}=="16c0", ATTRS{idProduct}=="04[789A]?", ENV{MTP_NO_PROBE}="1"
        SUBSYSTEMS=="usb", ATTRS{idVendor}=="16c0", ATTRS{idProduct}=="04[789ABCD]?", MODE:="0660", GROUP="teensy"
        KERNEL=="ttyACM*", ATTRS{idVendor}=="16c0", ATTRS{idProduct}=="04[789B]?", MODE:="0660", GROUP="teensy"
    - require:
      - group: teensy

# Reload udev rules after they changed.
reload_teensy_udev_rules:
  cmd.run:
    - name: udevadm control --reload-rules
    - onchanges:
      - file: /etc/udev/rules.d/49-teensy.rules
