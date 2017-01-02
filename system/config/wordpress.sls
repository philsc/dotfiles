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

# Disable nginx for now.
#nginx:
#  docker.running:
#    - container: nginx_container
#    - image: nginx:latest
#    - ports:
#      - "80/tcp":
#            HostIp: "0.0.0.0"
#            HostPort: "80"
#    - volumes:
#      - {{ pillar['static_nginx_volume'] }}
#    - watch:
#      - docker: nginx_container


# Install actual wordpress.
{% for image in ['mariadb', 'wordpress'] %}
{{ image }}_image:
  docker.pulled:
    - name: {{ image }}
    - tag: latest
    - require:
      - service: docker
{% endfor %}

mariadb_container:
  docker.installed:
    - image: mariadb:latest
    - environment:
      - MYSQL_ROOT_PASSWORD: {{ pillar['mariadb_root_password'] }}
    - watch:
      - docker: mariadb_image

wordpress_container:
  docker.installed:
    - image: wordpress:latest
    - environment:
      - WORDPRESS_DB_PASSWORD: {{ pillar['mariadb_root_password'] }}
    - watch:
      - docker: wordpress_image

mariadb_folder:
  file.directory:
    - name: {{ pillar['mariadb_static_volume'] }}
    - user: 999
    - group: docker
    - dir_mode: 750
    - file_mode: 640
    - require:
      - service: docker

mariadb:
  docker.running:
    - container: mariadb_container
    - image: mariadb:latest
    - volumes:
      - {{ pillar['mariadb_static_volume'] }}:/var/lib/mysql
    - watch:
      - docker: mariadb_container
    - require:
      - file: mariadb_folder

wordpress:
  docker.running:
    - container: wordpress_container
    - image: wordpress:latest
    - links:
        mariadb_container: mysql
    - ports:
      - "80/tcp":
            HostIp: "0.0.0.0"
            HostPort: "80"
      - "443/tcp":
            HostIp: "0.0.0.0"
            HostPort: "443"
    - watch:
      - docker: wordpress_container
