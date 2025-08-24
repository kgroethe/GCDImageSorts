//
//  QuickSortPicture.h
//  PThreadSorts
//
//  Contains: Quick Sort O(N*log(N))
//           Modernized to use AppKit instead of Carbon framework.
//
//  Originally by Karl Groethe, 2000
//  Modernized for macOS 11.0+, 2024
//

#ifndef QUICK_SORT_PICTURE_H
#define QUICK_SORT_PICTURE_H

#include "SortablePicture.h"

class QuickSortPicture : public SortablePicture
{
public:
    QuickSortPicture() : SortablePicture() {}
    virtual NSString* GetSortName() override { return @"Quick Sort"; }
    virtual NSString* GetBigONotation() override { return @"O(n log n)"; }
    virtual void Sort() override;
    
protected:
    void qsort(int32_t lower, int32_t upper);
};

#endif