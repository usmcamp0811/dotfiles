#!/bin/sh

while :; do /usr/bin/inotifywait --event create /mnt/srv/lejeune/lejeune/phone-pictures && /usr/bin/docker-compose -f /home/mcamp/docker/docker-compose.photoprism.yml exec photoprism photoprism import; done 
