//
//  InsertionSortPicture.mm
//  PThreadSorts
//
//  Contains: Insertion Sort O(N*N) - Implementation
//           Modernized to use AppKit instead of Carbon framework.
//
//  Originally by Karl Groethe, 2000
//  Modernized for macOS 11.0+, 2024
//

#include "InsertionSortPicture.h"

void InsertionSortPicture::Sort() {
    for (uint32_t i = 1; i < linearPictSize; i++) {
        uint32_t key = i;
        int32_t j = i - 1;
        
        while (j >= 0 && !InOrder(j, key)) {
            SwapPixels(j + 1, j);
            key = j;  // Update key to track the moved element
            j--;
        }
    }
}