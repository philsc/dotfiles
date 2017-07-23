# Install docker from the repo on the machine.
apt_key_docker_added:
  cmd.run:
    - name: apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
    - unless:
      - apt-key list | grep -q '4096R/2C52609D 2015-07-14'

# Install the docker apt configuration.
apt_sources_docker:
  file.managed:
    - name: /etc/apt/sources.list.d/docker.com.list
    - contents: |
        deb https://apt.dockerproject.org/repo debian-{{ grains['oscodename'] }} main
    - require:
      - cmd: apt_key_docker_added

# Install the packages.
docker_packages:
  pkg.installed:
    - pkgs:
      # Use 1.11.2 since we have an old version of salt which means that we
      # have to use an older version of docker-py.
      - docker-engine: 1.11.2-0~jessie
    - require:
      - pkg: general_packages

{% for python_version in [2, 3] %}
docker_packages_python{{ python_version }}:
  pip.installed:
    - name: docker-py==1.2.3
    - bin_env: /usr/bin/pip{{ python_version }}
    - upgrade: False
    - require:
      - pkg: general_packages
{% endfor %}

docker_service:
  service.running:
    - name: docker
    - require:
      - pkg: docker_packages
    - watch:
      - pkg: docker_packages

