FROM debian:stretch

MAINTAINER Philipp Schrader <philipp.schrader@gmail.com>

RUN echo deb http://ftp.debian.org/debian stretch-backports main contrib > /etc/apt/sources.list.d/backports.list
RUN apt-get update
RUN apt-get -y install locales
RUN apt-get -y install dumb-init
RUN apt-get -y install curl
RUN apt-get -y install unzip

RUN locale-gen en_US.UTF-8
RUN dpkg-reconfigure locales

RUN apt-get -t stretch-backports -y install minetest-server

RUN adduser --uid 3000 --system --group --shell /bin/sh minetest
RUN su minetest -c "mkdir /home/minetest/config/"
RUN su minetest -c "mkdir /home/minetest/worlds/"
RUN su minetest -c "mkdir /home/minetest/.minetest/"
RUN su minetest -c "mkdir /home/minetest/.minetest/mods/"

ADD ./init.sh /init
RUN chmod +x /init

VOLUME /home/minetest/worlds/
VOLUME /home/minetest/config/
VOLUME /home/minetest/.minetest/mods
VOLUME /var/log/minetest/

ENTRYPOINT ["/usr/bin/dumb-init"]
CMD ["/init"]

EXPOSE 30000
