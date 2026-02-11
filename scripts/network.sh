#!/bin/bash
# =================NETWORK PERFORMANCE TESTS=================
# Tests network latency (ping) and bandwidth (iperf3)
# ===========================================================

LOG_DIR="benchmark_logs"
LOG_FILE="$LOG_DIR/network_results.csv"
PING_BIN=$(which ping)
IPERF_BIN=$(which iperf3)
ITERATIONS=5

# Configuration - UPDATE THESE
IPERF_SERVER="10.128.0.10"
IPERF_PORT=5201
PING_TARGETS=("8.8.8.8" "1.1.1.1" "$IPERF_SERVER")
PING_TARGET_NAMES=("Google DNS" "Cloudflare DNS" "Internal Server")

# iPerf3 test configurations
IPERF_DURATIONS=(5)  # seconds
IPERF_PARALLEL_STREAMS=(1)  # number of parallel streams
IPERF_PROTOCOLS=("tcp" "udp")
MAX_RETRIES=3  # Retry up to 3 times (4 total attempts)

mkdir -p "$LOG_DIR"

# Create CSV header
if [ ! -f "$LOG_FILE" ]; then
    echo "timestamp,test_iteration,test_type,target,protocol,config,result_value,result_unit" > "$LOG_FILE"
fi

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "Network Performance Testing"
echo "==========================="
echo ""

# Ping Tests
echo "Running ping latency tests..."
for i in "${!PING_TARGETS[@]}"; do
    target="${PING_TARGETS[$i]}"
    target_name="${PING_TARGET_NAMES[$i]}"

    echo "  Target: $target_name ($target)"

    for iter in $(seq 1 $ITERATIONS); do
        TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

        # Send 10 pings
        PING_OUTPUT=$($PING_BIN -c 10 -i 0.2 "$target" 2>&1)

        if [ $? -eq 0 ]; then
            # Extract min/avg/max/stddev from summary line
            PING_STATS=$(echo "$PING_OUTPUT" | tail -1 | awk -F'=' '{print $2}')
            PING_MIN=$(echo "$PING_STATS" | cut -d'/' -f1)
            PING_AVG=$(echo "$PING_STATS" | cut -d'/' -f2)
            PING_MAX=$(echo "$PING_STATS" | cut -d'/' -f3)
            PING_STDDEV=$(echo "$PING_STATS" | cut -d'/' -f4 | awk '{print $1}')

            # Also get packet loss
            PACKET_LOSS=$(echo "$PING_OUTPUT" | grep "packet loss" | awk '{print $6}' | tr -d '%')

            echo "$TIMESTAMP,$iter,ping_min,$target_name,icmp,default,$PING_MIN,ms" >> "$LOG_FILE"
            echo "$TIMESTAMP,$iter,ping_avg,$target_name,icmp,default,$PING_AVG,ms" >> "$LOG_FILE"
            echo "$TIMESTAMP,$iter,ping_max,$target_name,icmp,default,$PING_MAX,ms" >> "$LOG_FILE"
            echo "$TIMESTAMP,$iter,ping_stddev,$target_name,icmp,default,$PING_STDDEV,ms" >> "$LOG_FILE"
            echo "$TIMESTAMP,$iter,ping_loss,$target_name,icmp,default,$PACKET_LOSS,percent" >> "$LOG_FILE"
        else
            echo "    Ping failed"
            echo "$TIMESTAMP,$iter,ping_failed,$target_name,icmp,default,0,ms" >> "$LOG_FILE"
        fi

        sleep 2
    done
    echo ""
done

# iPerf3 Tests
if [ -n "$IPERF_BIN" ]; then
    echo "Running iPerf3 bandwidth tests..."

    for protocol in "${IPERF_PROTOCOLS[@]}"; do
        for duration in "${IPERF_DURATIONS[@]}"; do
            for parallel in "${IPERF_PARALLEL_STREAMS[@]}"; do
                TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
                CONFIG="duration=${duration}s_parallel=${parallel}"
                echo "  Protocol: $protocol, Config: $CONFIG"

                for iter in $(seq 1 $ITERATIONS); do
                    
                    # Retry logic variables
                    attempt=0
                    success=false
                    
                    # Build iperf3 command
                    IPERF_CMD="$IPERF_BIN -c $IPERF_SERVER -p $IPERF_PORT -t $duration -P $parallel -f m"
                    if [ "$protocol" = "udp" ]; then
                        IPERF_CMD="$IPERF_CMD -u -b 1000M"  # UDP with 1Gbps target
                    fi

                    # Retry Loop
                    while [ $attempt -le $MAX_RETRIES ]; do
                        if [ $attempt -gt 0 ]; then
                            echo "    ...Retry #$attempt for iteration $iter..."
                        fi

                        # Run test
                        IPERF_OUTPUT=$($IPERF_CMD 2>&1)
                        cmd_status=$?

                        if [ $cmd_status -eq 0 ]; then
                            success=true
                            # Extract sender bandwidth
                            BANDWIDTH=$(echo "$IPERF_OUTPUT" | grep "sender" | tail -1 | awk '{print $7}')

                            # For UDP, also get jitter and packet loss
                            if [ "$protocol" = "udp" ]; then
                                JITTER=$(echo "$IPERF_OUTPUT" | grep "sender" | tail -1 | awk '{print $9}')
                                LOSS=$(echo "$IPERF_OUTPUT" | grep "sender" | tail -1 | awk '{print $12}' | tr -d '()%')

                                echo "$TIMESTAMP,$iter,iperf_bw,$IPERF_SERVER,$protocol,$CONFIG,$BANDWIDTH,Mbps" >> "$LOG_FILE"
                                echo "$TIMESTAMP,$iter,iperf_jitter,$IPERF_SERVER,$protocol,$CONFIG,$JITTER,ms" >> "$LOG_FILE"
                                echo "$TIMESTAMP,$iter,iperf_loss,$IPERF_SERVER,$protocol,$CONFIG,$LOSS,percent" >> "$LOG_FILE"
                            else
                                echo "$TIMESTAMP,$iter,iperf_bw,$IPERF_SERVER,$protocol,$CONFIG,$BANDWIDTH,Mbps" >> "$LOG_FILE"
                            fi
                            
                            # Break the retry loop on success
                            break
                        else
                            ((attempt++))
                            if [ $attempt -le $MAX_RETRIES ]; then
                                sleep 1
                            fi
                        fi
                    done

                    # If we exhausted retries without success
                    if [ "$success" = false ]; then
                        echo "    iPerf3 test failed for iteration $iter (Max retries reached). Skipping log."
                        # Explicitly NOT logging to CSV here as requested
                    fi

                    sleep 3
                done
                echo ""
            done
        done
    done
else
    echo "iPerf3 not found - skipping bandwidth tests"
fi

echo "Network tests completed. Results: $LOG_FILE"