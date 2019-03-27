# Install system packages for desktop systems.
desktop_packages:
  pkg.installed:
    - pkgs:
      - autocutsel
      - awesome
      - awesome-extra
      - fonts-liberation
      - pasystray
      - rxvt-unicode-256color
      - vim-gtk
      - xbacklight
      - xcape
      - xdotool
      - xsel
      - xserver-xephyr
      - xserver-xorg-input-synaptics
{% if grains['oscodename'] != 'jessie' %}
      - maim
      - slop
{% endif %}

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

# On my laptop I need to add this little X11 config snippet so that the
# backlight controls work properly. Without this snippet I can't use
# xbacklight(1) to control the backlight.
{% if grains['host'] == 'minitardis' %}
fixup_backlight_config:
  file.managed:
    - name: /etc/X11/xorg.conf
    - contents: |
        # File managed by Salt.
        Section "Device"
            Identifier  "Card0"
            Driver      "intel"
            Option      "Backlight"  "intel_backlight"
        EndSection
    - require:
      - pkg: desktop_packages
{% endif %}
