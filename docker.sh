#!/bin/bash
docker compose -f /home/samsaju/cloud-stuff/docker-compose.yml up --abort-on-container-exit
docker compose -f /home/samsaju/cloud-stuff/docker-compose.yml down