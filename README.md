Chef Server
===========

This image runs
[Chef Server 12](https://community.chef.io/downloads/tools/infra-server),
[Chef Infra Server 15](https://docs.chef.io/server/), or
[Cinc Server 15](https://cinc.sh/download/#cinc-server).

The following images and tags are available:

- [`ghcr.io/b-dean/chef-server`](https://github.com/b-dean/docker-chef-server/pkgs/container/chef-server)
    - `12.19.31`
    - `latest`, `15.10.12`
- [`ghcr.io/b-dean/cinc-server`](https://github.com/b-dean/docker-chef-server/pkgs/container/cinc-server)
    - `latest`, `15.10.12`

Git repository containing the Dockerfile lives at
https://github.com/b-dean/docker-chef-server/

Environment Variables
---------------------

- `PUBLIC_URL` - should be configured to a full public URL of the
  endpoint (e.g. `https://chef.example.com`)
- `OC_ID_ADMINISTRATORS` - if set, it should be a comma-separated
  list of users that will be allowed to add oc_id applications
- `FORCE_RECONFIGURE` - if set, it will force reconfigure to run
- `CHEF_LICENSE` - If you use Chef server 13 or newer, you need to
  have a license from [Progress Chef](https://chef.io).
  Valid values are `accept` or `accept-no-persist`

Ports
-----

Ports 80 (HTTP) and 443 (HTTPS) are exposed.

Volumes
-------

`/var/opt/opscode` directory, that holds all Chef server data, is a
volume. Directories `/var/log/opscode` and `/etc/opscode` are linked
there as, respectively, `log` and `etc`.

If there is a file `etc/chef-server-local.rb` in this volume, it will
be read at the end of `chef-server.rb` and it can be used to customize
Chef Server's settings.

Signals
-------

 - `docker kill -s HUP $CONTAINER_ID` will run `chef-server-ctl reconfigure`
 - `docker kill -s USR1 $CONTAINER_ID` will run `chef-server-ctl status`

Usage
-----

### Prerequisites and first start

First start will automatically run `chef-server-ctl
reconfigure`. Subsequent starts will not run `reconfigure`, unless
file `/var/opt/opscode/bootstrapped` has been deleted or hostname has
changed (i.e. on upgrade). You can run `reconfigure` (e.g. after
editing `etc/chef-server.rb`) using `docker-enter` or by sending
SIGHUP to the container: `docker kill -HUP $CONTAINER_ID`.

### Upgrading

Just kill the old container and start a new one using the same data
volume. The image will automatically run `chef-server-ctl upgrade`
when version of `chef-server-core` package changes. You will need to
run `chef-server-ctl cleanup` afterwards.

If the repository is lagging, to build a new image with new Chef
Server version, all you need to do is update the variables on top of
the [`install.sh`](install.sh) script.

### Maintenance commands

Chef Server's design makes it impossible to wrap it cleanly in
a container - it will always be necessary to run custom
commands. While some of the management commands may work with linked
containers with varying amount of ugly hacks, it is simpler to have
one way of interacting with the software that is closest to
interacting with a Chef Server installed directly on host (and thus
closest to supported usage).

This means you need Docker 1.3+ with `docker exec` feature, and run
`chef-server-ctl` commands like:

    docker exec $CONTAINER_ID chef-server-ctl status
    docker exec $CONTAINER_ID chef-server-ctl user-create …
    docker exec $CONTAINER_ID chef-server-ctl org-create …
    docker exec $CONTAINER_ID chef-server-ctl …

If you have Docker older than 1.3 and can't upgrade, you should be
able to get by with `nsenter` utility and
[`docker-enter`](https://github.com/jpetazzo/nsenter) script by
[Jérôme Petazzoni](https://github.com/jpetazzo) on your Docker
host. The easiest way to install it is to run the installer Docker
image:

    docker run --rm -v /usr/local/bin:/target jpetazzo/nsenter

Then, you can use the `docker-enter` script to run `chef-server-ctl`
commands:

    docker-enter $CONTAINER_ID chef-server-ctl …

### Publishing the endpoint

This container is not supposed to listen on a publically available
port. It is very strongly recommended to use a proxy server, such as
[nginx](http://nginx.org/), as a public endpoint.

Unfortunately, Chef's logic for figuring out the absolute URL of
various pieces (oc_id, bookshelf, erchef API, etc) for links and
redirects is twisted and fragile. There are `chef-server.rb` settings,
but some pieces insist on using the `Host:` header of the request, and
it doesn't seem possible to use plain HTTP endpoint and have the Chef
Server generate HTTPS redirects everywhere.

The main setting you need to configure is `PUBLIC_URL` environment
variable. It needs to contain full public URL, as seen by `knife` and
`chef-client` (e.g. `PUBLIC_URL=https://chef-api.example.com/`).

Then, you need to make sure that the proxy passes proper `Host:`
header to the Chef Server, and talks with the Chef Server on
the same protocol that the final endpoint will use (i.e. proxy that
listens on HTTPS would need to use Chef Server's self-signed HTTPS
endpoint; proxy that listens on plain HTTP would need to talk to HTTP
endpoint).

If you prefer to avoid overhead of encrypting the connection between
proxy and the Chef Server, it *should* be sufficient to rewrite the
`Location:` headers (`proxy_redirect` in nginx, `ProxyPassReverse` in
Apache). It works for me, but I can't guarantee you won't bump into
a wrong URL generated by the server.

A sample nginx configuration looks like this:

    server {
      listen 443 ssl;
      server_name chef.example.com;
      ssl_certificate /path/to/chef.example.com.pem;
      ssl_certificate_key /path/to/chef.example.com.key;
      client_max_body_size 4G;
      location / {
          proxy_pass http://127.0.0.1:5000;
          proxy_set_header Host $host;
          proxy_set_header X-Forwarded-Proto https;
          proxy_redirect default;
          proxy_redirect http://chef.example.com https://chef.example.com;
      }
    }

### Backup and restore

    $ docker exec chef-server chef-server-backup

Backup will be created in `/var/opt/opscode/backup/latest`, and all
previous backups will be in their own timestamped directories. Backups
will use hardlinks to share unchanged files. The backups will take
form of JSON files with user and organization details, and each
organization's chef repository dump generated with `knife download`.

There is no full restore script yet; you'll need to create orgs &
users based on JSON files, and then use `knife upload` to upload each
organization's data separately. The restore script is being worked on,
but some pieces can't be restored (in particular, users' passwords),
and other pieces seem tricky (in particular, ACLs).

Alternatively, one can take a binary backup of data volume (it is not
possible to read anything from such backup without starting up whole
Chef server, and it takes much more disk space, though):

1. `docker stop chef-server`
2. Archive `/var/opt/opscode` volume (delete the `bootstrapped` file
   from the archive to force `chef-server-ctl reconfigure` run on the
   new container)
3. `docker start chef-server`

Same thing works for upgrades: just reuse container, remembering to
remove the `bootstrapped` file. You may also need to remove the
symlinks in `/var/opt/opscode/service` and/or run `chef-server-ctl
upgrade` via `docker exec`.

### Chef Plugins

**UNSUPPORTED.** No idea how to handle this (especially that this is
the point at which licensing issues start to occur). Most likely, a
separate image based off this one would be necessary.

Alternatives
------------

An alternative image is maintained at
https://github.com/trueability/docker-chef-server /
https://hub.docker.com/r/trueability/chef-server/ and it might be more
frequently updated than this one.
