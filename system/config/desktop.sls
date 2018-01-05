# Install system packages for desktop systems.
desktop_packages:
  pkg.installed:
    - pkgs:
      - autocutsel
      - awesome
      - awesome-extra
      - fonts-liberation
      - rxvt-unicode-256color
      - vim-gtk
      - xbacklight
      - xsel
      - xserver-xephyr
      - xserver-xorg-input-synaptics

{% if grains['oscodename'] == 'jessie' %}
enable_awesome:
  cmd.run:
    - name: sed -i 's/NoDisplay=true/NoDisplay=false/' /usr/share/xsessions/awesome.desktop
    - runas: root
    - unless:
      - grep -q 'NoDisplay=false' /usr/share/xsessions/awesome.desktop
    - require:
      - pkg: desktop_packages
{% endif %}
