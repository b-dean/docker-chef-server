#!/bin/bash
set -exo pipefail

## You can update the versions from the release notes pages
# https://docs.chef.io/release_notes_server/
: ${SERVER_VERSION:=12.18.14}

: ${OMNITRUCK_URL:=https://omnitruck.chef.io/install.sh}
: ${SERVER_PROJECT:=chef-server}
: ${SERVER_SUBDIR:=opscode}
: ${SERVER_USER:=opscode}
: ${SERVER_PGUSER:=opscode-pgsql}

# Install prerequisites
export DEBIAN_FRONTEND=noninteractive
apt-get update -q --yes
apt-get install -q --yes logrotate vim-nox hardlink curl ca-certificates erlang-base iproute2 locales python3

# fix en_US.UTF-8 locale
echo 'LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8' > /etc/default/locale
echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen
locale-gen

# fake systemctl
curl -fsSL -o /usr/bin/systemctl https://raw.githubusercontent.com/gdraheim/docker-systemctl-replacement/refs/heads/master/files/docker/systemctl3.py
chmod 755 /usr/bin/systemctl


# Download and install Chef's packages
curl -fsSL ${OMNITRUCK_URL} | bash -s -- -P ${SERVER_PROJECT} -v ${SERVER_VERSION}

# Extra setup
mkdir -p /etc/cron.hourly
if [ ! -d /etc/init ]; then ln -sfv /etc/init.d/ /etc/init; fi
rm -rf /etc/opscode /etc/${SERVER_SUBDIR}
ln -sfv /var/opt/${SERVER_SUBDIR}/log /var/log/${SERVER_SUBDIR}
ln -sfv /var/opt/${SERVER_SUBDIR}/etc /etc/${SERVER_SUBDIR}
rm -rf /opt/${SERVER_SUBDIR}/sv
ln -sfv /var/opt/${SERVER_SUBDIR}/sv /opt/${SERVER_SUBDIR}/sv
mkdir -p /.chef/embedded/opensearch/config
mv /opt/${SERVER_SUBDIR}/embedded/service /.chef/embedded/
ln -sfv /var/opt/${SERVER_SUBDIR}/embedded/service /opt/${SERVER_SUBDIR}/embedded/service
ln -sfv /var/opt/${SERVER_SUBDIR}/embedded/opensearch/config /opt/${SERVER_SUBDIR}/embedded/opensearch/config
ln -sfv /var/opt/${SERVER_SUBDIR}/cache/omnibus /var/cache/omnibus
if [[ "${SERVER_SUBDIR}" != "opscode" ]]; then
  ln -sfv /etc/${SERVER_SUBDIR} /etc/opscode
  ln -sfv /opt/${SERVER_SUBDIR} /opt/opscode
  ln -sfv /var/log/${SERVER_SUBDIR} /var/log/opscode
  ln -sfv /var/opt/${SERVER_SUBDIR} /var/opt/opscode
fi

# make users
useradd -lrUM -s /bin/sh -d /var/opt/${SERVER_SUBDIR}/postgresql ${SERVER_PGUSER}
useradd -lrUM -s /bin/sh -d /var/opt/${SERVER_SUBDIR} ${SERVER_USER}

# Cleanup
rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*
