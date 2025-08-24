//
//  MergeSortPicture.h
//  PThreadSorts
//
//  Contains: Merge Sort O(N*log(N))
//           Stable sorting algorithm with consistent performance.
//
//  Modernized for macOS 11.0+, 2024
//

#ifndef MERGE_SORT_PICTURE_H
#define MERGE_SORT_PICTURE_H

#include "SortablePicture.h"

class MergeSortPicture : public SortablePicture
{
public:
    MergeSortPicture();
    virtual ~MergeSortPicture();
    virtual NSString* GetSortName() override;
    virtual void Sort() override;
    
protected:
    void mergeSort(int32_t left, int32_t right);
    void merge(int32_t left, int32_t mid, int32_t right);
    
private:
    uint32_t* tempArray; // Temporary array for merging
};

#endif