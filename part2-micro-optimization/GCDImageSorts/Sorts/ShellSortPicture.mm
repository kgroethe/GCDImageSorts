//
//  ShellSortPicture.mm
//  PThreadSorts
//
//  Contains: Shell Sort O(N*N) worst case - Implementation
//           Modernized to use AppKit instead of Carbon framework.
//
//  Originally by Karl Groethe, 2000
//  Modernized for macOS 11.0+, 2024
//

#include "ShellSortPicture.h"

void ShellSortPicture::Sort() {
    // Shell sort with decreasing gap sequence
    for (uint32_t gap = linearPictSize / 2; gap > 0; gap /= 2) {
        // Insertion sort for elements gap apart
        for (uint32_t i = gap; i < linearPictSize; i++) {
            uint32_t temp = i;
            int32_t j = i - gap;
            
            // Move temp element to its correct position
            while (j >= 0 && !InOrder(j, temp)) {
                SwapPixels(j + gap, j);
                temp = j;  // Update temp to track the moved element
                j -= gap;
            }
        }
    }
    
    // Force final display update to show completed sort
    ForceDraw();
}