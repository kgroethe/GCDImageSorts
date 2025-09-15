//
//  RadixSortPicture.h
//  GCDImageSorts
//
//  The ULTIMATE sorting algorithm for pixel data
//  Radix Sort with SIMD optimization and parallelization
//

#ifndef RADIX_SORT_PICTURE_H
#define RADIX_SORT_PICTURE_H

#include "SortablePicture.h"
#include <atomic>
#include <arm_neon.h>

class RadixSortPicture : public SortablePicture {
public:
    RadixSortPicture();
    virtual ~RadixSortPicture();
    
    virtual NSString* GetSortName() override { return @"Ultra Radix Sort"; }
    virtual NSString* GetBigONotation() override { return @"O(n) - Linear Time!"; }
    virtual void Sort() override;
    
private:
    // Core radix sort functions
    void RadixSortLSD();  // Least Significant Digit radix sort
    void CountingSortByByte(uint32_t byteIndex);
    void ParallelCountingSortByByte(uint32_t byteIndex);
    
    // SIMD optimized functions
    void ExtractBytesWithSIMD(uint32_t* source, uint8_t* dest, uint32_t count, uint32_t byteIndex);
    void GatherWithSIMD(uint32_t* source, uint32_t* dest, uint32_t* indices, uint32_t count);
    
    // Helper arrays
    uint32_t* tempArray;
    uint32_t* countArray;  // For counting sort buckets
    
    // Statistics
    std::atomic<uint64_t> passes;
    std::atomic<uint64_t> simd_operations;
    
    // Thread management for parallel passes
    dispatch_queue_t concurrent_queue;
    dispatch_group_t sort_group;
    
    // Constants
    static constexpr uint32_t RADIX = 256;  // Process one byte at a time
    static constexpr uint32_t PARALLEL_THRESHOLD = 100000;  // When to use parallel
};

#endif