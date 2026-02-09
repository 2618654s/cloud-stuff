#!/bin/bash
# =================WRK HTTP LOAD TESTING=================
# Tests HTTP server performance under various loads
# Requires: wrk (github.com/wg/wrk)
# ========================================================

LOG_DIR="benchmark_logs"
LOG_FILE="$LOG_DIR/wrk_results.csv"
WRK_BIN=$(which wrk)
ITERATIONS=5

# Configuration - UPDATE THESE
TARGET_URL="http://localhost:80"  # Your HTTP endpoint to test
# Test configurations (threads, connections, duration)
THREAD_COUNTS=(1 2 4)
CONNECTION_COUNTS=(10 50 100)
DURATION="10s"  # Duration of each test

mkdir -p "$LOG_DIR"

# Check if wrk is installed
if [ -z "$WRK_BIN" ]; then
    echo "ERROR: wrk not found. Install from github.com/wg/wrk"
    exit 1
fi

# Create CSV header
if [ ! -f "$LOG_FILE" ]; then
    echo "timestamp,test_iteration,threads,connections,duration,requests_total,requests_per_sec,transfer_per_sec_mb,latency_avg_ms,latency_stdev_ms,latency_max_ms" > "$LOG_FILE"
fi

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "WRK HTTP Load Testing"
echo "Target: $TARGET_URL"
echo "====================="
echo ""

for threads in "${THREAD_COUNTS[@]}"; do
    for connections in "${CONNECTION_COUNTS[@]}"; do
        echo "Testing: threads=$threads, connections=$connections"

        for iter in $(seq 1 $ITERATIONS); do
            echo "  Iteration $iter/$ITERATIONS..."
            TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

            # Run wrk and capture output
            WRK_OUTPUT=$($WRK_BIN -t$threads -c$connections -d$DURATION --latency "$TARGET_URL" 2>&1)

            # Parse results
            REQUESTS_TOTAL=$(echo "$WRK_OUTPUT" | grep "requests in" | awk '{print $1}')
            REQUESTS_PER_SEC=$(echo "$WRK_OUTPUT" | grep "Requests/sec:" | awk '{print $2}')
            TRANSFER_PER_SEC=$(echo "$WRK_OUTPUT" | grep "Transfer/sec:" | awk '{print $2}')

            # Convert transfer to MB (handle KB/MB/GB)
            if echo "$TRANSFER_PER_SEC" | grep -q "KB"; then
                TRANSFER_MB=$(echo "$TRANSFER_PER_SEC" | sed 's/KB//' | awk '{print $1/1024}')
            elif echo "$TRANSFER_PER_SEC" | grep -q "GB"; then
                TRANSFER_MB=$(echo "$TRANSFER_PER_SEC" | sed 's/GB//' | awk '{print $1*1024}')
            else
                TRANSFER_MB=$(echo "$TRANSFER_PER_SEC" | sed 's/MB//')
            fi

            # Parse latency stats (avg, stdev, max)
            LATENCY_AVG=$(echo "$WRK_OUTPUT" | grep "Latency" | head -1 | awk '{print $2}')
            LATENCY_STDEV=$(echo "$WRK_OUTPUT" | grep "Latency" | head -1 | awk '{print $3}')
            LATENCY_MAX=$(echo "$WRK_OUTPUT" | grep "Latency" | head -1 | awk '{print $4}')

            # Convert latency to ms (handle us/ms/s)
            convert_to_ms() {
                local value=$1
                if echo "$value" | grep -q "us"; then
                    echo "$value" | sed 's/us//' | awk '{print $1/1000}'
                elif echo "$value" | grep -q "s"; then
                    echo "$value" | sed 's/s//' | awk '{print $1*1000}'
                else
                    echo "$value" | sed 's/ms//'
                fi
            }

            LATENCY_AVG_MS=$(convert_to_ms "$LATENCY_AVG")
            LATENCY_STDEV_MS=$(convert_to_ms "$LATENCY_STDEV")
            LATENCY_MAX_MS=$(convert_to_ms "$LATENCY_MAX")

            # Log results
            echo "$TIMESTAMP,$iter,$threads,$connections,$DURATION,$REQUESTS_TOTAL,$REQUESTS_PER_SEC,$TRANSFER_MB,$LATENCY_AVG_MS,$LATENCY_STDEV_MS,$LATENCY_MAX_MS" >> "$LOG_FILE"

            sleep 3  # Cool-down between tests
        done
        echo ""
    done
done

echo "WRK tests completed. Results: $LOG_FILE"
