#!/bin/bash
# Configuration
OUTPUT_FILE="benchmark_logs/speedtest_results.csv"
runs=5  # Default to 5 runs if no argument is provided
DELAY=10      # Seconds to wait between tests (if running multiple times)

# Check for dependencies
if ! command -v speedtest &> /dev/null; then
    echo "Error: Official Ookla 'speedtest' CLI is not installed."
    echo "Install it from: https://www.speedtest.net/apps/cli"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "Error: 'jq' is not installed. Please install it to parse JSON output."
    echo "Debian/Ubuntu: sudo apt-get install jq"
    echo "MacOS: brew install jq"
    exit 1
fi

# Create CSV header if file doesn't exist
if [ ! -f "$OUTPUT_FILE" ]; then
    mkdir -p "$(dirname "$OUTPUT_FILE")"
    echo "timestamp,test_iteration,server_name,server_location,server_id,ping_ms,download_mbps,upload_mbps,packet_loss_percent,isp" > "$OUTPUT_FILE"
fi

echo "Fetching available speedtest servers..."
# Get list of nearby servers and exclude Google-hosted ones
server_list=$(speedtest --servers --format=json 2>/dev/null | jq -r '.servers[] | select(.host | contains("google") | not) | "\(.id),\(.name),\(.location),\(.host)"' | head -10)

if [ -z "$server_list" ]; then
    echo "Warning: Could not fetch server list. Will use default server selection (may include Google servers)."
    USE_SPECIFIC_SERVER=false
else
    echo ""
    echo "Available non-Google servers:"
    echo "$server_list" | nl
    echo ""
    
    # Use the first non-Google server by default
    SELECTED_SERVER_ID=$(echo "$server_list" | head -1 | cut -d',' -f1)
    SELECTED_SERVER_NAME=$(echo "$server_list" | head -1 | cut -d',' -f2)
    
    echo "Using server: $SELECTED_SERVER_NAME (ID: $SELECTED_SERVER_ID)"
    echo "To use a different server, modify SELECTED_SERVER_ID in the script."
    echo ""
    USE_SPECIFIC_SERVER=true
fi

echo "Starting Speedtest ($runs iteration(s))..."

for (( i=1; i<=runs; i++ ))
do
    echo "Running test $i of $runs..."
    
    # Run speedtest with specific server selection if available
    if [ "$USE_SPECIFIC_SERVER" = true ]; then
        json_output=$(speedtest --server-id="$SELECTED_SERVER_ID" --format=json --accept-license --accept-gdpr 2>/dev/null)
    else
        json_output=$(speedtest --format=json --accept-license --accept-gdpr 2>/dev/null)
    fi
    
    # Check if the speedtest command failed
    if [ $? -ne 0 ] || [ -z "$json_output" ]; then
        echo "Error: Speedtest failed on iteration $i."
        continue
    fi
    
    # Parse JSON using jq
    timestamp=$(echo "$json_output" | jq -r '.timestamp')
    server_id=$(echo "$json_output" | jq -r '.server.id // "N/A"')
    server_name=$(echo "$json_output" | jq -r '.server.name // "N/A"')
    server_location=$(echo "$json_output" | jq -r '.server.location // "N/A"')
    server_host=$(echo "$json_output" | jq -r '.server.host // "N/A"')
    ping=$(echo "$json_output" | jq -r '.ping.latency // 0')
    
    # Calculate Mbps (Bytes * 8 / 1,000,000)
    download=$(echo "$json_output" | jq -r '(.download.bandwidth * 8 / 1000000) | . * 100 | floor / 100')
    upload=$(echo "$json_output" | jq -r '(.upload.bandwidth * 8 / 1000000) | . * 100 | floor / 100')
    
    # Handle Packet Loss (often null if 0% loss, so we default to 0)
    packet_loss=$(echo "$json_output" | jq -r '.packetLoss // 0')
    isp=$(echo "$json_output" | jq -r '.isp // "Unknown"')
    
    # Verify the server is not Google-hosted
    if echo "$server_host" | grep -qi "google"; then
        echo "Warning: Test $i used a Google-hosted server ($server_host). Results may not reflect external network performance."
    fi
    
    # Write to CSV
    echo "$timestamp,$i,\"$server_name\",\"$server_location\",$server_id,$ping,$download,$upload,$packet_loss,\"$isp\"" >> "$OUTPUT_FILE"
    
    echo "Iteration $i complete. Server: $server_name ($server_host)"
    echo "Results saved to $OUTPUT_FILE"
    
    # Wait before next run (except after the last one)
    if [ $i -lt $runs ]; then
        sleep $DELAY
    fi
done

echo ""
echo "All tests completed. Results saved to: $OUTPUT_FILE"