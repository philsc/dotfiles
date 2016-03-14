download_dir:
  file.directory:
    - name: /opt/downloads/
    - user: root
    - group: root
    - dir_mode: 755
    - file_mode: 644
    - recurse:
      - user
      - group
      - mode
