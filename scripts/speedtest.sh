#!/bin/bash
# Configuration
OUTPUT_FILE="benchmark_logs/speedtest_results.csv"
DELAY=10            # Seconds to wait between each individual test
REPETITIONS=5       # How many times to repeat the entire set of 3 locations

# --- MANUAL SERVER SELECTION ---
# Add IDs here to override automatic selection, e.g., (13273 4567 8910)
# Leave empty () to use the automatic filtering logic
MANUAL_SERVER_IDS=()
# -------------------------------

# Check for dependencies
if ! command -v speedtest &> /dev/null || ! command -v jq &> /dev/null; then
    echo "Error: 'speedtest' (Ookla) and 'jq' are required."
    exit 1
fi

# Create CSV header if file doesn't exist
if [ ! -f "$OUTPUT_FILE" ]; then
    mkdir -p "$(dirname "$OUTPUT_FILE")"
    echo "timestamp,cycle,iteration,server_name,server_location,server_id,ping_ms,download_mbps,upload_mbps,packet_loss_percent,isp" > "$OUTPUT_FILE"
fi

# Determine which servers to use
if [ ${#MANUAL_SERVER_IDS[@]} -gt 0 ]; then
    echo "Using manually specified Server IDs: ${MANUAL_SERVER_IDS[*]}"
    SELECTED_IDS=("${MANUAL_SERVER_IDS[@]}")
else
    echo "Fetching available non-Google/non-Synthesis Health servers..."

    # 1. Get raw list of candidates (ID and Location separated by pipe '|')
    # We explicitly exclude specific hosts
    raw_server_list=$(speedtest --servers --format=json 2>/dev/null | jq -r '.servers[] | select((.host | contains("google") | not) and (.name | contains("Synthesis Health") | not)) | "\(.id)|\(.location)"')

    if [ -z "$raw_server_list" ]; then
        echo "Error: No suitable servers found automatically."
        exit 1
    fi

    echo "Selecting top 3 servers from unique locations..."

    # 2. Use awk to deduplicate by Location ($2) while preserving the sort order (distance)
    # The '!seen[$2]++' idiom checks if the location has been processed before.
    mapfile -t SELECTED_IDS < <(echo "$raw_server_list" | awk -F"|" '!seen[$2]++ { print $1; count++; if (count == 3) exit }')
fi

NUM_SERVERS=${#SELECTED_IDS[@]}

if [ "$NUM_SERVERS" -eq 0 ]; then
    echo "Error: Could not select any servers."
    exit 1
fi

echo "Selected Server IDs: ${SELECTED_IDS[*]}"
echo "Starting test: $REPETITIONS cycles of $NUM_SERVERS locations."
echo "---"

# OUTER LOOP: Repetitions
for (( cycle=1; cycle<=REPETITIONS; cycle++ ))
do
    echo ">>> STARTING CYCLE $cycle of $REPETITIONS <<<"

    # INNER LOOP: Locations
    for i in "${!SELECTED_IDS[@]}"
    do
        current_id=${SELECTED_IDS[$i]}
        iteration=$((i+1))

        echo "Cycle $cycle | Test $iteration/$NUM_SERVERS (ID: $current_id)..."

        json_output=$(speedtest --server-id="$current_id" --format=json --accept-license --accept-gdpr 2>/dev/null)

        # Check if json_output is empty or if jq fails to parse it
        if [ $? -ne 0 ] || [ -z "$json_output" ]; then
            echo "Error: Speedtest failed on Server ID $current_id."
            continue
        fi

        # Parse JSON
        timestamp=$(echo "$json_output" | jq -r '.timestamp')
        server_id=$(echo "$json_output" | jq -r '.server.id // "N/A"')
        server_name=$(echo "$json_output" | jq -r '.server.name // "N/A"')
        server_location=$(echo "$json_output" | jq -r '.server.location // "N/A"')
        ping=$(echo "$json_output" | jq -r '.ping.latency // 0')
        download=$(echo "$json_output" | jq -r '(.download.bandwidth * 8 / 1000000) | . * 100 | floor / 100')
        upload=$(echo "$json_output" | jq -r '(.upload.bandwidth * 8 / 1000000) | . * 100 | floor / 100')
        packet_loss=$(echo "$json_output" | jq -r '.packetLoss // 0')
        isp=$(echo "$json_output" | jq -r '.isp // "Unknown"')

        # Write to CSV
        echo "$timestamp,$cycle,$iteration,\"$server_name\",\"$server_location\",$server_id,$ping,$download,$upload,$packet_loss,\"$isp\"" >> "$OUTPUT_FILE"

        echo "Result: $download Mbps Down / $upload Mbps Up (Loss: $packet_loss%) [$server_location]"

        # Delay between tests to avoid being rate-limited or overheating the modem
        sleep $DELAY
    done
    echo "---"
done

echo "All tests completed successfully. Results saved to: $OUTPUT_FILE"
