#!/bin/bash
# =================WRK HTTP LOAD TESTING=================
# Tests HTTP server performance under various loads
# Requires: wrk (github.com/wg/wrk)
# ========================================================

LOG_DIR="benchmark_logs"
LOG_FILE="$LOG_DIR/wrk_results.csv"
WRK_BIN=$(which wrk)
ITERATIONS=5

# Configuration
# Choose test server type: nginx, python, or manual
SERVER_TYPE="nginx"  # Options: nginx, python, manual
LOCAL_SERVER_PORT=8080

# For manual mode, set your target URL
MANUAL_TARGET_URL="http://localhost:8080"

# Test configurations (threads, connections, duration)
THREAD_COUNTS=(1)
CONNECTION_COUNTS=(10)
DURATION="10s"  # Duration of each test

mkdir -p "$LOG_DIR"

# Check if wrk is installed
if [ -z "$WRK_BIN" ]; then
    echo "ERROR: wrk not found. Install from github.com/wg/wrk"
    exit 1
fi

# Function to start nginx test server
start_nginx_server() {
    echo "Starting nginx test server on port $LOCAL_SERVER_PORT..."

    # Check if nginx is installed
    if ! command -v nginx >/dev/null 2>&1; then
        echo "ERROR: nginx not found. Install with: sudo apt-get install nginx"
        return 1
    fi

    # Create temporary nginx config
    NGINX_CONF="/tmp/nginx_bench_test.conf"
    NGINX_ROOT="/tmp/nginx_bench_html"
    NGINX_PID="/tmp/nginx_bench.pid"

    mkdir -p "$NGINX_ROOT"

    # Create test HTML file
    cat > "$NGINX_ROOT/index.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>WRK Benchmark Test</title>
    <meta charset="utf-8">
</head>
<body>
    <h1>nginx Benchmark Test Server</h1>
    <p>This is a test page for WRK HTTP benchmarking.</p>
    <p>Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.</p>
    <ul>
        <li>Fast static content delivery</li>
        <li>Low latency responses</li>
        <li>High throughput capability</li>
    </ul>
</body>
</html>
EOF

    # Create nginx configuration
    cat > "$NGINX_CONF" << EOF
daemon off;
pid $NGINX_PID;
worker_processes auto;
error_log /tmp/nginx_bench_error.log;

events {
    worker_connections 1024;
}

http {
    access_log /tmp/nginx_bench_access.log;
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    sendfile on;
    keepalive_timeout 65;

    server {
        listen $LOCAL_SERVER_PORT;
        server_name localhost;
        root $NGINX_ROOT;

        location / {
            index index.html;
        }
    }
}
EOF

    # Start nginx in background
    nginx -c "$NGINX_CONF" > /dev/null 2>&1 &
    NGINX_PID=$!

    # Wait for nginx to start
    sleep 2

    # Test if server is responding
    if curl -s "http://localhost:$LOCAL_SERVER_PORT" > /dev/null; then
        echo "✓ nginx server started successfully (PID: $NGINX_PID)"
        TARGET_URL="http://localhost:$LOCAL_SERVER_PORT/index.html"
        SERVER_PID=$NGINX_PID
        return 0
    else
        echo "✗ Failed to start nginx server"
        return 1
    fi
}

# Function to stop nginx server
stop_nginx_server() {
    if [ -n "$SERVER_PID" ]; then
        echo "Stopping nginx server (PID: $SERVER_PID)..."
        kill $SERVER_PID 2>/dev/null
        wait $SERVER_PID 2>/dev/null

        # Cleanup temp files
        rm -f /tmp/nginx_bench_test.conf
        rm -f /tmp/nginx_bench.pid
        rm -f /tmp/nginx_bench_error.log
        rm -f /tmp/nginx_bench_access.log
        rm -rf /tmp/nginx_bench_html

        echo "✓ nginx server stopped"
    fi
}

# Function to start Python test server
start_python_server() {
    echo "Starting Python test HTTP server on port $LOCAL_SERVER_PORT..."

    if ! command -v python3 >/dev/null 2>&1; then
        echo "ERROR: Python 3 not found."
        return 1
    fi

    # Create test HTML file
    cat > /tmp/test_index.html << 'EOF'
<!DOCTYPE html>
<html>
<head><title>WRK Test Server</title></head>
<body>
    <h1>Test HTTP Server</h1>
    <p>This is a test page for WRK benchmarking.</p>
    <p>Random data to simulate realistic responses:</p>
    <pre>Lorem ipsum dolor sit amet, consectetur adipiscing elit...</pre>
</body>
</html>
EOF

    # Start Python HTTP server in background
    cd /tmp
    python3 -m http.server $LOCAL_SERVER_PORT > /dev/null 2>&1 &
    SERVER_PID=$!

    # Wait for server to start
    sleep 2

    # Test if server is responding
    if curl -s "http://localhost:$LOCAL_SERVER_PORT" > /dev/null; then
        echo "✓ Python server started successfully (PID: $SERVER_PID)"
        TARGET_URL="http://localhost:$LOCAL_SERVER_PORT/test_index.html"
        return 0
    else
        echo "✗ Failed to start Python server"
        return 1
    fi
}

# Function to stop Python server
stop_python_server() {
    if [ -n "$SERVER_PID" ]; then
        echo "Stopping Python server (PID: $SERVER_PID)..."
        kill $SERVER_PID 2>/dev/null
        wait $SERVER_PID 2>/dev/null
        rm -f /tmp/test_index.html
        echo "✓ Python server stopped"
    fi
}

# Function to stop test server (generic)
stop_test_server() {
    case "$SERVER_TYPE" in
        nginx)
            stop_nginx_server
            ;;
        python)
            stop_python_server
            ;;
        manual)
            # No server to stop
            ;;
    esac
}

