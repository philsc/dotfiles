# Set up a minetest server.

{{ pillar['minetest_volume'] }}:
  file.directory:
    - user: 3000
    - group: 3000
    - dir_mode: 700
    - file_mode: 600

{% for subfolder in ['worlds', 'config', 'logs', 'mods'] %}
{{ pillar['minetest_volume'] }}/{{ subfolder }}:
  file.directory:
    - user: 3000
    - group: 3000
    - require:
      - file: {{ pillar['minetest_volume'] }}
{% endfor %}

minetest_image_build:
  dockerng.image_present:
    - build: system/dockerfiles/minetest-server/

minetest:
  dockerng.running:
    - image: minetest_image_build:latest
    - binds:
      - {{ pillar['minetest_volume'] }}/worlds:/home/minetest/worlds:rw
      - {{ pillar['minetest_volume'] }}/config:/home/minetest/config:rw
      - {{ pillar['minetest_volume'] }}/mods:/home/minetest/.minetest/mods:rw
      - {{ pillar['minetest_volume'] }}/logs:/var/log/minetest:rw
    - watch:
      - dockerng: minetest_image_build
    - port_bindings:
      - '30000:30000/udp'
    - memory: 1500M
    - require:
      - file: {{ pillar['minetest_volume'] }}/worlds
      - file: {{ pillar['minetest_volume'] }}/config
      - file: {{ pillar['minetest_volume'] }}/logs
      - file: {{ pillar['minetest_volume'] }}/mods
