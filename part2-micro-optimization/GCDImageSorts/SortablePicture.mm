//
//  SortablePicture.mm
//  GCDImageSorts
//
//  Contains: Implementation of the Sortable Picture abstract base class.
//           Modern sorting visualization using AppKit and Grand Central Dispatch.
//
//  Originally by Karl Groethe, 2000
//  Modernized for macOS 11.0+, 2024
//

#import "SortablePicture.h"
#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>
#include <cstdlib>
#include <objc/runtime.h>
#include <ctime>
#include <cmath>
#include <algorithm>


/**
 * Constructor: Initialize a new sorting visualization window
 * Sets up the window, allocates memory, and creates the initial scrambled pattern
 */
SortablePicture::SortablePicture() {
    // Initialize display properties - optimal size for modern displays
    pictWidth = 640;
    pictHeight = 480;
    bytesPerPixel = 4; // RGBA
    bytesPerRow = pictWidth * bytesPerPixel;
    linearPictSize = pictWidth * pictHeight;
    displayScale = 1.0;  // Default to 1:1 display
    
    swaps = 0;
    comparisons = 0;
    showStats = true;
    overlaysEnabled = true;
    sortDurationMs = 0.0;
    sortCompleted = false;
    victoryScreenVisible = false;
    lastDrawTime = std::chrono::high_resolution_clock::now();
    
    // Initialize pointers to null
    pixelIndexArray = nullptr;
    pixelOffsetArray = nullptr;
    pixelBuffer = nullptr;
    pictWindow = nullptr;
    imageView = nullptr;
    displayImage = nullptr;
    originalBitmapData = nullptr;
    
    // Initialize overlay UI elements to null
    algorithmNameField = nullptr;
    bigOField = nullptr;
    timingField = nullptr;
    statsField = nullptr;
    imageInfoField = nullptr;
    
    // Set default wait times
    frameWaitTime.tv_sec = 0;
    frameWaitTime.tv_nsec = 16666667; // ~60 FPS
    
#ifdef SPEED_CONTROL
    swapWaitTime.tv_sec = 0;
    swapWaitTime.tv_nsec = 10000000; // 10ms for slower visualization
#endif

    // Create window and initialize visualization
    CreatePictWindow();
    AllocPictBitmap();
    CreateGradientPattern();  // Create default pattern for constructor
    AllocPixelArrays();
    Scramble();
    
    // Delay initial draw to ensure window is ready
    dispatch_async(dispatch_get_main_queue(), ^{
        Draw();
        UpdateStats();
    });
    
    // Set up initial overlay display (algorithm name will be set by AppDelegate)
    if (pictWindow) {
        UpdateStats();
        updateOverlayInfo();
        
        // Make sure overlay is visible at startup
        SetOverlaysEnabled(true);
    }
}

SortablePicture::~SortablePicture() {
    DisposePictWindow();
    DisposePixelArrays();
}

/**
 * Create and configure the visualization window
 * Sets up a resizable window with proper content view and image display
 */
void SortablePicture::CreatePictWindow() {
    
    // Calculate display size using scale factor for large images
    CGFloat displayWidth = pictWidth * displayScale;
    CGFloat displayHeight = pictHeight * displayScale;
    NSRect contentRect = NSMakeRect(100, 100, displayWidth, displayHeight);
    
    pictWindow = [[NSWindow alloc] 
        initWithContentRect:contentRect
        styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable)
        backing:NSBackingStoreBuffered
        defer:NO];
    
    [pictWindow setTitle:GetSortName()];
    [pictWindow setTitleVisibility:NSWindowTitleVisible];
    [pictWindow setTitlebarAppearsTransparent:NO];
    
    // The window is already created with the correct content size, no need to resize
    NSRect finalFrame = [pictWindow frame];
    
    // Create an image view that exactly matches the content area
    NSRect contentViewBounds = [[pictWindow contentView] bounds];
    imageView = [[NSImageView alloc] initWithFrame:contentViewBounds];
    [imageView setImageScaling:NSImageScaleAxesIndependently];
    [imageView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [pictWindow.contentView addSubview:imageView];
    
    
    [pictWindow makeKeyAndOrderFront:nil];
    
    
    // No bottom stats label - use overlays instead
    statsLabel = nil;
    
    // Create persistent overlay fields (hidden by default)
    createPersistentOverlayFields();
    
    // Make sure overlay is visible at startup
    SetOverlaysEnabled(true);
    updateOverlayInfo(); // Update with initial info
}

void SortablePicture::DisposePictWindow() {
    if (pictWindow) {
        [pictWindow close];
        pictWindow = nullptr;
    }
}

void SortablePicture::AllocPictBitmap() {
    // Allocate direct pixel buffer (RGBA format)
    size_t bufferSize = linearPictSize * bytesPerPixel;
    pixelBuffer = (uint8_t*)malloc(bufferSize);
    
    if (!pixelBuffer) {
        return;
    }
    
    // Only create gradient if we're not loading an image
    // (LoadImageFromFile will fill the buffer instead)
    // CreateGradientPattern();
    
    // Create initial NSImage from pixel buffer
    NSBitmapImageRep* bitmap = [[NSBitmapImageRep alloc] 
        initWithBitmapDataPlanes:&pixelBuffer
        pixelsWide:pictWidth
        pixelsHigh:pictHeight
        bitsPerSample:8
        samplesPerPixel:4
        hasAlpha:YES
        isPlanar:NO
        colorSpaceName:NSCalibratedRGBColorSpace
        bytesPerRow:bytesPerRow
        bitsPerPixel:32];
    
    displayImage = [[NSImage alloc] initWithSize:NSMakeSize(pictWidth, pictHeight)];
    [displayImage addRepresentation:bitmap];
    
    // Set initial image to the view
    [imageView setImage:displayImage];
    
}

