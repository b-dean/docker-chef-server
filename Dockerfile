# -*- conf -*-

FROM ubuntu:18.04
MAINTAINER Maciej Pasternacki <maciej@3ofcoins.net>

EXPOSE 80 443
VOLUME /var/opt/opscode

ARG SERVER_VERSION=12.19.31
ARG CLIENT_VERSION=14.15.6

COPY install.sh /tmp/install.sh

RUN [ "/bin/bash", "/tmp/install.sh" ]

COPY init.rb /init.rb
COPY chef-server.rb /.chef/chef-server.rb
COPY logrotate /opt/opscode/sv/logrotate
COPY knife.rb /etc/chef/knife.rb
COPY backup.sh /usr/local/bin/chef-server-backup

ENV KNIFE_HOME /etc/chef

# set this at runtime to the public url for the chef server
ENV PUBLIC_URL=

HEALTHCHECK \
  CMD ["/usr/bin/chef-server-ctl", "status"]

CMD [ "/opt/opscode/embedded/bin/ruby", "/init.rb" ]
