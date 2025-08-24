//
//  GCDQuickSortPicture.mm
//  PThreadSorts
//
//  Contains: GCD (Grand Central Dispatch) Concurrent Quick Sort Implementation
//           Uses modern dispatch queues for optimal performance scaling.
//
//  Modernized for macOS 11.0+, 2024
//

#include "GCDQuickSortPicture.h"
#include <algorithm>
#include <atomic>

GCDQuickSortPicture::GCDQuickSortPicture() : SortablePicture() {
    // Create a concurrent queue for parallel sorting
    concurrent_queue = dispatch_queue_create("com.pthreadsorts.quicksort", DISPATCH_QUEUE_CONCURRENT);
    sort_group = dispatch_group_create();
    active_tasks = 0;
}

GCDQuickSortPicture::~GCDQuickSortPicture() {
    // In ARC, dispatch objects are automatically managed
    // No manual release needed
}

NSString* GCDQuickSortPicture::GetSortName() {
    return @"GCD Concurrent Quick Sort";
}

void GCDQuickSortPicture::Sort() {
    if (linearPictSize > 1) {
        active_tasks = 0;
        quicksort(0, linearPictSize - 1, sort_group);
        
        // Wait for all concurrent operations to complete
        dispatch_group_wait(sort_group, DISPATCH_TIME_FOREVER);
    }
}

void GCDQuickSortPicture::quicksort(int32_t lower, int32_t upper, dispatch_group_t group) {
    if (lower < upper) {
        int32_t range = upper - lower;
        
        // For small ranges or when we have too many active tasks, sort serially
        if (range < threshold || active_tasks.load() > 8) {
            // Serial quicksort for small ranges
            int32_t pivot_index = partition(lower, upper);
            quicksort(lower, pivot_index - 1, group);
            quicksort(pivot_index + 1, upper, group);
        } else {
            // Parallel quicksort for larger ranges
            int32_t pivot_index = partition(lower, upper);
            
            // Increment active task counter
            active_tasks.fetch_add(2);
            
            // Sort left partition asynchronously
            dispatch_group_async(group, concurrent_queue, ^{
                quicksort(lower, pivot_index - 1, group);
                active_tasks.fetch_sub(1);
            });
            
            // Sort right partition asynchronously  
            dispatch_group_async(group, concurrent_queue, ^{
                quicksort(pivot_index + 1, upper, group);
                active_tasks.fetch_sub(1);
            });
        }
    }
}

int32_t GCDQuickSortPicture::partition(int32_t lower, int32_t upper) {
    // Choose middle element as pivot for better performance on sorted/reverse sorted data
    int32_t mid = lower + (upper - lower) / 2;
    SwapPixels(mid, upper);
    
    int32_t pivot = upper;
    int32_t i = lower - 1;
    
    for (int32_t j = lower; j < upper; j++) {
        if (InOrder(j, pivot)) {
            i++;
            if (i != j) {
                SwapPixels(i, j);
            }
        }
    }
    
    SwapPixels(i + 1, pivot);
    return i + 1;
}