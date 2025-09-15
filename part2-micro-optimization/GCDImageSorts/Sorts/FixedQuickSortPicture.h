//
//  FixedQuickSortPicture.h
//  GCDImageSorts
//
//  A PROPERLY optimized QuickSort that actually works
//

#ifndef FIXED_QUICKSORT_PICTURE_H
#define FIXED_QUICKSORT_PICTURE_H

#include "SortablePicture.h"
#include <atomic>
#include <arm_neon.h>

class FixedQuickSortPicture : public SortablePicture {
public:
    FixedQuickSortPicture();
    virtual ~FixedQuickSortPicture();
    
    virtual NSString* GetSortName() override { return @"Optimized QuickSort"; }
    virtual NSString* GetBigONotation() override { return @"O(n log n) - Properly Optimized"; }
    virtual void Sort() override;
    
private:
    void QuickSort(int32_t lower, int32_t upper);
    int32_t Partition(int32_t lower, int32_t upper);
    int32_t PartitionWithSIMD(int32_t lower, int32_t upper);
    void InsertionSort(int32_t lower, int32_t upper);
    void ParallelQuickSort(int32_t lower, int32_t upper, dispatch_group_t group);
    
    // Thresholds based on testing
    static constexpr int32_t INSERTION_THRESHOLD = 16;    // Use insertion sort for small arrays
    static constexpr int32_t SIMD_THRESHOLD = 128;        // Use SIMD for larger partitions
    static constexpr int32_t PARALLEL_THRESHOLD = 50000;  // Use parallel for large sections
    
    // Thread management
    std::atomic<int32_t> active_tasks;
    dispatch_queue_t concurrent_queue;
    dispatch_group_t sort_group;
    
    // Statistics
    std::atomic<uint64_t> simd_partitions;
    std::atomic<uint64_t> regular_partitions;
};

#endif