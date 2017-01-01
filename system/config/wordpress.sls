# Set up a wordpress instance.

# TODO(phil): Upgrade these to the dockerng module when it makes sense.

nginx_image:
  docker.pulled:
    - name: nginx
    - tag: latest
    - require:
      - service: docker

nginx_container:
  docker.installed:
    - image: nginx:latest
    - watch:
      - docker: nginx_image

nginx:
  docker.running:
    - container: nginx_container
    - image: nginx:latest
    - ports:
      - "80/tcp":
            HostIp: "0.0.0.0"
            HostPort: "80"
    - volumes:
      - {{ pillar['static_nginx_volume'] }}
    - watch:
      - docker: nginx_container
