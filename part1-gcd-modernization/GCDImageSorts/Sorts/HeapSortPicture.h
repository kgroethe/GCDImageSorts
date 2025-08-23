//
//  HeapSortPicture.h
//  PThreadSorts
//
//  Contains: Heap Sort O(N*log(N))
//           Modernized to use AppKit instead of Carbon framework.
//
//  Originally by Karl Groethe, 2000
//  Modernized for macOS 11.0+, 2024
//

#ifndef HEAP_SORT_PICTURE_H
#define HEAP_SORT_PICTURE_H

#include "SortablePicture.h"

class HeapSortPicture : public SortablePicture
{
public:
    HeapSortPicture() : SortablePicture() {}
    virtual NSString* GetSortName() override { return @"Heap Sort"; }
    virtual NSString* GetBigONotation() override { return @"O(n log n)"; }
    virtual void Sort() override;
    
protected:
    void BuildHeap();
    void Heapify(uint32_t heapsize, uint32_t index);
};

#endif