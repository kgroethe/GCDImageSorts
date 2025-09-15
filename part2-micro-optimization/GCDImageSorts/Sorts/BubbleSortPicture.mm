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
    // Log start with timestamp
    NSDate *startDate = [NSDate date];
    NSLog(@"=== BubbleSort STARTED at %@ with %u pixels ===", startDate, linearPictSize);
    
    for (uint32_t i = 0; i < linearPictSize - 1; i++) {
        for (uint32_t j = 0; j < linearPictSize - i - 1; j++) {
            if (!InOrder(j, j + 1)) {
                SwapPixels(j, j + 1);
            }
        }
        
        // Log progress periodically for larger arrays
        if (linearPictSize > 1000 && i % 200 == 0) {
            NSLog(@"BubbleSort progress: %u/%u passes completed", i, linearPictSize - 1);
        }
    }
    
    // Log completion with timestamp and detailed stats
    NSDate *endDate = [NSDate date];
    NSTimeInterval totalSeconds = [endDate timeIntervalSinceDate:startDate];
    NSLog(@"=== BubbleSort COMPLETED at %@ ===", endDate);
    NSLog(@"=== TOTAL TIME: %.2f seconds (%.0f ms) ===", totalSeconds, totalSeconds * 1000);
    NSLog(@"=== FINAL STATS: %llu swaps, %llu comparisons ===", swaps, comparisons);
    NSLog(@"=== PERFORMANCE: %.0f swaps/sec, %.0f comparisons/sec ===", 
          swaps / totalSeconds, comparisons / totalSeconds);
    
    // Also write to file for easier retrieval
    NSString *resultString = [NSString stringWithFormat:@"BubbleSort: %.2f seconds, %llu swaps, %llu comparisons\n", 
                             totalSeconds, swaps, comparisons];
    [resultString writeToFile:@"/tmp/bubble_result.txt" 
                   atomically:YES 
                     encoding:NSUTF8StringEncoding 
                        error:nil];
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