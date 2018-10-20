djmount_package:
  pkg.installed:
    - pkgs:
      - djmount
    - require:
      - pkg: general_packages

fuse_settings:
  file.managed:
    - name: /etc/fuse.conf
    - contents: |
        user_allow_other
    - require:
      - pkg: djmount_package

djmount:
  # Set up a user/group for isolating permissions.
  group.present:
    - system: False

  user.present:
    - fullname: djmount
    - home: /nonexistent
    - createhome: False
    - gid: djmount
    - shell: /usr/sbin/nologin
    - password: "*"
    - require:
      - group: djmount

  file.directory:
    - name: /opt/djmount/

# Install the djmount service file for autostarting.
djmount_service:
  file.managed:
    - name: /etc/systemd/system/djmount.service
    - contents: |
        [Unit]
        Description = DJMmount
        [Service]
        ExecStart=/usr/bin/djmount -o iocharset=utf8,allow_other /opt/djmount/
        Type=forking
        Restart=always
        StandardOutput=syslog
        StandardError=syslog
        SyslogIdentifier=djmount
        User=djmount
        Group=djmount
        [Install]
        WantedBy=multi-user.target
    - require:
      - file: djmount

  service.running:
    - name: djmount
    - enable: True
    - require:
      - file: djmount_service
