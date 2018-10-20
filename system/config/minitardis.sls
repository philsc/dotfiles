# Quirks for my laptop.

# VLC has trouble playing video by default. Gotta point it at a different mode
# to use. Works great after that.
vlc_fixup:
  file.managed:
    - name: /usr/local/bin/vlc
    - mode: 755
    - user: root
    - group: root
    - contents: |
        #!/bin/bash
        exec /usr/bin/vlc --avcodec-hw=vaapi "$@"
