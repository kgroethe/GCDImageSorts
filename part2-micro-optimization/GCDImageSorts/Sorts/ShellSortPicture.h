//
//  ShellSortPicture.h
//  PThreadSorts
//
//  Contains: Shell Sort O(N*N) worst case
//           Modernized to use AppKit instead of Carbon framework.
//
//  Originally by Karl Groethe, 2000
//  Modernized for macOS 11.0+, 2024
//

#ifndef SHELL_SORT_PICTURE_H
#define SHELL_SORT_PICTURE_H

#include "SortablePicture.h"

class ShellSortPicture : public SortablePicture
{
public:
    ShellSortPicture() : SortablePicture() {}
    virtual NSString* GetSortName() override { return @"Shell Sort"; }
    virtual NSString* GetBigONotation() override { return @"O(n^1.25)"; }
    virtual void Sort() override;
};

#endif