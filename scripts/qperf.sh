#!/bin/bash
# =================QPERF NETWORK PERFORMANCE=================
# Tests network bandwidth and latency between hosts
# Requires: qperf on both client and server
# Server setup: qperf &
# ===========================================================

LOG_DIR="benchmark_logs"
LOG_FILE="$LOG_DIR/qperf_results.csv"
QPERF_BIN=$(which qperf)
ITERATIONS=5

# Configuration - UPDATE THIS
QPERF_SERVER="10.128.0.10"  # Server running 'qperf' daemon
QPERF_PORT=4000  # Default qperf port

# Test types
TEST_TYPES=("tcp_bw" "tcp_lat" "udp_bw" "udp_lat")
MESSAGE_SIZES=(1 1024 8192 65536)  # bytes

mkdir -p "$LOG_DIR"

# Check if qperf is installed
if [ -z "$QPERF_BIN" ]; then
    echo "ERROR: qperf not found. Install: apt-get install qperf"
    echo "Also ensure qperf server is running on target: qperf &"
    exit 1
fi

# Create CSV header
if [ ! -f "$LOG_FILE" ]; then
    echo "timestamp,test_iteration,test_type,message_size_bytes,result_value,result_unit" > "$LOG_FILE"
fi

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "QPERF Network Performance Testing"
echo "Server: $QPERF_SERVER"
echo "=================================="
echo ""

# Test if server is reachable
if ! ping -c 1 -W 2 "$QPERF_SERVER" > /dev/null 2>&1; then
    echo "ERROR: Cannot reach server $QPERF_SERVER"
    exit 1
fi

for test_type in "${TEST_TYPES[@]}"; do
    echo "Running $test_type tests..."

    for msg_size in "${MESSAGE_SIZES[@]}"; do
        echo "  Message size: $msg_size bytes"

        for iter in $(seq 1 $ITERATIONS); do
            TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
            # Run qperf test
            if [[ "$test_type" == *"bw"* ]]; then
                # Bandwidth test
                QPERF_OUTPUT=$($QPERF_BIN -lp $QPERF_PORT "$QPERF_SERVER" -m "$msg_size" "$test_type" 2>&1)
                RESULT=$(echo "$QPERF_OUTPUT" | grep "bw" | awk '{print $3}')
                UNIT=$(echo "$QPERF_OUTPUT" | grep "bw" | awk '{print $4}')

            else
                # Latency test
                TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
                QPERF_OUTPUT=$($QPERF_BIN -lp $QPERF_PORT "$QPERF_SERVER" -m "$msg_size" "$test_type" 2>&1)
                RESULT=$(echo "$QPERF_OUTPUT" | grep "latency" | awk '{print $3}')
                UNIT="us"
            fi

            # Handle empty results
            [ -z "$RESULT" ] && RESULT="0"
            [ -z "$UNIT" ] && UNIT="unknown"

            echo "$TIMESTAMP,$iter,$test_type,$msg_size,$RESULT,$UNIT" >> "$LOG_FILE"

            sleep 1
        done
    done
    echo ""
done

echo "QPERF tests completed. Results: $LOG_FILE"
