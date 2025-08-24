//
//  SelectionSortPicture.mm
//  PThreadSorts
//
//  Contains: Selection Sort O(N*N) - Implementation
//           Modernized to use AppKit instead of Carbon framework.
//
//  Originally by Karl Groethe, 2000
//  Modernized for macOS 11.0+, 2024
//

#include "SelectionSortPicture.h"

void SelectionSortPicture::Sort() {
    for (uint32_t i = 0; i < linearPictSize - 1; i++) {
        uint32_t minIndex = i;
        
        for (uint32_t j = i + 1; j < linearPictSize; j++) {
            if (!InOrder(minIndex, j)) {
                minIndex = j;
            }
        }
        
        if (minIndex != i) {
            SwapPixels(i, minIndex);
        }
    }
}