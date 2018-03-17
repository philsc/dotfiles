{% set units = ['data', 'var-lib-docker'] %}

{% for unit in units %}
/{{ unit|replace("-", "/") }}:
  file.directory:
    - user: root
{% endfor %}

{% for unit in units %}
mount_unit_{{ unit }}:
  file.managed:
    - name: /etc/systemd/system/{{ unit }}.mount
    - source:
      - salt://gallifrey/{{ unit }}.mount

  service.enabled:
    - name: {{ unit }}.mount
{% endfor %}

service.systemctl_reload:
  module.run:
    - onchanges:
{% for unit in units %}
      - file: /etc/systemd/system/{{ unit }}.mount
{% endfor %}

mount_data:
  mount.mounted:
    - name: /data
    - device: /dev/sdc
    - fstype: auto
    - persist: False
    - opts: defaults
    - require:
      - file: /data
