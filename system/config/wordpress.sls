# Set up a wordpress instance.

# TODO(phil): Upgrade these to the dockerng module when it makes sense.

wordpress_container:
  docker.running:
    - image: wordpress
    - ports:
      - "8080/tcp":
          HostIp: ""
          HostPort: 80
    - environment:
      - WORDPRESS_DB_PASSWORD: {{ pillar['mysqldb_root_password'] }}
    - require:
      - service: docker_service
      - pip: docker_packages_python2
      - pip: docker_packages_python3

mysql_container:
  docker.running:
    - image: mariadb
    - environment:
      - MYSQL_ROOT_PASSWORD: {{ pillar['mysqldb_root_password'] }}
    - require:
      - service: docker_service
      - pip: docker_packages_python2
      - pip: docker_packages_python3
