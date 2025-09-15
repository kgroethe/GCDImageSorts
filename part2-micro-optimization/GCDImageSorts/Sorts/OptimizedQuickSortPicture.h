//
//  OptimizedQuickSortPicture.h
//  GCDImageSorts
//
//  Contains: Ultra-optimized QuickSort using all micro-optimization techniques
//           ARM NEON SIMD, branchless operations, parallel GCD, cache optimization
//
//  Part 2B: Applying bubble sort learnings to a GOOD algorithm
//  Originally by Karl Groethe, 2000
//  Optimized for Apple Silicon, 2024
//

#ifndef OPTIMIZED_QUICKSORT_PICTURE_H
#define OPTIMIZED_QUICKSORT_PICTURE_H

#include "SortablePicture.h"
#include <atomic>
#include <arm_neon.h>

class OptimizedQuickSortPicture : public SortablePicture {
public:
    OptimizedQuickSortPicture();
    virtual ~OptimizedQuickSortPicture();
    
    virtual NSString* GetSortName() override { return @"Ultra-Optimized QuickSort"; }
    virtual NSString* GetBigONotation() override { return @"O(n log n) - SIMD + Parallel"; }
    virtual void Sort() override;
    
private:
    // Core sorting functions
    void OptimizedQuickSort(int32_t lower, int32_t upper, int32_t depth);
    int32_t OptimizedPartition_SIMD(int32_t lower, int32_t upper);
    int32_t ThreeWayPartition_SIMD(int32_t lower, int32_t upper, int32_t& equalEnd);
    
    // Specialized sorting for small arrays
    void InsertionSort_Optimized(int32_t lower, int32_t upper);
    
    // SIMD helper functions
    inline void CompareAndSwap_SIMD(uint32_t* array, int32_t i, int32_t j);
    inline uint32_t MedianOfThree_Branchless(uint32_t a, uint32_t b, uint32_t c);
    inline void GatherPivotCandidates_SIMD(int32_t lower, int32_t upper, uint32_t* candidates);
    
    // Parallel execution support
    void ParallelQuickSort(int32_t lower, int32_t upper, dispatch_group_t group);
    
    // Cache optimization
    static constexpr int32_t INSERTION_SORT_THRESHOLD = 32;  // Optimal for cache line
    static constexpr int32_t PARALLEL_THRESHOLD = 10000;      // When to use threads
    static constexpr int32_t MAX_DEPTH = 64;                  // Prevent stack overflow
    
    // Thread management
    std::atomic<int32_t> active_tasks;
    dispatch_queue_t concurrent_queue;
    dispatch_group_t sort_group;
    
    // Statistics for optimization analysis
    std::atomic<uint64_t> simd_operations;
    std::atomic<uint64_t> branchless_operations;
};

#endif // OPTIMIZED_QUICKSORT_PICTURE_H