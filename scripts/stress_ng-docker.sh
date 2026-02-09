#!/bin/bash
# run_interference_test.sh
# MEASURES: Impact of resource contention (Noisy Neighbor / Traffic Spike)
# CONTEXT: Simulates a "Flash Sale" or a shared-host interference event.

# --- CONFIGURATION ---
# The script you created in the previous step
BENCHMARK_SCRIPT="/benchmarks/scripts/sysbench.sh"
BENCHMARK_SCRIPT_2="/benchmarks/scripts/fio_fast.sh"
LOG_DIR="$HOME/benchmark_logs"
RESULT_FILE="$LOG_DIR/interference_comparison.txt"

# Ensure log dir exists
mkdir -p $LOG_DIR

echo "========================================================" | tee -a $RESULT_FILE
echo "STARTING INTERFERENCE TEST SUITE - $(date)" | tee -a $RESULT_FILE
echo "========================================================" | tee -a $RESULT_FILE

run_all_benchmarks() {
    echo "   -> Running $BENCHMARK_SCRIPT..." | tee -a $RESULT_FILE
    $BENCHMARK_SCRIPT
    echo "   -> Running $BENCHMARK_SCRIPT_2..." | tee -a $RESULT_FILE
    $BENCHMARK_SCRIPT_2
}

# ---------------------------------------------------------
# PHASE 1: BASELINE (The Calm Before the Storm)
# ---------------------------------------------------------
echo "[PHASE 1] Running Baseline Benchmarks (No Stress)..." | tee -a $RESULT_FILE
# We pass a "tag" or just rely on the timestamp in the log
# Ideally, verify no background processes are running here.
run_all_benchmarks
echo ">> Baseline Complete." | tee -a $RESULT_FILE
echo "" | tee -a $RESULT_FILE

# ---------------------------------------------------------
# PHASE 2: CPU STRESS (Simulating High Traffic / Noisy CPU)
# ---------------------------------------------------------
# --cpu 2: Spawns 2 workers spinning on sqrt() calculations.
# --timeout 120s: Ensures it dies automatically if we forget to kill it.
echo "[PHASE 2] Spinning up CPU Stress (Simulating Compute Spike)..." | tee -a $RESULT_FILE
stress-ng --cpu 2 --cpu-method sqrt --timeout 120s &
STRESS_PID=$!

# Give it 5 seconds to warm up
sleep 5

echo ">> Running Benchmarks UNDER CPU LOAD..." | tee -a $RESULT_FILE
run_all_benchmarks

# Kill the stressor
kill $STRESS_PID 2>/dev/null
wait $STRESS_PID 2>/dev/null
echo ">> CPU Stress Test Complete." | tee -a $RESULT_FILE
echo "" | tee -a $RESULT_FILE

# ---------------------------------------------------------
# PHASE 3: I/O STRESS (Simulating Database Backup / Disk Contention)
# ---------------------------------------------------------
# --hdd 1: Spawns 1 worker spinning on write/unlink (Disk thrashing).
# --io 2: Spawns 2 workers spinning on sync() (Metadata thrashing).
echo "[PHASE 3] Spinning up I/O Stress (Simulating DB Contention)..." | tee -a $RESULT_FILE
stress-ng --hdd 1 --io 2 --timeout 120s &
STRESS_PID=$!

sleep 5

echo ">> Running Benchmarks UNDER I/O LOAD..." | tee -a $RESULT_FILE
run_all_benchmarks

kill $STRESS_PID 2>/dev/null
wait $STRESS_PID 2>/dev/null
echo ">> I/O Stress Test Complete." | tee -a $RESULT_FILE

echo "========================================================" | tee -a $RESULT_FILE
echo "INTERFERENCE SUITE FINISHED." | tee -a $RESULT_FILE