void SortablePicture::LoadImageFromFile(NSString* imagePath) {
    // Clear all existing overlays when loading a new image
    clearAllOverlays();
    
    
    if (!imagePath) {
        CreateGradientPattern();
        return;
    }
    
    NSImage* sourceImage = [[NSImage alloc] initWithContentsOfFile:imagePath];
    if (!sourceImage) {
        CreateGradientPattern();
        return;
    }
    
    NSSize originalSize = sourceImage.size;
    
    // Additional debugging for image representations and get actual pixel dimensions
    NSArray* representations = [sourceImage representations];
    
    // Use the largest representation's pixel dimensions for true image size
    NSInteger maxPixels = 0;
    NSInteger actualWidth = (NSInteger)originalSize.width;
    NSInteger actualHeight = (NSInteger)originalSize.height;
    
    for (NSImageRep* rep in representations) {
        NSInteger pixelCount = rep.pixelsWide * rep.pixelsHigh;
        if (pixelCount > maxPixels) {
            maxPixels = pixelCount;
            actualWidth = rep.pixelsWide;
            actualHeight = rep.pixelsHigh;
        }
    }
    
    // Use actual pixel dimensions if available, otherwise fall back to points
    if (actualWidth > 0 && actualHeight > 0) {
        originalSize = NSMakeSize(actualWidth, actualHeight);
    } else {
    }
    
    // Calculate new dimensions respecting aspect ratio with reasonable constraints
    CGFloat aspectRatio = originalSize.width / originalSize.height;
    uint32_t newWidth, newHeight;
    
    // Set maximum size constraints (for performance and memory)
    const uint32_t maxDimension = 16384;  // Allow MEGA resolution for James Webb Telescope images
    const uint32_t minDimension = 100;
    
    if (originalSize.width > originalSize.height) {
        // Landscape image
        newWidth = MIN(maxDimension, MAX(minDimension, (uint32_t)originalSize.width));
        newHeight = (uint32_t)(newWidth / aspectRatio);
    } else {
        // Portrait or square image  
        newHeight = MIN(maxDimension, MAX(minDimension, (uint32_t)originalSize.height));
        newWidth = (uint32_t)(newHeight * aspectRatio);
    }
    
    // Ensure dimensions are reasonable
    if (newWidth < minDimension) newWidth = minDimension;
    if (newHeight < minDimension) newHeight = minDimension;
    if (newWidth > maxDimension) newWidth = maxDimension;
    if (newHeight > maxDimension) newHeight = maxDimension;
    
    
    // Calculate display scale for large images to keep windows manageable
    const uint32_t maxDisplayDimension = 1200;  // Maximum window size on screen
    CGFloat newDisplayScale = 1.0;
    if (newWidth > maxDisplayDimension || newHeight > maxDisplayDimension) {
        CGFloat scaleForWidth = (CGFloat)maxDisplayDimension / newWidth;
        CGFloat scaleForHeight = (CGFloat)maxDisplayDimension / newHeight;
        newDisplayScale = MIN(scaleForWidth, scaleForHeight);
    }
    
    // Only reallocate if dimensions changed significantly
    if (newWidth != pictWidth || newHeight != pictHeight) {
        // Clean up existing data
        if (pixelBuffer) {
            free(pixelBuffer);
            pixelBuffer = nullptr;
        }
        if (originalBitmapData) {
            delete[] originalBitmapData;
            originalBitmapData = nullptr;
        }
        if (pixelIndexArray) {
            delete[] pixelIndexArray;
            pixelIndexArray = nullptr;
        }
        if (pixelOffsetArray) {
            delete[] pixelOffsetArray;
            pixelOffsetArray = nullptr;
        }
        
        // Update dimensions and display scale
        pictWidth = newWidth;
        pictHeight = newHeight;
        bytesPerRow = pictWidth * bytesPerPixel;
        linearPictSize = pictWidth * pictHeight;
        displayScale = newDisplayScale;
        
        NSLog(@"📷 Loading image: original %dx%d, resized to %dx%d (%u pixels)", 
              (int)originalSize.width, (int)originalSize.height, 
              pictWidth, pictHeight, linearPictSize);
        
        // Reallocate with new dimensions
        AllocPictBitmap();
        AllocPixelArrays();
        Scramble();  // Scramble the newly allocated pixel array
        
        // Keep image view filling the entire content view - let NSImageScaleAxesIndependently handle scaling
        if (imageView) {
            // Image view should always fill the entire content view
            NSRect contentViewBounds = [[pictWindow contentView] bounds];
            [imageView setFrame:contentViewBounds];
            [imageView setImageScaling:NSImageScaleAxesIndependently]; // This will scale the image to fit
        }
        
        // Resize window to fit new display dimensions (scaled)
        if (pictWindow) {
            NSRect currentFrame = [pictWindow frame];
            CGFloat displayWidth = pictWidth * displayScale;
            CGFloat displayHeight = pictHeight * displayScale;
            NSRect contentRect = NSMakeRect(0, 0, displayWidth, displayHeight);
            NSRect newFrame = [pictWindow frameRectForContentRect:contentRect];
            
            // Keep the window in the same position (top-left corner)
            newFrame.origin.x = currentFrame.origin.x;
            newFrame.origin.y = currentFrame.origin.y + currentFrame.size.height - newFrame.size.height;
            
            [pictWindow setFrame:newFrame display:YES animate:YES];
        }
        
    } else {
    }
    
    // Clean up old data safely
    if (originalBitmapData) {
        delete[] originalBitmapData;
        originalBitmapData = nullptr;
    }
    
    // Create a temporary bitmap for drawing the scaled image
    NSBitmapImageRep* sourceRep = [[NSBitmapImageRep alloc] 
        initWithBitmapDataPlanes:nil 
        pixelsWide:pictWidth 
        pixelsHigh:pictHeight 
        bitsPerSample:8 
        samplesPerPixel:4 
        hasAlpha:YES 
        isPlanar:NO 
        colorSpaceName:NSCalibratedRGBColorSpace 
        bytesPerRow:bytesPerRow 
        bitsPerPixel:32];
    
    // Draw the source image into our bitmap at the correct size
    NSGraphicsContext* context = [NSGraphicsContext graphicsContextWithBitmapImageRep:sourceRep];
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:context];
    
    // Use NSZeroRect to draw the entire source image
    NSRect destRect = NSMakeRect(0, 0, pictWidth, pictHeight);
    [sourceImage drawInRect:destRect fromRect:NSZeroRect operation:NSCompositingOperationCopy fraction:1.0];
    
    [NSGraphicsContext restoreGraphicsState];
    
    // Copy the scaled image data directly to our pixel buffer
    uint8_t* sourceData = [sourceRep bitmapData];
    
    // Copy pixel data ensuring RGBA format directly to our memory-backed buffer
    for (uint32_t i = 0; i < linearPictSize; i++) {
        uint32_t offset = i * bytesPerPixel;
        pixelBuffer[offset] = sourceData[offset];       // Red
        pixelBuffer[offset + 1] = sourceData[offset + 1]; // Green
        pixelBuffer[offset + 2] = sourceData[offset + 2]; // Blue
        pixelBuffer[offset + 3] = 255;                    // Alpha (opaque)
    }
    
    // Store the original bitmap data
    originalBitmapData = new uint8_t[linearPictSize * bytesPerPixel];
    memcpy(originalBitmapData, pixelBuffer, linearPictSize * bytesPerPixel);
    
    // Update the display to show the loaded image
    Draw();
    
    // Update overlay to show new image information
    updateOverlayInfo();
}

