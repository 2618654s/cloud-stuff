#!/bin/bash
# =================MASTER BENCHMARK SCRIPT=================
# This script coordinates all individual benchmark tools
# ==========================================================

# Configuration
LOG_DIR="benchmark_logs"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
ITERATIONS=5

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Color output for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "  Comprehensive Benchmark Suite"
echo "  Started: $TIMESTAMP"
echo "=========================================="
echo ""

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to run a benchmark script
run_benchmark() {
    local script_name=$1
    local tool_name=$2

    if [ -f "$script_name" ]; then
        echo -e "${GREEN}[RUN]${NC} Starting $tool_name benchmark..."
        bash "$script_name"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}[OK]${NC} $tool_name completed successfully"
        else
            echo -e "${RED}[FAIL]${NC} $tool_name failed"
        fi
        echo ""
    else
        echo -e "${YELLOW}[SKIP]${NC} $script_name not found"
        echo ""
    fi
}

# Check for required tools
echo "Checking available tools..."
echo "----------------------------"
command_exists sysbench && echo -e "${GREEN}✓${NC} sysbench" || echo -e "${RED}✗${NC} sysbench (install: apt-get install sysbench)"
command_exists wrk && echo -e "${GREEN}✓${NC} wrk" || echo -e "${YELLOW}⚠${NC} wrk (optional - install from github.com/wg/wrk)"
command_exists locust && echo -e "${GREEN}✓${NC} locust" || echo -e "${YELLOW}⚠${NC} locust (optional - pip install locust)"
command_exists qperf && echo -e "${GREEN}✓${NC} qperf" || echo -e "${YELLOW}⚠${NC} qperf (optional - apt-get install qperf)"
command_exists speedtest && echo -e "${GREEN}✓${NC} speedtest-cli" || echo -e "${YELLOW}⚠${NC} speedtest-cli (optional)"
command_exists stress-ng && echo -e "${GREEN}✓${NC} stress-ng" || echo -e "${YELLOW}⚠${NC} stress-ng (optional - apt-get install stress-ng)"
command_exists iperf3 && echo -e "${GREEN}✓${NC} iperf3" || echo -e "${RED}✗${NC} iperf3 (install: apt-get install iperf3)"
command_exists fio && echo -e "${GREEN}✓${NC} fio" || echo -e "${YELLOW}⚠${NC} fio (optional - apt-get install fio)"
echo ""

# Run individual benchmark scripts
echo "Starting benchmark sequence..."
echo "=============================="
echo ""

run_benchmark "/home/samsaju/cloud-stuff/scripts/stress_ng.sh" "Stress-NG (System Stress)"
# run_benchmark "sysbench.sh" "Sysbench (CPU/Memory/Disk)"

run_benchmark "/home/samsaju/cloud-stuff/scripts/qperf.sh" "QPERF (Network Performance)"
run_benchmark "/home/samsaju/cloud-stuff/scripts/speedtest.sh" "Speedtest (Internet Speed)"
run_benchmark "/home/samsaju/cloud-stuff/scripts/network.sh" "Network Tests (Ping/iPerf)"
# run_benchmark "fio.sh" "FIO (Advanced Disk I/O)"
run_benchmark "/home/samsaju/cloud-stuff/scripts/nginx.sh" "Nginx"
run_benchmark "/home/samsaju/cloud-stuff/scripts/forksum_script.sh" "Forksum"

echo "=========================================="
echo "  Benchmark Suite Completed"
echo "  Logs stored in: $LOG_DIR/"
echo "=========================================="

# Generate summary report
echo ""
echo "Generating summary report..."
bash generate_summary.sh 2>/dev/null || echo "Summary generation skipped (generate_summary.sh not found)"
