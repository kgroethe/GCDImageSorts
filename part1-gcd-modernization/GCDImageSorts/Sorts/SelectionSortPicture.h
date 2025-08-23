//
//  SelectionSortPicture.h
//  PThreadSorts
//
//  Contains: Selection Sort O(N*N)
//           Modernized to use AppKit instead of Carbon framework.
//
//  Originally by Karl Groethe, 2000
//  Modernized for macOS 11.0+, 2024
//

#ifndef SELECTION_SORT_PICTURE_H
#define SELECTION_SORT_PICTURE_H

#include "SortablePicture.h"

class SelectionSortPicture : public SortablePicture
{
public:
    SelectionSortPicture() : SortablePicture() {}
    virtual NSString* GetSortName() override { return @"Selection Sort"; }
    virtual NSString* GetBigONotation() override { return @"O(n²)"; }
    virtual void Sort() override;
};

#endif