# Cloud Stuff

## Stack

### CPU Tests

#### Forksum
- Takes an integer range, splits it in half, and then forks processes; each process calculates its sum.  
- This cycle repeats until the total sum is computed.  
- Tests the speed of:
  - Arithmetic operations  
  - Spawning processes  
  - Performing function calls  

- **Configurations:**
  1. **Light load:** Sum numbers 1 to 1000  
  2. **Heavy load:** Sum numbers 1 to 5000  
  3. **Concurrent load:** Run two light-load forksum processes concurrently (sum 1 to 1000)  

#### Sysbench
- CPU-focused benchmark (unlike Forksum which also tests OS process scheduling).  
- Measures how fast the CPU can perform computations in **user space**.  
- Tracks:
  - **Load average**  
  - **Free RAM**  
  - **Result value**  

| Metric | Description |
|--------|-------------|
| **load_avg_1min** | System load average over the past 1 minute. Gives an idea of how busy the system was while the benchmark ran. Lower numbers (~1 per core) indicate little interference; higher numbers indicate other workloads may have affected results. |
| **free_ram_mb** | Free RAM in megabytes at the time of the test. Low free RAM can trigger swapping and affect results, especially for memory- and disk-intensive benchmarks. |
| **result_value** | The measured performance metric. Depends on benchmark type: <br> - CPU: events per second (number of primes computed per second) <br> - Memory: MiB/sec (throughput) <br> - Disk: MiB/sec (read/write throughput) |

---

### Disk I/O Tests

#### FIO
- Run `fio` to measure I/O performance.  
- **Parameters:**
  - `--rw` → type of I/O (randread, randwrite, read, write)  
  - `--bs` → block size (4K for random, 1M for sequential)  
  - `--size` → test file size  
  - `--numjobs=1` → single FIO thread  
  - `--runtime` → 20 seconds  
  - `--time_based` → ignore total size, run for specified time  
  - `--group_reporting` → summarize per-job stats  
  - `--output-format=json` → output JSON to temp file  

- **Measures:**
  - Read, write, and sequential read speeds  
  - Bandwidth  
  - Mean latency  
  - Number of I/O operations the instance could perform per second  

---

### Network Tests

- **Ping tests** across different DNS servers:
  - Google Cloud  
  - Cloudflare  
  - Internal server (another instance running an iperf3 server)  

- Test both **UDP** and **TCP** protocols.  
- Measure:
  - Latency of ping  
  - Bandwidth between the instance and iperf3 server  

---

### Web Server Tests

#### Nginx
- Create and stop a web server instance to simulate web server performance.  
- Send HTTP requests to simulate client activity.  
- Iterate through different numbers of connections and measure **requests per second**.  

---

### Internet Speed Tests

#### Speedtest
- Test bandwidth between the instance and **speedtest.net servers** in three locations:
  - Omaha  
  - Blair  
  - Bloomfield (all NE)  
- Record:
  - Ping  
  - Upload/download bandwidth
