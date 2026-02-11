# cloud-stuff
stack
cpu tests:
forksum:
takes integer range, splits in half, and then forks process and each process responsible for calculating sum - this cycle keeps on repeating until sum reached; tests speed of arithmetic operations, spawning of processes and performing function calls.
Performs 3 configurations:
light load: sum nums 1 to 1000
heavy load: sum nums 1 to 5000
concurrent load: runs two light load forksum processes concurrently (sum 1 to 1000)
fio:
run fio to measure io peformance
parameters:
--rw → type of IO (randread, randwrite, read, write)
--bs → block size (4k for random, 1M for sequential)
--size → test file size
--numjobs=1 → single FIO thread
--runtime → 20 seconds
--time_based → ignore total size, run for specified time
--group_reporting → summarize per-job stats
--output-format=json → output JSON to temp file
test read, write, and sequential read speeds, measure bandwidth, mean latency, and the number of io operations the instance could perform per second
network
test ping across different dns servers: google cloud, cloudflare and an internal server (another instance dedicated to running iperf3 server)
test both udp and tdp protocols
measure: latency of ping and bandwidth between instance and iperf3 server
nginx:
create and stop web server instance to simulate web server performance & send http requests to simulate what clients may do
iterates through different number of connections and measures number of requests that were achieved per second
speedtest
test bandwidth between instance and other speedtest.net servers in three different locations
omaha, blair, bloomfield (all NE)
record ping, upld/download bandwidth
sysbench
cpu focused benchmark unlike fork which also assessed os process scheduling
focus on how fast cpu can perform computations in user space
load average, free ram and result value
load_avg_1min	System load average over the past 1 minute	Gives an idea of how busy the system was while the benchmark ran. Lower numbers (~1 per core) indicate little interference, higher numbers indicate other workloads might have affected results.
free_ram_mb	Free RAM in megabytes at the time of the test	Indicates available memory. Low free RAM can trigger swapping and affect results, especially for memory- and disk-intensive benchmarks.
result_value	The measured performance metric	Depends on the benchmark type:
- CPU: events per second (number of primes computed per second)
- Memory: MiB/sec (throughput)
- Disk: MiB/sec (read/write throughput)