void SortablePicture::CreateGradientPattern() {
    if (!pixelBuffer) return;
    
    // Create a colorful geometric test pattern
    for (uint32_t i = 0; i < linearPictSize; i++) {
        uint32_t offset = i * bytesPerPixel;
        uint32_t x = i % pictWidth;
        uint32_t y = i / pictWidth;
        
        uint8_t red = 0, green = 0, blue = 0;
        
        // Create multiple overlapping patterns for visual interest
        
        // 1. Diagonal stripes
        uint32_t diagonalStripe = (x + y) / 20;
        uint8_t stripeColor = (diagonalStripe % 3) * 80 + 40;
        
        // 2. Concentric circles from center
        float centerX = pictWidth / 2.0f;
        float centerY = pictHeight / 2.0f;
        float distance = sqrt((x - centerX) * (x - centerX) + (y - centerY) * (y - centerY));
        uint32_t ring = (uint32_t)(distance / 15) % 7;
        
        // Leave space at top for algorithm name overlay (50px)
        uint32_t adjustedY = y;
        if (y < 50) {
            // Top space - pure black background for overlay text
            red = green = blue = 0; // Pure black
            pixelBuffer[offset] = red;
            pixelBuffer[offset + 1] = green;
            pixelBuffer[offset + 2] = blue;
            pixelBuffer[offset + 3] = 255;
            continue;
        }
        adjustedY = y - 50; // Adjust for the reserved space
        
        // 3. Horizontal color bands (in the remaining space)
        uint32_t colorBand = (adjustedY * 6) / (pictHeight - 50);
        
        // Create sharp, vibrant colors
        switch (colorBand) {
            case 0: // Pure Red band
                red = 255;
                green = 0;
                blue = (ring % 2) * 255; // Black and blue stripes
                break;
            case 1: // Pure Yellow band  
                red = 255;
                green = 255;
                blue = ((x / 20) % 2) * 255; // Black and white vertical stripes
                break;
            case 2: // Pure Green band
                red = (ring % 2) * 255; // Red and black rings
                green = 255;
                blue = 0;
                break;
            case 3: // Pure Orange band
                red = 255;
                green = ((diagonalStripe % 2) == 0) ? 165 : 0; // Orange and red stripes
                blue = 0;
                break;
            case 4: // Pure Blue band
                red = 0;
                green = (ring % 3) * 127; // Black, gray, light gray rings
                blue = 255;
                break;
            case 5: // Black and White band
                uint8_t checker = ((x / 15) + (y / 15)) % 2;
                red = green = blue = checker * 255;
                break;
        }
        
        // Add some geometric shapes for extra visual interest (skip the top reserved space)
        if (y >= 50) {
            // Remove white corners - they look like errors. Keep the pattern consistent.
            
            // Add checkerboard pattern in the center region (adjusted for reserved space)
            uint32_t adjustedHeight = pictHeight - 50;
            if (x > pictWidth/3 && x < pictWidth*2/3 && 
                adjustedY > adjustedHeight/3 && adjustedY < adjustedHeight*2/3) {
                uint32_t checkX = (x - pictWidth/3) / 15;
                uint32_t checkY = (adjustedY - adjustedHeight/3) / 15;
                if ((checkX + checkY) % 2 == 0) {
                    red = (red + 100) / 2;
                    green = (green + 100) / 2;
                    blue = (blue + 100) / 2;
                }
            }
        }
        
        // Ensure values are in valid range
        red = red > 255 ? 255 : red;
        green = green > 255 ? 255 : green;
        blue = blue > 255 ? 255 : blue;
        
        pixelBuffer[offset] = red;         // Red
        pixelBuffer[offset + 1] = green;   // Green
        pixelBuffer[offset + 2] = blue;    // Blue
        pixelBuffer[offset + 3] = 255;     // Alpha
    }
    
    // Update the original bitmap data
    if (originalBitmapData) {
        delete[] originalBitmapData;
    }
    originalBitmapData = new uint8_t[linearPictSize * bytesPerPixel];
    memcpy(originalBitmapData, pixelBuffer, linearPictSize * bytesPerPixel);
}

