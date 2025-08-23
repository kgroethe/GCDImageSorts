//
//  MergeSortPicture.mm
//  PThreadSorts
//
//  Contains: Merge Sort Implementation O(N*log(N))
//           Stable sorting algorithm with consistent performance.
//
//  Modernized for macOS 11.0+, 2024
//

#include "MergeSortPicture.h"
#include <algorithm>

MergeSortPicture::MergeSortPicture() : SortablePicture() {
    tempArray = nullptr;
}

MergeSortPicture::~MergeSortPicture() {
    if (tempArray) {
        delete[] tempArray;
        tempArray = nullptr;
    }
}

NSString* MergeSortPicture::GetSortName() {
    return @"Merge Sort";
}

void MergeSortPicture::Sort() {
    if (linearPictSize > 1) {
        // Allocate temporary array for merging
        tempArray = new uint32_t[linearPictSize];
        
        // Perform merge sort
        mergeSort(0, linearPictSize - 1);
        
        // Clean up temporary array
        delete[] tempArray;
        tempArray = nullptr;
    }
}

void MergeSortPicture::mergeSort(int32_t left, int32_t right) {
    if (left < right) {
        int32_t mid = left + (right - left) / 2;
        
        // Sort first half
        mergeSort(left, mid);
        
        // Sort second half
        mergeSort(mid + 1, right);
        
        // Merge the sorted halves
        merge(left, mid, right);
    }
}

void MergeSortPicture::merge(int32_t left, int32_t mid, int32_t right) {
    // Copy the current state to temporary array
    for (int32_t i = left; i <= right; i++) {
        tempArray[i] = pixelIndexArray[i];
    }
    
    int32_t i = left;      // Initial index of left subarray
    int32_t j = mid + 1;   // Initial index of right subarray
    int32_t k = left;      // Initial index of merged subarray
    
    // Merge the temp arrays back into pixelIndexArray[left..right]
    while (i <= mid && j <= right) {
        // Use InOrder for consistent comparison with other sorts
        // We compare the original pixel values, not the indices
        if (tempArray[i] <= tempArray[j]) {
            pixelIndexArray[k] = tempArray[i];
            i++;
        } else {
            pixelIndexArray[k] = tempArray[j];
            j++;
        }
        k++;
        
        // Increment comparisons counter
        comparisons++;
        
        // Visual update every few operations
        if (comparisons % 500 == 0) {
            Draw();
        }
    }
    
    // Copy the remaining elements of left subarray, if any
    while (i <= mid) {
        pixelIndexArray[k] = tempArray[i];
        i++;
        k++;
    }
    
    // Copy the remaining elements of right subarray, if any
    while (j <= right) {
        pixelIndexArray[k] = tempArray[j];
        j++;
        k++;
    }
    
    // Count this as a swap operation for stats consistency
    swaps++;
}