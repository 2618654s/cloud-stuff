#!/bin/bash

# ================= CONFIGURATION =================
# Output File
RESULTS_FILE="startup_benchmark.csv"

# Machine Types to Test
MACHINE_TYPES=("e2-micro" "e2-medium" "n2-standard-2")

# Infrastructure Config
ZONE="us-central1-a"
IMAGE_FAMILY="ubuntu-2204-lts"
IMAGE_PROJECT="ubuntu-os-cloud"

# Command Shortcuts (Auto-detects paths)
GCLOUD_BIN=$(which gcloud)
BC_BIN=$(which bc)

# =================================================

# 1. Prepare CSV File
if [ ! -f "$RESULTS_FILE" ]; then
    echo "Creating new CSV file: $RESULTS_FILE"
    echo "batch_id,run_number,machine_type,boot_time_seconds,timestamp" > "$RESULTS_FILE"
else
    echo "Appending to existing file: $RESULTS_FILE"
fi

# Generate a unique Batch ID for this execution
BATCH_ID="batch-$(date +%s)"
echo "Starting Benchmark Batch: $BATCH_ID"
echo "------------------------------------------------"

# --- OUTER LOOP: 5 ITERATIONS ---
for RUN_NUM in {1..5}
do
    echo "🔄 [Iteration $RUN_NUM of 5]"

    # --- INNER LOOP: 3 MACHINE TYPES ---
    for TYPE in "${MACHINE_TYPES[@]}"
    do
        INSTANCE_NAME="bench-$TYPE-$RANDOM"
        echo "   Target: $TYPE | Instance: $INSTANCE_NAME"

        # A. Start Timer (Nanoseconds)
        START_TIME=$(date +%s%N)

        # B. Create Instance
        # We run this in the background but wait for it to finish
        $GCLOUD_BIN compute instances create "$INSTANCE_NAME" \
            --zone="$ZONE" \
            --machine-type="$TYPE" \
            --image-family="$IMAGE_FAMILY" \
            --image-project="$IMAGE_PROJECT" \
            --quiet > /dev/null 2>&1

        # C. Wait for Status "RUNNING"
        # This ensures the API has allocated the resource before we try to SSH
        while true; do
            STATUS=$($GCLOUD_BIN compute instances describe "$INSTANCE_NAME" --zone="$ZONE" --format='get(status)' 2>/dev/null)
            if [ "$STATUS" == "RUNNING" ]; then
                break
            fi
            sleep 2
        done

        # D. Small buffer to allow SSH Daemon (sshd) to start
        # This prevents the "Connection Refused" error you saw earlier
        sleep 10

        # E. Poll for SSH Connection
        # We try every 2 seconds until successful
        echo "      Polling SSH..."
        while ! $GCLOUD_BIN compute ssh "$INSTANCE_NAME" \
            --zone="$ZONE" \
            --command="echo 'ready'" \
            --quiet \
            --ssh-flag="-o StrictHostKeyChecking=no" \
            --ssh-flag="-o ConnectTimeout=5" > /dev/null 2>&1; do

            sleep 2
        done

        # F. Stop Timer & Calculate Duration
        END_TIME=$(date +%s%N)
        DURATION=$(echo "scale=2; ($END_TIME - $START_TIME) / 1000000000" | $BC_BIN)
        TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

        echo "      ✅ Startup Time: ${DURATION}s"

        # G. Log to CSV
        echo "$BATCH_ID,$RUN_NUM,$TYPE,$DURATION,$TIMESTAMP" >> "$RESULTS_FILE"

        # H. Cleanup (Delete instance immediately)
        echo "      Cleaning up..."
        $GCLOUD_BIN compute instances delete "$INSTANCE_NAME" --zone="$ZONE" --quiet > /dev/null 2>&1

        # Cool down slightly to avoid API rate limits
        sleep 2
    done
    echo "------------------------------------------------"
done

echo "🎉 Benchmark Complete. Results saved to $RESULTS_FILE"
