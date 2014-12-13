# Install the latest docker.io package.
docker.io:
  pkgrepo.managed:
    - humanname: Docker PPA
    - name: deb https://get.docker.io/ubuntu docker main
    - dist: docker
    - file: /etc/apt/sources.list.d/docker.list
    - keyid: d8576a8ba88d21e9
    - keyserver: keyserver.ubuntu.com

  pkg.latest:
    - refresh: true

# Install the helper scripts nsenter and docker-enter.
nsenter:
  cmd.run:
    - name: docker run -v /usr/local/bin:/target jpetazzo/nsenter
    - unless: test -x /usr/local/bin/nsenter
