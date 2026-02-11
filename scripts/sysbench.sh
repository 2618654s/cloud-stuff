#!/bin/bash
# =================SYSBENCH BENCHMARK=================
LOG_DIR="benchmark_logs"
LOG_FILE="$LOG_DIR/sysbench_results.csv"
SYSBENCH_BIN=$(which sysbench)
ITERATIONS=5
RUNTIME=30

# Test configurations
CPU_MAX_PRIMES=(5000 20000)
CPU_THREADS=(1 4)
MEM_BLOCK_SIZES=("1K" "1M")
MEM_TOTAL_SIZE="100T"
MEM_THREADS=(1 4)
DISK_FILE_SIZES=("2G")
DISK_THREADS=(1 4)

mkdir -p "$LOG_DIR"

# Create CSV header
if [ ! -f "$LOG_FILE" ]; then
    echo "timestamp,test_iteration,benchmark_type,param_config,load_avg_1min,free_ram_mb,result_value,result_unit" > "$LOG_FILE"
fi

log_result() {
    local timestamp=$1
    local iteration=$2
    local bench_type=$3
    local param_config=$4
    local load_avg=$5
    local free_ram=$6
    local result_value=$7
    local result_unit=$8

    echo "$timestamp,$iteration,$bench_type,$param_config,$load_avg,$free_ram,$result_value,$result_unit" >> "$LOG_FILE"
}

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# CPU Benchmarks
echo "Running CPU benchmarks..."
for max_prime in "${CPU_MAX_PRIMES[@]}"; do
    for threads in "${CPU_THREADS[@]}"; do
        TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

        PARAM_CONFIG="prime=${max_prime}_threads=${threads}"
        echo "  → $PARAM_CONFIG"

        for iter in $(seq 1 $ITERATIONS); do
            LOAD_AVG=$(cat /proc/loadavg | awk '{print $1}')
            FREE_RAM=$(free -m | grep Mem | awk '{print $7}')

            CPU_RES=$($SYSBENCH_BIN cpu \
                --cpu-max-prime=$max_prime \
                --threads=$threads \
                run 2>/dev/null | grep "events per second" | awk '{print $4}')

            log_result "$TIMESTAMP" "$iter" "cpu" "$PARAM_CONFIG" "$LOAD_AVG" "$FREE_RAM" "$CPU_RES" "events/sec"
            sleep 2
        done
    done
done

# Memory Benchmarks
echo "Running Memory benchmarks..."
for block_size in "${MEM_BLOCK_SIZES[@]}"; do
    for threads in "${MEM_THREADS[@]}"; do
        TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        PARAM_CONFIG="blocksize=${block_size}_threads=${threads}"
        echo "  → $PARAM_CONFIG"

        for iter in $(seq 1 $ITERATIONS); do
            LOAD_AVG=$(cat /proc/loadavg | awk '{print $1}')
            FREE_RAM=$(free -m | grep Mem | awk '{print $7}')

            MEM_RES=$($SYSBENCH_BIN memory \
                --memory-block-size=$block_size \
                --memory-total-size=$MEM_TOTAL_SIZE \
                --threads=$threads \
                --time=$RUNTIME \
                --max-requests=0 \
                run 2>/dev/null | grep "MiB/sec" | awk '{print $4}' | tr -d '(')

            log_result "$TIMESTAMP" "$iter" "memory" "$PARAM_CONFIG" "$LOAD_AVG" "$FREE_RAM" "$MEM_RES" "MiB/sec"
            sleep 2
        done
    done
done

# Disk I/O Benchmarks
echo "Running Disk I/O benchmarks..."
for file_size in "${DISK_FILE_SIZES[@]}"; do
    for threads in "${DISK_THREADS[@]}"; do
        TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        PARAM_CONFIG="filesize=${file_size}_threads=${threads}"
        echo "  → $PARAM_CONFIG"

        for iter in $(seq 1 $ITERATIONS); do
            LOAD_AVG=$(cat /proc/loadavg | awk '{print $1}')
            FREE_RAM=$(free -m | grep Mem | awk '{print $7}')

            $SYSBENCH_BIN fileio --file-total-size=$file_size --threads=$threads prepare > /dev/null 2>&1

            DISK_OUTPUT=$($SYSBENCH_BIN fileio \
                --file-total-size=$file_size \
                --file-test-mode=rndrw \
                --threads=$threads \
                --time=$RUNTIME \
                --max-requests=0 \
                run 2>/dev/null)

            DISK_READ=$(echo "$DISK_OUTPUT" | grep "read, MiB/s:" | awk '{print $3}')
            DISK_WRITE=$(echo "$DISK_OUTPUT" | grep "written, MiB/s:" | awk '{print $3}')

            log_result "$TIMESTAMP" "$iter" "disk_read" "$PARAM_CONFIG" "$LOAD_AVG" "$FREE_RAM" "$DISK_READ" "MiB/sec"
            log_result "$TIMESTAMP" "$iter" "disk_write" "$PARAM_CONFIG" "$LOAD_AVG" "$FREE_RAM" "$DISK_WRITE" "MiB/sec"

            $SYSBENCH_BIN fileio --file-total-size=$file_size --threads=$threads cleanup > /dev/null 2>&1
            sleep 2
        done
    done
done

echo "Sysbench tests completed. Results: $LOG_FILE"
