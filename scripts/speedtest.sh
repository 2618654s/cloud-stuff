#!/bin/bash

# Configuration
OUTPUT_FILE="benchmark_logs/speedtest_results.csv"
runs=5  # Default to 1 run if no argument is provided
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
    echo "timestamp,test_iteration,server_name,server_location,ping_ms,download_mbps,upload_mbps,packet_loss_percent,isp" > "$OUTPUT_FILE"
fi

echo "Starting Speedtest ($runs iteration(s))..."

for (( i=1; i<=runs; i++ ))
do
    echo "Running test $i of $runs..."

    # Run speedtest and capture JSON output
    # --accept-license and --accept-gdpr prevent interactive prompts
    json_output=$(speedtest --format=json --accept-license --accept-gdpr)

    # Check if the speedtest command failed
    if [ $? -ne 0 ] || [ -z "$json_output" ]; then
        echo "Error: Speedtest failed on iteration $i."
        continue
    fi

    # Parse JSON using jq
    # Note: Ookla provides bandwidth in bytes/sec. We multiply by 8 to get bits, then divide by 1,000,000 for Mbps.
    # We use -r for raw output to avoid extra quotes around strings
    
    timestamp=$(echo "$json_output" | jq -r '.timestamp')
    server_name=$(echo "$json_output" | jq -r '.server.name // "N/A"')
    server_location=$(echo "$json_output" | jq -r '.server.location // "N/A"')
    ping=$(echo "$json_output" | jq -r '.ping.latency // 0')
    
    # Calculate Mbps (Bytes * 8 / 1,000,000)
    download=$(echo "$json_output" | jq -r '(.download.bandwidth * 8 / 1000000) | . * 100 | floor / 100')
    upload=$(echo "$json_output" | jq -r '(.upload.bandwidth * 8 / 1000000) | . * 100 | floor / 100')
    
    # Handle Packet Loss (often null if 0% loss, so we default to 0)
    packet_loss=$(echo "$json_output" | jq -r '.packetLoss // 0')
    isp=$(echo "$json_output" | jq -r '.isp // "Unknown"')

    # Write to CSV
    # We quote the strings just in case they contain commas (like "Comcast Cable, LLC")
    echo "$timestamp,$i,\"$server_name\",\"$server_location\",$ping,$download,$upload,$packet_loss,\"$isp\"" >> "$OUTPUT_FILE"

    echo "Iteration $i complete. Results saved to $OUTPUT_FILE"
    
    # Wait before next run (except after the last one)
    if [ $i -lt $runs ]; then
        sleep $DELAY
    fi
done

echo "All tests completed."