#!/bin/bash
# =================SUMMARY REPORT GENERATOR=================
# Analyzes all benchmark results and creates a summary
# ==========================================================

LOG_DIR="benchmark_logs"
SUMMARY_FILE="$LOG_DIR/SUMMARY_REPORT.txt"

echo "Generating Summary Report..."
echo "============================="
echo ""

# Create summary file
cat > "$SUMMARY_FILE" << 'EOF'
================================================================================
                    BENCHMARK SUMMARY REPORT
================================================================================
Generated: $(date)

EOF

# Function to calculate statistics from CSV
calc_stats() {
    local file=$1
    local column=$2
    local label=$3
    
    if [ -f "$file" ]; then
        local count=$(tail -n +2 "$file" | wc -l)
        if [ $count -gt 0 ]; then
            echo "" >> "$SUMMARY_FILE"
            echo "--- $label ---" >> "$SUMMARY_FILE"
            echo "Total tests: $count" >> "$SUMMARY_FILE"
            
            # Calculate average for numeric column
            local avg=$(tail -n +2 "$file" | cut -d',' -f"$column" | \
                       awk '{sum+=$1; count++} END {if(count>0) print sum/count; else print 0}')
            
            local min=$(tail -n +2 "$file" | cut -d',' -f"$column" | sort -n | head -1)
            local max=$(tail -n +2 "$file" | cut -d',' -f"$column" | sort -n | tail -1)
            
            echo "Average: $avg" >> "$SUMMARY_FILE"
            echo "Min: $min" >> "$SUMMARY_FILE"
            echo "Max: $max" >> "$SUMMARY_FILE"
        fi
    fi
}

# Sysbench Summary
if [ -f "$LOG_DIR/sysbench_results.csv" ]; then
    echo "════════════════════════════════════════════════════════════════" >> "$SUMMARY_FILE"
    echo "SYSBENCH RESULTS" >> "$SUMMARY_FILE"
    echo "════════════════════════════════════════════════════════════════" >> "$SUMMARY_FILE"
    
    # CPU results
    grep ",cpu," "$LOG_DIR/sysbench_results.csv" | head -1 > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        calc_stats "$LOG_DIR/sysbench_results.csv" 7 "CPU Performance (events/sec)"
    fi
    
    # Memory results
    grep ",memory," "$LOG_DIR/sysbench_results.csv" | head -1 > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        calc_stats "$LOG_DIR/sysbench_results.csv" 7 "Memory Throughput (MiB/sec)"
    fi
fi

# WRK Summary
if [ -f "$LOG_DIR/wrk_results.csv" ]; then
    echo "" >> "$SUMMARY_FILE"
    echo "════════════════════════════════════════════════════════════════" >> "$SUMMARY_FILE"
    echo "WRK HTTP LOAD TESTING RESULTS" >> "$SUMMARY_FILE"
    echo "════════════════════════════════════════════════════════════════" >> "$SUMMARY_FILE"
    
    calc_stats "$LOG_DIR/wrk_results.csv" 7 "Requests per Second"
    calc_stats "$LOG_DIR/wrk_results.csv" 9 "Average Latency (ms)"
fi

# QPERF Summary
if [ -f "$LOG_DIR/qperf_results.csv" ]; then
    echo "" >> "$SUMMARY_FILE"
    echo "════════════════════════════════════════════════════════════════" >> "$SUMMARY_FILE"
    echo "QPERF NETWORK RESULTS" >> "$SUMMARY_FILE"
    echo "════════════════════════════════════════════════════════════════" >> "$SUMMARY_FILE"
    
    calc_stats "$LOG_DIR/qperf_results.csv" 5 "Network Performance"
fi

# Speedtest Summary
if [ -f "$LOG_DIR/speedtest_results.csv" ]; then
    echo "" >> "$SUMMARY_FILE"
    echo "════════════════════════════════════════════════════════════════" >> "$SUMMARY_FILE"
    echo "SPEEDTEST INTERNET RESULTS" >> "$SUMMARY_FILE"
    echo "════════════════════════════════════════════════════════════════" >> "$SUMMARY_FILE"
    
    calc_stats "$LOG_DIR/speedtest_results.csv" 6 "Download Speed (Mbps)"
    calc_stats "$LOG_DIR/speedtest_results.csv" 7 "Upload Speed (Mbps)"
    calc_stats "$LOG_DIR/speedtest_results.csv" 5 "Ping Latency (ms)"
fi

