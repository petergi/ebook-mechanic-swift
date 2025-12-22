#!/bin/bash

# swift/benchmark-parallel.sh

# This script benchmarks the parallel validation performance of the EbookMechanicCLI tool.
# It runs the tool with different concurrency levels and with/without the cache,
# and then prints a summary of the performance statistics.

set -e

# --- Configuration ---

# Number of books to generate for the test library
NUM_BOOKS=100

# Concurrency levels to test
CONCURRENCY_LEVELS=(1 2 4 8 16)

# --- Helper Functions ---

function print_header() {
    echo " "
    echo "======================================================================="
    echo "  $1"
    echo "======================================================================="
    echo " "
}

function print_footer() {
    echo " "
    echo "======================================================================="
    echo " "
}

# --- Main Script ---

# Change to the EbookMechanicCLI directory
cd "$(dirname "$0")/EbookMechanicCLI"

# 1. Build the CLI tool
print_header "Building EbookMechanicCLI"
swift build -c release
CLI_PATH="$(swift build -c release --show-bin-path)/EbookMechanicCLI"
echo "CLI Path: $CLI_PATH"
print_footer

# 2. Create a temporary directory for the benchmark
BENCHMARK_DIR=$(mktemp -d -t ebookmechanic-benchmark-XXXXXX)
echo "Benchmark directory: $BENCHMARK_DIR"

# 3. Generate a test library
print_header "Generating test library with $NUM_BOOKS books"
python3 ../../scripts/generate_test_library.py "$BENCHMARK_DIR" --num-books $NUM_BOOKS
echo "Test library generated."
print_footer

# 4. Run benchmarks
RESULTS_FILE=$(mktemp -t ebookmechanic-benchmark-results-XXXXXX)
echo "Concurrency,Cache,TotalTime,FilesPerSecond,AvgValidationTime,CacheHitRate" > "$RESULTS_FILE"

for concurrency in "${CONCURRENCY_LEVELS[@]}"; do
    for cache_status in "enabled" "disabled"; do
        print_header "Running benchmark: Concurrency=$concurrency, Cache=$cache_status"
        
        # Determine cache flag
        if [ "$cache_status" == "disabled" ]; then
            CACHE_FLAG="--no-cache"
        else
            CACHE_FLAG=""
        fi
        
        # Run the command and capture output
        output=$($CLI_PATH --dir "$BENCHMARK_DIR" --performance-stats --max-concurrent "$concurrency" $CACHE_FLAG)
        
        # Extract performance metrics
        total_time=$(echo "$output" | grep "Total validation time" | awk '{print $5}' | sed 's/s//')
        files_per_second=$(echo "$output" | grep "Files per second" | awk '{print $4}')
        avg_validation_time=$(echo "$output" | grep "Average validation time" | awk '{print $4}' | sed 's/s//')
        cache_hit_rate=$(echo "$output" | grep "Cache hit rate" | awk '{print $4}' | sed 's/%//')
        
        # Print the metrics
        echo "  Total validation time: ${total_time}s"
        echo "  Files per second: $files_per_second"
        echo "  Average validation time: ${avg_validation_time}s"
        echo "  Cache hit rate: ${cache_hit_rate}%"
        
        # Save results to CSV
        echo "$concurrency,$cache_status,$total_time,$files_per_second,$avg_validation_time,$cache_hit_rate" >> "$RESULTS_FILE"
        
        print_footer
    done
done

# 5. Print summary
print_header "Benchmark Results Summary"
cat "$RESULTS_FILE" | csvlook
print_footer

# 6. Clean up
echo "Cleaning up benchmark directory: $BENCHMARK_DIR"
rm -rf "$BENCHMARK_DIR"
rm -f "$RESULTS_FILE"

echo "Benchmark complete."
