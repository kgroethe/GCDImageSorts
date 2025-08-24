//
//  GCDQuickSortPicture.h
//  PThreadSorts
//
//  Contains: GCD (Grand Central Dispatch) Concurrent Quick Sort O(N*log(N))
//           Modern approach using dispatch queues for optimal performance.
//
//  Modernized for macOS 11.0+, 2024
//

#ifndef GCD_QUICK_SORT_PICTURE_H
#define GCD_QUICK_SORT_PICTURE_H

#include "SortablePicture.h"
#include <dispatch/dispatch.h>
#include <atomic>

class GCDQuickSortPicture : public SortablePicture
{
public:
    GCDQuickSortPicture();
    virtual ~GCDQuickSortPicture();
    virtual NSString* GetSortName() override;
    virtual void Sort() override;
    
protected:
    void quicksort(int32_t lower, int32_t upper, dispatch_group_t group);
    int32_t partition(int32_t lower, int32_t upper);
    
private:
    dispatch_queue_t concurrent_queue;
    dispatch_group_t sort_group;
    std::atomic<int32_t> active_tasks;
    const int32_t threshold = 1000; // Switch to serial sort below this size
};

#endif