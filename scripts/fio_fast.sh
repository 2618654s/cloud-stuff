#!/bin/bash
# ==============================================================================
# FIO ADVANCED BENCHMARK (JSON Parsing)
# Captures: IOPS, BW, Mean, Min, Max, StdDev, and 95th Percentile Latency
# ==============================================================================

TEST_DIR=${1:-$(pwd)}
TEST_FILE="$TEST_DIR/fio_test_file"
RESULT_CSV="benchmark_logs/fio_advanced_results.csv"

# SETTINGS
ITERATIONS=5
RUNTIME="20"
SIZE="1G"

# Check for tools
if ! command -v fio &> /dev/null; then echo "Error: fio missing"; exit 1; fi
if ! command -v python3 &> /dev/null; then echo "Error: python3 missing"; exit 1; fi

# Create CSV Header
if [ ! -f "$RESULT_CSV" ]; then
    echo "Timestamp,Iteration,Test_Type,IOPS,BW_MiB_s,Lat_Mean_ms,Lat_Min_ms,Lat_Max_ms,Lat_StdDev_ms,Lat_p95_ms" > "$RESULT_CSV"
fi

echo "Starting Advanced FIO Benchmark..."
echo "Results will be saved to: $RESULT_CSV"

# ------------------------------------------------------------------------------
# PYTHON PARSER (Embedded)
# ------------------------------------------------------------------------------
# This python script reads JSON from stdin and prints a CSV line.
parse_json() {
    python3 -c "
import sys, json

try:
    data = json.load(sys.stdin)
    job = data['jobs'][0]
    
    # Determine if Read or Write
    if 'read' in job['job options']['rw'] or 'randread' in job['job options']['rw']:
        metrics = job['read']
    else:
        metrics = job['write']
        
    # Extract Metrics
    iops = metrics['iops']
    bw = metrics['bw'] / 1024  # KB to MiB
    
    # Latency is usually in 'clat_ns' (Completion Latency in nanoseconds)
    # We convert to milliseconds (ms) by dividing by 1,000,000
    lat_node = metrics['clat_ns']
    mean = lat_node['mean'] / 1e6
    min_l = lat_node['min'] / 1e6
    max_l = lat_node['max'] / 1e6
    stddev = lat_node['stddev'] / 1e6
    
    # 95th Percentile (Handling dictionary structure)
    # FIO returns percentiles as a dict: {'95.000000': 1234, ...}
    p95 = lat_node['percentile'].get('95.000000', 0) / 1e6
    
    print(f'{iops},{bw:.2f},{mean:.2f},{min_l:.2f},{max_l:.2f},{stddev:.2f},{p95:.2f}')

except Exception as e:
    print(f'0,0,0,0,0,0,0') # Fallback on error
"
}

# ------------------------------------------------------------------------------
# RUN TEST FUNCTION
# ------------------------------------------------------------------------------
run_test() {
    local ITER=$1
    local NAME=$2
    local RW=$3
    local BS=$4

    echo "   Running $NAME (Iter $ITER)..."

    # Get current UTC timestamp
    local TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Run FIO and pipe JSON output to Python parser
    fio --name=$NAME \
        --ioengine=libaio --rw=$RW --bs=$BS \
        --direct=1 --size=$SIZE --numjobs=1 --runtime=$RUNTIME \
        --time_based --group_reporting --output-format=json \
        --filename=$TEST_FILE > temp_fio.json

    # Parse the temp file
    CSV_DATA=$(cat temp_fio.json | parse_json)
    
    # Save to file with timestamp
    echo "$TIMESTAMP,$ITER,$NAME,$CSV_DATA" >> "$RESULT_CSV"
    
    rm -f $TEST_FILE temp_fio.json
    sleep 2
}


# ------------------------------------------------------------------------------
# MAIN EXECUTION
# ------------------------------------------------------------------------------
for ((i=1; i<=ITERATIONS; i++)); do
    echo "--- Iteration $i ---"
    run_test $i "Random_Write" "randwrite" "4k"
    run_test $i "Random_Read" "randread" "4k"
    run_test $i "Seq_Read" "read" "1M"
done

echo "Done. Check $RESULT_CSV."