#!/bin/bash
# =================WRK HTTP LOAD TESTING (Containerized)=================
# Targets the remote Nginx container defined in Docker Compose
# =======================================================================

LOG_DIR="benchmark_logs"
LOG_FILE="$LOG_DIR/wrk_results.csv"
WRK_BIN=$(which wrk)
ITERATIONS=5

# Configuration
# In Docker Compose, the Nginx container is reachable via its service name or localhost (if net=host)
TARGET_URL=${TARGET_URL:-"http://localhost:80"}

# Test configurations
THREAD_COUNTS=(1 2 4)
CONNECTION_COUNTS=(10 50 100)
DURATION="10s"

mkdir -p "$LOG_DIR"

if [ -z "$WRK_BIN" ]; then
    echo "ERROR: wrk not found."
    exit 1
fi

# Function to convert wrk time/size units to standard numbers
convert_to_ms() {
    local value=$1
    if [[ $value == *us ]]; then echo "$value" | sed 's/us//' | awk '{print $1/1000}';
    elif [[ $value == *s ]]; then echo "$value" | sed 's/s//' | awk '{print $1*1000}';
    else echo "$value" | sed 's/ms//'; fi
}

convert_to_mb() {
    local value=$1
    if [[ $value == *KB ]]; then echo "$value" | sed 's/KB//' | awk '{print $1/1024}';
    elif [[ $value == *GB ]]; then echo "$value" | sed 's/GB//' | awk '{print $1*1024}';
    else echo "$value" | sed 's/MB//'; fi
}

# Ensure CSV header
if [ ! -f "$LOG_FILE" ]; then
    echo "timestamp,test_iteration,threads,connections,duration,requests_total,requests_per_sec,transfer_per_sec_mb,latency_avg_ms,latency_stdev_ms,latency_max_ms" > "$LOG_FILE"
fi

echo "Starting WRK Load Test against: $TARGET_URL"
echo "------------------------------------------------"

# Wait for Target
until curl -s "$TARGET_URL" > /dev/null; do
  echo "Waiting for $TARGET_URL..."
  sleep 2
done

for threads in "${THREAD_COUNTS[@]}"; do
    for connections in "${CONNECTION_COUNTS[@]}"; do
        echo "Config: T:$threads | C:$connections"

        for iter in $(seq 1 $ITERATIONS); do
            TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
            WRK_OUTPUT=$($WRK_BIN -t$threads -c$connections -d$DURATION --latency "$TARGET_URL" 2>&1)

            if [ $? -eq 0 ]; then
                REQ_TOTAL=$(echo "$WRK_OUTPUT" | grep "requests in" | awk '{print $1}')
                REQ_SEC=$(echo "$WRK_OUTPUT" | grep "Requests/sec:" | awk '{print $2}')
                TRANS_SEC=$(echo "$WRK_OUTPUT" | grep "Transfer/sec:" | awk '{print $2}')

                TRANS_MB=$(convert_to_mb "$TRANS_SEC")

                L_AVG=$(echo "$WRK_OUTPUT" | grep "Latency" | head -1 | awk '{print $2}')
                L_STD=$(echo "$WRK_OUTPUT" | grep "Latency" | head -1 | awk '{print $3}')
                L_MAX=$(echo "$WRK_OUTPUT" | grep "Latency" | head -1 | awk '{print $4}')

                L_AVG_MS=$(convert_to_ms "$L_AVG")
                L_STD_MS=$(convert_to_ms "$L_STD")
                L_MAX_MS=$(convert_to_ms "$L_MAX")

                echo "$TIMESTAMP,$iter,$threads,$connections,$DURATION,$REQ_TOTAL,$REQ_SEC,$TRANS_MB,$L_AVG_MS,$L_STD_MS,$L_MAX_MS" >> "$LOG_FILE"
                echo "  Iter $iter: $REQ_SEC req/s"
            else
                echo "  Iter $iter: FAILED"
            fi
            sleep 2
        done
    done
done