void SortablePicture::DisposePictBitmap() {
    // Clean up pixel buffer
    if (pixelBuffer) {
        free(pixelBuffer);
        pixelBuffer = nullptr;
    }
    
    // Clean up original bitmap data
    delete[] originalBitmapData;
    originalBitmapData = nullptr;
    
    // displayImage will be cleaned up by ARC
    displayImage = nullptr;
}

void SortablePicture::AllocPixelArrays() {
    if (linearPictSize > 0) {
        pixelIndexArray = new uint32_t[linearPictSize];
        pixelOffsetArray = new uint32_t[linearPictSize];
        
        // Initialize arrays
        for (uint32_t i = 0; i < linearPictSize; i++) {
            pixelIndexArray[i] = i;
            pixelOffsetArray[i] = i * bytesPerPixel;
        }
    }
}

void SortablePicture::DisposePixelArrays() {
    delete[] pixelIndexArray;
    delete[] pixelOffsetArray;
    pixelIndexArray = nullptr;
    pixelOffsetArray = nullptr;
}

void SortablePicture::Scramble() {
    if (!pixelIndexArray) return;
    
    // Use high-resolution time and pointer address for better randomization
    // This prevents multiple windows created quickly from having identical scrambles
    auto now = std::chrono::high_resolution_clock::now();
    auto seed = static_cast<unsigned>(now.time_since_epoch().count()) ^ 
                reinterpret_cast<uintptr_t>(this);
    srand(seed);
    
    // Fisher-Yates shuffle for uniform distribution
    for (uint32_t i = linearPictSize - 1; i > 0; i--) {
        uint32_t j = rand() % (i + 1);
        std::swap(pixelIndexArray[i], pixelIndexArray[j]);
    }
    
    // Debug: Verify scrambling worked
    bool isScrambled = false;
    for (uint32_t i = 0; i < std::min(100u, linearPictSize); i++) {
        if (pixelIndexArray[i] != i) {
            isScrambled = true;
            break;
        }
    }
    NSLog(@"Scramble completed for %p: %s", this, isScrambled ? "SUCCESS" : "FAILED");
}

void SortablePicture::SwapBytes(uint8_t* a, uint8_t* b, uint32_t numBytes) {
    for (uint32_t i = 0; i < numBytes; i++) {
        std::swap(a[i], b[i]);
    }
}

/**
 * SwapPixels - Core sorting algorithm method
 * 
 * This method is called by sorting algorithms to swap two elements.
 * Display updates are now handled by a separate CADisplayLink running at 60fps
 * for smooth, consistent visual updates regardless of algorithm swap frequency.
 * 
 * This separation provides massive performance improvements for swap-heavy
 * algorithms like bubble sort by eliminating expensive time checks.
 */
void SortablePicture::SwapPixels(uint32_t indexA, uint32_t indexB) {
    if (indexA >= linearPictSize || indexB >= linearPictSize) return;

    std::swap(pixelIndexArray[indexA], pixelIndexArray[indexB]);
    swaps++;

    // Debug logging to track swap calls
    static uint64_t swapCallCount = 0;
    swapCallCount++;
    if (swapCallCount % 10000 == 0) { // Log every 10K swaps
        NSLog(@"SwapPixels() call #%llu - total swaps: %llu", swapCallCount, swaps);
    }

#ifdef SPEED_CONTROL
    nanosleep(&swapWaitTime, nullptr);
#endif
}

bool SortablePicture::InOrder(uint32_t indexA, uint32_t indexB) {
    if (indexA >= linearPictSize || indexB >= linearPictSize) return false;
    
    comparisons++;
    
    uint32_t valueA = pixelIndexArray[indexA];
    uint32_t valueB = pixelIndexArray[indexB];
    
    // For visual sorting, we want to sort pixels back to their original positions
    // So we compare if the pixel values are in ascending order (which would be sorted)
    bool result = valueA <= valueB;
    
    // Debug logging removed for production version
    
    return result;
}

