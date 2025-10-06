//
//  RadixSortPicture.mm
//  GCDImageSorts
//
//  The ULTIMATE sorting algorithm for pixel data
//  Radix Sort with SIMD optimization and parallelization
//

#include "RadixSortPicture.h"
#include <cstring>
#include <algorithm>

RadixSortPicture::RadixSortPicture() : SortablePicture() {
    tempArray = nullptr;
    countArray = nullptr;
    passes = 0;
    simd_operations = 0;
    
    // Create high-priority queue for performance cores
    dispatch_queue_attr_t attrs = dispatch_queue_attr_make_with_qos_class(
        DISPATCH_QUEUE_CONCURRENT, QOS_CLASS_USER_INTERACTIVE, 0);
    concurrent_queue = dispatch_queue_create("com.gcdsorts.radixsort", attrs);
    sort_group = dispatch_group_create();
}

RadixSortPicture::~RadixSortPicture() {
    if (tempArray) delete[] tempArray;
    if (countArray) delete[] countArray;
}

void RadixSortPicture::Sort() {
    if (linearPictSize <= 1) return;
    
    NSDate *startDate = [NSDate date];
    NSLog(@"⚡ RADIX SORT: Starting with %u pixels", linearPictSize);
    
    // Allocate helper arrays
    tempArray = new uint32_t[linearPictSize];
    countArray = new uint32_t[RADIX];
    
    // Perform LSD radix sort
    RadixSortLSD();
    
    // Clean up
    delete[] tempArray;
    tempArray = nullptr;
    delete[] countArray;
    countArray = nullptr;
    
    NSDate *endDate = [NSDate date];
    NSTimeInterval totalSeconds = [endDate timeIntervalSinceDate:startDate];
    
    NSLog(@"⚡ RADIX SORT COMPLETED: %.3f seconds", totalSeconds);
    NSLog(@"⚡ STATS: %llu passes, %llu SIMD operations", passes.load(), simd_operations.load());
    NSLog(@"⚡ PERFORMANCE: %llu operations (no swaps/comparisons in radix!)", 
          passes.load() * linearPictSize);
    
    // Write results
    NSString *resultString = [NSString stringWithFormat:
        @"RadixSort: %.3f seconds, %u pixels sorted\n", totalSeconds, linearPictSize];
    [resultString writeToFile:@"/tmp/radix_sort_result.txt" 
                   atomically:YES 
                     encoding:NSUTF8StringEncoding 
                        error:nil];
    
    // Force final display update to show completed sort
    ForceDraw();
}

void RadixSortPicture::RadixSortLSD() {
    // Process 4 bytes (32 bits) one byte at a time
    // This gives us O(4n) = O(n) complexity!
    
    for (uint32_t byteIndex = 0; byteIndex < 4; byteIndex++) {
        // Use parallel counting sort for large arrays
        if (linearPictSize > PARALLEL_THRESHOLD) {
            ParallelCountingSortByByte(byteIndex);
        } else {
            CountingSortByByte(byteIndex);
        }
        passes++;

        // No manual draw calls - let the NSTimer handle all UI updates
        NSLog(@"⚡ RADIX SORT: Completed pass %u/4", byteIndex + 1);
    }
}

