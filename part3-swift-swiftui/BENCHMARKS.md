# Part 3 benchmarks

Raw material for the Part 3 post. Every number here was produced by
`SortCore/Sources/sortbench`, not estimated.

## Method

- Release build, `-Ounchecked`, run from the command line with no UI attached.
- The scramble is Fisher-Yates driven by a seeded SplitMix64, so every run of a
  given size starts from an identical permutation and the two machines sort
  exactly the same arrangement.
- Every run is checked for order afterwards and reports `sorted: yes`. A run
  that did not finish sorted would be reported, not silently averaged in.
- 640x480 = 307,200 pixels, the size Parts 1 and 2 measured.

## 640x480, measured 2026-08-28

| Variant | M4 mini, 10 cores | M5 Max, 18 cores |
|---|---|---|
| BubbleSort | 62.375 s | 63.986 s |
| Branchless BubbleSort | 92.479 s | 97.045 s |
| SIMD Odd-Even | 51.203 s | 51.337 s |
| Parallel Odd-Even | **8.597 s** | 10.470 s |

All four report the same 23,512,182,364 swaps, which is the inversion count of
the shared starting permutation and a useful check that they are doing
equivalent work.

Two things worth keeping:

**Branchless is slower than naive**, by about 1.5x. This reproduces Part 2's
finding on the Objective-C++ side, where the branchless build came in at
26.52 s against threading's 20.86 s. Removing the branch does not pay for the
unconditional writes it costs.

**More cores made it slower.** Parallel odd-even is faster on the 10-core M4
mini than on the 18-core M5 Max. Each phase ends in a barrier, so wider
machines spend more of the run synchronising. This is a property of odd-even
transposition, not of Swift.

## What is not settled

Part 2 finished at 15.89 s on the M4 mini. The Swift parallel odd-even sort
does 8.597 s on that same machine. **That is not yet a like-for-like result and
should not be published as one:**

1. `sortbench` draws nothing. The 15.89 s run was rendering to screen on a
   timer and updating overlay fields while it sorted.
2. The algorithms differ. Part 2's best was a branchless parallel hybrid built
   on ARM NEON intrinsics; this is odd-even transposition using `min`/`max`.
3. The starting permutations differ, though only slightly by the swap counts
   (23,512M here against the 23,552M in Part 2's screenshot).

The measurement that would settle it: run Part 2's `OptimizedBubbleSortPicture`
on the mini with drawing disabled, and compare that against `sortbench` on the
same machine. Until then the fair statement is that Swift is in the same range
without any intrinsics, not that it beat the tuned C++.

Note also that Part 2's 366 s baseline included a redraw on every swap. The
comparable no-rendering baseline from Part 1 is 136.75 s.

## Reproducing

```sh
cd part3-swift-swiftui/SortCore
swift build -c release
./.build/release/sortbench --width 640 --height 480
```

`--only <substring>` filters, `--seed` changes the permutation. The Mac mini's
SwiftPM install is currently broken (Command Line Tools missing
`BuildServerProtocol.framework`), so that machine was measured by compiling the
sources directly with `swiftc -Ounchecked -wmo`.

## Part 4: the 3D case, measured 2026-08-28

A picture is a 2D grid of pixels, so its spatial equivalent is a 3D grid of
voxels. 64^3 = 262,144 voxels against 307,200 pixels for a 640x480 image, so
the two are the same order of magnitude.

The point worth making in the post: **every sorter in SortCore sorts the volume
without modification.** `VoxelVolume` is the same flat `[UInt32]` buffer as
`PixelCanvas`; only the meaning of the index changes, from (x, y) to (x, y, z).

M5 Max, release build, `sortbench --volume 64`, every run verified sorted:

| Algorithm | 262,144 voxels |
|---|---|
| GCD QuickSort | 0.002 s |
| RadixSort | 0.003 s |
| QuickSort | 0.006 s |
| Merge Sort | 0.009 s |
| Shell Sort | 0.011 s |
| Heap Sort | 0.012 s |
| Parallel Odd-Even | 7.898 s |

Numbers seen inside the visionOS app are much slower (RadixSort reports about
0.2 s there) because that is a Debug build running in the simulator. App
timings are not benchmark timings and should not be quoted as such.

### A rendering note that is worth a paragraph in the post

Sorted order runs x, then y, then z. That means each z-slice ends up holding one
narrow band of values, so a sorted cube viewed straight down the z axis is a
single flat colour: the gradient is entirely in the depth you are looking along.
The volume has to be turned before the sort is legible at all. Order that is
obvious in 2D can hide in 3D purely because of the axis you view it from.

## On device, measured 2026-08-31

iPhone 13 Pro Max (iPhone14,3), 6 cores, Release build, 640x480 = 307,200 px.
Same `SortCore` package that builds for macOS and visionOS, unmodified.

Run twice: once with no rendering, once driving a 60fps redraw off the buffer
while each sort ran. The second matches what Part 2 measured, whose AppDelegate
scheduled an `NSTimer` at `1.0/60.0` on the main thread while sorting happened
on background threads (`AppDelegate.mm`:706, `SortablePicture.mm`:619).

| Algorithm | rendering | no rendering |
|---|---|---|
| RadixSort | 0.003 s | 0.007 s |
| GCD QuickSort | 0.005 s | 0.004 s |
| Merge Sort | 0.013 s | 0.016 s |
| QuickSort | 0.015 s | 0.010 s |
| Heap Sort | 0.019 s | 0.017 s |
| Shell Sort | 0.027 s | 0.016 s |
| **Parallel Odd-Even** | **12.485 s** | 12.967 s |
| Insertion Sort | 13.422 s | 12.555 s |
| Selection Sort | 22.967 s | 20.560 s |
| SIMD Odd-Even | 83.396 s | 79.963 s |
| BubbleSort | 94.609 s | 94.130 s |
| Branchless BubbleSort | 138.236 s | 138.399 s |

Every run verified sorted.

### The comparison, finally like for like

**12.485 s on an iPhone 13 Pro Max, with rendering, against Part 2's 15.89 s on
the M4 Mac mini, with rendering.** A phone from 2021 running plain Swift with no
NEON intrinsics beats the hand-tuned Objective-C++ result on a desktop.

What is still not identical: the algorithms differ (odd-even transposition using
`min`/`max` versus a branchless NEON hybrid), and the permutations differ
slightly (23,583M swaps here against 23,552M in Part 2's screenshot). Rendering
is no longer one of the differences, which it was in every earlier comparison.

### Rendering costs almost nothing

This was the surprise. Rebuilding a 307,200 pixel image 60 times a second sounds
expensive, and it is not: the largest effect anywhere is 12% (selection sort),
and parallel odd-even came out marginally *faster* with rendering on, which is
noise rather than a real gain.

That reframes Part 2. Its 366 s original was not slow because drawing is
expensive. Drawing on a timer is nearly free. It was slow because it drew on
**every swap**, 23 billion times. The cost was the call frequency, never the
rendering itself.

### Note on the data model

These runs use the corrected `PixelCanvas`, which sorts an index array so the
picture reassembles, matching `SortablePicture::InOrder`. Earlier device numbers
in this session sorted pixel *values*, which produced a gradient rather than an
image and is not what the series does. Inversion counts shift slightly between
the two models (23,583M against 23,488M at this size), so the earlier figures
should not be mixed with these.
