{% set llvm_version = '6.0' -%}
{% set vagrant_version = '2.0.1' -%}

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
    - name: /etc/apt/sources.list.d/llvm.list
    - contents: |
        deb http://llvm.org/apt/{{ grains['oscodename'] }}/ llvm-toolchain-{{ grains['oscodename'] }}-{{ llvm_version }} main
        deb-src http://llvm.org/apt/{{ grains['oscodename'] }}/ llvm-toolchain-{{ grains['oscodename'] }}-{{ llvm_version }} main
    - require:
      - cmd: apt_key_llvm_added

# Install development system packages.
development_packages:
  pkg.installed:
    - pkgs:
      - debootstrap
      - clang-format-{{ llvm_version }}
      - clang-{{ llvm_version }}
      - cmake
      - debconf-utils
      - python
      - python-dev
      - python3
      - python3-dev
      - subversion
      - vpnc
    - reload_modules: true
    - require:
      - file: apt_sources_llvm

# Set up some symlinks.
{% for llvm_target in ['clang-format', 'clang-format-diff', 'clang++'] %}
symlink_{{ llvm_target }}:
  file.symlink:
    - name: /usr/bin/{{ llvm_target }}
    - target: /usr/bin/{{ llvm_target }}-{{ llvm_version }}
    - require:
      - pkg: development_packages
{% endfor %}

# Download the version of vagrant in the form of a .deb package.
vagrant_download:
  file.managed:
    - name: /opt/downloads/vagrant_{{ vagrant_version }}_x86_64.deb
    - source: https://releases.hashicorp.com/vagrant/{{ vagrant_version }}/vagrant_{{ vagrant_version }}_x86_64.deb
    - source_hash: sha256=2f9498a83b3d650fcfcfe0ec7971070fcd3803fad6470cf7da871caf2564d84f
    - require:
      - file: download_dir

vagrant_install:
  pkg.installed:
    - sources:
      - vagrant: /opt/downloads/vagrant_{{ vagrant_version }}_x86_64.deb
    - require:
      - file: vagrant_download


# Enable user namespaces.
userns_sysctl_file:
  file.managed:
    - name: /etc/sysctl.d/0-userns.conf
    - mode: 644
    - contents: |
        # Enable user namespaces. This is really useful for bazel.
        kernel.unprivileged_userns_clone = 1
