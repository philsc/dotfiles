# Upgrade the existing packages.
pkg.upgrade:
  module.run:
    - refresh: true

# Install the necessary packages.
packages:
  pkg.installed:
    - pkgs:
      - vim
      - colordiff
      - subversion
      - git
      - markdown
      - python3
      # 32-bit compatibility libraries.
      - lib32z1
      - lib32ncurses5
      - lib32bz2-1.0
      # Samba so that other machines can ping us by hostname.
      - samba
