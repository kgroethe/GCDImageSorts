//
//  HeapSortPicture.mm
//  PThreadSorts
//
//  Contains: Heap Sort O(N*log(N)) - Implementation
//           Modernized to use AppKit instead of Carbon framework.
//
//  Originally by Karl Groethe, 2000
//  Modernized for macOS 11.0+, 2024
//

#include "HeapSortPicture.h"

void HeapSortPicture::Sort() {
    // Build max heap
    BuildHeap();
    
    // Extract elements from heap one by one
    for (uint32_t i = linearPictSize - 1; i > 0; i--) {
        SwapPixels(0, i);  // Move current root to end
        Heapify(i, 0);     // Call heapify on the reduced heap
    }
}

void HeapSortPicture::BuildHeap() {
    // Start from the last non-leaf node and heapify each node
    for (int32_t i = (linearPictSize / 2) - 1; i >= 0; i--) {
        Heapify(linearPictSize, i);
    }
}

void HeapSortPicture::Heapify(uint32_t heapsize, uint32_t index) {
    uint32_t largest = index;
    uint32_t left = 2 * index + 1;
    uint32_t right = 2 * index + 2;
    
    // Find largest among root, left child and right child
    if (left < heapsize && InOrder(largest, left)) {
        largest = left;
    }
    
    if (right < heapsize && InOrder(largest, right)) {
        largest = right;
    }
    
    // If largest is not root
    if (largest != index) {
        SwapPixels(index, largest);
        Heapify(heapsize, largest);  // Recursively heapify the affected sub-tree
    }
}