void SortablePicture::Draw() {
    // CRITICAL: Check if we're on the main thread
    if (![NSThread isMainThread]) {
        NSLog(@"❌ THREADING ERROR: Draw() called from background thread! This will cause UI bugs.");
        dispatch_async(dispatch_get_main_queue(), ^{
            Draw();
        });
        return;
    }

    if (!pixelBuffer || !imageView || !originalBitmapData) {
        NSLog(@"Draw() called but missing components: pixelBuffer=%p, imageView=%p, originalBitmapData=%p",
              pixelBuffer, imageView, originalBitmapData);
        return;
    }

    // Debug logging to track draw calls
    static int drawCallCount = 0;
    drawCallCount++;
    if (drawCallCount % 30 == 0) { // Log every 30 calls
        NSLog(@"✅ Draw() call #%d - swaps: %llu (main thread)", drawCallCount, swaps);
    }
    
    // No throttling needed - NSTimer in AppDelegate already controls 60fps rate
    // This ensures smooth, fluid animations synchronized with the display refresh
    
    // Rearrange pixels directly in the memory-backed pixel buffer
    // This is a zero-copy operation - the CGImage will automatically reflect changes
    for (uint32_t i = 0; i < linearPictSize; i++) {
        uint32_t sourceIndex = pixelIndexArray[i];
        uint32_t destOffset = i * bytesPerPixel;
        uint32_t sourceOffset = sourceIndex * bytesPerPixel;
        
        if (sourceOffset + bytesPerPixel <= linearPictSize * bytesPerPixel) {
            // Direct 4-byte copy (RGBA pixel) - highly optimized
            *((uint32_t*)&pixelBuffer[destOffset]) = *((uint32_t*)&originalBitmapData[sourceOffset]);
        }
    }
    
    // Create a new NSImage from the updated pixel buffer
    dispatch_async(dispatch_get_main_queue(), ^{
        // Create NSBitmapImageRep directly from our pixel buffer
        NSBitmapImageRep* bitmap = [[NSBitmapImageRep alloc] 
            initWithBitmapDataPlanes:&pixelBuffer
            pixelsWide:pictWidth
            pixelsHigh:pictHeight
            bitsPerSample:8
            samplesPerPixel:4
            hasAlpha:YES
            isPlanar:NO
            colorSpaceName:NSCalibratedRGBColorSpace
            bytesPerRow:bytesPerRow
            bitsPerPixel:32];
        
        // Create new NSImage with the bitmap
        NSImage* newImage = [[NSImage alloc] initWithSize:NSMakeSize(pictWidth, pictHeight)];
        [newImage addRepresentation:bitmap];
        
        // Update the image view
        [imageView setImage:newImage];
        
        // CRITICAL: Ensure overlay stays visible and on top
        if (bigOField && overlaysEnabled) {
            NSView* overlayView = (NSView*)bigOField;
            NSView* contentView = [pictWindow contentView];
            
            // Check if overlay needs to be re-added or made visible
            NSArray* subviews = [contentView subviews];
            NSUInteger overlayIndex = [subviews indexOfObject:overlayView];
            
            if (overlayIndex == NSNotFound) {
                // Overlay was removed somehow - add it back
                NSLog(@"Draw() - WARNING: Overlay missing from hierarchy! Re-adding...");
                [contentView addSubview:overlayView];
                [overlayView setHidden:NO];
            } else if ([overlayView isHidden]) {
                // Overlay is hidden - show it
                NSLog(@"Draw() - WARNING: Overlay was hidden! Making visible...");
                [overlayView setHidden:NO];
            } else if (overlayIndex < [subviews count] - 1) {
                // Overlay is not on top - bring to front
                NSLog(@"Draw() - Overlay not on top (index=%lu of %lu), bringing to front", 
                      overlayIndex, [subviews count]);
                [overlayView removeFromSuperview];
                [contentView addSubview:overlayView];
                [overlayView setHidden:NO];
            }
            // If overlay is already visible and on top, do nothing to avoid flicker
        }
    });
    
    // Update timestamp
    auto currentTime = std::chrono::steady_clock::now();
    lastDrawTime = currentTime;
}

void SortablePicture::ForceDraw() {
    if (!pixelBuffer || !imageView || !originalBitmapData) return;
    
    // Force update display without timing throttle - used for final sort display
    for (uint32_t i = 0; i < linearPictSize; i++) {
        uint32_t sourceIndex = pixelIndexArray[i];
        uint32_t destOffset = i * bytesPerPixel;
        uint32_t sourceOffset = sourceIndex * bytesPerPixel;
        
        if (sourceOffset + bytesPerPixel <= linearPictSize * bytesPerPixel) {
            // Direct 4-byte copy (RGBA pixel) - highly optimized
            *((uint32_t*)&pixelBuffer[destOffset]) = *((uint32_t*)&originalBitmapData[sourceOffset]);
        }
    }
    
    // Create a new NSImage from the updated pixel buffer
    dispatch_async(dispatch_get_main_queue(), ^{
        // Create NSBitmapImageRep directly from our pixel buffer
        NSBitmapImageRep* bitmapRep = [[NSBitmapImageRep alloc]
            initWithBitmapDataPlanes:&pixelBuffer
                          pixelsWide:pictWidth
                          pixelsHigh:pictHeight
                       bitsPerSample:8
                     samplesPerPixel:4
                            hasAlpha:YES
                            isPlanar:NO
                      colorSpaceName:NSCalibratedRGBColorSpace
                        bitmapFormat:NSBitmapFormatThirtyTwoBitLittleEndian
                         bytesPerRow:bytesPerRow
                        bitsPerPixel:32];
        
        if (bitmapRep) {
            NSSize imageSize = NSMakeSize(pictWidth * displayScale, pictHeight * displayScale);
            NSImage* newImage = [[NSImage alloc] initWithSize:imageSize];
            [newImage addRepresentation:bitmapRep];
            [imageView setImage:newImage];
        }
        
        // CRITICAL: Ensure overlay stays visible and on top (same logic as Draw())
        if (bigOField && overlaysEnabled) {
            NSView* overlayView = (NSView*)bigOField;
            NSView* contentView = [pictWindow contentView];
            
            // Check if overlay needs to be re-added or made visible
            NSArray* subviews = [contentView subviews];
            NSUInteger overlayIndex = [subviews indexOfObject:overlayView];
            
            if (overlayIndex == NSNotFound) {
                // Overlay was removed somehow - add it back
                NSLog(@"ForceDraw() - WARNING: Overlay missing from hierarchy! Re-adding...");
                [contentView addSubview:overlayView];
                [overlayView setHidden:NO];
            } else if ([overlayView isHidden]) {
                // Overlay is hidden - show it
                NSLog(@"ForceDraw() - WARNING: Overlay was hidden! Making visible...");
                [overlayView setHidden:NO];
            } else if (overlayIndex < [subviews count] - 1) {
                // Overlay is not on top - bring to front
                NSLog(@"ForceDraw() - Overlay not on top, bringing to front");
                [overlayView removeFromSuperview];
                [contentView addSubview:overlayView];
                [overlayView setHidden:NO];
            }
        }
    });
    
    // Update timestamp
    lastDrawTime = std::chrono::steady_clock::now();
}