# Stress-NG Summary
if [ -f "$LOG_DIR/stress_ng_results.csv" ]; then
    echo "" >> "$SUMMARY_FILE"
    echo "════════════════════════════════════════════════════════════════" >> "$SUMMARY_FILE"
    echo "STRESS-NG SYSTEM STRESS RESULTS" >> "$SUMMARY_FILE"
    echo "════════════════════════════════════════════════════════════════" >> "$SUMMARY_FILE"
    
    calc_stats "$LOG_DIR/stress_ng_results.csv" 7 "Bogo Ops per Second"
fi

# Network Summary
if [ -f "$LOG_DIR/network_results.csv" ]; then
    echo "" >> "$SUMMARY_FILE"
    echo "════════════════════════════════════════════════════════════════" >> "$SUMMARY_FILE"
    echo "NETWORK PERFORMANCE RESULTS" >> "$SUMMARY_FILE"
    echo "════════════════════════════════════════════════════════════════" >> "$SUMMARY_FILE"
    
    # Ping results
    grep "ping_avg" "$LOG_DIR/network_results.csv" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "" >> "$SUMMARY_FILE"
        echo "--- Average Ping Latencies ---" >> "$SUMMARY_FILE"
        grep "ping_avg" "$LOG_DIR/network_results.csv" | \
            awk -F',' '{sum[$4]+=$7; count[$4]++} END {for(t in sum) print t": "sum[t]/count[t]" ms"}' >> "$SUMMARY_FILE"
    fi
    
    # iPerf results
    grep "iperf_bw" "$LOG_DIR/network_results.csv" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        calc_stats "$LOG_DIR/network_results.csv" 7 "iPerf3 Bandwidth (Mbps)"
    fi
fi

# FIO Summary
if [ -f "$LOG_DIR/fio_results.csv" ]; then
    echo "" >> "$SUMMARY_FILE"
    echo "════════════════════════════════════════════════════════════════" >> "$SUMMARY_FILE"
    echo "FIO DISK I/O RESULTS" >> "$SUMMARY_FILE"
    echo "════════════════════════════════════════════════════════════════" >> "$SUMMARY_FILE"
    
    # Sequential Read
    grep ",read," "$LOG_DIR/fio_results.csv" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "" >> "$SUMMARY_FILE"
        echo "--- Sequential Read Performance ---" >> "$SUMMARY_FILE"
        grep ",read," "$LOG_DIR/fio_results.csv" | \
            awk -F',' '{sum_iops+=$7; sum_bw+=$8; count++} END {print "Avg IOPS: "sum_iops/count"\nAvg BW: "sum_bw/count" MB/s"}' >> "$SUMMARY_FILE"
    fi
    
    # Random Read
    grep ",randread," "$LOG_DIR/fio_results.csv" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "" >> "$SUMMARY_FILE"
        echo "--- Random Read Performance ---" >> "$SUMMARY_FILE"
        grep ",randread," "$LOG_DIR/fio_results.csv" | \
            awk -F',' '{sum_iops+=$7; sum_bw+=$8; count++} END {print "Avg IOPS: "sum_iops/count"\nAvg BW: "sum_bw/count" MB/s"}' >> "$SUMMARY_FILE"
    fi
    
    # Sequential Write
    grep ",write," "$LOG_DIR/fio_results.csv" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "" >> "$SUMMARY_FILE"
        echo "--- Sequential Write Performance ---" >> "$SUMMARY_FILE"
        grep ",write," "$LOG_DIR/fio_results.csv" | \
            awk -F',' '{sum_iops+=$10; sum_bw+=$11; count++} END {print "Avg IOPS: "sum_iops/count"\nAvg BW: "sum_bw/count" MB/s"}' >> "$SUMMARY_FILE"
    fi
    
    # Random Write
    grep ",randwrite," "$LOG_DIR/fio_results.csv" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "" >> "$SUMMARY_FILE"
        echo "--- Random Write Performance ---" >> "$SUMMARY_FILE"
        grep ",randwrite," "$LOG_DIR/fio_results.csv" | \
            awk -F',' '{sum_iops+=$10; sum_bw+=$11; count++} END {print "Avg IOPS: "sum_iops/count"\nAvg BW: "sum_bw/count" MB/s"}' >> "$SUMMARY_FILE"
    fi
fi

echo "" >> "$SUMMARY_FILE"
echo "=================================================================================" >> "$SUMMARY_FILE"
echo "End of Report" >> "$SUMMARY_FILE"
echo "=================================================================================" >> "$SUMMARY_FILE"

# Display summary
cat "$SUMMARY_FILE"
echo ""
echo "Summary saved to: $SUMMARY_FILE"