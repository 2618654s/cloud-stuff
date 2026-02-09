#!/bin/bash

# Configuration
OUTPUT_FILE="benchmark_logs/benchmark_results_with_time.csv"
EXECUTABLE="/home/samsaju/cloud-stuff/scripts/forksum"
SOURCE="/home/samsaju/cloud-stuff/scripts/forksum.c"
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
TIMEFORMAT="%R"

# 3. Initialize CSV file if it doesn't exist
if [ ! -f "$OUTPUT_FILE" ]; then
    # Ensure this matches the columns output by your C program + external_time
    echo "timestamp,test_type,start,end,sum,forks,internal_time_sec,internal_fps,external_time_sec" > "$OUTPUT_FILE"
fi

echo "Starting benchmark with Linux 'time' integration..."
echo "Results will be saved to $OUTPUT_FILE"

run_test() {
    local TYPE=$1
    local START=$2
    local END=$3

    # Wall-clock timestamp (UTC, ISO-8601)
    TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # --- FIX 1: Silence Application Errors ---
    # We add '2>/dev/null' to the executable command.
    # This sends "Resource unavailable" to the void, so it doesn't get captured by the outer '2>&1'.
    EXT_TIME=$({ time $EXECUTABLE $START $END > $TEMP_OUT 2>/dev/null; } 2>&1)

    # --- FIX 2: Check for Success ---
    # If the program crashed, TEMP_OUT will be empty. We skip writing to CSV to avoid broken rows.
    if [ -s "$TEMP_OUT" ]; then
        INNER_CSV=$(cat $TEMP_OUT)
        echo "$TIMESTAMP,$TYPE,$INNER_CSV,$EXT_TIME" >> $OUTPUT_FILE
        echo -n "."
    else
        # Print an 'x' to console to indicate a dropped/failed test
        echo -n "x"
    fi
}


# --- CONFIG 1: BASELINE (Small Request) ---
echo "Running Config 1: Baseline (Small Load)..."
for i in {1..5}; do
    run_test "Baseline" 1 1000
done
echo " Done."

# --- CONFIG 3: VERY HEAVY LOAD (Complex Request) ---
echo "Running Config 3: Heavy Load..."
for i in {1..5}; do
    run_test "Very Heavy" 1 5000
done
echo " Done."

# --- CONFIG 4: CONCURRENCY STRESS ---
echo "Running Config 4: Concurrent Execution (2x Parallel)..."

for i in {1..5}; do
    TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # --- FIX 3: Silence Parallel Errors ---
    BATCH_TIME=$({ time {
        $EXECUTABLE 1 1000 > /tmp/res1 2>/dev/null &  # Error silence
        PID1=$!
        $EXECUTABLE 1 1000 > /tmp/res2 2>/dev/null &  # Error silence
        PID2=$!
        wait $PID1
        wait $PID2
    }; } 2>&1)

    # Only write if BOTH succeeded
    if [ -s "/tmp/res1" ] && [ -s "/tmp/res2" ]; then
        R1=$(cat /tmp/res1)
        R2=$(cat /tmp/res2)

        echo "$TIMESTAMP,Concurrent_A,$R1,$BATCH_TIME" >> $OUTPUT_FILE
        echo "$TIMESTAMP,Concurrent_B,$R2,$BATCH_TIME" >> $OUTPUT_FILE
        echo -n "."
    else
        echo -n "x"
    fi
done

echo " Done."

# Cleanup
rm -f $TEMP_OUT /tmp/res1 /tmp/res2

echo ""
echo "Benchmark complete!"
# Check the last few lines to make sure they look clean
if [ -f "$OUTPUT_FILE" ]; then
    echo "Sample of results:"
    tail -n 5 $OUTPUT_FILE
fi
