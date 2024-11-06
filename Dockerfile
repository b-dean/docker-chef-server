# -*- conf -*-

ARG BASE_IMAGE=ubuntu
ARG BASE_TAG=18.04
FROM ${BASE_IMAGE}:${BASE_TAG}

EXPOSE 80 443
VOLUME /var/opt/opscode

ARG SERVER_VERSION=12.19.31
ARG CLIENT_VERSION=14.15.6

ARG OMNITRUCK_URL=https://omnitruck.chef.io/install.sh
ARG SERVER_PROJECT=chef-server
ARG CLIENT_PROJECT=chef
ARG SERVER_INSTALL_DIR=/opt/opscode

# if using Chef Infra Client 15 or newer you need to accept the license to build
ARG CHEF_LICENSE=""

COPY install.sh /tmp/install.sh

RUN [ "/bin/bash", "/tmp/install.sh" ]

COPY init.rb /init.rb
COPY chef-server.rb /.chef/chef-server.rb
COPY logrotate /opt/opscode/sv/logrotate
COPY knife.rb /etc/chef/knife.rb
COPY backup.sh /usr/local/bin/chef-server-backup

ENV KNIFE_HOME=/etc/chef

# set this at runtime to the public url for the chef server
ENV PUBLIC_URL=

HEALTHCHECK \
  CMD ["/usr/bin/chef-server-ctl", "status"]

CMD [ "/opt/opscode/embedded/bin/ruby", "/init.rb" ]

LABEL \
  org.opencontainers.image.authors="Ben.Dean@Finvi.com" \
  org.opencontainers.image.url="https://github.com/b-dean/docker-chef-server/" \
  org.opencontainers.image.version="$SERVER_VERSION"
