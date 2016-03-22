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

{% if grains['oscodename'] == 'jessie' %}
# Install the gpg key for saltstack's deb packages.
apt_key_saltstack:
  file.managed:
    - name: /etc/apt/trusted.gpg.d/saltstack.gpg.key
    - source: http://debian.saltstack.com/debian-salt-team-joehealy.gpg.key
    - source_hash: sha256=145157dfb896f7a0c1f390c6f72e6d092fbbfaf4374b510d4c7828c4177ab476

apt_key_saltstack_added:
  cmd.run:
    - name: apt-key add /etc/apt/trusted.gpg.d/saltstack.gpg.key
{% if grains['saltversion'] >= '2014.7' %}
    - unless:
      - apt-key list | grep -q '4096R/F2AE6AB9 2013-04-29'
{% endif %}
    - require:
      - file: apt_key_saltstack

apt_sources_saltstack:
  file.managed:
    - name: /etc/apt/sources.list.d/saltstack.list
    - contents: |
        deb http://debian.saltstack.com/debian jessie-saltstack main
    - require:
      - cmd: apt_key_saltstack_added

saltstack_packages:
  pkg.installed:
    - pkgs:
      - salt-minion
    - reload_modules: true
    - require:
      - file: apt_sources_saltstack
{% endif %}
