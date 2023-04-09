#!/bin/sh

while :; do /usr/bin/inotifywait --event create /mnt/campfs/media/phone-pictures && /usr/bin/docker-compose -f /mnt/campfs/docker/hosts/lucas/docker-compose.photoprism.yml exec photoprism photoprism import; done
