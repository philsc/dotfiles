# Set up a gitolite instance.

gitolite_image_build:
  dockerng.image_present:
    - build: system/third_party/dockerfiles/gitolite/

gitolite:
  dockerng.running:
    - image: gitolite_image_build:latest
    - binds:
      - {{ pillar['gitolite_volume'] }}:/home/git/repositories:rw
    - watch:
      - dockerng: gitolite_image_build
    - port_bindings:
      - '778:22'
    - memory: 64M
