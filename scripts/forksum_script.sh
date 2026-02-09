#!/bin/bash

# Configuration
OUTPUT_FILE="benchmark_logs/benchmark_results_with_time.csv"
EXECUTABLE="./forksum"
SOURCE="forksum.c"
TEMP_OUT="/tmp/forksum_stdout.txt"

# 1. Compile (Only if needed)
if [ ! -f "$EXECUTABLE" ]; then
    echo "Compiling $SOURCE..."
    gcc -o "$EXECUTABLE" "$SOURCE"
    if [ $? -ne 0 ]; then
        echo "Compilation failed!"
        exit 1
    fi
else
    echo "Executable '$EXECUTABLE' already exists. Skipping compilation."
fi

# 2. Configure 'time' format
# %R = Elapsed time in seconds. 
# We use the bash builtin 'time', not /usr/bin/time, for easier formatting.
TIMEFORMAT="%R"

# 3. Initialize CSV file with NEW headers
# We are adding 'external_time_sec' and 'overhead_sec' to the end.
echo "test_type,start,end,sum,forks,internal_time_sec,internal_fps,external_time_sec" > $OUTPUT_FILE

echo "Starting benchmark with Linux 'time' integration..."
echo "Results will be saved to $OUTPUT_FILE"

# Function to run a single test
run_test() {
    local TYPE=$1
    local START=$2
    local END=$3
    
    # Run the executable:
    # 1. { ... } groups the command.
    # 2. 'time' measures the group.
    # 3. $EXECUTABLE > $TEMP_OUT redirects the C program's CSV output to a file.
    # 4. } 2>&1 captures the 'time' output (which goes to stderr) into the variable EXT_TIME.
    EXT_TIME=$({ time $EXECUTABLE $START $END > $TEMP_OUT; } 2>&1)
    
    # Read the C program's output
    INNER_CSV=$(cat $TEMP_OUT)
    
    # Append everything to the main results file
    echo "$TYPE,$INNER_CSV,$EXT_TIME" >> $OUTPUT_FILE
    echo -n "."
}

# --- CONFIG 1: BASELINE (Small Request) ---
echo "Running Config 1: Baseline (Small Load)..."
for i in {1..10}; do
    run_test "Baseline" 1 1000
done
echo " Done."

# --- CONFIG 2: HEAVY LOAD (Complex Request) ---
echo "Running Config 2: Heavy Load..."
for i in {1..10}; do
    run_test "Heavy" 1 5000
done
echo " Done."

# --- CONFIG 3: VERY HEAVY LOAD (Complex Request) ---
echo "Running Config 3: Heavy Load..."
for i in {1..10}; do
    run_test "Very Heavy" 1 10000
done
echo " Done."

# --- CONFIG 4: CONCURRENCY STRESS ---
# Note: 'time' is tricky with background processes (&). 
# We wrap the whole parallel block to measure the TOTAL time for the batch.
echo "Running Config 4: Concurrent Execution (2x Parallel)..."

for i in {1..5}; do
    # We measure how long it takes for the PAIR to finish
    BATCH_TIME=$({ time {
        $EXECUTABLE 1 1000 > /tmp/res1 &
        PID1=$!
        $EXECUTABLE 1 1000 > /tmp/res2 &
        PID2=$!
        wait $PID1
        wait $PID2
    }; } 2>&1)

    # Read the individual results
    R1=$(cat /tmp/res1)
    R2=$(cat /tmp/res2)
    
    # Log them. Note: We use the BATCH_TIME for both, as they ran together.
    echo "Concurrent_A,$R1,$BATCH_TIME" >> $OUTPUT_FILE
    echo "Concurrent_B,$R2,$BATCH_TIME" >> $OUTPUT_FILE
    echo -n "."
done
echo " Done."

# Cleanup
rm $TEMP_OUT /tmp/res1 /tmp/res2

echo ""
echo "Benchmark complete!"
echo "Sample of results (Last column is Linux Time):"
head -n 5 $OUTPUT_FILE