# Set up trap to ensure server is stopped on exit
trap stop_test_server EXIT INT TERM

# Start test server based on configuration
case "$SERVER_TYPE" in
    nginx)
        if ! start_nginx_server; then
            echo ""
            echo "Failed to start nginx. Trying Python fallback..."
            SERVER_TYPE="python"
            if ! start_python_server; then
                echo "ERROR: Could not start any test server"
                exit 1
            fi
        fi
        ;;
    python)
        if ! start_python_server; then
            echo "ERROR: Could not start Python server"
            exit 1
        fi
        ;;
    manual)
        TARGET_URL="$MANUAL_TARGET_URL"
        echo "Using manual target: $TARGET_URL"

        # Test if target is reachable
        if ! curl -s "$TARGET_URL" > /dev/null; then
            echo "WARNING: Target URL may not be reachable"
            echo "Continuing anyway..."
        fi
        ;;
    *)
        echo "ERROR: Invalid SERVER_TYPE: $SERVER_TYPE"
        exit 1
        ;;
esac

# Create CSV header
if [ ! -f "$LOG_FILE" ]; then
    echo "timestamp,test_iteration,threads,connections,duration,requests_total,requests_per_sec,transfer_per_sec_mb,latency_avg_ms,latency_stdev_ms,latency_max_ms" > "$LOG_FILE"
fi

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo ""
echo "WRK HTTP Load Testing"
echo "Target: $TARGET_URL"
echo "Server Type: $SERVER_TYPE"
echo "====================="
echo ""

for threads in "${THREAD_COUNTS[@]}"; do
    for connections in "${CONNECTION_COUNTS[@]}"; do
        echo "Testing: threads=$threads, connections=$connections"

        for iter in $(seq 1 $ITERATIONS); do
            echo "  Iteration $iter/$ITERATIONS..."

            # Run wrk and capture output
            WRK_OUTPUT=$($WRK_BIN -t$threads -c$connections -d$DURATION --latency "$TARGET_URL" 2>&1)

            # Check if test succeeded
            if [ $? -eq 0 ]; then
                # Parse results
                REQUESTS_TOTAL=$(echo "$WRK_OUTPUT" | grep "requests in" | awk '{print $1}')
                REQUESTS_PER_SEC=$(echo "$WRK_OUTPUT" | grep "Requests/sec:" | awk '{print $2}')
                TRANSFER_PER_SEC=$(echo "$WRK_OUTPUT" | grep "Transfer/sec:" | awk '{print $2}')

                # Convert transfer to MB (handle KB/MB/GB)
                if echo "$TRANSFER_PER_SEC" | grep -q "KB"; then
                    TRANSFER_MB=$(echo "$TRANSFER_PER_SEC" | sed 's/KB//' | awk '{print $1/1024}')
                elif echo "$TRANSFER_PER_SEC" | grep -q "GB"; then
                    TRANSFER_MB=$(echo "$TRANSFER_PER_SEC" | sed 's/GB//' | awk '{print $1*1024}')
                else
                    TRANSFER_MB=$(echo "$TRANSFER_PER_SEC" | sed 's/MB//')
                fi

                # Parse latency stats (avg, stdev, max)
                LATENCY_AVG=$(echo "$WRK_OUTPUT" | grep "Latency" | head -1 | awk '{print $2}')
                LATENCY_STDEV=$(echo "$WRK_OUTPUT" | grep "Latency" | head -1 | awk '{print $3}')
                LATENCY_MAX=$(echo "$WRK_OUTPUT" | grep "Latency" | head -1 | awk '{print $4}')

                # Convert latency to ms (handle us/ms/s)
                convert_to_ms() {
                    local value=$1
                    if echo "$value" | grep -q "us"; then
                        echo "$value" | sed 's/us//' | awk '{print $1/1000}'
                    elif echo "$value" | grep -q "s"; then
                        echo "$value" | sed 's/s//' | awk '{print $1*1000}'
                    else
                        echo "$value" | sed 's/ms//'
                    fi
                }

                LATENCY_AVG_MS=$(convert_to_ms "$LATENCY_AVG")
                LATENCY_STDEV_MS=$(convert_to_ms "$LATENCY_STDEV")
                LATENCY_MAX_MS=$(convert_to_ms "$LATENCY_MAX")

                # Log results
                echo "$TIMESTAMP,$iter,$threads,$connections,$DURATION,$REQUESTS_TOTAL,$REQUESTS_PER_SEC,$TRANSFER_MB,$LATENCY_AVG_MS,$LATENCY_STDEV_MS,$LATENCY_MAX_MS" >> "$LOG_FILE"

                echo "    ✓ ${REQUESTS_PER_SEC} req/sec, ${LATENCY_AVG_MS} ms avg latency"
            else
                echo "    ✗ Test failed"
                echo "$TIMESTAMP,$iter,$threads,$connections,$DURATION,0,0,0,0,0,0" >> "$LOG_FILE"
            fi

            sleep 3  # Cool-down between tests
        done
        echo ""
    done
done

# Server will be stopped by trap
echo "WRK tests completed. Results: $LOG_FILE"
echo ""
echo "Quick analysis:"
echo "==============="
echo "Best throughput:"
sort -t',' -k7 -rn "$LOG_FILE" | head -1 | awk -F',' '{printf "  %s req/sec with %s threads, %s connections\n", $7, $3, $4}'
echo ""
echo "Best latency:"
sort -t',' -k9 -n "$LOG_FILE" | head -1 | awk -F',' '{printf "  %.2f ms avg with %s threads, %s connections\n", $9, $3, $4}'
