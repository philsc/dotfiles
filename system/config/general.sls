{% set pip_packages = [
  'autopep8',
  'humanfriendly',
] -%}
{% set llvm_version = '3.8' -%}
{% set vagrant_version = '1.8.1' -%}

# Install the gpg key for LLVM's deb packages.
apt_key_llvm:
  file.managed:
    - name: /etc/apt/trusted.gpg.d/llvm-snapshot.gpg.key
    - source: http://llvm.org/apt/llvm-snapshot.gpg.key
    - source_hash: sha256=ce6eee4130298f79b0e0f09a89f93c1bc711cd68e7e3182d37c8e96c5227e2f0

apt_key_llvm_added:
  cmd.run:
    - name: apt-key add /etc/apt/trusted.gpg.d/llvm-snapshot.gpg.key
    - require:
      - file: apt_key_llvm
    - unless:
      - apt-key list | grep -q '4096R/AF4F7421 2013-03-11'

# Install the llvm apt configuration.
apt_sources_llvm:
  file.managed:
    - name: /etc/apt/sources.list.d/llvm-3.8.list
    - contents: |
        deb http://llvm.org/apt/{{ grains['oscodename'] }}/ llvm-toolchain-{{ grains['oscodename'] }} main
        deb-src http://llvm.org/apt/{{ grains['oscodename'] }}/ llvm-toolchain-{{ grains['oscodename'] }} main
    - require:
      - cmd: apt_key_llvm_added

# Install regular system packages.
general_packages:
  pkg.installed:
    - pkgs:
      - acpi
      - debootstrap
      - clang-format-{{ llvm_version }}
      - clang-{{ llvm_version }}
      - colordiff
      - gdebi-core
      - git
      - keychain
      - pass
      - python
      - python-pip
      - python3
      - python3-pip
      - subversion
      - tmux
      - vim
      - vpnc
    - reload_modules: true
    - require:
      - file: apt_sources_llvm

# Download the version of vagrant in the form of a .deb package.
vagrant_download:
  file.managed:
    - name: /opt/downloads/vagrant_{{ vagrant_version }}_x86_64.deb
    - source: https://releases.hashicorp.com/vagrant/{{ vagrant_version }}/vagrant_{{ vagrant_version }}_x86_64.deb
    - source_hash: sha256=ed0e1ae0f35aecd47e0b3dfb486a230984a08ceda3b371486add4d42714a693d
    - require:
      - file: download_dir

vagrant_install:
  pkg.installed:
    - sources:
      - vagrant: /opt/downloads/vagrant_{{ vagrant_version }}_x86_64.deb
    - require:
      - file: vagrant_download

# Install all the pip packages.
{% for pip_pkg in pip_packages %}
{{ pip_pkg }}:
  pip.installed:
    - bin_env: /usr/bin/pip3
    - require:
      - pkg: general_packages
{% endfor %}

# Set up some symlinks.
{% for llvm_target in ['clang-format', 'clang-format-diff', 'clang++'] %}
symlink_{{ llvm_target }}:
  file.symlink:
    - name: /usr/bin/{{ llvm_target }}
    - target: /usr/bin/{{ llvm_target }}-{{ llvm_version }}
{% endfor %}

# Map Caps-Lock to Control in the virtual terminal.
setup_keymaps:
  cmd.run:
    - name: sed -i 's#XKBOPTIONS=".*"#XKBOPTIONS="ctrl:nocaps"#' /etc/default/keyboard
    - user: root
    - unless:
      - grep -q 'XKBOPTIONS="ctrl:nocaps"' /etc/default/keyboard

apply_keymaps:
  cmd.wait:
    - name: dpkg-reconfigure -f noninteractive  -phigh console-setup
    - user: root
    - watch:
      - cmd: setup_keymaps
    - env:
        DEBIAN_FRONTEND: noninteractive
        DEBCONF_NONINTERACTIVE_SEEN: "true"
