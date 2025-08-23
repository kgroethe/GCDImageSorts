//
//  QuickSortPicture.mm
//  PThreadSorts
//
//  Contains: Quick Sort O(N*log(N)) - Implementation
//           Modernized to use AppKit instead of Carbon framework.
//
//  Originally by Karl Groethe, 2000
//  Modernized for macOS 11.0+, 2024
//

#include "QuickSortPicture.h"

void QuickSortPicture::Sort() {
    if (linearPictSize > 1) {
        qsort(0, linearPictSize - 1);
    }
}

void QuickSortPicture::qsort(int32_t lower, int32_t upper) {
    if (lower < upper) {
        // Simple partition
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
        
        qsort(lower, right - 1);
        qsort(right + 1, upper);
    }
}