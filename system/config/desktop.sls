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
      - xfonts-terminus
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

# On my laptops I need to add this little X11 config snippet so that the
# backlight controls work properly. Without this snippet I can't use
# xbacklight(1) to control the backlight.
{% if grains['host'] == 'minitardis' or grains['host'] == 'philipp-laptop' %}
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

# Enable bitmap fonts. No idea why they're disabled by default.
desktop_remove_disable_bitmap_fonts:
  file.absent:
    - name: /etc/fonts/conf.d/70-no-bitmaps.conf

desktop_remove_scale_bitmap_fonts:
  file.absent:
    - name: /etc/fonts/conf.d/10-scale-bitmap-fonts.conf

desktop_add_enable_bitmap_fonts:
  file.symlink:
    - name: /etc/fonts/conf.d/70-yes-bitmaps.conf
    - target: /usr/share/fontconfig/conf.avail/70-yes-bitmaps.conf
    - require:
      - file: desktop_remove_disable_bitmap_fonts
      - file: desktop_remove_scale_bitmap_fonts

desktop_fonts_reconfigure:
  cmd.run:
    - name: dpkg-reconfigure -f noninteractive fontconfig
    - onchanges:
      - file: desktop_add_enable_bitmap_fonts
