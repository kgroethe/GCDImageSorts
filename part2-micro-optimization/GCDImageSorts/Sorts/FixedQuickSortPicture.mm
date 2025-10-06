//
//  FixedQuickSortPicture.mm
//  GCDImageSorts
//
//  A PROPERLY optimized QuickSort that actually works
//

#include "FixedQuickSortPicture.h"
#include <algorithm>
#include <cstring>  // for memmove

FixedQuickSortPicture::FixedQuickSortPicture() : SortablePicture() {
    active_tasks = 0;
    simd_partitions = 0;
    regular_partitions = 0;
    
    // Create high-priority queue for performance cores
    dispatch_queue_attr_t attrs = dispatch_queue_attr_make_with_qos_class(
        DISPATCH_QUEUE_CONCURRENT, QOS_CLASS_USER_INTERACTIVE, 0);
    concurrent_queue = dispatch_queue_create("com.gcdsorts.fixed_quicksort", attrs);
    sort_group = dispatch_group_create();
}

FixedQuickSortPicture::~FixedQuickSortPicture() {
    // ARC handles dispatch objects
}

void FixedQuickSortPicture::Sort() {
    if (linearPictSize <= 1) return;
    
    NSDate *startDate = [NSDate date];
    NSLog(@"📐 FIXED QUICKSORT: Starting with %u pixels", linearPictSize);
    
    // Use parallel for large arrays, serial for small
    if (linearPictSize > PARALLEL_THRESHOLD) {
        ParallelQuickSort(0, linearPictSize - 1, sort_group);
        dispatch_group_wait(sort_group, DISPATCH_TIME_FOREVER);
    } else {
        QuickSort(0, linearPictSize - 1);
    }
    
    NSDate *endDate = [NSDate date];
    NSTimeInterval totalSeconds = [endDate timeIntervalSinceDate:startDate];
    
    NSLog(@"📐 FIXED QUICKSORT COMPLETED: %.3f seconds", totalSeconds);
    NSLog(@"📐 STATS: %llu SIMD partitions, %llu regular partitions", 
          simd_partitions.load(), regular_partitions.load());
    NSLog(@"📐 PERFORMANCE: %llu swaps, %llu comparisons", swaps, comparisons);
    
    // Write results for comparison
    NSString *resultString = [NSString stringWithFormat:
        @"FixedQuickSort: %.3f seconds, %llu swaps, %llu comparisons\n", 
        totalSeconds, swaps, comparisons];
    [resultString writeToFile:@"/tmp/fixed_quicksort_result.txt" 
                   atomically:YES 
                     encoding:NSUTF8StringEncoding 
                        error:nil];
    
    // Force final display update to show completed sort
    ForceDraw();
}

void FixedQuickSortPicture::QuickSort(int32_t lower, int32_t upper) {
    while (lower < upper) {
        // Use insertion sort for small arrays
        if (upper - lower < INSERTION_THRESHOLD) {
            InsertionSort(lower, upper);
            return;
        }
        
        // Choose partition method based on size
        int32_t pivot;
        if (upper - lower > SIMD_THRESHOLD) {
            pivot = PartitionWithSIMD(lower, upper);
            simd_partitions++;
        } else {
            pivot = Partition(lower, upper);
            regular_partitions++;
        }

        // No manual draw calls - the NSTimer + SwapPixels model handles UI updates
        
        // Tail recursion optimization: recurse on smaller half
        if (pivot - lower < upper - pivot) {
            QuickSort(lower, pivot - 1);
            lower = pivot + 1;  // Iterate on larger half
        } else {
            QuickSort(pivot + 1, upper);
            upper = pivot - 1;  // Iterate on larger half
        }
    }
}

int32_t FixedQuickSortPicture::Partition(int32_t lower, int32_t upper) {
    // Median-of-three pivot selection (PROPER implementation)
    int32_t mid = lower + (upper - lower) / 2;
    
    // Sort first, middle, last
    if (pixelIndexArray[mid] < pixelIndexArray[lower]) {
        SwapPixels(lower, mid);
    }
    if (pixelIndexArray[upper] < pixelIndexArray[lower]) {
        SwapPixels(lower, upper);
    }
    if (pixelIndexArray[upper] < pixelIndexArray[mid]) {
        SwapPixels(mid, upper);
    }
    comparisons += 3;
    
    // Place median at upper-1 position
    SwapPixels(mid, upper - 1);
    
    uint32_t pivotValue = pixelIndexArray[upper - 1];
    
    // Standard two-pointer partition
    int32_t i = lower;
    int32_t j = upper - 1;
    
    while (true) {
        while (i < upper - 1 && pixelIndexArray[++i] < pivotValue) comparisons++;
        while (j > lower && pixelIndexArray[--j] > pivotValue) comparisons++;
        comparisons += 2;
        
        if (i >= j) break;

        SwapPixels(i, j);
    }

    // Restore pivot
    SwapPixels(i, upper - 1);
    
    return i;
}

int32_t FixedQuickSortPicture::PartitionWithSIMD(int32_t lower, int32_t upper) {
    // For large partitions, SIMD doesn't help much with partitioning
    // The overhead isn't worth it - just use the optimized scalar version
    return Partition(lower, upper);
}

void FixedQuickSortPicture::InsertionSort(int32_t lower, int32_t upper) {
    // Simple insertion sort - turns out to be faster for small arrays
    for (int32_t i = lower + 1; i <= upper; i++) {
        uint32_t key = pixelIndexArray[i];
        int32_t j = i - 1;
        
        while (j >= lower && pixelIndexArray[j] > key) {
            pixelIndexArray[j + 1] = pixelIndexArray[j];
            j--;
            comparisons++;
        }
        if (j >= lower) comparisons++;
        
        pixelIndexArray[j + 1] = key;
        if (j + 1 != i) swaps++;
    }
}

void FixedQuickSortPicture::ParallelQuickSort(int32_t lower, int32_t upper, dispatch_group_t group) {
    if (lower >= upper) return;
    
    // Don't parallelize small sections
    if (upper - lower < PARALLEL_THRESHOLD) {
        QuickSort(lower, upper);
        return;
    }
    
    // Limit parallelism to avoid overhead (M4 has 10 cores)
    if (active_tasks.load() >= 8) {
        QuickSort(lower, upper);
        return;
    }
    
    // Partition
    int32_t pivot = Partition(lower, upper);
    regular_partitions++;
    
    // Sort halves in parallel
    active_tasks.fetch_add(2);
    
    dispatch_group_async(group, concurrent_queue, ^{
        ParallelQuickSort(lower, pivot - 1, group);
        active_tasks.fetch_sub(1);
    });
    
    dispatch_group_async(group, concurrent_queue, ^{
        ParallelQuickSort(pivot + 1, upper, group);
        active_tasks.fetch_sub(1);
    });
}