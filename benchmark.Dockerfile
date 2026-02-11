FROM ubuntu:latest

ENV DEBIAN_FRONTEND=noninteractive

# Install all tools except the nginx server itself
RUN apt-get update && apt-get install -y \
    sysbench iperf3 fio make \
    python3-pip python3-full build-essential libssl-dev \
    git unzip curl sudo jq && rm -rf /var/lib/apt/lists/*

RUN pip3 install locust --break-system-packages

# Build wrk
WORKDIR /tmp
RUN git clone https://github.com/wg/wrk.git && \
    cd wrk && make && cp wrk /usr/local/bin/

RUN apt-get update && apt-get install -y \
    gnupg1 \
    apt-transport-https \
    dirmngr \
    lsb-release \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /benchmarks
COPY ./scripts /benchmarks/scripts
RUN chmod +x /benchmarks/scripts/*.sh

ENTRYPOINT ["/benchmarks/scripts/master-docker.sh"]
