# Set up a gitolite instance.

# TODO(phil): Upgrade these to the dockerng module when it makes sense.

gitolite_image_build:
  docker.built:
    - path: third_party/dockerfiles/gitolite/

gitolite:
  docker.running:
    - container: gitolite_image_build
    - image: gitolite_image_build:latest
    - volumes:
      - {{ pillar['gitolite_volume'] }}:/home/git/repositories
    - watch:
      - docker: gitolite_image_build
    - ports:
      - "22/tcp":
            HostIp: "0.0.0.0"
            HostPort: "778"
