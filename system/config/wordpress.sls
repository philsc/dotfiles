# Set up a wordpress instance.

# TODO(phil): Upgrade these to the dockerng module when it makes sense.

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
    - volumes:
      - {{ pillar['wordpress_static_volume'] }}:/var/www/html
    - watch:
      - docker: wordpress_container

https_portal_image:
  docker.pulled:
    - name: steveltn/https-portal
    - tag: 1.0.1
    - require:
      - service: docker

https_portal_container:
  docker.installed:
    - image: steveltn/https-portal:1.0.1
    - environment:
      - DOMAINS: "chocolate-gypsy.com -> http://wordpress"
    - watch:
      - docker: https_portal_image

https_portal:
  docker.running:
    - container: https_portal_container
    - image: steveltn/https-portal:1.0.1
    - ports:
      - "80/tcp":
            HostIp: "0.0.0.0"
            HostPort: "80"
      - "443/tcp":
            HostIp: "0.0.0.0"
            HostPort: "443"
    - links:
        wordpress_container: wordpress