void SortablePicture::UpdateStats() {
    // Stats are now displayed in the overlay, so just trigger an overlay update
    updateOverlayInfo();
}

bool SortablePicture::GetShowStats() {
    return showStats;
}

void SortablePicture::SetShowStats(bool show) {
    showStats = show;
}

bool SortablePicture::GetOverlaysEnabled() {
    return overlaysEnabled;
}

void SortablePicture::SetOverlaysEnabled(bool enabled) {
    NSLog(@"SetOverlaysEnabled called with %s (current overlaysEnabled=%d)", 
          enabled ? "TRUE" : "FALSE", overlaysEnabled);
    overlaysEnabled = enabled;
    
    // Handle visibility and positioning here, not in updateOverlayInfo
    dispatch_async(dispatch_get_main_queue(), ^{
        if (bigOField) {
            NSView* overlayView = (NSView*)bigOField;
            NSView* contentView = [pictWindow contentView];
            
            if (enabled) {
                // Show and position the overlay
                if (contentView) {
                    NSRect contentViewBounds = [contentView bounds];
                    
                    // Calculate position (top-left corner with padding)
                    CGFloat padding = 10;
                    NSRect overlayFrame = NSMakeRect(
                        padding,
                        contentViewBounds.size.height - 80 - padding, // Fixed height estimate
                        300, // Fixed width
                        80   // Fixed height
                    );
                    
                    NSRect textFrameInOverlay = NSMakeRect(padding, padding, 280, 60);
                    
                    [overlayView setFrame:overlayFrame];
                    [algorithmNameField setFrame:textFrameInOverlay];
                }
                [overlayView setHidden:NO];
                NSLog(@"SetOverlaysEnabled: SHOWING overlay");
                
                // Update content after showing
                updateOverlayInfo();
            } else {
                // Just hide it
                [overlayView setHidden:YES];
                NSLog(@"SetOverlaysEnabled: HIDING overlay");
            }
        }
    });
}

void SortablePicture::SetWindowFrame(NSRect frame) {
    if (pictWindow) {
        [pictWindow setFrame:frame display:YES];
    }
}

NSWindow* SortablePicture::GetWindow() {
    return pictWindow;
}

timespec SortablePicture::GetFrameWaitTime() {
    return frameWaitTime;
}

#ifdef SPEED_CONTROL
void SortablePicture::SetFrameWaitTime(long waitTime) {
    frameWaitTime.tv_nsec = waitTime;
}

timespec SortablePicture::GetSwapWaitTime() {
    return swapWaitTime;
}

void SortablePicture::SetSwapWaitTime(long waitTime) {
    swapWaitTime.tv_nsec = waitTime;
}
#endif

void SortablePicture::DisposePictureWindow(NSWindow* window) {
    // Placeholder
}

void* SortablePicture::DrawThread(void* inPict) {
    // Placeholder
    return nullptr;
}

void* SortablePicture::ScrambleAndSortThread(void* inPict) {
    // Placeholder
    return nullptr;
}

void SortablePicture::StartSortTimer() {
    
    // DO NOT clear any overlays - let them stay visible during sorting
    // clearTemporaryOverlays();
    
    sortStartTime = std::chrono::high_resolution_clock::now();
    sortCompleted = false;
    sortDurationMs = 0.0;
    
}

void SortablePicture::EndSortTimer() {
    sortEndTime = std::chrono::high_resolution_clock::now();
    sortCompleted = true;
    
    auto duration = std::chrono::duration_cast<std::chrono::microseconds>(sortEndTime - sortStartTime);
    sortDurationMs = duration.count() / 1000.0; // Convert to milliseconds
    
    
    // Trigger final draw
    Draw();
    
    // Update overlay with final timing and statistics
    updateOverlayInfo();
    
    // Show prominent timing display immediately
    NSString* timingText = formatDurationMs(sortDurationMs);
    showBigTimingDisplay(timingText);
    
}

bool SortablePicture::IsRunning() const {
    return !sortCompleted;
}

void SortablePicture::DrawTimingOverlay() {
    // Simplified to avoid crashes - no-op for now
    return;
}

void SortablePicture::DrawAlgorithmOverlay() {
    // Simplified to avoid crashes - no-op for now
    return;
}