void RadixSortPicture::CountingSortByByte(uint32_t byteIndex) {
    // Clear count array
    memset(countArray, 0, RADIX * sizeof(uint32_t));
    
    // Count occurrences of each byte value using SIMD
    uint32_t shift = byteIndex * 8;
    
    // Process 4 pixels at a time with NEON
    // Note: NEON shift requires compile-time constant, so we need separate paths
    uint32_t i = 0;
    if (shift == 0) {
        for (; i + 3 < linearPictSize; i += 4) {
            uint32x4_t pixels = vld1q_u32(&pixelIndexArray[i]);
            uint32x4_t bytes = vandq_u32(pixels, vdupq_n_u32(0xFF));
            countArray[vgetq_lane_u32(bytes, 0)]++;
            countArray[vgetq_lane_u32(bytes, 1)]++;
            countArray[vgetq_lane_u32(bytes, 2)]++;
            countArray[vgetq_lane_u32(bytes, 3)]++;
            simd_operations++;
        }
    } else if (shift == 8) {
        for (; i + 3 < linearPictSize; i += 4) {
            uint32x4_t pixels = vld1q_u32(&pixelIndexArray[i]);
            uint32x4_t shifted = vshrq_n_u32(pixels, 8);
            uint32x4_t bytes = vandq_u32(shifted, vdupq_n_u32(0xFF));
            countArray[vgetq_lane_u32(bytes, 0)]++;
            countArray[vgetq_lane_u32(bytes, 1)]++;
            countArray[vgetq_lane_u32(bytes, 2)]++;
            countArray[vgetq_lane_u32(bytes, 3)]++;
            simd_operations++;
        }
    } else if (shift == 16) {
        for (; i + 3 < linearPictSize; i += 4) {
            uint32x4_t pixels = vld1q_u32(&pixelIndexArray[i]);
            uint32x4_t shifted = vshrq_n_u32(pixels, 16);
            uint32x4_t bytes = vandq_u32(shifted, vdupq_n_u32(0xFF));
            countArray[vgetq_lane_u32(bytes, 0)]++;
            countArray[vgetq_lane_u32(bytes, 1)]++;
            countArray[vgetq_lane_u32(bytes, 2)]++;
            countArray[vgetq_lane_u32(bytes, 3)]++;
            simd_operations++;
        }
    } else { // shift == 24
        for (; i + 3 < linearPictSize; i += 4) {
            uint32x4_t pixels = vld1q_u32(&pixelIndexArray[i]);
            uint32x4_t shifted = vshrq_n_u32(pixels, 24);
            countArray[vgetq_lane_u32(shifted, 0)]++;
            countArray[vgetq_lane_u32(shifted, 1)]++;
            countArray[vgetq_lane_u32(shifted, 2)]++;
            countArray[vgetq_lane_u32(shifted, 3)]++;
            simd_operations++;
        }
    }
    
    // Handle remaining pixels
    for (; i < linearPictSize; i++) {
        uint32_t byteVal = (pixelIndexArray[i] >> shift) & 0xFF;
        countArray[byteVal]++;
    }
    
    // Convert counts to indices (prefix sum)
    uint32_t total = 0;
    for (uint32_t j = 0; j < RADIX; j++) {
        uint32_t count = countArray[j];
        countArray[j] = total;
        total += count;
    }
    
    // Build output array
    for (uint32_t i = 0; i < linearPictSize; i++) {
        uint32_t pixel = pixelIndexArray[i];
        uint32_t byteVal = (pixel >> shift) & 0xFF;
        tempArray[countArray[byteVal]++] = pixel;
    }
    
    // Copy back to original array
    memcpy(pixelIndexArray, tempArray, linearPictSize * sizeof(uint32_t));
}

void RadixSortPicture::ParallelCountingSortByByte(uint32_t byteIndex) {
    // Split work across multiple threads for counting phase
    uint32_t numThreads = 8;  // M4 has 10 cores, use 8 for efficiency
    uint32_t chunkSize = linearPictSize / numThreads;
    
    // Thread-local count arrays
    uint32_t** localCounts = new uint32_t*[numThreads];
    for (uint32_t t = 0; t < numThreads; t++) {
        localCounts[t] = new uint32_t[RADIX];
        memset(localCounts[t], 0, RADIX * sizeof(uint32_t));
    }
    
    uint32_t shift = byteIndex * 8;
    
    // Parallel counting phase
    dispatch_apply(numThreads, concurrent_queue, ^(size_t t) {
        uint32_t start = t * chunkSize;
        uint32_t end = (t == numThreads - 1) ? linearPictSize : (start + chunkSize);
        
        // Count in this thread's chunk with bounds checking
        for (uint32_t i = start; i < end && i < linearPictSize; i++) {
            if (pixelIndexArray && i < linearPictSize) {
                uint32_t byteVal = (pixelIndexArray[i] >> shift) & 0xFF;
                localCounts[t][byteVal]++;
            }
        }
    });
    
    // Merge thread-local counts
    memset(countArray, 0, RADIX * sizeof(uint32_t));
    for (uint32_t t = 0; t < numThreads; t++) {
        for (uint32_t j = 0; j < RADIX; j++) {
            countArray[j] += localCounts[t][j];
        }
    }
    
    // Convert to indices (prefix sum)
    uint32_t total = 0;
    for (uint32_t j = 0; j < RADIX; j++) {
        uint32_t count = countArray[j];
        countArray[j] = total;
        total += count;
    }
    
    // Build output array (sequential for cache coherency)
    for (uint32_t i = 0; i < linearPictSize; i++) {
        uint32_t pixel = pixelIndexArray[i];
        uint32_t byteVal = (pixel >> shift) & 0xFF;
        tempArray[countArray[byteVal]++] = pixel;
    }
    
    // Copy back
    memcpy(pixelIndexArray, tempArray, linearPictSize * sizeof(uint32_t));
    
    // Clean up
    for (uint32_t t = 0; t < numThreads; t++) {
        delete[] localCounts[t];
    }
    delete[] localCounts;
}