//
//  MultiThreadedBubbleSortPicture.h  
//  GCDImageSorts
//
//  Contains: Multi-threaded NEON SIMD BubbleSort Class O(N*N) - Header
//           The ultimate micro-optimized bubble sort using all available
//           cores and SIMD instructions. Still O(n²), but incredibly fast O(n²).
//
//  Part 2: Micro-optimization experiments  
//  Originally by Karl Groethe, 2000
//  Modernized for macOS 11.0+, 2024
//

#ifndef MultiThreadedBubbleSortPicture_h
#define MultiThreadedBubbleSortPicture_h

#include "SortablePicture.h"

class MultiThreadedBubbleSortPicture : public SortablePicture {
    
public:
    MultiThreadedBubbleSortPicture() : SortablePicture(8, 8) { }
    virtual ~MultiThreadedBubbleSortPicture() {}
    
    virtual NSString* GetSortName() override { return @"Multi-Threaded NEON Bubble Sort"; }
    virtual NSString* GetBigONotation() override { return @"O(n²) - ultimate micro-optimization"; }
    virtual void Sort() override;
    
private:
    // Multi-threaded SIMD bubble sort implementation
    void MultiThreadedBubbleSort_Ultimate();
    
    // ARM NEON SIMD helpers
    inline bool ComparePixels_SIMD(const uint32_t* a, const uint32_t* b, size_t count);
    inline void SwapPixels_SIMD(uint32_t* a, uint32_t* b, size_t count);
};

#endif /* MultiThreadedBubbleSortPicture_h */