void SortablePicture::showBigTimingDisplay(NSString* timingText) {
    if (!pictWindow || !imageView) return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSView* contentView = [pictWindow contentView];
        NSRect contentViewBounds = [contentView bounds];
        
        // Create a large overlay view with translucent black background
        NSView* overlayBackground = [[NSView alloc] init];
        [overlayBackground setWantsLayer:YES];
        [overlayBackground.layer setBackgroundColor:[NSColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.7].CGColor];
        [overlayBackground.layer setCornerRadius:20]; // Rounded corners for game-like appearance
        [overlayBackground.layer setZPosition:2000]; // Above everything else
        
        // Create the big timing text
        NSTextField* bigTimingField = [[NSTextField alloc] init];
        [bigTimingField setEditable:NO];
        [bigTimingField setBordered:NO];
        [bigTimingField setBackgroundColor:[NSColor clearColor]];
        [bigTimingField setAlignment:NSTextAlignmentCenter];
        [bigTimingField setWantsLayer:YES];
        [bigTimingField.layer setZPosition:2001];
        [bigTimingField setStringValue:timingText];
        // Scale font sizes based on window size to ensure they fit
        CGFloat maxWindowDimension = MAX(contentViewBounds.size.width, contentViewBounds.size.height);
        CGFloat fontScale = MIN(1.0, maxWindowDimension / 800.0); // Scale down if window is smaller than 800px
        
        CGFloat timingFontSize = 48 * fontScale;
        CGFloat completedFontSize = 32 * fontScale;
        
        // Ensure minimum readable sizes
        timingFontSize = MAX(timingFontSize, 16);
        completedFontSize = MAX(completedFontSize, 14);
        
        [bigTimingField setFont:[NSFont boldSystemFontOfSize:timingFontSize]];
        [bigTimingField setTextColor:[NSColor whiteColor]];
        [bigTimingField sizeToFit];
        
        // Create "COMPLETED!" text above the timing
        NSTextField* completedField = [[NSTextField alloc] init];
        [completedField setEditable:NO];
        [completedField setBordered:NO];
        [completedField setBackgroundColor:[NSColor clearColor]];
        [completedField setAlignment:NSTextAlignmentCenter];
        [completedField setWantsLayer:YES];
        [completedField.layer setZPosition:2001];
        [completedField setStringValue:@"COMPLETED!"];
        [completedField setFont:[NSFont boldSystemFontOfSize:completedFontSize]];
        [completedField setTextColor:[NSColor colorWithRed:0.2 green:1.0 blue:0.2 alpha:1.0]]; // Bright green
        [completedField sizeToFit];
        
        // Calculate sizes and positioning
        NSSize timingSize = [bigTimingField frame].size;
        NSSize completedSize = [completedField frame].size;
        
        // Scale padding based on window size
        CGFloat padding = 20 * fontScale;
        padding = MAX(padding, 10); // Minimum padding
        
        CGFloat maxWidth = MAX(timingSize.width, completedSize.width);
        CGFloat totalHeight = completedSize.height + timingSize.height + 10; // Reduced spacing
        
        // Ensure the overlay fits within the window with some margin
        CGFloat maxOverlayWidth = contentViewBounds.size.width * 0.8; // 80% of window width
        CGFloat maxOverlayHeight = contentViewBounds.size.height * 0.6; // 60% of window height
        
        if (maxWidth + padding * 2 > maxOverlayWidth) {
            maxWidth = maxOverlayWidth - padding * 2;
        }
        if (totalHeight + padding * 2 > maxOverlayHeight) {
            totalHeight = maxOverlayHeight - padding * 2;
        }
        
        NSRect backgroundFrame = NSMakeRect(
            (contentViewBounds.size.width - maxWidth - padding * 2) / 2,
            (contentViewBounds.size.height - totalHeight - padding * 2) / 2,
            maxWidth + padding * 2,
            totalHeight + padding * 2
        );
        
        // Position "COMPLETED!" text
        NSRect completedFrame = NSMakeRect(
            (backgroundFrame.size.width - completedSize.width) / 2,
            backgroundFrame.size.height - padding - completedSize.height,
            completedSize.width,
            completedSize.height
        );
        
        // Position timing text below "COMPLETED!"
        NSRect timingFrame = NSMakeRect(
            (backgroundFrame.size.width - timingSize.width) / 2,
            completedFrame.origin.y - timingSize.height - 5, // Reduced spacing
            timingSize.width,
            timingSize.height
        );
        
        [overlayBackground setFrame:backgroundFrame];
        [completedField setFrame:completedFrame];
        [bigTimingField setFrame:timingFrame];
        
        // Add text fields to the background overlay
        [overlayBackground addSubview:completedField];
        [overlayBackground addSubview:bigTimingField];
        
        // Add the background overlay to the content view
        [contentView addSubview:overlayBackground];
        
        // Set flag to indicate victory screen is visible
        victoryScreenVisible = true;
        
        // Victory screen stays visible until user clicks it or starts/resets sorting
    });
}


void SortablePicture::hideBigTimingDisplay() {
    victoryScreenVisible = false;
    
    if (!pictWindow) return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSView* contentView = [pictWindow contentView];
        if (!contentView) return;
        
        // More aggressive removal of victory screen overlays
        NSArray* subviews = [[contentView subviews] copy];
        for (NSView* subview in subviews) {
            // Remove any view with high z-position (victory screen)
            if ([subview wantsLayer] && subview.layer && subview.layer.zPosition >= 2000) {
                [subview removeFromSuperview];
            }
            // Also remove views that look like victory overlays (translucent backgrounds)
            else if ([subview wantsLayer] && subview.layer) {
                CGColorRef bgColor = subview.layer.backgroundColor;
                if (bgColor) {
                    NSColor* color = [NSColor colorWithCGColor:bgColor];
                    // Check if it's a translucent black (victory overlay background)
                    if ([color alphaComponent] > 0.5 && [color alphaComponent] < 1.0) {
                        [subview removeFromSuperview];
                    }
                }
            }
        }
    });
}

void SortablePicture::clearAllOverlays() {
    // Clear victory screen first
    hideBigTimingDisplay();
    
    // Don't hide the stats overlay - it should always be visible
    // The stats overlay (bigOField) contains important info like swaps/comparisons
}

void SortablePicture::clearStatisticsOverlays() {
    // Don't hide the stats overlay anymore - it should always be visible
    // The stats overlay contains important info that should persist
}

void SortablePicture::clearTemporaryOverlays() {
    // Simplified to avoid crashes - no-op for now
    return;
}

NSString* SortablePicture::formatDurationMs(double durationMs) {
    if (durationMs < 1.0) {
        // Show microseconds for very fast sorts
        return [NSString stringWithFormat:@"%.2f μs", durationMs * 1000.0];
    } else if (durationMs < 1000.0) {
        // Show milliseconds with decimal places
        return [NSString stringWithFormat:@"%.2f ms", durationMs];
    } else {
        // Convert to total seconds
        double totalSeconds = durationMs / 1000.0;
        
        if (totalSeconds < 60.0) {
            // Show seconds with decimal places for under 1 minute
            return [NSString stringWithFormat:@"%.2f s", totalSeconds];
        } else {
            // Show hours/minutes/seconds format
            int hours = (int)(totalSeconds / 3600);
            int minutes = (int)((totalSeconds - (hours * 3600)) / 60);
            double seconds = totalSeconds - (hours * 3600) - (minutes * 60);
            
            if (hours > 0) {
                return [NSString stringWithFormat:@"%dhr %dmin %.2fs", hours, minutes, seconds];
            } else {
                return [NSString stringWithFormat:@"%dmin %.2fs", minutes, seconds];
            }
        }
    }
}

