#!/bin/bash
set -exo pipefail

## You can update the versions from the release notes pages
# https://docs.chef.io/release_notes_server/
: ${SERVER_VERSION:=12.18.14}
# https://docs.chef.io/release_notes_client/
: ${CLIENT_VERSION:=14.6.47}

: ${OMNITRUCK_URL:=https://omnitruck.chef.io/install.sh}
: ${SERVER_PROJECT:=chef-server}
: ${CLIENT_PROJECT:=chef}
: ${SERVER_INSTALL_DIR:=/opt/opscode}

# Install prerequisites
export DEBIAN_FRONTEND=noninteractive
apt-get update -q --yes
apt-get install -q --yes logrotate vim-nox hardlink curl ca-certificates erlang-base iproute2 make gcc

# Download and install Chef's packages
curl -fsSL ${OMNITRUCK_URL} | bash -s -- -P ${SERVER_PROJECT} -v ${SERVER_VERSION}
curl -fsSL ${OMNITRUCK_URL} | bash -s -- -P ${CLIENT_PROJECT} -v ${CLIENT_VERSION}

# Extra setup
[[ "${SERVER_INSTALL_DIR}" == "/opt/opscode" ]] || ln -sfv ${SERVER_INSTALL_DIR} /opt/opscode
rm -rf /etc/opscode
mkdir -p /etc/cron.hourly
ln -sfv /var/opt/opscode/log /var/log/opscode
ln -sfv /var/opt/opscode/etc /etc/opscode
ln -sfv /opt/opscode/sv/logrotate /opt/opscode/service
ln -sfv /opt/opscode/embedded/bin/sv /opt/opscode/init/logrotate
if [ ! -d /etc/init ]; then ln -sfv /etc/init.d/ /etc/init; fi
chef-apply -e 'chef_gem "knife-opc"'
CLIENT_MAJOR=$(echo $CLIENT_VERSION | cut -f1 -d.)
(( "$CLIENT_MAJOR" < 17 )) || chef-apply -e "chef_gem('knife') { version('~> $CLIENT_MAJOR.0') }"

# Cleanup
cd /
apt-get autoremove -q -y make gcc
rm -rf /tmp/install.sh /var/lib/apt/lists/* /var/cache/apt/archives/*
