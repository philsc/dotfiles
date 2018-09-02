# Set up a Minecraft server.

{{ pillar['minecraft_server_volume'] }}:
  file.directory:
    - user: 1000
    - group: 1000
    - dir_mode: 755

itzg/minecraft-server:latest:
  dockerng.image_present

minecraft_server:
  dockerng.running:
    - image: itzg/minecraft-server:latest
    - binds:
      - {{ pillar['minecraft_server_volume'] }}:/data:rw
    - watch:
      - dockerng: itzg/minecraft-server:latest
    - port_bindings:
      - '25565:25565'
    - memory: 1500M
    - environment:
      - EULA: "TRUE"
    - require:
      - file: {{ pillar['minecraft_server_volume'] }}
