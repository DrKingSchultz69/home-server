#!/bin/sh
# One-time install of the join requests service (needs sudo). Run on homeserver:
#   sudo sh ~/Server/requests/install.sh
set -eu

# Its own system user: no home folder, no login shell.
id joinreq >/dev/null 2>&1 || useradd --system --no-create-home --shell /usr/sbin/nologin joinreq

install -m 0644 /home/palani/Server/requests/join-requests.service /etc/systemd/system/join-requests.service
systemctl daemon-reload
systemctl enable --now join-requests.service
sleep 2
systemctl --no-pager --lines=5 status join-requests.service
