#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

# Update package list
sudo apt-get update

# Core tools
sudo apt-get install -y \
  sysbench \
  iperf3 \
  fio \
  iputils-ping \
  qperf \
  stress-ng \
  python3-pip \
  build-essential \
  libssl-dev \
  git \
  unzip \
  curl \
  locust \
  nginx

# Install wrk
cd /tmp
rm -rf wrk
git clone https://github.com/wg/wrk.git
cd wrk
make
sudo cp wrk /usr/local/bin/

# Ensure sbin paths are in bashrc (for future shells)
LINE='export PATH="/usr/local/sbin:/usr/sbin:/sbin:$PATH"'
grep -qxF "$LINE" ~/.bashrc || echo "$LINE" >> ~/.bashrc

# Install Ookla Speedtest
curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | sudo bash
sudo apt-get install -y speedtest

sudo apt update
sudo apt install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update

mkdir /home/samsaju/benchmark_logs