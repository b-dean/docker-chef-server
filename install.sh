#!/bin/bash
set -exo pipefail

## You can update the versions from the release notes pages
# https://docs.chef.io/release_notes_server/
: ${SERVER_VERSION:=12.18.14}
# https://docs.chef.io/release_notes_client/
: ${CLIENT_VERSION:=14.6.47}

OMNITRUCK_URL=https://omnitruck.chef.io/install.sh
SERVER_PROJECT=chef-server
CLIENT_PROJECT=chef

# Install prerequisites
export DEBIAN_FRONTEND=noninteractive
apt-get update -q --yes
apt-get install -q --yes logrotate vim-nox hardlink curl ca-certificates

# Download and install Chef's packages
curl -fsSL ${OMNITRUCK_URL} | bash -s -- -P ${SERVER_PROJECT} -v ${SERVER_VERSION}
curl -fsSL ${OMNITRUCK_URL} | bash -s -- -P ${CLIENT_PROJECT} -v ${CLIENT_VERSION}

# Extra setup
rm -rf /etc/opscode
mkdir -p /etc/cron.hourly
ln -sfv /var/opt/opscode/log /var/log/opscode
ln -sfv /var/opt/opscode/etc /etc/opscode
ln -sfv /opt/opscode/sv/logrotate /opt/opscode/service
ln -sfv /opt/opscode/embedded/bin/sv /opt/opscode/init/logrotate
chef-apply -e 'chef_gem "knife-opc"'

# Cleanup
cd /
rm -rf $tmpdir /tmp/install.sh /var/lib/apt/lists/* /var/cache/apt/archives/*
