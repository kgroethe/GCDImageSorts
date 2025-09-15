//
//  ThreadedQuickSortPicture.mm
//  PThreadSorts
//
//  Contains: Modern GCD Concurrent Quick Sort and Merge Sort Implementation
//           Replaced original pthread implementation with GCD for better performance.
//
//  Originally by Karl Groethe, 2000
//  Modernized for macOS 11.0+, 2024
//

#include "ThreadedQuickSortPicture.h"
#include <algorithm>

ThreadedQuickSortPicture::ThreadedQuickSortPicture(uint32_t inAlgorithmType) : SortablePicture() {
    algorithmType = inAlgorithmType;
    active_tasks = 0;
    tempArray = nullptr;
    
    if (algorithmType == 1) {
        // GCD QuickSort setup - Use high priority for M4 performance cores
        dispatch_queue_attr_t attrs = dispatch_queue_attr_make_with_qos_class(
            DISPATCH_QUEUE_CONCURRENT, QOS_CLASS_USER_INTERACTIVE, 0);
        concurrent_queue = dispatch_queue_create("com.pthreadsorts.gcdquicksort", attrs);
        sort_group = dispatch_group_create();
    } else {
        // Merge Sort doesn't need concurrent queue
        concurrent_queue = nullptr;
        sort_group = nullptr;
    }
}

ThreadedQuickSortPicture::~ThreadedQuickSortPicture() {
    // In ARC, dispatch objects are automatically managed
    if (tempArray) {
        delete[] tempArray;
        tempArray = nullptr;
    }
}

NSString* ThreadedQuickSortPicture::GetSortName() {
    switch (algorithmType) {
        case 1:
            return @"GCD Concurrent Quick Sort";
        case 2:
            return @"Merge Sort";
        default:
            return @"Unknown Sort";
    }
}

NSString* ThreadedQuickSortPicture::GetBigONotation() {
    switch (algorithmType) {
        case 1:
            return @"O(n log n)";  // QuickSort average case
        case 2:
            return @"O(n log n)";  // Merge Sort always
        default:
            return @"O(?)";
    }
}

void ThreadedQuickSortPicture::Sort() {
    if (linearPictSize <= 1) return;
    
    NSDate *startDate = [NSDate date];
    
    if (algorithmType == 1) {
        // GCD Concurrent QuickSort
        active_tasks = 0;
        
        // For very large datasets, avoid aggressive parallelization that can cause overhead
        // Use standard quicksort for large images as the kickstart can be counterproductive
        gcdQuicksort(0, linearPictSize - 1, sort_group);
        
        dispatch_group_wait(sort_group, DISPATCH_TIME_FOREVER);
    } else if (algorithmType == 2) {
        // Merge Sort
        tempArray = new uint32_t[linearPictSize];
        mergeSort(0, linearPictSize - 1);
        delete[] tempArray;
        tempArray = nullptr;
        
        // Force final display update to show completed sort
        ForceDraw();
    }
    
    NSDate *endDate = [NSDate date];
    NSTimeInterval totalSeconds = [endDate timeIntervalSinceDate:startDate];
    
    NSString *sortName = (algorithmType == 1) ? @"GCD QuickSort" : @"Merge Sort";
    NSString *fileName = (algorithmType == 1) ? @"/tmp/gcd_quicksort_result.txt" : @"/tmp/mergesort_result.txt";
    
    NSLog(@"%@ completed: %.3f seconds, %llu swaps, %llu comparisons", 
          sortName, totalSeconds, swaps, comparisons);
    
    NSString *resultString = [NSString stringWithFormat:
        @"%@: %.3f seconds, %llu swaps, %llu comparisons\n", 
        sortName, totalSeconds, swaps, comparisons];
    [resultString writeToFile:fileName 
                   atomically:YES 
                     encoding:NSUTF8StringEncoding 
                        error:nil];
}

// GCD QuickSort Implementation
void ThreadedQuickSortPicture::gcdQuicksort(int32_t lower, int32_t upper, dispatch_group_t group) {
    if (lower < upper) {
        int32_t range = upper - lower;
        
        // For smaller ranges, use efficient serial quicksort
        // Use larger threshold for very large datasets to reduce task overhead
        int32_t dynamicThreshold = (linearPictSize > 1000000) ? threshold * 4 : threshold;
        if (range < dynamicThreshold) {
            serialQuicksort(lower, upper);
            return;
        }
        
        // Use efficient two-pointer partition (same as original quicksort)
        int32_t pivot_pos = efficientPartition(lower, upper);
        
        // Optimize for M4: 4 performance + 6 efficiency cores = 10 total
        // Allow moderate parallelization without oversaturating the scheduler
        // Reduce max tasks for very large datasets to prevent scheduler overhead
        int32_t maxTasks = (linearPictSize > 2000000) ? 8 : 16;
        if (active_tasks.load() < maxTasks) {
            // Increment active task counter
            active_tasks.fetch_add(2);
            
            // Sort left partition asynchronously
            dispatch_group_async(group, concurrent_queue, ^{
                gcdQuicksort(lower, pivot_pos - 1, group);
                active_tasks.fetch_sub(1);
            });
            
            // Sort right partition asynchronously  
            dispatch_group_async(group, concurrent_queue, ^{
                gcdQuicksort(pivot_pos + 1, upper, group);
                active_tasks.fetch_sub(1);
            });
        } else {
            // Only fall back to serial when we have too many tasks
            serialQuicksort(lower, pivot_pos - 1);
            serialQuicksort(pivot_pos + 1, upper);
        }
    }
}

