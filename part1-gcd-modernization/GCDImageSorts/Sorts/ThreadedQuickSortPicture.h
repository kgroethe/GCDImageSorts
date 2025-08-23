//
//  ThreadedQuickSortPicture.h
//  PThreadSorts
//
//  Contains: Modern GCD Concurrent Quick Sort and Merge Sort
//           Replaced original pthread implementation with GCD for better performance.
//
//  Originally by Karl Groethe, 2000
//  Modernized for macOS 11.0+, 2024
//

#ifndef THREADED_QUICK_SORT_PICTURE_H
#define THREADED_QUICK_SORT_PICTURE_H

#include "SortablePicture.h"
#include <dispatch/dispatch.h>
#include <atomic>

// Modern GCD-based concurrent quicksort
class ThreadedQuickSortPicture : public SortablePicture
{
public:
    ThreadedQuickSortPicture(uint32_t algorithmType);
    virtual ~ThreadedQuickSortPicture();
    virtual NSString* GetSortName() override;
    virtual NSString* GetBigONotation() override;
    virtual void Sort() override;
    
protected:
    // GCD QuickSort methods
    void gcdQuicksort(int32_t lower, int32_t upper, dispatch_group_t group);
    void serialQuicksort(int32_t lower, int32_t upper);
    void kickstartParallelization();
    void mergeInPlace(int32_t start, int32_t mid, int32_t end);
    int32_t efficientPartition(int32_t lower, int32_t upper);
    int32_t partition(int32_t lower, int32_t upper);
    
    // Merge Sort methods
    void mergeSort(int32_t left, int32_t right);
    void merge(int32_t left, int32_t mid, int32_t right);
    
private:
    uint32_t algorithmType; // 1 = GCD QuickSort, 2 = Merge Sort
    dispatch_queue_t concurrent_queue;
    dispatch_group_t sort_group;
    std::atomic<int32_t> active_tasks;
    uint32_t* tempArray; // For merge sort
    const int32_t threshold = 100;  // Original balanced threshold
};

#endif