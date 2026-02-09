#!/bin/bash
docker compose up -f docker-compose.yml --abort-on-container-exit
docker compose down