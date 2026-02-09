#include <errno.h>
#include <stdlib.h>
#include <stdio.h>
#include <time.h> // Added for clock_gettime
#include <sys/wait.h>
#include <unistd.h>

/*
 * Modified forksum.c for Cloud Benchmarking
 * Changes: Added execution timer and CSV output format.
 */

typedef struct Result
{
	int sum;
	int num;
} Result;

Result forksum(int start, int end);
int parseInt(char *str, char *errMsg);

int spawnChild(int start, int end)
{
	int pipefd[2];
	if (pipe(pipefd) < 0)
	{
		perror("pipe");
		exit(1);
	}

	int child;
	while ((child = fork()) < 0)
	{
		perror("fork");
	}
	if (child == 0)
	{
		Result result = forksum(start, end);

		close(pipefd[0]);
		FILE *stream = fdopen(pipefd[1], "w");
		if (!stream)
		{
			perror("fdopen child write pipe");
			exit(1);
		}
		fprintf(stream, "%d\n%d\n", result.sum, result.num);
		exit(0);
	}

	close(pipefd[1]);
	return pipefd[0];
}

int readIntLine(FILE *stream, char *errorMsg)
{
	size_t bufSize = 1024;
	char *line = malloc(bufSize);
	ssize_t len = getline(&line, &bufSize, stream);

	if (len < 0)
	{
		perror("read line from child");
		return 0;
	}
	line[len - 1] = '\0';
	return parseInt(line, errorMsg);
}

Result readChild(int fd)
{
	FILE *stream = fdopen(fd, "r");
	if (!stream)
	{
		perror("fdopen child read pipe");
		exit(1);
	}
	int sum = readIntLine(stream, "Failed to parse sum result from child");
	int num = readIntLine(stream, "Failed to parse num result from child");
	return (Result){sum, num};
}

Result forksum(int start, int end)
{
	if (start >= end)
	{
		if (start > end)
			fprintf(stderr, "Start bigger than end: %d - %d\n", start, end);
		return (Result){start, 1};
	}

	int mid = start + (end - start) / 2;
	int child1 = spawnChild(start, mid);
	int child2 = spawnChild(mid + 1, end);

	Result res1 = readChild(child1);
	Result res2 = readChild(child2);

	wait(0);
	wait(0);
	return (Result){res1.sum + res2.sum, res1.num + res2.num + 1};
}

int parseInt(char *str, char *errMsg)
{
	char *endptr = NULL;
	errno = 0;
	int result = strtol(str, &endptr, 10);
	if (errno != 0)
	{
		perror(errMsg);
		exit(1);
	}
	if (*endptr)
	{
		fprintf(stderr, "%s: %s\n", errMsg, str);
		exit(1);
	}
	return result;
}

int main(int argc, char **args)
{
	if (argc != 3)
	{
		fprintf(stderr, "Need 2 parameters: start and end\n");
		exit(1);
	}
	int start = parseInt(args[1], "Failed to parse start argument");
	int end = parseInt(args[2], "Failed to parse end argument");

	// --- TIMING START ---
	struct timespec ts_start, ts_end;
	clock_gettime(CLOCK_MONOTONIC, &ts_start);

	Result result = forksum(start, end);

	// --- TIMING END ---
	clock_gettime(CLOCK_MONOTONIC, &ts_end);

	// Calculate time in seconds
	double time_taken = (ts_end.tv_sec - ts_start.tv_sec) +
						(ts_end.tv_nsec - ts_start.tv_nsec) * 1e-9;

	// Calculate Forks Per Second (throughput)
	double fps = result.num / time_taken;

	// Validation (Logic preserved, but output silenced unless error)
	int test = (end * (end + 1) / 2) - (start * (start + 1) / 2) + start;
	if (test != result.sum)
	{
		fprintf(stderr, "Wrong result: %d (should be: %d)\n", result.sum, test);
		exit(1);
	}

	// --- CSV OUTPUT ---
	// Format: start, end, total_sum, total_forks, duration_seconds, forks_per_second
	fprintf(stdout, "%d,%d,%d,%d,%.6f,%.2f\n", start, end, result.sum, result.num, time_taken, fps);

	return 0;
}