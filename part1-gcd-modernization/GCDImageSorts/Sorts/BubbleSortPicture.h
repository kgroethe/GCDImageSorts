//
//  BubbleSortPicture.h
//  PThreadSorts
//
//  Contains: BubbleSort Classes O(N*N)
//           Modernized to use AppKit instead of Carbon framework.
//
//  Originally by Karl Groethe, 2000
//  Modernized for macOS 11.0+, 2024
//

#ifndef BUBBLE_SORT_PICTURE
#define BUBBLE_SORT_PICTURE

#include "SortablePicture.h"

class BubbleSortPicture : public SortablePicture
{
public:
    BubbleSortPicture() : SortablePicture() {}
    virtual NSString* GetSortName() override { return @"BubbleSort"; }
    virtual NSString* GetBigONotation() override { return @"O(n²)"; }
    virtual void Sort() override;
};

// Bubble Sort, only reversed
class RBubbleSortPicture : public SortablePicture
{
public:
    RBubbleSortPicture() : SortablePicture() {}
    virtual NSString* GetSortName() override { return @"BubbleSort(reversed)"; }
    virtual NSString* GetBigONotation() override { return @"O(n²)"; }
    virtual void Sort() override;
};

// Bubble Sort, alternating directions
class BiDirBubbleSortPicture : public SortablePicture
{
public:
    BiDirBubbleSortPicture() : SortablePicture() {}
    virtual NSString* GetSortName() override { return @"Bi-Directional Bubble Sort"; }
    virtual NSString* GetBigONotation() override { return @"O(n²)"; }
    virtual void Sort() override;
};

#endif