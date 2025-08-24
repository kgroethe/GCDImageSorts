//
//  InsertionSortPicture.h
//  PThreadSorts
//
//  Contains: Insertion Sort O(N*N)
//           Modernized to use AppKit instead of Carbon framework.
//
//  Originally by Karl Groethe, 2000
//  Modernized for macOS 11.0+, 2024
//

#ifndef INSERTION_SORT_PICTURE_H
#define INSERTION_SORT_PICTURE_H

#include "SortablePicture.h"

class InsertionSortPicture : public SortablePicture
{
public:
    InsertionSortPicture() : SortablePicture() {}
    virtual NSString* GetSortName() override { return @"Insertion Sort"; }
    virtual NSString* GetBigONotation() override { return @"O(n²)"; }
    virtual void Sort() override;
};

#endif