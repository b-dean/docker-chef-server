# -*- conf -*-

ARG BASE_IMAGE=ubuntu
ARG BASE_TAG=18.04
FROM ${BASE_IMAGE}:${BASE_TAG}

EXPOSE 80 443

ARG SERVER_VERSION=12.19.31
ARG OMNITRUCK_URL=https://omnitruck.chef.io/install.sh
ARG SERVER_PROJECT=chef-server
ARG SERVER_SUBDIR=opscode
ARG SERVER_USER=opscode

VOLUME /var/opt/${SERVER_SUBDIR}

ENV \
  LANG=en_US.UTF-8 \
  LANGUAGE=en_US:en \
  LC_ALL=en_US.UTF-8

COPY init.rb /init.rb
COPY chef-server.rb /.chef/chef-server.rb
COPY logrotate /.chef/sv/logrotate
COPY knife.rb /etc/chef/knife.rb
COPY backup.sh /usr/local/bin/chef-server-backup

RUN --mount=source=./install.sh,target=/tmp/install.sh [ "/bin/bash", "/tmp/install.sh" ]

ENV \
    KNIFE_HOME=/etc/chef \
    PATH="/opt/${SERVER_SUBDIR}/bin:/opt/${SERVER_SUBDIR}/embedded/bin:${PATH}" \
    # set this at runtime to the public url for the chef server
    PUBLIC_URL="" \
    # if using Chef Infra Server 13 or newer you need to accept the license
    CHEF_LICENSE=""

HEALTHCHECK \
  CMD ["/usr/bin/chef-server-ctl", "status"]

CMD [ "/opt/opscode/embedded/bin/ruby", "/init.rb" ]

LABEL \
  org.opencontainers.image.authors="Ben.Dean@Finvi.com" \
  org.opencontainers.image.url="https://github.com/b-dean/docker-chef-server/" \
  org.opencontainers.image.version="$SERVER_VERSION"
