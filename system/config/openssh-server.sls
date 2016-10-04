# Set up openssh-server with a more restrictive configuartion than default.
openssh-server:
  pkg.installed: []

  service.running:
    - name: ssh
    - require:
      - pkg: openssh-server
    - watch:
      - file: /etc/ssh/sshd_config

  file.managed:
    - name: /etc/ssh/sshd_config
    - source:
      - salt://sshd_config
    - user: root
    - group: root
    - mode: 644
    - require:
      - pkg: openssh-server