void SortablePicture::createPersistentOverlayFields() {
    if (!pictWindow) return;
    
    NSLog(@"Creating overlay fields SYNCHRONOUSLY");
    
    // Create synchronously since we're already on the main thread during window creation
    NSView* contentView = [pictWindow contentView];
    
    // Create a single overlay view that contains all information (like part1)
    NSView* overlayView = [[NSView alloc] init];
    [overlayView setWantsLayer:YES];
    [overlayView.layer setBackgroundColor:[NSColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.7].CGColor];
    [overlayView.layer setCornerRadius:8];
    [overlayView.layer setZPosition:1000];
    [overlayView setHidden:NO]; // Start visible since we call SetOverlaysEnabled(true) right after
    
    // Create a multi-line text field that shows all info (like part1)
    algorithmNameField = [[NSTextField alloc] init];
    [algorithmNameField setEditable:NO];
    [algorithmNameField setBordered:NO];
    [algorithmNameField setBackgroundColor:[NSColor clearColor]];
    [algorithmNameField setAlignment:NSTextAlignmentLeft];
    [algorithmNameField setFont:[NSFont systemFontOfSize:12]];
    [algorithmNameField setTextColor:[NSColor whiteColor]];
    [algorithmNameField setAccessibilityIdentifier:@"OverlayInfo"];
    
    // Add the text field to the overlay view
    [overlayView addSubview:algorithmNameField];
    [contentView addSubview:overlayView];
    
    // Store reference to overlay view in bigOField for convenience (like part1)
    bigOField = (NSTextField*)overlayView;
    
    NSLog(@"Overlay fields created SYNCHRONOUSLY: algorithmNameField=%p, bigOField=%p", 
          algorithmNameField, bigOField);
}
void SortablePicture::updateOverlayInfo() {
    if (!algorithmNameField || !overlaysEnabled) {
        NSLog(@"updateOverlayInfo SKIPPED: algorithmNameField=%p, overlaysEnabled=%d", 
              algorithmNameField, overlaysEnabled);
        return; // Don't update if overlay doesn't exist or is disabled
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        // DEBUG: Log everything about the overlay view
        NSView* overlayView = (NSView*)bigOField;
        if (overlayView) {
            BOOL isHidden = [overlayView isHidden];
            NSRect frame = [overlayView frame];
            CGFloat alpha = [overlayView alphaValue];
            NSView* superview = [overlayView superview];
            
            NSLog(@"OVERLAY DEBUG: hidden=%s, frame=%@, alpha=%.2f, superview=%p, swaps=%llu", 
                  isHidden ? "YES" : "NO", NSStringFromRect(frame), alpha, superview, swaps);
        } else {
            NSLog(@"OVERLAY DEBUG: overlayView is NULL!");
        }
        // Format large numbers with K/M suffix
        NSString* swapsText;
        NSString* comparisonsText;
        
        if (swaps >= 1000000) {
            swapsText = [NSString stringWithFormat:@"%.1fM", swaps / 1000000.0];
        } else if (swaps >= 1000) {
            swapsText = [NSString stringWithFormat:@"%.1fK", swaps / 1000.0];
        } else {
            swapsText = [NSString stringWithFormat:@"%llu", swaps];
        }
        
        if (comparisons >= 1000000) {
            comparisonsText = [NSString stringWithFormat:@"%.1fM", comparisons / 1000000.0];
        } else if (comparisons >= 1000) {
            comparisonsText = [NSString stringWithFormat:@"%.1fK", comparisons / 1000.0];
        } else {
            comparisonsText = [NSString stringWithFormat:@"%llu", comparisons];
        }
        
        // Create image info text (megapixels and size)
        double megapixels = linearPictSize / 1000000.0;
        NSString* imageInfoText;
        if (megapixels >= 1.0) {
            imageInfoText = [NSString stringWithFormat:@"%.1f MP (%ux%u)", megapixels, pictWidth, pictHeight];
        } else {
            imageInfoText = [NSString stringWithFormat:@"%.0f K (%ux%u)", linearPictSize / 1000.0, pictWidth, pictHeight];
        }
        
        // Create the complete overlay text
        NSString* overlayText;
        if (sortCompleted) {
            NSString* timingText = formatDurationMs(sortDurationMs);
            overlayText = [NSString stringWithFormat:@"%@ %@\nSwaps: %@  Comps: %@\n%@\nTime: %@", 
                          GetSortName(), GetBigONotation(), swapsText, comparisonsText, imageInfoText, timingText];
        } else {
            overlayText = [NSString stringWithFormat:@"%@ %@\nSwaps: %@  Comps: %@\n%@", 
                          GetSortName(), GetBigONotation(), swapsText, comparisonsText, imageInfoText];
        }
        
        // ONLY update the text content - no positioning or visibility changes
        [algorithmNameField setStringValue:overlayText];
    });
}

void SortablePicture::resetSorting() {
    // Clear victory screen and reset sorting state
    clearAllOverlays();
    hideBigTimingDisplay();
    victoryScreenVisible = false;
    sortCompleted = false;
    swaps = 0;
    comparisons = 0;
    sortDurationMs = 0.0;
    
    // Scramble the image and update display
    Scramble();
    Draw();
    UpdateStats();
    updateOverlayInfo();
}