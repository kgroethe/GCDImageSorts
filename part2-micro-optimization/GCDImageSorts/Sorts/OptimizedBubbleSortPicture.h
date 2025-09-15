//
//  OptimizedBubbleSortPicture.h
//  GCDImageSorts
//
//  Contains: Micro-optimized BubbleSort Classes O(N*N)
//           Exploring SIMD, loop unrolling, and cache optimization techniques
//           to demonstrate limits of micro-optimization on poor algorithms.
//
//  Part 2: Micro-optimization experiments
//  Originally by Karl Groethe, 2000
//  Modernized for macOS 11.0+, 2024
//

#ifndef OPTIMIZED_BUBBLE_SORT_PICTURE
#define OPTIMIZED_BUBBLE_SORT_PICTURE

#include "SortablePicture.h"
#include <simd/simd.h>

class OptimizedBubbleSortPicture : public SortablePicture
{
public:
    OptimizedBubbleSortPicture() : SortablePicture() {}
    virtual NSString* GetSortName() override { return @"Optimized BubbleSort"; }
    virtual NSString* GetBigONotation() override { return @"O(n²) - micro-optimized"; }
    virtual void Sort() override;
    
private:
    // Micro-optimization techniques
    void OptimizedBubbleSort_SIMD();
    void OptimizedBubbleSort_Unrolled(); 
    void OptimizedBubbleSort_CacheFriendly();
    void OptimizedBubbleSort_Combined();
    void OptimizedBubbleSort_MultiThreadedSIMD();
    void OptimizedBubbleSort_Bidirectional();
    void OptimizedBubbleSort_BranchlessParallel();
    
    // SIMD helpers for pixel comparison and swapping
    inline bool ComparePixels_SIMD(const uint32_t* a, const uint32_t* b, size_t count);
    inline void SwapPixels_SIMD(uint32_t* a, uint32_t* b, size_t count);
    
    // Branchless comparison and swap - eliminates branch misprediction
    inline void BranchlessCompareSwap(uint32_t* a, uint32_t* b);
    inline void BranchlessCompareSwap_SIMD(uint32_t* a, uint32_t* b);
    
    // Cache-friendly memory access patterns
    void PrefetchNextCache(const uint32_t* addr);
    
    // Loop unrolling helpers
    template<int UnrollFactor>
    void BubbleSort_UnrolledInner(uint32_t* data, size_t start, size_t end);
};

#endif