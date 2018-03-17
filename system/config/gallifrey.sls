{% set units = ['data', 'var-lib-docker'] %}

{% for unit in units %}
/{{ unit|replace("-", "/") }}:
  file.directory:
    - user: root
{% endfor %}

{% for unit in units %}
mount_{{ unit }}:
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
