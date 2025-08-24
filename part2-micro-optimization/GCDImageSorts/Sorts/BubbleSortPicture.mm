//
//  BubbleSortPicture.mm
//  PThreadSorts
//
//  Contains: BubbleSort Classes O(N*N) - Implementation
//           Modernized to use AppKit instead of Carbon framework.
//
//  Originally by Karl Groethe, 2000
//  Modernized for macOS 11.0+, 2024
//

#include "BubbleSortPicture.h"

void BubbleSortPicture::Sort() {
    // Basic bubble sort implementation
    NSLog(@"BubbleSort started with %u pixels", linearPictSize);
    
    for (uint32_t i = 0; i < linearPictSize - 1; i++) {
        for (uint32_t j = 0; j < linearPictSize - i - 1; j++) {
            if (!InOrder(j, j + 1)) {
                SwapPixels(j, j + 1);
            }
        }
        
        // Log progress periodically for larger arrays
        if (linearPictSize > 1000 && i % 100 == 0) {
            NSLog(@"BubbleSort progress: %u/%u passes completed", i, linearPictSize - 1);
        }
    }
    
    NSLog(@"BubbleSort completed with %llu swaps, %llu comparisons", swaps, comparisons);
}

void RBubbleSortPicture::Sort() {
    // Reverse bubble sort implementation
    for (uint32_t i = 0; i < linearPictSize - 1; i++) {
        for (int32_t j = linearPictSize - 1; j > (int32_t)i; j--) {
            if (!InOrder(j - 1, j)) {
                SwapPixels(j - 1, j);
            }
        }
    }
}

void BiDirBubbleSortPicture::Sort() {
    // Bidirectional bubble sort implementation
    uint32_t left = 0;
    uint32_t right = linearPictSize - 1;
    
    while (left < right) {
        // Forward pass
        for (uint32_t i = left; i < right; i++) {
            if (!InOrder(i, i + 1)) {
                SwapPixels(i, i + 1);
            }
        }
        right--;
        
        // Backward pass
        for (uint32_t i = right; i > left; i--) {
            if (!InOrder(i - 1, i)) {
                SwapPixels(i - 1, i);
            }
        }
        left++;
    }
}