// Aggressive initial parallelization for large datasets
void ThreadedQuickSortPicture::kickstartParallelization() {
    // Create initial partitions to immediately saturate all cores
    int32_t num_initial_partitions = 8;  // Start with 8 chunks to feed all cores
    int32_t chunk_size = linearPictSize / num_initial_partitions;
    
    // Pre-partition the array into chunks and sort each chunk in parallel
    for (int32_t i = 0; i < num_initial_partitions; i++) {
        int32_t start = i * chunk_size;
        int32_t end = (i == num_initial_partitions - 1) ? linearPictSize - 1 : (start + chunk_size - 1);
        
        active_tasks.fetch_add(1);
        dispatch_group_async(sort_group, concurrent_queue, ^{
            gcdQuicksort(start, end, sort_group);
            active_tasks.fetch_sub(1);
        });
    }
    
    // Wait for initial chunks to complete, then merge adjacent sorted chunks
    dispatch_group_wait(sort_group, DISPATCH_TIME_FOREVER);
    
    // Now merge the sorted chunks using parallel merge operations
    int32_t current_chunk_size = chunk_size;
    while (current_chunk_size < linearPictSize) {
        int32_t new_chunk_size = current_chunk_size * 2;
        
        for (int32_t start = 0; start < linearPictSize; start += new_chunk_size) {
            int32_t mid = start + current_chunk_size - 1;
            int32_t end = MIN(start + new_chunk_size - 1, linearPictSize - 1);
            
            if (mid < end) {
                active_tasks.fetch_add(1);
                dispatch_group_async(sort_group, concurrent_queue, ^{
                    // Use merge-like approach to combine two sorted subarrays
                    mergeInPlace(start, mid, end);
                    active_tasks.fetch_sub(1);
                });
            }
        }
        
        dispatch_group_wait(sort_group, DISPATCH_TIME_FOREVER);
        current_chunk_size = new_chunk_size;
    }
}

// In-place merge for combining sorted chunks
void ThreadedQuickSortPicture::mergeInPlace(int32_t start, int32_t mid, int32_t end) {
    // For simplicity, use quicksort on the combined range
    // This isn't a true merge but leverages existing efficient partition logic
    gcdQuicksort(start, end, sort_group);
}

// Efficient serial quicksort (identical to original algorithm)
void ThreadedQuickSortPicture::serialQuicksort(int32_t lower, int32_t upper) {
    if (lower < upper) {
        int32_t pivot_pos = efficientPartition(lower, upper);
        serialQuicksort(lower, pivot_pos - 1);
        serialQuicksort(pivot_pos + 1, upper);
    }
}

// Two-pointer partition (same algorithm as original QuickSort for efficiency)
int32_t ThreadedQuickSortPicture::efficientPartition(int32_t lower, int32_t upper) {
    int32_t pivot = lower;
    int32_t left = lower + 1;
    int32_t right = upper;
    
    while (left <= right) {
        while (left <= upper && InOrder(left, pivot)) left++;
        while (right >= lower && !InOrder(right, pivot)) right--;
        
        if (left < right) {
            SwapPixels(left, right);
        }
    }
    
    SwapPixels(pivot, right);
    return right;
}

// Legacy partition function (kept for merge sort compatibility)
int32_t ThreadedQuickSortPicture::partition(int32_t lower, int32_t upper) {
    return efficientPartition(lower, upper);
}

// Merge Sort Implementation
void ThreadedQuickSortPicture::mergeSort(int32_t left, int32_t right) {
    if (left < right) {
        int32_t mid = left + (right - left) / 2;
        
        // Sort first half
        mergeSort(left, mid);
        
        // Sort second half
        mergeSort(mid + 1, right);
        
        // Merge the sorted halves
        merge(left, mid, right);
    }
}

void ThreadedQuickSortPicture::merge(int32_t left, int32_t mid, int32_t right) {
    // Copy the current state to temporary array
    for (int32_t i = left; i <= right; i++) {
        tempArray[i] = pixelIndexArray[i];
    }
    
    int32_t i = left;      // Initial index of left subarray
    int32_t j = mid + 1;   // Initial index of right subarray
    int32_t k = left;      // Initial index of merged subarray
    
    // Merge the temp arrays back into pixelIndexArray[left..right]
    while (i <= mid && j <= right) {
        // Compare the actual temp values
        comparisons++;
        if (tempArray[i] <= tempArray[j]) {
            pixelIndexArray[k] = tempArray[i];
            i++;
        } else {
            pixelIndexArray[k] = tempArray[j];
            j++;
        }
        k++;
        swaps++;  // Count each element placement as a swap for consistency
    }
    
    // Copy the remaining elements of left subarray, if any
    while (i <= mid) {
        pixelIndexArray[k] = tempArray[i];
        i++;
        k++;
        swaps++;  // Count each move as a swap
    }
    
    // Copy the remaining elements of right subarray, if any
    while (j <= right) {
        pixelIndexArray[k] = tempArray[j];
        j++;
        k++;
        swaps++;  // Count each move as a swap
    }
}