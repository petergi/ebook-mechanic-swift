# Phase 05: Parallel Validation Performance Optimization

This phase optimizes validation performance by implementing parallel validation similar to the worker pool pattern in the reference Go projects, while maintaining Swift's actor-based concurrency model. This will significantly speed up validation of large ebook libraries.

## Tasks

- [ ] Update FileScanner actor in FileScanner.swift to add configurable maxConcurrentValidations property (default: ProcessInfo.processInfo.activeProcessorCount)
- [ ] Implement async TaskGroup-based parallel validation in validateFiles method: create TaskGroup with maxConcurrentValidations limit, submit validation tasks to group with automatic load balancing, collect results as tasks complete while maintaining progress updates
- [ ] Add validationBatchSize configuration option to control how many files are queued ahead (default: maxConcurrentValidations * 2 for optimal throughput)
- [ ] Update ProgressEvent enum to include concurrentValidationCount property showing current number of files being validated simultaneously
- [ ] Create ValidationQueue actor to manage validation task distribution with priority queue (corrupt files from previous scans get lower priority), rate limiting for external tool calls to avoid overwhelming system, fair distribution across file types
- [ ] Update ExternalToolRunner.swift to add semaphore-based rate limiting: maximum concurrent external tool processes (default: 4), queue external tool requests when limit reached, prevent resource exhaustion from too many concurrent pdfcpu/epubcheck processes
- [ ] Add PerformanceMetrics struct to track validation statistics: files per second, average validation time by format, external tool call count, cache hit rate, parallel efficiency ratio
- [ ] Implement validation result caching in FileValidator: SHA256-based cache key from file path + modification time + size, cache stores ValidationResult for recent validations, configurable cache size (default: 1000 entries), automatic eviction of oldest entries
- [ ] Add ParallelValidationTests.swift with tests for correct parallel execution with varying concurrency limits, progress event ordering and accuracy, cache correctness under concurrent access, external tool rate limiting effectiveness
- [ ] Update CLIConfiguration.swift to add --max-concurrent flag to control parallel validation limit, --no-cache flag to disable validation caching, --performance-stats flag to display detailed performance metrics at end
- [ ] Update ProgressPrinter.swift to show concurrent validation count in progress output: "Validating (3 concurrent): file.epub", display performance stats when --performance-stats enabled showing throughput and efficiency metrics
- [ ] Create benchmark comparison script Scripts/benchmark-parallel.sh that tests validation with concurrency levels 1, 2, 4, 8, 16, measures throughput at each level, generates performance chart data, compares against single-threaded baseline